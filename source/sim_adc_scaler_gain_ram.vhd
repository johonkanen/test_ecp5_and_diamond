-- Behavioural stand-in for the Lattice RAM_DP IP core
-- ip/main_clocks/adc_scaler_gain_ram : 512 x 32, one write port + one
-- read port, 2-cycle registered read (RdAddress -> Q : address register
-- + OUTREG). Power-up contents match ip/adc_scaler_gain_ram_init.mem :
-- every word = 0x000336D5 (default gain 210645, radix 20 -> +0.20089).
-- Regenerate that .mem AND update the init here together if the default
-- calibration changes.
--
-- Same entity name as the SCUBA netlist so adc_scale_pipeline can
-- instantiate `entity work.adc_scaler_gain_ram` in both flows (the real
-- netlist comes in via ip/main_clocks/main_clocks.sbx in the Diamond
-- build ; this file is added only to the VUnit build).
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity adc_scaler_gain_ram is
    port (
        WrAddress : in  std_logic_vector(8 downto 0);
        RdAddress : in  std_logic_vector(8 downto 0);
        Data      : in  std_logic_vector(31 downto 0);
        WE        : in  std_logic;
        RdClock   : in  std_logic;
        RdClockEn : in  std_logic;
        Reset     : in  std_logic;
        WrClock   : in  std_logic;
        WrClockEn : in  std_logic;
        Q         : out std_logic_vector(31 downto 0)
    );
end entity;

architecture sim of adc_scaler_gain_ram is
    type mem_t is array (0 to 511) of std_logic_vector(31 downto 0);
    signal mem   : mem_t := (others => x"000336D5");
    signal q_reg : std_logic_vector(31 downto 0) := (others => '0');
begin

    write_port : process(WrClock)
    begin
        if rising_edge(WrClock) then
            if WrClockEn = '1' and WE = '1' then
                mem(to_integer(unsigned(WrAddress))) <= Data;
            end if;
        end if;
    end process;

    read_port : process(RdClock)
    begin
        if rising_edge(RdClock) then
            if RdClockEn = '1' then
                q_reg <= mem(to_integer(unsigned(RdAddress)));  -- address register
                Q     <= q_reg;                                  -- OUTREG
            end if;
        end if;
    end process;

end architecture;
