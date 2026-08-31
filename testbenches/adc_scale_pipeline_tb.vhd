LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

    use work.dual_port_ram_pkg.all;
    use work.muxed_adc_pkg.all;
    use work.fpga_interconnect_pkg.all;
    use work.adc_scale_pipeline_pkg.all;
    use work.real_to_fixed_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;

-- validates adc_scale_pipeline end to end : both muxed adcs continuously
-- round-robin their 8 channels, each channel's gain/offset is looked up
-- from that adc's own dpram and applied via the shared fixed_dsp's fmac
-- (scaled = raw*gain + offset), and the result comes back tagged with
-- the right one of the 16 channels.
--
-- note: adc_scale_pipeline no longer takes a gain/offset init generic
-- (synplify drops a dual_port_ram init that crosses an entity's generic
-- boundary). its rams power up as identity (gain 1.0, offset 0) from a
-- local constant ; this bench calibrates all 16 gains and 16 offsets in
-- over port b during the first ~32 clocks, before the first measurement
-- result can appear, then checks the scaled results against those values.
--
-- both fake ads7056 slaves (u_ada_slave/u_adb_slave, the same
-- falling_edge(ad_cs)-loads / rising_edge(ad_clock)-shifts loopback
-- technique used by testbenches/ads7056_entity_tb.vhd and
-- testbenches/muxed_adc_tb.vhd) always present the same known raw code
-- regardless of which channel is being sampled -- muxed_adc's own
-- mux-position tagging was already verified bit-exactly in
-- muxed_adc_tb.vhd, so this testbench trusts whichever channel
-- adc_scale_pipeline reports and checks only what it is responsible for :
-- that channel's gain/offset lookup and fmac scaling. gain and offset are
-- 32-bit signed values at radix 20 (built here with real_to_fixed_pkg's
-- to_fixed) ; every gain and offset is a multiple of 0.25 and raw is
-- 2**14, so raw*gain + offset is exact at radix 20 and the expected
-- results below have no rounding.
entity adc_scale_pipeline_tb is
    generic (runner_cfg : string);
end;

