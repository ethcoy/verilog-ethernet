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

helper_path = os.path.abspath("./../../../helper")
sys.path.append(helper_path)

from helper import axis_source

@cocotb.test()
async def test(dut):

    cocotb.start_soon(Clock(dut.xmii_tx_clk, 20, unit="ns").start())

    src = axis_source(dut.xmii_tx_clk, dut.s_axis_tdata, dut.s_axis_tvalid, dut.s_axis_tready, dut.s_axis_tlast)

    await RisingEdge(dut.xmii_tx_clk)

    data = []
    for i in range(60):
        data += [i]

    src.send_nowait(data)

    await Timer(10000, unit='ns')

    # Be sure to place meaningful assertions in your tests. This is just here as an example of a test that will pass.
    assert 1 == 1

def run_tests():
    sim = os.getenv("SIM", "icarus")

    # runner.build and runner.test specific parameters
    hdl_toplevel = "axis_mac_xmii_tx"
    waves = True
    timescale = ("1ns", "1ps")

    # runner.build specific parameters
    sources = []
    sources += ["./../../rtl/axis_mac_xmii_tx.v"]
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