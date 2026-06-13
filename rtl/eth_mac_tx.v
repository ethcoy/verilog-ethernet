module eth_mac_tx #(
    parameter c_DATA_WIDTH = 8,
    parameter c_ENABLE_PADDING = 1,
    parameter c_MIN_FRAME_LENGTH = 64
) (
    input wire tx_clk,
    input wire tx_rst,

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
     * MAC-to-reconciliation sublayer transmitting interface (MAC -> xMII)
     */
    output wire [c_DATA_WIDTH - 1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire m_axis_tlast,

    /*
     * Tx Status
     */ 
    output wire o_tx_er
);

/*
4.1.2.1.1
- MAC prepends a preamble and an SFD to beginning of frame (user should not send these)
- MAC appends a Pad to the end of the MAC information field of sufficient length to ensure minimum frame-size requirement (4.2.3.3)
- MAC prepends destination and source addresses, length/type field, and appends a Frame Check Sequence (FCS) to provide for error detection.
- MAC can support client-supplied FCS. If not supported, MAC must compute FCS.
- MAC computes FCS after appending Pad


Process Header -> Calculate Pad -> Send Preamble and SFD -> Read/Send Data With Pad (Compute FCS) -> 

Receive everything with a little-endian bit order and handle flipping it before sending to xMII

*/

localparam [4:0]
    c_STATE_HEADER = 5'd0;
    c_STATE_PAD = 5'd0;

reg [4:0] r_state = c_STATE_HEADER;

reg s_axis_eth_hdr_ready_reg = 1'b1;

assign s_axis_eth_hdr_ready = s_axis_eth_hdr_ready_reg;

reg [c_DATA_WIDTH - 1:0] s_axis_tdata_reg = {c_DATA_WIDTH{1'b0}};
reg s_axis_tready_reg = 1'b0;

assign s_axis_tready = s_axis_tready_reg;

reg [c_DATA_WIDTH - 1:0] m_axis_tdata_reg = {c_DATA_WIDTH{1'b0}};
reg m_axis_tvalid_reg = 1'b0;
reg m_axis_tlast_reg = 1'b0;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast = m_axis_tlast_reg;

reg r_tx_er = 1'b0;

assign o_tx_er = r_tx_er;


reg [47:0] s_axis_eth_dest_addr_reg = 48'b0;
reg [47:0] s_axis_eth_src_addr_reg = 48'b0;
reg [15:0] s_axis_eth_type_reg = 16'b0;

reg [6:0] r_pad_bytes = 7'b0

always @(posedge tx_clk) begin
    case (r_state)
        c_STATE_HEADER: begin
            if (s_axis_eth_hdr_valid & s_axis_eth_hdr_ready) begin
                s_axis_eth_dest_addr_reg <= s_axis_eth_dest_addr;
                s_axis_eth_src_addr_reg <= s_axis_eth_src_addr;
                s_axis_eth_type <= s_axis_eth_type_reg;
                if (s_axis_eth_type < c_MIN_FRAME_LENGTH) begin
                    r_pad_bytes <= c_MIN_FRAME_LENGTH - s_axis_eth_type;
                end
                
                r_state <= c_STATE_PAD;
            end        
        end

        c_STATE_PAD: begin
            
        end


    endcase


    if (tx_rst) begin
        
    end
end

endmodule