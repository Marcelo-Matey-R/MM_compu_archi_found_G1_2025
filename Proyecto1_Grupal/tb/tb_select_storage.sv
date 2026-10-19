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

    // Igual, pero con step en ciclos consecutivos (sin huecos) y una sola palabra.
    task automatic send_word_burst(input logic [8:0] word,
                                   input logic [1:0] sel);
        s = sel;
        for (int i = 8; i >= 0; i--)
            step_cycle(word[i]);
        step_cycle(1'($urandom_range(0, 1)));       // bit de relleno
        idle(3);

        model_store(word, sel);
        check($sformatf("burst s=%b (word=%b)", sel, word));
    endtask

    // Tres palabras encadenadas, sin ningun ciclo libre entre ellas:
    // el primer bit de cada palabra cae en el ciclo de captura (done) de la anterior.
    // En ese primer step s todavia debe tener el valor de la palabra anterior;
    // cambia justo despues.
    task automatic send_chain(input logic [8:0] wa, input logic [1:0] sa,
                              input logic [8:0] wb, input logic [1:0] sb,
                              input logic [8:0] wc, input logic [1:0] sc);
        // palabra a
        s = sa;
        for (int i = 8; i >= 0; i--)
            step_cycle(wa[i]);
        step_cycle(1'($urandom_range(0, 1)));       // relleno de a

        // palabra b: su 1.er bit coincide con la captura de a (s sigue en sa)
        step_cycle(wb[8]);
        model_store(wa, sa);
        check($sformatf("cadena: captura de a (s=%b)", sa));
        s = sb;
        for (int i = 7; i >= 0; i--)
            step_cycle(wb[i]);
        step_cycle(1'($urandom_range(0, 1)));       // relleno de b

        // palabra c: su 1.er bit coincide con la captura de b (s sigue en sb)
        step_cycle(wc[8]);
        model_store(wb, sb);
        check($sformatf("cadena: captura de b (s=%b)", sb));
        s = sc;
        for (int i = 7; i >= 0; i--)
            step_cycle(wc[i]);
        step_cycle(1'($urandom_range(0, 1)));       // relleno de c

        idle(3);
        model_store(wc, sc);
        check($sformatf("cadena: captura de c (s=%b)", sc));
    endtask

    // Reset en medio de una palabra: debe limpiar src*, count y done
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
    logic [8:0] w, wb, wc;
    logic [1:0] sel, sb, sc;

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
        send_word_burst(9'b110_010_101, 2'b00);
        send_word_burst(9'b001_101_110, 2'b01);
        send_word_burst(9'b101_011_000, 2'b10);

        // 4) s cambia durante la palabra, solo cuenta el valor en done
        $display("--- 4) s cambia durante la palabra");
        send_word_slow(9'b011_011_011, 2'b00, 1, 1'b1);
        send_word_slow(9'b100_100_100, 2'b01, 1, 1'b1);
        send_word_slow(9'b010_101_010, 2'b10, 1, 1'b1);
        send_word_slow(9'b111_000_111, 2'b11, 1, 1'b1);

        // 5) Palabras encadenadas: el 1.er step de una palabra coincide con done
        $display("--- 5) palabras encadenadas");
        send_chain(9'b101_101_001, 2'b00,  9'b010_110_011, 2'b01,  9'b001_001_110, 2'b10);
        send_chain(9'b110_011_100, 2'b10,  9'b000_111_000, 2'b11,  9'b111_000_111, 2'b00);
        // despues de una cadena, el contador debe seguir alineado
        send_word_slow(9'b011_001_101, 2'b01, 2, 1'b0);

        // 6) Reset a mitad de palabra
        $display("--- 6) reset a mitad de palabra");
        reset_mid_word();

        // 7) Aleatorio
        $display("--- 7) aleatorio");
        for (int n = 0; n < 40; n++) begin
            w   = 9'($urandom_range(0, 511));
            sel = 2'($urandom_range(0, 3));
            case ($urandom_range(0, 2))
                0: send_word_slow(w, sel, $urandom_range(0, 3), 1'($urandom_range(0, 1)));
                1: send_word_burst(w, sel);
                default: begin
                    wb = 9'($urandom_range(0, 511));  sb = 2'($urandom_range(0, 3));
                    wc = 9'($urandom_range(0, 511));  sc = 2'($urandom_range(0, 3));
                    send_chain(w, sel, wb, sb, wc, sc);
                end
            endcase
        end

        $display("Checks realizados: %0d", checks);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errores", errors);
        $finish;
    end

endmodule