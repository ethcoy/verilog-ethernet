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

from helper import axis_sink, rmii_sink

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
async def test_count(dut):
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())

    rmii_snk = rmii_sink(dut.xmii_tx_clk, dut.xmii_txd, dut.xmii_tx_en)

    await Timer(40000, unit="ns")

    print(rmii_snk.packets_received)

    ethernet_packet_tuple = ethernet_packet_parser(rmii_snk.packets_received[0])

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
    hdl_toplevel = "axis_tcp_ip_stack"
    waves = True
    timescale = ("1ns", "1ps")

    # runner.build specific parameters
    sources = []
    sources += ["./../../rtl/axis_tcp_ip_stack.sv"]
    sources += ["./../../rtl/axis_counter.sv"]
    sources += ["./../../../../rtl/axis_udp_ipv4_stack_tx.sv"]
    sources += ["./../../../../rtl/axis_udp_tx.sv"]
    sources += ["./../../../../rtl/axis_ipv4_tx.sv"]
    sources += ["./../../../../rtl/axis_mac_tx.sv"]
    sources += ["./../../../../rtl/axis_mac_xmii_phy_async_fifo.sv"]
    sources += ["./../../../../rtl/axis_xmii_phy_tx.sv"]
    sources += ["./../../../../rtl/axis_async_fifo.sv"]
    sources += ["./../../../../rtl/crc.sv"]

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