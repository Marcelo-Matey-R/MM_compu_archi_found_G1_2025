module is_four (
    input logic [2:0] d_in,
    output logic out
);
    logic y;

    logic bit1_neg;
    not U_NOT (bit1_neg, d_in[0]);

    logic bit2_neg;
    not U_NOT2 (bit2_neg, d_in[1]);

    and U_AND (y, bit2_neg, bit1_neg);
    and U_AND2 (out, y, d_in[2]);
endmodule