module crc #(
    parameter c_DATA_WIDTH = 16,
    parameter c_GEN_POLY = 8'h07,
    parameter c_GEN_POLY_WIDTH = 8
) (
    input wire i_rst,

    input wire i_clk,

    input wire [c_DATA_WIDTH - 1:0] i_data,
    input wire i_data_valid,
    output wire [c_GEN_POLY_WIDTH - 1:0] o_crc
);

reg [c_GEN_POLY_WIDTH - 1:0] r_crc = {c_GEN_POLY_WIDTH{1'b0}};
reg [c_GEN_POLY_WIDTH - 1:0] crc_next = {c_GEN_POLY_WIDTH{1'b0}};

assign o_crc = r_crc;

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
                for (j = 0; j < c_GEN_POLY_WIDTH; j = j + 1) begin
                    S[c_GEN_POLY_WIDTH - 1 - j] = c_GEN_POLY[c_GEN_POLY_WIDTH - 1 - j] * i_data[0];
                end
            end
            
            if (i > 0) begin
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
                        S[c_GEN_POLY_WIDTH - 1 - j] = T0[j][k] * c_GEN_POLY[c_GEN_POLY_WIDTH - 1 - k] * i_data[i] ^ S[c_GEN_POLY_WIDTH - 1 - j];
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
                S[c_GEN_POLY_WIDTH - 1 - j] = T0[j][k] * o_crc[c_GEN_POLY_WIDTH - 1 - k] ^ S[c_GEN_POLY_WIDTH - 1 - j];
            end
        end
                          
        crc = S;
    end
    
endfunction

always @(*) begin
    crc_next = crc(i_data, o_crc);
end

always @(posedge i_clk) begin
    if (i_data_valid) begin
        r_crc <= crc_next;
    end
end

endmodule