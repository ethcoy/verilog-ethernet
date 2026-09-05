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

from helper import axis_sink

# @cocotb.test()
# @cocotb.parametrize(
#     ("number_of_last", [1, 2, 3, 4])
# )
# async def test_count(dut, number_of_last):
    # test bench does not automatically restart when doing this

@cocotb.test()
async def test_count(dut):
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())

    axis_snk = axis_sink(dut.i_clk, dut.m_axis_tdata, dut.m_axis_tvalid, dut.m_axis_tready, dut.m_axis_tlast)

    l = 4

    while (len(axis_snk.m_axis_tdata_read) != l*(2**int(dut.DATA_WIDTH.value))):
        await RisingEdge(dut.i_clk)

    data_read = [int(x) for x in axis_snk.m_axis_tdata_read]
    last_read = [int(x) for x in axis_snk.m_axis_tlast_read]

    data_comp = []
    last_comp = []
    for i in range(l):
        for j in range(2**int(dut.DATA_WIDTH.value)):
            data_comp += [j % (2**int(dut.DATA_WIDTH.value))]
            if (j == (2**int(dut.DATA_WIDTH.value)) - 1):
                last_comp += [1]
            else:
                last_comp += [0]

    print(data_read)
    print(last_read)
    print(data_comp)
    print(last_comp)
    print(int(dut.DATA_WIDTH.value))

    assert data_read == data_comp
    assert last_read == last_comp

@pytest.mark.parametrize("data_width", [1, 2, 4, 8])
def test_runner(data_width):
    sim = os.getenv("SIM", "icarus")

    # runner.build and runner.test specific parameters
    hdl_toplevel = "axis_counter"
    waves = True
    timescale = ("1ns", "1ps")

    # runner.build specific parameters
    sources = []
    sources += ["./../../rtl/axis_counter.sv"]

    always = True
    build_dir = "sim_build"
   
    # runner.test specific parameter
    test_module = os.path.splitext(os.path.basename(__file__))[0]
    parameters = {}
    parameters["DATA_WIDTH"] = data_width
    hdl_toplevel_lang = "verilog"
    seed = 0

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
        seed = seed,
        waves=waves,
        parameters=parameters,
        timescale=timescale,
    )

if __name__ == "__main__":
    test_runner()