import alu_types_pkg::*;


module top_level #(
    parameter T_BITS    = 25,       // duracion de los sonidos cortos: 2^(T_BITS-1) ciclos (0.34 s)
    parameter MOTOR_DIV = 7142      // tick del pwm del motor: f_pwm = 50 MHz / (7 * (MOTOR_DIV + 1)) = 1 kHz
) (
    input  logic       CLOCK_50,
    input  logic [3:0] KEY,         // activo bajo
    output logic [9:0] LEDR,
    output logic [6:0] HEX0,        // activo bajo
    inout  wire  [35:0] topGPIO
);

    //  Reset -
    logic rst;      // activo en alto (sincronizadores)
    logic rst_n;    // activo en bajo (el resto de modulos)
    assign rst_n = ~rst;

    reset_bridge U_RST_BTN (
        .clk(CLOCK_50),
        .async_rst_in(~KEY[0]),
        .sync_rst_out(rst)
    );

    //  Botones: pulso de un ciclo al presionar 
    logic pulse_cap, pulse_admin, pulse_test;

    sync_edge_detector U_BTN_CAP (
        .clk(CLOCK_50), .rst(rst), .async_in(~KEY[1]),
        .sync_out(), .pulse_out(pulse_cap)
    );

    sync_edge_detector U_BTN_ADMIN (
        .clk(CLOCK_50), .rst(rst), .async_in(~KEY[2]),
        .sync_out(), .pulse_out(pulse_admin)
    );

    sync_edge_detector U_BTN_TEST (
        .clk(CLOCK_50), .rst(rst), .async_in(~KEY[3]),
        .sync_out(), .pulse_out(pulse_test)
    );

    // Sensores de la puerta (sincronizados) -
    logic sen_opened, sen_closed;

    sync_edge_detector U_SEN_OPEN (
        .clk(CLOCK_50), .rst(rst), .async_in(topGPIO[0]),
        .sync_out(sen_opened), .pulse_out()
    );

    sync_edge_detector U_SEN_CLOSE (
        .clk(CLOCK_50), .rst(rst), .async_in(topGPIO[1]),
        .sync_out(sen_closed), .pulse_out()
    );

    // Dedos -> digito 
    // encoder_inputs espera 6 lineas en termometro, donde f[0] = 1 es "cero dedos".
    // Con 5 sensores, f[0] va fijo en 1 y los dedos ocupan f[5:1].
    // (digit_capture sincroniza el digito por dentro)
    logic [5:0] f;
    logic [2:0] digit;

    assign f = {topGPIO[8:4], 1'b1};

    encoder_inputs U_ENCODER (
        .f(f),
        .b(digit)
    );

    //  Captura de los 3 digitos
    logic listening, capture;
    logic [2:0] d1, d2, d3;
    logic [8:0] code;
    logic ready;
    logic [1:0] dc_state;

    and U_CAPTURE(capture, pulse_cap, listening);

    digit_capture U_DIGITS (
        .clk(CLOCK_50), .rst(rst_n),
        .capture(capture), .digit(digit),
        .d1(d1), .d2(d2), .d3(d3), .code(code),
        .ready(ready), .state(dc_state)
    );

    // ---------------- Memoria de contrasenias ----------------
    logic mem_toggle, hit, full;
    logic [3:0] used;

    password_memory U_MEM (
        .clk(CLOCK_50), .rst(rst_n),
        .code(code), .toggle(mem_toggle),
        .hit(hit), .full(full), .used(used)
    );

    //  Velocidad 
    // Normal: vel = ALU(op = d1, A = d2, B = d3).
    // vel_fija (prueba, o el cierre despues del reset): vel = 4 + 0 = 4.
    logic vel_fija;
    logic [2:0] op_sel, a_sel, b_sel;
    logic [2:0] vel;
    logic step_motor, pwm_motor;

    mux_2_1_param #(.N(3)) U_MUX_OP (.a(d1), .b(3'b000), .sel(vel_fija), .y(op_sel));   // 000 = ADD
    mux_2_1_param #(.N(3)) U_MUX_A  (.a(d2), .b(3'd4),   .sel(vel_fija), .y(a_sel));
    mux_2_1_param #(.N(3)) U_MUX_B  (.a(d3), .b(3'd0),   .sel(vel_fija), .y(b_sel));

    tick_var #(.S(15)) U_TICK_MOTOR (
        .clk(CLOCK_50), .rst(rst_n),
        .div(15'(MOTOR_DIV)),
        .step(step_motor)
    );

    pwm #(.N(3)) U_PWM_MOTOR (
        .clk(CLOCK_50), .rst(rst_n), .step(step_motor),
        .src1(a_sel), .src2(b_sel), .op_code(alu_op_e'(op_sel)),
        .pwm_out(pwm_motor), .vel(vel)
    );

    // vel_ok = operacion valida (0 a 4) * velocidad distinta de 0
    //        = !(d1[2] * (d1[1] + d1[0])) * (vel[2] + vel[1] + vel[0])
    logic op_alta, op_mala, op_ok, vel_nz, vel_ok;

    or  U_OP_ALTA(op_alta, d1[1], d1[0]);
    and U_OP_MALA(op_mala, d1[2], op_alta);
    not U_OP_OK  (op_ok, op_mala);
    or  U_VEL_NZ (vel_nz, vel[2], vel[1], vel[0]);
    and U_VEL_OK (vel_ok, op_ok, vel_nz);

    //  MEF general 
    logic door_toggle;
    logic motor_open, motor_close;
    logic [2:0] evento, fsm_state;

    main_fsm #(.T_BITS(T_BITS)) U_FSM (
        .clk(CLOCK_50), .rst(rst_n),
        .ready(ready), .hit(hit), .full(full), .vel_ok(vel_ok),
        .btn_admin(pulse_admin), .btn_test(pulse_test),
        .motor_open(motor_open), .motor_close(motor_close),
        .door_toggle(door_toggle), .mem_toggle(mem_toggle), .vel_fija(vel_fija),
        .listening(listening), .evento(evento), .state(fsm_state)
    );

    //  Puerta 
    // El mismo toggle va a open y close: en CERRADO abre, en ABIERTO cierra.
    motor_control U_DOOR (
        .clk(CLOCK_50), .rst(rst_n),
        .open(door_toggle), .close(door_toggle),
        .sen_opened(sen_opened), .sen_closed(sen_closed),
        .motor_open(motor_open), .motor_close(motor_close)
    );

    logic motor_a, motor_b;
    and U_MOTOR_A(motor_a, motor_open,  pwm_motor);
    and U_MOTOR_B(motor_b, motor_close, pwm_motor);

    //  Buzzer 
    logic buzzer_out;

    buzzer U_BUZZER (
        .clk(CLOCK_50), .rst(rst_n),
        .evento(evento),
        .buzzer_out(buzzer_out)
    );

    // Salidas 
    hex7seg U_HEX (
        .x({vel, vel[2]}),
        .seg(HEX0)
    );

    assign topGPIO[0]     = 1'bz;      // entrada
    assign topGPIO[1]     = 1'bz;      // entrada
    assign topGPIO[2]     = motor_a;
    assign topGPIO[3]     = motor_b;
    assign topGPIO[8:4]   = 5'bzzzzz;  // entradas
    assign topGPIO[9]     = buzzer_out;
    assign topGPIO[35:10] = {26{1'bz}};

    assign LEDR[2:0] = fsm_state;
    assign LEDR[4:3] = dc_state;
    assign LEDR[8:5] = used;
    assign LEDR[9]   = listening;

endmodule
