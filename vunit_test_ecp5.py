#!/usr/bin/env python3

from pathlib import Path
from vunit import VUnit
import argparse

# Parse extra arguments
parser = argparse.ArgumentParser()
parser.add_argument(
    "--dump-arrays",
    action="store_true",
    help="Enable dumping arrays in the NVC simulator"
)
args, vunit_args = parser.parse_known_args()

ROOT = Path(__file__).resolve().parent
VU = VUnit.from_argv(vunit_args)

MPROC = "source/hVHDL_microprogam_processor"


v2008 = VU.add_library("v2008")

v2008.add_source_files(ROOT / MPROC / "source/hVHDL_fixed_point/real_to_fixed/real_to_fixed_pkg.vhd")
v2008.add_source_files(ROOT / MPROC / "source/hVHDL_memory_library/vhdl2008/dp_ram_w_configurable_recrods.vhd")
v2008.add_source_files(ROOT / MPROC / "source/hVHDL_memory_library/vhdl2008/arch_sim_dp_ram_w_configurable_records.vhd")
v2008.add_source_files(ROOT / MPROC / "source/hVHDL_memory_library/vhdl2008/mpram_w_configurable_records.vhd")
v2008.add_source_files(ROOT / MPROC / "source/hVHDL_floating_point/vhdl2008/*.vhd")
v2008.add_source_files(ROOT / MPROC / "source/hVHDL_floating_point/vhdl2008/altera/multiply_add_arch_agilex.vhd")
v2008.add_source_files(ROOT / MPROC / "source/hVHDL_floating_point/vhdl2008/altera/sim_native_fp32.vhd")

v2008.add_source_files(ROOT / MPROC / "vhdl2008/ram_connector_pkg.vhd")
v2008.add_source_files(ROOT / MPROC / "vhdl2008/instruction_pkg.vhd")
v2008.add_source_files(ROOT / MPROC / "vhdl2008/addsub.vhd")
v2008.add_source_files(ROOT / MPROC / "vhdl2008/microprogram_sequencer.vhd")
v2008.add_source_files(ROOT / MPROC / "vhdl2008/vhdl2008_microinstruction_pkg.vhd")
v2008.add_source_files(ROOT / MPROC / "vhdl2008/def_microinstruction_pkg.vhd")

v2008.add_source_files(ROOT / MPROC / "vhdl2008/microprogram_processor_pkg.vhd")
v2008.add_source_files(ROOT / MPROC / "vhdl2008/microprogram_processor.vhd")
v2008.add_source_files(ROOT / MPROC / "vhdl2008/microprogram_controller.vhd")

# mirrors build_diamond.tcl : the ECP5-targeted (constrained-record)
# entity + the ecp5 architecture that uses the mpy_32x32 hard IP (stood
# in for here by sim_mpy32x32.vhd below), not the generic fixed_dsp.vhd
# / rtl combo used by the hVHDL_fixed_point submodule's own testbench
v2008.add_source_files(ROOT / MPROC / "source/hVHDL_fixed_point/fixed_dsp/fixed_dsp.vhd")
v2008.add_source_files(ROOT / MPROC / "source/hVHDL_fixed_point/fixed_dsp/arch_ecp5_fixed_dsp.vhd")

# sine_calculator resizes its a/b/c operands up to whatever width
# fixed_dsp_in actually has, so it can be driven by the same ecp5
# architecture (native 32x32, wider than lut_sine_pkg's own 16-bit
# angle_word_length) as everything else in this library -- no separate
# rtl-architecture library needed
v2008.add_source_files(ROOT / MPROC / "source/hVHDL_fixed_point/lut_interpolation/lut_sine_pkg.vhd")
v2008.add_source_files(ROOT / MPROC / "source/hVHDL_fixed_point/sine_calculator/sine_calculator.vhd")

v2008.add_source_files(ROOT / MPROC / "source/hVHDL_fixed_point/lut_interpolation/lut_reciprocal_pkg.vhd")
v2008.add_source_files(ROOT / MPROC / "source/hVHDL_fixed_point/reciprocal_calculator/reciprocal_calculator.vhd")

v2008.add_source_files(ROOT / MPROC / "source/hVHDL_fixed_point/lut_interpolation/lut_sqrt_pkg.vhd")
v2008.add_source_files(ROOT / MPROC / "source/hVHDL_fixed_point/sqrt_calculator/sqrt_calculator.vhd")

v2008.add_source_files(ROOT / MPROC / "testbenches/vhdl2008/microprogram_sequencer_tb.vhd")
v2008.add_source_files(ROOT / MPROC / "testbenches/vhdl2008/retry_microprogram_processor_tb.vhd")

v2008.add_source_files(ROOT / MPROC / "vhdl2008/arch_float_mult_add.vhd")
v2008.add_source_files(ROOT / MPROC / "vhdl2008/arch_fixed_mult_add.vhd")
v2008.add_source_files(ROOT / MPROC / "testbenches/vhdl2008/float_microprocessor_tb.vhd")