architecture vunit_simulation of adc_scale_pipeline_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 3000;

    -- the muxed_adc instances now sit in the testbench alongside the DUT
    -- (as in top.vhd) ; this process drives their request inputs and
    -- adc_scale_pipeline only sees their measurement records. a fixed
    -- period, generous versus one conversion + ram lookup + arbitration,
    -- keeps the round-robin here simple and correct without watching
    -- muxed_adc's own ready/mux tag
    constant trigger_period : natural := 80;

    constant scaler_radix : natural := 20;
    constant raw_pattern  : std_logic_vector(15 downto 0) := x"4000"; -- 16384 = 2**14
    constant raw_value    : real := 16384.0;

    -- address 0..7 = ada's channels 0..7, address 8..15 = adb's.
    -- adb offsets go negative so the fmac's sign handling is exercised.
    -- expected(ch) = raw*gain(ch) + offset(ch)
    type real_array is array (0 to 15) of real;
    constant gain_real_values : real_array := (
        0 => 1.0, 1 => 1.5,  2 => 2.0, 3 => 2.5,  4 => 3.0, 5 => 3.5,  6 => 4.0, 7 => 4.5,
        8 => 1.0, 9 => 1.25, 10 => 1.5, 11 => 1.75, 12 => 2.0, 13 => 2.25, 14 => 2.5, 15 => 2.75);
    constant offset_real_values : real_array := (
        0 => 100.0,  1 => 200.0,  2 => 300.0,  3 => 400.0,  4 => 500.0, 5 => 600.0, 6 => 700.0, 7 => 800.0,
        8 => -800.0, 9 => -600.0, 10 => -400.0, 11 => -200.0, 12 => 0.0, 13 => 200.0, 14 => 400.0, 15 => 600.0);

    function build_ram_values (reals : real_array) return work.dual_port_ram_pkg.ram_array is
        variable retval : work.dual_port_ram_pkg.ram_array(0 to 15)(31 downto 0);
    begin
        for i in retval'range loop
            retval(i) := to_fixed(reals(i), 32, scaler_radix);
        end loop;
        return retval;
    end function;

    constant gain_values   : work.dual_port_ram_pkg.ram_array(0 to 15)(31 downto 0) := build_ram_values(gain_real_values);
    constant offset_values : work.dual_port_ram_pkg.ram_array(0 to 15)(31 downto 0) := build_ram_values(offset_real_values);

    -- signals, not constants : bus_test below overwrites channel
    -- bus_test_channel's gain/offset through port b (the same underlying
    -- memory ada/adb's own port a scans read from), so the expected
    -- value for that one channel changes partway through the simulation
    type expected_array is array (0 to 7) of integer;
    function build_expected (base : natural) return expected_array is
        variable retval : expected_array;
    begin
        for i in retval'range loop
            retval(i) := integer(raw_value * gain_real_values(base + i) + offset_real_values(base + i));
        end loop;
        return retval;
    end function;

    signal expected_ada : expected_array := build_expected(0);
    signal expected_adb : expected_array := build_expected(8);

    type checked_array is array (0 to 15) of boolean;
    signal checked : checked_array := (others => false);

    -- one 16-address host window per ram (serves reads and writes) ;
    -- reads come back on the shared address-0 reply channel
    constant gain_ram_address   : natural := 100;
    constant offset_ram_address : natural := 300;
    constant reply_address      : natural := 0;

    constant bus_test_channel         : natural := 3;
    constant bus_test_new_gain_real   : real := 3.25;
    constant bus_test_new_offset_real : real := -300.0;
    constant bus_test_new_gain   : std_logic_vector(31 downto 0) := to_fixed(bus_test_new_gain_real,   32, scaler_radix);
    constant bus_test_new_offset : std_logic_vector(31 downto 0) := to_fixed(bus_test_new_offset_real, 32, scaler_radix);

    signal bus_test_gain_done   : boolean := false;
    signal bus_test_offset_done : boolean := false;

    signal simulator_clock : std_logic := '0';

    signal ada_mux   : std_logic_vector(2 downto 0);
    signal ada_clock : std_logic;
    signal ada_cs    : std_logic;
    signal ada_data  : std_logic := '1';

    signal adb_mux   : std_logic_vector(2 downto 0);
    signal adb_clock : std_logic;
    signal adb_cs    : std_logic;
    signal adb_data  : std_logic := '1';

    signal muxed_adc_a_in  : muxed_adc_in_record := init_muxed_adc_in;
    signal muxed_adc_b_in  : muxed_adc_in_record := init_muxed_adc_in;
    signal muxed_adc_a_out : muxed_adc_out_record;
    signal muxed_adc_b_out : muxed_adc_out_record;

    -- offset by 1 (not 0) so the first trigger lands well after the
    -- adc's own startup calibration, instead of racing it at time 0
    signal trigger_counter : natural range 0 to trigger_period-1 := 1;
    signal ada_next_channel : std_logic_vector(2 downto 0) := (others => '0');
    signal adb_next_channel : std_logic_vector(2 downto 0) := (others => '0');

    signal adc_scale_pipeline_out : adc_scale_pipeline_out_record;
    signal bus_to_adc_scaler      : work.fpga_interconnect_pkg.fpga_interconnect_record;
    signal bus_from_adc_scaler    : work.fpga_interconnect_pkg.fpga_interconnect_record;

begin

