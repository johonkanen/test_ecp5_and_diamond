LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

    use work.muxed_adc_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;

-- validates muxed_adc's 1 measurement cycle pipeline delay : a trigger
-- both starts a conversion and sets the mux position for the *next* one,
-- so the measurement it produces must be tagged with whichever mux
-- position was requested one trigger earlier, not the one just requested.
--
-- a fake ads7056 slave (u_ad_slave, the same falling_edge(ad_cs)-loads /
-- rising_edge(ad_clock)-shifts loopback technique used by
-- testbenches/ads7056_entity_tb.vhd) presents a known 16 bit pattern per
-- mux position, so both the measurement value and its mux tag can be
-- checked bit-exactly against what the testbench expects, tracked
-- independently of the dut in pending_tag/shadow_current_mux_pos
entity muxed_adc_tb is
    generic (runner_cfg : string);
end;

architecture vunit_simulation of muxed_adc_tb is

    constant clock_period      : time    := 1 ns;

    -- generics matching top.vhd's real ada/adb instances ; worst case
    -- (including the one-off startup calibration) completes well within
    -- 80 cycles, so an 80 cycle trigger period leaves generous margin
    constant g_u8_clk_cnt             : integer := 2;
    constant g_u8_clks_per_conversion : integer := 18;
    constant g_sh_counter_latch       : integer := 9;
    constant g_mux_switch_delay_in_clocks : natural := 20;

    constant trigger_period    : natural := 80;
    constant num_triggers      : natural := 20;
    -- +2 periods of margin : one for the initial calibration delay before
    -- the first trigger is even issued, one for the last conversion to drain
    constant simtime_in_clocks : integer := trigger_period*(num_triggers+2);

    type pattern_array is array (0 to 7) of std_logic_vector(15 downto 0);
    constant expected_pattern : pattern_array := (
        x"1001", x"2002", x"3003", x"4004", x"5005", x"6006", x"7007", x"8008");

    signal simulator_clock : std_logic := '0';

    signal ad_clock : std_logic;
    signal ad_data  : std_logic := '1';
    signal ad_cs    : std_logic;
    signal mux_io   : std_logic_vector(2 downto 0);

    signal muxed_adc_in  : muxed_adc_in_record := init_muxed_adc_in;
    signal muxed_adc_out : muxed_adc_out_record;

    -- offset by 1 (not 0) so the first trigger_counter=0 event lands near
    -- the end of the first period, well after the dut's own startup
    -- calibration has finished, instead of racing it at simulation time 0
    signal trigger_counter : natural range 0 to trigger_period-1 := 1;
    signal trigger_count   : natural := 0;
    signal next_mux_pos    : std_logic_vector(2 downto 0) := (others => '0');

    -- mirrors muxed_adc's own current_mux_pos/converted_mux_pos bookkeeping,
    -- computed independently here so the checks below aren't just comparing
    -- the dut against itself
    signal shadow_current_mux_pos : std_logic_vector(2 downto 0) := (others => '0');
    signal pending_tag            : std_logic_vector(2 downto 0) := (others => '0');

    -- mux_io's value just before the most recent trigger, so its checks
    -- below can confirm the switch really is delayed, not immediate
    signal mux_io_before_trigger : std_logic_vector(2 downto 0) := (others => '0');
    -- highest trigger_count the delay checks have already run for, so a
    -- free-running trigger_counter wrap after the last real trigger can't
    -- spuriously re-trigger them against now-stale expected values
    signal delay_checked_for_trigger : natural := 0;

    -- requests are issued in strict order and never reordered (only one
    -- conversion is ever in flight at a time), so the k'th ready pulse
    -- always belongs to the k'th trigger issued -- no latency bookkeeping
    -- beyond the single one-trigger-deep pending_tag above is needed
    signal result_count   : natural := 0;
    signal all_tests_done : boolean := false;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        check(all_tests_done, "muxed_adc pipeline test did not complete");
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus_and_check : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then

            init_muxed_adc(muxed_adc_in);

            if trigger_counter < trigger_period-1 then
                trigger_counter <= trigger_counter + 1;
            else
                trigger_counter <= 0;
            end if;

            if trigger_counter = 0 and trigger_count < num_triggers then
                request_measurement(muxed_adc_in, next_mux_pos);

                mux_io_before_trigger  <= mux_io;
                pending_tag            <= shadow_current_mux_pos;
                shadow_current_mux_pos <= next_mux_pos;
                next_mux_pos           <= std_logic_vector(unsigned(next_mux_pos) + 1);
                trigger_count          <= trigger_count + 1;
            end if;

            -- mux_io must still hold its pre-trigger value this close to (but
            -- before) the configured deadline -- proves the switch is tied to
            -- g_mux_switch_delay_in_clocks, not immediate or hardcoded shorter.
            -- guarded on delay_checked_for_trigger so this only ever evaluates
            -- once per real trigger -- trigger_counter keeps free-running
            -- with no new trigger once num_triggers is reached, which would
            -- otherwise make a stale comparison here spurious
            if trigger_counter = g_mux_switch_delay_in_clocks - 5 and trigger_count > 0
                and delay_checked_for_trigger < trigger_count
            then
                check(mux_io = mux_io_before_trigger,
                    "mux_io switched before the configured delay elapsed, trigger " & natural'image(trigger_count));
            end if;

            -- ...but must have reached the newly requested position well
            -- before the delay's deadline (with margin to spare)
            if trigger_counter = g_mux_switch_delay_in_clocks + 5 and trigger_count > 0
                and delay_checked_for_trigger < trigger_count
            then
                check(mux_io = shadow_current_mux_pos,
                    "mux_io did not switch within the configured delay, trigger " & natural'image(trigger_count));
                delay_checked_for_trigger <= trigger_count;
            end if;

            if adc_ready(muxed_adc_out) then
                check(get_sampled_mux_pos(muxed_adc_out) = pending_tag,
                    "mux tag mismatch at result " & natural'image(result_count));
                check(get_adc_result(muxed_adc_out) = expected_pattern(to_integer(unsigned(pending_tag))),
                    "measurement mismatch at result " & natural'image(result_count));

                if result_count = num_triggers-1 then
                    all_tests_done <= true;
                end if;
                result_count <= result_count + 1;
            end if;

        end if; -- rising_edge
    end process stimulus_and_check;
------------------------------------------------------------------------

    -- fake ads7056 slave : loads the pattern expected for whichever mux
    -- position the testbench believes is active (pending_tag) the moment
    -- cs falls, then shifts it out msb-first on every spi clock edge
    u_ad_slave : process(ad_clock, ad_cs)
        variable shift_register : std_logic_vector(17 downto 0);
    begin
        if falling_edge(ad_cs) then
            shift_register := (17 downto 2 => expected_pattern(to_integer(unsigned(pending_tag))), others => '1');
        end if;

        if rising_edge(ad_clock) then
            shift_register := shift_register(shift_register'high-1 downto 0) & '0';
        end if;

        ad_data <= shift_register(shift_register'high);
    end process;
------------------------------------------------------------------------

    u_muxed_adc : entity work.muxed_adc
    generic map(g_u8_clk_cnt, g_u8_clks_per_conversion, g_sh_counter_latch, g_mux_switch_delay_in_clocks)
    port map(
        clock    => simulator_clock
        ,mux_io  => mux_io
        ,ad_clock => ad_clock
        ,ad_cs    => ad_cs
        ,ad_data  => ad_data
        ,muxed_adc_in  => muxed_adc_in
        ,muxed_adc_out => muxed_adc_out
    );
------------------------------------------------------------------------
end vunit_simulation;
