module axis_ipv4_tx #(
    parameter DATA_WIDTH = 8
) (
    input wire i_clk,
    input wire i_rst,

    /*
     * IPv4 header interface
     */
    input wire [3:0] s_axis_ipv4_version,
    input wire [3:0] s_axis_ipv4_ihl,
    input wire [5:0] s_axis_ipv4_dscp,
    input wire [1:0] s_axis_ipv4_ecn,
    input wire [15:0] s_axis_ipv4_length,
    input wire [15:0] s_axis_ipv4_id,
    input wire [15:0] s_axis_ipv4_flags,
    input wire [12:0] s_axis_ipv4_fragment_offset,
    input wire [7:0] s_axis_ipv4_ttl,
    input wire [7:0] s_axis_ipv4_protocol,
    // Checksum is computed by this module
    // input wire [7:0] s_axis_ipv4_checksum,
    input wire [31:0] s_axis_ipv4_source,
    input wire [31:0] s_axis_ipv4_destinvation,
    input wire s_axis_ipv4_header_valid,
    output wire s_axis_ipv4_header_ready,

    /*
     * IPv4 data interface
     */
    input wire [DATA_WIDTH - 1:0] s_axis_ipv4_tdata,
    input wire s_axis_ipv4_tvalid,
    output wire s_axis_ipv4_tready,
    input wire s_axis_ipv4_tlast,
    input wire [DATA_WIDTH/8 - 1:0] s_axis_ipv4_tkeep,

    output wire [DATA_WIDTH - 1:0] m_axis_ipv4_tdata,
    output wire m_axis_ipv4_tvalid,
    input wire m_axis_ipv4_tready,
    output wire m_axis_ipv4_tlast,
    output wire [DATA_WIDTH/8 - 1:0] m_axis_ipv4_tkeep
);

localparam KEEP_WIDTH = DATA_WIDTH/8;

reg [159:0] s_axis_ipv4_header_reg = {160{1'b0}};
reg s_axis_ipv4_header_ready_reg = 1'b0;
reg [20:0] ipv4_checksum_reg = 21'b0; 

assign s_axis_ipv4_header_ready = s_axis_ipv4_header_ready_reg;

reg [DATA_WIDTH - 1:0] s_axis_ipv4_tdata_reg = {DATA_WIDTH{1'b0}};
reg s_axis_ipv4_tready_reg = 1'b0;
reg s_axis_ipv4_tlast_reg = 1'b0;
reg [KEEP_WIDTH - 1:0] s_axis_ipv4_tkeep_reg = {KEEP_WIDTH{1'b0}};

assign s_axis_ipv4_tready = s_axis_ipv4_tready_reg;

reg [DATA_WIDTH - 1:0] m_axis_ipv4_tdata_reg = {DATA_WIDTH{1'b0}};
reg m_axis_ipv4_tvalid_reg = 1'b0;
reg m_axis_ipv4_tlast_reg = 1'b0;
reg [KEEP_WIDTH - 1:0] m_axis_ipv4_tkeep_reg = {KEEP_WIDTH{1'b0}};

assign m_axis_ipv4_tdata = m_axis_ipv4_tdata_reg;
assign m_axis_ipv4_tvalid = m_axis_ipv4_tvalid_reg;
assign m_axis_ipv4_tlast = m_axis_ipv4_tlast_reg;
assign m_axis_ipv4_tkeep = m_axis_ipv4_tkeep_reg;

reg [15:0] count_reg = 16'b0;

localparam HEADER_IS_MULTIPLE = 160%DATA_WIDTH == 0 ? 1 : 0;
localparam HEADER_IS_LESS = DATA_WIDTH > 160 ? 1 : 0;
localparam HEADER_FULL_TRANSACTIONS = 160/DATA_WIDTH;
localparam HEADER_BYTES_ENABLED_LAST_TRANSACTION_WHEN_MORE = (160%DATA_WIDTH)/8;
localparam HEADER_BYTES_ENABLED_LAST_TRANSACTION_WHEN_LESS = (DATA_WIDTH%160)/8;

localparam STATE_IPV4_IDLE = 0;
localparam STATE_IPV4_CHECKSUM = 1;
localparam STATE_IPV4_HEADER = 2;

reg [3:0] state_reg = STATE_IPV4_IDLE;

always @(posedge i_clk) begin
    case (state_reg)
        STATE_IPV4_IDLE: begin
            s_axis_ipv4_tready_reg <= 1'b1;
            count_reg <= 16'd0;
            if (s_axis_ipv4_header_valid && s_axis_ipv4_header_ready && s_axis_ipv4_tvalid) begin
                s_axis_ipv4_header_reg <= {s_axis_ipv4_version, s_axis_ipv4_ihl, s_axis_ipv4_dscp, 
                                           s_axis_ipv4_ecn, s_axis_ipv4_length, s_axis_ipv4_id,
                                           s_axis_ipv4_flags, s_axis_ipv4_fragment_offset, s_axis_ipv4_ttl,
                                           s_axis_ipv4_protocol, 16'b0, s_axis_ipv4_source, s_axis_ipv4_destinvation};
                state_reg <= STATE_IPV4_CHECKSUM;
                // reject packets that are too short in the future
                // if (s_axis_ipv4_length >= )
            end
        end

        STATE_IPV4_CHECKSUM: begin
            count_reg <= count_reg + 1'b1;
            case (count_reg)
                16'd0: begin
                    ipv4_checksum_reg <= s_axis_ipv4_header_reg[159:144] + s_axis_ipv4_header_reg[143:128];
                end

                16'd1: begin
                    ipv4_checksum_reg <= ipv4_checksum_reg + s_axis_ipv4_header_reg[127:112];
                end 

                16'd2: begin
                    ipv4_checksum_reg <= ipv4_checksum_reg + s_axis_ipv4_header_reg[111:96];
                end

                16'd3: begin
                    ipv4_checksum_reg <= ipv4_checksum_reg + s_axis_ipv4_header_reg[95:80];
                end

                16'd4: begin
                    ipv4_checksum_reg <= ipv4_checksum_reg[15:0] + (ipv4_checksum_reg >> 16);
                    count_reg <= count_reg;
                    if (ipv4_checksum_reg <= 2**16 - 1) begin
                        count_reg <= 16'b0;
                        s_axis_ipv4_header_reg[79:64] <= ~ipv4_checksum_reg;
                        state_reg <= STATE_IPV4_HEADER;
                    end
                end
            endcase
        end

    STATE_IPV4_HEADER: begin
        m_axis_ipv4_tdata_reg <= s_axis_ipv4_header_reg[159:160 - DATA_WIDTH];
        m_axis_ipv4_tvalid_reg <= 1'b1;

        if (HEADER_IS_LESS) begin
            m_axis_ipv4_tdata_reg <= s_axis_ipv4_header_reg;
            m_axis_ipv4_tkeep_reg <= 1'b1 << HEADER_BYTES_ENABLED_LAST_TRANSACTION_WHEN_LESS;
        end

        if (HEADER_IS_MULTIPLE) begin
            m_axis_ipv4_tkeep_reg <= {KEEP_WIDTH{1'b1}};
        end
        
        if (m_axis_ipv4_tvalid && m_axis_ipv4_tready) begin
            s_axis_ipv4_header_reg <= s_axis_ipv4_header_reg << DATA_WIDTH;
            count_reg <= count_reg + 1'b1;
            
            if (count_reg == HEADER_FULL_TRANSACTIONS) begin
                
            end

            if (HEADER_IS_MULTIPLE) begin
            
            end
        end
    end

    endcase



    if (i_rst) begin
        
    end
end




endmodule