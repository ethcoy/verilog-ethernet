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

from binascii import crc32

async def send_ethernet_packet(dut, destination_mac, source_mac, length, data):
    destination_mac = destination_mac & 0xFFFFFFFFFFFF
    source_mac = source_mac & 0xFFFFFFFFFFFF
    length = length & 0xFFFF

    await RisingEdge(dut.i_clk)
    dut.s_axis_eth_destination_mac.value = destination_mac
    dut.s_axis_eth_source_mac.value = source_mac
    dut.s_axis_eth_length.value = length
    dut.s_axis_eth_header_tvalid.value = 1
    await RisingEdge(dut.i_clk)
    while (not (dut.s_axis_eth_header_tvalid.value and dut.s_axis_eth_header_tready.value)):
        await RisingEdge(dut.i_clk)
    dut.s_axis_eth_header_tvalid.value = 0

    data = [int(x & 0xFF) for x in data]
    axis_src = axis_source(dut.i_clk, dut.s_axis_tdata, dut.s_axis_tvalid, dut.s_axis_tready, dut.s_axis_tlast)
    data_bytes = await axis_src.send_wait(data)

    header = [
        destination_mac,
        source_mac,
        length
    ]

    header_bytes = [
        (destination_mac >> 40) & 0xFF,
        (destination_mac >> 32) & 0xFF,
        (destination_mac >> 24) & 0xFF,
        (destination_mac >> 16) & 0xFF,
        (destination_mac >> 8) & 0xFF,
        destination_mac & 0xFF,
        (source_mac >> 40) & 0xFF,
        (source_mac >> 32) & 0xFF,
        (source_mac >> 24) & 0xFF,
        (source_mac >> 16) & 0xFF,
        (source_mac >> 8) & 0xFF,
        source_mac & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF
    ]

    if (len(data_bytes) < 46):
        for i in range(46 - len(data_bytes)):
            data_bytes.append(0x00)

    header_data_pad = []
    header_data_pad += header_bytes
    header_data_pad += data_bytes
    header_data_pad = bytes(header_data_pad)

    checksum = crc32(header_data_pad)
    if (checksum < 0):
        checksum = checksum % (1<<32)

    checksum_bytes = [
        (checksum >> 24) & 0xFF,
        (checksum >> 16) & 0xFF,
        (checksum >> 8) & 0xFF,
        checksum & 0xFF
    ]

    checksum_for_phy = [int('{:08b}'.format(x)[::-1], 2) for x in checksum_bytes]

    return header, header_bytes, data_bytes, checksum, checksum_bytes, checksum_for_phy

@cocotb.test()
async def test_data_io(dut):
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())

    for i in range(100):
        await RisingEdge(dut.i_clk)



def test_runner():
    sim = os.getenv("SIM", "icarus")

    # runner.build and runner.test specific parameters
    hdl_toplevel = "axis_udp_ipv4_stack_tx"
    waves = True
    timescale = ("1ns", "1ps")

    # runner.build specific parameters
    sources = []
    sources += ["./../../rtl/axis_udp_ipv4_stack_tx.sv"]
    sources += ["./../../rtl/axis_udp_tx.sv"]
    sources += ["./../../rtl/axis_ipv4_tx.sv"]
    sources += ["./../../rtl/axis_mac_tx.sv"]
    sources += ["./../../rtl/crc.sv"]
    sources += ["./../../rtl/axis_mac_xmii_phy_async_fifo.sv"]
    sources += ["./../../rtl/axis_async_fifo.sv"]
    sources += ["./../../rtl/axis_xmii_phy_tx.sv"]

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