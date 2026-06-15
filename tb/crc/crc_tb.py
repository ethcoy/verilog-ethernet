import cocotb

import os
import random

from cocotb import simulator
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Event, Timer

from cocotb_test.simulator import run

import numpy as np

@cocotb.test()
async def crc(dut):

    dut.i_rst.value = 0
    dut.i_clk.value = 0

    dut.i_data_valid.value = 0

    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    
    dut.i_data_valid.value = 1

    dut.i_data.value = 0x03
    await RisingEdge(dut.i_clk)

    dut.i_data.value = 0x11
    await RisingEdge(dut.i_clk)
    
    # dut.i_data.value = 0x33
    # await RisingEdge(dut.i_clk)
        
    # dut.i_data.value = 0x34
    # await RisingEdge(dut.i_clk)
        
    # dut.i_data.value = 0x35
    # await RisingEdge(dut.i_clk)
        
    # dut.i_data.value = 0x36
    # await RisingEdge(dut.i_clk)
        
    # dut.i_data.value = 0x37
    # await RisingEdge(dut.i_clk)
        
    # dut.i_data.value = 0x38
    # await RisingEdge(dut.i_clk)
        
    # dut.i_data.value = 0x39
    # await RisingEdge(dut.i_clk)

    dut.i_data_valid.value = 0

    await Timer(200, unit='ns')

    print(f'crc_next = {hex(int(dut.crc_next.value))}')
    print(f'o_crc = {hex(int(dut.o_crc.value))}')

parameters = {}
parameters['c_DATA_WIDTH'] = 8
parameters['c_GEN_POLY'] = 0x04C11DB7
parameters['c_GEN_POLY_WIDTH'] = 32

c_DATA_WIDTH = parameters['c_DATA_WIDTH']
c_GEN_POLY = parameters['c_GEN_POLY']
c_GEN_POLY_WIDTH = parameters['c_GEN_POLY_WIDTH']

if __name__ == "__main__":
    run(verilog_sources = [
            './../../rtl/crc.v',
        ],
        includes = [
        ],
        toplevel = "crc",
        module = "crc_tb",
        parameters = parameters,
        sim_build = "sim_build/",
        timescale = "1ns/1ps",
        force_compile = True,
        seed = int(0),
        waves = 1,
        defines=
                {"c_COMPLEMENT_OUTPUT": "1",
                 "c_REVERSE_INPUT_BIT_ORDER": "1",
                 "c_REVERSE_OUTPUT_BIT_ORDER": "1"}
    )

# module crc #(
#     parameter c_DATA_WIDTH = 8,
#     parameter c_GEN_POLY = 32'h04c11db7,
#     parameter c_GEN_POLY_WIDTH = 32,
#     parameter c_INITIAL_CRC_VALUE = {c_GEN_POLY_WIDTH{1'b0}},
#     parameter c_REVERSE_BIT_ORDER = 0,
#     parameter c_COMPLEMENT_OUTPUT = 0 
# ) (
#     input wire i_rst,

#     input wire i_clk,

#     input wire [c_DATA_WIDTH - 1:0] i_data,
#     input wire i_data_valid,
#     output wire [c_GEN_POLY_WIDTH - 1:0] o_crc
# );

# reg [c_GEN_POLY_WIDTH - 1:0] r_crc = c_INITIAL_CRC_VALUE;
# reg [c_GEN_POLY_WIDTH - 1:0] crc_next = {c_GEN_POLY_WIDTH{1'b0}};

# assign o_crc = c_COMPLEMENT_OUTPUT ? ~r_crc : r_crc;

# function [c_GEN_POLY_WIDTH - 1:0] crc (input [c_DATA_WIDTH - 1:0] i_data, input [c_GEN_POLY_WIDTH - 1:0] o_crc);
#     reg [0:c_GEN_POLY_WIDTH - 1] A [0:c_GEN_POLY_WIDTH - 1];
#     reg [0:c_GEN_POLY_WIDTH - 1] T0 [0:c_GEN_POLY_WIDTH - 1];
#     reg [0:c_GEN_POLY_WIDTH - 1] T1 [0:c_GEN_POLY_WIDTH - 1];
#     reg [c_GEN_POLY_WIDTH - 1:0] S;
    
