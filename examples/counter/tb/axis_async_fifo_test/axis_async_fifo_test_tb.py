from __future__ import annotations

import os
import random
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb_tools.runner import get_runner

import pytest

import sys

helper_path = os.path.abspath("./../../../../../helper")
sys.path.append(helper_path)

from helper import axis_sink

@cocotb.test()
async def test_count(dut):
    cocotb.start_soon(Clock(dut.s_clk, 10, unit="ns").start())
    await Timer(1, unit='ns')
    cocotb.start_soon(Clock(dut.m_clk, 5, unit="ns").start())

    await Timer(10000, unit='ns')

def test_runner():
    sim = os.getenv("SIM", "icarus")

    # runner.build and runner.test specific parameters
    hdl_toplevel = "axis_async_fifo_test"
    waves = True
    timescale = ("1ns", "1ps")

    # runner.build specific parameters
    sources = []
    sources += ["./../../rtl/axis_async_fifo_test.sv"]
    sources += ["./../../rtl/axis_counter.sv"]
    sources += ["./../../../../rtl/axis_async_fifo.sv"]

    always = True
    build_dir = "sim_build"
   
    # runner.test specific parameter
    test_module = os.path.splitext(os.path.basename(__file__))[0]
    hdl_toplevel_lang = "verilog"
    seed = 0

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
        seed = seed,
        waves=waves,
        timescale=timescale,
    )

if __name__ == "__main__":
    test_runner()