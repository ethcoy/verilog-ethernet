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

from helper import axis_source, axis_sink

from cocotb.simtime import get_sim_time

@cocotb.test()
async def test_data_io(dut):
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())

    dut.s_axis_eth_destination_addr.value = 0xEEEEEEEEEEEE
    dut.s_axis_eth_source_addr.value = 0xFFFFFFFFFFFF
    dut.s_axis_eth_type.value = 0xAAAA
    dut.s_axis_eth_tvalid.value = 1

    await RisingEdge(dut.i_clk)

    axis_src = axis_source(dut.i_clk, dut.s_axis_tdata, dut.s_axis_tvalid, dut.s_axis_tready, dut.s_axis_tlast)
    axis_snk = axis_sink(dut.i_clk, dut.m_axis_tdata, dut.m_axis_tvalid, dut.m_axis_tready, dut.m_axis_tlast)

    data = []
    for i in range(46):
        print(hex(i))
        data += [i]

    axis_src.send_nowait(data)

    for i in range(200):
        await RisingEdge(dut.i_clk)

def test_runner():
    sim = os.getenv("SIM", "icarus")

    # runner.build and runner.test specific parameters
    hdl_toplevel = "axis_mac_tx"
    waves = True
    timescale = ("1ns", "1ps")

    # runner.build specific parameters
    sources = []
    sources += ["./../../rtl/axis_mac_tx.sv"]
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
    test_runner()