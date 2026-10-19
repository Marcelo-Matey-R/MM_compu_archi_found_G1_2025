module mux_2_1_param_tb; 

    localparam int N = 32; 

    // Señales de prueba
    logic [N-1:0] a;
    logic [N-1:0] b;
    logic sel;
    logic [N-1:0] y;

    // Instancia del DUT (Device Under Test)
    mux_2_1_param #(.N(N)) dut (
        .a(a),
        .b(b),
        .sel(sel),
        .y(y)
    );

    // Bloque de estímulos
    initial begin
        $display("========================================");
        $display(" Iniciando Testbench MUX 2:1 (%0d bits)", N);
        $display("========================================");

        // Caso 1: Probar selección con sel = 0 (debe pasar 'a')
        a = 32'h12345678;
        b = 32'h87654321;
        sel = 1'b0;
        #10;
        $display("T=%0t | sel=%b | a=%h | b=%h | y=%h", $time, sel, a, b, y);
        assert(y == a) else $error("¡Error! Con sel=0, y debería ser igual a a");

        // Caso 2: Probar selección con sel = 1 (debe pasar 'b')
        sel = 1'b1;
        #10;
        $display("T=%0t | sel=%b | a=%h | b=%h | y=%h", $time, sel, a, b, y);
        assert(y == b) else $error("¡Error! Con sel=1, y debería ser igual a b");

        // Caso 3: Pruebas con valores aleatorios (bucle)
        repeat (100) begin
            a = $random();
            b = $random();
            sel = $random();
            #10;
            $display("T=%0t | sel=%b | a=%h | b=%h | y=%h", $time, sel, a, b, y);
            assert(y == (sel ? b : a)) else $error("¡Error en prueba aleatoria!");
        end

        $display("========================================");
        $display(" Simulacion finalizada sin errores");
        $display("========================================");
        $finish;
    end

    // (Opcional) Generar ondas para visualización en la GUI de QuestaSim
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, mux_2_1_param_tb);
    end

endmodule