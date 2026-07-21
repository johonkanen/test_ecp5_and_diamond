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
		
	component fmac
		port (
			CLK0: in  std_logic; 
			CE0: in  std_logic; 
			RST0: in  std_logic; 
			ACCUMSLOAD: in  std_logic; 
			ADDNSUB: in  std_logic; 
			A: in  std_logic_vector(31 downto 0); 
			B: in  std_logic_vector(31 downto 0); 
			LD: in  std_logic_vector(81 downto 0); 
			OVERFLOW: out  std_logic; 
			ACCUM: out  std_logic_vector(81 downto 0)
		);
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
	
	signal test_data1_buf : std_logic_vector(31 downto 0);
	signal test_data2_buf : std_logic_vector(31 downto 0);
	
	signal test_data3 : std_logic_vector(31 downto 0) := x"00000002";
	signal test_data4 : std_logic_vector(31 downto 0) := x"00000002";
	
	signal mpya : signed(31 downto 0);
	signal mpyb : signed(31 downto 0);

    signal res : signed(63 downto 0);
    signal res_buf : signed(63 downto 0);

	signal mpy_buf : std_logic_vector(81 downto 0) := (others => '0');
	signal mpy_buf2 : std_logic_vector(81 downto 0) := (others => '0');
	signal mpy_out : std_logic_vector(63 downto 0) := (others => '0');
	
	---
	use work.dual_port_ram_pkg.all;
	
	function init_ram return ram_array is
		variable counter : unsigned(31 downto 0) := (others => '0');
		variable retval : ram_array(0 to 511)(31 downto 0);
	begin
		for i in 0 to 511 loop
			retval(i) := std_logic_vector(counter);
			counter := counter + 1;
		end loop;
		
		return retval;
			
	
	end;

    constant init_values : ram_array(0 to 511)(31 downto 0) := init_ram; --(others => (others => '0'));
    constant dp_ram_subtype : dpram_ref_record := create_ref_subtypes(
        datawidth      => 32
        , addresswidth => 9);
    signal ram_a_in  : dp_ram_subtype.ram_in'subtype := dp_ram_subtype.ram_in;
    signal ram_a_out : dp_ram_subtype.ram_out'subtype;
    --------------------
    signal ram_b_in  : dp_ram_subtype.ram_in'subtype := dp_ram_subtype.ram_in;
    signal ram_b_out : dp_ram_subtype.ram_out'subtype;

	signal ram_data_pipe : std_logic_vector(1 downto 0) := (others => '0');
	---
    use work.multi_port_ram_pkg.all;
    constant ref_subtype : subtype_ref_record := 
        create_ref_subtypes(readports => 2, datawidth => 32);
    signal ram_read_in  : ref_subtype.ram_read_in'subtype;
    signal ram_read_out : ref_subtype.ram_read_out'subtype;
    signal ram_write_in : ref_subtype.ram_write_in'subtype;

    use work.microinstruction_pkg.all;
    constant test_program : work.dual_port_ram_pkg.ram_array(0 to 511)(ref_subtype.data'range) := (
        6   => sub( 96, 101,101)

        , 7  => sub( 100 , 101 , 102)
        , 8  => sub( 99  , 102 , 101)
        , 9  => add( 98  , 103 , 104)
        , 10 => add( 97  , 104 , 103)
        , 11 => op(mpy_add , 96  , 101 , 104  , 105)
        , 12 => op(mpy_add , 95  , 102 , 104  , 102)

        , others => op(program_end));

