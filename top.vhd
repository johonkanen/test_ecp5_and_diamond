library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity top is
    port(
	    xclk : in std_logic;
        pi_uart_rx_serial : in std_logic;
        po_uart_tx_serial : out std_logic;

        -- onboard adc io
        ada_data  : in std_logic;
        ada_clock : out std_logic;
        ada_cs    : out std_logic;
        ada_mux   : out std_logic_vector(2 downto 0);

        adb_data  : in std_logic;
        adb_clock : out std_logic;
        adb_cs    : out std_logic;
        adb_mux   : out std_logic_vector(2 downto 0);

        -- dhb io
        dhb_primary_high : out std_logic;
        dhb_primary_low  : out std_logic;
        dhb_secondary_high : out std_logic;
        dhb_secondary_low  : out std_logic;

        dhb_ad_data  : in std_logic;
        dhb_ad_clock : out std_logic;
        dhb_ad_cs    : out std_logic;

        -- llc io
        pri_high : out std_logic;
        pri_low  : out std_logic;
        sync1    : out std_logic;
        sync2    : out std_logic;

        llc_ad_data  : in std_logic;
        llc_ad_clock : out std_logic;
        llc_ad_cs    : out std_logic;

        -- pfc io
        ac1_switch : out std_logic;
        ac2_switch : out std_logic;

        -- misc
        bypass_relay : out std_logic;

        rgb_led1 : out std_logic_vector(2 downto 0);
        rgb_led2 : out std_logic_vector(2 downto 0);
        rgb_led3 : out std_logic_vector(2 downto 0)

    );
end top;

architecture behavioral of top is

	component main_pll
		port (CLKI: in  std_logic; CLKOP: out  std_logic; 
			CLKOS: out  std_logic);
	end component;
	
	component mpy_32x32
		port (Clock: in  std_logic; ClkEn: in  std_logic; 
			Aclr: in  std_logic; DataA: in  std_logic_vector(31 downto 0); 
			DataB: in  std_logic_vector(31 downto 0); 
			Result: out  std_logic_vector(63 downto 0));
	end component;

	signal clk120MHz : std_logic := '0';
	signal clk240MHz : std_logic := '0';
	
	signal counter_120Mhz : natural := 0;
	signal counter_240Mhz : natural := 60e6;
	
	signal led1_buffer : rgb_led1'subtype := (others => '0');
	
	signal led2_buffer : rgb_led2'subtype := (others => '0');
	
	signal bus_from_top : work.fpga_interconnect_pkg.fpga_interconnect_record;
	signal bus_to_communications : work.fpga_interconnect_pkg.fpga_interconnect_record;
	signal bus_from_communications : work.fpga_interconnect_pkg.fpga_interconnect_record;
	
	signal test_data1 : std_logic_vector(31 downto 0) := x"0000acdc";
	signal test_data2 : std_logic_vector(31 downto 0) := (20 => '1', others => '0');
	signal test_data3 : std_logic_vector(31 downto 0) := x"00000001";
	signal test_data4 : std_logic_vector(31 downto 0) := x"00000002";
	

	signal mpy_out : std_logic_vector(63 downto 0) := (others => '0');

	
begin
	u_main_clocks : main_pll
	port map(CLKI => xclk
	,CLKOP => clk120Mhz
	,CLKOS => clk240Mhz);
	
	rgb_led1 <= led1_buffer;
	process(clk120Mhz) is
	begin
		if rising_edge(clk120Mhz) then
			if counter_120Mhz < 60e6 then
				counter_120Mhz <= counter_120Mhz + 1;
			else
				counter_120Mhz <= 0;
			end if;
			
			if counter_120Mhz = 0 then
			 led1_buffer <= (0 => not led1_buffer(0) , others => '1');
			end if;
		
		end if;
	end process;
	
	rgb_led2 <= led2_buffer;
	process(clk240Mhz) is
	begin
		if rising_edge(clk240Mhz) then
			if counter_240Mhz < 120e6 then
				counter_240Mhz <= counter_240Mhz + 1;
			else
				counter_240Mhz <= 0;
			end if;
			
			if counter_240Mhz = 0 then
			 led2_buffer <= (1 => not led2_buffer(1), others => '1');
			end if;
		end if;
	end process;

        --pi_uart_rx_serial : in std_logic;
        --po_uart_tx_serial  <= '0';

        -- onboard adc io
        --ada_data  : in std_logic;
        ada_clock  <= '0';
        ada_cs     <= '0';
        ada_mux   <= (others => '0');

        --adb_data  : in std_logic;
        adb_clock  <= '0';
        adb_cs     <= '0';
        adb_mux   <= (others => '0');

        -- dhb io
        dhb_primary_high  <= '0';
        dhb_primary_low   <= '0';
        dhb_secondary_high  <= '0';
        dhb_secondary_low   <= '0';

        --dhb_ad_data  : in std_logic;
        dhb_ad_clock  <= '0';
        dhb_ad_cs     <= '0';

        -- llc io
        pri_high  <= '0';
        pri_low   <= '0';
        sync1     <= '0';
        sync2     <= '0';

        --llc_ad_data  : in std_logic;
        llc_ad_clock  <= '0';
        llc_ad_cs     <= '0';

        -- pfc io
        ac1_switch <= '0';
        ac2_switch <= '0';

        -- misc
        bypass_relay <= '0';

       -- rgb_led1 <= (others => '0');
        --rgb_led2 <= (others => '0');
        rgb_led3 <= (others => '0');
		
		u_communications : entity work.fpga_communications
		generic map(
					--work.fpga_interconnect_pkg,
					g_clock_divider => 24
				)
		port map(
			clock => clk120Mhz
			,uart_rx => pi_uart_rx_serial
			,uart_tx => po_uart_tx_serial
			,bus_to_communications => bus_to_communications
			,bus_from_communications => bus_from_communications
		);

		
		
		test_uart : process(clk120Mhz)
			use work.fpga_interconnect_pkg.all;
			variable data : std_logic_vector(31 downto 0);
		begin
			if rising_edge(clk120Mhz) then
			
				init_bus(bus_from_top);
				connect_read_only_data_to_address(bus_from_communications, bus_from_top, 1, std_logic_vector(resize(shift_right(signed(mpy_out),20),32)));
				connect_data_to_address(bus_from_communications, bus_from_top, 2, test_data1);		
				connect_data_to_address(bus_from_communications, bus_from_top, 3, test_data2);		
				connect_data_to_address(bus_from_communications, bus_from_top, 4, test_data3);				
				bus_to_communications <= bus_from_top;

			
			end if;
		end process;
		
		u_mpy : mpy_32x32
		port map(
			 Clock => clk120Mhz
			,ClkEn => test_data3(0)
			,Aclr => test_data3(1)
			,DataA => test_data1 
			,DataB => test_data2 
			,Result => mpy_out
		);
		
	/*	process(clk120Mhz)
		begin
			if rising_edge(clk120MHz) then
				--p1
				mpya <= signed(test_data1);
				mpyb <= signed(test_data2);
				--p2
				mpy_buf <= mpya * mpyb;
				--p3
				mpy_out <= mpy_buf;
			end if;
		end process;*/


------------------------------------------------------------------------
end behavioral;
