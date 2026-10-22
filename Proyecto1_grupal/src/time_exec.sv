import alu_types_pkg::*;

module time_exec #(
    parameter TICK_BITS = 14, //el acumulador se actualiza una vez cada 2^14 ciclos
    parameter L = 12_207,     //4 s * 50 MHz / 2^TICK_BITS
    parameter N = 15          //se debe cumplir L + 7 < 2^(N-1), por la flag negative
)(
    input logic clk,
    input logic rst,          //activo en bajo
    input logic enable,       //motor_open | motor_close
    input logic [2:0] v,

    output logic timeout
);

    logic [N - 1 : 0] x0;
    logic [N - 1 : 0] next_x0;
    logic [1 : 0] current_state;
    logic [1 : 0] next_state;

    always_ff @(posedge clk) begin
        if (!rst) begin
            x0 <= '0;
            current_state <= 2'b00;
        end else begin
            current_state <= next_state;
            x0 <= next_x0;
        end
    end


    //prescaler: contador que corre libre, su acarreo de salida es el tick
    //(pulso de 1 ciclo cada 2^TICK_BITS ciclos)

    logic [TICK_BITS - 1 : 0] cnt;
    logic [TICK_BITS - 1 : 0] next_cnt;
    logic tick;

    ripple_adder #(.N(TICK_BITS)) U_PRESCALER (
        .a(cnt),
        .b({{(TICK_BITS - 1){1'b0}}, 1'b1}),
        .c_in(1'b0),
        .res(next_cnt),
        .c_out(tick)              //1 cuando cnt es todo unos
    );

    always_ff @(posedge clk) begin
        if (!rst) cnt <= '0;
        else      cnt <= next_cnt;
    end


    //codificacion: 00 = IDLE, 01 = SUM, 10 = CHECK, 11 = HALT

    logic S0, S1, nS0, nS1;
    logic nextS0, nextS1;
    logic negative, not_negative, not_enable, not_tick;
    logic y1, y2, y3, y4, y5;

    assign S0 = current_state[0];
    assign S1 = current_state[1];

    not u_not_s0(nS0, S0);
    not u_not_s1(nS1, S1);
    not u_not_enable(not_enable, enable);
    not u_not_neg(not_negative, negative);
    not u_not_tick(not_tick, tick);

    //logica de siguiente estado:
    //SUM se queda en SUM hasta que llega el tick, y ahi pasa a CHECK.
    //
    //nextS1 = EN * ( S1 * (S0 + !Neg) + !S1 * S0 * Tick )
    //nextS0 = EN * ( !S0 + S1 + !Tick )

    or  u_or_y1(y1, S0, not_negative);
    and u_and_y2(y2, S1, y1);                //CHECK sin negative, o HALT
    and u_and_y3(y3, nS1, S0, tick);         //SUM con tick
    or  u_or_y4(y4, y2, y3);
    and u_and_nextS1(nextS1, enable, y4);

    or  u_or_y5(y5, nS0, S1, not_tick);
    and u_and_nextS0(nextS0, enable, y5);

    assign next_state = {nextS1, nextS0};

    //salida Moore:
    and u_and_timeout(timeout, S1, S0);


    //instanciacion de la alu y locuras varias:

    localparam logic [N - 1 : 0] L_vec = L;
    logic [N - 1 : 0] v_ext;
    logic [N - 1 : 0] alu_result;
    logic [N - 1 : 0] src_b;
    logic [N - 1 : 0] intermedian;

    alu_op_e alu_op;
    alu_flags_t flags;

    assign v_ext = {{(N - 3){1'b0}}, v};
    assign alu_op = alu_op_e'({2'b00, S1});   //S1 = 0: ADD, S1 = 1: SUB

    mux_2_1_param #(.N(N)) U_MUXB (
        .a(v_ext),
        .b(L_vec),
        .sel(S1),
        .y(src_b)
    );

    alu_nbit #(.N(N)) U_ALU (
        .a(x0),
        .b(src_b),
        .alu_control(alu_op),
        .result(alu_result),
        .flags(flags)
    );

    assign negative = flags.negative;

    //x0 solo se actualiza en SUM con tick, en los demas estados se conserva:
    logic is_sum, write_x, hold;

    and u_is_sum(is_sum, nS1, S0);
    and u_write_x(write_x, is_sum, tick);
    not u_hold(hold, write_x);

    mux_2_1_param #(.N(N)) U_MUXC (
        .a(alu_result),
        .b(x0),
        .sel(hold),
        .y(intermedian)
    );

    //si enable baja, x0 vuelve a 0:
    mux_2_1_param #(.N(N)) U_MUXD (
        .a(intermedian),
        .b('0),
        .sel(not_enable),
        .y(next_x0)
    );

endmodule