library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- channel 0..7 = ada's mux positions 0..7, channel 8..15 = adb's
package adc_scale_pipeline_pkg is

    type adc_scale_pipeline_out_record is record
        scaled_value : std_logic_vector(31 downto 0);
        ready_with_1 : std_logic;
        channel      : std_logic_vector(3 downto 0);
    end record;

    function adc_ready (self : adc_scale_pipeline_out_record) return boolean;
    function get_scaled_value (self : adc_scale_pipeline_out_record) return std_logic_vector;
    function get_channel (self : adc_scale_pipeline_out_record) return std_logic_vector;

end package adc_scale_pipeline_pkg;

package body adc_scale_pipeline_pkg is

    function adc_ready (self : adc_scale_pipeline_out_record) return boolean is
    begin
        return self.ready_with_1 = '1';
    end function;

    function get_scaled_value (self : adc_scale_pipeline_out_record) return std_logic_vector is
    begin
        return self.scaled_value;
    end function;

    function get_channel (self : adc_scale_pipeline_out_record) return std_logic_vector is
    begin
        return self.channel;
    end function;

end package body adc_scale_pipeline_pkg;

------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.dual_port_ram_pkg.all;
    use work.muxed_adc_pkg.all;
    use work.fixed_dsp_pkg.all;
    use work.fpga_interconnect_pkg.all;
    use work.adc_scale_pipeline_pkg.all;

entity adc_scale_pipeline is
    generic(
        -- gain and offset are 32-bit signed values at this radix
        -- (make them with real_to_fixed_pkg.to_fixed(x, 32, g_radix)) ;
        -- raw is an integer count (radix 0), so raw*gain lands at this
        -- radix, offset is added at the same radix, and scaled_value is
        -- that sum shifted back down by g_radix
        g_radix : natural := 20

        ;g_u8_clk_cnt                 : integer := 2
        ;g_u8_clks_per_conversion     : integer := 18
        ;g_sh_counter_latch           : integer := 9
        ;g_mux_switch_delay_in_clocks : natural := 20

        ;g_gain_values   : work.dual_port_ram_pkg.ram_array
        ;g_offset_values : work.dual_port_ram_pkg.ram_array

        ;g_gain_ram_address   : natural
        ;g_offset_ram_address : natural
    );
    port(
        clock : in std_logic

        ;ada_mux   : out std_logic_vector(2 downto 0)
        ;ada_clock : out std_logic
        ;ada_cs    : out std_logic
        ;ada_data  : in std_logic

        ;adb_mux   : out std_logic_vector(2 downto 0)
        ;adb_clock : out std_logic
        ;adb_cs    : out std_logic
        ;adb_data  : in std_logic

        ;bus_to_adc_scaler : in work.fpga_interconnect_pkg.fpga_interconnect_record
        ;bus_from_adc_scaler : out work.fpga_interconnect_pkg.fpga_interconnect_record

        ;muxed_adc_a_in : in muxed_adc_in_record
        ;muxed_adc_b_in : in muxed_adc_in_record

        ;adc_scale_pipeline_out : out adc_scale_pipeline_out_record
    );
end entity adc_scale_pipeline;

