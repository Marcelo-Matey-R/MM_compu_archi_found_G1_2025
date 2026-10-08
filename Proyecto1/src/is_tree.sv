module is_tree (
    input logic [2:0] d_in,
    output logic out
);
    logic y;

    logic bit3_neg;
    not U_NOT (bit3_neg, d_in[2]);


    and U_AND (y, d_in[1], d_in[0]);
    and U_AND2 (out, y, bit3_neg);
endmodule