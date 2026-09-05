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

async def send_udp_packet(dut, source_port, destination_port, length, data):
    source_port = source_port & 0xFFFF
    destination_port = destination_port & 0xFFFF
    length = length & 0xFFFF

    await RisingEdge(dut.i_clk)
    dut.s_axis_udp_source_port.value = source_port
    dut.s_axis_udp_destination_port.value = destination_port
    dut.s_axis_udp_length.value = length
    dut.s_axis_udp_header_tvalid.value = 1
    await RisingEdge(dut.i_clk)
    while (not (dut.s_axis_udp_header_tvalid.value and dut.s_axis_udp_header_tready.value)):
        await RisingEdge(dut.i_clk)
    dut.s_axis_udp_header_tvalid.value = 0

    data = [int(x & 0xFF) for x in data]
    axis_src = axis_source(dut.i_clk, dut.s_axis_tdata, dut.s_axis_tvalid, dut.s_axis_tready, dut.s_axis_tlast)
    data_bytes = await axis_src.send_wait(data)

    header = [
        source_port,
        destination_port,
        length,
        0x0000
    ]

    header_bytes = [
        (source_port >> 8) & 0xFF,
        source_port & 0xFF,
        (destination_port >> 8) & 0xFF,
        destination_port & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF,
        0x00,
        0x00
    ]

    return header, header_bytes, data_bytes

@cocotb.test()
async def test_data_io(dut):
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())

    axis_snk = axis_sink(dut.i_clk, dut.m_axis_tdata, dut.m_axis_tvalid, dut.m_axis_tready, dut.m_axis_tlast)

    data_comp = []

    data = []
    for i in range(1):
        data += [random.randint(0, 2**8 - 1)]

    header, header_bytes, data_bytes = await send_udp_packet(
        dut,
        0x0001,
        0x0002,
        0x0005,
        data
    )

    data_comp += header_bytes
    data_comp += data_bytes

    data = []
    for i in range(100):
        data += [random.randint(0, 2**8 - 1)]

    header, header_bytes, data_bytes = await send_udp_packet(
        dut,
        0x0001,
        0x0002,
        0x0005,
        data
    )

    data_comp += header_bytes
    data_comp += data_bytes

    for i in range(2):
        await RisingEdge(dut.i_clk)
    
    data_read = [int(x) for x in axis_snk.m_axis_tdata_read]

    print(data_read)
    print()
    print(data_comp)
    print()
    print([int(x) for x in axis_snk.m_axis_tlast_read])

    assert data_read == data_comp

def test_runner():
    sim = os.getenv("SIM", "icarus")

    # runner.build and runner.test specific parameters
    hdl_toplevel = "axis_udp_tx"
    waves = True
    timescale = ("1ns", "1ps")

    # runner.build specific parameters
    sources = []
    sources += ["./../../rtl/axis_udp_tx.sv"]

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