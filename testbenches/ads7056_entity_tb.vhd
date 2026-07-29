
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity ads7056_entity_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of ads7056_entity_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 5000;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    signal clock_counter    : natural := 0;
    signal number_of_clocks : natural range 0 to 63;

    signal ad_clock : std_logic := '1';
    signal ad_data : std_logic := '1';
    signal ad_cs : std_logic := '1';

    --- module signals

    signal start_conversion_w_1 : std_logic := '0';
    signal shift_register : std_logic_vector(17 downto 0);
    signal clock_divider : natural := 0;
    type t_adc_states is (idle, convert, output, calibrate);
    signal adc_state : t_adc_states := idle;
    signal c_adc_state : t_adc_states := idle;
    signal clock : std_logic;

    signal edge_counter : natural := 0;
    signal ad_conversion : std_logic_vector(15 downto 0);


    type ads7056_record is record
        spi_cs : std_logic;
        spi_clock : std_logic;
    end record;

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

    stimulus : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            start_conversion_w_1 <= '0';
            CASE simulation_counter is
                WHEN 15  => start_conversion_w_1 <= '1';
                WHEN 200 => start_conversion_w_1 <= '1';
                WHEN 330 => start_conversion_w_1 <= '1';
                WHEN others => --do nothing
            end CASE; --simulation_counter

        end if; -- rising_edge
    end process stimulus;	

    clock <= simulator_clock;
------------------------------------------------------------------------
------------------------------------------------------------------------
    u_ad_conversion : process(ad_clock, ad_cs) is
    begin
        if falling_edge(ad_cs) then
            shift_register <= (17 downto 2 => x"acdc", others => '1');
        end if;

        if rising_edge(ad_clock) then
            shift_register <= shift_register(shift_register'high -1 downto 0) & '0';
        end if;
    end process; 
    
    ad_data <= shift_register(shift_register'high);

    u_ads7056 : entity work.spi3w_ads7056_driver
    generic map(2, 18, 9)
    port map(
    simulator_clock
    ,'1'
    ,ad_cs
    ,ad_clock
    ,ad_data
    ,start_conversion_w_1
    ,open
    ,open
    ,open
    ,ad_conversion
    );

------------------------------------------------------------------------
end vunit_simulation;
