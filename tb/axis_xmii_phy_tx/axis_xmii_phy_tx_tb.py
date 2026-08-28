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

async def send_data(dut, src, data):
    await RisingEdge(dut.xmii_tx_clk)
    src.send_nowait(data)
    dut.i_packet_ready.value = 1
    await RisingEdge(dut.xmii_tx_clk)
    while (not (dut.i_packet_ready.value and (not dut.o_xmii_phy_tx_busy.value))):
        await RisingEdge(dut.xmii_tx_clk)
    dut.i_packet_ready.value = 0

@cocotb.test()
async def test_data_io(dut):
    axis_src = axis_source(dut.xmii_tx_clk, dut.s_axis_tdata, dut.s_axis_tvalid, dut.s_axis_tready, dut.s_axis_tlast)
    mii_snk = mii_sink(dut.xmii_tx_clk, dut.xmii_txd, dut.xmii_tx_en)

    await RisingEdge(dut.xmii_tx_clk)
    await RisingEdge(dut.xmii_tx_clk)
    await RisingEdge(dut.xmii_tx_clk)

    data = []
    l = 1
    for i in range(l):
        data += [random.randint(0, 255)]

    await send_data(dut, axis_src, data)

    data = []
    l = 50
    for i in range(l):
        data += [random.randint(0, 255)]

    await send_data(dut, axis_src, data)

    for i in range(l*5):
        await RisingEdge(dut.xmii_tx_clk)

    data = []
    l = 100
    for i in range(l):
        data += [random.randint(0, 255)]

    await send_data(dut, axis_src, data)

    for i in range(l*5):
        await RisingEdge(dut.xmii_tx_clk)

    data = []
    l = 323
    for i in range(l):
        data += [random.randint(0, 255)]

    await send_data(dut, axis_src, data)

    for i in range(l*5):
        await RisingEdge(dut.xmii_tx_clk)

    data_sent = [int(x) for x in axis_src.s_axis_tdata_sent]
    data_read = []

    for i in range(len(mii_snk.packets_received)):
        for j in range(len(mii_snk.packets_received[i])):
            data_read += [int(mii_snk.packets_received[i][j])]

    print(data_sent)
    print(data_read)

    assert data_read == data_sent

def test_runner():
    sim = os.getenv("SIM", "icarus")

    # runner.build and runner.test specific parameters
    hdl_toplevel = "axis_xmii_phy_tx"
    waves = True
    timescale = ("1ns", "1ps")

    # runner.build specific parameters
    sources = []
    sources += ["./../../rtl/axis_xmii_phy_tx.sv"]

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