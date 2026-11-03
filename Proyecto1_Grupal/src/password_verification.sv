module password_ver (
    input logic [8:0] close_pass,
    input logic [8:0] open_pass,
    input logic [8:0] d_in,
    output logic open,
    output logic close,
    output logic invalid
);
    logic [8:0] diff_open;
    logic [8:0] diff_close;

    xnor_nbit #(.N(9)) U_OPEN_DIFF(
        .src1(open_pass),
        .src2(d_in),
        .y(diff_open)
    );
    xnor_nbit #(.N(9)) U_CLOSE_DIFF(
        .src1(d_in),
        .src2(close_pass),
        .y(diff_close)
    );
    and U_CLOSE_VER(close, diff_close[0], diff_close[1], diff_close[2], diff_close[3], diff_close[4], diff_close[5], diff_close[6], diff_close[7], diff_close[8]);
    and U_OPEN_VER(open, diff_open[0], diff_open[1], diff_open[2], diff_open[3], diff_open[4], diff_open[5], diff_open[6], diff_open[7], diff_open[8]);
    xnor U_INV_VER(invalid, open, close);

endmodule