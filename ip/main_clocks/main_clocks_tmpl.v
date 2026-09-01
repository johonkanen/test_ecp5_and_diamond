//Verilog instantiation template

main_clocks _inst (.addsub_DataA(), .addsub_DataB(), .addsub_Result(), 
            .addsub_Add_Sub(), .addsub_Clock(), .addsub_ClockEn(), .addsub_Reset(), 
            .main_pll_CLKI(), .main_pll_CLKOP(), .main_pll_CLKOS(), .mpy_32x32_DataA(), 
            .mpy_32x32_DataB(), .mpy_32x32_Result(), .mpy_32x32_Aclr(), 
            .mpy_32x32_ClkEn(), .mpy_32x32_Clock(), .adc_scaler_offset_ram_Data(), 
            .adc_scaler_offset_ram_Q(), .adc_scaler_offset_ram_RdAddress(), 
            .adc_scaler_offset_ram_WrAddress(), .adc_scaler_offset_ram_RdClock(), 
            .adc_scaler_offset_ram_RdClockEn(), .adc_scaler_offset_ram_Reset(), 
            .adc_scaler_offset_ram_WE(), .adc_scaler_offset_ram_WrClock(), 
            .adc_scaler_offset_ram_WrClockEn(), .adc_scaler_gain_ram_Data(), 
            .adc_scaler_gain_ram_Q(), .adc_scaler_gain_ram_RdAddress(), 
            .adc_scaler_gain_ram_WrAddress(), .adc_scaler_gain_ram_RdClock(), 
            .adc_scaler_gain_ram_RdClockEn(), .adc_scaler_gain_ram_Reset(), 
            .adc_scaler_gain_ram_WE(), .adc_scaler_gain_ram_WrClock(), .adc_scaler_gain_ram_WrClockEn(), 
            .fmac_A(), .fmac_ACCUM(), .fmac_B(), .fmac_LD(), .fmac_ACCUMSLOAD(), 
            .fmac_ADDNSUB(), .fmac_CE0(), .fmac_CLK0(), .fmac_OVERFLOW(), 
            .fmac_RST0());