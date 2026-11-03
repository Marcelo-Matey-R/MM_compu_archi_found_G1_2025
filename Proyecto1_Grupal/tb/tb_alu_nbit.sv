`timescale 1ns/1ps
import alu_types_pkg::*;

module tb_alu_nbit();

    // 1. Parámetro de prueba (puedes cambiarlo a 4, 8, 16, etc.)
    localparam int N = 26;

    // 2. Señales para conectar con el DUT (Device Under Test)
    logic [N-1:0] a;
    logic [N-1:0] b;
    alu_op_e      alu_control;
    logic [N-1:0] result;
    alu_flags_t   flags;

    // 3. Instancia de la ALU
    alu_nbit #(
        .N(N)
    ) dut (
        .a(a),
        .b(b),
        .alu_control(alu_control),
        .result(result),
        .flags(flags)
    );

    // Variables auxiliares para modelar el comportamiento esperado en el testbench
    logic [N:0] expected_full;
    logic       expected_carry;
    logic       expected_negative;
    logic       expected_zero;
    logic       expected_overflow;

    // 4. Bloque de estímulos y verificación automática
    initial begin
        $display("==================================================");
        $display(" Iniciando Testbench - ALU N-bits (N=%0d)", N);
        $display("==================================================");

        
        // FASE 1: Pruebas de Suma (ADD_OP)
        
        $display("\n--- Probando Operacion: ADD ---");
        alu_control = ADD_OP;

        // Caso 1.1: Suma simple
        a = 8'd15; b = 8'd10;
        #10;
        verificar_alu(ADD_OP, a, b);

        // Caso 1.2: Suma con Cero
        a = 8'd42; b = 8'd0;
        #10;
        verificar_alu(ADD_OP, a, b);

        // Caso 1.3: Suma que genera desbordamiento (Overflow / Carry)
        a = 8'd200; b = 8'd100; // 300 -> Desborda 8 bits
        #10;
        verificar_alu(ADD_OP, a, b);


        
        // FASE 2: Pruebas de Resta (SUB_OP)
        
        $display("\n--- Probando Operacion: SUB ---");
        alu_control = SUB_OP;

        // Caso 2.1: Resta simple
        a = 8'd50; b = 8'd20;
        #10;
        verificar_alu(SUB_OP, a, b);

        // Caso 2.2: Resta que da exactamente cero
        a = 8'd77; b = 8'd77;
        #10;
        verificar_alu(SUB_OP, a, b);

        // Caso 2.3: Resta con resultado negativo (bajo complemento a 2)
        a = 8'd10; b = 8'd25;
        #10;
        verificar_alu(SUB_OP, a, b);


        
        // FASE 3: Stress test / Pruebas Aleatorias Automatizadas
        
        $display("\n--- Ejecutando pruebas aleatorias (ADD & SUB) ---");
        repeat (4000) begin
            a = $random();
            b = $random();
            // Alternar aleatoriamente entre ADD y SUB
            alu_control = ($random() % 2 == 0) ? ADD_OP : SUB_OP;
            #10;
            verificar_alu(alu_control, a, b);
        end

        $display("==================================================");
        $display(" Simulacion de la ALU finalizada exitosamente");
        $display("==================================================");
        $finish;
    end

    // Task de verificación automática para comparar hardware vs modelo de referencia
    task verificar_alu(input alu_op_e op, input logic [N-1:0] val_a, input logic [N-1:0] val_b);
        begin
            // Calcular modelo esperado según la operación
            case (op)
                ADD_OP: begin
                    expected_full = val_a + val_b;
                    expected_carry = expected_full[N];
                    expected_overflow = (val_a[N-1] == val_b[N-1]) && (expected_full[N-1] != val_a[N-1]);
                end
                SUB_OP: begin
                    expected_full = val_a - val_b;
                    // En resta con sumador, el c_out actúa como borrow invertido o carry de la resta
                    expected_carry = expected_full[N]; // O según tu convención de resta por MUX
                    expected_overflow = (val_a[N-1] != val_b[N-1]) && (expected_full[N-1] != val_a[N-1]);
                end
                default: begin
                    expected_full = '0;
                    expected_carry = 0;
                    expected_overflow = 0;
                end
            endcase

            expected_negative = expected_full[N-1];
            expected_zero     = (expected_full[N-1:0] == '0);

            // Mostrar traza en consola
            $display("Op=%s | a=%0d, b=%0d -> Res=%0d | Flags: C=%b, Z=%b, N=%b, V=%b",
                     op.name(), val_a, val_b, result, flags.carry, flags.zero, flags.negative, flags.overflow);

            // Validaciones con Assertions
            assert (result === expected_full[N-1:0]) else 
                $error("FALLO EN RESULTADO Esperado: %0d, Obtenido: %0d", expected_full[N-1:0], result);
            
            assert (flags.negative === expected_negative) else 
                $error("FALLO EN FLAG NEGATIVE");
            
            assert (flags.zero === expected_zero) else 
                $error("FALLO EN FLAG ZERO");
            
            assert (flags.overflow === expected_overflow) else 
                $error("FALLO EN FLAG OVERFLOW");
        end
    endtask

endmodule