architecture rtl of adc_scale_pipeline is

    constant dsp_word_length : natural := 32;

    signal muxed_adc_a_out : muxed_adc_out_record;
    signal muxed_adc_b_out : muxed_adc_out_record;

    constant dp_ram_subtype : dpram_ref_record := create_ref_subtypes(
        datawidth     => 32
        ,addresswidth => 4);

    -- port a of each ram is dedicated to ada/adb's own scanning
    signal gain_ram_in    : dp_ram_subtype.ram_in'subtype  := dp_ram_subtype.ram_in;
    signal gain_ram_out   : dp_ram_subtype.ram_out'subtype;
    signal offset_ram_in  : dp_ram_subtype.ram_in'subtype  := dp_ram_subtype.ram_in;
    signal offset_ram_out : dp_ram_subtype.ram_out'subtype;

    -- port b of each ram is exposed to the host via bus_to_adc_scaler /
    -- bus_from_adc_scaler
    signal gain_ram_b_in    : dp_ram_subtype.ram_in'subtype  := dp_ram_subtype.ram_in;
    signal gain_ram_b_out   : dp_ram_subtype.ram_out'subtype;
    signal offset_ram_b_in  : dp_ram_subtype.ram_in'subtype  := dp_ram_subtype.ram_in;
    signal offset_ram_b_out : dp_ram_subtype.ram_out'subtype;

    signal fixed_dsp_in  : fixed_dsp_in_record(
        a(dsp_word_length-1 downto 0)
        ,d(dsp_word_length-1 downto 0)
        ,b(dsp_word_length-1 downto 0)
        ,c(2*dsp_word_length-1 downto 0)
    );
    signal fixed_dsp_out : fixed_dsp_out_record(
        result(2*dsp_word_length-1 downto 0)
    );

    constant ram_latency : natural := 3;
    constant dsp_latency : natural := 5;
    constant scaling_pipeline_depth : natural := ram_latency + 1 + dsp_latency;
    constant scaling_pipeline_width : natural := 5 ; -- channel & ready

    type std_vector_array is array (natural range <>) of std_logic_vector;
    signal scaling_pipeline : std_vector_array(0 to scaling_pipeline_depth-1)(scaling_pipeline_width-1 downto 0) := (others => (others => '0'));
    signal measurement_pipeline : std_vector_array(0 to ram_latency-1)(15 downto 0) := (others => (others => '0'));

    signal muxed_adc_b_ready : boolean := false;

begin

--------------------------------------------------------
    u_muxed_adc_a : entity work.muxed_adc
    generic map(g_u8_clk_cnt, g_u8_clks_per_conversion, g_sh_counter_latch, g_mux_switch_delay_in_clocks)
    port map(
        clock    => clock
        ,mux_io  => ada_mux
        ,ad_clock => ada_clock
        ,ad_cs    => ada_cs
        ,ad_data  => ada_data
        ,muxed_adc_in  => muxed_adc_a_in
        ,muxed_adc_out => muxed_adc_a_out
    );

--------------------------------------------------------
    u_muxed_adc_b : entity work.muxed_adc
    generic map(g_u8_clk_cnt, g_u8_clks_per_conversion, g_sh_counter_latch, g_mux_switch_delay_in_clocks)
    port map(
        clock    => clock
        ,mux_io  => adb_mux
        ,ad_clock => adb_clock
        ,ad_cs    => adb_cs
        ,ad_data  => adb_data
        ,muxed_adc_in  => muxed_adc_b_in
        ,muxed_adc_out => muxed_adc_b_out
    );

--------------------------------------------------------
    u_dpram_gain : entity work.dual_port_ram
    generic map(g_dpram_subtype => dp_ram_subtype, g_ram_init_values => g_gain_values)
    port map(clock, gain_ram_in, gain_ram_out, gain_ram_b_in, gain_ram_b_out);

--------------------------------------------------------
    u_dpram_offset : entity work.dual_port_ram
    generic map(g_dpram_subtype => dp_ram_subtype, g_ram_init_values => g_offset_values)
    port map(clock, offset_ram_in, offset_ram_out, offset_ram_b_in, offset_ram_b_out);

--------------------------------------------------------
    u_fixed_dsp : entity work.fixed_dsp
    port map(
        clock => clock
        ,fixed_dsp_in  => fixed_dsp_in
        ,fixed_dsp_out => fixed_dsp_out
    );

