`timescale 1ns/1ps

// Prueba del sistema completo desde los pines: botones KEY, dedos y sensores por GPIO,
// motor y buzzer por GPIO, HEX0 y LEDR. La puerta es un modelo que avanza mientras
// la salida del motor (ya con pwm) esta en 1.
//
// Se usan parametros chicos para que la simulacion sea rapida:
//   T_BITS = 4     -> sonidos cortos de 8 ciclos
//   MOTOR_DIV = 2  -> pwm del motor rapido
// El buzzer queda con sus frecuencias reales (por eso la puerta tarda bastante en moverse).

module tb_top_level;

    localparam DOOR_T = 150_000;    // "pasos" del motor de un extremo al otro

    logic clk = 0;
    always #10 clk = ~clk;

    logic [3:0] KEY = 4'b1111;      // activos en bajo
    logic [9:0] LEDR;
    logic [6:0] HEX0;
    tri   [35:0] GPIO;

    top_level #(.T_BITS(4), .MOTOR_DIV(2)) dut (
        .CLOCK_50(clk), .KEY(KEY), .LEDR(LEDR), .HEX0(HEX0), .topGPIO(GPIO)
    );

    // ---------------- Lo que el TB pone en los pines de entrada ----------------
    logic sen_opened, sen_closed;
    logic [4:0] dedos = 5'b00000;

    assign GPIO[0]   = sen_opened;
    assign GPIO[1]   = sen_closed;
    assign GPIO[8:4] = dedos;

    logic motor_a, motor_b, buzzer;
    assign motor_a = GPIO[2];
    assign motor_b = GPIO[3];
    assign buzzer  = GPIO[9];

    // ---------------- Modelo de la puerta ----------------
    int pos = DOOR_T / 2;
    always @(posedge clk) begin
        if (motor_a === 1'b1 && pos < DOOR_T) pos <= pos + 1;
        if (motor_b === 1'b1 && pos > 0)      pos <= pos - 1;
    end
    assign sen_closed = (pos == 0);
    assign sen_opened = (pos == DOOR_T);

    // ---------------- Monitor ----------------
    int fallos = 0;
    int flancos_buzzer = 0;
    logic buzzer_prev = 0;

    always @(posedge clk) begin
        if (motor_a === 1'b1 && motor_b === 1'b1) begin
            $display("FALLO (monitor) t=%0t: motor_a y motor_b a la vez", $time); fallos++;
        end
        if (buzzer === 1'b1 && buzzer_prev === 1'b0) flancos_buzzer++;
        buzzer_prev <= buzzer;
    end

    // ---------------- Tareas ----------------
    task automatic check(input logic cond, input string msg);
        if (!cond) begin
            $display("FALLO: %s (estado=%0d digito=%0d ranuras=%b pos=%0d HEX0=%b)",
                     msg, LEDR[2:0], LEDR[4:3], LEDR[8:5], pos, HEX0);
            fallos++;
        end else begin
            $display("OK:    %s", msg);
        end
    endtask

    // Aprieta y suelta un boton (KEY[k])
    task automatic boton(input int k);
        @(negedge clk) KEY[k] = 0;
        repeat (10) @(negedge clk);
        KEY[k] = 1;
        repeat (10) @(negedge clk);
    endtask

    // Muestra n dedos (termometro) y aprieta el boton de captura
    task automatic dedo(input int n);
        dedos = (5'b1 << n) - 5'b1;
        repeat (10) @(negedge clk);
        boton(1);
    endtask

    task automatic codigo(input int a, input int b, input int c);
        dedo(a); dedo(b); dedo(c);
    endtask

    // Espera a que la MEF este en ESPERA y la puerta quieta
    task automatic esperar_reposo();
        int n = 0;
        while ((LEDR[2:0] != 3'b000 || motor_a === 1'b1 || motor_b === 1'b1 ||
                dut.motor_open || dut.motor_close) && n < 2_000_000) begin
            @(negedge clk);
            n++;
        end
        repeat (20) @(negedge clk);
    endtask

    // seg activo en bajo de b (vel 5) y 9 (vel 4)
    localparam logic [6:0] SEG_B = 7'b0000011;
    localparam logic [6:0] SEG_9 = 7'b0010000;

    int abrio, cerro;

    initial begin
        // ======================= 1. Reset con la puerta a medias =======================
        KEY[0] = 0;
        repeat (5) @(negedge clk);
        KEY[0] = 1;
        repeat (5) @(negedge clk);
        check(dut.motor_close, "despues del reset la puerta se cierra");
        esperar_reposo();
        check(pos == 0 && LEDR[9], "puerta cerrada y escuchando");
        check(LEDR[8:5] == 4'b0000, "sin contrasenias registradas");

        // ======================= 2. Registrar 0-3-2 =======================
        boton(2);
        check(LEDR[2:0] == 3'b001, "KEY[2]: ADMIN");
        codigo(0, 3, 2);
        esperar_reposo();
        check(LEDR[8:5] == 4'b0001, "0-3-2 registrada en la ranura 0");

        // ======================= 3. Contrasenia incorrecta =======================
        codigo(1, 1, 1);
        esperar_reposo();
        check(pos == 0, "1-1-1 no abre la puerta");

        // ======================= 4. Abrir con 0-3-2 =======================
        flancos_buzzer = 0;
        codigo(0, 3, 2);
        check(HEX0 == SEG_B, "HEX0 muestra b (velocidad 5 normalizada)");
        abrio = 0;
        while (!dut.motor_open && abrio < 1000) begin @(negedge clk); abrio++; end
        check(dut.motor_open, "0-3-2: la puerta empieza a abrir");
        esperar_reposo();
        check(pos == DOOR_T, "la puerta llego a abierta");
        $display("       flancos del buzzer mientras abria: %0d (~1 kHz durante ~4 ms)", flancos_buzzer);
        check(flancos_buzzer >= 2, "el buzzer sono mientras abria");

        // ======================= 5. Cerrar con 0-3-2 =======================
        codigo(0, 3, 2);
        cerro = 0;
        while (!dut.motor_close && cerro < 1000) begin @(negedge clk); cerro++; end
        check(dut.motor_close, "la misma contrasenia cierra la puerta");
        esperar_reposo();
        check(pos == 0, "la puerta llego a cerrada");

        // ======================= 6. Metodo de prueba =======================
        abrio = 0; cerro = 0;
        boton(3);
        check(HEX0 == SEG_9, "en prueba HEX0 muestra 9 (velocidad 4 normalizada)");
        while (LEDR[2:0] == 3'b100 || LEDR[2:0] == 3'b101) begin
            if (dut.motor_open)  abrio = 1;
            if (dut.motor_close) cerro = 1;
            @(negedge clk);
        end
        check(abrio && cerro, "la prueba abre y luego cierra");
        esperar_reposo();
        check(pos == 0 && LEDR[2:0] == 3'b000, "termina cerrada y en ESPERA");

        // ======================= 7. Borrar 0-3-2 =======================
        boton(2);
        codigo(0, 3, 2);
        esperar_reposo();
        check(LEDR[8:5] == 4'b0000, "repetir 0-3-2 en ADMIN la borra");
        codigo(0, 3, 2);
        esperar_reposo();
        check(pos == 0, "0-3-2 ya no abre");

        if (fallos == 0) $display("TODAS LAS PRUEBAS PASARON");
        else             $display("HUBO %0d FALLO(S)", fallos);
        $finish;
    end

endmodule
