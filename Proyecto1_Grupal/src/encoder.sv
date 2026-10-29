module encoder_inputs (
    input logic [4:0] f,
    output logic [2:0] b
);
    logic neg_f0, neg_f1, neg_f2, neg_f3;
    not U_NOT_F0(neg_f0, f[0]);
    not U_NOT_F1(neg_f1, f[1]);
    not U_NOT_F2(neg_f2, f[2]);
    not U_NOT_F3(neg_f3, f[3]);

    logic gap0, gap1, gap2, gap3, valid;
    and U_GAP0(gap0, f[1], neg_f0);
    and U_GAP1(gap1, f[2], neg_f1);
    and U_GAP2(gap2, f[3], neg_f2);
    and U_GAP3(gap3, f[4], neg_f3);

    nor U_CALC_VALID(valid, gap0, gap1, gap2, gap3);

    logic b0_term1, b0_term2;
    and U_CALC_B0_1(b0_term1, neg_f1, f[0]);
    and U_CALC_B0_2(b0_term2, neg_f3, f[2]);

    logic b1_raw, b0_raw;
    and U_CALC_B1_RAW(b1_raw, f[1], neg_f3);
    or U_CALC_B0_RAW(b0_raw, b0_term1, b0_term2, f[4]);

    and U_CALC_B0(b[0], b0_raw, valid);
    and U_CALC_B1(b[1], b1_raw, valid);
    and U_CALC_B2(b[2], f[3], valid);
endmodule