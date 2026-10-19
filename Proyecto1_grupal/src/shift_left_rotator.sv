module shift_left_rotator #(
    parameter N = 8,
    localparam S = $clog2(N)
) (
    input  logic [N-1:0] a,
    input  logic [S-1:0] sh,
    output logic [N-1:0] y
);
    logic [N-1:0] stage [S+1];

    assign stage[0] = a;

    genvar i;
    generate
        for (i = 0; i < S; i++) begin : g_stage
            localparam K = 2**i;   // siempre 1 <= K <= N-1
            mux_2_1_param #(.N(N)) U_CALC_STAGE(
                .a(stage[i]),
                .b({stage[i][N-1-K:0], stage[i][N-1:N-K]}),
                .sel(sh[i]),
                .y(stage[i+1])
            );
        end
    endgenerate

    assign y = stage[S];
endmodule