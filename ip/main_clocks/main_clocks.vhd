






--
-- Verific VHDL Description of module main_clocks
--

library ieee ;
use ieee.std_logic_1164.all ;

entity main_clocks is
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
    
end entity main_clocks; -- sbp_module=true 

architecture main_clocks of main_clocks is 
    component adc_scaler_gain_ram is
        port (Data: in std_logic_vector(31 downto 0);
            Q: out std_logic_vector(31 downto 0);
            RdAddress: in std_logic_vector(8 downto 0);
            WrAddress: in std_logic_vector(8 downto 0);
            RdClock: in std_logic;
            RdClockEn: in std_logic;
            Reset: in std_logic;
            WE: in std_logic;
            WrClock: in std_logic;
            WrClockEn: in std_logic
        );
        
    end component adc_scaler_gain_ram; -- not_need_bbox=true 
    
    
    component adc_scaler_offset_ram is
        port (Data: in std_logic_vector(31 downto 0);
            Q: out std_logic_vector(31 downto 0);
            RdAddress: in std_logic_vector(8 downto 0);
            WrAddress: in std_logic_vector(8 downto 0);
            RdClock: in std_logic;
            RdClockEn: in std_logic;
            Reset: in std_logic;
            WE: in std_logic;
            WrClock: in std_logic;
            WrClockEn: in std_logic
        );
        
    end component adc_scaler_offset_ram; -- not_need_bbox=true 
    
    
    component addsub is
        port (DataA: in std_logic_vector(63 downto 0);
            DataB: in std_logic_vector(63 downto 0);
            Result: out std_logic_vector(63 downto 0);
            Add_Sub: in std_logic;
            Clock: in std_logic;
            ClockEn: in std_logic;
            Reset: in std_logic
        );
        
    end component addsub; -- not_need_bbox=true 
    
    
    component fmac is
        port (A: in std_logic_vector(31 downto 0);
            ACCUM: out std_logic_vector(81 downto 0);
            B: in std_logic_vector(31 downto 0);
            LD: in std_logic_vector(81 downto 0);
            ACCUMSLOAD: in std_logic;
            ADDNSUB: in std_logic;
            CE0: in std_logic;
            CLK0: in std_logic;
            OVERFLOW: out std_logic;
            RST0: in std_logic
        );
        
    end component fmac; -- not_need_bbox=true 
    
    
    component main_pll is
        port (CLKI: in std_logic;
            CLKOP: out std_logic;
            CLKOS: out std_logic;
            CLKOS2: out std_logic
        );
        
    end component main_pll; -- not_need_bbox=true 
    
    
    component mpy_32x32 is
        port (DataA: in std_logic_vector(31 downto 0);
            DataB: in std_logic_vector(31 downto 0);
            Result: out std_logic_vector(63 downto 0);
            Aclr: in std_logic;
            ClkEn: in std_logic;
            Clock: in std_logic
        );
        
    end component mpy_32x32; -- not_need_bbox=true 
    
    
    
