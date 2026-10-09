module hex_decoder (
    input  logic open,
    input  logic close,
    input logic valid,
    output logic [6:0] seg   // {g, f, e, d, c, b, a}
);

    logic y1;
    logic val;

    and U_AND(y1, open, close);
    not U_NOT(val, y1);

    logic a_d;
    nand U_AND2(a_d, val, valid);

    logic b_c;
    nand U_AND3(b_c, val, open);

    assign seg[0] = a_d;
    assign seg[3] = a_d;

    assign seg[1] = b_c;
    assign seg[2] = b_c;

    assign seg[4] = 1'b0;
    assign seg[5] = 1'b0;

    assign seg[6] = 1'b1;

endmodule