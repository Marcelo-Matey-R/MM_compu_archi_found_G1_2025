`timescale 1ns/1ps
import alu_types_pkg::*;

// Prueba de integracion: main_fsm + digit_capture + password_memory + motor_control (los reales),
// con un modelo sencillo de la puerta que mueve una posicion y activa los sensores.
//
// Ademas de las pruebas paso a paso, hay un monitor que revisa todo el tiempo que no pase nada raro:
//   - nunca se manda toggle a la puerta mientras se mueve
//   - motor_open y motor_close nunca al mismo tiempo
//   - el evento del buzzer nunca vale 111
//   - mem_toggle solo en ADMIN

module tb_main_fsm;

    localparam T_BITS = 4;          // sonidos cortos de 8 ciclos para que la simulacion sea rapida
    localparam DOOR_T = 40;         // ciclos que tarda la puerta de un extremo al otro

    // codigos de estado
    localparam logic [2:0] ESPERA = 3'b000, ADMIN = 3'b001, VALIDA = 3'b010, MOVIENDO = 3'b011,
                           PRUEBA_A = 3'b100, PRUEBA_B = 3'b101, REGISTRADA = 3'b110, INVALIDA = 3'b111;

    logic clk = 0;
    logic rst = 0;
    always #10 clk = ~clk;

    // ---------------- Estimulos ----------------
    logic cap_btn = 0;              // pulso del boton (o tick) de captura
    logic [2:0] digit = 0;
    logic btn_admin = 0;
    logic btn_test = 0;

    // ---------------- Interconexion ----------------
    logic capture, listening;
    logic [2:0] d1, d2, d3;
    logic [8:0] code;
    logic ready;
    logic [1:0] dc_state;
    logic hit, full;
    logic [3:0] used;
    logic door_toggle, mem_toggle, vel_fija;
    logic [2:0] evento, state;
    logic motor_open, motor_close;
    logic sen_opened, sen_closed;
    logic vel_ok;
    logic [2:0] vel;

    assign capture = cap_btn & listening;

    digit_capture U_DC (
        .clk(clk), .rst(rst), .capture(capture), .digit(digit),
        .d1(d1), .d2(d2), .d3(d3), .code(code), .ready(ready), .state(dc_state)
    );

    password_memory U_MEM (
        .clk(clk), .rst(rst), .code(code), .toggle(mem_toggle),
        .hit(hit), .full(full), .used(used)
    );

    // velocidad = ALU(d1, d2, d3); en el top real esto va al pwm del motor
    alu_nbit #(.N(3)) U_ALU (
        .a(d2), .b(d3), .alu_control(alu_op_e'(d1)), .result(vel), .flags()
    );
    // velocidad usable: operacion valida (0 a 4) y velocidad distinta de 0
    assign vel_ok = (d1 <= 3'd4) && (vel != 3'd0);

    main_fsm #(.T_BITS(T_BITS)) U_FSM (
        .clk(clk), .rst(rst),
        .ready(ready), .hit(hit), .full(full), .vel_ok(vel_ok),
        .btn_admin(btn_admin), .btn_test(btn_test),
        .motor_open(motor_open), .motor_close(motor_close),
        .door_toggle(door_toggle), .mem_toggle(mem_toggle), .vel_fija(vel_fija),
        .listening(listening), .evento(evento), .state(state)
    );

    motor_control U_MOTOR (
        .clk(clk), .rst(rst),
        .open(door_toggle), .close(door_toggle),
        .sen_opened(sen_opened), .sen_closed(sen_closed),
        .motor_open(motor_open), .motor_close(motor_close)
    );

    // ---------------- Modelo de la puerta ----------------
    int pos = DOOR_T / 2;           // arranca a medio camino
    always @(posedge clk) begin
        if (motor_open  && pos < DOOR_T) pos <= pos + 1;
        if (motor_close && pos > 0)      pos <= pos - 1;
    end
    assign sen_closed = (pos == 0);
    assign sen_opened = (pos == DOOR_T);

    // ---------------- Monitor ----------------
    int fallos = 0;

    always @(posedge clk) begin
        if (rst) begin
            if (door_toggle && (motor_open || motor_close)) begin
                $display("FALLO (monitor) t=%0t: toggle a la puerta mientras se mueve", $time); fallos++;
            end
            if (motor_open && motor_close) begin
                $display("FALLO (monitor) t=%0t: motor_open y motor_close a la vez", $time); fallos++;
            end
            if (evento == 3'b111) begin
                $display("FALLO (monitor) t=%0t: evento 111", $time); fallos++;
            end
            if (mem_toggle && state != ADMIN) begin
                $display("FALLO (monitor) t=%0t: mem_toggle fuera de ADMIN", $time); fallos++;
            end
        end
    end

    // ---------------- Tareas ----------------
    task automatic check(input logic cond, input string msg);
        if (!cond) begin
            $display("FALLO: %s (state=%0d evento=%b used=%b pos=%0d dc_state=%0d)",
                     msg, state, evento, used, pos, dc_state);
            fallos++;
        end else begin
            $display("OK:    %s", msg);
        end
    endtask

    task automatic pulso(ref logic s);
        @(negedge clk) s = 1;
        @(negedge clk) s = 0;
    endtask

    // Muestra los tres digitos y da un pulso de captura por cada uno
    task automatic ingresar(input logic [2:0] a, input logic [2:0] b, input logic [2:0] c);
        logic [2:0] dig [3];
        dig[0] = a; dig[1] = b; dig[2] = c;
        for (int i = 0; i < 3; i++) begin
            digit = dig[i];
            repeat (4) @(negedge clk);
            cap_btn = 1;
            @(negedge clk);
            cap_btn = 0;
        end
    endtask

    // Espera hasta que el estado valga s (max ciclos). Devuelve 1 si llego.
    task automatic esperar_estado(input logic [2:0] s, input int max, output logic llego);
        int n = 0;
        while (state !== s && n < max) begin
            @(negedge clk);
            n++;
        end
        llego = (state === s);
    endtask

    // Espera a que la puerta quede quieta y la MEF en ESPERA
    task automatic esperar_reposo();
        logic ok;
        esperar_estado(ESPERA, 1000, ok);
        while (motor_open || motor_close) @(negedge clk);
        repeat (2) @(negedge clk);
    endtask

    logic llego;
    logic vio_abriendo, vio_cerrando, vio_prueba_siempre;

    initial begin
        // ======================= 1. Reset =======================
        repeat (3) @(negedge clk);
        check(state == ESPERA && used == 4'b0000, "reset: ESPERA y memoria vacia");
        rst = 1;
        repeat (2) @(negedge clk);
        check(motor_close && vel_fija, "despues del reset la puerta se cierra sola, con la velocidad fija");
        check(!listening, "mientras la puerta se mueve no se escucha");
        // intentar ingresar un codigo mientras se cierra: debe ignorarse
        ingresar(3'd0, 3'd3, 3'd2);
        check(dc_state == 2'b00 && state == ESPERA, "un codigo mientras se mueve se ignora");
        esperar_reposo();
        check(pos == 0 && sen_closed, "la puerta llego a cerrada");
        check(listening, "con la puerta quieta en ESPERA se escucha");

        // ======================= 2. Codigo no registrado =======================
        ingresar(3'd0, 3'd3, 3'd2);         // ADD 3 + 2 = 5
        @(negedge clk);
        check(state == INVALIDA && evento == 3'b100, "032 sin registrar: INVALIDA, suena invalida");
        esperar_reposo();
        check(state == ESPERA && pos == 0, "vuelve a ESPERA y la puerta no se movio");

        // ======================= 3. Registrar 032 =======================
        pulso(btn_admin);
        @(negedge clk);
        check(state == ADMIN, "boton admin: ADMIN");
        ingresar(3'd0, 3'd3, 3'd2);
        @(negedge clk);
        check(state == REGISTRADA && evento == 3'b010 && used == 4'b0001,
              "032 en ADMIN: se guarda y suena registrada");
        esperar_reposo();
        check(state == ESPERA && pos == 0, "vuelve a ESPERA sin mover la puerta");

        // ======================= 4. Abrir con 032 =======================
        ingresar(3'd0, 3'd3, 3'd2);
        @(negedge clk);
        check(state == VALIDA && evento == 3'b011, "032 registrada: VALIDA, suena valida");
        check(vel == 3'd5, "velocidad = 3 + 2 = 5");
        esperar_estado(MOVIENDO, 100, llego);
        @(negedge clk);
        check(llego && motor_open && evento == 3'b101 && !vel_fija, "MOVIENDO: abre con la velocidad del codigo y suena abriendo");
        // boton de prueba y de admin mientras se mueve: se ignoran
        pulso(btn_test);
        pulso(btn_admin);
        @(negedge clk);
        check(state == MOVIENDO, "botones durante el movimiento se ignoran");
        esperar_reposo();
        check(pos == DOOR_T && sen_opened && state == ESPERA, "la puerta quedo abierta y vuelve a ESPERA");

        // ======================= 5. Cerrar con 032 =======================
        ingresar(3'd0, 3'd3, 3'd2);
        esperar_estado(MOVIENDO, 100, llego);
        @(negedge clk);
        check(llego && motor_close && evento == 3'b110, "misma contrasenia con la puerta abierta: cierra, suena cerrando");
        esperar_reposo();
        check(pos == 0 && state == ESPERA, "la puerta quedo cerrada");

        // ======================= 6. Registrar codigos que no sirven =======================
        pulso(btn_admin);
        ingresar(3'd2, 3'd0, 3'd3);         // MUL 0 * 3 = 0 -> velocidad 0
        @(negedge clk);
        check(state == INVALIDA && used == 4'b0001, "203 da velocidad 0: no se registra, suena invalida");
        esperar_reposo();

        pulso(btn_admin);
        ingresar(3'd5, 3'd1, 3'd1);         // operacion 5 no existe
        @(negedge clk);
        check(state == INVALIDA && used == 4'b0001, "511 tiene operacion invalida: no se registra");
        esperar_reposo();

        // ======================= 7. Llenar la memoria =======================
        pulso(btn_admin); ingresar(3'd0, 3'd1, 3'd1); esperar_reposo();
        pulso(btn_admin); ingresar(3'd0, 3'd2, 3'd2); esperar_reposo();
        pulso(btn_admin); ingresar(3'd0, 3'd4, 3'd1); esperar_reposo();
        check(used == 4'b1111 && full, "con 4 contrasenias la memoria esta llena");

        pulso(btn_admin);
        ingresar(3'd0, 3'd1, 3'd2);
        @(negedge clk);
        check(state == INVALIDA && used == 4'b1111, "memoria llena: 012 no se guarda, suena invalida");
        esperar_reposo();

        // ======================= 8. Borrar 022 =======================
        pulso(btn_admin);
        ingresar(3'd0, 3'd2, 3'd2);
        @(negedge clk);
        check(state == REGISTRADA && used == 4'b1011, "repetir 022 en ADMIN la borra (ranura 2 libre)");
        esperar_reposo();
        ingresar(3'd0, 3'd2, 3'd2);
        @(negedge clk);
        check(state == INVALIDA, "022 ya no abre");
        esperar_reposo();
        check(pos == 0, "la puerta sigue cerrada");

        // ======================= 9. Entrar y salir de ADMIN =======================
        pulso(btn_admin);
        @(negedge clk);
        check(state == ADMIN, "entra a ADMIN");
        pulso(btn_admin);
        @(negedge clk);
        check(state == ESPERA && used == 4'b1011, "segundo boton admin: sale sin cambiar nada");

        // ======================= 10. Metodo de prueba =======================
        vio_abriendo = 0; vio_cerrando = 0; vio_prueba_siempre = 1;
        pulso(btn_test);
        @(negedge clk);
        check(state == PRUEBA_A && vel_fija && motor_open, "boton de prueba: PRUEBA_A y abre con la velocidad fija");
        while (state == PRUEBA_A || state == PRUEBA_B) begin
            if (evento != 3'b001) vio_prueba_siempre = 0;
            if (motor_open)  vio_abriendo = 1;
            if (motor_close) vio_cerrando = 1;
            @(negedge clk);
        end
        check(vio_prueba_siempre, "el sonido de prueba suena todo el tiempo");
        check(vio_abriendo && vio_cerrando, "en la prueba la puerta abre y luego cierra");
        check(state == ESPERA && pos == 0 && !vel_fija, "termina en ESPERA con la puerta cerrada");

        // ======================= 11. Digitos sueltos mientras suena un resultado =======================
        ingresar(3'd1, 3'd1, 3'd1);         // invalida
        @(negedge clk);
        check(state == INVALIDA && !listening, "durante INVALIDA no se escucha");
        // un pulso de captura ahora no debe avanzar digit_capture
        cap_btn = 1; @(negedge clk); cap_btn = 0;
        check(dc_state == 2'b00, "la captura durante el sonido se ignora");
        esperar_reposo();

        // ======================= 12. Reset borra las contrasenias =======================
        rst = 0;
        repeat (3) @(negedge clk);
        rst = 1;
        check(used == 4'b0000, "reset borra todas las contrasenias");
        esperar_reposo();
        ingresar(3'd0, 3'd3, 3'd2);
        @(negedge clk);
        check(state == INVALIDA, "032 ya no es valida despues del reset");
        esperar_reposo();

        if (fallos == 0) $display("TODAS LAS PRUEBAS PASARON");
        else             $display("HUBO %0d FALLO(S)", fallos);
        $finish;
    end

    // Por si algo se traba
    initial begin
        #5ms;
        $display("FALLO: la simulacion no termino (algo se trabo), state=%0d", state);
        $finish;
    end

endmodule