v2008.add_source_files(ROOT / "source/fpga_communication/hVHDL_fpga_interconnect/fpga_interconnect_generic_pkg.vhd")
v2008.add_source_files(ROOT / "source/fpga_communication/fpga_interconnect_16bit_pkg.vhd")

v2008.add_source_files(ROOT / "sim_mpy32x32.vhd")
v2008.add_source_files(ROOT / "test_processor.vhd")
v2008.add_source_files(ROOT / "arch_processor.vhd")
v2008.add_source_files(ROOT / "arch_ecp_dsp_instruction.vhd")

v2008.add_source_files(ROOT / "testbenches/mpy_32x32_tb.vhd")
# fixed_dsp's own testbench (both the rtl and ecp5 architectures) now lives
# with the relocated source at source/hVHDL_microprogam_processor/source/
# hVHDL_fixed_point/testbenches/fixed_dsp/fixed_dsp_tb.vhd, run via that
# submodule's own vunit_run.py

v2008.add_source_files(ROOT / "testbenches/ecp5_microprocessor_tb.vhd")

v2008.add_source_files(ROOT / "spi3w_ads7056_driver.vhd")
v2008.add_source_files(ROOT / "testbenches/ads7056_entity_tb.vhd")

v2008.add_source_files(ROOT / "muxed_adc.vhd")
v2008.add_source_files(ROOT / "testbenches/muxed_adc_tb.vhd")

v2008.add_source_files(ROOT / "adc_scale_pipeline.vhd")
v2008.add_source_files(ROOT / "testbenches/adc_scale_pipeline_tb.vhd")

v2008.add_source_files(ROOT / "testbenches/dab_modulator_tb.vhd")

# rgb_led module : wraps the "heartbeat + pwm" behaviour of the two
# inline rgb-led processes in top.vhd (top.vhd:388-443) into an entity.
# the testbench runs it against an independent reference model ; counter
# sizes are generics so the sim runs in microseconds instead of 60e6 counts.
v2008.add_source_files(ROOT / "rgb_led.vhd")
v2008.add_source_files(ROOT / "testbenches/rgb_led_blinker_tb.vhd")
rgb_led_blinker_tb = v2008.test_bench("rgb_led_blinker_tb")
# one pwm threshold per rgb-led io. 256 (= g_pwm_max+1) pins a channel
# permanently high, i.e. "off" for a common-anode led.
rgb_led_blinker_tb.add_config(
    name="rgb_led1",  # old rgb_led1 : red blinks/dims, green+blue off
    generics=dict(g_blink_half_period=1000, g_pwm_max=255,
                  g_pwm_threshold_0=100, g_pwm_threshold_1=256, g_pwm_threshold_2=256,
                  g_active_bit=0),
)
rgb_led_blinker_tb.add_config(
    name="rgb_led2",  # old rgb_led2 : green blinks/dims, red+blue off
    generics=dict(g_blink_half_period=1500, g_pwm_max=255,
                  g_pwm_threshold_0=256, g_pwm_threshold_1=200, g_pwm_threshold_2=256,
                  g_active_bit=1),
)
rgb_led_blinker_tb.add_config(
    name="independent_rgb",  # all three colours dimmed to their own level
    generics=dict(g_blink_half_period=900, g_pwm_max=255,
                  g_pwm_threshold_0=64, g_pwm_threshold_1=128, g_pwm_threshold_2=192,
                  g_active_bit=0),
)
rgb_led_blinker_tb.add_config(
    name="pwm_extremes",  # channel always-on, mid, always-off ; heartbeat on blue
    generics=dict(g_blink_half_period=800, g_pwm_max=255,
                  g_pwm_threshold_0=0, g_pwm_threshold_1=128, g_pwm_threshold_2=256,
                  g_active_bit=2),
)

v2008.add_source_files(ROOT / "testbenches/sine_calculator_tb.vhd")
sine_calculator_tb = v2008.test_bench("sine_calculator_tb")
sine_calculator_tb.add_config(name="continuous", generics=dict(use_gaps=False))
sine_calculator_tb.add_config(name="gapped", generics=dict(use_gaps=True))

v2008.add_source_files(ROOT / "testbenches/reciprocal_calculator_tb.vhd")
reciprocal_calculator_tb = v2008.test_bench("reciprocal_calculator_tb")
reciprocal_calculator_tb.add_config(name="continuous", generics=dict(use_gaps=False))
reciprocal_calculator_tb.add_config(name="gapped", generics=dict(use_gaps=True))

v2008.add_source_files(ROOT / "testbenches/sqrt_calculator_tb.vhd")
sqrt_calculator_tb = v2008.test_bench("sqrt_calculator_tb")
sqrt_calculator_tb.add_config(name="continuous", generics=dict(use_gaps=False))
sqrt_calculator_tb.add_config(name="gapped", generics=dict(use_gaps=True))

if args.dump_arrays:
    VU.set_sim_option("nvc.sim_flags", ["-w", "--dump-arrays"])

VU.main()
