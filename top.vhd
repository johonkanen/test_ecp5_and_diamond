library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    library ecp5u;
    use ecp5u.components.all;

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
			CLKOS: out  std_logic;
			CLKOS2: out  std_logic
        );
	end component;
	
	component mpy_32x32
		port (Clock: in  std_logic; ClkEn: in  std_logic; 
			Aclr: in  std_logic; DataA: in  std_logic_vector(31 downto 0); 
			DataB: in  std_logic_vector(31 downto 0); 
			Result: out  std_logic_vector(63 downto 0));
	end component;
		
	signal clk120MHz : std_logic := '0';
	signal clk240MHz : std_logic := '0';
	signal clk5MHz : std_logic := '0';
	
	signal counter_120Mhz : natural := 0;
	signal counter_240Mhz : natural := 60e6;
	
	signal led1_buffer : rgb_led1'subtype := (others => '0');
	
	signal led2_buffer : rgb_led2'subtype := (others => '0');
	
	signal bus_to_communications : work.fpga_interconnect_pkg.fpga_interconnect_record;
	signal bus_from_communications : work.fpga_interconnect_pkg.fpga_interconnect_record;
	
	signal bus_from_top : work.fpga_interconnect_pkg.fpga_interconnect_record;
	signal bus_from_uproc : work.fpga_interconnect_pkg.fpga_interconnect_record;

	signal test_data1 : std_logic_vector(31 downto 0) := x"0000acdc";
	signal test_data2 : std_logic_vector(31 downto 0) := (20 => '1', others => '0');
	
	signal test_data1_buf : std_logic_vector(31 downto 0);
	signal test_data2_buf : std_logic_vector(31 downto 0);
	
	signal test_data3 : std_logic_vector(31 downto 0) := x"00000002";
	signal test_data4 : std_logic_vector(31 downto 0) := x"00000002";
	signal test_data5 : std_logic_vector(31 downto 0) := x"000061ab";
	signal test_data6 : std_logic_vector(31 downto 0) := x"00007d00";
	
	signal mpya : signed(31 downto 0);
	signal mpyb : signed(31 downto 0);

    signal res : signed(63 downto 0);
    signal res_buf : signed(63 downto 0);

	signal mpy_buf : std_logic_vector(81 downto 0) := (others => '0');
	signal mpy_buf2 : std_logic_vector(81 downto 0) := (others => '0');
	signal mpy_out : std_logic_vector(63 downto 0) := (others => '0');

    signal pwm_counter1 : natural range 0 to 2**15-1;
    signal pwm1 : std_logic := '0';

    signal pwm_counter2 : natural range 0 to 2**15-1;
    signal pwm2 : std_logic := '0';

	-----------------------------
	-----------------------------
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
	-----------------------------
	-----------------------------

    constant init_values : ram_array(0 to 511)(31 downto 0) := init_ram; --(others => (others => '0'));
    constant dp_ram_subtype : dpram_ref_record := create_ref_subtypes(
        datawidth      => 32
        , addresswidth => 9);
    signal ram_a_in  : dp_ram_subtype.ram_in'subtype := dp_ram_subtype.ram_in;
    signal ram_a_out : dp_ram_subtype.ram_out'subtype;
    --------------------
    signal ram_b_in  : dp_ram_subtype.ram_in'subtype := dp_ram_subtype.ram_in;
    signal ram_b_out : dp_ram_subtype.ram_out'subtype;

	---

    -- microprogram processor start
    use work.instruction_pkg.all;
    constant instruction_length : natural := 32;
    constant word_length        : natural := 32;
    constant used_radix         : natural := 20;

    use work.multi_port_ram_pkg.all;
    constant ref_subtype       : subtype_ref_record := 
        create_ref_subtypes(readports => 3 
        , datawidth => word_length        
        , addresswidth => 10);

    constant instr_ref_subtype : subtype_ref_record := 
        create_ref_subtypes(readports => 1 
        , datawidth => instruction_length 
        , addresswidth => 10);

    signal ram_read_in  : ref_subtype.ram_read_in'subtype;
    signal ram_read_out : ref_subtype.ram_read_out'subtype;
    signal ram_write_in : ref_subtype.ram_write_in'subtype;

    signal mc_output   : ref_subtype.ram_write_in'subtype;
    signal mc_write_in : ref_subtype.ram_write_in'subtype := ref_subtype.ram_write_in;

    use work.microprogram_processor_pkg.all;
    signal mproc_in     : microprogram_processor_in_record;
    signal mproc_out    : microprogram_processor_out_record;

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

    constant instruction_in_ref : instruction_in_record := (
        instr_ram_read_out => instr_ref_subtype.ram_read_out
        ,data_read_out     => ref_subtype.ram_read_out
        ,instr_pipeline    => (0 to 7 => op(nop))
        );

    constant instruction_out_ref : instruction_out_record := (
        data_read_in  => ref_subtype.ram_read_in
        ,ram_write_in => ref_subtype.ram_write_in
        );

    signal addsub_in  : instruction_in_ref'subtype  := instruction_in_ref;
    signal addsub_out : instruction_out_ref'subtype := instruction_out_ref;
    -- microprogram processor end
	
	-- use work.ads7056_pkg.all;
	--    signal ad1 : ads7056_record := init_ads7056;


    signal ada_conversion       : std_logic_vector(15 downto 0);
    signal start_ada_conversion : std_logic := '0';
    signal conversion_counter   : natural   := 0;
    signal adb_conversion       : std_logic_vector(15 downto 0);

    signal llc_ad_conversion : std_logic_vector(15 downto 0);
    signal dhb_ad_conversion : std_logic_vector(15 downto 0);
	
	--constant zero : 

    -- constant init_dsp_in : work.fixed_dsp_pkg.fixed_dsp_in_record :=(
    --     a => (31 downto 0 => '0')
    --     ,b => (31 downto 0 => '0')
    --     ,c => (31 downto 0 => '0')
    --     ,d => (31 downto 0 => '0')
    --     ,request_with_1          => '0'
    --     ,accumulate_with_1       => '0'
    --     ,pre_subtract_with_1     => '0'
    --     ,post_subtract_with_1    => '0'
    --     ,invert_result_with_1    => '0'
    --     ,reset_accumulator_with_1=> '0'
    --
    -- );
    -- signal fixed_dsp_in : work.fixed_dsp_pkg.fixed_dsp_in_record := init_dsp_in;
    use work.fixed_dsp_pkg.all;
    constant init_input : fixed_dsp_in_record := init_fixed_dsp_in;
    signal fixed_dsp_in  : init_input'subtype := init_input;

    -- constant zero_res : signed(63 downto 0) := (others => '0');
    signal fixed_dsp_out : fixed_dsp_out_record(result(63 downto 0)) := (
    ready_with_1 => '0'
    , result     => (others => '0'));

    signal ready_with_1 : std_logic;

