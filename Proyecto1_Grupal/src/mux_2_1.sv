module mux_2_1 (
    input logic a,
    input logic b,
    input logic sel,
    output logic y
);

    logic neg_sel, a_out, b_out;

    not U_NOT(neg_sel, sel);
    and U_AND(a_out, a, neg_sel);
    and U_AND2(b_out, b, sel);

    or U_OR(y, a_out, b_out);

endmodule