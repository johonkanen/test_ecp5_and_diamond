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
        print("  @%-4d %-8s %5d" % (adc_raw_base + channel, name, read_adc_raw(channel)))

def read_adc_scaler_calibration():
    scale = float(2 ** adc_scaler_radix)
    print("adc scaler per-channel calibration (fixed point, radix", adc_scaler_radix, "):")
    for channel in range(16):
        name = ("ada_ch%d" % channel) if channel < 8 else ("adb_ch%d" % (channel - 8))
        gain = read_adc_scaler_gain(channel)
        offset = read_adc_scaler_offset(channel)
        print("  %-8s gain @%-4d %11d (%+.4f)   offset @%-4d %11d (%+.4f)"
              % (name, adc_scaler_gain_base + channel, gain, gain / scale,
                 adc_scaler_offset_base + channel, offset, offset / scale))

def _channel_name(channel):
    return "ada_ch%d" % channel if channel < 8 else "adb_ch%d" % (channel - 8)

def _scaled_mean(channel, points):
    address = bus_constants["address_ada_ch0"] + channel
    return float(np.mean(to_signed32(uart.stream_data_from_address(address, points))))

def _poll_stable_mean(channel, points, tol, attempts):
    """Stream <points> samples three times ; return the mean once the
    three means agree within <tol> (the input has settled)."""
    name = _channel_name(channel)
    for _ in range(attempts):
        means = [_scaled_mean(channel, points) for _ in range(3)]
        spread = max(means) - min(means)
        print("  %-8s means [%s]  spread %.2f"
              % (name, ", ".join("%.1f" % m for m in means), spread))
        if spread <= tol:
            return sum(means) / 3.0
    raise RuntimeError("%s did not settle within tol %.2f after %d attempts"
                       % (name, tol, attempts))

def _fit_and_write(channel, raws, volts, out_per_volt):
    """least-squares fit  scaled = raw*gain + offset  through
    (mean_raw, volt*out_per_volt) and write the fixed-point gain/offset."""
    scale = 1 << adc_scaler_radix
    name = _channel_name(channel)
    targets = [v * out_per_volt for v in volts]
    m, b = np.polyfit(raws, targets, 1)                # scaled = m*raw + b
    gain, offset = int(round(m * scale)), int(round(b * scale))
    for label, val in (("gain", gain), ("offset", offset)):
        if not -(2 ** 31) <= val <= 2 ** 31 - 1:
            raise ValueError("%s %s %+d does not fit signed 32 bit" % (name, label, val))
    write_adc_scaler_gain(channel, gain)
    write_adc_scaler_offset(channel, offset)
    resid = max(abs(t - (m * r + b)) for r, t in zip(raws, targets))
    print("  %-8s gain %+d (%.6g/count)  offset %+d (%+.2f)  max residual %.2f"
          % (name, gain, m, offset, b, resid))
    return gain, offset

def calibrate_channel(channel, volts=(1.0, 2.0, 3.0), out_per_volt=1000.0,
                      points=20000, tol=1.0, attempts=8):
    """Multi-point fixed-point calibration of one adc channel.

    For each reference voltage in <volts> : prompts you to apply it, polls
    the channel until three successive <points>-sample means agree within
    <tol> (the "3 correct values"), and records the mean raw code. Then
    least-squares fits  scaled = raw*gain + offset  through
    (mean_raw, volt * out_per_volt) and writes the fixed-point gain and
    offset (radix adc_scaler_radix).

    out_per_volt sets what the scaled register then reads : 1000 (default)
    -> millivolts, (1 << adc_scaler_radix) -> volts as radix-20 fixed point.
    """
    if not 0 <= channel <= 15:
        raise ValueError("channel must be 0..15 (0..7 = ada, 8..15 = adb)")
    if len(volts) < 2:
        raise ValueError("need at least two reference voltages for gain + offset")

    name = _channel_name(channel)
    write_adc_scaler_gain(channel, 1 << adc_scaler_radix)   # identity : streamed == raw
    write_adc_scaler_offset(channel, 0)

    raws = []
    for v in volts:
        input("apply %+.4f V to %s and press enter " % (v, name))
        raws.append(_poll_stable_mean(channel, points, tol, attempts))
        print("  %-8s %+.4f V  ->  raw %.2f" % (name, v, raws[-1]))

    return _fit_and_write(channel, raws, volts, out_per_volt)

def calibrate_all(volts=(1.0, 2.0, 3.0), out_per_volt=1000.0,
                  points=20000, tol=1.0, attempts=8):
    """calibrate_channel for all 16 channels in one reference sweep : each
    voltage is applied once (to every adc input) and all channels measured."""
    for ch in range(16):
        write_adc_scaler_gain(ch, 1 << adc_scaler_radix)
        write_adc_scaler_offset(ch, 0)

    raws = {ch: [] for ch in range(16)}
    for v in volts:
        input("apply %+.4f V to all adc inputs and press enter " % v)
        for ch in range(16):
            raws[ch].append(_poll_stable_mean(ch, points, tol, attempts))

    return {ch: _fit_and_write(ch, raws[ch], volts, out_per_volt) for ch in range(16)}

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
