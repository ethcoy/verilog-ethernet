module axis_async_fifo_test #(
    parameter DATA_WIDTH = 16,
    parameter CYCLE_DELAY = 50
) (
    input wire logic s_clk,
    input wire logic m_clk,

    output wire logic [DATA_WIDTH - 1:0] o_leds
);

logic [DATA_WIDTH - 1:0] leds_reg = '0;

assign o_leds = leds_reg;

wire [DATA_WIDTH - 1:0] axis_counter_inst_m_axis_tdata;
wire axis_counter_inst_m_axis_tvalid;
wire axis_async_fifo_inst_s_axis_tready;
wire axis_counter_inst_m_axis_tlast;

axis_counter #(
    .DATA_WIDTH(DATA_WIDTH),
    .CYCLE_DELAY(CYCLE_DELAY)
) 
axis_counter_inst (
    .i_clk(s_clk),
    .i_rst(),
    .m_axis_tdata(axis_counter_inst_m_axis_tdata),
    .m_axis_tvalid(axis_counter_inst_m_axis_tvalid),
    .m_axis_tready(axis_async_fifo_inst_s_axis_tready),
    .m_axis_tlast(axis_counter_inst_m_axis_tlast)
);

wire [DATA_WIDTH - 1:0] axis_async_fifo_inst_m_axis_tdata;
wire axis_async_fifo_inst_m_axis_tvalid;

axis_async_fifo #(
    .DATA_WIDTH(16),
    .FIFO_DEPTH(256)
) 
axis_async_fifo_inst (
    .s_clk(s_clk),
    .m_clk(m_clk),
    .s_rst(),
    .m_rst(),
    .s_axis_tdata(axis_counter_inst_m_axis_tdata),
    .s_axis_tvalid(axis_counter_inst_m_axis_tvalid),
    .s_axis_tready(axis_async_fifo_inst_s_axis_tready),
    .s_axis_tlast(axis_counter_inst_m_axis_tlast),
    .m_axis_tdata(axis_async_fifo_inst_m_axis_tdata),
    .m_axis_tvalid(axis_async_fifo_inst_m_axis_tvalid),
    .m_axis_tready(1'b1),
    .m_axis_tlast()
);

always_ff @(posedge m_clk) begin
    if (axis_async_fifo_inst_m_axis_tvalid) begin
        leds_reg <= axis_async_fifo_inst_m_axis_tdata;
    end
end

endmodule