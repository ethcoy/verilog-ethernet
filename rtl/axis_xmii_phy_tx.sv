module axis_xmii_phy_tx #(
    parameter DATA_WIDTH = 8,
    parameter XMII_WIDTH = 4
) (
    input wire logic i_rst,

    input wire logic [DATA_WIDTH - 1:0] s_axis_tdata,
    input wire logic s_axis_tvalid,
    output wire logic s_axis_tready,
    input wire logic s_axis_tlast,

    // xMII Tx interface
    input wire logic xmii_tx_clk,
    output wire logic [XMII_WIDTH - 1:0] xmii_txd,
    output wire logic xmii_tx_en,
    output wire logic xmii_tx_er,

    // PHY control
    input wire logic i_packet_ready,

    // PHY status
    output wire logic o_xmii_phy_tx_busy
);

logic [DATA_WIDTH - 1:0] s_axis_tdata_reg = '0, s_axis_tdata_next; 
logic s_axis_tready_reg = 1'b0, s_axis_tready_next;
logic s_axis_tlast_reg = 1'b0, s_axis_tlast_next;

logic [XMII_WIDTH - 1:0] xmii_txd_reg = '0, xmii_txd_next;
logic xmii_tx_en_reg = 1'b0, xmii_tx_en_next;

logic xmii_phy_tx_busy_reg = 1'b0, xmii_phy_tx_busy_next;

logic [15:0] count_reg = '0, count_next;

assign s_axis_tready = s_axis_tready_reg;

assign xmii_txd = xmii_txd_reg;
assign xmii_tx_en = xmii_tx_en_reg;

assign o_xmii_phy_tx_busy = xmii_phy_tx_busy_reg;

localparam DATA_WIDTH_PER_XMII_WIDTH = DATA_WIDTH/XMII_WIDTH;

typedef enum logic [0:0] {
    STATE_PHY_IDLE,
    STATE_PHY_SEND
} state_t;

state_t state_reg = STATE_PHY_IDLE, state_next;

always_comb begin
    state_next = state_reg;

    s_axis_tdata_next = s_axis_tdata_reg;
    s_axis_tready_next = s_axis_tready_reg;
    s_axis_tlast_next = s_axis_tlast_reg;

    xmii_txd_next = xmii_txd_reg;
    xmii_tx_en_next = xmii_tx_en_reg;

    xmii_phy_tx_busy_next = xmii_phy_tx_busy_reg;

    count_next = count_reg;

    case (state_reg)
        STATE_PHY_IDLE: begin
            s_axis_tready_next = 1'b1;
            xmii_phy_tx_busy_next = 1'b0;
            if (s_axis_tvalid && s_axis_tready && i_packet_ready) begin
                s_axis_tdata_next = s_axis_tdata;
                s_axis_tready_next = 1'b0;
                s_axis_tlast_next = s_axis_tlast;
                xmii_txd_next = s_axis_tdata_next[XMII_WIDTH - 1:0];
                xmii_tx_en_next = 1'b1;
                xmii_phy_tx_busy_next = 1'b1;
                state_next = STATE_PHY_SEND;
                if (DATA_WIDTH_PER_XMII_WIDTH == 1) begin
                    s_axis_tready_next = 1'b1;
                end
            end
        end

        STATE_PHY_SEND: begin
            count_next = count_reg + 1'b1;
            s_axis_tdata_next = s_axis_tdata_reg >> XMII_WIDTH;
            xmii_txd_next = s_axis_tdata_next;
            if (count_next == DATA_WIDTH_PER_XMII_WIDTH) begin
                count_next = '0;
                s_axis_tdata_next = s_axis_tdata;
                xmii_txd_next = s_axis_tdata_next[XMII_WIDTH - 1:0];
            end
        end
    endcase
end

always_ff @(posedge xmii_tx_clk) begin
    state_reg <= state_next;

    s_axis_tdata_reg <= s_axis_tdata_next;
    s_axis_tready_reg <= s_axis_tready_next;
    s_axis_tlast_reg <= s_axis_tlast_next;

    xmii_txd_reg <= xmii_txd_next;
    xmii_tx_en_reg <= xmii_tx_en_next;

    xmii_phy_tx_busy_reg <= xmii_phy_tx_busy_next;

    count_reg <= count_next;
end

endmodule