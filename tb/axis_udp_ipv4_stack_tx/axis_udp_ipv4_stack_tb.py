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

from helper import axis_source, axis_sink, mii_sink

from binascii import crc32

async def send_udp_header(dut, source_port, destination_port, length):
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

    return header, header_bytes

async def send_ipv4_header(dut, version, ihl, dscp, ecn, length, identification, flags, fragment_offset, 
                           ttl, protocol, source_ip, destination_ip):
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
    destination_ip = destination_ip & 0xFFFFFFFF

    await RisingEdge(dut.i_clk)
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
    dut.s_axis_ipv4_source_ip.value = source_ip
    dut.s_axis_ipv4_destination_ip.value = destination_ip
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
    checksum += (destination_ip >> 16) & 0xFFFF
    checksum += destination_ip & 0xFFFF
    while (checksum >= 2**16):
        checksum = (checksum & 0xFFFF) + (checksum >> 16)
    checksum = (~checksum) & 0xFFFF

    header = [
        version, 
        ihl,
        dscp,
        ecn, 
        length, 
        identification, 
        flags, 
        fragment_offset, 
        ttl, 
        protocol, 
        checksum, 
        source_ip, 
        destination_ip
    ]

    header_bytes = [(version << 4) | ihl, (dscp << 2) | ecn, (length >> 8) & 0xFF,
                    length & 0xFF, (identification >> 8) & 0xFF, identification & 0xFF, 
                    (flags << 5) | (fragment_offset >> 8), fragment_offset & 0xFF, ttl, protocol,
                    (checksum >> 8) & 0xFF, checksum & 0xFF, (source_ip >> 24) & 0xFF, (source_ip >> 16) & 0xFF,
                    (source_ip >> 8) & 0xFF, source_ip & 0xFF, (destination_ip >> 24) & 0xFF, (destination_ip >> 16) & 0xFF,
                    (destination_ip >> 8) & 0xFF, destination_ip & 0xFF]

    return header, header_bytes

async def send_ethernet_header(dut, destination_mac, source_mac, length):
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

    return header, header_bytes

def ethernet_packet_parser(packet):
    preamble_bytes = packet[0:6]
    sfd_byte = [packet[7]]
    destination_mac_bytes = packet[8:13 + 1]
    source_mac_bytes = packet[14:19 + 1]
    length_bytes = packet[20:21 + 1]
    start_of_payload = 22
    end_of_payload = len(packet) - 16
    data_bytes = packet[start_of_payload:end_of_payload]
    fcs_bytes = packet[-16:-12]
    ipg_bytes = packet[-12:]

    destination_mac = 0
    for byte in destination_mac_bytes:
        destination_mac = (destination_mac << 8) + byte

    source_mac = 0
    for byte in source_mac_bytes:
        source_mac = (source_mac << 8) + byte

    length = 0
    for byte in length_bytes:
        length = (length << 8) + byte

    fcs_bytes = [int('{:08b}'.format(x)[::-1], 2) for x in fcs_bytes]
    fcs = 0
    for x in fcs_bytes:
        fcs = (fcs << 8) | x

    return preamble_bytes, sfd_byte, destination_mac, source_mac, length, data_bytes, fcs, ipg_bytes
    
def ipv4_packet_parser(packet):
    version = packet[0] >> 4
    ihl = packet[0] & 0xF
    dscp = packet[1] >> 2
    ecn = packet[1] & 0x3
    length = (packet[2] << 8) | packet[3]
    identification = (packet[4] << 8) | packet[5]
    flags = packet[6] >> 5
    fragment_offset = ((packet[6] & 0x1F) << 8) | packet[7]
    ttl = packet[8]
    protocol = packet[9]
    checksum = (packet[10] << 8) | packet[11]
    source_ip = (packet[12] << 24) | (packet[13] << 16) | (packet[14] << 8) | packet[15]
    destination_ip = (packet[16] << 24) | (packet[17] << 16) | (packet[18] << 8) | packet[19]
    data_bytes = packet[20:length]

    return version, ihl, dscp, ecn, length, identification, flags, fragment_offset, ttl, protocol, checksum, source_ip, destination_ip, data_bytes

def udp_packet_parser(packet):
    source_port = (packet[0] << 8) | packet[1]
    destination_port = (packet[2] << 8) | packet[3]
    length = (packet[4] << 8) | packet[5]
    checksum = (packet[6] << 8) | packet[7]
    data_bytes = packet[8:]

    return source_port, destination_port, length, checksum, data_bytes

