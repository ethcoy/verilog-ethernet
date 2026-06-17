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

    # data = [0x8c, 0x3b, 0x4a, 0xa2, 0x5d, 0xdb, 0xb8, 0xa5, 0x35, 0x9e, 0x2f, 0x81, 0x86, 0xdd, 0x60, 0x4, 0xd5, 0xe8, 0x0, 0x20, 0x6, 0x77, 0x26, 0x7, 0xf8, 0xb0, 0x40, 0x20, 0xc, 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x5e, 0x26, 0x7, 0xfe, 0xa8, 0xea, 0x22, 0x74, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xf4, 0x69, 0x1, 0xbb, 0x87, 0xd0, 0xcc, 0x23, 0x96, 0x33, 0x8f, 0xae, 0x17, 0x66, 0x80, 0x10, 0x4, 0x14, 0xb7, 0x22, 0x0, 0x0, 0x1, 0x1, 0x8, 0xa, 0x3f, 0xb, 0x80, 0xec, 0xf9, 0x11, 0x8d, 0xb]

    # for i in range(len(data)):
    #     dut.i_data.value = data[i]
    #     await RisingEdge(dut.i_clk)

    # dut.i_data.value = 0x03_12_76_04
    dut.i_data.value = 0x04_76_12_03

    # Literally need to mirror positions of elements before putting into crc

    await RisingEdge(dut.i_clk)

    dut.i_data_valid.value = 0

    await Timer(200, unit='ns')

    print(f'crc_next = {hex(int(dut.crc_next.value))}')
    print(f'o_crc = {hex(int(dut.o_crc.value))}')

parameters = {}
parameters['c_DATA_WIDTH'] = 32
parameters['c_GEN_POLY'] = 0x04C11DB7
parameters['c_GEN_POLY_WIDTH'] = 32
# parameters['c_INITIAL_CRC_VALUE'] = 0
parameters['c_INITIAL_CRC_VALUE'] = 0xFFFFFFFF
parameters['c_REVERSE_INPUT_BIT_ORDER'] = 1
parameters['c_REVERSE_OUTPUT_BIT_ORDER'] = 1
parameters['c_COMPLEMENT_OUTPUT'] = 1

c_DATA_WIDTH = parameters['c_DATA_WIDTH']
c_GEN_POLY = parameters['c_GEN_POLY']
c_GEN_POLY_WIDTH = parameters['c_GEN_POLY_WIDTH']
c_INITIAL_CRC_VALUE = parameters['c_INITIAL_CRC_VALUE']
c_REVERSE_INPUT_BIT_ORDER = parameters['c_REVERSE_INPUT_BIT_ORDER']
c_REVERSE_OUTPUT_BIT_ORDER = parameters['c_REVERSE_OUTPUT_BIT_ORDER']
c_COMPLEMENT_OUTPUT = parameters['c_COMPLEMENT_OUTPUT']

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
        # defines=
                # {"c_COMPLEMENT_OUTPUT": "1",
                #  {"c_REVERSE_INPUT_BIT_ORDER": "1"},
                #  "c_REVERSE_OUTPUT_BIT_ORDER": "1"}
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