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

# async def send_header

@cocotb.test()
async def test_data_io(dut):
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())

    dut.s_axis_ipv4_version.value = 0x4
    dut.s_axis_ipv4_ihl.value = 0x5
    dut.s_axis_ipv4_dscp.value = 0
    dut.s_axis_ipv4_ecn.value = 0
    dut.s_axis_ipv4_length.value = 0x0073
    dut.s_axis_ipv4_id.value = 0x0000
    dut.s_axis_ipv4_flags.value = 0b010
    dut.s_axis_ipv4_fragment_offset.value = 0
    dut.s_axis_ipv4_ttl.value = 0x40
    dut.s_axis_ipv4_protocol.value = 0x11
    
    dut.s_axis_ipv4_source_addr.value = 0xc0a80001
    dut.s_axis_ipv4_destination_addr.value = 0xc0a800c7
    
    dut.s_axis_ipv4_header_tvalid.value = 1

    axis_src = axis_source(dut.i_clk, dut.s_axis_tdata, dut.s_axis_tvalid, dut.s_axis_tready, dut.s_axis_tlast)
    axis_snk = axis_sink(dut.i_clk, dut.m_axis_tdata, dut.m_axis_tvalid, dut.m_axis_tready, dut.m_axis_tlast)

    data = []
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

    for i in range(2500):
        await RisingEdge(dut.i_clk)

def test_runner():
    sim = os.getenv("SIM", "icarus")

    # runner.build and runner.test specific parameters
    hdl_toplevel = "axis_ipv4_tx"
    waves = True
    timescale = ("1ns", "1ps")

    # runner.build specific parameters
    sources = []
    sources += ["./../../rtl/axis_ipv4_tx.sv"]

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