--VHDL instantiation template

component main_clocks is
    port (adc_scaler_gain_ram_Data: in std_logic_vector(31 downto 0);
        adc_scaler_gain_ram_Q: out std_logic_vector(31 downto 0);
        adc_scaler_gain_ram_RdAddress: in std_logic_vector(8 downto 0);
        adc_scaler_gain_ram_WrAddress: in std_logic_vector(8 downto 0);
        adc_scaler_offset_ram_Data: in std_logic_vector(31 downto 0);
        adc_scaler_offset_ram_Q: out std_logic_vector(31 downto 0);
        adc_scaler_offset_ram_RdAddress: in std_logic_vector(8 downto 0);
        adc_scaler_offset_ram_WrAddress: in std_logic_vector(8 downto 0);
        addsub_DataA: in std_logic_vector(63 downto 0);
        addsub_DataB: in std_logic_vector(63 downto 0);
        addsub_Result: out std_logic_vector(63 downto 0);
        fmac_A: in std_logic_vector(31 downto 0);
        fmac_ACCUM: out std_logic_vector(81 downto 0);
        fmac_B: in std_logic_vector(31 downto 0);
        fmac_LD: in std_logic_vector(81 downto 0);
        mpy_32x32_DataA: in std_logic_vector(31 downto 0);
        mpy_32x32_DataB: in std_logic_vector(31 downto 0);
        mpy_32x32_Result: out std_logic_vector(63 downto 0);
        adc_scaler_gain_ram_RdClock: in std_logic;
        adc_scaler_gain_ram_RdClockEn: in std_logic;
        adc_scaler_gain_ram_Reset: in std_logic;
        adc_scaler_gain_ram_WE: in std_logic;
        adc_scaler_gain_ram_WrClock: in std_logic;
        adc_scaler_gain_ram_WrClockEn: in std_logic;
        adc_scaler_offset_ram_RdClock: in std_logic;
        adc_scaler_offset_ram_RdClockEn: in std_logic;
        adc_scaler_offset_ram_Reset: in std_logic;
        adc_scaler_offset_ram_WE: in std_logic;
        adc_scaler_offset_ram_WrClock: in std_logic;
        adc_scaler_offset_ram_WrClockEn: in std_logic;
        addsub_Add_Sub: in std_logic;
        addsub_Clock: in std_logic;
        addsub_ClockEn: in std_logic;
        addsub_Reset: in std_logic;
        fmac_ACCUMSLOAD: in std_logic;
        fmac_ADDNSUB: in std_logic;
        fmac_CE0: in std_logic;
        fmac_CLK0: in std_logic;
        fmac_OVERFLOW: out std_logic;
        fmac_RST0: in std_logic;
        main_pll_CLKI: in std_logic;
        main_pll_CLKOP: out std_logic;
        main_pll_CLKOS: out std_logic;
        mpy_32x32_Aclr: in std_logic;
        mpy_32x32_ClkEn: in std_logic;
        mpy_32x32_Clock: in std_logic
    );
    
end component main_clocks; -- sbp_module=true 
_inst: main_clocks port map (addsub_DataA => __,addsub_DataB => __,addsub_Result => __,
            addsub_Add_Sub => __,addsub_Clock => __,addsub_ClockEn => __,
            addsub_Reset => __,main_pll_CLKI => __,main_pll_CLKOP => __,main_pll_CLKOS => __,
            mpy_32x32_DataA => __,mpy_32x32_DataB => __,mpy_32x32_Result => __,
            mpy_32x32_Aclr => __,mpy_32x32_ClkEn => __,mpy_32x32_Clock => __,
            adc_scaler_offset_ram_Data => __,adc_scaler_offset_ram_Q => __,
            adc_scaler_offset_ram_RdAddress => __,adc_scaler_offset_ram_WrAddress => __,
            adc_scaler_offset_ram_RdClock => __,adc_scaler_offset_ram_RdClockEn => __,
            adc_scaler_offset_ram_Reset => __,adc_scaler_offset_ram_WE => __,
            adc_scaler_offset_ram_WrClock => __,adc_scaler_offset_ram_WrClockEn => __,
            adc_scaler_gain_ram_Data => __,adc_scaler_gain_ram_Q => __,adc_scaler_gain_ram_RdAddress => __,
            adc_scaler_gain_ram_WrAddress => __,adc_scaler_gain_ram_RdClock => __,
            adc_scaler_gain_ram_RdClockEn => __,adc_scaler_gain_ram_Reset => __,
            adc_scaler_gain_ram_WE => __,adc_scaler_gain_ram_WrClock => __,
            adc_scaler_gain_ram_WrClockEn => __,fmac_A => __,fmac_ACCUM => __,
            fmac_B => __,fmac_LD => __,fmac_ACCUMSLOAD => __,fmac_ADDNSUB => __,
            fmac_CE0 => __,fmac_CLK0 => __,fmac_OVERFLOW => __,fmac_RST0 => __);
