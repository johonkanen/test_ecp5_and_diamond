
-- LIBRARY ieee  ; 
--     USE ieee.NUMERIC_STD.all  ; 
--     USE ieee.std_logic_1164.all  ; 
--     use ieee.math_real.all;
--
-- entity fixed_dsp is
--     generic(g_radix : natural);
--     port(
--         clock : in std_logic := '0'
--         ;a    : in signed
--         ;d    : in signed
--         ;b    : in signed
--         ;c    : in signed
--
--         ;accumulate_with_1    : in std_logic -- 0=p <= p + (a*b)
--         ;pre_subtract_with_1  : in std_logic -- 0=a+d
--         ;post_subtract_with_1 : in std_logic -- 0=mpy_out+d, 1 => mpy_out-d
--         ;invert_result_with_1 : in std_logic -- 1 => negate multiplier result
--         ;reset_accumulator_with_1 : in std_logic
--
--         ;result : out signed
--     );
-- end entity;

architecture ecp5 of fixed_dsp is

	signal mpy_out : std_logic_vector(63 downto 0) := (others => '0');

    signal buf_accumulate               : std_logic_vector(2 downto 0); -- 0=p <= p + (a*b)
    signal buf_pre_subtract             : std_logic_vector(2 downto 0); -- 0=a+d
    signal buf_post_subtract            : std_logic_vector(2 downto 0); -- 0=mpy_out+d, 1 => mpy_out-d
    signal buf_invert_result            : std_logic_vector(2 downto 0); -- 1 => negate multiplier result
    signal buf_reset_accumulator_with_1 : std_logic_vector(2 downto 0);

begin

    pre <= a + d when pre_subtract_with_1 = '0'
     else  a - d;

    u_mpy : mpy_32x32
    port map(
        Clock   => clock
        ,ClkEn  => test_data3(0)
        ,Aclr   => test_data3(1)
        ,DataA  => pre
        ,DataB  => b
        ,Result => mpy_out
    );

    process(clk120Mhz) 
    begin
        if rising_edge(clk120Mhz) then

            buf_accumulate              <= buf_accumulate(buf_accumulate'high-1 downto 0) & buf_accumulate;
            buf_pre_subtract            <= buf_pre_subtract(buf_pre_subtract'high-1 downto 0) & buf_pre_subtract;
            buf_post_subtract           <= buf_post_subtract(buf_post_subtract'high-1 downto 0) & buf_post_subtract;
            buf_invert_result           <= buf_invert_result(buf_invert_result'high-1 downto 0) & buf_invert_result;
            buf_reset_accumulator_with_1<= buf_reset_accumulator_with_1(buf_reset_accumulator_with_1'high-1 downto 0) & buf_reset_accumulator_with_1;

            CASE test_data3(3 downto 2) is
                WHEN "00" =>
                    res_buf <= signed(mpy_out) + shift_left(resize(signed(test_data4), res'length),20);
                WHEN "01" =>
                    res_buf <= signed(mpy_out) - shift_left(resize(signed(test_data4), res'length),20);
                WHEN "10" =>
                    res_buf <= signed(mpy_out) - res_buf;
                WHEN others => --"11"
                    res_buf <= signed(mpy_out) + res_buf;
            end CASE;
            res <= res_buf;
        
        end if;
    end process;

end ecp5;
