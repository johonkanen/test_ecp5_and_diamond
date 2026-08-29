library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- a request/response record pair for muxed_adc : a "request_with_1" pulse
-- both starts a conversion and sets the analog mux position that the
-- *next* conversion should use, since the mux + its analog settling take
-- real time and can't affect a conversion that is starting this same cycle
package muxed_adc_pkg is

    type muxed_adc_in_record is record
        request_with_1 : std_logic;
        next_mux_pos    : natural range 0 to 7;
    end record;

    type muxed_adc_out_record is record
        ready_with_1           : std_logic;
        measurement            : std_logic_vector(15 downto 0);
        mux_pos_of_measurement : natural range 0 to 7;
    end record;

    constant init_muxed_adc_in : muxed_adc_in_record := (request_with_1 => '0', next_mux_pos => 0);

    procedure init_muxed_adc (signal self : out muxed_adc_in_record);

    procedure request_measurement (
        signal self  : out muxed_adc_in_record
        ;next_mux_pos : natural
    );

end package muxed_adc_pkg;

package body muxed_adc_pkg is

    procedure init_muxed_adc (signal self : out muxed_adc_in_record) is
    begin
        self.request_with_1 <= '0';
    end procedure;

    procedure request_measurement (
        signal self  : out muxed_adc_in_record
        ;next_mux_pos : natural
    ) is
    begin
        self.request_with_1 <= '1';
        self.next_mux_pos   <= next_mux_pos;
    end procedure;

end package body muxed_adc_pkg;

------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.muxed_adc_pkg.all;

-- wraps spi3w_ads7056_driver with an analog mux select line : the mux is
-- switched the moment a conversion is triggered, but since the mux and its
-- analog settling take real time, the conversion that trigger just started
-- still samples through the *previous* mux position, not the one just
-- requested (a 1 measurement cycle pipeline delay) -- so every reported
-- measurement is tagged with whichever mux position was actually active
-- when its conversion began, not the freshly requested one. the caller
-- must not trigger a new conversion while one is already in flight ; this
-- is enforced here (a request while busy is simply ignored), matching how
-- the underlying driver only honours si_spi_start from its own idle state
entity muxed_adc is
    generic(
        g_u8_clk_cnt             : integer := 2
        ;g_u8_clks_per_conversion : integer := 18
        ;g_sh_counter_latch       : integer := 9
    );
    port(
        clock : in std_logic

        ;mux_io   : out std_logic_vector(2 downto 0)
        ;ad_clock : out std_logic
        ;ad_cs    : out std_logic
        ;ad_data  : in std_logic

        ;muxed_adc_in  : in muxed_adc_in_record
        ;muxed_adc_out : out muxed_adc_out_record
    );
end entity muxed_adc;

architecture rtl of muxed_adc is

    signal spi_busy : std_logic;
    signal spi_rdy  : std_logic;
    signal spi_rx   : std_logic_vector(15 downto 0);

    -- current_mux_pos : the mux position that took effect at the most
    -- recent accepted trigger (i.e. the one in use for the conversion
    -- currently running, or about to be superseded by the next trigger)
    -- converted_mux_pos : a one-trigger-old snapshot of current_mux_pos,
    -- i.e. the mux position that was actually active when the in-flight
    -- conversion began -- this is what gets tagged onto its measurement
    signal current_mux_pos   : natural range 0 to 7 := 0;
    signal converted_mux_pos : natural range 0 to 7 := 0;

begin

    u_spi3w_ads7056_driver : entity work.spi3w_ads7056_driver
    generic map(g_u8_clk_cnt, g_u8_clks_per_conversion, g_sh_counter_latch)
    port map(
        si_spi_clk     => clock
        ,si_pll_lock   => '1'
        ,po_spi_cs     => ad_cs
        ,po_spi_clk_out => ad_clock
        ,pi_spi_serial => ad_data
        ,si_spi_start  => muxed_adc_in.request_with_1
        ,s_spi_busy    => spi_busy
        ,so_spi_rdy    => spi_rdy
        ,so_sh_rdy     => open
        ,b_spi_rx      => spi_rx
    );

    muxed_adc_out.ready_with_1           <= spi_rdy;
    muxed_adc_out.measurement            <= spi_rx;
    muxed_adc_out.mux_pos_of_measurement <= converted_mux_pos;

    process(clock)
    begin
        if rising_edge(clock) then
            if muxed_adc_in.request_with_1 = '1' and spi_busy = '0' then
                mux_io            <= std_logic_vector(to_unsigned(muxed_adc_in.next_mux_pos, mux_io'length));
                converted_mux_pos <= current_mux_pos;
                current_mux_pos   <= muxed_adc_in.next_mux_pos;
            end if;
        end if;
    end process;

end architecture rtl;
