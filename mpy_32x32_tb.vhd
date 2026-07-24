
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity mpy_32x32_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of mpy_32x32_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 15;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;

    ----------
    -- signal a : signed(31 downto 0) := others => '0')
    use work.real_to_fixed_pkg.all;

    function to_fixed is new generic_to_fixed generic map(word_length => 32, used_radix => 20);

    signal a : std_logic_vector(31 downto 0) :=to_fixed(1.0);
    signal b : std_logic_vector(31 downto 0) :=to_fixed(1.0);
    signal result : std_logic_vector(63 downto 0);

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
            CASE simulation_counter is
                WHEN 0 => 
                    a <= to_fixed(1.0);
                    b <= to_fixed(-1.0);
                WHEN 1 => 
                    a <= to_fixed(-2.0);
                    b <= to_fixed(-1.0);
                WHEN others => -- do nothing
            end CASE;
        end if; -- rising_edge
    end process stimulus;	

    u_mpy32x32 : entity work.mpy_32x32
    port map(
        clock => simulator_clock
        ,ClkEn => '1'
        ,Aclr => '0'
        ,DataA => a
        ,DataB => b
        ,Result => result
    );

end vunit_simulation;
