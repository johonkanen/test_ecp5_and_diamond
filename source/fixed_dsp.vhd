library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- note this crashes diamond build if it is not instantiated
-- also does not meet timing even though the direct instantion of configured ip does

entity fixed_dsp is
	port (
			reset, clk : in std_logic := '0';
			dataax, dataay : in std_logic_vector;
			dataout : out std_logic_vector
		);
end;

architecture arch of fixed_dsp is
	signal dataax_reg, dataay_reg : dataax'subtype;
	signal dataout_node : dataout'subtype;
	signal dataout_pipeline : dataout'subtype;
begin

	process (clk, reset)
	begin
		if (reset='1') then
			dataax_reg <= (others => '0');
			dataay_reg <= (others => '0');
		elsif (clk'event and clk='1') then
			dataax_reg <= dataax;
			dataay_reg <= dataay;
		end if;
	end process;


	dataout_node <= dataax_reg * dataay_reg;
	process (clk, reset)
	begin
		if (reset='1') then
			dataout_pipeline <= (others => '0');
		elsif (clk'event and clk='1') then
			dataout_pipeline <= dataout_node;
		end if;
	end process;
	
	process (clk, reset)
	begin
		if (reset='1') then
			dataout <= (others => '0');
		elsif (clk'event and clk='1') then
			dataout <= dataout_pipeline;
		end if;
	end process;
	
end arch;