@cocotb.test()
async def test_data_io(dut):
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())

    axis_src = axis_source(dut.i_clk, dut.s_axis_tdata, dut.s_axis_tvalid, dut.s_axis_tready, dut.s_axis_tlast)
    mii_snk = mii_sink(dut.xmii_tx_clk, dut.xmii_txd, dut.xmii_tx_en)

    data = [1, 2, 3, 4, 5, 6]
    data_len = len(data)

    header, header_bytes = await send_udp_header(
        dut,
        0x0000,
        0x0000,
        0x0008 + data_len
    )

    header, header_bytes = await send_ipv4_header(
        dut,
        0x4,
        0x5,
        0x00,
        0x0,
        0x0014 + 0x0008 + data_len,
        0x0000,
        0x2,
        0x0000,
        0x40,
        0x11,
        0xc0a80001,
        0xc0a800c7
    )

    header, header_bytes = await send_ethernet_header(
        dut,
        0xc4efbb5a967b,
        0x100000000001,
        0x0800
    )

    data = await axis_src.send_wait(data)

    for i in range(500):
        await RisingEdge(dut.xmii_tx_clk)

    print(mii_snk.packets_received)

    print()

    ethernet_packet_tuple = ethernet_packet_parser(mii_snk.packets_received[0])

    ethernet_preamble_bytes = ethernet_packet_tuple[0]
    ethernet_sfd_byte = ethernet_packet_tuple[1]
    ethernet_destination_mac = ethernet_packet_tuple[2]
    ethernet_source_mac = ethernet_packet_tuple[3]
    ethernet_length = ethernet_packet_tuple[4]
    ethernet_data_bytes = ethernet_packet_tuple[5]
    ethernet_fcs = ethernet_packet_tuple[6]
    ethernet_ipg_bytes = ethernet_packet_tuple[7]

    ipv4_packet_tuple = ipv4_packet_parser(ethernet_data_bytes)

    ipv4_version = ipv4_packet_tuple[0]
    ipv4_ihl = ipv4_packet_tuple[1]
    ipv4_dscp = ipv4_packet_tuple[2]
    ipv4_ecn = ipv4_packet_tuple[3]
    ipv4_length = ipv4_packet_tuple[4]
    ipv4_identification = ipv4_packet_tuple[5]
    ipv4_flags = ipv4_packet_tuple[6]
    ipv4_fragment_offset = ipv4_packet_tuple[7]
    ipv4_ttl = ipv4_packet_tuple[8]
    ipv4_protocol = ipv4_packet_tuple[9]
    ipv4_checksum = ipv4_packet_tuple[10]
    ipv4_source_ip = ipv4_packet_tuple[11]
    ipv4_destination_ip = ipv4_packet_tuple[12]
    ipv4_data_bytes = ipv4_packet_tuple[13]

    udp_packet_tuple = udp_packet_parser(ipv4_data_bytes)

    udp_source_port = udp_packet_tuple[0]
    udp_destination_port = udp_packet_tuple[1]
    udp_length = udp_packet_tuple[2]
    udp_checksum = udp_packet_tuple[3]
    udp_data_bytes = udp_packet_tuple[4]

    print("Ethernet Header Information:")
    print(f"Destination MAC Address: {hex(ethernet_destination_mac)}")
    print(f"Source MAC Address: {hex(ethernet_source_mac)}")
    print(f"Length: {hex(ethernet_length)}")
    print(f"Frame Check Sequence: {hex(ethernet_fcs)}")
    print()
    print("IPv4 Header Information:")
    print(f"Version: {hex(ipv4_version)}")
    print(f"IHL: {hex(ipv4_ihl)}")
    print(f"DSCP: {hex(ipv4_dscp)}")
    print(f"ECN: {hex(ipv4_ecn)}")
    print(f"Total Length: {ipv4_length}")
    print(f"Identificaiton: {hex(ipv4_identification)}")
    print(f"Flags: {hex(ipv4_flags)}")
    print(f"Fragment Offset: {hex(ipv4_fragment_offset)}")
    print(f"Time to Live: {hex(ipv4_ttl)}")
    print(f"Protocol: {hex(ipv4_protocol)}")
    print(f"Header Checksum: {hex(ipv4_checksum)}")
    print(f"Source IP Address: {hex(ipv4_source_ip)}")
    print(f"Destination IP Address: {hex(ipv4_destination_ip)}")
    print()
    print("UDP Header Information:")
    print(f"Source Port: {hex(udp_source_port)}")
    print(f"Destination Port: {hex(udp_destination_port)}")
    print(f"Length: {udp_length}")
    print(f"Checksum: {hex(udp_checksum)}")
    print()
    print("Data:")
    print(udp_data_bytes)

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