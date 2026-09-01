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
        -- the gain / offset tables are the Lattice RAM_DP IP cores
        -- adc_scaler_gain_ram / adc_scaler_offset_ram (512 x 32, one
        -- write port + one read port, 2-cycle registered read). power-up
        -- contents come from ip/adc_scaler_*_ram_init.mem : identity gain
        -- (2**g_radix) and zero offset -- g_radix must match the radix
        -- those .mem files were generated for (20).
        g_radix : natural := 20

        ;g_gain_ram_address   : natural
        ;g_offset_ram_address : natural
    );
    port(
        clock : in std_logic

        ;bus_to_adc_scaler : in work.fpga_interconnect_pkg.fpga_interconnect_record
        ;bus_from_adc_scaler : out work.fpga_interconnect_pkg.fpga_interconnect_record

        ;muxed_adc_a_out : in muxed_adc_out_record
        ;muxed_adc_b_out : in muxed_adc_out_record

        ;adc_scale_pipeline_out : out adc_scale_pipeline_out_record
    );
end entity adc_scale_pipeline;

architecture rtl of adc_scale_pipeline is

    constant dsp_word_length : natural := 32;

    -- rd_addr register (1) + IP RdAddress->Q (2)
    constant ram_latency : natural := 3;

    -- gain / offset IP RAMs : one shared read address (gain and offset
    -- are always the same channel), dedicated write ports
    signal rd_addr        : std_logic_vector(8 downto 0) := (others => '0');
    signal gain_wr_addr   : std_logic_vector(8 downto 0) := (others => '0');
    signal gain_wr_data   : std_logic_vector(31 downto 0) := (others => '0');
    signal gain_we        : std_logic := '0';
    signal gain_q         : std_logic_vector(31 downto 0);
    signal offset_wr_addr : std_logic_vector(8 downto 0) := (others => '0');
    signal offset_wr_data : std_logic_vector(31 downto 0) := (others => '0');
    signal offset_we      : std_logic := '0';
    signal offset_q       : std_logic_vector(31 downto 0);

    -- host-readback tag riding the shared read port : "01" gain, "10" offset
    type tag_array is array (0 to ram_latency-1) of std_logic_vector(1 downto 0);
    signal host_rd_tag : tag_array := (others => "00");

    -- scan read : (valid, raw, channel) held ram_latency cycles so it
    -- lands on the dsp add() the same cycle gain_q / offset_q are valid
    type scan_rec is record
        valid : std_logic;
        raw   : std_logic_vector(15 downto 0);
        chan  : std_logic_vector(3 downto 0);
    end record;
    constant scan_idle : scan_rec := ('0', (others => '0'), (others => '0'));
    type scan_arr is array (0 to ram_latency-1) of scan_rec;
    signal scan_pipe : scan_arr := (others => scan_idle);

    signal fixed_dsp_in  : fixed_dsp_in_record(
        a(dsp_word_length-1 downto 0)
        ,d(dsp_word_length-1 downto 0)
        ,b(dsp_word_length-1 downto 0)
        ,c(2*dsp_word_length-1 downto 0)
    );
    signal fixed_dsp_out : fixed_dsp_out_record(
        result(2*dsp_word_length-1 downto 0)
    );

    -- retiming-immune result capture : hold the last NON-ZERO dsp result
    -- (only one conversion is ever in flight -- adb deferred well clear
    -- of ada -- so res_buf decays to 0 between them and "last non-zero"
    -- is this conversion's value). emit emit_wait cycles after the dsp's
    -- own ready_with_1, by which point result_held has definitely caught
    -- this conversion's value whichever side of ready retiming puts it.
    constant emit_wait : natural := 12;
    signal result_held    : signed(2*dsp_word_length-1 downto 0) := (others => '0');
    signal pending_channel : std_logic_vector(3 downto 0) := (others => '0');
    signal emit_countdown  : natural range 0 to 15 := 0;

    signal out_ready   : std_logic := '0';
    signal out_channel : std_logic_vector(3 downto 0) := (others => '0');
    signal out_scaled  : std_logic_vector(31 downto 0) := (others => '0');

    -- adb's conversion completes the same cycle as ada's : latch it and
    -- issue its multiply ~b_defer_reload cycles later, clear of ada's
    -- whole pipeline, so the two never share result_held
    constant b_defer_reload : natural := 32;
    signal b_raw   : std_logic_vector(15 downto 0) := (others => '0');
    signal b_chan  : std_logic_vector(3 downto 0)  := (others => '0');
    signal b_defer : natural range 0 to 63 := 0;

begin

--------------------------------------------------------
    u_gain_ram : entity work.adc_scaler_gain_ram
    port map(
        WrAddress => gain_wr_addr, RdAddress => rd_addr,
        Data      => gain_wr_data, WE        => gain_we,
        RdClock   => clock, RdClockEn => '1', Reset => '0',
        WrClock   => clock, WrClockEn => '1', Q => gain_q);

--------------------------------------------------------
    u_offset_ram : entity work.adc_scaler_offset_ram
    port map(
        WrAddress => offset_wr_addr, RdAddress => rd_addr,
        Data      => offset_wr_data, WE        => offset_we,
        RdClock   => clock, RdClockEn => '1', Reset => '0',
        WrClock   => clock, WrClockEn => '1', Q => offset_q);

--------------------------------------------------------
    u_fixed_dsp : entity work.fixed_dsp
    port map(
        clock => clock
        ,fixed_dsp_in  => fixed_dsp_in
        ,fixed_dsp_out => fixed_dsp_out
    );

--------------------------------------------------------
    adc_scale_pipeline_out.ready_with_1 <= out_ready;
    adc_scale_pipeline_out.channel      <= out_channel;
    adc_scale_pipeline_out.scaled_value <= out_scaled;

    scaler : process(clock)
        variable a_pos : natural range 0 to 7;
        variable b_pos : natural range 0 to 7;
    begin
        if rising_edge(clock) then

            init_bus(bus_from_adc_scaler);
            init_fixed_dsp(fixed_dsp_in);

            gain_we   <= '0';
            offset_we <= '0';
            out_ready <= '0';

            -- shift the scan and host-tag pipelines
            scan_pipe(1 to ram_latency-1) <= scan_pipe(0 to ram_latency-2);
            scan_pipe(0) <= scan_idle;
            host_rd_tag(1 to ram_latency-1) <= host_rd_tag(0 to ram_latency-2);
            host_rd_tag(0) <= "00";

            if b_defer > 1 then
                b_defer <= b_defer - 1;
            end if;

            -- ---- host calibration writes : dedicated write port ----
            if write_is_requested_to_address_range(bus_to_adc_scaler, g_gain_ram_address, g_gain_ram_address+16) then
                gain_wr_addr <= std_logic_vector(to_unsigned(get_address(bus_to_adc_scaler) - g_gain_ram_address, 9));
                gain_wr_data <= get_slv_data(bus_to_adc_scaler);
                gain_we      <= '1';
            end if;
            if write_is_requested_to_address_range(bus_to_adc_scaler, g_offset_ram_address, g_offset_ram_address+16) then
                offset_wr_addr <= std_logic_vector(to_unsigned(get_address(bus_to_adc_scaler) - g_offset_ram_address, 9));
                offset_wr_data <= get_slv_data(bus_to_adc_scaler);
                offset_we      <= '1';
            end if;

            -- ---- shared read port : host readback > ada scan > deferred adb ----
            if data_is_requested_from_address_range(bus_to_adc_scaler, g_gain_ram_address, g_gain_ram_address+16) then
                rd_addr <= std_logic_vector(to_unsigned(get_address(bus_to_adc_scaler) - g_gain_ram_address, 9));
                host_rd_tag(0) <= "01";
            elsif data_is_requested_from_address_range(bus_to_adc_scaler, g_offset_ram_address, g_offset_ram_address+16) then
                rd_addr <= std_logic_vector(to_unsigned(get_address(bus_to_adc_scaler) - g_offset_ram_address, 9));
                host_rd_tag(0) <= "10";
            elsif adc_ready(muxed_adc_a_out) then
                a_pos := get_sampled_mux_pos(muxed_adc_a_out);
                rd_addr      <= std_logic_vector(to_unsigned(a_pos, 9));
                scan_pipe(0) <= ('1', get_adc_result(muxed_adc_a_out), std_logic_vector(to_unsigned(a_pos, 4)));
                if adc_ready(muxed_adc_b_out) then
                    b_pos  := get_sampled_mux_pos(muxed_adc_b_out);
                    b_raw  <= get_adc_result(muxed_adc_b_out);
                    b_chan <= std_logic_vector(to_unsigned(8 + b_pos, 4));
                    b_defer <= b_defer_reload;
                end if;
            elsif b_defer = 1 then
                b_defer <= 0;
                rd_addr      <= std_logic_vector(resize(unsigned(b_chan), 9));
                scan_pipe(0) <= ('1', b_raw, b_chan);
            elsif adc_ready(muxed_adc_b_out) then
                b_pos  := get_sampled_mux_pos(muxed_adc_b_out);
                b_raw  <= get_adc_result(muxed_adc_b_out);
                b_chan <= std_logic_vector(to_unsigned(8 + b_pos, 4));
                b_defer <= b_defer_reload;
            end if;

            -- ---- host readback reply : ram_latency cycles after issue ----
            if host_rd_tag(ram_latency-1) = "01" then
                write_data_to_address(bus_from_adc_scaler, 0, gain_q);
            elsif host_rd_tag(ram_latency-1) = "10" then
                write_data_to_address(bus_from_adc_scaler, 0, offset_q);
            end if;

            -- ---- feed the dsp when a scan read has propagated ----
            if scan_pipe(ram_latency-1).valid = '1' then
                add(fixed_dsp_in
                    ,a => resize(signed('0' & scan_pipe(ram_latency-1).raw), dsp_word_length)
                    ,b => resize(signed(gain_q), dsp_word_length)
                    ,c => resize(signed(offset_q), 2*dsp_word_length)
                );
                pending_channel <= scan_pipe(ram_latency-1).chan;
            end if;

            -- ---- retiming-immune result capture / emit ----
            if fixed_dsp_out.result /= 0 then
                result_held <= fixed_dsp_out.result;
            end if;

            if fixed_dsp_out.ready_with_1 = '1' then
                emit_countdown <= emit_wait;
            elsif emit_countdown = 1 then
                emit_countdown <= 0;
                out_scaled  <= std_logic_vector(resize(shift_right(result_held, g_radix), 32));
                out_channel <= pending_channel;
                out_ready   <= '1';
            elsif emit_countdown > 1 then
                emit_countdown <= emit_countdown - 1;
            end if;

        end if;
    end process;

end architecture rtl;
