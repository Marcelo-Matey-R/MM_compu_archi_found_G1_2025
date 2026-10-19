module tb_select_storage;

    // ------------------------------------------------------------------
    // Señales
    // ------------------------------------------------------------------
    logic       clk  = 0;
    logic       rst;
    logic       step = 0;
    logic       ser  = 0;
    logic [1:0] s    = 2'b11;
    logic [8:0] src1, src2, src3;

    int         errors = 0;
    int         checks = 0;
    logic [8:0] m1, m2, m3;          // modelo de referencia de los 3 registros

    select_storage dut (
        .clk (clk),
        .rst (rst),
        .step(step),
        .ser (ser),
        .s   (s),
        .src1(src1),
        .src2(src2),
        .src3(src3)
    );

    always #5 clk = ~clk;            // periodo de 10 ns

    // Watchdog por si algo se cuelga
    initial begin
        #500000;
        $display("TEST FAILED: timeout");
        $finish;
    end

    // ------------------------------------------------------------------
    // Primitivas de estímulo
    // Todas las tareas empiezan y terminan 1 ns después de un posedge clk.
    // ------------------------------------------------------------------

    // Un ciclo de clk con step = 1 y ser = b (se muestrea en el siguiente posedge)
    task automatic step_cycle(input logic b);
        ser  = b;
        step = 1'b1;
        @(posedge clk); #1;
    endtask

    // n ciclos con step = 0
    task automatic idle(input int n);
        step = 1'b0;
        if (n > 0) begin
            repeat (n) @(posedge clk);
            #1;
        end
    endtask

    // ------------------------------------------------------------------
    // Modelo y chequeo
    // ------------------------------------------------------------------
    task automatic model_store(input logic [8:0] w, input logic [1:0] sel);
        case (sel)
            2'b00:   m1 = w;
            2'b01:   m2 = w;
            2'b10:   m3 = w;
            default: ;               // s = 11: no escribe
        endcase
    endtask

    task automatic check(input string name);
        checks++;
        if (src1 !== m1 || src2 !== m2 || src3 !== m3) begin
            $error("[%0t] %s: esperado %b %b %b, obtenido %b %b %b (q=%b)",
                   $time, name, m1, m2, m3, src1, src2, src3, dut.q);
            errors++;
        end
    endtask

    // ------------------------------------------------------------------
    // Envío de palabras
    // ------------------------------------------------------------------

    // Palabra de 9 bits (MSB primero) + 10.o pulso de relleno.
    // gap      : ciclos de espera entre pulsos de step
    // scramble : si es 1, s cambia en cada bit y solo se fija en sel antes del 10.o pulso
    task automatic send_word_slow(input logic [8:0] word,
                                  input logic [1:0] sel,
                                  input int         gap,
                                  input bit         scramble);
        for (int i = 8; i >= 0; i--) begin
            s = scramble ? 2'($urandom_range(0, 3)) : sel;
            step_cycle(word[i]);
            idle(gap);
        end
        idle(3);
        check("tras 9 pulsos, aun sin guardar");

        s = sel;
        step_cycle(1'($urandom_range(0, 1)));       // bit de relleno
        idle(gap + 3);

        model_store(word, sel);
        check($sformatf("tras 10 pulsos con s=%b (word=%b, gap=%0d, scramble=%0b)",
                        sel, word, gap, scramble));
    endtask

    // Igual, pero con step en ciclos consecutivos (sin huecos).
    // extra = 1: agrega un 11.o step justo en el ciclo en que full esta activo.
    task automatic send_word_burst(input logic [8:0] word,
                                   input logic [1:0] sel,
                                   input bit         extra);
        s = sel;
        for (int i = 8; i >= 0; i--)
            step_cycle(word[i]);
        step_cycle(1'($urandom_range(0, 1)));       // bit de relleno
        if (extra)
            step_cycle(1'($urandom_range(0, 1)));   // step coincide con full
        idle(3);

        model_store(word, sel);
        check($sformatf("burst s=%b (word=%b, extra=%0b)", sel, word, extra));
    endtask

    // Reset en medio de una palabra: debe limpiar src*, count y el desplazador
    task automatic reset_mid_word();
        s = 2'b00;
        for (int i = 0; i < 4; i++) begin
            step_cycle(1'($urandom_range(0, 1)));
            idle(2);
        end
        rst = 1'b0;
        idle(3);
        rst = 1'b1;
        idle(2);

        m1 = '0; m2 = '0; m3 = '0;
        check("reset a mitad de palabra");

        // Despues del reset debe contar 10 pasos desde cero
        send_word_slow(9'b101_010_101, 2'b01, 2, 1'b0);
    endtask

    // ------------------------------------------------------------------
    // Secuencia principal
    // ------------------------------------------------------------------
    logic [8:0] w;
    logic [1:0] sel;

    initial begin
        m1 = '0; m2 = '0; m3 = '0;

        // Reset inicial (activo en bajo)
        rst = 0;
        repeat (3) @(posedge clk);
        #1 rst = 1;
        repeat (2) @(posedge clk);
        #1;
        check("despues del reset");

        // 1) Casos dirigidos, step lento
        $display("--- 1) dirigidos, step lento");
        send_word_slow(9'b001_010_100, 2'b00, 2, 1'b0);   // src1
        send_word_slow(9'b011_100_010, 2'b01, 2, 1'b0);   // src2
        send_word_slow(9'b100_001_011, 2'b10, 2, 1'b0);   // src3
        send_word_slow(9'b100_100_000, 2'b11, 2, 1'b0);   // s=11: no escribe
        send_word_slow(9'b010_011_001, 2'b00, 2, 1'b0);   // sobrescribe src1

        // 2) Palabras limite
        $display("--- 2) palabras limite");
        send_word_slow(9'b000_000_000, 2'b00, 2, 1'b0);
        send_word_slow(9'b111_111_111, 2'b01, 2, 1'b0);
        send_word_slow(9'b100_000_001, 2'b10, 2, 1'b0);

        // 3) Step en ciclos consecutivos
        $display("--- 3) step consecutivo");
        send_word_burst(9'b110_010_101, 2'b00, 1'b0);
        send_word_burst(9'b001_101_110, 2'b01, 1'b0);
        send_word_burst(9'b101_011_000, 2'b10, 1'b0);

        // 4) s cambia durante la palabra, solo cuenta el valor en full
        $display("--- 4) s cambia durante la palabra");
        send_word_slow(9'b011_011_011, 2'b00, 1, 1'b1);
        send_word_slow(9'b100_100_100, 2'b01, 1, 1'b1);
        send_word_slow(9'b010_101_010, 2'b10, 1, 1'b1);
        send_word_slow(9'b111_000_111, 2'b11, 1, 1'b1);

        // 5) Step coincidiendo con el ciclo de full (11 steps seguidos),
        //    y luego una palabra normal para verificar que no se pierde la sincronia
        $display("--- 5) step coincide con full");
        send_word_burst(9'b101_101_001, 2'b00, 1'b1);
        send_word_slow (9'b010_110_011, 2'b01, 2, 1'b0);
        send_word_burst(9'b001_001_110, 2'b10, 1'b1);
        send_word_slow (9'b110_011_100, 2'b00, 2, 1'b0);

        // 6) Reset a mitad de palabra
        $display("--- 6) reset a mitad de palabra");
        reset_mid_word();

        // 7) Aleatorio
        $display("--- 7) aleatorio");
        for (int n = 0; n < 40; n++) begin
            w   = 9'($urandom_range(0, 511));
            sel = 2'($urandom_range(0, 3));
            if ($urandom_range(0, 1))
                send_word_slow(w, sel, $urandom_range(0, 3), 1'($urandom_range(0, 1)));
            else
                send_word_burst(w, sel, 1'($urandom_range(0, 1)));
        end

        $display("Checks realizados: %0d", checks);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errores", errors);
        $finish;
    end

endmodule