--------------------------------------------------------
    bus_interface : process(clock)
    begin
        if rising_edge(clock) then

            init_bus(bus_from_adc_scaler);
            init_ram(gain_ram_b_in);
            init_ram(offset_ram_b_in);

            -- one 16-address window per ram (channel 0..7 = ada, 8..15 =
            -- adb). a read of <base + channel> triggers the port b ram
            -- read, whose value comes back on the shared address-0 reply
            -- channel ; a write of <base + channel> updates that channel's
            -- calibration. read and write are told apart by the bus's
            -- own read/write flags, not the address, so one window serves
            -- both.
            if data_is_requested_from_address_range(bus_to_adc_scaler, g_gain_ram_address, g_gain_ram_address+16) then
                request_data_from_ram(gain_ram_b_in, get_address(bus_to_adc_scaler) - g_gain_ram_address);
            end if;

            if ram_read_is_ready(gain_ram_b_out) then
                write_data_to_address(bus_from_adc_scaler, 0, get_ram_data(gain_ram_b_out));
            end if;

            if write_is_requested_to_address_range(bus_to_adc_scaler, g_gain_ram_address, g_gain_ram_address+16) then
                write_data_to_ram(gain_ram_b_in, get_address(bus_to_adc_scaler) - g_gain_ram_address, get_slv_data(bus_to_adc_scaler));
            end if;

            if data_is_requested_from_address_range(bus_to_adc_scaler, g_offset_ram_address, g_offset_ram_address+16) then
                request_data_from_ram(offset_ram_b_in, get_address(bus_to_adc_scaler) - g_offset_ram_address);
            end if;

            if ram_read_is_ready(offset_ram_b_out) then
                write_data_to_address(bus_from_adc_scaler, 0, get_ram_data(offset_ram_b_out));
            end if;

            if write_is_requested_to_address_range(bus_to_adc_scaler, g_offset_ram_address, g_offset_ram_address+16) then
                write_data_to_ram(offset_ram_b_in, get_address(bus_to_adc_scaler) - g_offset_ram_address, get_slv_data(bus_to_adc_scaler));
            end if;

        end if;
    end process bus_interface;

    adc_scale_pipeline_out.ready_with_1 <= fixed_dsp_out.ready_with_1;
    adc_scale_pipeline_out.channel      <= scaling_pipeline(scaling_pipeline_depth-1)(3 downto 0);
    adc_scale_pipeline_out.scaled_value <= std_logic_vector(resize(shift_right(fixed_dsp_out.result, g_radix), 32));

----------------------------------
    process(clock)
    begin
        if rising_edge(clock) then

            init_ram(gain_ram_in);
            init_ram(offset_ram_in);
            init_fixed_dsp(fixed_dsp_in);

            scaling_pipeline <= "00000" & scaling_pipeline(0 to scaling_pipeline_depth-2);
            measurement_pipeline <= x"0000" & measurement_pipeline(0 to ram_latency-2);

            muxed_adc_b_ready <= adc_ready(muxed_adc_b_out) or muxed_adc_b_ready;
            if adc_ready(muxed_adc_a_out) then
                measurement_pipeline(0) <= get_adc_result(muxed_adc_a_out);
                request_data_from_ram(gain_ram_in,get_sampled_mux_pos(muxed_adc_a_out));
                request_data_from_ram(offset_ram_in,get_sampled_mux_pos(muxed_adc_a_out));
                scaling_pipeline(0) <= '1' & '0' & get_sampled_mux_pos(muxed_adc_a_out);
            else
                if adc_ready(muxed_adc_b_out) or muxed_adc_b_ready then
                    measurement_pipeline(0) <= get_adc_result(muxed_adc_b_out);
                    request_data_from_ram(gain_ram_in,get_sampled_mux_pos(muxed_adc_b_out)+8);
                    request_data_from_ram(offset_ram_in,get_sampled_mux_pos(muxed_adc_b_out)+8);
                    muxed_adc_b_ready <= false;
                    scaling_pipeline(0) <= '1' & '1' & get_sampled_mux_pos(muxed_adc_b_out);
                end if;
            end if;


            if ram_read_is_ready(gain_ram_out) then

                -- raw (radix 0) * gain (radix g_radix) = product at radix
                -- g_radix ; offset is stored at that same radix, so it is
                -- sign-extended into the product width and added directly,
                -- with no shift of its own
                add(fixed_dsp_in
                    ,a => resize(signed('0' & measurement_pipeline(ram_latency-1)), dsp_word_length)
                    ,b => resize(signed(get_ram_data(gain_ram_out)), dsp_word_length)
                    ,c => resize(signed(get_ram_data(offset_ram_out)), 2*dsp_word_length)
                );

            end if;


        end if;
    end process;

end architecture rtl;
