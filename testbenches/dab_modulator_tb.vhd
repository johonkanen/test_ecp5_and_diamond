
----------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;
    use std.textio.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity dab_modulator_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of dab_modulator_tb is

    constant clock_period : time := 1 ns;
    
    signal simulator_clock    : std_logic := '0';
    signal simulation_counter : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    signal realtime : real := 0.0;

    --- module signals
    signal dab_carrier : natural := 0;
    signal dab_pwm : std_logic_vector(1 downto 0) := "00";
    signal phase_shift : integer := 10;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait until simulation_counter >= 10000;
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------
    -- 00 => 01 => 11 => 10

    stimulus : process(simulator_clock)


    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            CASE simulation_counter is
                WHEN 540 => phase_shift <= 3;
                WHEN others => -- do nothing
            end CASE;

            dab_carrier <= dab_carrier + 1;
            if dab_carrier > 199 then
                dab_carrier <= 0;
            end if;

            if dab_carrier = 0   + phase_shift then dab_pwm <= "11"; end if;
            if dab_carrier = 99  - phase_shift then dab_pwm <= "10"; end if;
            if dab_carrier = 100 + phase_shift then dab_pwm <= "00"; end if;
            if dab_carrier = 199 - phase_shift then dab_pwm <= "01"; end if;


        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
