module serial_crc #(
    parameter c_MESSAGE_LENGTH = 3,
    parameter c_CRC_LENGTH = 4,
    parameter c_POLYNOMIAL = 4'h1
) (
    input wire i_rst,

    input wire i_clk,

    input wire s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,

    output wire [c_CRC_LENGTH - 1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready
);

reg [c_CRC_LEN - 1:0] r_crc = {c_CRC_LEN{1'b0}};



always @(posedge i_clk) begin
    if (s_axis_tvalid) begin
        













    end 


    if (i_rst) begin
        r_crc <= {c_CRC_LEN{1'b1}};
    end
end

endmodule