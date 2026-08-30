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

    use work.dual_port_ram_pkg.all;
    use work.muxed_adc_pkg.all;
    use work.fixed_dsp_pkg.all;
    use work.fpga_interconnect_pkg.all;
    use work.adc_scale_pipeline_pkg.all;

-- owns both muxed_adc instances (their physical pins are ports of this
-- entity) : the caller decides what to request of each -- and when --
-- by driving muxed_adc_a_in/muxed_adc_b_in directly (e.g. with
-- muxed_adc_pkg's own request_measurement), which are just forwarded
-- straight into the internal muxed_adc instances. their measurement
-- output records, by contrast, stay entirely internal : nothing outside
-- this entity ever sees a raw measurement, only the gain/offset lookup
-- and fixed_dsp fmac scaling this entity applies to it.
--
-- one dpram holds every channel's gain, the other every channel's
-- offset : address 0..7 is ada's channels 0..7, address 8..15 is adb's.
-- port a of each is dedicated to ada/adb's own scanning (arbitrated with
-- fixed priority, ada first, at the point they request a lookup -- since
-- that already serializes them to at most one ram request in flight at a
-- time, no separate arbitration is needed later at the shared
-- fixed_dsp). port b of each is exposed on bus_to_adc_scaler /
-- bus_from_adc_scaler instead, so a host can read or write any channel's
-- calibration values live, the same way top.vhd's own dpram exposes
-- ram_a/ram_b over fpga_interconnect : a 16-address read window and a
-- 16-address write window per ram, plus one fixed readback address each
entity adc_scale_pipeline is
    generic(
        -- gain and offset are 32-bit signed values at this radix
        -- (make them with real_to_fixed_pkg.to_fixed(x, 32, g_radix)) ;
        -- raw is an integer count (radix 0), so raw*gain lands at this
        -- radix, offset is added at the same radix, and scaled_value is
        -- that sum shifted back down by g_radix
        g_radix : natural := 20

        ;g_u8_clk_cnt                 : integer := 2
        ;g_u8_clks_per_conversion     : integer := 18
        ;g_sh_counter_latch           : integer := 9
        ;g_mux_switch_delay_in_clocks : natural := 20

        ;g_gain_values   : work.dual_port_ram_pkg.ram_array
        ;g_offset_values : work.dual_port_ram_pkg.ram_array

        ;g_gain_ram_read_address     : natural
        ;g_gain_ram_write_address    : natural
        ;g_gain_ram_readback_address : natural

        ;g_offset_ram_read_address     : natural
        ;g_offset_ram_write_address    : natural
        ;g_offset_ram_readback_address : natural
    );
    port(
        clock : in std_logic

        ;ada_mux   : out std_logic_vector(2 downto 0)
        ;ada_clock : out std_logic
        ;ada_cs    : out std_logic
        ;ada_data  : in std_logic

        ;adb_mux   : out std_logic_vector(2 downto 0)
        ;adb_clock : out std_logic
        ;adb_cs    : out std_logic
        ;adb_data  : in std_logic

        ;bus_to_adc_scaler : in work.fpga_interconnect_pkg.fpga_interconnect_record
        ;bus_from_adc_scaler : out work.fpga_interconnect_pkg.fpga_interconnect_record

        ;muxed_adc_a_in : in muxed_adc_in_record
        ;muxed_adc_b_in : in muxed_adc_in_record

        ;adc_scale_pipeline_out : out adc_scale_pipeline_out_record
    );
end entity adc_scale_pipeline;

