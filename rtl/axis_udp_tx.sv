module axis_udp_tx # (
    parameter DATA_WIDTH = 8
) (
    input wire logic i_clk,
    input wire logic i_rst,

    // UDP AXI-Stream header sink interface
    input wire logic [15:0] s_axis_udp_source_port,
    input wire logic [15:0] s_axis_udp_destination_port,
    input wire logic [15:0] s_axis_udp_length,
    input wire logic s_axis_udp_header_tvalid,
    output wire logic s_axis_udp_header_tready,

    // UDP AXI-Stream data sink interface
    input wire logic [DATA_WIDTH - 1:0] s_axis_tdata,
    input wire logic s_axis_tvalid,
    output wire logic s_axis_tready,
    input wire logic s_axis_tlast,

    // UDP AXI-Stream data source interface
    output wire logic [DATA_WIDTH - 1:0] m_axis_tdata,
    output wire logic m_axis_tvalid,
    input wire logic m_axis_tready,
    output wire logic m_axis_tlast
);

logic [63:0] s_axis_udp_header_reg = '0, s_axis_udp_header_next;
logic s_axis_udp_header_tready_reg = 1'b0, s_axis_udp_header_tready_next;

assign s_axis_udp_header_tready = s_axis_udp_header_tready_reg;

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

logic [20:0] udp_checksum_reg = '0, udp_checksum_next; 

typedef enum logic [1:0] {
    STATE_UDP_IDLE,
    STATE_UDP_CHECKSUM,
    STATE_UDP_HEADER,
    STATE_UDP_DATA
} state_t;

state_t state_reg = STATE_UDP_IDLE, state_next;

always_comb begin
    state_next = state_reg;

    s_axis_udp_header_next = s_axis_udp_header_reg;
    s_axis_udp_header_tready_next = s_axis_udp_header_tready_reg;

    udp_checksum_next = udp_checksum_reg;

    s_axis_tdata_next = s_axis_tdata_reg;
    s_axis_tready_next = s_axis_tready_reg;
    s_axis_tlast_next = s_axis_tlast_reg;

    m_axis_tdata_next = m_axis_tdata_reg;
    m_axis_tvalid_next = m_axis_tvalid_reg;
    m_axis_tlast_next = m_axis_tlast_reg;

    count_next = count_reg;

    udp_checksum_next = udp_checksum_reg;

    case (state_reg)
        STATE_UDP_IDLE: begin
            s_axis_udp_header_tready_next = 1'b1;
            if (s_axis_udp_header_tvalid && s_axis_udp_header_tready) begin
                s_axis_udp_header_next = {s_axis_udp_source_port, s_axis_udp_destination_port,
                                          s_axis_udp_length, 16'd0};
                s_axis_udp_header_tready_next = 1'b0;
                m_axis_tdata_next = s_axis_udp_header_next[63:56];
                m_axis_tvalid_next = 1'b1;
                count_next = '0;
                udp_checksum_next = '0;
                // state_next = STATE_UDP_CHECKSUM;
                state_next = STATE_UDP_HEADER;
            end
        end

        // STATE_UDP_CHECKSUM: begin
        // end

        STATE_UDP_HEADER: begin
            if (m_axis_tvalid && m_axis_tready) begin
                s_axis_udp_header_next = s_axis_udp_header_reg << DATA_WIDTH;
                m_axis_tdata_next = s_axis_udp_header_next[63:56];
                count_next = count_reg + 1'b1;
                if (count_next == 8) begin
                    s_axis_tready_next = 1'b1;
                    m_axis_tvalid_next = 1'b0;
                    count_next = '0;
                    state_next = STATE_UDP_DATA;
                end
            end
        end

        STATE_UDP_DATA: begin
            if (m_axis_tvalid && m_axis_tready) begin
                s_axis_tready_next = 1'b1;
                m_axis_tvalid_next = 1'b0;
                count_next = count_reg + 1'b1;
                if (s_axis_tlast_reg) begin
                    s_axis_tready_next = 1'b0;
                    m_axis_tlast_next = 1'b0;
                    state_next = STATE_UDP_IDLE;
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
            state_next = STATE_UDP_IDLE;
        end
    endcase
end

always_ff @(posedge i_clk) begin
    state_reg <= state_next;

    s_axis_udp_header_reg <= s_axis_udp_header_next;
    s_axis_udp_header_tready_reg <= s_axis_udp_header_tready_next;

    s_axis_tdata_reg <= s_axis_tdata_next;
    s_axis_tready_reg <= s_axis_tready_next;
    s_axis_tlast_reg <= s_axis_tlast_next;

    m_axis_tdata_reg <= m_axis_tdata_next;
    m_axis_tvalid_reg <= m_axis_tvalid_next;
    m_axis_tlast_reg <= m_axis_tlast_next;

    count_reg <= count_next;

    udp_checksum_reg <= udp_checksum_next;
end

endmodule
