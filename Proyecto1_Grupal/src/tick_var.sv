// Igual que tick.sv, pero el divisor llega por un puerto (div) en vez de ser fijo.
// step sale en 1 cuando el contador llega a div; el periodo es div + 1 ciclos.
// S debe ser suficiente para el divisor mas grande que se vaya a usar.
module tick_var #(
    parameter S = 15
) (
    input logic clk,
    input logic rst,                // activo en bajo
    input logic [S - 1:0] div,
    output logic step
);

    logic [S - 1:0] cnt;
    logic [S - 1:0] cnt_next;
    logic [S - 1:0] cnt_incr;
    logic [S - 1:0] neg_div;
    logic [S - 1:0] diff;
    logic [S - 1:0] equal_zero_bus;
    logic equal_zero_bit;

    not_nbit #(.N(S)) U_CALC_NEG_DIVS(
        .src(div),
        .neg_src(neg_div)
    );

    ripple_adder #(.N(S)) U_CALC_CNT(
        .a(cnt),
        .b({{(S-1){1'b0}}, 1'b1}),
        .c_in(1'b0),
        .res(cnt_incr),
        .c_out()
    );

    // Limpia el contador cuando se llega a div
    mux_2_1_param #(.N(S)) U_RST_CNT(
        .a(cnt_incr),
        .b({(S){1'b0}}),
        .sel(equal_zero_bit),
        .y(cnt_next)
    );

    // diff = cnt - div
    ripple_adder #(.N(S)) U_CALC_STEP(
        .a(cnt),
        .b(neg_div),
        .c_in(1'b1),
        .res(diff),
        .c_out()
    );

    // diff == 0
    xnor_nbit #(.N(S)) U_CALC_EQUAL(
        .src1(diff),
        .src2({(S){1'b0}}),
        .y(equal_zero_bus)
    );

    assign equal_zero_bit = &equal_zero_bus;
    assign step = equal_zero_bit;

    always_ff @(posedge clk, negedge rst) begin
        if (!rst) cnt <= '0;
        else      cnt <= cnt_next;
    end

endmodule
