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

    genvar k, i;
    generate
        for (k = 0; k < S; k++) begin : etapa
            localparam int DESP = 2**k;
            for (i = 0; i < N; i++) begin : bit_i
                if (i + DESP >= N) begin : relleno
                    // Bits que entran por la izquierda: 0 si se desplaza
                    mux_2_1 m (
                        .a(stage[k][i]),
                        .b(1'b0),
                        .sel(sh[k]),
                        .y (stage[k+1][i])
                    );
                end else begin : desplaza
                    mux_2_1 m (
                        .a(stage[k][i]),
                        .b(stage[k][i + DESP]),
                        .sel(sh[k]),
                        .y(stage[k+1][i])
                    );
                end
            end
        end
    endgenerate

    assign y = stage[S];
endmodule