------------------------------------------------------------------------
    simtime : process
        variable all_checked : boolean;
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;

        all_checked := true;
        for i in checked'range loop
            if not checked(i) then
                all_checked := false;
            end if;
        end loop;
        check(all_checked, "not every one of the 16 channels was observed within the simulation window");
        check(bus_test_gain_done, "gain ram port b read/write over fpga_interconnect never completed");
        check(bus_test_offset_done, "offset ram port b read/write over fpga_interconnect never completed");

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    -- drives muxed_adc_a_in/muxed_adc_b_in directly (this is now the
    -- caller's job, not adc_scale_pipeline's) : round-robins channels
    -- 0 to 7 on a fixed period
    stimulus : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then

            init_muxed_adc(muxed_adc_a_in);
            init_muxed_adc(muxed_adc_b_in);

            if trigger_counter < trigger_period-1 then
                trigger_counter <= trigger_counter + 1;
            else
                trigger_counter <= 0;
            end if;

            if trigger_counter = 0 then
                request_measurement(muxed_adc_a_in, ada_next_channel);
                request_measurement(muxed_adc_b_in, adb_next_channel);
                ada_next_channel <= std_logic_vector(unsigned(ada_next_channel) + 1);
                adb_next_channel <= std_logic_vector(unsigned(adb_next_channel) + 1);
            end if;

        end if; -- rising_edge
    end process stimulus;
