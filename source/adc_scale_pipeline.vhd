library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- channel 0..7 = ada's mux positions 0..7, channel 8..15 = adb's
package adc_scale_pipeline_pkg is

    type adc_scale_pipeline_out_record is record
        scaled_value : std_logic_vector(31 downto 0);
        ready_with_1 : std_logic;
        channel      : std_logic_vector(3 downto 0);
    end record;

    function adc_ready (self : adc_scale_pipeline_out_record) return boolean;
    function get_scaled_value (self : adc_scale_pipeline_out_record) return std_logic_vector;
    function get_channel (self : adc_scale_pipeline_out_record) return std_logic_vector;

end package adc_scale_pipeline_pkg;

package body adc_scale_pipeline_pkg is

    function adc_ready (self : adc_scale_pipeline_out_record) return boolean is
    begin
        return self.ready_with_1 = '1';
    end function;

    function get_scaled_value (self : adc_scale_pipeline_out_record) return std_logic_vector is
    begin
        return self.scaled_value;
    end function;

    function get_channel (self : adc_scale_pipeline_out_record) return std_logic_vector is
    begin
        return self.channel;
    end function;

end package body adc_scale_pipeline_pkg;

------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.muxed_adc_pkg.all;
    use work.fixed_dsp_pkg.all;
    use work.fpga_interconnect_pkg.all;
    use work.adc_scale_pipeline_pkg.all;

entity adc_scale_pipeline is
    generic(
        -- gain and offset are 32-bit signed values at this radix (make
        -- them with real_to_fixed_pkg.to_fixed(x, 32, g_radix)) ; raw is
        -- an integer count (radix 0), so raw*gain lands at this radix,
        -- offset is added at the same radix, and scaled_value is that sum
        -- shifted back down by g_radix.
        --
        -- the per-channel gain/offset tables power up as identity (gain
        -- 1.0, offset 0) and are calibrated in over the bus.
        g_radix : natural := 20

        ;g_gain_ram_address   : natural
        ;g_offset_ram_address : natural
    );
    port(
        clock : in std_logic

        ;bus_to_adc_scaler : in work.fpga_interconnect_pkg.fpga_interconnect_record
        ;bus_from_adc_scaler : out work.fpga_interconnect_pkg.fpga_interconnect_record

        -- measurement results from the two muxed_adc instances, which now
        -- live one level up (same layer as this entity)
        ;muxed_adc_a_out : in muxed_adc_out_record
        ;muxed_adc_b_out : in muxed_adc_out_record

        ;adc_scale_pipeline_out : out adc_scale_pipeline_out_record

        -- debug taps : the a (raw) and b (gain) operands latched at the
        -- cycle add() is issued, and a running OR of every dsp result low
        -- word ever seen (nonzero => the multiply does produce something)
        ;dbg_a        : out std_logic_vector(31 downto 0)
        ;dbg_b        : out std_logic_vector(31 downto 0)
        ;dbg_result_or : out std_logic_vector(31 downto 0)
    );
end entity adc_scale_pipeline;

