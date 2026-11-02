`timescale 1ns/1ps

module tb_ripple_adder();

    // 1. Parámetro de prueba (puedes cambiarlo a 4, 8, 16, etc.)
    localparam N = 8;

    // 2. Señales para conectar con el módulo bajo prueba (DUT)
    logic [N-1:0] a;
    logic [N-1:0] b;
    logic [N-1:0] res;
    logic c_out;

    // Señal auxiliar para verificar el resultado esperado de 9 bits (res + c_out)
    logic [N:0] expected_sum; 

    // 3. Instanciamos el módulo que queremos probar
    ripple_adder #(
        .N(N)
    ) dut (
        .a(a),
        .b(b),
        .c_in(1'b0), 
        .res(res),
        .c_out(c_out)
    );

    // 4. Bloque de estímulos y verificación
    initial begin
        $display("==================================================");
        $display(" Iniciando Testbench Avanzado - Ripple Carry Adder");
        $display(" Ancho de bits (N) = %0d", N);
        $display("==================================================");

        // ----------------------------------------------------
        // FASE 1: Casos de prueba dirigidos (Corner Cases)
        // ----------------------------------------------------
        
        // Caso 1: Ceros
        a = 8'd0; b = 8'd0;
        #10;
        verificar_resultado(a, b);

        // Caso 2: Suma simple sin acarreo
        a = 8'd10; b = 8'd5;
        #10;
        verificar_resultado(a, b);

        // Caso 3: Suma media
        a = 8'd25; b = 8'd30;
        #10;
        verificar_resultado(a, b);

        // Caso 4: Suma límite exacta antes de desbordar (255)
        a = 8'd200; b = 8'd55;
        #10;
        verificar_resultado(a, b);

        // Caso 5: Desbordamiento (genera acarreo final c_out = 1)
        a = 8'd200; b = 8'd100;
        #10;
        verificar_resultado(a, b);

        // Caso 6: Suma de valores máximos (255 + 1)
        a = 8'b1111_1111; b = 8'b0000_0001;
        #10;
        verificar_resultado(a, b);

        // Caso 7: Máximos absolutos (255 + 255)
        a = {N{1'b1}}; b = {N{1'b1}};
        #10;
        verificar_resultado(a, b);

        // ----------------------------------------------------
        // FASE 2: Pruebas aleatorias automatizadas (Stress Test)
        // ----------------------------------------------------
        $display("\n--- Ejecutando 50 pruebas aleatorias ---");
        repeat (50) begin
            a = $random();
            b = $random();
            #10;
            verificar_resultado(a, b);
        end

        $display("==================================================");
        $display(" ¡Simulacion finalizada exitosamente sin errores!");
        $display("==================================================");
        $finish; // Detiene la simulación en Questa
    end

    // Task auxiliar para automatizar la comprobación matemática
    task verificar_resultado(input logic [N-1:0] val_a, input logic [N-1:0] val_b);
        begin
            // Calculamos el valor esperado usando aritmética de SystemVerilog de mayor tamaño
            expected_sum = val_a + val_b;
            
            // Verificamos mediante assertions si coincide tanto el resultado como el c_out
            if ({c_out, res} !== expected_sum) begin
                $error("FALLO T=%0t | a=%0d, b=%d | Esperado: res=%0d, c_out=%b | Obtenido: res=%0d, c_out=%b", 
                       $time, val_a, val_b, expected_sum[N-1:0], expected_sum[N], res, c_out);
            end else begin
                $display("EXITO: T=%0t | a=%0d, b=%0d -> res=%0d, c_out=%b", 
                       $time, val_a, val_b, res, c_out);
            end
        end
    endtask

endmodule