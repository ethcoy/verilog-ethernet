/*

MIT License

Copyright (c) 2026 Ethan Coyle

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

module crc #(
    parameter DATA_WIDTH = 32,
    parameter GEN_POLY = 32'h04c11db7,
    parameter GEN_POLY_WIDTH = 32,
    parameter INITIAL_CRC_VALUE = {GEN_POLY_WIDTH{1'b1}},
    parameter REVERSE_INPUT_BIT_ORDER = 1,
    parameter REVERSE_OUTPUT_BIT_ORDER = 1,
    parameter COMPLEMENT_OUTPUT = 1
) (
    input wire logic i_clk,
    input wire logic i_rst,

    input wire logic [DATA_WIDTH - 1:0] i_data,
    input wire logic i_data_valid,
    output wire logic [GEN_POLY_WIDTH - 1:0] o_crc
);

logic [GEN_POLY_WIDTH - 1:0] r_crc = INITIAL_CRC_VALUE;
logic [GEN_POLY_WIDTH - 1:0] crc_next = {GEN_POLY_WIDTH{1'b0}};
logic [GEN_POLY_WIDTH - 1:0] t_crc;

assign o_crc = t_crc;

function [GEN_POLY_WIDTH - 1:0] crc (input [DATA_WIDTH - 1:0] i_data, input [GEN_POLY_WIDTH - 1:0] i_crc);
    logic [0:GEN_POLY_WIDTH - 1] A [0:GEN_POLY_WIDTH - 1];
    logic [0:GEN_POLY_WIDTH - 1] T0 [0:GEN_POLY_WIDTH - 1];
    logic [0:GEN_POLY_WIDTH - 1] T1 [0:GEN_POLY_WIDTH - 1];
    logic [GEN_POLY_WIDTH - 1:0] S;
    
    integer i;
    integer j;
    integer k;
    integer w;
    begin
        for (i = 0; i < GEN_POLY_WIDTH; i = i + 1) begin
            S[i] = 0;
            A[i] = 0;
            A[i][0] = GEN_POLY[GEN_POLY_WIDTH - 1 - i];
            T0[i] = 0;
            T0[i][i] = 1;
            T1[i] = 0;
            if (i > 0) begin
                A[i - 1][i] = 1;
            end
        end
                
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin
            if (i == 0) begin
                if (REVERSE_INPUT_BIT_ORDER) begin
                    S = GEN_POLY & {GEN_POLY_WIDTH{i_data[DATA_WIDTH - 1'b1]}};
                end else begin
                    S = GEN_POLY & {GEN_POLY_WIDTH{i_data[0]}};
                end
            end
            
            if (i > 0) begin
                for (j = 0; j < GEN_POLY_WIDTH; j = j + 1) begin
                    for (k = 0; k < GEN_POLY_WIDTH; k = k + 1) begin
                        for (w = 0; w < GEN_POLY_WIDTH; w = w + 1) begin
                            T1[j][k] = (T0[j][w] & A[w][k]) ^ T1[j][k];
                        end
                    end
                end
                
                for (j = 0; j < GEN_POLY_WIDTH; j = j + 1) begin
                    for (k = 0; k < GEN_POLY_WIDTH; k = k + 1) begin
                        T0[j][k] = T1[j][k];
                        T1[j][k] = 0;
                        if (REVERSE_INPUT_BIT_ORDER) begin
                            S[GEN_POLY_WIDTH - 1 - j] = T0[j][k] * GEN_POLY[GEN_POLY_WIDTH - 1 - k] * i_data[DATA_WIDTH - 1'b1 - i] ^ S[GEN_POLY_WIDTH - 1 - j];
                        end else begin
                            S[GEN_POLY_WIDTH - 1 - j] = T0[j][k] * GEN_POLY[GEN_POLY_WIDTH - 1 - k] * i_data[i] ^ S[GEN_POLY_WIDTH - 1 - j];
                        end
                    end
                end                
            end
        end
        
        for (j = 0; j < GEN_POLY_WIDTH; j = j + 1) begin
            for (k = 0; k < GEN_POLY_WIDTH; k = k + 1) begin
                for (w = 0; w < GEN_POLY_WIDTH; w = w + 1) begin
                    T1[j][k] = T0[j][w] * A[w][k] ^ T1[j][k];
                end
            end
        end
                    
        for (j = 0; j < GEN_POLY_WIDTH; j = j + 1) begin
            for (k = 0; k < GEN_POLY_WIDTH; k = k + 1) begin
                T0[j][k] = T1[j][k];
                T1[j][k] = 0;
                S[GEN_POLY_WIDTH - 1 - j] = T0[j][k] * i_crc[GEN_POLY_WIDTH - 1 - k] ^ S[GEN_POLY_WIDTH - 1 - j];
            end
        end
                          
        crc = S;
    end
    
endfunction

integer i;

always_comb begin
    if (REVERSE_OUTPUT_BIT_ORDER) begin
        if (COMPLEMENT_OUTPUT) begin
            for (i = 0; i < GEN_POLY_WIDTH; i = i + 1) begin
                t_crc[i] = ~r_crc[GEN_POLY_WIDTH - 1 - i];
            end
        end else begin
            for (i = 0; i < GEN_POLY_WIDTH; i = i + 1) begin
                t_crc[i] = r_crc[GEN_POLY_WIDTH - 1 - i];
            end
        end
    end else begin
        if (COMPLEMENT_OUTPUT) begin
            t_crc = ~r_crc;
        end else begin
            t_crc = r_crc;
        end
    end

    crc_next = crc(i_data, r_crc);
end

always_ff @(posedge i_clk) begin
    if (i_data_valid) begin
        r_crc <= crc_next;
    end
    
    if (i_rst) begin
        r_crc <= INITIAL_CRC_VALUE;
    end
end

endmodule
