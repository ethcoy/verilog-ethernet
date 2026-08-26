interface axis_if #(
    parameter DATA_WIDTH = 8
)
();
    logic [DATA_WIDTH - 1:0] tdata;
    logic tvalid;
    logic tready;
    logic tlast;

    modport snk (
        input  tdata,
        input  tvalid,
        output tready,
        input  tlast
    );

    modport src (
        output tdata,
        output tvalid,
        input  tready,
        output tlast
    );

endinterface