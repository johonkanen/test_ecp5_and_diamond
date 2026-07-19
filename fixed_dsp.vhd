library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
entity fixed_dsp is
	port (
			reset, clk : in std_logic := '0';
			dataax, dataay : in std_logic_vector := (31 downto 0 => '0');
			dataout : out std_logic_vector := (63 downto 0 => '0')
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