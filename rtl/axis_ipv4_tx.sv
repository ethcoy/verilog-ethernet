module axis_ipv4_tx #(
    parameter DATA_WIDTH = 8
) (
    input wire logic i_clk,
    input wire logic i_rst,

    // IPv4 AXI-Stream sink header interface
    input wire logic [3:0] s_axis_ipv4_version,
    input wire logic [3:0] s_axis_ipv4_ihl,
    input wire logic [5:0] s_axis_ipv4_dscp,
    input wire logic [1:0] s_axis_ipv4_ecn,
    input wire logic [15:0] s_axis_ipv4_length,
    input wire logic [15:0] s_axis_ipv4_id,
    input wire logic [2:0] s_axis_ipv4_flags,
    input wire logic [12:0] s_axis_ipv4_fragment_offset,
    input wire logic [7:0] s_axis_ipv4_ttl,
    input wire logic [7:0] s_axis_ipv4_protocol,
    input wire logic [31:0] s_axis_ipv4_source_ip,
    input wire logic [31:0] s_axis_ipv4_destination_ip,
    input wire logic s_axis_ipv4_header_tvalid,
    output wire logic s_axis_ipv4_header_tready,

    // IPv4 AXI-Stream data sink interface
    input wire logic [DATA_WIDTH - 1:0] s_axis_tdata,
    input wire logic s_axis_tvalid,
    output wire logic s_axis_tready,
    input wire logic s_axis_tlast,

    // IPv4 AXI-Stream data source interface
    output wire logic [DATA_WIDTH - 1:0] m_axis_tdata,
    output wire logic m_axis_tvalid,
    input wire logic m_axis_tready,
    output wire logic m_axis_tlast
);

logic [159:0] s_axis_ipv4_header_reg = '0, s_axis_ipv4_header_next;
logic s_axis_ipv4_header_tready_reg = 1'b0, s_axis_ipv4_header_tready_next;

assign s_axis_ipv4_header_tready = s_axis_ipv4_header_tready_reg;

logic [DATA_WIDTH - 1:0] s_axis_tdata_reg = '0, s_axis_tdata_next;
logic s_axis_tready_reg = 1'b0, s_axis_tready_next;
logic s_axis_tlast_reg = 1'b0, s_axis_tlast_next;

assign s_axis_tready = s_axis_tready_reg;

logic [DATA_WIDTH - 1:0] m_axis_tdata_reg = '0, m_axis_tdata_next;
logic m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
logic m_axis_tlast_reg = 1'b0, m_axis_tlast_next;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast = m_axis_tlast_reg;

logic [15:0] count_reg = '0, count_next;

logic [20:0] ipv4_checksum_reg = '0, ipv4_checksum_next; 

typedef enum logic [1:0] {
    STATE_IPV4_IDLE,
    STATE_IPV4_CHECKSUM,
    STATE_IPV4_HEADER,
    STATE_IPV4_DATA
} state_t;

state_t state_reg = STATE_IPV4_IDLE, state_next;

