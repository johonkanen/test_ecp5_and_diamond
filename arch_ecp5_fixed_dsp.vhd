LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

entity ecp5_fixed_dsp is
    generic(g_radix : natural);
    port(
        clock : in std_logic := '0'
        ;a    : in signed
        ;d    : in signed
        ;b    : in signed
        ;c    : in signed

        ;accumulate_with_1    : in std_logic -- 0=p <= p + (a*b)
        ;pre_subtract_with_1  : in std_logic -- 0=a+d
        ;post_subtract_with_1 : in std_logic -- 0=mpy_out+d, 1 => mpy_out-d
        ;invert_result_with_1 : in std_logic -- 1 => negate multiplier result
        ;reset_accumulator_with_1 : in std_logic

        ;result : out signed
    );
end entity;

architecture ecp5 of ecp5_fixed_dsp is

	signal mpy_out : std_logic_vector(63 downto 0) := (others => '0');

    signal buf_accumulate               : std_logic_vector(2 downto 0); -- 0=p <= p + (a*b)
    signal buf_pre_subtract             : std_logic_vector(2 downto 0); -- 0=a+d
    signal buf_post_subtract            : std_logic_vector(2 downto 0); -- 0=mpy_out+d, 1 => mpy_out-d
    signal buf_invert_result            : std_logic_vector(2 downto 0); -- 1 => negate multiplier result
    signal buf_reset_accumulator_with_1 : std_logic_vector(2 downto 0);

    signal pre : a'subtype;
    signal res_buf : signed(63 downto 0);
    signal res : signed(63 downto 0);

    signal arg : std_logic_vector(0 to 1);

begin

    pre <= a + d when pre_subtract_with_1 = '0'
     else  a - d;

    u_mpy : entity work.mpy_32x32
    port map(
        Clock   => clock
        ,ClkEn  => '1'
        ,Aclr   => '0'
        ,DataA  => std_logic_vector(pre)
        ,DataB  => std_logic_vector(b)
        ,Result => mpy_out
    );

    arg <= (0 => buf_accumulate(2) , 1 => buf_post_subtract(2));

    process(clock) 
    begin
        if rising_edge(clock) then

            buf_accumulate              <= buf_accumulate(buf_accumulate'high-1 downto 0) & accumulate_with_1;
            buf_pre_subtract            <= buf_pre_subtract(buf_pre_subtract'high-1 downto 0) & pre_subtract_with_1;
            buf_post_subtract           <= buf_post_subtract(buf_post_subtract'high-1 downto 0) & post_subtract_with_1;
            buf_invert_result           <= buf_invert_result(buf_invert_result'high-1 downto 0) & invert_result_with_1;
            buf_reset_accumulator_with_1<= buf_reset_accumulator_with_1(buf_reset_accumulator_with_1'high-1 downto 0) & reset_accumulator_with_1;

            CASE arg is
                WHEN "00" =>
                    res_buf <= signed(mpy_out) + shift_left(resize(c, res'length),g_radix);
                WHEN "01" =>
                    res_buf <= signed(mpy_out) - shift_left(resize(c, res'length),g_radix);
                WHEN "10" =>
                    res_buf <= signed(mpy_out) + res_buf;
                WHEN others => --"11"
                    res_buf <= signed(mpy_out) - res_buf;
            end CASE;
            res <= res_buf;
        
        end if;
    end process;

    result <= res;

end ecp5;
