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

# single-register bus addresses live in source/address_pkg.vhd as
# "constant address_<name> : natural := <value>;" -- parse them straight
# out of that file so the register dump can't drift out of sync with top.vhd
def load_registers(vhd_path):
    pattern = re.compile(r"constant\s+address_(\w+)\s*:\s*natural\s*:=\s*(\d+)\s*;")
    with open(vhd_path) as f:
        matches = pattern.findall(f.read())
    return dict(sorted((int(address), name) for name, address in matches))

registers = load_registers(os.path.join(abs_path, "source", "address_pkg.vhd"))
sine_result_address = next(address for address, name in registers.items() if name == "sine_result")
adc_channel_addresses = {name: address for address, name in registers.items()
    if name.startswith("ada_ch") or name.startswith("adb_ch")}

def test_hw():
    print("reading all registers")
    for address, name in registers.items():
        print(address, name, to_signed32(get(address)))

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