#     integer i;
#     integer j;
#     integer k;
#     integer w;
#     begin
#         for (i = 0; i < c_GEN_POLY_WIDTH; i = i + 1) begin
#             S[i] = 0;
#             A[i] = 0;
#             A[i][0] = c_GEN_POLY[c_GEN_POLY_WIDTH - 1 - i];
#             T0[i] = 0;
#             T0[i][i] = 1;
#             T1[i] = 0;
#             if (i > 0) begin
#                 A[i - 1][i] = 1;
#             end
#         end
                
#         for (i = 0; i < c_DATA_WIDTH; i = i + 1) begin
#             if (i == 0) begin
#                 `ifdef c_REVERSE_BIT_ORDER
#                     S = c_GEN_POLY & {c_GEN_POLY_WIDTH{i_data[c_DATA_WIDTH - 1'b1]}};
#                 `else
#                     S = c_GEN_POLY & {c_GEN_POLY_WIDTH{i_data[0]}};
#                 `endif
#             end
            
#             if (i > 0) begin
#                 for (j = 0; j < c_GEN_POLY_WIDTH; j = j + 1) begin
#                     for (k = 0; k < c_GEN_POLY_WIDTH; k = k + 1) begin
#                         for (w = 0; w < c_GEN_POLY_WIDTH; w = w + 1) begin
#                             T1[j][k] = (T0[j][w] & A[w][k]) ^ T1[j][k];
#                         end
#                     end
#                 end
                
#                 for (j = 0; j < c_GEN_POLY_WIDTH; j = j + 1) begin
#                     for (k = 0; k < c_GEN_POLY_WIDTH; k = k + 1) begin
#                         T0[j][k] = T1[j][k];
#                         T1[j][k] = 0;
#                         S[c_GEN_POLY_WIDTH - 1 - j] = T0[j][k] * c_GEN_POLY[c_GEN_POLY_WIDTH - 1 - k] * i_data[i] ^ S[c_GEN_POLY_WIDTH - 1 - j];
#                         `ifdef c_REVERSE_BIT_ORDER
#                             S[c_GEN_POLY_WIDTH - 1 - j] = T0[j][k] * c_GEN_POLY[c_GEN_POLY_WIDTH - 1 - k] * i_data[c_DATA_WIDTH - 1 - i] ^ S[c_GEN_POLY_WIDTH - 1 - j];
#                         `else
#                             S[c_GEN_POLY_WIDTH - 1 - j] = T0[j][k] * c_GEN_POLY[c_GEN_POLY_WIDTH - 1 - k] * i_data[i] ^ S[c_GEN_POLY_WIDTH - 1 - j];
#                         `endif
#                     end
#                 end                
#             end
#         end
        
#         for (j = 0; j < c_GEN_POLY_WIDTH; j = j + 1) begin
#             for (k = 0; k < c_GEN_POLY_WIDTH; k = k + 1) begin
#                 for (w = 0; w < c_GEN_POLY_WIDTH; w = w + 1) begin
#                     T1[j][k] = T0[j][w] * A[w][k] ^ T1[j][k];
#                 end
#             end
#         end
                    
#         for (j = 0; j < c_GEN_POLY_WIDTH; j = j + 1) begin
#             for (k = 0; k < c_GEN_POLY_WIDTH; k = k + 1) begin
#                 T0[j][k] = T1[j][k];
#                 T1[j][k] = 0;
#                 S[c_GEN_POLY_WIDTH - 1 - j] = T0[j][k] * o_crc[c_GEN_POLY_WIDTH - 1 - k] ^ S[c_GEN_POLY_WIDTH - 1 - j];
#             end
#         end
                          
#         crc = S;
#     end
    
# endfunction

# always @(*) begin
#     crc_next = crc(i_data, r_crc);
# end

# always @(posedge i_clk) begin
#     if (i_data_valid) begin
#         r_crc <= crc_next;
#     end
# end

# endmodule