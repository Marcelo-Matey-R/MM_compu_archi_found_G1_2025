module not_nbit #(
    parameter N = 8
) (
    input logic [N-1:0] src,
    output logic [N-1:0] neg_src
);
    genvar i;
    generate
        for(i = 0; i < N; i++) begin : neg_bits
            not U_NOT(neg_src[i], src[i]);
        end
    endgenerate
endmodule