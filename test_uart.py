import os
import sys

abs_path = os.path.dirname(os.path.realpath(__file__))
sys.path.append(abs_path + './source/fpga_communication/fpga_uart_pc_software/')

# assume that first argument is the comport for example 
# python test_app.py com7
comport = sys.argv[1]

from uart_communication_functions import *

uart = uart_link(comport, 120e6/25, number_of_databytes = 4)