begin

    ada : entity work.spi3w_ads7056_driver
        generic map(2,18,9)
        port map(
                clk120MHz, 
                '1',
                ada_cs,
                ada_clock,
                ada_data, 
                start_ada_conversion,
                open,
                open,
                open,
                ada_conversion);

    adb : entity work.spi3w_ads7056_driver
        generic map(2,18,9)
        port map(
                clk120MHz, 
                '1',
                adb_cs,
                adb_clock,
                adb_data, 
                start_ada_conversion,
                open,
                open,
                open,
                adb_conversion);

    ads120s101_a : entity work.spi3w_ads7056_driver
        generic map(6,16,9)
        port map(
                clk120MHz, 
                '1',
                llc_ad_cs,
                llc_ad_clock,
                llc_ad_data, 
                start_ada_conversion,
                open,
                open,
                open,
                llc_ad_conversion);

    ads120s101_b : entity work.spi3w_ads7056_driver
        generic map(6,16,9)
        port map(
                clk120MHz, 
                '1',
                dhb_ad_cs,
                dhb_ad_clock,
                dhb_ad_data, 
                start_ada_conversion,
                open,
                open,
                open,
                dhb_ad_conversion);

    ddr_output_inst : ODDRX1F
    port map (
        SCLK => clk5MHz,
        RST  => '0',
        D0   => '0',
        D1   => '0',
        Q    => dhb_primary_high
    );

