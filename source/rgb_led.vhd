library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- wraps the rgb-led "heartbeat + pwm" behaviour that used to live as two
-- inline processes in top.vhd (top.vhd:388-443).
--
-- each of the three rgb-led ios has its own pwm : a single counter
-- free-runs 0..g_pwm_max and channel i is high while that counter is
-- below pwm_thresholds(i), so channel i's duty is
-- pwm_thresholds(i)/(g_pwm_max+1). the thresholds are ports, not
-- generics, so they can be retargeted at runtime -- in top.vhd they come
-- from bus registers (test_data5 / test_data6 / ...).
--
-- on top of its pwm, one colour (g_active_bit) is also OR'd with a slow
-- heartbeat toggle : a counter wraps every g_blink_half_period+1 clocks
-- and each wrap flips led_buffer.
--
-- polarity is unchanged from top.vhd : the led vector drives '1' when a
-- channel's pwm (or the heartbeat) is high, which is "off" for a
-- common-anode led -- hold an unused colour off by giving it a threshold
-- of g_pwm_max+1 (pwm permanently high).
entity rgb_led is
    generic (
        g_blink_half_period : natural             := 60_000_000; -- 0.5 s at 120 MHz
        g_pwm_max           : natural             := 2**15 - 1;
        g_active_bit        : natural range 0 to 2 := 0
    );
    port (
        clock          : in  std_logic;
        pwm_thresholds : in  integer_vector(0 to 2);
        rgb_led        : out std_logic_vector(2 downto 0)
    );
end entity rgb_led;

architecture rtl of rgb_led is

    signal blink_counter : natural range 0 to g_blink_half_period := 0;
    signal led_buffer    : std_logic := '0';
    signal pwm_counter   : natural range 0 to g_pwm_max := 0;
    signal pwm           : std_logic_vector(2 downto 0) := (others => '0');

begin

    blinker : process(clock) is
    begin
        if rising_edge(clock) then

            if blink_counter < g_blink_half_period then
                blink_counter <= blink_counter + 1;
            else
                blink_counter <= 0;
            end if;

            if blink_counter = 0 then
                led_buffer <= not led_buffer;
            end if;

            if pwm_counter < g_pwm_max then
                pwm_counter <= pwm_counter + 1;
            else
                pwm_counter <= 0;
            end if;

            for i in pwm'range loop
                if pwm_counter < pwm_thresholds(i) then
                    pwm(i) <= '1';
                else
                    pwm(i) <= '0';
                end if;
            end loop;

        end if;
    end process blinker;

    -- per-channel pwm, plus the heartbeat OR'd into the active colour.
    -- driven per bit because a named non-locally-static choice with
    -- 'others' is illegal in an aggregate.
    drive_outputs : for i in rgb_led'range generate
        rgb_led(i) <= (led_buffer or pwm(i)) when i = g_active_bit
                      else pwm(i);
    end generate;

end architecture rtl;