architecture rtl of adc_scale_pipeline is

    constant dsp_word_length : natural := 32;

    -- per-channel calibration : must stay plain flip-flops so it keeps
    -- its power-up value (gain 1.0, offset 0). a variable-index write into
    -- an array makes synplify infer distributed LUT RAM, which the ecp5
    -- cannot initialise (syn_ramstyle "registers" does NOT override this),
    -- so the writes below are fully address-decoded per channel -- 16
    -- separate compare + load-enable FFs, no RAM. 16 x 32 bits each.
    type cal_array is array (0 to 15) of std_logic_vector(31 downto 0);
    constant identity_gain : std_logic_vector(31 downto 0) :=
        std_logic_vector(shift_left(to_unsigned(1, 32), g_radix));
    signal gain_cal   : cal_array := (others => identity_gain);
    signal offset_cal : cal_array := (others => (others => '0'));

    signal fixed_dsp_in  : fixed_dsp_in_record(
        a(dsp_word_length-1 downto 0)
        ,d(dsp_word_length-1 downto 0)
        ,b(dsp_word_length-1 downto 0)
        ,c(2*dsp_word_length-1 downto 0)
    );
    signal fixed_dsp_out : fixed_dsp_out_record(
        result(2*dsp_word_length-1 downto 0)
    );

    -- which channel a finished dsp result belongs to is tracked with a
    -- small fifo, NOT a fixed-depth shift register : retiming
    -- (map_reg_retiming / pipelining_retiming, both on in this build)
    -- freely reshapes arch_ecp5_fixed_dsp, so a hand-counted latency does
    -- not survive synthesis and the channel/result would drift apart on
    -- hardware. this is the same decoupling sine_calculator uses for its
    -- angle_fifo. requests never stall or reorder, so a channel pushed
    -- when add() is issued is popped in order when ready_with_1 fires ;
    -- depth only has to exceed the in-flight count (<= 1 here).
    constant fifo_depth : natural := 16;
    type channel_fifo_t is array (0 to fifo_depth-1) of std_logic_vector(3 downto 0);
    signal channel_fifo : channel_fifo_t := (others => (others => '0'));
    signal push_ptr   : natural range 0 to fifo_depth-1 := 0;
    signal output_ptr : natural range 0 to fifo_depth-1 := 0;

    -- most recent non-zero dsp result, and the plumbing to space adb's
    -- multiply well clear of ada's and to emit only after the result has
    -- definitely landed (see the scale process)
    signal result_held : signed(2*dsp_word_length-1 downto 0) := (others => '0');
    signal b_meas      : std_logic_vector(15 downto 0) := (others => '0');
    signal b_chan      : natural range 0 to 15 := 8;
    signal b_defer     : natural range 0 to 31 := 0;
    signal ready_delay : std_logic_vector(7 downto 0) := (others => '0');

    signal dbg_a_reg         : std_logic_vector(31 downto 0) := (others => '0');
    signal dbg_b_reg         : std_logic_vector(31 downto 0) := (others => '0');
    signal dbg_result_or_reg : std_logic_vector(31 downto 0) := (others => '0');

    -- registered entity outputs : all three fields are captured on the
    -- same clock edge from the dsp, so whatever alignment the dsp gives
    -- is frozen here and top's own capture register can't be retimed back
    -- through the combinational shift/resize and split the data away from
    -- its ready strobe.
    signal out_ready   : std_logic := '0';
    signal out_channel : std_logic_vector(3 downto 0) := (others => '0');
    signal out_scaled  : std_logic_vector(31 downto 0) := (others => '0');

    -- retiming (map_reg_retiming + pipelining_retiming, both on and both
    -- un-removable in this build) was shifting arch_ecp5_fixed_dsp's
    -- result register relative to its ready_with_1, so the scaled value
    -- was captured a cycle or two before it was valid (== 0). block it
    -- for this datapath.
    attribute syn_allow_retiming : boolean;
    -- freeze the whole scaler datapath : nothing here is on a critical
    -- path, and retiming was silently breaking the dsp result/ready
    -- alignment.
    attribute syn_allow_retiming of rtl         : architecture is false;
    attribute syn_allow_retiming of out_ready   : signal is false;
    attribute syn_allow_retiming of out_channel : signal is false;
    attribute syn_allow_retiming of out_scaled  : signal is false;
    attribute syn_allow_retiming of u_fixed_dsp : label is false;
    attribute syn_preserve : boolean;
    attribute syn_preserve of out_ready   : signal is true;
    attribute syn_preserve of out_channel : signal is true;
    attribute syn_preserve of out_scaled  : signal is true;

begin

--------------------------------------------------------
    u_fixed_dsp : entity work.fixed_dsp
    port map(
        clock => clock
        ,fixed_dsp_in  => fixed_dsp_in
        ,fixed_dsp_out => fixed_dsp_out
    );

--------------------------------------------------------
    bus_interface : process(clock)
    begin
        if rising_edge(clock) then

            init_bus(bus_from_adc_scaler);

            -- one 16-address window per table (channel 0..7 = ada, 8..15
            -- = adb). a write of <base + channel> updates that channel's
            -- calibration ; a read of <base + channel> returns it on the
            -- shared address-0 reply channel. fully decoded per channel so
            -- the tables stay flip-flops (see the note on gain_cal).
            for i in 0 to 15 loop
                if write_is_requested_to_address(bus_to_adc_scaler, g_gain_ram_address + i) then
                    gain_cal(i) <= get_slv_data(bus_to_adc_scaler);
                end if;
                if write_is_requested_to_address(bus_to_adc_scaler, g_offset_ram_address + i) then
                    offset_cal(i) <= get_slv_data(bus_to_adc_scaler);
                end if;
                if data_is_requested_from_address(bus_to_adc_scaler, g_gain_ram_address + i) then
                    write_data_to_address(bus_from_adc_scaler, 0, gain_cal(i));
                end if;
                if data_is_requested_from_address(bus_to_adc_scaler, g_offset_ram_address + i) then
                    write_data_to_address(bus_from_adc_scaler, 0, offset_cal(i));
                end if;
            end loop;

        end if;
    end process bus_interface;

    adc_scale_pipeline_out.ready_with_1 <= out_ready;
    adc_scale_pipeline_out.channel      <= out_channel;
    adc_scale_pipeline_out.scaled_value <= out_scaled;

    dbg_a         <= dbg_a_reg;
    dbg_b         <= dbg_b_reg;
    dbg_result_or <= dbg_result_or_reg;

