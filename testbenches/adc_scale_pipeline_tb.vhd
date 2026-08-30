LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

    use work.dual_port_ram_pkg.all;
    use work.muxed_adc_pkg.all;
    use work.adc_scale_pipeline_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;

-- validates adc_scale_pipeline end to end : both muxed adcs continuously
-- round-robin their 8 channels, each channel's gain/offset is looked up
-- from that adc's own dpram and applied via the shared fixed_dsp's fmac
-- (scaled = raw*gain + offset), and the result comes back tagged with
-- the right one of the 16 channels.
--
-- both fake ads7056 slaves (u_ada_slave/u_adb_slave, the same
-- falling_edge(ad_cs)-loads / rising_edge(ad_clock)-shifts loopback
-- technique used by testbenches/ads7056_entity_tb.vhd and
-- testbenches/muxed_adc_tb.vhd) always present the same known raw code
-- regardless of which channel is being sampled -- muxed_adc's own
-- mux-position tagging was already verified bit-exactly in
-- muxed_adc_tb.vhd, so this testbench trusts whichever channel
-- adc_scale_pipeline reports and checks only what it is responsible for :
-- that channel's gain/offset lookup and fmac scaling. raw and every gain
-- are chosen so the fixed-point math has no rounding to worry about
-- (raw = 2**14, every gain a multiple of 2, so raw*gain is always an
-- exact multiple of 2**radix), so the expected results below are exact.
entity adc_scale_pipeline_tb is
    generic (runner_cfg : string);
end;

architecture vunit_simulation of adc_scale_pipeline_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 3000;

    -- adc_scale_pipeline no longer sequences channels itself (the caller
    -- drives muxed_adc_a_in/muxed_adc_b_in directly now, and can no
    -- longer see muxed_adc's own ready/mux tag to pace off of, since
    -- that record stays entirely internal to adc_scale_pipeline) ; a
    -- fixed period, generous versus one conversion + ram lookup +
    -- arbitration, keeps this simple and correct without needing that
    -- visibility, matching testbenches/muxed_adc_tb.vhd's own approach
    constant trigger_period : natural := 80;

    constant raw_pattern : std_logic_vector(15 downto 0) := x"4000"; -- 16384 = 2**14

    -- address 0..7 = ada's channels 0..7, address 8..15 = adb's
    -- ada : gain(ch) = (ch+1)*2000, offset(ch) = (ch+1)*100
    -- adb : gain(ch) = (ch+1)*3000, offset(ch) = (ch-4)*500 (includes
    -- negative offsets, so the pipeline's sign handling gets exercised too)
    -- expected(ch) = gain(ch)/2 + offset(ch)
    constant gain_values : work.dual_port_ram_pkg.ram_array(0 to 15)(15 downto 0) := (
        0  => std_logic_vector(to_signed(2000,  16)), 1  => std_logic_vector(to_signed(4000,  16))
        ,2  => std_logic_vector(to_signed(6000,  16)), 3  => std_logic_vector(to_signed(8000,  16))
        ,4  => std_logic_vector(to_signed(10000, 16)), 5  => std_logic_vector(to_signed(12000, 16))
        ,6  => std_logic_vector(to_signed(14000, 16)), 7  => std_logic_vector(to_signed(16000, 16))
        ,8  => std_logic_vector(to_signed(3000,  16)), 9  => std_logic_vector(to_signed(6000,  16))
        ,10 => std_logic_vector(to_signed(9000,  16)), 11 => std_logic_vector(to_signed(12000, 16))
        ,12 => std_logic_vector(to_signed(15000, 16)), 13 => std_logic_vector(to_signed(18000, 16))
        ,14 => std_logic_vector(to_signed(21000, 16)), 15 => std_logic_vector(to_signed(24000, 16))
    );

    constant offset_values : work.dual_port_ram_pkg.ram_array(0 to 15)(15 downto 0) := (
        0  => std_logic_vector(to_signed(100, 16)), 1  => std_logic_vector(to_signed(200, 16))
        ,2  => std_logic_vector(to_signed(300, 16)), 3  => std_logic_vector(to_signed(400, 16))
        ,4  => std_logic_vector(to_signed(500, 16)), 5  => std_logic_vector(to_signed(600, 16))
        ,6  => std_logic_vector(to_signed(700, 16)), 7  => std_logic_vector(to_signed(800, 16))
        ,8  => std_logic_vector(to_signed(-2000, 16)), 9  => std_logic_vector(to_signed(-1500, 16))
        ,10 => std_logic_vector(to_signed(-1000, 16)), 11 => std_logic_vector(to_signed(-500,  16))
        ,12 => std_logic_vector(to_signed(0,     16)), 13 => std_logic_vector(to_signed(500,   16))
        ,14 => std_logic_vector(to_signed(1000,  16)), 15 => std_logic_vector(to_signed(1500,  16))
    );

    type expected_array is array (0 to 7) of integer;
    constant expected_ada : expected_array := (1100, 2200, 3300, 4400, 5500, 6600, 7700, 8800);
    constant expected_adb : expected_array := (-500, 1500, 3500, 5500, 7500, 9500, 11500, 13500);

    type checked_array is array (0 to 15) of boolean;
    signal checked : checked_array := (others => false);

    signal simulator_clock : std_logic := '0';

    signal ada_mux   : std_logic_vector(2 downto 0);
    signal ada_clock : std_logic;
    signal ada_cs    : std_logic;
    signal ada_data  : std_logic := '1';

    signal adb_mux   : std_logic_vector(2 downto 0);
    signal adb_clock : std_logic;
    signal adb_cs    : std_logic;
    signal adb_data  : std_logic := '1';

    signal muxed_adc_a_in : muxed_adc_in_record := init_muxed_adc_in;
    signal muxed_adc_b_in : muxed_adc_in_record := init_muxed_adc_in;

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

    u_adc_scale_pipeline : entity work.adc_scale_pipeline
    generic map(
        g_radix => 15
        ,g_u8_clk_cnt => 2
        ,g_u8_clks_per_conversion => 18
        ,g_sh_counter_latch => 9
        ,g_mux_switch_delay_in_clocks => 20
        ,g_gain_values   => gain_values
        ,g_offset_values => offset_values
    )
    port map(
        clock    => simulator_clock
        ,ada_mux   => ada_mux
        ,ada_clock => ada_clock
        ,ada_cs    => ada_cs
        ,ada_data  => ada_data
        ,adb_mux   => adb_mux
        ,adb_clock => adb_clock
        ,adb_cs    => adb_cs
        ,adb_data  => adb_data
        ,muxed_adc_a_in => muxed_adc_a_in
        ,muxed_adc_b_in => muxed_adc_b_in
        ,bus_to_adc_scaler   => bus_to_adc_scaler  
        ,bus_from_adc_scaler => bus_from_adc_scaler
        ,adc_scale_pipeline_out => adc_scale_pipeline_out
    );
------------------------------------------------------------------------
end vunit_simulation;
