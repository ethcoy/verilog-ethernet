module axis_mac_mii_tx #(
    parameter DATA_WIDTH = 8,
    parameter XMII_WIDTH = 4,
    parameter ENABLE_PADDING = 1,
    parameter MIN_FRAME_LENGTH = 64
) (
    input wire i_rst,

    /*
     * Ethernet data stream (FPGA -> MAC)
     */
    input wire [DATA_WIDTH - 1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,

    /*
     * xMII interface
     */
    input wire xmii_tx_clk,
    output wire [XMII_WIDTH - 1:0] xmii_txd,
    output wire xmii_tx_en,
    output wire xmii_tx_er,
);

/*
4.1.2.1.1
- MAC prepends a preamble and an SFD to beginning of frame (user should not send these)
- MAC appends a Pad to the end of the MAC information field of sufficient length to ensure minimum frame-size requirement (4.2.3.3)
- MAC prepends destination and source addresses, length/type field, and appends a Frame Check Sequence (FCS) to provide for error detection.
- MAC can support client-supplied FCS. If not supported, MAC must compute FCS.
- MAC computes FCS after appending Pad


Process Header -> Send Preamble and SFD -> Calculate Pad -> Send Preamble and SFD -> Read/Send Data With Pad (Compute FCS) ->

Make MAC specific to MII, RGMII, etc.

Receive everything with a little-endian bit order and handle flipping it before sending to xMII

*/
localparam STATE_ETHERNET_IDLE = 0;
localparam STATE_ETHERNET_PREAMBLE_AND_SFD = 1;
localparam STATE_ETHERNET_HEADER_AND_PAYLOAD = 2;
localparam STATE_ETHERNET_PAD = 3;
localparam STATE_ETHERNET_FCS = 4;
localparam STATE_ETHERNET_IPG = 5;

reg [4:0] state_reg = STATE_ETHERNET_IDLE;
reg [4:0] state_next;

reg [DATA_WIDTH - 1:0] s_axis_tdata_reg = {DATA_WIDTH{1'b0}};
reg [DATA_WIDTH - 1:0] s_axis_tdata_buff_reg = {DATA_WIDTH{1'b0}};
reg s_axis_tready_reg = 1'b0;
reg s_axis_tlast_reg = 1'b0;

assign s_axis_tready = s_axis_tready_reg;

reg [XMII_WIDTH - 1:0] xmii_txd_reg = {XMII_WIDTH{1'b0}}; 
reg xmii_tx_en_reg = 1'b0;

assign xmii_txd = xmii_txd_reg;

reg [7:0] eth_pre_reg = 8'hAA;
reg [7:0] eth_sfd_reg = 8'hAB;

reg [15:0] count_reg = 16'b0;
reg [15:0] byte_count_reg = 16'b0;
reg [15:0] partial_byte_count_reg = 16'b0;

wire crc_valid_wire;

assign crc_valid_wire = count_reg == 16'b0 && state_reg == STATE_ETHERNET_HEADER_AND_PAYLOAD;

wire crc_wire;

crc #(
    .c_DATA_WIDTH(8),
    .c_GEN_POLY(32'h04c11db7),
    .c_GEN_POLY_WIDTH(32),
    .c_INITIAL_CRC_VALUE(32'b1),
    .c_REVERSE_INPUT_BIT_ORDER(1),
    .c_REVERSE_OUTPUT_BIT_ORDER(1),
    .c_COMPLEMENT_OUTPUT(1)
)
crc_inst (
    .i_rst (i_rst),
    .i_clk (xmii_tx_clk),
    .i_data (s_axis_tdata_reg),
    .i_data_valid (crc_valid_wire),
    .o_crc (crc_wire)
);

localparam COUNT_TARGET1 = 7*8/XMII_WIDTH - 1;
localparam COUNT_TARGET2 = 8*8/XMII_WIDTH - 1;
localparam COUNT_TARGET3 = DATA_WIDTH/XMII_WIDTH;

always @(posedge xmii_tx_clk) begin
    case (state_reg)
        STATE_ETHERNET_IDLE: begin
            s_axis_tready_reg <= 1'b1;
            if (s_axis_tvalid && s_axis_tready) begin
                s_axis_tdata_reg <= s_axis_tdata;
                byte_count_reg <= 3'd4;
                state_reg <= STATE_ETHERNET_PREAMBLE_AND_SFD;
            end
        end

        STATE_ETHERNET_PREAMBLE_AND_SFD: begin
            xmii_tx_en_reg <= 1'b1;
            xmii_txd_reg <= eth_pre_reg[XMII_WIDTH - 1:0];            
            count_reg <= count_reg + 1'b1;
            if (count_reg >= COUNT_TARGET1) begin
                xmii_txd_reg <= eth_sfd_reg[XMII_WIDTH - 1:0];
                eth_sfd_reg <= {eth_sfd_reg[XMII_WIDTH - 1:0], eth_sfd_reg[7:8 - XMII_WIDTH]};

                if (count_reg == COUNT_TARGET2) begin
                    count_reg <= 16'b0;
                    state_reg <= STATE_ETHERNET_HEADER_AND_PAYLOAD;
                end
            end

            if (s_axis_tvalid && s_axis_tready) begin
                s_axis_tdata_buff_reg <= s_axis_tdata;
                s_axis_tready_reg <= 1'b0;
                state_reg <= STATE_ETHERNET_PREAMBLE_AND_SFD;
            end
        end

        STATE_ETHERNET_HEADER_AND_PAYLOAD: begin
            count_reg <= count_reg + 1'b1;
            xmii_txd_reg <= s_axis_tdata_reg[XMII_WIDTH - 1:0];
            s_axis_tdata_reg <= s_axis_tdata_reg >> XMII_WIDTH;
            
            if (count_reg == COUNT_TARGET3 - 1) begin
                s_axis_tdata_reg <= s_axis_tdata_buff_reg;
                s_axis_tready_reg <= 1'b1;
                count_reg <= 16'b0;
                if (s_axis_tlast_reg) begin
                    s_axis_tready_reg <= 1'b0;
                    state_reg <= STATE_ETHERNET_FCS;
                    if (byte_count_reg < MIN_FRAME_LENGTH - 1) begin
                        state_reg <= STATE_ETHERNET_PAD;
                    end
                end
            end

            if (s_axis_tvalid && s_axis_tready) begin
                s_axis_tdata_buff_reg <= s_axis_tdata;
                s_axis_tready_reg <= 1'b0;
                s_axis_tlast_reg <= s_axis_tlast;            
            end
        end

        STATE_ETHERNET_PAD: begin
            xmii_txd_reg <= {XMII_WIDTH{1'b0}};
            if (byte_count_reg >= MIN_FRAME_LENGTH - 1 && partial_byte_count_reg == DATA_WIDTH/XMII_WIDTH - 1) begin
                state_reg <= STATE_ETHERNET_FCS;
            end
        end

        STATE_ETHERNET_FCS: begin
            count_reg <= count_reg + 1'b1;
            xmii_txd_reg <= crc_wire[XMII_WIDTH - 1:0];     
        end
    endcase

    if (s_axis_tvalid && s_axis_tready) begin
        byte_count_reg <= byte_count_reg + (DATA_WIDTH >> 2'd3);
    end

    if (xmii_tx_en) begin
        partial_byte_count_reg <= partial_byte_count_reg + 1'b1;
        if (partial_byte_count_reg == DATA_WIDTH/XMII_WIDTH - 1) begin
            partial_byte_count_reg <= 16'b0;
        end
    end
end

always @(posedge rmii_tx_clk) begin
    state_reg <= state_next;
    s_axis_tdata_reg <= s_axis_tdata_next;
    s_axis_tready_reg <= s_axis_tready_next;
    s_axis_tlast_reg <= s_axis_tlast_next;
    xmii_txd_reg <= rmii_txd_next;
    xmii_tx_en_reg <= rmii_tx_en_next;
    count_reg <= count_next;

end

endmodule