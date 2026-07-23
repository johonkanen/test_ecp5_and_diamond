library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity mpy_32x32
		port (
            Clock   : in  std_logic
            ;ClkEn  : in  std_logic
            ;Aclr   : in  std_logic
            ;DataA  : in  std_logic_vector(31 downto 0)
            ;DataB  : in  std_logic_vector(31 downto 0)
            ;Result : out  std_logic_vector(63 downto 0)
        );
end entity;

architecture sim of mpy_32x32 is

    type sign_array is array (natural range <>) of signed;
    signal result_buffer : sign_array(2 downto 0)(Result'range);

begin

    result_buffer <= result_buffer(1 downto 0) & signed(DataA) * signed(DataB) when rising_edge(Clock);

end sim;
