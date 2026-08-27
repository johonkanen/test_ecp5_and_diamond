LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;
    use ieee.math_real.all;

    use work.fixed_dsp_pkg.all;
    use work.lut_sqrt_pkg.all;
    use work.sqrt_calculator_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;

-- validates sqrt_calculator against the actual ECP5-targeted fixed_dsp
-- build (entity fixed_dsp, architecture ecp5, which uses the mpy_32x32
-- hard IP -- stood in for here by sim_mpy32x32.vhd, same as
-- arch_ecp_dsp_instruction.vhd does). mpy_32x32 is a fixed 32x32
-- multiplier, wider than lut_sqrt_pkg's own 16-bit sqrt_word_length ;
-- sqrt_calculator resizes its operands up to whatever width fixed_dsp_in
-- actually has, so driving it with a wider dsp than its own lut tables
-- just works.
--
-- with use_gaps = false, a new x_frac is requested every clock cycle
-- without ever waiting for the previous request to complete ; with
-- use_gaps = true, requests are instead issued in irregular bursts with
-- idle cycles in between, to prove the pipeline also tracks in-flight
-- requests correctly when it is not kept saturated
entity sqrt_calculator_tb is
    generic (
        runner_cfg : string
        ;use_gaps : boolean := false
    );
end;

architecture sim of sqrt_calculator_tb is

    signal simulator_clock : std_logic := '0';
    constant clock_period : time := 1 ns;
    -- a full sweep of every x_frac ; the gapped run needs extra cycles
    -- for its idle gaps, plus a little margin for the pipeline to drain,
    -- so reserve enough for that regardless of which mode is running
    constant simtime_in_clocks : integer := 2*2**sqrt_word_length + 20;
------------------------------------------------------------------------

    signal sqrt_calculator_in  : sqrt_calculator_in_record;
    signal sqrt_calculator_out : sqrt_calculator_out_record;

    -- fixed_dsp lives outside sqrt_calculator ; instantiated here (with
    -- the ecp5 architecture, native to mpy_32x32's 32x32 width -- wider
    -- than sqrt_word_length) and wired straight to its ports
    constant dsp_word_length : natural := 32;

    signal fixed_dsp_in  : fixed_dsp_in_record(
        a(dsp_word_length-1 downto 0)
        ,d(dsp_word_length-1 downto 0)
        ,b(dsp_word_length-1 downto 0)
        ,c(2*dsp_word_length-1 downto 0)
    );
    signal fixed_dsp_out : fixed_dsp_out_record(
        result(2*dsp_word_length-1 downto 0)
    );

    signal test_x_frac : unsigned(sqrt_word_length-1 downto 0) := (others => '0');

    -- an arbitrary, irregular issue/idle pattern (not a simple period-2
    -- toggle) : bursts of 1-2 requests followed by 1-2 idle cycles
    constant gap_pattern : std_logic_vector(0 to 6) := "1101001";
    signal pattern_index : natural range 0 to gap_pattern'length-1 := 0;

    -- requests are issued in strict order (whether back-to-back or with
    -- gaps in between), and sqrt_calculator neither stalls nor reorders,
    -- so the k'th result it produces always belongs to the k'th x_frac
    -- requested -- no need to know its latency
    signal result_count : unsigned(sqrt_word_length-1 downto 0) := (others => '0');

    signal all_tests_done : boolean := false;
    constant tolerance : real := 0.001;
------------------------------------------------------------------------
begin

------------------------------------------------------------------------
    u_fixed_dsp : entity work.fixed_dsp(ecp5)
    port map(
        clock => simulator_clock
        ,fixed_dsp_in  => fixed_dsp_in
        ,fixed_dsp_out => fixed_dsp_out
    );

    u_sqrt_calculator : entity work.sqrt_calculator
    port map(
        clock => simulator_clock
        ,sqrt_calculator_in  => sqrt_calculator_in
        ,sqrt_calculator_out => sqrt_calculator_out
        ,fixed_dsp_in  => fixed_dsp_in
        ,fixed_dsp_out => fixed_dsp_out
    );
------------------------------------------------------------------------

    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        check(all_tests_done, "sqrt_calculator sweep did not complete");
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus_and_check : process(simulator_clock)
        variable x             : real;
        variable expected      : unsigned(sqrt_word_length-1 downto 0);
        variable expected_real : real;
        variable actual_real   : real;
        variable issue_now     : boolean;
    begin
        if rising_edge(simulator_clock) then

            -- request a new x_frac either every single cycle, or (with
            -- use_gaps) only on the cycles the gap pattern marks as active
            init_sqrt_calculator(sqrt_calculator_in);

            issue_now := (not use_gaps) or (gap_pattern(pattern_index) = '1');
            if issue_now then
                request_sqrt(sqrt_calculator_in, test_x_frac);
                test_x_frac <= test_x_frac + 1;
            end if;
            pattern_index <= (pattern_index + 1) mod gap_pattern'length;

            if sqrt_calculator_out.ready_with_1 = '1' then
                expected := get_sqrt_from_lut(result_count);

                check(sqrt_calculator_out.y = expected,
                    "sqrt_calculator mismatch at x_frac " & natural'image(to_integer(result_count)));

                x             := 0.5 * (1.0 + real(to_integer(result_count))/real(2**sqrt_word_length));
                expected_real := sqrt(x);
                actual_real   := real(to_integer(sqrt_calculator_out.y))/(2.0**(sqrt_word_length-1)-1.0);
                check(abs(actual_real - expected_real) < tolerance,
                    "sqrt error too large at x_frac " & natural'image(to_integer(result_count)));

                if result_count = 2**sqrt_word_length - 1 then
                    all_tests_done <= true;
                end if;
                result_count <= result_count + 1;
            end if;

        end if; -- rising_edge
    end process stimulus_and_check;
------------------------------------------------------------------------
end sim;
