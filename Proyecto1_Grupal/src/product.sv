module product #(
    parameter N = 8
) (
    input  logic [N-1:0]   src1, // Multiplicando
    input  logic [N-1:0]   src2, // Multiplicador
    output logic [2*N-1:0] y     // Producto final (2*N bits)
);
    
    logic [2*N-1:0] p [N:0];
    
    assign p[0] = '0;

    genvar i;
    generate
        for (i = 0; i < N; i++) begin : gen_mult_row
            logic [2*N-1:0] src1_extendido;
            logic [2*N-1:0] parcial_product;
            logic [2*N-1:0] to_sum;

            localparam int S_SHIFT = $clog2(2*N);
            logic [S_SHIFT-1:0] shift_amount;
            assign shift_amount = S_SHIFT'(i);

            assign src1_extendido = { {(N){1'b0}}, src1 };

            shift_left #(.N(2*N)) U_SHIFT (
                .a(src1_extendido),
                .sh(shift_amount),
                .y(parcial_product)
            );

            mux_2_1_param #(.N(2*N)) U_MUX (
                .a('0),
                .b(parcial_product),
                .sel(src2[i]),
                .y(to_sum)
            );
            ripple_adder #(.N(2*N)) U_SUM (
                .a(p[i]),
                .b(to_sum),
                .c_in(1'b0),
                .res(p[i+1]),
                .c_out()
            );
               
        end
    endgenerate

    assign y = p[N];

endmodule
