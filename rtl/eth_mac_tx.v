module eth_mac_tx #(
    parameter c_DATA_WIDTH = 8,
    parameter c_ENABLE_PADDING = 1,
    parameter c_MIN_FRAME_LENGTH = 64
) (
    input wire i_rst,

    /*
     * Ethernet header stream (FPGA -> MAC)
     */
    input wire [47:0] s_axis_eth_dest_addr,
    input wire [47:0] s_axis_eth_src_addr,
    input wire [15:0] s_axis_eth_type,
    input wire s_axis_eth_hdr_valid,
    output wire s_axis_eth_hdr_ready,

    /*
     * Ethernet data stream (FPGA -> MAC)
     */
    input wire [c_DATA_WIDTH - 1:0] s_axis_tdata
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,

    /*
     * MII interface
     */
    input wire mii_tx_clk,
    output wire [3:0] mii_txd,
    output wire mii_tx_en,
    output wire mii_tx_er,
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

localparam [4:0]
    c_STATE_HEADER_INIT = 5'd0;
    c_STATE_DATA_INIT = 5'd1;
    c_STATE_PREAMBLE_SFD = 5'd2;
    c_STATE_TRANSMIT_HEADER = 5'd3;
    c_STATE_TRANSMIT_DATA = 5'd4;
    c_STATE_PAD_FRAME = 5'd5;
    c_STATE_FCS = 5'd6;
    c_STATE_IPG = 5'd7;

reg [4:0] r_state = c_STATE_HEADER;

reg s_axis_eth_hdr_ready_reg = 1'b1;

assign s_axis_eth_hdr_ready = s_axis_eth_hdr_ready_reg;

reg [c_DATA_WIDTH - 1:0] s_axis_tdata_reg = {c_DATA_WIDTH{1'b0}};
reg s_axis_tready_reg = 1'b0;
reg s_axis_tlast_reg = 1'b0;

assign s_axis_tready = s_axis_tready_reg;

reg [47:0] s_axis_eth_dest_addr_reg = 48'b0;
reg [47:0] s_axis_eth_src_addr_reg = 48'b0;
reg [15:0] s_axis_eth_type_reg = 16'b0;

reg [111:0] s_axis_eth_header_reg = 112'b0;

localparam c_MIN_FRAME_WIDTH = $clog2(c_MIN_FRAME_LENGTH + 1'b1);

reg [c_MIN_FRAME_WIDTH - 1:0] r_pad_bytes = c_MIN_FRAME_LENGTH - 6 - 6 - 2;

localparam c_COUNT_WIDTH = $clog2(c_DATA_WIDTH >> 2) + 8;

reg [c_COUNT_WIDTH - 1:0] r_count = {c_COUNT_WIDTH{1'b0}};

reg [3:0] mii_txd_reg = 1'b0;
reg mii_tx_en_reg = 1'b0;
reg mii_tx_er_reg = 1'b0;

assign mii_txd = mii_txd_reg;
assign mii_tx_en = mii_tx_en_reg;
assign mii_tx_er = mii_tx_er_reg;

reg [8*8 - 1:0] r_preamble_sfd = 64'hAA_AA_AA_AA_AA_AA_AA_AB;

reg r_pad_bytes_flag <= 1'b0;
reg [1:0] r_nibble_count <= 2'b0;

wire [31:0] w_crc;

reg r_crc_valid = 1'b0;

crc #(
    .c_DATA_WIDTH(4),
    .c_GEN_POLY(32'h04c11db7),
    .c_GEN_POLY_WIDTH(32),
    .c_INITIAL_CRC_VALUE(c_GEN_POLY_WIDTH{1'b1}),
    .c_REVERSE_INPUT_BIT_ORDER(1),
    .c_REVERSE_OUTPUT_BIT_ORDER(1),
    .c_COMPLEMENT_OUTPUT(1)
) 
crc_inst (
    .i_rst (i_rst),
    .i_clk (mii_tx_clk),
    .i_data (mii_txd),
    .i_data_valid (r_crc_valid),
    .o_crc (w_crc)
);

always @(posedge mii_tx_clk) begin
    case (r_state)
        c_STATE_HEADER: begin
            if (s_axis_eth_hdr_valid & s_axis_eth_hdr_ready) begin
                s_axis_eth_header_reg <= {s_axis_eth_dest_addr, s_axis_eth_src_addr, s_axis_eth_type}
                s_axis_tready_reg <= 1'b1;
                r_state <= c_STATE_DATA_INIT;
            end        
        end

        c_STATE_DATA_INIT: begin
            if (s_axis_tvalid & s_axis_tready) begin
                s_axis_tdata_reg <= s_axis_tdata;
                s_axis_tready_reg <= 1'b0;
                r_pad_bytes <= r_pad_bytes - 1'b1;
                if (s_axis_tlast) begin
                    s_axis_tlast_reg <= 1'b1;
                end
                r_state <= c_STATE_PREAMBLE_SFD;
            end   
        end

        c_STATE_PREAMBLE_SFD: begin
            mii_tx_en <= 1'b1;
            mii_txd_reg <= r_preamble_sfd[60:63];
            r_preamble_sfd <= {r_preamble_sfd[59:0], r_preamble_sfd[63:60]};
            r_count <= r_count + 1'b1;
            if (r_count == 15) begin
                r_state <= c_STATE_TRANSMIT_FRAME;
                r_count <= {c_COUNT_WIDTH{1'b0}};
            end
        end

        c_STATE_TRANSMIT_HEADER: begin
            r_crc_valid <= 1'b1;
            mii_txd_reg <= s_axis_eth_header_reg[111:108];
            s_axis_eth_header_reg <= s_axis_eth_header_reg << 4;
            r_count <= r_count + 1'b1;
            if (r_count == 27) begin
                r_state <= c_STATE_TRANSMIT_DATA;
                r_count <= {c_COUNT_WIDTH{1'b0}};
            end
        end

        c_STATE_TRANSMIT_DATA: begin
            mii_txd_reg <= s_axis_tdata_reg[c_DATA_WIDTH - 1: c_DATA_WIDTH - 4];
            s_axis_tdata_reg <= s_axis_tdata_reg << 4;
            s_axis_tready <= 1'b0;
            r_count <= r_count + 1'b1;
            r_nibble_count <= r_nibble_count + 1'b1;
            if (r_count == c_DATA_WIDTH/4 - 1) begin
                s_axis_tdata_reg <= s_axis_tdata;
                s_axis_tready_reg <= 1'b1;
                r_count <= {c_COUNT_WIDTH{1'b0}};
                if (s_axis_tlast) begin
                    s_axis_tlast_reg <= 1'b1;
                end

                if (s_axis_tlast_reg) begin
                    s_axis_tready_reg <= 1'b0;
                    r_state <= c_STATE_PAD;
                    if (r_pad_bytes == c_MIN_FRAME_WIDTH{1'b0}) begin
                        r_state <= c_STATE_FCS;
                    end
                end
            end

            if (r_nibble_count <= 2'd1) begin
                r_nibble_count <= 2'b0;
                if (r_pad_bytes > c_MIN_FRAME_WIDTH{1'b0}) begin
                    r_pad_bytes <= r_pad_bytes - 1'b1;
                end 
            end
        end

        c_STATE_PAD: begin
            mii_txd_reg <= 4'b0;
            r_nibble_count <= r_nibble_count + 1'b1;
            if (r_nibble_count == 2'd1) begin
                r_nibble_count <= 2'b0
                r_pad_bytes <= r_pad_bytes - 1'b1;
                if (r_pad_bytes == c_MIN_FRAME_WIDTH{1'b0}) begin
                    r_crc_valid <= 1'b0;
                    r_state <= c_STATE_FCS;
                end
            end
        end

        c_STATE_FCS: begin
            mii_txd_reg <= w_crc[28:31];
            // need to shift
        end


    endcase


    if (tx_rst) begin
        
    end
end

endmodule