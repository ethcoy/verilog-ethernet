module axis_counter #(
    parameter DATA_WIDTH = 8,
    parameter CYCLE_DELAY = 10
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

logic [DATA_WIDTH - 1:0] m_axis_tdata_reg = '0, m_axis_tdata_next;
logic m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
logic m_axis_tlast_reg = 1'b0, m_axis_tlast_next;

localparam COUNT_WIDTH = $clog2(CYCLE_DELAY);

logic [COUNT_WIDTH - 1:0] count_reg = '0, count_next;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast = m_axis_tlast_reg;

typedef enum logic [0:0] {
    STATE_SEND,
    STATE_DELAY
} state_t;

state_t state_reg = STATE_SEND, state_next;

always_comb begin
    state_next = state_reg;

    m_axis_tdata_next = m_axis_tdata_reg;
    m_axis_tvalid_next = m_axis_tvalid_reg;
    m_axis_tlast_next = m_axis_tlast_reg;

    count_next = count_reg;

    case (state_reg)
        STATE_SEND: begin
            m_axis_tvalid_next = 1'b1;
            if (m_axis_tvalid && m_axis_tready) begin
                state_next = STATE_DELAY;
                count_next = '0;
                m_axis_tdata_next = m_axis_tdata_reg + 1'b1;
                m_axis_tvalid_next = 1'b0;
                m_axis_tlast_next = 1'b0;
                if (m_axis_tdata_reg == MAX_COUNT - 1) begin
                    m_axis_tlast_next = 1'b1;
                end
            end
        end

        STATE_DELAY: begin
            count_next = count_reg + 1'b1;
            if (count_reg == CYCLE_DELAY - 1) begin
                state_next = STATE_SEND;
                m_axis_tvalid_next = 1'b1;
            end
        end

        default: begin
            state_next = STATE_SEND;
        end
    endcase
end

always_ff @(posedge i_clk) begin
    state_reg <= state_next;

    m_axis_tdata_reg <= m_axis_tdata_next;
    m_axis_tvalid_reg <= m_axis_tvalid_next;
    m_axis_tlast_reg <= m_axis_tlast_next;

    count_reg <= count_next;
end

endmodule