------------------------------------------------------------------------
    u_mproc : entity work.uproc_test
    generic map(g_word_length => 32)
    port map(clock => clk120Mhz
    ,bus_from_communications => bus_from_communications
    ,bus_from_uproc          => bus_from_uproc
    );

	u_main_clocks : main_pll
	port map(CLKI => xclk
	,CLKOP => clk120Mhz
	,CLKOS => clk240Mhz
    ,CLKOS2 => clk5MHz
);
	
    rgb_led1 <= (0 => led1_buffer(0) or pwm1, others => '1');
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

            if pwm_counter1 < 2**15-1 then
                pwm_counter1 <= pwm_counter1 + 1;
            else
                pwm_counter1 <= 0;
            end if;

            if pwm_counter1 < unsigned(test_data5(15 downto 0)) then
                pwm1 <= '1';
            else
                pwm1 <= '0';
            end if;
		
		end if;
	end process;
	
    rgb_led2 <= (1 => led2_buffer(1) or pwm2, others => '1');
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

            if pwm_counter2 < 2**15-1 then
                pwm_counter2 <= pwm_counter2 + 1;
            else
                pwm_counter2 <= 0;
            end if;

            if pwm_counter2 < unsigned(test_data6(15 downto 0)) then
                pwm2 <= '1';
            else
                pwm2 <= '0';
            end if;
		end if;
	end process;

        -- onboard adc io
        --ada_data  : in std_logic;
        -- ada_clock  <= '0';
        -- ada_cs     <= '0';
        ada_mux   <= "011";

        --adb_data  : in std_logic;
        -- adb_clock  <= '0';
        -- adb_cs     <= '0';
        adb_mux   <= "011";

        -- dhb io
        -- dhb_primary_high  <= '0';

        dhb_primary_low    <= '0';
        dhb_secondary_high <= '0';
        dhb_secondary_low  <= '0';

        --dhb_ad_data  : in std_logic;
        -- dhb_ad_clock  <= '0';
        -- dhb_ad_cs     <= '0';

        -- llc io
        pri_high  <= '0';
        pri_low   <= '0';
        sync1     <= '0';
        sync2     <= '0';

        --llc_ad_data  : in std_logic;
        -- llc_ad_clock  <= '0';
        -- llc_ad_cs     <= '0';

        -- pfc io
        ac1_switch <= '0';
        ac2_switch <= '0';

        -- misc
        bypass_relay <= '0';

       -- rgb_led1 <= (others => '0');
        --rgb_led2 <= (others => '0');
        rgb_led3 <= (others => '1');
		
		u_communications : entity work.fpga_communications
		generic map(
					--work.fpga_interconnect_pkg,
					g_clock_divider => 24
				)
		port map(
			clock => clk120Mhz
			,uart_rx                 => pi_uart_rx_serial
			,uart_tx                 => po_uart_tx_serial
			,bus_to_communications   => bus_to_communications
			,bus_from_communications => bus_from_communications
		);

        process(clk120Mhz)
			use work.fpga_interconnect_pkg.all;
        begin
            if rising_edge(clk120Mhz) then
                bus_to_communications <= bus_from_top
                                         and bus_from_uproc;
            end if;
        end process;
		
		test_uart : process(clk120Mhz)
			use work.fpga_interconnect_pkg.all;
			variable data : std_logic_vector(31 downto 0);
		begin
			if rising_edge(clk120Mhz) then	
			
				init_bus(bus_from_top);
				connect_read_only_data_to_address(bus_from_communications , bus_from_top , 1 , std_logic_vector(resize(shift_right(signed(res) , 20) , 32)));
				connect_data_to_address(bus_from_communications           , bus_from_top , 2 , test_data1);
				connect_data_to_address(bus_from_communications           , bus_from_top , 3 , test_data2);
				connect_data_to_address(bus_from_communications           , bus_from_top , 4 , test_data3);
				connect_data_to_address(bus_from_communications           , bus_from_top , 5 , test_data4);
				connect_data_to_address(bus_from_communications           , bus_from_top , 6 , test_data5);
				connect_data_to_address(bus_from_communications           , bus_from_top , 7 , test_data6);
				connect_read_only_data_to_address(bus_from_communications , bus_from_top , 8 , ada_conversion);
				connect_read_only_data_to_address(bus_from_communications , bus_from_top , 9 , adb_conversion);
				connect_read_only_data_to_address(bus_from_communications , bus_from_top , 10 , llc_ad_conversion);
				connect_read_only_data_to_address(bus_from_communications , bus_from_top , 11 , dhb_ad_conversion);
				
				init_ram(ram_a_in);
                -- create_ads7056_driver(ad1,ada_data, ada_cs, ada_clock); 

                conversion_counter <= conversion_counter + 1;
                if conversion_counter >= 1000 then
                    conversion_counter <= 0;
                end if;

                if conversion_counter = 0 then
                    start_ada_conversion <= '1';
                else
                    start_ada_conversion <= '0';
                end if;

				
				if read_is_requested(bus_from_communications) 
					and get_address(bus_from_communications) >= 100
					and get_address(bus_from_communications) <= 611
				then
					request_data_from_ram(ram_a_in, get_address(bus_from_communications) - 100);
				end if;
				
				if ram_read_is_ready(ram_a_out) then
					write_data_to_address(bus_from_top, 0, get_ram_data(ram_a_out));
				end if;
				
				if write_from_bus_is_requested(bus_from_communications)
					and get_address(bus_from_communications) >= 1000
					and get_address(bus_from_communications) <= 1611
				then
					write_data_to_ram(ram_b_in, get_address(bus_from_communications) - 1000, get_slv_data(bus_from_communications));
				end if;
			
			end if;
		end process;

        fixed_dsp_in.a <= signed(test_data1);
        fixed_dsp_in.d <= signed(test_data3);
        fixed_dsp_in.b <= signed(test_data2);
        fixed_dsp_in.c <= signed(test_data4);

        fixed_dsp_in.request_with_1           <= '1';
        fixed_dsp_in.accumulate_with_1        <= '0';
        fixed_dsp_in.pre_subtract_with_1      <= '0';
        fixed_dsp_in.post_subtract_with_1     <= '0';
        fixed_dsp_in.invert_result_with_1     <= '0';
        fixed_dsp_in.reset_accumulator_with_1 <= '0';

        fixed_dsp_out.ready_with_1 <= ready_with_1;
        fixed_dsp_out.result <= res;

        u_ecp5_fixed_dsp : entity work.fixed_dsp
        generic map(g_radix => 20)
        port map(
            clock => clk120Mhz
            ,fixed_dsp_in  => fixed_dsp_in
            ,fixed_dsp_out => fixed_dsp_out
        );

------------------------------------------------------------------------
end behavioral;