----------------------------------
    scale : process(clock)
        variable channel : natural range 0 to 15;
    begin
        if rising_edge(clock) then

            init_fixed_dsp(fixed_dsp_in);

            -- debug : running OR of every dsp result low word, and the a/b
            -- operands as they were fed to add()
            dbg_result_or_reg <= dbg_result_or_reg or std_logic_vector(fixed_dsp_out.result(31 downto 0));

            -- hold the most recent NON-ZERO dsp result. ada and adb
            -- multiplies are spaced well apart (below) and ada->ada is
            -- ~500 cycles, so arch_ecp5_fixed_dsp's res_buf is non-zero
            -- only while a real result is present then decays to 0 --
            -- "last non-zero" is always the current conversion's value,
            -- no matter how retiming shifts result vs ready_with_1.
            if fixed_dsp_out.result /= 0 then
                result_held <= fixed_dsp_out.result;
            end if;

            -- ready_with_1 is a clean one-pulse-per-request strobe (a
            -- plain shift of request_with_1). delay the emit a few more
            -- cycles so result_held has definitely caught this request's
            -- result even if retiming makes ready fire early, then pair it
            -- with the channel fifo's oldest entry.
            ready_delay <= ready_delay(ready_delay'high-1 downto 0) & fixed_dsp_out.ready_with_1;
            out_ready <= '0';
            if ready_delay(ready_delay'high) = '1' then
                out_scaled  <= std_logic_vector(resize(shift_right(result_held, g_radix), 32));
                out_channel <= channel_fifo(output_ptr);
                output_ptr  <= (output_ptr + 1) mod fifo_depth;
                out_ready   <= '1';
            end if;

            if b_defer > 1 then
                b_defer <= b_defer - 1;
            end if;

            -- ada is issued the cycle it completes ; adb's conversion
            -- completes the same cycle, so its measurement is latched and
            -- its multiply deferred ~24 cycles, clear of ada's pipeline,
            -- so the two never share result_held.
            if adc_ready(muxed_adc_a_out) then
                channel := get_sampled_mux_pos(muxed_adc_a_out);
                add(fixed_dsp_in
                    ,a => resize(signed('0' & get_adc_result(muxed_adc_a_out)), dsp_word_length)
                    ,b => resize(signed(gain_cal(channel)), dsp_word_length)
                    ,c => resize(signed(offset_cal(channel)), 2*dsp_word_length)
                );
                dbg_a_reg <= std_logic_vector(resize(signed('0' & get_adc_result(muxed_adc_a_out)), dsp_word_length));
                dbg_b_reg <= gain_cal(channel);
                channel_fifo(push_ptr) <= std_logic_vector(to_unsigned(channel, 4));
                push_ptr <= (push_ptr + 1) mod fifo_depth;
            elsif b_defer = 1 then
                b_defer <= 0;
                channel := b_chan;
                add(fixed_dsp_in
                    ,a => resize(signed('0' & b_meas), dsp_word_length)
                    ,b => resize(signed(gain_cal(channel)), dsp_word_length)
                    ,c => resize(signed(offset_cal(channel)), 2*dsp_word_length)
                );
                dbg_a_reg <= std_logic_vector(resize(signed('0' & b_meas), dsp_word_length));
                dbg_b_reg <= gain_cal(channel);
                channel_fifo(push_ptr) <= std_logic_vector(to_unsigned(channel, 4));
                push_ptr <= (push_ptr + 1) mod fifo_depth;
            end if;

            if adc_ready(muxed_adc_b_out) then
                b_meas <= get_adc_result(muxed_adc_b_out);
                b_chan <= 8 + get_sampled_mux_pos(muxed_adc_b_out);
                b_defer <= 24;
            end if;

        end if;
    end process scale;

end architecture rtl;
