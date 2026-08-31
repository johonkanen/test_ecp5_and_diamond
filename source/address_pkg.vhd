
package address_pkg is

    -- single-register addresses on the test_uart communication bus ;
    -- test_uart.py parses these constant names/values directly out of
    -- this file to label its register dump, so keep the "address_<name>"
    -- naming convention when adding new ones
    constant address_ram_a_readback    : natural := 0;
    constant address_fixed_dsp_result  : natural := 1;
    constant address_test_data1        : natural := 2;
    constant address_test_data2        : natural := 3;
    constant address_test_data3        : natural := 4;
    constant address_test_data4        : natural := 5;
    constant address_test_data5        : natural := 6;
    constant address_test_data6        : natural := 7;
    -- address 8/9 used to be ada_conversion/adb_conversion (a single,
    -- unmuxed reading each) ; ada/adb are muxed_adc scanners now, each
    -- with 8 channels of its own below, so 8/9 are retired rather than
    -- reused, to avoid renumbering everything that follows them
    constant address_llc_ad_conversion : natural := 10;
    constant address_dhb_ad_conversion : natural := 11;
    constant address_test_data9        : natural := 12;
    constant address_sine_result       : natural := 13;

    -- ada/adb continuously round-robin mux positions 0 to 7 ; each
    -- channel's latest scaled reading lands in its own read-only address
    -- (these 16 are contiguous and form a window keyed off address_ada_ch0)
    constant address_ada_ch0 : natural := 14;
    constant address_ada_ch1 : natural := 15;
    constant address_ada_ch2 : natural := 16;
    constant address_ada_ch3 : natural := 17;
    constant address_ada_ch4 : natural := 18;
    constant address_ada_ch5 : natural := 19;
    constant address_ada_ch6 : natural := 20;
    constant address_ada_ch7 : natural := 21;

    constant address_adb_ch0 : natural := 22;
    constant address_adb_ch1 : natural := 23;
    constant address_adb_ch2 : natural := 24;
    constant address_adb_ch3 : natural := 25;
    constant address_adb_ch4 : natural := 26;
    constant address_adb_ch5 : natural := 27;
    constant address_adb_ch6 : natural := 28;
    constant address_adb_ch7 : natural := 29;

    -- debug taps for the scaled-adc datapath : ready-pulse counter (should
    -- climb steadily if adc_scale_pipeline_out.ready_with_1 ever fires)
    -- and the most recent scaled value captured on that pulse, regardless
    -- of which channel it was for
    constant address_adc_ready_count : natural := 30;
    constant address_adc_scaled_last : natural := 31;
    constant address_adc_dbg_a       : natural := 32;
    constant address_adc_dbg_b       : natural := 33;
    constant address_adc_dbg_res_or  : natural := 34;

    -- adc_scale_pipeline's host-facing port b access (live gain/offset
    -- calibration read/write) : each constant is the base of one
    -- 16-address window (one address per channel, 0..7 = ada, 8..15 =
    -- adb) that serves both reads and writes. a read of <base + channel>
    -- triggers the port b ram read and the value comes straight back on
    -- the address-0 reply channel (the same one address_ram_a_readback
    -- uses) ; a write of <base + channel> updates that channel.
    constant adc_scaler_gain_ram_address   : natural := 700;
    constant adc_scaler_offset_ram_address : natural := 750;

    -- base of a read-only 16-address window (one per channel, 0..7 = ada,
    -- 8..15 = adb) holding the raw, unscaled adc code for each channel,
    -- backed by u_dpram_adc_raw in top.vhd
    constant adc_raw_ram_address : natural := 800;

    constant test_memory_address_low  : natural := 100;
    constant test_memory_address_high : natural := 611;

    constant test_memory_write_address_low  : natural := 1000;
    constant test_memory_write_address_high : natural := 1611;

end package;
