
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
    constant address_ada_conversion    : natural := 8;
    constant address_adb_conversion    : natural := 9;
    constant address_llc_ad_conversion : natural := 10;
    constant address_dhb_ad_conversion : natural := 11;
    constant address_test_data9        : natural := 12;
    constant address_sine_result       : natural := 13;

    constant test_memory_address_low  : natural := 100;
    constant test_memory_address_high : natural := 611;

    constant test_memory_write_address_low  : natural := 1000;
    constant test_memory_write_address_high : natural := 1611;

end package;
