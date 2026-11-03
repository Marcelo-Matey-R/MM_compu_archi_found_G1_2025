`timescale 1ns/1ps

module tb_motor_control;

    // Entradas del DUT
    logic clk;
    logic rst;          // activo en bajo
    logic open;
    logic close;
    logic sen_opened;
    logic sen_closed;

    // Salidas del DUT
    logic motor_open;
    logic motor_close;

    // Codificacion de estados (la misma del modulo)
    localparam logic [1:0] CERRADO  = 2'b00;
    localparam logic [1:0] ABRIENDO = 2'b01;
    localparam logic [1:0] ABIERTO  = 2'b10;
    localparam logic [1:0] CERRANDO = 2'b11;

    // Contador de fallos para el resumen final
    int fallos = 0;

    motor_control dut (
        .clk(clk),
        .rst(rst),
        .open(open),
        .close(close),
        .sen_opened(sen_opened),
        .sen_closed(sen_closed),
        .motor_open(motor_open),
        .motor_close(motor_close)
    );

    // Reloj de 10 ns
    initial clk = 0;
    always #5 clk = ~clk;

    // Espera un flanco de subida y 1 ns extra para que las salidas se asienten
    task ciclo;
        @(posedge clk);
        #1;
    endtask

    // Compara el estado interno Y las salidas del motor contra lo esperado.
    // Las salidas esperadas salen del estado: motor_open solo en ABRIENDO,
    // motor_close solo en CERRANDO.
    task check(input logic [1:0] exp_state, input string msg);
        logic exp_open, exp_close;
        exp_open  = (exp_state == ABRIENDO);
        exp_close = (exp_state == CERRANDO);

        if (dut.current_state !== exp_state ||
            motor_open !== exp_open || motor_close !== exp_close) begin
            $display("[%0t] FALLO: %s  (estado=%b, esperado %b | open=%b close=%b)",
                     $time, msg, dut.current_state, exp_state,
                     motor_open, motor_close);
            fallos++;
        end else begin
            $display("[%0t] OK:    %s  (estado=%b)", $time, msg, dut.current_state);
        end
    endtask

    initial begin
        // Valores iniciales, con reset activo
        rst = 0; open = 0; close = 0;
        sen_opened = 0; sen_closed = 0;

        // 1. Reset: debe quedar en CERRANDO
        ciclo; ciclo;
        check(CERRANDO, "reset -> CERRANDO");
        rst = 1;

        // 2. CERRANDO sin sensor de cerrado: se queda cerrando
        ciclo; ciclo;
        check(CERRANDO, "CERRANDO se queda sin sen_closed");

        // 3. Llega el sensor de cerrado: pasa a CERRADO
        sen_closed = 1;
        ciclo;
        check(CERRADO, "sen_closed -> CERRADO");

        // 4. close estando CERRADO: no debe cambiar
        close = 1;
        ciclo;
        check(CERRADO, "CERRADO ignora close");
        close = 0;

        // 5. open estando CERRADO: pasa a ABRIENDO
        open = 1;
        ciclo;
        sen_closed = 0;        // la puerta ya se despego del tope
        check(ABRIENDO, "open -> ABRIENDO");
        open = 0;

        // 6. ABRIENDO sin sensor de abierto: se queda abriendo
        ciclo; ciclo;
        check(ABRIENDO, "ABRIENDO se queda sin sen_opened");

        // 7. open mientras ABRIENDO: no debe cambiar
        open = 1;
        ciclo;
        check(ABRIENDO, "ABRIENDO ignora open");
        open = 0;

        // 8. close mientras ABRIENDO: tampoco debe cambiar
        close = 1;
        ciclo;
        check(ABRIENDO, "ABRIENDO ignora close");
        close = 0;

        // 9. Llega el sensor de abierto: pasa a ABIERTO
        sen_opened = 1;
        ciclo;
        check(ABIERTO, "sen_opened -> ABIERTO");

        // 10. open estando ABIERTO: no debe cambiar
        open = 1;
        ciclo;
        check(ABIERTO, "ABIERTO ignora open");
        open = 0;

        // 11. close estando ABIERTO: pasa a CERRANDO
        close = 1;
        ciclo;
        sen_opened = 0;        // la puerta ya se despego del tope
        check(CERRANDO, "close -> CERRANDO");
        close = 0;

        // 12. CERRANDO sin sensor de cerrado: se queda cerrando
        ciclo; ciclo;
        check(CERRANDO, "CERRANDO se queda sin sen_closed");

        // 13. open mientras CERRANDO: no debe cambiar
        open = 1;
        ciclo;
        check(CERRANDO, "CERRANDO ignora open");
        open = 0;

        // 14. Llega el sensor de cerrado: pasa a CERRADO
        sen_closed = 1;
        ciclo;
        check(CERRADO, "sen_closed -> CERRADO");

        // 15. Reset a medias: abrir y tirar reset en pleno movimiento
        open = 1;
        ciclo;
        open = 0;
        sen_closed = 0;
        check(ABRIENDO, "open -> ABRIENDO (antes del reset)");

        rst = 0;
        ciclo;
        rst = 1;
        check(CERRANDO, "reset a medias -> CERRANDO");

        // 16. Tras el reset, cierra hasta que el sensor avise
        sen_closed = 1;
        ciclo;
        check(CERRADO, "tras reset -> CERRADO");

        // Resumen
        if (fallos == 0)
            $display("TODAS LAS PRUEBAS PASARON");
        else
            $display("HUBO %0d FALLO(S)", fallos);

        $finish;
    end

endmodule
