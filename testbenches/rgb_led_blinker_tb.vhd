LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

library vunit_lib;
context vunit_lib.vunit_context;

-- clocked testbench for the rgb_led module (rgb_led.vhd), which wraps the
-- "heartbeat + pwm" behaviour that used to live as two inline processes
-- in top.vhd (top.vhd:388-443).
--
-- the module gives each of the three rgb-led ios its own pwm : one shared
-- counter free-runs 0..g_pwm_max and channel i is high while it is below
-- pwm_thresholds(i), so channel i's duty is
-- pwm_thresholds(i)/(g_pwm_max+1). the thresholds are ports (bus
-- registers in top.vhd). on top of its pwm, the g_active_bit colour is
-- also OR'd with a slow heartbeat toggle that flips every
-- g_blink_half_period+1 clocks.
--
-- top.vhd uses 60e6 / 2**15 sized counters ; this testbench takes the
-- sizes as generics so the sim runs in microseconds. it keeps an
-- independent behavioural reference model and verifies :
--   1. the reference heartbeat toggles every g_blink_half_period+1 clocks
--   2. every reference pwm channel is high for exactly
--      min(threshold, g_pwm_max+1) clocks out of each g_pwm_max+1
--   3. the reference led vector is
--      (active_bit => heartbeat or pwm, others => pwm)
--   4. the rgb_led module's output matches the reference model every clock
entity rgb_led_blinker_tb is
    generic (
        runner_cfg          : string;
        g_blink_half_period : natural := 1000;  -- stands in for 60e6 / 120e6
        g_pwm_max           : natural := 255;   -- stands in for 2**15-1
        -- one threshold per rgb-led io ; stand in for test_data5/6/...(15 downto 0)
        g_pwm_threshold_0   : natural := 100;
        g_pwm_threshold_1   : natural := 256;
        g_pwm_threshold_2   : natural := 256;
        g_active_bit        : natural := 0     -- which colour also gets the heartbeat
    );
end;

