import alu_types_pkg::*;

module buzzer (
    input logic clk,
    input logic rst,                // activo en bajo
    input logic [2:0] evento,
    output logic buzzer_out         // va al transistor del buzzer
);

    localparam S = 15;

    localparam logic [S - 1:0] D1 = 15'd14285;  // prueba
    localparam logic [S - 1:0] D2 = 15'd3570;   // registrada
    localparam logic [S - 1:0] D3 = 15'd4761;   // valida
    localparam logic [S - 1:0] D4 = 15'd28570;  // invalida
    localparam logic [S - 1:0] D5 = 15'd7142;   // abriendo
    localparam logic [S - 1:0] D6 = 15'd10203;  // cerrando

    // Decodificador de evento 
    logic n0, n1, n2;
    logic e1, e2, e3, e4, e5, e6;
    logic activo;

    not U_N0(n0, evento[0]);
    not U_N1(n1, evento[1]);
    not U_N2(n2, evento[2]);

    and U_E1(e1, n2, n1, evento[0]);                // 001
    and U_E2(e2, n2, evento[1], n0);                // 010
    and U_E3(e3, n2, evento[1], evento[0]);         // 011
    and U_E4(e4, evento[2], n1, n0);                // 100
    and U_E5(e5, evento[2], n1, evento[0]);         // 101
    and U_E6(e6, evento[2], evento[1], n0);         // 110

    or U_ACTIVO(activo, e1, e2, e3, e4, e5, e6);

    // Divisor segun el evento 
    // Cada bit del divisor es el OR de las lineas e_k cuya constante tiene ese bit en 1
    logic [S - 1:0] div;
    logic [S - 1:0] t1, t2, t3, t4, t5, t6;

    genvar i;
    generate
        for (i = 0; i < S; i++) begin : div_bits
            and U_T1(t1[i], e1, D1[i]);
            and U_T2(t2[i], e2, D2[i]);
            and U_T3(t3[i], e3, D3[i]);
            and U_T4(t4[i], e4, D4[i]);
            and U_T5(t5[i], e5, D5[i]);
            and U_T6(t6[i], e6, D6[i]);
            or  U_OR(div[i], t1[i], t2[i], t3[i], t4[i], t5[i], t6[i]);
        end
    endgenerate

    //Tick con divisor variable + pwm 
    logic step;
    logic pwm_raw;

    tick_var #(.S(S)) U_TICK (
        .clk(clk),
        .rst(rst),
        .div(div),
        .step(step)
    );

    // vel = 4 + 0 = 4 -> duty de 4/7 (57 %), suficiente para el buzzer
    pwm #(.N(3)) U_PWM (
        .clk(clk),
        .rst(rst),
        .step(step),
        .src1(3'd4),
        .src2(3'd0),
        .op_code(alu_op_e'(3'b000)),   // 000 = ADD_OP
        .pwm_out(pwm_raw),
        .vel()
    );

    // Sin evento la salida queda en 0 (transistor apagado)
    and U_OUT(buzzer_out, pwm_raw, activo);

endmodule
