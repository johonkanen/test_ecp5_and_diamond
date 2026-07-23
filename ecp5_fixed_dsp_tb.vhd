
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity ecp5_fixed_dsp_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of ecp5_fixed_dsp_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 15;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;

    ----------
    -- signal a : signed(31 downto 0) := others => '0')
    use work.real_to_fixed_pkg.all;

    function to_fixed (a : real) return signed is
        variable retval : signed(31 downto 0);
    begin
        retval := to_fixed(a, 32, 20);

        return retval;

    end function;

    signal a : signed(31 downto 0) :=to_fixed(1.0);
    signal b : signed(31 downto 0) :=to_fixed(1.0);
    signal c : signed(31 downto 0) :=to_fixed(1.0);
    signal d : signed(31 downto 0) :=to_fixed(1.0);
    signal result : signed(63 downto 0);

    -- (a +/- d) * b +/- c
    signal accumulate_with_1 : std_logic := '0';
    signal ready : std_logic := '0';

    signal request_with_1 : std_logic := '0';

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;

------------------------------------------------------------------------
------------------------------------------------------------------------
    stimulus : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            a <= to_fixed(0.0);
            b <= to_fixed(0.0);
            d <= to_fixed(0.0);
            c <= to_fixed(0.0);
            request_with_1 <= '0';
            CASE simulation_counter is
                WHEN 2 => 
                    a <= to_fixed(1.0);
                    b <= to_fixed(1.0);
                    d <= to_fixed(0.0);
                    accumulate_with_1 <= '1';
                    request_with_1 <= '1';
                WHEN 3 => 
                    a <= to_fixed(1.0);
                    b <= to_fixed(1.0);
                    d <= to_fixed(1.0);
                    accumulate_with_1 <= '1';
                    request_with_1 <= '1';
                WHEN 5 => 
                    a <= to_fixed(1.0);
                    b <= to_fixed(1.0);
                    d <= to_fixed(0.0);
                    c <= to_fixed(1.0);
                    accumulate_with_1 <= '1';
                    request_with_1 <= '1';
                WHEN others => -- do nothing
                    accumulate_with_1 <= '0';
            end CASE;
        end if; -- rising_edge
    end process stimulus;	

    u_ecp5_fixed_dsp : entity work.ecp5_fixed_dsp
    generic map(g_radix => 20)
    port map(
        clock => simulator_clock
        ,fixed_dsp_in.a => a
        ,fixed_dsp_in.d => d
        ,fixed_dsp_in.b => b
        ,fixed_dsp_in.c => c

        ,fixed_dsp_in.request_with_1       => request_with_1
        ,fixed_dsp_in.accumulate_with_1    => accumulate_with_1
        ,fixed_dsp_in.pre_subtract_with_1  => '0'
        ,fixed_dsp_in.post_subtract_with_1 => '0'
        ,fixed_dsp_in.invert_result_with_1 => '0'
        ,fixed_dsp_in.reset_accumulator_with_1 => '0'

        ,ready_with_1 => ready
        ,result       => result
    );

end vunit_simulation;