begin
    adc_scaler_gain_ram_inst: component adc_scaler_gain_ram port map (Data(31)=>adc_scaler_gain_ram_Data(31),
            Data(30)=>adc_scaler_gain_ram_Data(30),Data(29)=>adc_scaler_gain_ram_Data(29),
            Data(28)=>adc_scaler_gain_ram_Data(28),Data(27)=>adc_scaler_gain_ram_Data(27),
            Data(26)=>adc_scaler_gain_ram_Data(26),Data(25)=>adc_scaler_gain_ram_Data(25),
            Data(24)=>adc_scaler_gain_ram_Data(24),Data(23)=>adc_scaler_gain_ram_Data(23),
            Data(22)=>adc_scaler_gain_ram_Data(22),Data(21)=>adc_scaler_gain_ram_Data(21),
            Data(20)=>adc_scaler_gain_ram_Data(20),Data(19)=>adc_scaler_gain_ram_Data(19),
            Data(18)=>adc_scaler_gain_ram_Data(18),Data(17)=>adc_scaler_gain_ram_Data(17),
            Data(16)=>adc_scaler_gain_ram_Data(16),Data(15)=>adc_scaler_gain_ram_Data(15),
            Data(14)=>adc_scaler_gain_ram_Data(14),Data(13)=>adc_scaler_gain_ram_Data(13),
            Data(12)=>adc_scaler_gain_ram_Data(12),Data(11)=>adc_scaler_gain_ram_Data(11),
            Data(10)=>adc_scaler_gain_ram_Data(10),Data(9)=>adc_scaler_gain_ram_Data(9),
            Data(8)=>adc_scaler_gain_ram_Data(8),Data(7)=>adc_scaler_gain_ram_Data(7),
            Data(6)=>adc_scaler_gain_ram_Data(6),Data(5)=>adc_scaler_gain_ram_Data(5),
            Data(4)=>adc_scaler_gain_ram_Data(4),Data(3)=>adc_scaler_gain_ram_Data(3),
            Data(2)=>adc_scaler_gain_ram_Data(2),Data(1)=>adc_scaler_gain_ram_Data(1),
            Data(0)=>adc_scaler_gain_ram_Data(0),Q(31)=>adc_scaler_gain_ram_Q(31),
            Q(30)=>adc_scaler_gain_ram_Q(30),Q(29)=>adc_scaler_gain_ram_Q(29),
            Q(28)=>adc_scaler_gain_ram_Q(28),Q(27)=>adc_scaler_gain_ram_Q(27),
            Q(26)=>adc_scaler_gain_ram_Q(26),Q(25)=>adc_scaler_gain_ram_Q(25),
            Q(24)=>adc_scaler_gain_ram_Q(24),Q(23)=>adc_scaler_gain_ram_Q(23),
            Q(22)=>adc_scaler_gain_ram_Q(22),Q(21)=>adc_scaler_gain_ram_Q(21),
            Q(20)=>adc_scaler_gain_ram_Q(20),Q(19)=>adc_scaler_gain_ram_Q(19),
            Q(18)=>adc_scaler_gain_ram_Q(18),Q(17)=>adc_scaler_gain_ram_Q(17),
            Q(16)=>adc_scaler_gain_ram_Q(16),Q(15)=>adc_scaler_gain_ram_Q(15),
            Q(14)=>adc_scaler_gain_ram_Q(14),Q(13)=>adc_scaler_gain_ram_Q(13),
            Q(12)=>adc_scaler_gain_ram_Q(12),Q(11)=>adc_scaler_gain_ram_Q(11),
            Q(10)=>adc_scaler_gain_ram_Q(10),Q(9)=>adc_scaler_gain_ram_Q(9),
            Q(8)=>adc_scaler_gain_ram_Q(8),Q(7)=>adc_scaler_gain_ram_Q(7),
            Q(6)=>adc_scaler_gain_ram_Q(6),Q(5)=>adc_scaler_gain_ram_Q(5),
            Q(4)=>adc_scaler_gain_ram_Q(4),Q(3)=>adc_scaler_gain_ram_Q(3),
            Q(2)=>adc_scaler_gain_ram_Q(2),Q(1)=>adc_scaler_gain_ram_Q(1),
            Q(0)=>adc_scaler_gain_ram_Q(0),RdAddress(8)=>adc_scaler_gain_ram_RdAddress(8),
            RdAddress(7)=>adc_scaler_gain_ram_RdAddress(7),RdAddress(6)=>adc_scaler_gain_ram_RdAddress(6),
            RdAddress(5)=>adc_scaler_gain_ram_RdAddress(5),RdAddress(4)=>adc_scaler_gain_ram_RdAddress(4),
            RdAddress(3)=>adc_scaler_gain_ram_RdAddress(3),RdAddress(2)=>adc_scaler_gain_ram_RdAddress(2),
            RdAddress(1)=>adc_scaler_gain_ram_RdAddress(1),RdAddress(0)=>adc_scaler_gain_ram_RdAddress(0),
            WrAddress(8)=>adc_scaler_gain_ram_WrAddress(8),WrAddress(7)=>adc_scaler_gain_ram_WrAddress(7),
            WrAddress(6)=>adc_scaler_gain_ram_WrAddress(6),WrAddress(5)=>adc_scaler_gain_ram_WrAddress(5),
            WrAddress(4)=>adc_scaler_gain_ram_WrAddress(4),WrAddress(3)=>adc_scaler_gain_ram_WrAddress(3),
            WrAddress(2)=>adc_scaler_gain_ram_WrAddress(2),WrAddress(1)=>adc_scaler_gain_ram_WrAddress(1),
            WrAddress(0)=>adc_scaler_gain_ram_WrAddress(0),RdClock=>adc_scaler_gain_ram_RdClock,
            RdClockEn=>adc_scaler_gain_ram_RdClockEn,Reset=>adc_scaler_gain_ram_Reset,
            WE=>adc_scaler_gain_ram_WE,WrClock=>adc_scaler_gain_ram_WrClock,
            WrClockEn=>adc_scaler_gain_ram_WrClockEn);
    adc_scaler_offset_ram_inst: component adc_scaler_offset_ram port map (Data(31)=>adc_scaler_offset_ram_Data(31),
            Data(30)=>adc_scaler_offset_ram_Data(30),Data(29)=>adc_scaler_offset_ram_Data(29),
            Data(28)=>adc_scaler_offset_ram_Data(28),Data(27)=>adc_scaler_offset_ram_Data(27),
            Data(26)=>adc_scaler_offset_ram_Data(26),Data(25)=>adc_scaler_offset_ram_Data(25),
            Data(24)=>adc_scaler_offset_ram_Data(24),Data(23)=>adc_scaler_offset_ram_Data(23),
            Data(22)=>adc_scaler_offset_ram_Data(22),Data(21)=>adc_scaler_offset_ram_Data(21),
            Data(20)=>adc_scaler_offset_ram_Data(20),Data(19)=>adc_scaler_offset_ram_Data(19),
            Data(18)=>adc_scaler_offset_ram_Data(18),Data(17)=>adc_scaler_offset_ram_Data(17),
            Data(16)=>adc_scaler_offset_ram_Data(16),Data(15)=>adc_scaler_offset_ram_Data(15),
            Data(14)=>adc_scaler_offset_ram_Data(14),Data(13)=>adc_scaler_offset_ram_Data(13),
            Data(12)=>adc_scaler_offset_ram_Data(12),Data(11)=>adc_scaler_offset_ram_Data(11),
            Data(10)=>adc_scaler_offset_ram_Data(10),Data(9)=>adc_scaler_offset_ram_Data(9),
            Data(8)=>adc_scaler_offset_ram_Data(8),Data(7)=>adc_scaler_offset_ram_Data(7),
            Data(6)=>adc_scaler_offset_ram_Data(6),Data(5)=>adc_scaler_offset_ram_Data(5),
            Data(4)=>adc_scaler_offset_ram_Data(4),Data(3)=>adc_scaler_offset_ram_Data(3),
            Data(2)=>adc_scaler_offset_ram_Data(2),Data(1)=>adc_scaler_offset_ram_Data(1),
            Data(0)=>adc_scaler_offset_ram_Data(0),Q(31)=>adc_scaler_offset_ram_Q(31),
            Q(30)=>adc_scaler_offset_ram_Q(30),Q(29)=>adc_scaler_offset_ram_Q(29),
            Q(28)=>adc_scaler_offset_ram_Q(28),Q(27)=>adc_scaler_offset_ram_Q(27),
            Q(26)=>adc_scaler_offset_ram_Q(26),Q(25)=>adc_scaler_offset_ram_Q(25),
            Q(24)=>adc_scaler_offset_ram_Q(24),Q(23)=>adc_scaler_offset_ram_Q(23),
            Q(22)=>adc_scaler_offset_ram_Q(22),Q(21)=>adc_scaler_offset_ram_Q(21),
            Q(20)=>adc_scaler_offset_ram_Q(20),Q(19)=>adc_scaler_offset_ram_Q(19),
            Q(18)=>adc_scaler_offset_ram_Q(18),Q(17)=>adc_scaler_offset_ram_Q(17),
            Q(16)=>adc_scaler_offset_ram_Q(16),Q(15)=>adc_scaler_offset_ram_Q(15),
            Q(14)=>adc_scaler_offset_ram_Q(14),Q(13)=>adc_scaler_offset_ram_Q(13),
            Q(12)=>adc_scaler_offset_ram_Q(12),Q(11)=>adc_scaler_offset_ram_Q(11),
            Q(10)=>adc_scaler_offset_ram_Q(10),Q(9)=>adc_scaler_offset_ram_Q(9),
            Q(8)=>adc_scaler_offset_ram_Q(8),Q(7)=>adc_scaler_offset_ram_Q(7),
            Q(6)=>adc_scaler_offset_ram_Q(6),Q(5)=>adc_scaler_offset_ram_Q(5),
            Q(4)=>adc_scaler_offset_ram_Q(4),Q(3)=>adc_scaler_offset_ram_Q(3),
            Q(2)=>adc_scaler_offset_ram_Q(2),Q(1)=>adc_scaler_offset_ram_Q(1),
            Q(0)=>adc_scaler_offset_ram_Q(0),RdAddress(8)=>adc_scaler_offset_ram_RdAddress(8),
            RdAddress(7)=>adc_scaler_offset_ram_RdAddress(7),RdAddress(6)=>adc_scaler_offset_ram_RdAddress(6),
            RdAddress(5)=>adc_scaler_offset_ram_RdAddress(5),RdAddress(4)=>adc_scaler_offset_ram_RdAddress(4),
            RdAddress(3)=>adc_scaler_offset_ram_RdAddress(3),RdAddress(2)=>adc_scaler_offset_ram_RdAddress(2),
            RdAddress(1)=>adc_scaler_offset_ram_RdAddress(1),RdAddress(0)=>adc_scaler_offset_ram_RdAddress(0),
            WrAddress(8)=>adc_scaler_offset_ram_WrAddress(8),WrAddress(7)=>adc_scaler_offset_ram_WrAddress(7),
            WrAddress(6)=>adc_scaler_offset_ram_WrAddress(6),WrAddress(5)=>adc_scaler_offset_ram_WrAddress(5),
            WrAddress(4)=>adc_scaler_offset_ram_WrAddress(4),WrAddress(3)=>adc_scaler_offset_ram_WrAddress(3),
            WrAddress(2)=>adc_scaler_offset_ram_WrAddress(2),WrAddress(1)=>adc_scaler_offset_ram_WrAddress(1),
            WrAddress(0)=>adc_scaler_offset_ram_WrAddress(0),RdClock=>adc_scaler_offset_ram_RdClock,
            RdClockEn=>adc_scaler_offset_ram_RdClockEn,Reset=>adc_scaler_offset_ram_Reset,
            WE=>adc_scaler_offset_ram_WE,WrClock=>adc_scaler_offset_ram_WrClock,
            WrClockEn=>adc_scaler_offset_ram_WrClockEn);
    addsub_inst: component addsub port map (DataA(63)=>addsub_DataA(63),DataA(62)=>addsub_DataA(62),
            DataA(61)=>addsub_DataA(61),DataA(60)=>addsub_DataA(60),DataA(59)=>addsub_DataA(59),
            DataA(58)=>addsub_DataA(58),DataA(57)=>addsub_DataA(57),DataA(56)=>addsub_DataA(56),
            DataA(55)=>addsub_DataA(55),DataA(54)=>addsub_DataA(54),DataA(53)=>addsub_DataA(53),
            DataA(52)=>addsub_DataA(52),DataA(51)=>addsub_DataA(51),DataA(50)=>addsub_DataA(50),
            DataA(49)=>addsub_DataA(49),DataA(48)=>addsub_DataA(48),DataA(47)=>addsub_DataA(47),
            DataA(46)=>addsub_DataA(46),DataA(45)=>addsub_DataA(45),DataA(44)=>addsub_DataA(44),
            DataA(43)=>addsub_DataA(43),DataA(42)=>addsub_DataA(42),DataA(41)=>addsub_DataA(41),
            DataA(40)=>addsub_DataA(40),DataA(39)=>addsub_DataA(39),DataA(38)=>addsub_DataA(38),
            DataA(37)=>addsub_DataA(37),DataA(36)=>addsub_DataA(36),DataA(35)=>addsub_DataA(35),
            DataA(34)=>addsub_DataA(34),DataA(33)=>addsub_DataA(33),DataA(32)=>addsub_DataA(32),
            DataA(31)=>addsub_DataA(31),DataA(30)=>addsub_DataA(30),DataA(29)=>addsub_DataA(29),
            DataA(28)=>addsub_DataA(28),DataA(27)=>addsub_DataA(27),DataA(26)=>addsub_DataA(26),
            DataA(25)=>addsub_DataA(25),DataA(24)=>addsub_DataA(24),DataA(23)=>addsub_DataA(23),
            DataA(22)=>addsub_DataA(22),DataA(21)=>addsub_DataA(21),DataA(20)=>addsub_DataA(20),
            DataA(19)=>addsub_DataA(19),DataA(18)=>addsub_DataA(18),DataA(17)=>addsub_DataA(17),
            DataA(16)=>addsub_DataA(16),DataA(15)=>addsub_DataA(15),DataA(14)=>addsub_DataA(14),
            DataA(13)=>addsub_DataA(13),DataA(12)=>addsub_DataA(12),DataA(11)=>addsub_DataA(11),
            DataA(10)=>addsub_DataA(10),DataA(9)=>addsub_DataA(9),DataA(8)=>addsub_DataA(8),
            DataA(7)=>addsub_DataA(7),DataA(6)=>addsub_DataA(6),DataA(5)=>addsub_DataA(5),
            DataA(4)=>addsub_DataA(4),DataA(3)=>addsub_DataA(3),DataA(2)=>addsub_DataA(2),
            DataA(1)=>addsub_DataA(1),DataA(0)=>addsub_DataA(0),DataB(63)=>addsub_DataB(63),
            DataB(62)=>addsub_DataB(62),DataB(61)=>addsub_DataB(61),DataB(60)=>addsub_DataB(60),
            DataB(59)=>addsub_DataB(59),DataB(58)=>addsub_DataB(58),DataB(57)=>addsub_DataB(57),
            DataB(56)=>addsub_DataB(56),DataB(55)=>addsub_DataB(55),DataB(54)=>addsub_DataB(54),
            DataB(53)=>addsub_DataB(53),DataB(52)=>addsub_DataB(52),DataB(51)=>addsub_DataB(51),
            DataB(50)=>addsub_DataB(50),DataB(49)=>addsub_DataB(49),DataB(48)=>addsub_DataB(48),
            DataB(47)=>addsub_DataB(47),DataB(46)=>addsub_DataB(46),DataB(45)=>addsub_DataB(45),
            DataB(44)=>addsub_DataB(44),DataB(43)=>addsub_DataB(43),DataB(42)=>addsub_DataB(42),
            DataB(41)=>addsub_DataB(41),DataB(40)=>addsub_DataB(40),DataB(39)=>addsub_DataB(39),
            DataB(38)=>addsub_DataB(38),DataB(37)=>addsub_DataB(37),DataB(36)=>addsub_DataB(36),
            DataB(35)=>addsub_DataB(35),DataB(34)=>addsub_DataB(34),DataB(33)=>addsub_DataB(33),
            DataB(32)=>addsub_DataB(32),DataB(31)=>addsub_DataB(31),DataB(30)=>addsub_DataB(30),
            DataB(29)=>addsub_DataB(29),DataB(28)=>addsub_DataB(28),DataB(27)=>addsub_DataB(27),
            DataB(26)=>addsub_DataB(26),DataB(25)=>addsub_DataB(25),DataB(24)=>addsub_DataB(24),
            DataB(23)=>addsub_DataB(23),DataB(22)=>addsub_DataB(22),DataB(21)=>addsub_DataB(21),
            DataB(20)=>addsub_DataB(20),DataB(19)=>addsub_DataB(19),DataB(18)=>addsub_DataB(18),
            DataB(17)=>addsub_DataB(17),DataB(16)=>addsub_DataB(16),DataB(15)=>addsub_DataB(15),
            DataB(14)=>addsub_DataB(14),DataB(13)=>addsub_DataB(13),DataB(12)=>addsub_DataB(12),
            DataB(11)=>addsub_DataB(11),DataB(10)=>addsub_DataB(10),DataB(9)=>addsub_DataB(9),
            DataB(8)=>addsub_DataB(8),DataB(7)=>addsub_DataB(7),DataB(6)=>addsub_DataB(6),
            DataB(5)=>addsub_DataB(5),DataB(4)=>addsub_DataB(4),DataB(3)=>addsub_DataB(3),
            DataB(2)=>addsub_DataB(2),DataB(1)=>addsub_DataB(1),DataB(0)=>addsub_DataB(0),
            Result(63)=>addsub_Result(63),Result(62)=>addsub_Result(62),Result(61)=>addsub_Result(61),
            Result(60)=>addsub_Result(60),Result(59)=>addsub_Result(59),Result(58)=>addsub_Result(58),
            Result(57)=>addsub_Result(57),Result(56)=>addsub_Result(56),Result(55)=>addsub_Result(55),
            Result(54)=>addsub_Result(54),Result(53)=>addsub_Result(53),Result(52)=>addsub_Result(52),
            Result(51)=>addsub_Result(51),Result(50)=>addsub_Result(50),Result(49)=>addsub_Result(49),
            Result(48)=>addsub_Result(48),Result(47)=>addsub_Result(47),Result(46)=>addsub_Result(46),
            Result(45)=>addsub_Result(45),Result(44)=>addsub_Result(44),Result(43)=>addsub_Result(43),
            Result(42)=>addsub_Result(42),Result(41)=>addsub_Result(41),Result(40)=>addsub_Result(40),
            Result(39)=>addsub_Result(39),Result(38)=>addsub_Result(38),Result(37)=>addsub_Result(37),
            Result(36)=>addsub_Result(36),Result(35)=>addsub_Result(35),Result(34)=>addsub_Result(34),
            Result(33)=>addsub_Result(33),Result(32)=>addsub_Result(32),Result(31)=>addsub_Result(31),
            Result(30)=>addsub_Result(30),Result(29)=>addsub_Result(29),Result(28)=>addsub_Result(28),
            Result(27)=>addsub_Result(27),Result(26)=>addsub_Result(26),Result(25)=>addsub_Result(25),
            Result(24)=>addsub_Result(24),Result(23)=>addsub_Result(23),Result(22)=>addsub_Result(22),
            Result(21)=>addsub_Result(21),Result(20)=>addsub_Result(20),Result(19)=>addsub_Result(19),
            Result(18)=>addsub_Result(18),Result(17)=>addsub_Result(17),Result(16)=>addsub_Result(16),
            Result(15)=>addsub_Result(15),Result(14)=>addsub_Result(14),Result(13)=>addsub_Result(13),
            Result(12)=>addsub_Result(12),Result(11)=>addsub_Result(11),Result(10)=>addsub_Result(10),
            Result(9)=>addsub_Result(9),Result(8)=>addsub_Result(8),Result(7)=>addsub_Result(7),
            Result(6)=>addsub_Result(6),Result(5)=>addsub_Result(5),Result(4)=>addsub_Result(4),
            Result(3)=>addsub_Result(3),Result(2)=>addsub_Result(2),Result(1)=>addsub_Result(1),
            Result(0)=>addsub_Result(0),Add_Sub=>addsub_Add_Sub,Clock=>addsub_Clock,
            ClockEn=>addsub_ClockEn,Reset=>addsub_Reset);
    fmac_inst: component fmac port map (A(31)=>fmac_A(31),A(30)=>fmac_A(30),
            A(29)=>fmac_A(29),A(28)=>fmac_A(28),A(27)=>fmac_A(27),A(26)=>fmac_A(26),
            A(25)=>fmac_A(25),A(24)=>fmac_A(24),A(23)=>fmac_A(23),A(22)=>fmac_A(22),
            A(21)=>fmac_A(21),A(20)=>fmac_A(20),A(19)=>fmac_A(19),A(18)=>fmac_A(18),
            A(17)=>fmac_A(17),A(16)=>fmac_A(16),A(15)=>fmac_A(15),A(14)=>fmac_A(14),
            A(13)=>fmac_A(13),A(12)=>fmac_A(12),A(11)=>fmac_A(11),A(10)=>fmac_A(10),
            A(9)=>fmac_A(9),A(8)=>fmac_A(8),A(7)=>fmac_A(7),A(6)=>fmac_A(6),
            A(5)=>fmac_A(5),A(4)=>fmac_A(4),A(3)=>fmac_A(3),A(2)=>fmac_A(2),
            A(1)=>fmac_A(1),A(0)=>fmac_A(0),ACCUM(81)=>fmac_ACCUM(81),ACCUM(80)=>fmac_ACCUM(80),
            ACCUM(79)=>fmac_ACCUM(79),ACCUM(78)=>fmac_ACCUM(78),ACCUM(77)=>fmac_ACCUM(77),
            ACCUM(76)=>fmac_ACCUM(76),ACCUM(75)=>fmac_ACCUM(75),ACCUM(74)=>fmac_ACCUM(74),
            ACCUM(73)=>fmac_ACCUM(73),ACCUM(72)=>fmac_ACCUM(72),ACCUM(71)=>fmac_ACCUM(71),
            ACCUM(70)=>fmac_ACCUM(70),ACCUM(69)=>fmac_ACCUM(69),ACCUM(68)=>fmac_ACCUM(68),
            ACCUM(67)=>fmac_ACCUM(67),ACCUM(66)=>fmac_ACCUM(66),ACCUM(65)=>fmac_ACCUM(65),
            ACCUM(64)=>fmac_ACCUM(64),ACCUM(63)=>fmac_ACCUM(63),ACCUM(62)=>fmac_ACCUM(62),
            ACCUM(61)=>fmac_ACCUM(61),ACCUM(60)=>fmac_ACCUM(60),ACCUM(59)=>fmac_ACCUM(59),
            ACCUM(58)=>fmac_ACCUM(58),ACCUM(57)=>fmac_ACCUM(57),ACCUM(56)=>fmac_ACCUM(56),
            ACCUM(55)=>fmac_ACCUM(55),ACCUM(54)=>fmac_ACCUM(54),ACCUM(53)=>fmac_ACCUM(53),
            ACCUM(52)=>fmac_ACCUM(52),ACCUM(51)=>fmac_ACCUM(51),ACCUM(50)=>fmac_ACCUM(50),
            ACCUM(49)=>fmac_ACCUM(49),ACCUM(48)=>fmac_ACCUM(48),ACCUM(47)=>fmac_ACCUM(47),
            ACCUM(46)=>fmac_ACCUM(46),ACCUM(45)=>fmac_ACCUM(45),ACCUM(44)=>fmac_ACCUM(44),
            ACCUM(43)=>fmac_ACCUM(43),ACCUM(42)=>fmac_ACCUM(42),ACCUM(41)=>fmac_ACCUM(41),
            ACCUM(40)=>fmac_ACCUM(40),ACCUM(39)=>fmac_ACCUM(39),ACCUM(38)=>fmac_ACCUM(38),
            ACCUM(37)=>fmac_ACCUM(37),ACCUM(36)=>fmac_ACCUM(36),ACCUM(35)=>fmac_ACCUM(35),
            ACCUM(34)=>fmac_ACCUM(34),ACCUM(33)=>fmac_ACCUM(33),ACCUM(32)=>fmac_ACCUM(32),
            ACCUM(31)=>fmac_ACCUM(31),ACCUM(30)=>fmac_ACCUM(30),ACCUM(29)=>fmac_ACCUM(29),
            ACCUM(28)=>fmac_ACCUM(28),ACCUM(27)=>fmac_ACCUM(27),ACCUM(26)=>fmac_ACCUM(26),
            ACCUM(25)=>fmac_ACCUM(25),ACCUM(24)=>fmac_ACCUM(24),ACCUM(23)=>fmac_ACCUM(23),
            ACCUM(22)=>fmac_ACCUM(22),ACCUM(21)=>fmac_ACCUM(21),ACCUM(20)=>fmac_ACCUM(20),
            ACCUM(19)=>fmac_ACCUM(19),ACCUM(18)=>fmac_ACCUM(18),ACCUM(17)=>fmac_ACCUM(17),
            ACCUM(16)=>fmac_ACCUM(16),ACCUM(15)=>fmac_ACCUM(15),ACCUM(14)=>fmac_ACCUM(14),
            ACCUM(13)=>fmac_ACCUM(13),ACCUM(12)=>fmac_ACCUM(12),ACCUM(11)=>fmac_ACCUM(11),
            ACCUM(10)=>fmac_ACCUM(10),ACCUM(9)=>fmac_ACCUM(9),ACCUM(8)=>fmac_ACCUM(8),
            ACCUM(7)=>fmac_ACCUM(7),ACCUM(6)=>fmac_ACCUM(6),ACCUM(5)=>fmac_ACCUM(5),
            ACCUM(4)=>fmac_ACCUM(4),ACCUM(3)=>fmac_ACCUM(3),ACCUM(2)=>fmac_ACCUM(2),
            ACCUM(1)=>fmac_ACCUM(1),ACCUM(0)=>fmac_ACCUM(0),B(31)=>fmac_B(31),
            B(30)=>fmac_B(30),B(29)=>fmac_B(29),B(28)=>fmac_B(28),B(27)=>fmac_B(27),
            B(26)=>fmac_B(26),B(25)=>fmac_B(25),B(24)=>fmac_B(24),B(23)=>fmac_B(23),
            B(22)=>fmac_B(22),B(21)=>fmac_B(21),B(20)=>fmac_B(20),B(19)=>fmac_B(19),
            B(18)=>fmac_B(18),B(17)=>fmac_B(17),B(16)=>fmac_B(16),B(15)=>fmac_B(15),
            B(14)=>fmac_B(14),B(13)=>fmac_B(13),B(12)=>fmac_B(12),B(11)=>fmac_B(11),
            B(10)=>fmac_B(10),B(9)=>fmac_B(9),B(8)=>fmac_B(8),B(7)=>fmac_B(7),
            B(6)=>fmac_B(6),B(5)=>fmac_B(5),B(4)=>fmac_B(4),B(3)=>fmac_B(3),
            B(2)=>fmac_B(2),B(1)=>fmac_B(1),B(0)=>fmac_B(0),LD(81)=>fmac_LD(81),
            LD(80)=>fmac_LD(80),LD(79)=>fmac_LD(79),LD(78)=>fmac_LD(78),LD(77)=>fmac_LD(77),
            LD(76)=>fmac_LD(76),LD(75)=>fmac_LD(75),LD(74)=>fmac_LD(74),LD(73)=>fmac_LD(73),
            LD(72)=>fmac_LD(72),LD(71)=>fmac_LD(71),LD(70)=>fmac_LD(70),LD(69)=>fmac_LD(69),
            LD(68)=>fmac_LD(68),LD(67)=>fmac_LD(67),LD(66)=>fmac_LD(66),LD(65)=>fmac_LD(65),
            LD(64)=>fmac_LD(64),LD(63)=>fmac_LD(63),LD(62)=>fmac_LD(62),LD(61)=>fmac_LD(61),
            LD(60)=>fmac_LD(60),LD(59)=>fmac_LD(59),LD(58)=>fmac_LD(58),LD(57)=>fmac_LD(57),
            LD(56)=>fmac_LD(56),LD(55)=>fmac_LD(55),LD(54)=>fmac_LD(54),LD(53)=>fmac_LD(53),
            LD(52)=>fmac_LD(52),LD(51)=>fmac_LD(51),LD(50)=>fmac_LD(50),LD(49)=>fmac_LD(49),
            LD(48)=>fmac_LD(48),LD(47)=>fmac_LD(47),LD(46)=>fmac_LD(46),LD(45)=>fmac_LD(45),
            LD(44)=>fmac_LD(44),LD(43)=>fmac_LD(43),LD(42)=>fmac_LD(42),LD(41)=>fmac_LD(41),
            LD(40)=>fmac_LD(40),LD(39)=>fmac_LD(39),LD(38)=>fmac_LD(38),LD(37)=>fmac_LD(37),
            LD(36)=>fmac_LD(36),LD(35)=>fmac_LD(35),LD(34)=>fmac_LD(34),LD(33)=>fmac_LD(33),
            LD(32)=>fmac_LD(32),LD(31)=>fmac_LD(31),LD(30)=>fmac_LD(30),LD(29)=>fmac_LD(29),
            LD(28)=>fmac_LD(28),LD(27)=>fmac_LD(27),LD(26)=>fmac_LD(26),LD(25)=>fmac_LD(25),
            LD(24)=>fmac_LD(24),LD(23)=>fmac_LD(23),LD(22)=>fmac_LD(22),LD(21)=>fmac_LD(21),
            LD(20)=>fmac_LD(20),LD(19)=>fmac_LD(19),LD(18)=>fmac_LD(18),LD(17)=>fmac_LD(17),
            LD(16)=>fmac_LD(16),LD(15)=>fmac_LD(15),LD(14)=>fmac_LD(14),LD(13)=>fmac_LD(13),
            LD(12)=>fmac_LD(12),LD(11)=>fmac_LD(11),LD(10)=>fmac_LD(10),LD(9)=>fmac_LD(9),
            LD(8)=>fmac_LD(8),LD(7)=>fmac_LD(7),LD(6)=>fmac_LD(6),LD(5)=>fmac_LD(5),
            LD(4)=>fmac_LD(4),LD(3)=>fmac_LD(3),LD(2)=>fmac_LD(2),LD(1)=>fmac_LD(1),
            LD(0)=>fmac_LD(0),ACCUMSLOAD=>fmac_ACCUMSLOAD,ADDNSUB=>fmac_ADDNSUB,
            CE0=>fmac_CE0,CLK0=>fmac_CLK0,OVERFLOW=>fmac_OVERFLOW,RST0=>fmac_RST0);
    main_pll_inst: component main_pll port map (CLKI=>main_pll_CLKI,CLKOP=>main_pll_CLKOP,
            CLKOS=>main_pll_CLKOS,CLKOS2=>open);
    mpy_32x32_inst: component mpy_32x32 port map (DataA(31)=>mpy_32x32_DataA(31),
            DataA(30)=>mpy_32x32_DataA(30),DataA(29)=>mpy_32x32_DataA(29),
            DataA(28)=>mpy_32x32_DataA(28),DataA(27)=>mpy_32x32_DataA(27),
            DataA(26)=>mpy_32x32_DataA(26),DataA(25)=>mpy_32x32_DataA(25),
            DataA(24)=>mpy_32x32_DataA(24),DataA(23)=>mpy_32x32_DataA(23),
            DataA(22)=>mpy_32x32_DataA(22),DataA(21)=>mpy_32x32_DataA(21),
            DataA(20)=>mpy_32x32_DataA(20),DataA(19)=>mpy_32x32_DataA(19),
            DataA(18)=>mpy_32x32_DataA(18),DataA(17)=>mpy_32x32_DataA(17),
            DataA(16)=>mpy_32x32_DataA(16),DataA(15)=>mpy_32x32_DataA(15),
            DataA(14)=>mpy_32x32_DataA(14),DataA(13)=>mpy_32x32_DataA(13),
            DataA(12)=>mpy_32x32_DataA(12),DataA(11)=>mpy_32x32_DataA(11),
            DataA(10)=>mpy_32x32_DataA(10),DataA(9)=>mpy_32x32_DataA(9),DataA(8)=>mpy_32x32_DataA(8),
            DataA(7)=>mpy_32x32_DataA(7),DataA(6)=>mpy_32x32_DataA(6),DataA(5)=>mpy_32x32_DataA(5),
            DataA(4)=>mpy_32x32_DataA(4),DataA(3)=>mpy_32x32_DataA(3),DataA(2)=>mpy_32x32_DataA(2),
            DataA(1)=>mpy_32x32_DataA(1),DataA(0)=>mpy_32x32_DataA(0),DataB(31)=>mpy_32x32_DataB(31),
            DataB(30)=>mpy_32x32_DataB(30),DataB(29)=>mpy_32x32_DataB(29),
            DataB(28)=>mpy_32x32_DataB(28),DataB(27)=>mpy_32x32_DataB(27),
            DataB(26)=>mpy_32x32_DataB(26),DataB(25)=>mpy_32x32_DataB(25),
            DataB(24)=>mpy_32x32_DataB(24),DataB(23)=>mpy_32x32_DataB(23),
            DataB(22)=>mpy_32x32_DataB(22),DataB(21)=>mpy_32x32_DataB(21),
            DataB(20)=>mpy_32x32_DataB(20),DataB(19)=>mpy_32x32_DataB(19),
            DataB(18)=>mpy_32x32_DataB(18),DataB(17)=>mpy_32x32_DataB(17),
            DataB(16)=>mpy_32x32_DataB(16),DataB(15)=>mpy_32x32_DataB(15),
            DataB(14)=>mpy_32x32_DataB(14),DataB(13)=>mpy_32x32_DataB(13),
            DataB(12)=>mpy_32x32_DataB(12),DataB(11)=>mpy_32x32_DataB(11),
            DataB(10)=>mpy_32x32_DataB(10),DataB(9)=>mpy_32x32_DataB(9),DataB(8)=>mpy_32x32_DataB(8),
            DataB(7)=>mpy_32x32_DataB(7),DataB(6)=>mpy_32x32_DataB(6),DataB(5)=>mpy_32x32_DataB(5),
            DataB(4)=>mpy_32x32_DataB(4),DataB(3)=>mpy_32x32_DataB(3),DataB(2)=>mpy_32x32_DataB(2),
            DataB(1)=>mpy_32x32_DataB(1),DataB(0)=>mpy_32x32_DataB(0),Result(63)=>mpy_32x32_Result(63),
            Result(62)=>mpy_32x32_Result(62),Result(61)=>mpy_32x32_Result(61),
            Result(60)=>mpy_32x32_Result(60),Result(59)=>mpy_32x32_Result(59),
            Result(58)=>mpy_32x32_Result(58),Result(57)=>mpy_32x32_Result(57),
            Result(56)=>mpy_32x32_Result(56),Result(55)=>mpy_32x32_Result(55),
            Result(54)=>mpy_32x32_Result(54),Result(53)=>mpy_32x32_Result(53),
            Result(52)=>mpy_32x32_Result(52),Result(51)=>mpy_32x32_Result(51),
            Result(50)=>mpy_32x32_Result(50),Result(49)=>mpy_32x32_Result(49),
            Result(48)=>mpy_32x32_Result(48),Result(47)=>mpy_32x32_Result(47),
            Result(46)=>mpy_32x32_Result(46),Result(45)=>mpy_32x32_Result(45),
            Result(44)=>mpy_32x32_Result(44),Result(43)=>mpy_32x32_Result(43),
            Result(42)=>mpy_32x32_Result(42),Result(41)=>mpy_32x32_Result(41),
            Result(40)=>mpy_32x32_Result(40),Result(39)=>mpy_32x32_Result(39),
            Result(38)=>mpy_32x32_Result(38),Result(37)=>mpy_32x32_Result(37),
            Result(36)=>mpy_32x32_Result(36),Result(35)=>mpy_32x32_Result(35),
            Result(34)=>mpy_32x32_Result(34),Result(33)=>mpy_32x32_Result(33),
            Result(32)=>mpy_32x32_Result(32),Result(31)=>mpy_32x32_Result(31),
            Result(30)=>mpy_32x32_Result(30),Result(29)=>mpy_32x32_Result(29),
            Result(28)=>mpy_32x32_Result(28),Result(27)=>mpy_32x32_Result(27),
            Result(26)=>mpy_32x32_Result(26),Result(25)=>mpy_32x32_Result(25),
            Result(24)=>mpy_32x32_Result(24),Result(23)=>mpy_32x32_Result(23),
            Result(22)=>mpy_32x32_Result(22),Result(21)=>mpy_32x32_Result(21),
            Result(20)=>mpy_32x32_Result(20),Result(19)=>mpy_32x32_Result(19),
            Result(18)=>mpy_32x32_Result(18),Result(17)=>mpy_32x32_Result(17),
            Result(16)=>mpy_32x32_Result(16),Result(15)=>mpy_32x32_Result(15),
            Result(14)=>mpy_32x32_Result(14),Result(13)=>mpy_32x32_Result(13),
            Result(12)=>mpy_32x32_Result(12),Result(11)=>mpy_32x32_Result(11),
            Result(10)=>mpy_32x32_Result(10),Result(9)=>mpy_32x32_Result(9),
            Result(8)=>mpy_32x32_Result(8),Result(7)=>mpy_32x32_Result(7),
            Result(6)=>mpy_32x32_Result(6),Result(5)=>mpy_32x32_Result(5),
            Result(4)=>mpy_32x32_Result(4),Result(3)=>mpy_32x32_Result(3),
            Result(2)=>mpy_32x32_Result(2),Result(1)=>mpy_32x32_Result(1),
            Result(0)=>mpy_32x32_Result(0),Aclr=>mpy_32x32_Aclr,ClkEn=>mpy_32x32_ClkEn,
            Clock=>mpy_32x32_Clock);
    
end architecture main_clocks; -- sbp_module=true 

