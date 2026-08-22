from __future__ import annotations

import os
import random
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb_tools.runner import get_runner

import pytest

@cocotb.test()
async def crc(dut):

    dut.i_rst.value = 0
    dut.i_clk.value = 0

    dut.i_data_valid.value = 0

    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    
    dut.i_data_valid.value = 1

    # data = [0x8c, 0x3b, 0x4a, 0xa2, 0x5d, 0xdb, 0xb8, 0xa5, 0x35, 0x9e, 0x2f, 0x81, 0x86, 0xdd, 0x60, 0x4, 0xd5, 0xe8, 0x0, 0x20, 0x6, 0x77, 0x26, 0x7, 0xf8, 0xb0, 0x40, 0x20, 0xc, 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x5e, 0x26, 0x7, 0xfe, 0xa8, 0xea, 0x22, 0x74, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xf4, 0x69, 0x1, 0xbb, 0x87, 0xd0, 0xcc, 0x23, 0x96, 0x33, 0x8f, 0xae, 0x17, 0x66, 0x80, 0x10, 0x4, 0x14, 0xb7, 0x22, 0x0, 0x0, 0x1, 0x1, 0x8, 0xa, 0x3f, 0xb, 0x80, 0xec, 0xf9, 0x11, 0x8d, 0xb]

    # for i in range(len(data)):
    #     dut.i_data.value = data[i]
    #     await RisingEdge(dut.i_clk)

    dut.i_data.value = 0x00
    # dut.i_data.value = 0x04_76_12_03

    # Literally need to mirror positions of elements before putting into crc

    await RisingEdge(dut.i_clk)

    dut.i_data_valid.value = 0

    await Timer(200, unit='ns')

    print(f'crc_next = {hex(int(dut.crc_next.value))}')
    print(f'o_crc = {hex(int(dut.o_crc.value))}')

parameters = {}
parameters['c_DATA_WIDTH'] = 8
parameters['c_GEN_POLY'] = 0x04C11DB7
parameters['c_GEN_POLY_WIDTH'] = 32
parameters['c_INITIAL_CRC_VALUE'] = 0xFFFFFFFF
parameters['c_REVERSE_INPUT_BIT_ORDER'] = 1
parameters['c_REVERSE_OUTPUT_BIT_ORDER'] = 1
parameters['c_COMPLEMENT_OUTPUT'] = 1

c_DATA_WIDTH = parameters['c_DATA_WIDTH']
c_GEN_POLY = parameters['c_GEN_POLY']
c_GEN_POLY_WIDTH = parameters['c_GEN_POLY_WIDTH']
c_INITIAL_CRC_VALUE = parameters['c_INITIAL_CRC_VALUE']
c_REVERSE_INPUT_BIT_ORDER = parameters['c_REVERSE_INPUT_BIT_ORDER']
c_REVERSE_OUTPUT_BIT_ORDER = parameters['c_REVERSE_OUTPUT_BIT_ORDER']
c_COMPLEMENT_OUTPUT = parameters['c_COMPLEMENT_OUTPUT']

def run_tests():
    sim = os.getenv("SIM", "icarus")

    # runner.build and runner.test specific parameters
    hdl_toplevel = "crc"
    waves = True
    timescale = ("1ns", "1ps")

    # runner.build specific parameters
    sources = []
    sources += ["./../../rtl/crc.v"]

    always = True
    build_dir = "sim_build"
   
    # runner.test specific parameter
    test_module = os.path.splitext(os.path.basename(__file__))[0]
    hdl_toplevel_lang = "verilog"

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        always=always,
        build_dir=build_dir,
        waves=waves,
        timescale=timescale,
    )

    runner.test(
        test_module=test_module,
        hdl_toplevel=hdl_toplevel,
        hdl_toplevel_lang=hdl_toplevel_lang,
        waves=waves,
        timescale=timescale,
    )

if __name__ == "__main__":
    run_tests()