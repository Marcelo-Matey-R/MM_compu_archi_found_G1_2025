module sr_165 #(
    parameter N = 3
)(
    input logic clk,
    input logic rst,
    input logic sh,
    input logic step,
    input logic [N-1:0] d_in,
    output logic qh
);

    logic [N-1:0] q;
    logic en;
    logic ld;
    not U_NOT(ld, sh);
    or U_OR(en, step, ld);


    genvar i;

    generate

        flip_flop_165 first (
            .clk(clk),
            .rst(rst),
            .load(sh),
            .en(en),
            .d_ser(1'b0),
            .d_par(d_in[0]),
            .q(q[0])
        );
        
        for(i = 1; i < N; i++) begin : ff_loop

            flip_flop_165 ff(
                .clk(clk),
                .rst(rst),
                .load(sh),
                .en(en),
                .d_ser(q[i-1]),
                .d_par(d_in[i]),
                .q(q[i])
            );
        end

    endgenerate


    assign qh = q[N-1];

endmodule