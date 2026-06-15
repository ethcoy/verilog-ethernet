module crc #(
    parameter c_DATA_WIDTH = 8,
    parameter c_GEN_POLY = 32'h04c11db7,
    parameter c_GEN_POLY_WIDTH = 32,
    parameter c_INITIAL_CRC_VALUE = {c_GEN_POLY_WIDTH{1'b1}},
    parameter c_REVERSE_INPUT_BIT_ORDER = 1,
    parameter c_REVERSE_OUTPUT_BIT_ORDER = 1,
    parameter c_COMPLEMENT_OUTPUT = 1
) (
    input wire i_rst,

    input wire i_clk,

    input wire [c_DATA_WIDTH - 1:0] i_data,
    input wire i_data_valid,
    output wire [c_GEN_POLY_WIDTH - 1:0] o_crc
);

reg [c_GEN_POLY_WIDTH - 1:0] r_crc = c_INITIAL_CRC_VALUE;
reg [c_GEN_POLY_WIDTH - 1:0] crc_next = {c_GEN_POLY_WIDTH{1'b0}};

`ifdef c_REVERSE_OUTPUT_BIT_ORDER
    `ifdef c_COMPLEMENT_OUTPUT
        genvar i;
        generate
            for (i = 0; i < c_GEN_POLY_WIDTH; i = i + 1) begin
                assign o_crc[i] = ~r_crc[c_GEN_POLY_WIDTH - 1 - i];
            end
        endgenerate
    `else
        genvar i;
        generate
            for (i = 0; i < c_GEN_POLY_WIDTH; i = i + 1) begin
                assign o_crc[i] = r_crc[c_GEN_POLY_WIDTH - 1 - i];
            end
        endgenerate
    `endif
`else
    `ifdef c_COMPLEMENT_OUTPUT
        assign o_crc = ~r_crc;
    `else
        assign o_crc = r_crc;
    `endif
`endif

function [c_GEN_POLY_WIDTH - 1:0] crc (input [c_DATA_WIDTH - 1:0] i_data, input [c_GEN_POLY_WIDTH - 1:0] o_crc);
    reg [0:c_GEN_POLY_WIDTH - 1] A [0:c_GEN_POLY_WIDTH - 1];
    reg [0:c_GEN_POLY_WIDTH - 1] T0 [0:c_GEN_POLY_WIDTH - 1];
    reg [0:c_GEN_POLY_WIDTH - 1] T1 [0:c_GEN_POLY_WIDTH - 1];
    reg [c_GEN_POLY_WIDTH - 1:0] S;
    
    integer i;
    integer j;
    integer k;
    integer w;
    begin
        for (i = 0; i < c_GEN_POLY_WIDTH; i = i + 1) begin
            S[i] = 0;
            A[i] = 0;
            A[i][0] = c_GEN_POLY[c_GEN_POLY_WIDTH - 1 - i];
            T0[i] = 0;
            T0[i][i] = 1;
            T1[i] = 0;
            if (i > 0) begin
                A[i - 1][i] = 1;
            end
        end
                
        for (i = 0; i < c_DATA_WIDTH; i = i + 1) begin
            if (i == 0) begin
                `ifdef c_REVERSE_INPUT_BIT_ORDER
                    S = c_GEN_POLY & {c_GEN_POLY_WIDTH{i_data[c_DATA_WIDTH - 1'b1]}};
                `else
                    S = c_GEN_POLY & {c_GEN_POLY_WIDTH{i_data[0]}};
                `endif
            end
            
            if (i > 0) begin
                for (j = 0; j < c_GEN_POLY_WIDTH; j = j + 1) begin
                    for (k = 0; k < c_GEN_POLY_WIDTH; k = k + 1) begin
                        for (w = 0; w < c_GEN_POLY_WIDTH; w = w + 1) begin
                            T1[j][k] = (T0[j][w] & A[w][k]) ^ T1[j][k];
                        end
                    end
                end
                
                for (j = 0; j < c_GEN_POLY_WIDTH; j = j + 1) begin
                    for (k = 0; k < c_GEN_POLY_WIDTH; k = k + 1) begin
                        T0[j][k] = T1[j][k];
                        T1[j][k] = 0;
                        `ifdef c_REVERSE_INPUT_BIT_ORDER
                            S[c_GEN_POLY_WIDTH - 1 - j] = T0[j][k] * c_GEN_POLY[c_GEN_POLY_WIDTH - 1 - k] * i_data[c_DATA_WIDTH - 1'b1 - i] ^ S[c_GEN_POLY_WIDTH - 1 - j];
                        `else
                            S[c_GEN_POLY_WIDTH - 1 - j] = T0[j][k] * c_GEN_POLY[c_GEN_POLY_WIDTH - 1 - k] * i_data[i] ^ S[c_GEN_POLY_WIDTH - 1 - j];
                        `endif
                    end
                end                
            end
        end
        
        for (j = 0; j < c_GEN_POLY_WIDTH; j = j + 1) begin
            for (k = 0; k < c_GEN_POLY_WIDTH; k = k + 1) begin
                for (w = 0; w < c_GEN_POLY_WIDTH; w = w + 1) begin
                    T1[j][k] = T0[j][w] * A[w][k] ^ T1[j][k];
                end
            end
        end
                    
        for (j = 0; j < c_GEN_POLY_WIDTH; j = j + 1) begin
            for (k = 0; k < c_GEN_POLY_WIDTH; k = k + 1) begin
                T0[j][k] = T1[j][k];
                T1[j][k] = 0;
                S[c_GEN_POLY_WIDTH - 1 - j] = T0[j][k] * r_crc[c_GEN_POLY_WIDTH - 1 - k] ^ S[c_GEN_POLY_WIDTH - 1 - j];
            end
        end
                          
        crc = S;
    end
    
endfunction

always @(*) begin
    crc_next = crc(i_data, r_crc);
end

always @(posedge i_clk) begin
    if (i_data_valid) begin
        r_crc <= crc_next;
    end
    
    if (i_rst) begin
        r_crc <= c_INITIAL_CRC_VALUE;
    end
end

endmodule