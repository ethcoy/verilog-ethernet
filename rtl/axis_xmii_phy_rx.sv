module axis_xmii_phy_rx #(
    parameter DATA_WIDTH = 8,
    parameter XMII_WIDTH = 2
) (
    input wire logic i_rst,

    output wire logic [DATA_WIDTH - 1:0] m_axis_tdata,
    output wire logic m_axis_tvalid,
    output wire logic m_axis_tlast,

    // xMII Tx interface
    input wire logic xmii_rx_clk,
    input wire logic [XMII_WIDTH - 1:0] xmii_rxd,
    input wire logic xmii_rx_dv,
    input wire logic xmii_rx_er
);

logic [DATA_WIDTH - 1:0] m_axis_tdata_reg = '0, m_axis_tdata_next;
logic [DATA_WIDTH - 1:0] m_axis_tdata_buffer0_reg = '0, m_axis_tdata_buffer0_next;
logic [DATA_WIDTH - 1:0] m_axis_tdata_buffer1_reg = '0, m_axis_tdata_buffer1_next;
logic m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
logic m_axis_tlast_reg = 1'b0, m_axis_tlast_next;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast = m_axis_tlast_reg;

logic [15:0] count_reg = '0, count_next;

logic buffer_switch_reg = 1'b0, buffer_switch_next;

logic enable_valid_reg = 1'b0, enable_valid_next;

localparam DATA_WIDTH_PER_XMII_WIDTH = DATA_WIDTH/XMII_WIDTH;

typedef enum logic [0:0] {
    STATE_PHY_IDLE,
    STATE_PHY_READ
} state_t;

state_t state_reg = STATE_PHY_IDLE, state_next;

always_comb begin
    state_next = state_reg;

    m_axis_tdata_next = m_axis_tdata_reg;
    m_axis_tdata_buffer0_next = m_axis_tdata_buffer0_reg;
    m_axis_tdata_buffer1_next = m_axis_tdata_buffer1_reg;
    m_axis_tvalid_next = 1'b0;
    m_axis_tlast_next = 1'b0;

    count_next = count_reg;

    buffer_switch_next = buffer_switch_reg;

    enable_valid_next = 1'b0;

    case (state_reg)
        STATE_PHY_IDLE: begin
            if (xmii_rx_dv) begin
                state_next = STATE_PHY_READ;
                count_next = count_reg + 1'b1;

                m_axis_tdata_buffer0_next = {xmii_rxd, m_axis_tdata_buffer0_next[DATA_WIDTH - 1:XMII_WIDTH]};
                if (DATA_WIDTH == XMII_WIDTH) begin
                    m_axis_tdata_buffer0_next = xmii_rxd;
                end

                if (buffer_switch_reg) begin
                    m_axis_tdata_buffer1_next = {xmii_rxd, m_axis_tdata_buffer1_next[DATA_WIDTH - 1:XMII_WIDTH]};
                    if (DATA_WIDTH == XMII_WIDTH) begin
                        m_axis_tdata_buffer1_next = xmii_rxd;
                    end
                end

                if (count_reg == DATA_WIDTH_PER_XMII_WIDTH - 1) begin
                    count_next = '0;
                    m_axis_tdata_next = m_axis_tdata_buffer0_next;
                    buffer_switch_next = ~buffer_switch_reg;
                    enable_valid_next = 1'b1;
                    if (buffer_switch_reg) begin
                        m_axis_tdata_next = m_axis_tdata_buffer1_next;
                    end
                end
            end
        end

        STATE_PHY_READ: begin
            count_next = count_reg + 1'b1;

            m_axis_tdata_buffer0_next = {xmii_rxd, m_axis_tdata_buffer0_next[DATA_WIDTH - 1:XMII_WIDTH]};
            if (DATA_WIDTH == XMII_WIDTH) begin
                m_axis_tdata_buffer0_next = xmii_rxd;
            end

            if (buffer_switch_reg) begin
                m_axis_tdata_buffer1_next = {xmii_rxd, m_axis_tdata_buffer1_next[DATA_WIDTH - 1:XMII_WIDTH]};
                if (DATA_WIDTH == XMII_WIDTH) begin
                    m_axis_tdata_buffer1_next = xmii_rxd;
                end
            end

            if (count_reg == DATA_WIDTH_PER_XMII_WIDTH - 1) begin
                count_next = '0;
                m_axis_tdata_next = m_axis_tdata_buffer0_next;
                buffer_switch_next = ~buffer_switch_reg;
                enable_valid_next = 1'b1;
                if (buffer_switch_reg) begin
                    m_axis_tdata_next = m_axis_tdata_buffer1_next;
                end
            end

            if (enable_valid_reg) begin
                m_axis_tvalid_next = 1'b1;
            end

            if (!xmii_rx_dv && count_reg == '0) begin
                state_next = STATE_PHY_IDLE;
                count_next = '0;
                m_axis_tlast_next = 1'b1;
            end
        end

        default: begin
            state_next = STATE_PHY_IDLE;
        end
    endcase
end

always_ff @(posedge xmii_rx_clk) begin
    state_reg <= state_next;

    m_axis_tdata_reg <= m_axis_tdata_next;
    m_axis_tdata_buffer0_reg <= m_axis_tdata_buffer0_next;
    m_axis_tdata_buffer1_reg <= m_axis_tdata_buffer1_next;
    m_axis_tvalid_reg <= m_axis_tvalid_next;
    m_axis_tlast_reg <= m_axis_tlast_next;

    count_reg <= count_next;

    buffer_switch_reg <= buffer_switch_next;

    enable_valid_reg <= enable_valid_next;

    if (i_rst) begin
        state_reg <= STATE_PHY_IDLE;
        m_axis_tdata_reg <= '0;
        m_axis_tdata_buffer0_reg <= '0;
        m_axis_tdata_buffer1_reg <= '0;
        m_axis_tvalid_reg <= 1'b0;
        m_axis_tlast_reg <= 1'b0;
        count_reg <= '0;
        buffer_switch_reg <= 1'b0;
        enable_valid_reg <= 1'b0;
    end
end

endmodule