begin

    u_dpram : entity work.dual_port_ram
    generic map(dp_ram_subtype, init_values)
    port map(
    clk120Mhz  ,
    ram_a_in   ,
    ram_a_out  ,
    --------------
    ram_b_in  ,
    ram_b_out);

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
				bus_to_communications <= bus_from_top;
			
				init_bus(bus_from_top);
				connect_read_only_data_to_address(bus_from_communications, bus_from_top, 1, std_logic_vector(resize(shift_right(signed(res),20),32)));
				connect_data_to_address(bus_from_communications, bus_from_top, 2, test_data1);		
				connect_data_to_address(bus_from_communications, bus_from_top, 3, test_data2);		
				connect_data_to_address(bus_from_communications, bus_from_top, 4, test_data3);			
				connect_data_to_address(bus_from_communications, bus_from_top, 5, test_data4);			
				
				init_ram(ram_a_in);
				ram_data_pipe <= ram_data_pipe(0) & '0';
				
				if read_is_requested(bus_from_communications) 
					and get_address(bus_from_communications) >= 100
					and get_address(bus_from_communications) <= 611
				then
					request_data_from_ram(ram_a_in, get_address(bus_from_communications) - 100);
					ram_data_pipe(0) <= '1';
				end if;
				
				if ram_read_is_ready(ram_a_out) then
					write_data_to_address(bus_from_top, 0, get_ram_data(ram_a_out));
				end if;
				
				if write_from_bus_is_requested(bus_from_communications)
					and get_address(bus_from_communications) >= 100
					and get_address(bus_from_communications) <= 611
				then
					write_data_to_ram(ram_b_in, get_address(bus_from_communications) - 100, get_slv_data(bus_from_communications));
				end if;
			
			end if;
		end process;
	
		-- directly instantiating configured ip works
		-- works
		u_mpy : mpy_32x32
		port map(
			Clock   => clk120Mhz
			,ClkEn  => test_data3(0)
			,Aclr   => test_data3(1)
			,DataA  => test_data1
			,DataB  => test_data2
			,Result => mpy_out
		);
        process(clk120Mhz) 
        begin
            if rising_edge(clk120Mhz) then
				CASE test_data3(2) is
				WHEN '1' =>
					res <= signed(mpy_out) - shift_left(resize(signed(test_data4), res'length),20);
				WHEN others => 
					res <= signed(mpy_out) + shift_left(resize(signed(test_data4), res'length),20);
				end CASE;
            
			end if;
        end process;
        
/*
		-- instantiated fmac does not meet timing
		u_fmac : fmac
		port map(
            CLK0        => clk120Mhz
            ,CE0        => test_data3(0)
            ,RST0       => test_data3(1)
            ,ACCUMSLOAD => '0'
            ,ADDNSUB    => '0'
            ,A          => test_data1_buf
            ,B          => test_data2_buf
            ,LD         => (others => '0')
            ,OVERFLOW   => open
            ,ACCUM      => mpy_buf2
		);
*/
/*
        process(clk120Mhz) 
        begin
            if rising_edge(clk120Mhz) then
				test_data1_buf <= test_data1;
				test_data2_buf <= test_data2;
                mpy_buf <= mpy_buf2;
                mpy_out <= mpy_buf;
            end if;
        end process;
*/

		
		
		-- example modified to this project does not work
		-- taken from appendixB of ECP5 and ECP5-5G sysDSP User Guide
		-- https://www.latticesemi.com/view_document?document_id=50469
		/*
		u_mult : entity work.fixed_dsp
		port map(
			reset => test_data3(1)
			, clk => clk120Mhz
			,dataax => test_data1
			,dataay => test_data2
			,dataout => mpy_out
			);
			*/
		
		
		/*
		-- does not meet timing for some reason
		mpy_buf <= mpya * mpyb;
		process(clk120MHz)
		begin
			if rising_edge(clk120MHz) then
				--p1
				mpya <= signed(test_data1);
				mpyb <= signed(test_data2);
				--p2
				mpy_out <= std_logic_vector(mpy_buf);
			end if;
		end process;
		*/
		
		/*
		-- also does not meet timing
		-- taken from appendixB of ECP5 and ECP5-5G sysDSP User Guide
		-- https://www.latticesemi.com/view_document?document_id=50469
		process(clk120Mhz, test_data3(1))
		begin
			if test_data3(1) = '1' then
				mpya <= (others => '0');
				mpyb <= (others => '0');
			elsif rising_edge(clk120MHz) then
				--p1
				mpya <= signed(test_data1);
				mpyb <= signed(test_data2);
				--p2
			end if;
		end process;
		
		mpy_buf <= mpya * mpyb;	
		process(clk120Mhz, test_data3(1))
		begin
			if test_data3(1) = '1' then
				mpy_out <= (others => '0');
			elsif rising_edge(clk120MHz) then
				--p2
				mpy_out <= std_logic_vector(mpy_buf);
				--p3
			end if;
		end process;
*/
				

------------------------------------------------------------------------
end behavioral;
