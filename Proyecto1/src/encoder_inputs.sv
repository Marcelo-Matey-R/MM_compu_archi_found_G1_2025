module encoder_5_3 (
    input logic [4:0] f,
    output logic [2:0] b
);

    logic neg_f2, neg_f4;
    logic b2_1, b2_2;

    not U_NOT(neg_f2, f[2]);
    not U_NOT2(neg_f4, f[4]);

    assign b[2] = f[4];

    and U_AND(b[1], neg_f4, f[2]);
    and U_AND2(b2_1, neg_f2, f[1]);
    and U_AND3(b2_2, neg_f4, f[3]);

    or U_OR(b[0], b2_1, b2_2);



    
endmodule