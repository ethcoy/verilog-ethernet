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

class mii_sink:
    def __init__(self, mii_tx_clk:LogicObject, mii_txd:LogicArray, mii_tx_en:LogicArray):
        self.mii_tx_clk = mii_tx_clk
        self.mii_txd = mii_txd
        self.mii_tx_en = mii_tx_en
        self.packets_received = []
        cocotb.start_soon(Clock(self.mii_tx_clk, 20, unit="ns").start())
        cocotb.start_soon(self.__mii_sink__())

    async def __mii_sink__(self):
        bytes_received = []
        count = 0
        receiving = False
        while (True):
            await RisingEdge(self.mii_tx_clk)
            if (self.mii_tx_en.value):
                receiving = True
                count = count + 1
                if (count == 1):
                    byte = int(self.mii_txd.value)
                if (count == 2):
                    count = 0
                    byte = byte | (int(self.mii_txd.value) << 4)
                    bytes_received.append(byte)
            else:
                count = 0
                if (receiving):
                    receiving = False
                    self.packets_received.append(bytes_received)
                    bytes_received = []

class rmii_sink:
    def __init__(self, rmii_tx_clk:LogicObject, rmii_txd:LogicArray, rmii_tx_en:LogicArray):
        self.rmii_tx_clk = rmii_tx_clk
        self.rmii_txd = rmii_txd
        self.rmii_tx_en = rmii_tx_en
        self.packets_received = []
        cocotb.start_soon(Clock(self.rmii_tx_clk, 20, unit="ns").start())
        cocotb.start_soon(self.__rmii_sink__())

    async def __rmii_sink__(self):
        bytes_received = []
        count = 0
        receiving = False
        while (True):
            await RisingEdge(self.rmii_tx_clk)
            if (self.rmii_tx_en.value):
                receiving = True
                count = count + 1
                if (count == 1):
                    byte = int(self.rmii_txd.value)
                if (count == 2):
                    byte = byte | (int(self.rmii_txd.value) << 2)
                if (count == 3):
                    byte = byte | (int(self.rmii_txd.value) << 4)
                if (count == 4):
                    count = 0
                    byte = byte | (int(self.rmii_txd.value) << 6)
                    bytes_received.append(byte)
            else:
                count = 0
                if (receiving):
                    receiving = False
                    self.packets_received.append(bytes_received)
                    bytes_received = []

class mii_source:
    def __init__(self, mii_rx_clk:LogicObject, mii_rxd:LogicArray, mii_rx_dv:LogicArray):
        self.mii_rx_clk = mii_rx_clk
        self.mii_rxd = mii_rxd
        self.mii_rx_dv = mii_rx_dv

    async def send_wait(self, data):
        await RisingEdge(self.mii_rx_clk)
        if (len(data) == 0):
            return False
        self.mii_rx_dv.value = 1
        for x in data:
            self.mii_rxd.value = x
            await RisingEdge(self.mii_rx_clk)
        self.mii_rxd.value = 3
        self.mii_rx_dv.value = 0
        return data

class rmii_source:
    def __init__(self, rmii_rx_clk:LogicObject, rmii_rxd:LogicArray, rmii_rx_dv:LogicArray):
        self.rmii_rx_clk = rmii_rx_clk
        self.rmii_rxd = rmii_rxd
        self.rmii_rx_dv = rmii_rx_dv

    async def send_wait(self, data):
        await RisingEdge(self.rmii_rx_clk)
        if (len(data) == 0):
            return False
        self.rmii_rx_dv.value = 1
        for x in data:
            self.rmii_rxd.value = x
            await RisingEdge(self.rmii_rx_clk)
        self.rmii_rxd.value = 3
        self.rmii_rx_dv.value = 0
        return data

def bits_to_bytes(bit_list, bits_per_element):
    bit_list_temp = [bit_list[x:x + int(8/bits_per_element)] for x in range(0, len(bit_list), int(8/bits_per_element))]
    byte_list = [0]*len(bit_list_temp)
    for i in range(len(bit_list_temp)):
        for j in range(len(bit_list_temp[i])):
            byte_list[i] = byte_list[i] | (bit_list_temp[i][j] << (bits_per_element*j))
    return byte_list

@cocotb.test()
async def test_rmii(dut):
    if (dut.XMII_WIDTH.value == 2):
        cocotb.start_soon(Clock(dut.xmii_rx_clk, 20, unit="ns").start())
        xmii_src = rmii_source(dut.xmii_rx_clk, dut.xmii_rxd, dut.xmii_rx_dv)
    if (dut.XMII_WIDTH.value == 4):
        cocotb.start_soon(Clock(dut.xmii_rx_clk, 40, unit="ns").start())
        xmii_src = mii_source(dut.xmii_rx_clk, dut.xmii_rxd, dut.xmii_rx_dv)

    axis_snk = axis_sink(dut.xmii_rx_clk, dut.m_axis_tdata, dut.m_axis_tvalid, None, dut.m_axis_tlast)

    dut.i_rst.value = 1
    await RisingEdge(dut.xmii_rx_clk)
    await RisingEdge(dut.xmii_rx_clk)
    await RisingEdge(dut.xmii_rx_clk)
    dut.i_rst.value = 0

    data_sent = []
    last_positions = []

    data = []
    number_of_bytes = 5
    for i in range(number_of_bytes):
        for j in range(8//int(dut.XMII_WIDTH.value)):
            data += [random.randint(0, 2**int(dut.XMII_WIDTH.value) - 1)]
    rmii_sent = await xmii_src.send_wait(data)
    data_sent += bits_to_bytes(rmii_sent, int(dut.XMII_WIDTH.value))
    last_positions += [0]*number_of_bytes
    last_positions[-1] = 1

    data = []
    number_of_bytes = 10
    for i in range(number_of_bytes):
        for j in range(8//int(dut.XMII_WIDTH.value)):
            data += [random.randint(0, 2**int(dut.XMII_WIDTH.value) - 1)]
    rmii_sent = await xmii_src.send_wait(data)
    data_sent += bits_to_bytes(rmii_sent, int(dut.XMII_WIDTH.value))
    last_positions += [0]*number_of_bytes
    last_positions[-1] = 1

    for i in range(100):
        await RisingEdge(dut.xmii_rx_clk)

    data_read = [int(x) for x in axis_snk.m_axis_tdata_read]
    last_read = [int(x) for x in axis_snk.m_axis_tlast_read]

    print(data_sent)
    print(data_read)
    print()
    print(last_positions)
    print(last_read)

    assert data_read == data_sent
    assert last_read == last_positions

@pytest.mark.parametrize("xmii_width", [2, 4])
def test_runner(xmii_width):
    sim = os.getenv("SIM", "icarus")

    # runner.build and runner.test specific parameters
    hdl_toplevel = "axis_xmii_phy_rx"
    waves = True
    timescale = ("1ns", "1ps")

    # runner.build specific parameters
    sources = []
    sources += ["./../../rtl/axis_xmii_phy_rx.sv"]
    always = True
    build_dir = "sim_build"
   
    # runner.test specific parameter
    test_module = os.path.splitext(os.path.basename(__file__))[0]
    seed = 0
    parameters = {}
    parameters["XMII_WIDTH"] = xmii_width
    hdl_toplevel_lang = "verilog"

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        parameters=parameters,
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
        seed=seed,
        waves=waves,
        parameters=parameters,
        timescale=timescale,
    )

if __name__ == "__main__":
    test_runner()