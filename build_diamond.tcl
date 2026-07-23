variable path_to_this_file [ file dirname [ file normalize [ info script ] ] ] 
puts $path_to_this_file
set outputDir ./output
set source_folder $path_to_this_file/../source
file mkdir $outputDir

set files [glob -nocomplain "$outputDir/*"]
if {[llength $files] != 0} {
    # clear folder contents
    puts "deleting contents of $outputDir"
    file delete -force {*}[glob -directory $outputDir *]; 
}


prj_project new -name ecp5_compile \
    -impl "impl1" \
    -dev LFE5U-12F-8BG381C \
    -impl_dir $outputDir \
    -synthesis "Synplify" \

prj_src add $path_to_this_file/ip/main_clocks/main_clocks.sbx

prj_strgy set_value -strategy Strategy1 syn_arrange_vhdl_files=True
prj_strgy set_value -strategy Strategy1 par_pathbased_place=On
prj_strgy set_value -strategy Strategy1 map_reg_retiming=True
prj_strgy set_value -strategy Strategy1 syn_update_compile_pt_timing_data=True 
#do not change area setting, synthesis will crash if syn_area = true
prj_strgy set_value -strategy Strategy1 syn_area=False
#If retiming is not on, Synplify will crash for some reason
prj_strgy set_value -strategy Strategy1 map_timing_driven=True map_timing_driven_node_replication=True map_timing_driven_pack=True
prj_strgy set_value -strategy Strategy1 syn_res_sharing=False
prj_strgy set_value -strategy Strategy1 syn_allow_dup_modules=True
prj_strgy set_value -strategy Strategy1 syn_frequency=150
prj_strgy set_value -strategy Strategy1 syn_fsm_encoding=True
prj_strgy set_value -strategy Strategy1 syn_vhdl2008=True

#make better fit
prj_strgy set_value -strategy Strategy1 {syn_pipelining_retiming=Pipelining and Retiming}
prj_strgy set_value -strategy Strategy1 par_place_iterator=3
prj_strgy set_value -strategy Strategy1 par_route_delay_reduction_pass=4
prj_strgy set_value -strategy Strategy1 par_routing_res_opt=4
prj_strgy set_value -strategy Strategy1 par_stop_zero=True

prj_strgy set_value -strategy Strategy1 syn_output_netlist_format=VHDL


proc add_vhdl_file_to_project {vhdl_file} {
    prj_src add $vhdl_file
}

proc add_vhdl_file_to_library {vhdl_file library} {
    prj_src add $vhdl_file -work $library
}


# crashes the build if not instantiated
# add_vhdl_file_to_project $path_to_this_file/fixed_dsp.vhd

add_vhdl_file_to_project $path_to_this_file/source/fpga_communication/hVHDL_uart/uart_rx/uart_rx_pkg.vhd
add_vhdl_file_to_project $path_to_this_file/source/fpga_communication/hVHDL_uart/uart_tx/uart_tx_pkg.vhd
add_vhdl_file_to_project $path_to_this_file/source/fpga_communication/hVHDL_fpga_interconnect/fpga_interconnect_generic_pkg.vhd
add_vhdl_file_to_project $path_to_this_file/source/fpga_communication/fpga_interconnect_16bit_pkg.vhd
add_vhdl_file_to_project $path_to_this_file/source/fpga_communication/ecp5/ecp5_communications.vhd
add_vhdl_file_to_project $path_to_this_file/source/fpga_communication/ecp5/ecp5_serial_protocol_generic_pkg.vhd
# microprogram processor modules
add_vhdl_file_to_project $path_to_this_file/source/hVHDL_microprogam_processor/source/hVHDL_memory_library/vhdl2008/dp_ram_w_configurable_recrods.vhd
add_vhdl_file_to_project $path_to_this_file/source/hVHDL_microprogam_processor/source/hVHDL_memory_library/vhdl2008/arch_rtl_dp_ram_w_configurable_records.vhd
add_vhdl_file_to_project $path_to_this_file/source/hVHDL_microprogam_processor/source/hVHDL_memory_library/vhdl2008/mpram_w_configurable_records.vhd

add_vhdl_file_to_project $path_to_this_file/source/hVHDL_microprogam_processor/vhdl2008/vhdl2008_microinstruction_pkg.vhd
add_vhdl_file_to_project $path_to_this_file/microinstruction_pkg.vhd

add_vhdl_file_to_project $path_to_this_file/source/hVHDL_microprogam_processor/vhdl2008/microprogram_processor_pkg.vhd
add_vhdl_file_to_project $path_to_this_file/source/hVHDL_microprogam_processor/vhdl2008/microprogram_sequencer.vhd
add_vhdl_file_to_project $path_to_this_file/source/hVHDL_microprogam_processor/vhdl2008/microprogram_controller.vhd
add_vhdl_file_to_project $path_to_this_file/source/hVHDL_microprogam_processor/vhdl2008/addsub.vhd
add_vhdl_file_to_project $path_to_this_file/source/hVHDL_microprogam_processor/vhdl2008/fixed_dsp.vhd
add_vhdl_file_to_project $path_to_this_file/source/hVHDL_microprogam_processor/vhdl2008/arch_rtl_fixed_dsp.vhd
# end microprogram processor modules

add_vhdl_file_to_project $path_to_this_file/top.vhd

prj_src add -exclude $path_to_this_file/ecp5_compile.lpf
prj_src enable $path_to_this_file/ecp5_compile.lpf
prj_src remove ecp5_compile.lpf
file delete -force ecp5_compile.lpf

# build project
prj_run Synthesis -impl impl1
prj_run Translate -impl impl1
prj_run Map -impl impl1
prj_run PAR -impl impl1
prj_run Export -impl impl1 -task Bitgen
prj_run Export -impl impl1 -task Promgen
prj_project save
