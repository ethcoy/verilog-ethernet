import cocotb

import os
import random

from cocotb import simulator
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Event, Timer

from cocotb_test.simulator import run

import numpy as np

@cocotb.test()
async def crc(dut):

    dut.i_rst.value = 0
    dut.i_clk.value = 0

    dut.i_data.value = 0xEE
    dut.i_data_valid.value = 0

    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())

    await Timer(200, unit='ns')

    print(hex(int(dut.crc_next.value)))
    print(hex(int(dut.o_crc.value)))

parameters = {}
parameters['c_DATA_WIDTH'] = 8
parameters['c_GEN_POLY'] = 0x55
parameters['c_GEN_POLY_WIDTH'] = 8

c_DATA_WIDTH = parameters['c_DATA_WIDTH']
c_GEN_POLY = parameters['c_GEN_POLY']
c_GEN_POLY_WIDTH = parameters['c_GEN_POLY_WIDTH']

if __name__ == "__main__":
    run(verilog_sources = [
            './../../rtl/crc.v',
        ],
        includes = [
        ],
        toplevel = "crc",
        module = "crc_tb",
        parameters = parameters,
        sim_build = "sim_build/",
        timescale = "1ns/1ps",
        force_compile = True,
        seed = int(0),
        waves = 1,
    )