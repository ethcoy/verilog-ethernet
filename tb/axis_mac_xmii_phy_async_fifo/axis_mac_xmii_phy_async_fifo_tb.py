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

async def controller(dut):
    dut.i_xmii_phy_busy.value = 0
    dut.m_axis_tready.value = 0
    while (True):
        await RisingEdge(dut.m_clk)
        while (dut.o_packet_ready.value == 0):
            await RisingEdge(dut.m_clk)
        dut.i_xmii_phy_busy.value = 1
        dut.m_axis_tready.value = 1
        while (dut.m_axis_tlast.value == 0):
            await RisingEdge(dut.m_clk)
        dut.i_xmii_phy_busy.value = 0
        dut.m_axis_tready.value = 0
        

@cocotb.test()
async def test_data_io_and_control(dut):
    cocotb.start_soon(Clock(dut.s_clk, 20, unit="ns").start())
    cocotb.start_soon(Clock(dut.m_clk, 1, unit="ns").start())

    await RisingEdge(dut.s_clk)
    await RisingEdge(dut.m_clk)

    axis_src = axis_source(dut.s_clk, dut.s_axis_tdata, dut.s_axis_tvalid, dut.s_axis_tready, dut.s_axis_tlast)
    axis_snk = axis_sink(dut.m_clk, dut.m_axis_tdata, dut.m_axis_tvalid, dut.m_axis_tready, dut.m_axis_tlast)

    cocotb.start_soon(controller(dut))

    data = []
    for i in range(10):
        print(hex(i))
        data += [i]

    axis_src.send_nowait(data)
    axis_src.send_nowait(data)
    axis_src.send_nowait(data)
    axis_src.send_nowait(data)

    # axis_src.


    for i in range(100):
        print(i)
        await RisingEdge(dut.s_clk)

    # axis_snk = axis_sink(dut.m_clk, dut.m_axis_tdata, dut.m_axis_tvalid, dut.m_axis_tready, dut.m_axis_tlast)

    # cocotb.start_soon(controller(dut))

    # for i in range(100):
    #     print(i)
    #     await RisingEdge(dut.s_clk)

    data_sent = [int(x) for x in axis_src.s_axis_tdata_sent]
    last_sent = [int(x) for x in axis_src.s_axis_tlast_sent]

    data_read = [int(x) for x in axis_snk.m_axis_tdata_read]
    last_read = [int(x) for x in axis_snk.m_axis_tlast_read]

    print(data_sent)
    print(last_sent)
    print()
    print(data_read)
    print(last_read)

    assert data_read == data_sent
    assert last_read == last_sent

def test_runner():
    sim = os.getenv("SIM", "icarus")

    # runner.build and runner.test specific parameters
    hdl_toplevel = "axis_mac_xmii_phy_async_fifo"
    waves = True
    timescale = ("1ns", "1ps")

    # runner.build specific parameters
    sources = []
    sources += ["./../../rtl/axis_mac_xmii_phy_async_fifo.sv"]
    sources += ["./../../rtl/axis_async_fifo.sv"]

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