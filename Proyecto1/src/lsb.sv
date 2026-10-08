module lsb_calc (
    input logic [2:0] d_in,
    output logic out1,
    output logic out2
);
    logic y1;
    logic y2;

    logic bit1_neg;
    not U_NOT (bit1_neg, d_in[0]);

    logic bit2_neg;
    not U_NOT2 (bit2_neg, d_in[1]);

    logic bit3_neg;
    not U_NOT3 (bit3_neg, d_in[2]);

    // Calculo del numero 2 -> out2
    and U_AND (y2, bit3_neg, bit1_neg);
    and U_AND2 (out2, y2, d_in[1]);


    // Calculo del numero 1 -> out1
    and U_AND3 (y1, bit3_neg, bit2_neg);
    and U_AND4 (out1, y1, d_in[0]);

endmodule