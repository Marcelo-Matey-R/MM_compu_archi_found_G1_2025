// Ingreso de la contrasenia: tres digitos de 3 bits (0 a 5 dedos), uno por cada captura.
// Reemplaza a la ruta serial anterior (sr_165 + dsr_595 + select_storage).
//
// Cada pulso en 'capture' guarda el digito que se esta mostrando en ese momento:
//   1er pulso -> d1 (operacion de la ALU)
//   2do pulso -> d2 (operando A)
//   3er pulso -> d3 (operando B)
// Despues del 3er pulso 'ready' vale 1 durante un ciclo y la MEF vuelve a esperar el 1er digito.
// d1, d2 y d3 se quedan guardados hasta que llegue el siguiente 1er pulso,
// asi que quien los use debe leerlos (o copiarlos) cuando ready = 1.
//
// 'capture' es un pulso de un ciclo. Puede venir del flanco de un boton (sync_edge_detector)
// o de un tick lento; este modulo no depende de cual.
//
// Codificacion de estados (S1 S0):
//   00 = ESPERA_D1    01 = ESPERA_D2    10 = ESPERA_D3    11 = LISTO
//
// Ecuaciones de siguiente estado (cap = capture):
//   nextS1 = !S1 * S0 * cap  +  S1 * !S0
//   nextS0 = !S1 * !S0 * cap  +  !S1 * S0 * !cap  +  S1 * !S0 * cap
// Salida (Moore):
//   ready = S1 * S0
// Escrituras de los registros (solo cuando hay captura en ese estado):
//   we1 = !S1 * !S0 * cap
//   we2 = !S1 *  S0 * cap
//   we3 =  S1 * !S0 * cap

module digit_capture (
    input logic clk,
    input logic rst,                // activo en bajo
    input logic capture,            // pulso de un ciclo: guardar el digito actual
    input logic [2:0] digit,        // digito actual (salida de encoder_inputs), asincrono

    output logic [2:0] d1,          // operacion
    output logic [2:0] d2,          // operando A
    output logic [2:0] d3,          // operando B
    output logic [8:0] code,        // {d1, d2, d3}
    output logic ready,             // 1 ciclo: los tres digitos ya estan guardados
    output logic [1:0] state        // para el display o el buzzer guia (que digito toca)
);

    // ---------------- Sincronizador del digito (viene de los sensores) ----------------
    logic [2:0] digit_ff1;
    logic [2:0] digit_s;

    always_ff @(posedge clk, negedge rst) begin
        if (!rst) begin
            digit_ff1 <= '0;
            digit_s   <= '0;
        end else begin
            digit_ff1 <= digit;
            digit_s   <= digit_ff1;
        end
    end

    // ---------------- MEF ----------------
    logic [1:0] current_state;
    logic [1:0] next_state;

    logic S0, S1, nS0, nS1;
    logic nextS0, nextS1;
    logic ncap;

    assign S0 = current_state[0];
    assign S1 = current_state[1];

    not u_not_s0(nS0, S0);
    not u_not_s1(nS1, S1);
    not u_not_cap(ncap, capture);

    // nextS1
    logic a1, a2;
    and u_and_a1(a1, nS1, S0, capture);
    and u_and_a2(a2, S1, nS0);
    or  u_or_nextS1(nextS1, a1, a2);

    // nextS0
    logic b1, b2, b3;
    and u_and_b1(b1, nS1, nS0, capture);
    and u_and_b2(b2, nS1, S0, ncap);
    and u_and_b3(b3, S1, nS0, capture);
    or  u_or_nextS0(nextS0, b1, b2, b3);

    assign next_state = {nextS1, nextS0};

    always_ff @(posedge clk, negedge rst) begin
        if (!rst) current_state <= 2'b00;
        else      current_state <= next_state;
    end

    and u_and_ready(ready, S1, S0);

    assign state = current_state;

    // ---------------- Registros de los digitos ----------------
    logic we1, we2, we3;
    logic [2:0] d1_next, d2_next, d3_next;

    and u_and_we1(we1, nS1, nS0, capture);
    and u_and_we2(we2, nS1, S0,  capture);
    and u_and_we3(we3, S1,  nS0, capture);

    // Si hay escritura entra el digito, si no se conserva el valor
    mux_2_1_param #(.N(3)) U_MUX_D1 (.a(d1), .b(digit_s), .sel(we1), .y(d1_next));
    mux_2_1_param #(.N(3)) U_MUX_D2 (.a(d2), .b(digit_s), .sel(we2), .y(d2_next));
    mux_2_1_param #(.N(3)) U_MUX_D3 (.a(d3), .b(digit_s), .sel(we3), .y(d3_next));

    always_ff @(posedge clk, negedge rst) begin
        if (!rst) begin
            d1 <= '0;
            d2 <= '0;
            d3 <= '0;
        end else begin
            d1 <= d1_next;
            d2 <= d2_next;
            d3 <= d3_next;
        end
    end

    assign code = {d1, d2, d3};

endmodule
