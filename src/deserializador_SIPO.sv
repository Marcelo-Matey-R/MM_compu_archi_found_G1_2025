module dsr_595 #(
    parameter N = 9
)(
    input logic clk,
    input logic rst,
    input logic step,
    input logic ser,
    output logic [N-1:0] q
);

    logic [N-1:0] shift_reg;

    genvar i;

    generate

        flip_flop_595 sh_reg_0(
            .clk(clk),
            .rst(rst),
            .en(step),
            .d_in(ser),
            .q(shift_reg[0])
        );

        flip_flop_595 mem_reg_0(
            .clk(clk),
            .rst(rst),
            .en(step),
            .d_in(shift_reg[0]),
            .q(q[0])
        );

        for(i = 1; i < N; i++) begin : ff_loop

            flip_flop_595 sh_reg(
                .clk(clk),
                .rst(rst),
                .en(step),
                .d_in(shift_reg[i-1]),
                .q(shift_reg[i])
            );

            flip_flop_595 mem_reg(
                .clk(clk),
                .rst(rst),
                .en(step),
                .d_in(shift_reg[i]),
                .q(q[i])
            );

        end

    endgenerate

endmodule