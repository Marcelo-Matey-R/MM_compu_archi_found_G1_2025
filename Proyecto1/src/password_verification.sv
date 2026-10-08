module password (
    input logic [8:0] d_in,
    output logic open,
    output logic close,
    output logic valid
);

    logic y1;
    logic y2;
    logic y3;
    logic y4;

    logic y_d32;
    logic y_open;

    is_four Y1 (
        .d_in(d_in[8:6]),
        .out(y1)
    );

    is_tree Y2 (
        .d_in(d_in[5:3]),
        .out(y2)
    );

    lsb_calc LSB (
        .d_in(d_in[2:0]),
        .out1(y3),
        .out2(y4)
    );

    and U_AND (y_d32, y1, y2);
    and U_AND2(close, y_d32, y3);
    and U_AND3(open, y_d32, y4);

    xor XOR(valid, open, close);

endmodule