architecture vunit_simulation of rgb_led_blinker_tb is

    constant clock_period      : time    := 1 ns;
    -- enough for several heartbeat toggles and many pwm periods
    constant simtime_in_clocks : natural := 6*(g_blink_half_period+1) + 10;

    type nat3 is array (0 to 2) of natural;

    constant pwm_thresholds : integer_vector(0 to 2) :=
        (g_pwm_threshold_0, g_pwm_threshold_1, g_pwm_threshold_2);

    -- expected number of high clocks in one pwm period, per channel
    constant expected_pwm_high : nat3 := (
        0 => minimum(g_pwm_threshold_0, g_pwm_max + 1),
        1 => minimum(g_pwm_threshold_1, g_pwm_max + 1),
        2 => minimum(g_pwm_threshold_2, g_pwm_max + 1));

    signal simulator_clock : std_logic := '0';

    -- independent reference model registers, mirroring top.vhd's signals
    signal blink_counter : natural range 0 to g_blink_half_period := 0;
    signal led_buffer    : std_logic := '0';
    signal pwm_counter   : natural range 0 to g_pwm_max := 0;
    signal pwm           : std_logic_vector(2 downto 0) := (others => '0');

    signal ref_rgb_led : std_logic_vector(2 downto 0);
    signal dut_rgb_led : std_logic_vector(2 downto 0);

    -- checker bookkeeping, read back in the simtime process
    signal blink_toggles      : natural := 0;
    signal pwm_periods_checked : natural := 0;
    signal equivalence_checks  : natural := 0;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;

        check(blink_toggles >= 4,
            "heartbeat never toggled enough times to be verified, saw "
            & integer'image(blink_toggles));
        check(pwm_periods_checked >= 8,
            "not enough complete pwm periods were observed, saw "
            & integer'image(pwm_periods_checked));
        check(equivalence_checks >= simtime_in_clocks - 5,
            "rgb_led module was not compared against the reference every clock");

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    -- device under test : the real module
    u_dut : entity work.rgb_led
    generic map (
        g_blink_half_period => g_blink_half_period
        ,g_pwm_max          => g_pwm_max
        ,g_active_bit        => g_active_bit
    )
    port map (
        clock          => simulator_clock
        ,pwm_thresholds => pwm_thresholds
        ,rgb_led        => dut_rgb_led
    );

------------------------------------------------------------------------
    -- reference model : identical in structure to the clocked body of
    -- both rgb-led processes in top.vhd, extended to one pwm per channel
    -- and kept separate from the DUT so the two can be compared
    reference_model : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then

            if blink_counter < g_blink_half_period then
                blink_counter <= blink_counter + 1;
            else
                blink_counter <= 0;
            end if;

            if blink_counter = 0 then
                led_buffer <= not led_buffer;
            end if;

            if pwm_counter < g_pwm_max then
                pwm_counter <= pwm_counter + 1;
            else
                pwm_counter <= 0;
            end if;

            for i in pwm'range loop
                if pwm_counter < pwm_thresholds(i) then
                    pwm(i) <= '1';
                else
                    pwm(i) <= '0';
                end if;
            end loop;

        end if; -- rising_edge
    end process reference_model;

    -- (active_bit => led_buffer or pwm, others => pwm) ; driven per bit
    -- because a named non-static choice with 'others' is illegal
    drive_ref_rgb_led : for i in ref_rgb_led'range generate
        ref_rgb_led(i) <= (led_buffer or pwm(i)) when i = g_active_bit
                          else pwm(i);
    end generate;

------------------------------------------------------------------------
    -- 1. heartbeat toggles exactly every g_blink_half_period+1 clocks
    check_blink : process(simulator_clock)
        variable clocks_since_toggle : natural   := 0;
        variable prev_buffer         : std_logic := '0';
        variable toggle_count        : natural   := 0;
    begin
        if rising_edge(simulator_clock) then
            clocks_since_toggle := clocks_since_toggle + 1;

            if led_buffer /= prev_buffer then
                -- skip the very first toggle : its lead-in isn't a full period
                if toggle_count > 0 then
                    check_equal(clocks_since_toggle, g_blink_half_period + 1,
                        "heartbeat half-period mismatch");
                end if;
                toggle_count        := toggle_count + 1;
                clocks_since_toggle := 0;
                prev_buffer         := led_buffer;
                blink_toggles       <= toggle_count;
            end if;
        end if;
    end process check_blink;

------------------------------------------------------------------------
    -- 2. every pwm channel is high for exactly expected_pwm_high(i) clocks
    -- per period. pwm is periodic with period g_pwm_max+1 regardless of
    -- phase, so any window of that many consecutive clocks carries the
    -- same on-time ; measuring over a fixed count (rather than aligning
    -- to pwm_counter=0) sidesteps the one-clock register lag between
    -- pwm_counter and pwm. the first window is skipped as warm-up.
    check_pwm : process(simulator_clock)
        variable high_count   : nat3    := (others => 0);
        variable sample_count : natural := 0;
        variable warmed_up    : boolean := false;
        variable periods      : natural := 0;
    begin
        if rising_edge(simulator_clock) then
            sample_count := sample_count + 1;
            for i in 0 to 2 loop
                if pwm(i) = '1' then
                    high_count(i) := high_count(i) + 1;
                end if;
            end loop;

            if sample_count = g_pwm_max + 1 then
                if warmed_up then
                    for i in 0 to 2 loop
                        check_equal(high_count(i), expected_pwm_high(i),
                            "pwm channel " & integer'image(i)
                            & " on-time (duty) mismatch");
                    end loop;
                    periods            := periods + 1;
                    pwm_periods_checked <= periods;
                end if;
                warmed_up    := true;
                high_count   := (others => 0);
                sample_count := 0;
            end if;
        end if;
    end process check_pwm;

------------------------------------------------------------------------
    -- 3. reference led vector : active colour = heartbeat or its pwm, the
    -- other two colours = their own pwm
    check_ref_output : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then
            for i in ref_rgb_led'range loop
                if i = g_active_bit then
                    check(ref_rgb_led(i) = (led_buffer or pwm(i)),
                        "active rgb-led channel not driven by heartbeat or its pwm");
                else
                    check(ref_rgb_led(i) = pwm(i),
                        "inactive rgb-led channel not driven by its own pwm");
                end if;
            end loop;
        end if;
    end process check_ref_output;

------------------------------------------------------------------------
    -- 4. the module tracks the reference model exactly, every clock
    check_equivalence : process(simulator_clock)
        variable checks : natural := 0;
    begin
        if rising_edge(simulator_clock) then
            check_equal(dut_rgb_led, ref_rgb_led,
                "rgb_led module output differs from the reference model");
            checks             := checks + 1;
            equivalence_checks <= checks;
        end if;
    end process check_equivalence;
------------------------------------------------------------------------
end vunit_simulation;