------------------------------------------------------------------------

    -- first loads the whole calibration in over port b (16 gains on
    -- cycles 1..16, 16 offsets on cycles 17..32 -- well before the first
    -- measurement result can appear), since the rams now power up as
    -- identity rather than from a generic. then exercises the readback
    -- path : rewrites one channel, requests it back and checks the
    -- readback matches -- proving the host path reaches the ram and back,
    -- independent of ada/adb's own port a scanning. gain and offset both
    -- reply on address 0, so the readbacks are done one at a time (gain
    -- first, then offset) the way a real host would.
    bus_test : process(simulator_clock)
        variable cycle : natural := 0;
    begin
        if rising_edge(simulator_clock) then

            init_bus(bus_to_adc_scaler);
            cycle := cycle + 1;

            -- gain and offset are full 32-bit signed bus words, through
            -- write_data_to_address's std_logic_vector overload, read
            -- straight back as signed 32 bit
            if cycle >= 1 and cycle <= 16 then
                write_data_to_address(bus_to_adc_scaler, gain_ram_address + (cycle - 1), gain_values(cycle - 1));
            elsif cycle >= 17 and cycle <= 32 then
                write_data_to_address(bus_to_adc_scaler, offset_ram_address + (cycle - 17), offset_values(cycle - 17));
            elsif cycle = 200 then
                write_data_to_address(bus_to_adc_scaler, gain_ram_address + bus_test_channel, bus_test_new_gain);
            elsif cycle = 205 then
                write_data_to_address(bus_to_adc_scaler, offset_ram_address + bus_test_channel, bus_test_new_offset);
            elsif cycle = 220 then
                -- port b writes land in the same memory ada's own port a
                -- scan reads from, so channel bus_test_channel's expected
                -- value changes from here on
                expected_ada(bus_test_channel) <= integer(raw_value * bus_test_new_gain_real + bus_test_new_offset_real);
            elsif cycle = 240 then
                request_data_from_address(bus_to_adc_scaler, gain_ram_address + bus_test_channel);
            elsif cycle = 300 then
                request_data_from_address(bus_to_adc_scaler, offset_ram_address + bus_test_channel);
            end if;

            -- the readback of whichever value was last requested arrives
            -- on the address-0 reply channel : gain by cycle ~44, offset
            -- by cycle ~104
            if write_is_requested_to_address(bus_from_adc_scaler, reply_address) then
                if not bus_test_gain_done then
                    check(signed(get_slv_data(bus_from_adc_scaler)) = signed(bus_test_new_gain),
                        "gain ram port b readback mismatch, got " & integer'image(to_integer(signed(get_slv_data(bus_from_adc_scaler)))));
                    bus_test_gain_done <= true;
                else
                    check(signed(get_slv_data(bus_from_adc_scaler)) = signed(bus_test_new_offset),
                        "offset ram port b readback mismatch, got " & integer'image(to_integer(signed(get_slv_data(bus_from_adc_scaler)))));
                    bus_test_offset_done <= true;
                end if;
            end if;

        end if; -- rising_edge
    end process bus_test;
------------------------------------------------------------------------

    check_results : process(simulator_clock)
        variable channel : std_logic_vector(3 downto 0);
        variable mux_pos : integer;
        variable actual  : integer;
    begin
        if rising_edge(simulator_clock) then
            if adc_ready(adc_scale_pipeline_out) then
                channel := get_channel(adc_scale_pipeline_out);
                mux_pos := to_integer(unsigned(channel(2 downto 0)));
                actual  := to_integer(signed(get_scaled_value(adc_scale_pipeline_out)));

                if channel(3) = '1' then
                    check(actual = expected_adb(mux_pos),
                        "adb channel " & integer'image(mux_pos) & " mismatch, got " & integer'image(actual));
                else
                    check(actual = expected_ada(mux_pos),
                        "ada channel " & integer'image(mux_pos) & " mismatch, got " & integer'image(actual));
                end if;

                checked(to_integer(unsigned(channel))) <= true;
            end if;
        end if; -- rising_edge
    end process check_results;
------------------------------------------------------------------------

    -- fake ads7056 slaves : always present the same known raw code,
    -- regardless of which channel is currently being sampled
    u_ada_slave : process(ada_clock, ada_cs)
        variable shift_register : std_logic_vector(17 downto 0);
    begin
        if falling_edge(ada_cs) then
            shift_register := (17 downto 2 => raw_pattern, others => '1');
        end if;
        if rising_edge(ada_clock) then
            shift_register := shift_register(shift_register'high-1 downto 0) & '0';
        end if;
        ada_data <= shift_register(shift_register'high);
    end process;

    u_adb_slave : process(adb_clock, adb_cs)
        variable shift_register : std_logic_vector(17 downto 0);
    begin
        if falling_edge(adb_cs) then
            shift_register := (17 downto 2 => raw_pattern, others => '1');
        end if;
        if rising_edge(adb_clock) then
            shift_register := shift_register(shift_register'high-1 downto 0) & '0';
        end if;
        adb_data <= shift_register(shift_register'high);
    end process;
------------------------------------------------------------------------
    -- the two muxed_adc instances now sit alongside the DUT (as in
    -- top.vhd), feeding it only their measurement records
    u_muxed_adc_a : entity work.muxed_adc
    generic map(2, 18, 9, 20)
    port map(
        clock    => simulator_clock
        ,mux_io   => ada_mux
        ,ad_clock => ada_clock
        ,ad_cs    => ada_cs
        ,ad_data  => ada_data
        ,muxed_adc_in  => muxed_adc_a_in
        ,muxed_adc_out => muxed_adc_a_out
    );

    u_muxed_adc_b : entity work.muxed_adc
    generic map(2, 18, 9, 20)
    port map(
        clock    => simulator_clock
        ,mux_io   => adb_mux
        ,ad_clock => adb_clock
        ,ad_cs    => adb_cs
        ,ad_data  => adb_data
        ,muxed_adc_in  => muxed_adc_b_in
        ,muxed_adc_out => muxed_adc_b_out
    );

------------------------------------------------------------------------

    u_adc_scale_pipeline : entity work.adc_scale_pipeline
    generic map(
        g_radix => scaler_radix
        ,g_gain_ram_address   => gain_ram_address
        ,g_offset_ram_address => offset_ram_address
    )
    port map(
        clock    => simulator_clock
        ,bus_to_adc_scaler   => bus_to_adc_scaler
        ,bus_from_adc_scaler => bus_from_adc_scaler
        ,muxed_adc_a_out => muxed_adc_a_out
        ,muxed_adc_b_out => muxed_adc_b_out
        ,adc_scale_pipeline_out => adc_scale_pipeline_out
        ,dbg_a         => open
        ,dbg_b         => open
        ,dbg_result_or => open
    );
------------------------------------------------------------------------
end vunit_simulation;
