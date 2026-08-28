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

    axis_src_eth_dest = axis_source(dut.i_clk, dut.s_axis_eth_destination_addr, dut.s_axis_eth_tvalid, dut.s_axis_eth_tready)
    axis_src_eth_src = axis_source(dut.i_clk, dut.s_axis_eth_source_addr, dut.s_axis_eth_tvalid, dut.s_axis_eth_tready)
    axis_src_eth_type = axis_source(dut.i_clk, dut.s_axis_eth_type, dut.s_axis_eth_tvalid, dut.s_axis_eth_tready)

    eth_dest = [0x1, 0x2, 0x3, 0x4, 0x5]
    eth_src = [0x5, 0x4, 0x3, 0x2, 0x1]
    eth_type = [0x11, 0x22, 0x33, 0x44, 0x55]

    axis_src_eth_dest.send_nowait(eth_dest)
    axis_src_eth_src.send_nowait(eth_src)
    axis_src_eth_type.send_nowait(eth_type)

    axis_src = axis_source(dut.i_clk, dut.s_axis_tdata, dut.s_axis_tvalid, dut.s_axis_tready, dut.s_axis_tlast)
    axis_snk = axis_sink(dut.i_clk, dut.m_axis_tdata, dut.m_axis_tvalid, dut.m_axis_tready, dut.m_axis_tlast)

    data = []
    # l = 1
    # for i in range(l):
    data += [5]

    axis_src.send_nowait(data)

    data = []
    l = 10
    for i in range(l):
        data += [i]

    axis_src.send_nowait(data)

    data = []
    l = 43
    for i in range(l):
        data += [i]

    axis_src.send_nowait(data)

    data = []
    l = 100
    for i in range(l):
        data += [i]

    axis_src.send_nowait(data)

    data = []
    l = 132
    for i in range(l):
        data += [i]

    axis_src.send_nowait(data)

    for i in range(2000):
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