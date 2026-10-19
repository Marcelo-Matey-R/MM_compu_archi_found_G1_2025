module or_nbit #(
    parameter N = 8
) (
    input logic [N-1:0] src1,
    input logic [N-1:0] src2,
    output logic [N-1:0] y
);
    genvar i;
    generate
        for(i = 0; i < N; i++) begin : neg_bits
            or U_OR(y[i], src1[i], src2[i]);
        end
    endgenerate
endmodule