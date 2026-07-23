library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package fixed_dsp_pkg is 

    type fixed_dsp_in_record is record
        a : signed;
        d : signed;
        b : signed;
        c : signed;

        request_with_1           : std_logic;
        accumulate_with_1        : std_logic; -- 0=p <= p + (a*b)
        pre_subtract_with_1      : std_logic; -- 0=a+d
        post_subtract_with_1     : std_logic; -- 0=mpy_out+d, 1 => mpy_out-d
        invert_result_with_1     : std_logic; -- 1 => negate multiplier result
        reset_accumulator_with_1 : std_logic;

    end record;

    procedure init_fixed_dsp (signal self : out fixed_dsp_in_record);

    type fixed_dsp_out_record is record
        ready_with_1 : std_logic;
        result : signed;
    end record;

end package fixed_dsp_pkg;

package body fixed_dsp_pkg is

    procedure init_fixed_dsp (signal self : out fixed_dsp_in_record) is
    begin
        self <= (
            a  => (self.a'range => '0')
            ,d => (self.d'range => '0')
            ,b => (self.b'range => '0')
            ,c => (self.c'range => '0')

            ,request_with_1           => '0'
            ,accumulate_with_1        => '0'-- 0=p <= p + (a*b)
            ,pre_subtract_with_1      => '0'-- 0=a+d
            ,post_subtract_with_1     => '0'-- 0=mpy_out+d, 1 => mpy_out-d
            ,invert_result_with_1     => '0'-- 1 => negate multiplier result
            ,reset_accumulator_with_1 => '0'
        );
    end procedure;

end package body fixed_dsp_pkg;

LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.fixed_dsp_pkg.all;

entity ecp5_fixed_dsp is
    generic(g_radix : natural);
    port(
        clock : in std_logic := '0'
        ;fixed_dsp_in : in fixed_dsp_in_record

        ;ready_with_1 : out std_logic
        ;result : out signed
    );
end entity;

architecture ecp5 of ecp5_fixed_dsp is


    signal buf_accumulate               : std_logic_vector(2 downto 0); -- 0=p <= p + (a*b)
    signal buf_pre_subtract             : std_logic_vector(2 downto 0); -- 0=a+d
    signal buf_post_subtract            : std_logic_vector(2 downto 0); -- 0=mpy_out+d, 1 => mpy_out-d
    signal buf_invert_result            : std_logic_vector(2 downto 0); -- 1 => negate multiplier result
    signal buf_reset_accumulator_with_1 : std_logic_vector(2 downto 0);

    signal pre     : fixed_dsp_in.a'subtype;
    signal mpy_out : std_logic_vector(fixed_dsp_in.a'length*2-1 downto 0) := (others => '0');
    signal res_buf : signed(fixed_dsp_in.a'length*2-1 downto 0);
    signal res     : signed(fixed_dsp_in.a'length*2-1 downto 0);

    signal arg : std_logic_vector(0 to 1);

begin

    pre <= fixed_dsp_in.a + fixed_dsp_in.d when fixed_dsp_in.pre_subtract_with_1 = '0'
     else  fixed_dsp_in.a - fixed_dsp_in.d;

    u_mpy : entity work.mpy_32x32
    port map(
        Clock   => clock
        ,ClkEn  => '1'
        ,Aclr   => '0'
        ,DataA  => std_logic_vector(pre)
        ,DataB  => std_logic_vector(fixed_dsp_in.b)
        ,Result => mpy_out
    );

    arg <= (0 => buf_accumulate(2) , 1 => buf_post_subtract(2));

    process(clock) 
    begin
        if rising_edge(clock) then

            buf_accumulate              <= buf_accumulate(buf_accumulate'high-1 downto 0) & fixed_dsp_in.accumulate_with_1;
            buf_pre_subtract            <= buf_pre_subtract(buf_pre_subtract'high-1 downto 0) & fixed_dsp_in.pre_subtract_with_1;
            buf_post_subtract           <= buf_post_subtract(buf_post_subtract'high-1 downto 0) & fixed_dsp_in.post_subtract_with_1;
            buf_invert_result           <= buf_invert_result(buf_invert_result'high-1 downto 0) & fixed_dsp_in.invert_result_with_1;
            buf_reset_accumulator_with_1<= buf_reset_accumulator_with_1(buf_reset_accumulator_with_1'high-1 downto 0) & fixed_dsp_in.reset_accumulator_with_1;

            CASE arg is
                WHEN "00" =>
                    res_buf <= signed(mpy_out) + shift_left(resize(fixed_dsp_in.c, res'length),g_radix);
                WHEN "01" =>
                    res_buf <= signed(mpy_out) - shift_left(resize(fixed_dsp_in.c, res'length),g_radix);
                WHEN "10" =>
                    res_buf <= signed(mpy_out) + res_buf;
                WHEN others => --"11"
                    res_buf <= signed(mpy_out) - res_buf;
            end CASE;

            if buf_reset_accumulator_with_1(2) = '1' then
                res_buf <= (others => '0');
            end if;
            res <= res_buf;
        
        end if;
    end process;

    result <= res;

end ecp5;