architecture rtl of adc_scale_pipeline is

    constant dsp_word_length : natural := 32;

    signal muxed_adc_a_out : muxed_adc_out_record;
    signal muxed_adc_b_out : muxed_adc_out_record;

    constant dp_ram_subtype : dpram_ref_record := create_ref_subtypes(
        datawidth     => 32
        ,addresswidth => 4);

    -- port a of each ram is dedicated to ada/adb's own scanning
    signal gain_ram_in    : dp_ram_subtype.ram_in'subtype  := dp_ram_subtype.ram_in;
    signal gain_ram_out   : dp_ram_subtype.ram_out'subtype;
    signal offset_ram_in  : dp_ram_subtype.ram_in'subtype  := dp_ram_subtype.ram_in;
    signal offset_ram_out : dp_ram_subtype.ram_out'subtype;

    -- port b of each ram is exposed to the host via bus_to_adc_scaler /
    -- bus_from_adc_scaler
    signal gain_ram_b_in    : dp_ram_subtype.ram_in'subtype  := dp_ram_subtype.ram_in;
    signal gain_ram_b_out   : dp_ram_subtype.ram_out'subtype;
    signal offset_ram_b_in  : dp_ram_subtype.ram_in'subtype  := dp_ram_subtype.ram_in;
    signal offset_ram_b_out : dp_ram_subtype.ram_out'subtype;

    signal fixed_dsp_in  : fixed_dsp_in_record(
        a(dsp_word_length-1 downto 0)
        ,d(dsp_word_length-1 downto 0)
        ,b(dsp_word_length-1 downto 0)
        ,c(2*dsp_word_length-1 downto 0)
    );
    signal fixed_dsp_out : fixed_dsp_out_record(
        result(2*dsp_word_length-1 downto 0)
    );

    -- adb conversions that finished while ada was granted the ram lookup
    -- this cycle queue here, so nothing is lost ; only channel+raw need
    -- to be remembered (unlike a full dsp request) since gain/offset
    -- haven't been fetched yet at this point. this is arbitration
    -- backlog (depth depends on contention, not a fixed latency), so it
    -- stays a fifo rather than becoming part of the shift register below
    type waiting_request is record
        channel : std_logic_vector(3 downto 0); -- combined 0..15 index (8..15 for adb)
        raw     : std_logic_vector(15 downto 0);
    end record;
    constant init_waiting_request : waiting_request := (
        channel => (others => '0'), raw => (others => '0'));

    constant b_waiting_fifo_depth : natural := 4;
    type waiting_request_array is array (0 to b_waiting_fifo_depth-1) of waiting_request;
    signal b_waiting_fifo      : waiting_request_array := (others => init_waiting_request);
    signal b_waiting_write_ptr : natural range 0 to b_waiting_fifo_depth-1 := 0;
    signal b_waiting_read_ptr  : natural range 0 to b_waiting_fifo_depth-1 := 0;
    signal b_waiting_count     : natural range 0 to b_waiting_fifo_depth  := 0;

    -- carries {channel, raw measurement} for a granted request through
    -- the ram lookup and on through fixed_dsp's own scaling, as a single
    -- fixed-depth, non-blocking shift register : both dual_port_ram and
    -- fixed_dsp accept a new request every cycle and always produce
    -- their result a fixed number of cycles later, so (unlike
    -- b_waiting_fifo's arbitration backlog, whose depth isn't
    -- predictable) this latency is a known constant, measured via
    -- simulation for this exact combination of dual_port_ram and
    -- fixed_dsp(ecp5) : 3 cycles from a ram request becoming visible to
    -- its data_is_ready, 6 more from a fixed_dsp request to its
    -- ready_with_1. a new entry (or an unused placeholder, on a cycle
    -- with no grant) shifts in every cycle regardless, so an entry
    -- granted this cycle is always exactly ram_latency+dsp_latency
    -- cycles behind its own result, whether or not the pipeline is busy
    constant ram_latency : natural := 3;
    constant dsp_latency : natural := 6;
    constant scaling_pipeline_depth : natural := ram_latency + dsp_latency;
    constant scaling_pipeline_width : natural := 4 + 16; -- channel & raw measurement

    type scaling_pipeline_array is array (0 to scaling_pipeline_depth-1) of std_logic_vector(scaling_pipeline_width-1 downto 0);
    signal scaling_pipeline : scaling_pipeline_array := (others => (others => '0'));

    -- g_gain_values / g_offset_values cannot be relied on as power-up ram
    -- contents : Synplify does not carry these array generics across
    -- adc_scale_pipeline's own generic boundary into the inner
    -- dual_port_ram's init (the map report shows every INITVAL_* of
    -- u_dpram_gain / u_dpram_offset as zero, while top.vhd's directly
    -- instantiated dpram keeps its init). an all-zero gain ram makes
    -- every scaled result raw*0 = 0, which is exactly the "all channels
    -- read zero" symptom. so the defaults are instead written into both
    -- rams over port a during the first 16 clocks after power-up, before
    -- the scan is allowed to request anything -- the mux switch delay
    -- alone is longer than that, so no conversion can complete first
    constant last_channel_address : natural := 15;
    signal startup_write_address  : natural range 0 to last_channel_address := 0;
    signal startup_complete       : std_logic := '0';

