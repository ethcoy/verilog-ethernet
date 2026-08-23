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

from helper import axis_source

from cocotb.handle import LogicObject
from cocotb.types import LogicArray
from cocotb.simtime import get_sim_time

# class mii_source:
#     def __init__(self, mii_tx_clk:LogicObject, mii_txd:LogicArray, mii_tx_en:LogicArray):
#         self.mii_tx_clk = mii_tx_clk
#         self.mii_txd = mii_txd
#         self.mii_tx_en = mii_tx_en
#         cocotb.start_soon(self.__axis_source__())

#     def send_nowait(self, data, dest=[]):
#         """Drives tdata and tdest with the values passed by the lists 'data' and 'dest'
#         """
#         for i in range(len(data)):
#             self.tdata_queue.put_nowait(data[i])
#             if (i == len(data) - 1):
#                 self.tlast_queue.put_nowait(1)
#             else:
#                 self.tlast_queue.put_nowait(0)
#         if (self.s_axis_tdest != None):
#             for i in range(len(dest)):
#                 self.tdest_queue.put_nowait(dest[i])
#         self.tdata_present.set()

#     async def __mii_source__(self):

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

@cocotb.test()
async def test(dut):
    axis_src = axis_source(dut.xmii_tx_clk, dut.s_axis_tdata, dut.s_axis_tvalid, dut.s_axis_tready, dut.s_axis_tlast)
    mii_snk = mii_sink(dut.xmii_tx_clk, dut.xmii_txd, dut.xmii_tx_en)

    await RisingEdge(dut.xmii_tx_clk)

    data = []
    for i in range(20):
        print(hex(i))
        data += [i]

    axis_src.send_nowait(data)
    axis_src.send_nowait(data)

    await Timer(8000, unit='ns')

    for i in range(len(mii_snk.packets_received)):
        print([hex(x) for x in mii_snk.packets_received[i]])
        print(len(mii_snk.packets_received[i]))
        print()

    # Be sure to place meaningful assertions in your tests. This is just here as an example of a test that will pass.
    assert 1 == 1

def run_tests():
    sim = os.getenv("SIM", "icarus")

    # runner.build and runner.test specific parameters
    hdl_toplevel = "axis_mac_xmii_tx"
    waves = True
    timescale = ("1ns", "1ps")

    # runner.build specific parameters
    sources = []
    sources += ["./../../rtl/axis_mac_xmii_tx.v"]
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
    run_tests()