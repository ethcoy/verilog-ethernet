module axis_counter #(
    parameter DATA_WIDTH = 8
) (
    input wire logic i_clk,
    input wire logic i_rst,

    // AXI-Stream data source interface
    output wire logic [DATA_WIDTH - 1:0] m_axis_tdata,
    output wire logic m_axis_tvalid,
    input wire logic m_axis_tready,
    output wire m_axis_tlast
);

localparam MAX_COUNT = 2**DATA_WIDTH - 1;

logic [DATA_WIDTH - 1:0] m_axis_tdata_reg = '0;
logic m_axis_tvalid_reg = 1'b1;
logic m_axis_tlast_reg = 1'b0;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast = m_axis_tlast_reg;

always_ff @(posedge i_clk) begin
    if (m_axis_tvalid && m_axis_tready) begin
        m_axis_tdata_reg <= m_axis_tdata_reg + 1'b1;
        m_axis_tlast_reg <= 1'b0;
        if (m_axis_tdata_reg == MAX_COUNT - 1) begin
            m_axis_tlast_reg <= 1'b1;
        end
    end
end

endmodule