always_comb begin
    state_next = state_reg;

    s_axis_ipv4_header_next = s_axis_ipv4_header_reg;
    s_axis_ipv4_header_tready_next = s_axis_ipv4_header_tready_reg;

    ipv4_checksum_next = ipv4_checksum_reg;

    s_axis_tdata_next = s_axis_tdata_reg;
    s_axis_tready_next = s_axis_tready_reg;
    s_axis_tlast_next = s_axis_tlast_reg;

    m_axis_tdata_next = m_axis_tdata_reg;
    m_axis_tvalid_next = m_axis_tvalid_reg;
    m_axis_tlast_next = m_axis_tlast_reg;

    count_next = count_reg;

    ipv4_checksum_next = ipv4_checksum_reg;

    case (state_reg)
        STATE_IPV4_IDLE: begin
            s_axis_ipv4_header_tready_next = 1'b1;
            if (s_axis_ipv4_header_tvalid && s_axis_ipv4_header_tready) begin
                s_axis_ipv4_header_next = {s_axis_ipv4_version, s_axis_ipv4_ihl, s_axis_ipv4_dscp,
                                           s_axis_ipv4_ecn, s_axis_ipv4_length, s_axis_ipv4_id, s_axis_ipv4_flags,
                                           s_axis_ipv4_fragment_offset, s_axis_ipv4_ttl, s_axis_ipv4_protocol,
                                           16'd0, s_axis_ipv4_source_ip, s_axis_ipv4_destination_ip};
                s_axis_ipv4_header_tready_next = 1'b0;
                count_next = '0;
                ipv4_checksum_next = '0;
                state_next = STATE_IPV4_CHECKSUM;
            end
        end

        STATE_IPV4_CHECKSUM: begin
            count_next = count_reg + 1'b1;
            case (count_reg)
                'd0: begin
                    ipv4_checksum_next = s_axis_ipv4_header_next[159:144] + s_axis_ipv4_header_next[143:128];
                end

                'd1: begin
                    ipv4_checksum_next = s_axis_ipv4_header_next[127:112] + ipv4_checksum_reg;
                end

                'd2: begin
                    ipv4_checksum_next = s_axis_ipv4_header_next[111:96] + ipv4_checksum_reg;
                end

                'd3: begin
                    ipv4_checksum_next = s_axis_ipv4_header_next[95:80] + ipv4_checksum_reg;
                end

                'd4: begin
                    ipv4_checksum_next = s_axis_ipv4_header_next[63:48] + ipv4_checksum_reg;
                end

                'd5: begin
                    ipv4_checksum_next = s_axis_ipv4_header_next[47:32] + ipv4_checksum_reg;
                end
    
                'd6: begin
                    ipv4_checksum_next = s_axis_ipv4_header_next[31:16] + ipv4_checksum_reg;
                end

                'd7: begin
                    ipv4_checksum_next = s_axis_ipv4_header_next[15:0] + ipv4_checksum_reg;
                end

                'd8: begin
                    if (ipv4_checksum_reg >= 65536) begin
                        count_next = count_reg;
                        ipv4_checksum_next = ipv4_checksum_reg[15:0] + (ipv4_checksum_reg >> 16);
                    end
                end

                'd9: begin
                    s_axis_ipv4_header_next[79:64] = ~ipv4_checksum_reg[15:0];
                    m_axis_tdata_next = s_axis_ipv4_header_reg[159:152];
                    m_axis_tvalid_next = 1'b1;
                    count_next = '0;
                    state_next = STATE_IPV4_HEADER;
                end

                default: begin
                    state_next = STATE_IPV4_IDLE;
                end
            endcase
        end

        STATE_IPV4_HEADER: begin
            if (m_axis_tvalid && m_axis_tready) begin
                s_axis_ipv4_header_next = s_axis_ipv4_header_reg << DATA_WIDTH;
                m_axis_tdata_next = s_axis_ipv4_header_next[159:152];
                count_next = count_reg + 1'b1;
                if (count_next == 20) begin
                    s_axis_tready_next = 1'b1;
                    m_axis_tvalid_next = 1'b0;
                    count_next = '0;
                    state_next = STATE_IPV4_DATA;
                end
            end
        end

        STATE_IPV4_DATA: begin
            if (m_axis_tvalid && m_axis_tready) begin
                s_axis_tready_next = 1'b1;
                m_axis_tvalid_next = 1'b0;
                count_next = count_reg + 1'b1;
                if (s_axis_tlast_reg) begin
                    s_axis_tready_next = 1'b0;
                    m_axis_tlast_next = 1'b0;
                    state_next = STATE_IPV4_IDLE;
                end
            end

            if (s_axis_tvalid && s_axis_tready) begin
                s_axis_tready_next = 1'b0;
                s_axis_tlast_next = s_axis_tlast;
                m_axis_tdata_next = s_axis_tdata;
                m_axis_tvalid_next = 1'b1;
                m_axis_tlast_next = 1'b0;
                if (s_axis_tlast_next) begin
                    m_axis_tlast_next = 1'b1;
                end
            end
        end

        default: begin
            state_next = STATE_IPV4_IDLE;
        end
    endcase
end

always_ff @(posedge i_clk) begin
    state_reg <= state_next;

    s_axis_ipv4_header_reg <= s_axis_ipv4_header_next;
    s_axis_ipv4_header_tready_reg <= s_axis_ipv4_header_tready_next;

    s_axis_tdata_reg <= s_axis_tdata_next;
    s_axis_tready_reg <= s_axis_tready_next;
    s_axis_tlast_reg <= s_axis_tlast_next;

    m_axis_tdata_reg <= m_axis_tdata_next;
    m_axis_tvalid_reg <= m_axis_tvalid_next;
    m_axis_tlast_reg <= m_axis_tlast_next;

    count_reg <= count_next;

    ipv4_checksum_reg <= ipv4_checksum_next;
end

endmodule
