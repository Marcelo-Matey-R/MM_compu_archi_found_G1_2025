module shift_right #(
    parameter N = 8,
    localparam S = $clog2(N)
)(
    input  logic [N-1:0] a,
    input  logic [S-1:0] sh,
    output logic [N-1:0] y
);
    // stage[k] es la salida de la etapa k-1 (stage[0] = entrada)
    logic [N-1:0] stage [S:0];

    assign stage[0] = a;

    genvar i;
    generate
        for (i = 0; i < S; i++) begin : etapa
            localparam K = 2**i;
            mux_2_1_param #(.N(N)) U_CALC_STAGE(
                .a(stage[i]),
                .b({{K{1'b0}}, stage[i][N-1:K]}),
                .sel(sh[i]),
                .y(stage[i+1])
            );
        end
    endgenerate

    assign y = stage[S];
endmodule