// Top para probar motor_control con el circuito de sensores real (GPIO).
// Los nombres de los puertos coinciden con los del .qsf generado por el
// System Builder (CLOCK_50, SW, KEY, LEDR y GPIOGPIO), asi que no hay
// que tocar el .qsf.
//
// Entradas:
//   SW[0]  = open   (orden de abrir, por ahora a mano)
//   SW[1]  = close  (orden de cerrar, por ahora a mano)
//   KEY[0] = reset  (activo en bajo, es el boton fisico)
//
// Header GPIO (GPIOGPIO):
//   GPIOGPIO[0] = entrada: fototransistor de puerta abierta  (PIN_W15)
//   GPIOGPIO[1] = entrada: fototransistor de puerta cerrada  (PIN_AK2)
//   GPIOGPIO[2] = salida:  LED externo, encendido en motor_open  (PIN_Y16)
//   GPIOGPIO[3] = salida:  LED externo, encendido en motor_close (PIN_AK3)
//
// LEDs de la placa:
//   LEDR[0] = motor_open
//   LEDR[1] = motor_close
//   LEDR[2] = sen_opened sincronizado
//   LEDR[3] = sen_closed sincronizado
//
// Los sensores se asumen activos en alto (1 = la luz llega al fototransistor).
// Si el circuito da lo contrario, invierte la entrada en el sincronizador,
// por ejemplo .async_in(~GPIOGPIO[0]).

module top_motor_test (
    input  logic       CLOCK_50,
    input  logic [9:0] SW,
    input  logic [3:0] KEY,       // activo bajo
    output logic [9:0] LEDR,
    inout  wire  [3:0] GPIOGPIO
);

    // ---------------- Reset ----------------
    logic rst;      // activo en alto, sincronizado (sale de reset_bridge)
    logic rst_n;    // activo en bajo, el que usa motor_control
    assign rst_n = ~rst;

    reset_bridge U_RST_BTN (
        .clk(CLOCK_50),
        .async_rst_in(~KEY[0]),
        .sync_rst_out(rst)
    );

    // ---------------- Sincronizadores de entradas ----------------
    // Se usa solo sync_out (nivel sincronizado), no el pulso.
    logic open_s, close_s, sen_opened_s, sen_closed_s;

    sync_edge_detector U_SYNC_OPEN (
        .clk(CLOCK_50),
        .rst(rst),
        .async_in(SW[0]),
        .sync_out(open_s),
        .pulse_out()
    );

    sync_edge_detector U_SYNC_CLOSE (
        .clk(CLOCK_50),
        .rst(rst),
        .async_in(SW[1]),
        .sync_out(close_s),
        .pulse_out()
    );

    sync_edge_detector U_SYNC_SEN_OPENED (
        .clk(CLOCK_50),
        .rst(rst),
        .async_in(GPIOGPIO[0]),
        .sync_out(sen_opened_s),
        .pulse_out()
    );

    sync_edge_detector U_SYNC_SEN_CLOSED (
        .clk(CLOCK_50),
        .rst(rst),
        .async_in(GPIOGPIO[1]),
        .sync_out(sen_closed_s),
        .pulse_out()
    );

    // ---------------- MEF ----------------
    logic motor_open, motor_close;

    motor_control U_MEF (
        .clk(CLOCK_50),
        .rst(rst_n),
        .open(open_s),
        .close(close_s),
        .sen_opened(sen_opened_s),
        .sen_closed(sen_closed_s),
        .motor_open(motor_open),
        .motor_close(motor_close)
    );

    // ---------------- Salidas ----------------
    // Los pines 0 y 1 del header son entradas: se dejan en alta impedancia.
    assign GPIOGPIO[1:0] = 2'bzz;
    assign GPIOGPIO[2]   = motor_open;
    assign GPIOGPIO[3]   = motor_close;

    assign LEDR[3:0] = {sen_closed_s, sen_opened_s, motor_close, motor_open};
    assign LEDR[9:4] = 6'b000000;

endmodule
