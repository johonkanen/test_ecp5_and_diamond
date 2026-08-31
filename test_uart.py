import os
import re
import sys
import numpy as np
from matplotlib import pyplot

abs_path = os.path.dirname(os.path.realpath(__file__))
sys.path.append(abs_path + './source/fpga_communication/fpga_uart_pc_software/')

# assume that first argument is the comport for example 
# python test_app.py com7
comport = sys.argv[1]

stream_length = 200000
adc_stream_length = 20000

from uart_communication_functions import *

uart = uart_link(comport, 120e6/25, number_of_databytes = 4)

def set(address, data):
    uart.write_data_to_address(address,data)

def get(address):
    data = uart.request_data_from_address(address)
    return data

def start_stream(address, stream_length = 10):
    uart.request_data_stream_from_address(address, stream_length)

def get_stream(stream_length = 10):
    return uart.get_streamed_data(stream_length)

# registers hold signed 32 bit integers, but the uart link only ever
# reads/streams raw unsigned bytes -- reinterpret as two's complement
def to_signed32(value):
    value = np.asarray(value, dtype=np.int64) & 0xffffffff
    value = np.where(value >= 2**31, value - 2**32, value)
    return value.item() if value.ndim == 0 else value

# bus addresses live in source/address_pkg.vhd as
# "constant <name> : natural := <value>;" -- parse them straight out of
# that file so this script can't drift out of sync with top.vhd
def load_bus_constants(vhd_path):
    pattern = re.compile(r"constant\s+(\w+)\s*:\s*natural\s*:=\s*(\d+)\s*;")
    with open(vhd_path) as f:
        return {name: int(value) for name, value in pattern.findall(f.read())}

address_pkg_path = os.path.join(abs_path, "source", "address_pkg.vhd")
bus_constants = load_bus_constants(address_pkg_path)

# single-register readable addresses, keyed by value -> short name, for the dump
registers = dict(sorted(
    (value, name[len("address_"):])
    for name, value in bus_constants.items() if name.startswith("address_")))
sine_result_address = next(address for address, name in registers.items() if name == "sine_result")
adc_channel_addresses = {name: address for address, name in registers.items()
    if name.startswith("ada_ch") or name.startswith("adb_ch")}

# adc_scale_pipeline exposes its per-channel calibration RAMs on port b :
# reading <gain/offset window base + channel> triggers a port b RAM read
# whose value comes straight back on that same request. channels 0..7 are
# ada mux positions, 8..15 are adb. values are signed fixed point at the
# radix top.vhd's adc_scaler_radix sets (20).
adc_scaler_gain_base   = bus_constants["adc_scaler_gain_ram_address"]
adc_scaler_offset_base = bus_constants["adc_scaler_offset_ram_address"]
adc_scaler_radix = 20  # source/top.vhd : constant adc_scaler_radix

def read_adc_scaler_gain(channel):
    return to_signed32(get(adc_scaler_gain_base + channel))

def read_adc_scaler_offset(channel):
    return to_signed32(get(adc_scaler_offset_base + channel))

def write_adc_scaler_gain(channel, value):
    set(adc_scaler_gain_base + channel, int(value) & 0xffffffff)

def write_adc_scaler_offset(channel, value):
    set(adc_scaler_offset_base + channel, int(value) & 0xffffffff)

# u_dpram_adc_raw : the raw, unscaled adc code per channel (0..7 ada,
# 8..15 adb), read straight back on the request. codes are unsigned.
adc_raw_base = bus_constants["adc_raw_ram_address"]

def read_adc_raw(channel):
    return get(adc_raw_base + channel) & 0xffff

def read_adc_raw_all():
    print("adc raw codes:")
    for channel in range(16):
        name = ("ada_ch%d" % channel) if channel < 8 else ("adb_ch%d" % (channel - 8))
        print("  %-8s %5d" % (name, read_adc_raw(channel)))

def read_adc_scaler_calibration():
    scale = float(2 ** adc_scaler_radix)
    print("adc scaler per-channel calibration (fixed point, radix", adc_scaler_radix, "):")
    for channel in range(16):
        name = ("ada_ch%d" % channel) if channel < 8 else ("adb_ch%d" % (channel - 8))
        gain = read_adc_scaler_gain(channel)
        offset = read_adc_scaler_offset(channel)
        print("  %-8s gain %11d (%+.4f)   offset %11d (%+.4f)"
              % (name, gain, gain / scale, offset, offset / scale))

def test_hw():
    print("reading all registers")
    for address, name in registers.items():
        print(address, name, to_signed32(get(address)))

    read_adc_scaler_calibration()
    read_adc_raw_all()

    print("streaming", stream_length, "points from address", sine_result_address, ", sine_result")
    signed_stream = to_signed32(uart.stream_data_from_address(sine_result_address, stream_length))
    pyplot.figure()
    pyplot.plot(signed_stream)

    print("streaming", adc_stream_length, "points from each of", len(adc_channel_addresses), "adc mux positions")
    pyplot.figure()
    for name, address in sorted(adc_channel_addresses.items(), key=lambda item: item[1]):
        channel_stream = to_signed32(uart.stream_data_from_address(address, adc_stream_length))
        pyplot.plot(channel_stream, label=name)
    pyplot.legend()

    pyplot.show()

test_hw()
