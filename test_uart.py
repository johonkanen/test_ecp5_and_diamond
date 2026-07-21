import os
import sys

abs_path = os.path.dirname(os.path.realpath(__file__))
sys.path.append(abs_path + './source/fpga_communication/fpga_uart_pc_software/')

# assume that first argument is the comport for example 
# python test_app.py com7
comport = sys.argv[1]

stream_length = 10000

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