begin

    u_muxed_adc_a : entity work.muxed_adc
    generic map(g_u8_clk_cnt, g_u8_clks_per_conversion, g_sh_counter_latch, g_mux_switch_delay_in_clocks)
    port map(
        clock    => clock
        ,mux_io  => ada_mux
        ,ad_clock => ada_clock
        ,ad_cs    => ada_cs
        ,ad_data  => ada_data
        ,muxed_adc_in  => muxed_adc_a_in
        ,muxed_adc_out => muxed_adc_a_out
    );

    u_muxed_adc_b : entity work.muxed_adc
    generic map(g_u8_clk_cnt, g_u8_clks_per_conversion, g_sh_counter_latch, g_mux_switch_delay_in_clocks)
    port map(
        clock    => clock
        ,mux_io  => adb_mux
        ,ad_clock => adb_clock
        ,ad_cs    => adb_cs
        ,ad_data  => adb_data
        ,muxed_adc_in  => muxed_adc_b_in
        ,muxed_adc_out => muxed_adc_b_out
    );

    u_dpram_gain : entity work.dual_port_ram
    generic map(g_dpram_subtype => dp_ram_subtype, g_ram_init_values => g_gain_values)
    port map(clock, gain_ram_in, gain_ram_out, gain_ram_b_in, gain_ram_b_out);

    u_dpram_offset : entity work.dual_port_ram
    generic map(g_dpram_subtype => dp_ram_subtype, g_ram_init_values => g_offset_values)
    port map(clock, offset_ram_in, offset_ram_out, offset_ram_b_in, offset_ram_b_out);

    u_fixed_dsp : entity work.fixed_dsp
    port map(
        clock => clock
        ,fixed_dsp_in  => fixed_dsp_in
        ,fixed_dsp_out => fixed_dsp_out
    );

    -- host access to port b of both rams, mirroring top.vhd's own
    -- dpram-over-fpga_interconnect pattern : a read request at an address
    -- in the read window is answered later at the fixed readback
    -- address, once the ram reports it ready ; a write at an address in
    -- the write window lands immediately
    bus_interface : process(clock)
    begin
        if rising_edge(clock) then

            init_bus(bus_from_adc_scaler);
            init_ram(gain_ram_b_in);
            init_ram(offset_ram_b_in);

            if data_is_requested_from_address_range(bus_to_adc_scaler, g_gain_ram_read_address, g_gain_ram_read_address+16) then
                request_data_from_ram(gain_ram_b_in, get_address(bus_to_adc_scaler) - g_gain_ram_read_address);
            end if;

            if ram_read_is_ready(gain_ram_b_out) then
                write_data_to_address(bus_from_adc_scaler, g_gain_ram_readback_address, get_ram_data(gain_ram_b_out));
            end if;

            if write_is_requested_to_address_range(bus_to_adc_scaler, g_gain_ram_write_address, g_gain_ram_write_address+16) then
                write_data_to_ram(gain_ram_b_in, get_address(bus_to_adc_scaler) - g_gain_ram_write_address, get_slv_data(bus_to_adc_scaler));
            end if;

            if data_is_requested_from_address_range(bus_to_adc_scaler, g_offset_ram_read_address, g_offset_ram_read_address+16) then
                request_data_from_ram(offset_ram_b_in, get_address(bus_to_adc_scaler) - g_offset_ram_read_address);
            end if;

            if ram_read_is_ready(offset_ram_b_out) then
                write_data_to_address(bus_from_adc_scaler, g_offset_ram_readback_address, get_ram_data(offset_ram_b_out));
            end if;

            if write_is_requested_to_address_range(bus_to_adc_scaler, g_offset_ram_write_address, g_offset_ram_write_address+16) then
                write_data_to_ram(offset_ram_b_in, get_address(bus_to_adc_scaler) - g_offset_ram_write_address, get_slv_data(bus_to_adc_scaler));
            end if;

        end if;
    end process bus_interface;

    adc_scale_pipeline_out.ready_with_1 <= fixed_dsp_out.ready_with_1;
    adc_scale_pipeline_out.channel      <= scaling_pipeline(scaling_pipeline_depth-1)(scaling_pipeline_width-1 downto 16);
    adc_scale_pipeline_out.scaled_value <= std_logic_vector(resize(shift_right(fixed_dsp_out.result, g_radix), 32));

    process(clock)
        variable push_b   : boolean;
        variable grant_a  : boolean;
        variable pop_b    : boolean;
        variable new_entry : std_logic_vector(scaling_pipeline_width-1 downto 0);
    begin
        if rising_edge(clock) then

            init_ram(gain_ram_in);
            init_ram(offset_ram_in);
            init_fixed_dsp(fixed_dsp_in);

            -- a conversion completing always queues its request for a ram
            -- lookup, regardless of whether it goes on to be granted this
            -- same cycle, so nothing is lost when ada also wants the ram
            -- this cycle
            push_b := adc_ready(muxed_adc_b_out);

            -- arbiter : ada has fixed priority and is granted the ram the
            -- instant its own conversion completes ; adb is granted from
            -- its waiting queue whenever ada doesn't need the ram this
            -- cycle (so if both complete the same cycle, ada enters the
            -- scaling pipeline this cycle and adb the very next one)
            grant_a := adc_ready(muxed_adc_a_out);
            pop_b   := (not grant_a) and (b_waiting_count /= 0);

            if push_b then
                b_waiting_fifo(b_waiting_write_ptr) <= (
                    channel => "1" & get_sampled_mux_pos(muxed_adc_b_out)
                    ,raw    => get_adc_result(muxed_adc_b_out)
                );
                b_waiting_write_ptr <= (b_waiting_write_ptr + 1) mod b_waiting_fifo_depth;
            end if;

            -- whatever is granted this cycle (or nothing) enters the
            -- scaling pipeline at stage 0 ; an idle cycle still shifts a
            -- placeholder through, since the pipeline never stalls
            new_entry := (others => '0');

            if grant_a then

                new_entry := "0" & get_sampled_mux_pos(muxed_adc_a_out) & get_adc_result(muxed_adc_a_out);
                request_data_from_ram(gain_ram_in,   to_integer(unsigned(get_sampled_mux_pos(muxed_adc_a_out))));
                request_data_from_ram(offset_ram_in, to_integer(unsigned(get_sampled_mux_pos(muxed_adc_a_out))));

            elsif pop_b then

                new_entry := b_waiting_fifo(b_waiting_read_ptr).channel & b_waiting_fifo(b_waiting_read_ptr).raw;
                request_data_from_ram(gain_ram_in,   to_integer(unsigned(b_waiting_fifo(b_waiting_read_ptr).channel)));
                request_data_from_ram(offset_ram_in, to_integer(unsigned(b_waiting_fifo(b_waiting_read_ptr).channel)));
                b_waiting_read_ptr <= (b_waiting_read_ptr + 1) mod b_waiting_fifo_depth;

            end if;

            scaling_pipeline <= new_entry & scaling_pipeline(0 to scaling_pipeline_depth-2);

            -- single, unambiguous update covering every combination of
            -- push_b/pop_b this cycle (a plain "+1"/"-1" in each branch
            -- above would let whichever one executed last in program
            -- order silently clobber the other's update instead of
            -- combining them)
            if push_b and not pop_b then
                b_waiting_count <= b_waiting_count + 1;
            elsif pop_b and not push_b then
                b_waiting_count <= b_waiting_count - 1;
            end if;

            -- a request granted ram_latency cycles ago (tracked purely
            -- by pipeline position, not by re-deriving it from the ram)
            -- is exactly what the ram is reporting ready right now
            if ram_read_is_ready(gain_ram_out) then

                -- raw (radix 0) * gain (radix g_radix) = product at radix
                -- g_radix ; offset is stored at that same radix, so it is
                -- sign-extended into the product width and added directly,
                -- with no shift of its own
                add(fixed_dsp_in
                    ,a => resize(signed('0' & scaling_pipeline(ram_latency-1)(15 downto 0)), dsp_word_length)
                    ,b => resize(signed(get_ram_data(gain_ram_out)), dsp_word_length)
                    ,c => resize(signed(get_ram_data(offset_ram_out)), 2*dsp_word_length)
                );

            end if;


        end if;
    end process;

end architecture rtl;
