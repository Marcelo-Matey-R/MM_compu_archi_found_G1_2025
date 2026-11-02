module full_adder(
    input logic a,
    input logic b,
    input logic c_in,
    output logic s,
    output logic c_out
);
    
    logic w1, w2, w3, w4, w5;

    xor u_xor(w1, a, b);
    xor u_xor2(s, w1, c_in);

    and u_and(w2, a, b);
    and u_and2(w3, a, c_in);
    and u_and3(w4, b, c_in);
 
    or u_or(w5, w2, w3);
    or u_or2(c_out, w4, w5);

endmodule

