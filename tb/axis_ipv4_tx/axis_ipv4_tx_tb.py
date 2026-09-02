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

async def send_ipv4_packet(dut, version, ihl, dscp, ecn, length, identification, flags, fragment_offset, 
                           ttl, protocol, source_ip, dest_ip, data, axis_source):
    version = version & 0xF
    ihl = ihl & 0xF
    dscp = dscp & 0x3F
    ecn = ecn & 0x3
    length = length & 0xFFFF
    identification = identification & 0xFFFF
    flags = flags & 0x7
    fragment_offset = fragment_offset & 0x1FFF
    ttl = ttl & 0xFF
    protocol = protocol & 0xFF
    source_ip = source_ip & 0xFFFFFFFF
    dest_ip = dest_ip & 0xFFFFFFFF

    dut.s_axis_ipv4_version.value = version
    dut.s_axis_ipv4_ihl.value = ihl
    dut.s_axis_ipv4_dscp.value = dscp
    dut.s_axis_ipv4_ecn.value = ecn
    dut.s_axis_ipv4_length.value = length
    dut.s_axis_ipv4_id.value = identification
    dut.s_axis_ipv4_flags.value = flags
    dut.s_axis_ipv4_fragment_offset.value = fragment_offset
    dut.s_axis_ipv4_ttl.value = ttl
    dut.s_axis_ipv4_protocol.value = protocol
    dut.s_axis_ipv4_source_addr.value = source_ip
    dut.s_axis_ipv4_destination_addr.value = dest_ip
    axis_source.send_nowait(data)
    await RisingEdge(dut.i_clk)
    dut.s_axis_ipv4_header_tvalid.value = 1
    await RisingEdge(dut.i_clk)
    while (not (dut.s_axis_ipv4_header_tvalid.value and dut.s_axis_ipv4_header_tready.value)):
        await RisingEdge(dut.i_clk)
    dut.s_axis_ipv4_header_tvalid.value = 0
    checksum = 0
    checksum += ((version << 12) | (ihl << 8) | (dscp << 2) | (ecn))
    checksum += length
    checksum += identification
    checksum += (flags << 13) | fragment_offset
    checksum += (ttl << 8) | protocol
    checksum += (source_ip >> 16) & 0xFFFF
    checksum += source_ip & 0xFFFF
    checksum += (dest_ip >> 16) & 0xFFFF
    checksum += dest_ip & 0xFFFF
    while (checksum >= 2**16):
        checksum = (checksum & 0xFFFF) + (checksum >> 16)
    checksum = (~checksum) & 0xFFFF
    header = [version, ihl, dscp, ecn, length, identification, flags, fragment_offset, ttl, protocol, checksum, source_ip, dest_ip]
    header_bytes = [(version << 4) | ihl, (dscp << 2) | ecn, (length >> 8) & 0xFF,
                    length & 0xFF, (identification >> 8) & 0xFF, identification & 0xFF, 
                    (flags << 5) | (fragment_offset >> 8), fragment_offset & 0xFF, ttl, protocol,
                    (checksum >> 8) & 0xFF, checksum & 0xFF, (source_ip >> 24) & 0xFF, (source_ip >> 16) & 0xFF,
                    (source_ip >> 8) & 0xFF, source_ip & 0xFF, (dest_ip >> 24) & 0xFF, (dest_ip >> 16) & 0xFF,
                    (dest_ip >> 8) & 0xFF, dest_ip & 0xFF]

    return header, header_bytes

@cocotb.test()
async def test_data_io(dut):
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())

    axis_src = axis_source(dut.i_clk, dut.s_axis_tdata, dut.s_axis_tvalid, dut.s_axis_tready, dut.s_axis_tlast)
    axis_snk = axis_sink(dut.i_clk, dut.m_axis_tdata, dut.m_axis_tvalid, dut.m_axis_tready, dut.m_axis_tlast)

    header, header_bytes = await send_ipv4_packet(
        dut,
        0x4,
        0x5,
        0x0,
        0x0,
        0x0073,
        0x0000,
        0x2,
        0x0,
        0x40,
        0x11,
        0xc0a80001,
        0xc0a800c7,
        [101],
        axis_src
    )

    data_comp = []
    data_comp += header_bytes

    for i in range(1000):
        await RisingEdge(dut.i_clk)

    data_sent = [int(x) for x in axis_src.s_axis_tdata_sent]
    data_comp.extend(data_sent)
    axis_src.s_axis_tdata_sent = []

    header, header_bytes = await send_ipv4_packet(
        dut,
        0x4,
        0x5,
        0x0,
        0x0,
        0x0073,
        0x0000,
        0x2,
        0x0,
        0x40,
        0x11,
        0xc0a80001,
        0xc0a800c7,
        [1, 2, 3, 4, 5],
        axis_src
    )

    data_comp += header_bytes

    for i in range(1000):
        await RisingEdge(dut.i_clk)

    data_sent = [int(x) for x in axis_src.s_axis_tdata_sent]
    data_comp.extend(data_sent)
    
    data_read = [int(x) for x in axis_snk.m_axis_tdata_read]

    print(data_read)
    print(data_comp)

    assert data_read == data_comp

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