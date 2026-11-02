import alu_types_pkg::*;

// PWM de N bits. La velocidad (vel) sale de la ALU con src1, src2 y op_code.
//
// El contador va de 0 a 2^N - 2 (para N = 3: 0 a 6, o sea 7 pasos) y vuelve a 0.
// pwm_out = 1 mientras cnt < vel, entonces:
//   duty = vel / (2^N - 1)   ->   N = 3: vel / 7 = 0 %, 14 %, 29 %, ... 86 %, 100 %
// Asi las 7 velocidades (1 a 7) quedan repartidas de forma pareja hasta el 100 %.
//
// El contador solo avanza cuando step = 1 (step viene de un tick_var), entonces
//   f_pwm = f_step / (2^N - 1)

module pwm #(
    parameter N = 3
) (
    input logic clk,
    input logic rst,
    input logic step,
    input logic [N-1:0] src1,
    input logic [N-1:0] src2,
    input alu_op_e op_code,

    output logic pwm_out,
    output logic [N-1:0] vel
);
    logic [N-1:0] cnt;
    logic [N-1:0] cnt_incr;
    logic [N-1:0] cnt_wrap;
    logic [N-1:0] cnt_next;
    logic [N-1:0] neg_vel;
    logic neg_pwm;
    logic neg_cnt0;
    logic at_max;

    alu_nbit #(.N(N)) U_ALU(
        .a(src1),
        .b(src2),
        .alu_control(op_code),
        .result(vel),
        .flags()
    );
    not_nbit #(.N(N)) U_NEG_VEL(
        .src(vel),
        .neg_src(neg_vel)
    );

    // cnt + 1
    ripple_adder #(.N(N)) U_CALC_CNT(
        .a(cnt),
        .b({{(N-1){1'b0}}, 1'b1}),
        .c_in(1'b0),
        .res(cnt_incr),
        .c_out()
    );

    // cnt == 2^N - 2: todos los bits en 1 menos el bit 0 (N = 3: 110)
    not U_NOT_CNT0(neg_cnt0, cnt[0]);
    assign at_max = (&cnt[N-1:1]) & neg_cnt0;

    // si llego al maximo vuelve a 0, si no suma 1
    mux_2_1_param #(.N(N)) U_MUX_WRAP(
        .a(cnt_incr),
        .b({N{1'b0}}),
        .sel(at_max),
        .y(cnt_wrap)
    );

    // solo avanza cuando hay step, si no se conserva
    mux_2_1_param #(.N(N)) U_MUX_STEP(
        .a(cnt),
        .b(cnt_wrap),
        .sel(step),
        .y(cnt_next)
    );

    always_ff @( posedge clk, negedge rst ) begin
        if(!rst) cnt <= '0;
        else     cnt <= cnt_next;
    end

    // cnt - vel: c_out = 1 cuando cnt >= vel
    ripple_adder #(.N(N)) U_CMP(
        .a(cnt),
        .b(neg_vel),
        .c_in(1'b1),
        .res(),
        .c_out(neg_pwm)
    );

    not U_NOT(pwm_out, neg_pwm);

endmodule
