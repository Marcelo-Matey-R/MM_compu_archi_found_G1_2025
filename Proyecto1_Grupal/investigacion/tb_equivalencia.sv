`timescale 1ns/1ps
import alu_types_pkg::*;

module tb_equivalencia;

    int fallos = 0;

    //  Sumadores 
    logic [3:0] a4, b4, s4_e, s4_b;   logic c4, co4_e, co4_b;
    logic [7:0] a8, b8, s8_e, s8_b;   logic c8, co8_e, co8_b;

    ripple_adder          #(.N(4)) U_ADD4_E (.a(a4), .b(b4), .c_in(c4), .res(s4_e), .c_out(co4_e));
    ripple_carry_adder_bh #(.N(4)) U_ADD4_B (.a(a4), .b(b4), .cin(c4),  .sum(s4_b), .cout(co4_b));
    ripple_adder          #(.N(8)) U_ADD8_E (.a(a8), .b(b8), .c_in(c8), .res(s8_e), .c_out(co8_e));
    ripple_carry_adder_bh #(.N(8)) U_ADD8_B (.a(a8), .b(b8), .cin(c8),  .sum(s8_b), .cout(co8_b));

    //  ALUs 
    logic [2:0] a3, b3, r3_e, r3_b;   logic [2:0] op3;   alu_flags_t f3_e, f3_b;
    logic [3:0] a4u, b4u, r4_e, r4_b; logic [2:0] op4;   alu_flags_t f4_e, f4_b;

    alu_nbit    #(.N(3)) U_ALU3_E (.a(a3), .b(b3), .alu_control(alu_op_e'(op3)), .result(r3_e), .flags(f3_e));
    alu_nbit_bh #(.N(3)) U_ALU3_B (.a(a3), .b(b3), .alu_control(alu_op_e'(op3)), .result(r3_b), .flags(f3_b));
    alu_nbit    #(.N(4)) U_ALU4_E (.a(a4u), .b(b4u), .alu_control(alu_op_e'(op4)), .result(r4_e), .flags(f4_e));
    alu_nbit_bh #(.N(4)) U_ALU4_B (.a(a4u), .b(b4u), .alu_control(alu_op_e'(op4)), .result(r4_b), .flags(f4_b));

    //  Decodificadores 
    logic [3:0] x;  logic [6:0] seg_e, seg_b;

    hex7seg         U_HEX_E (.x(x), .seg(seg_e));
    hex7seg_decoder U_HEX_B (.nibble(x), .segments(seg_b));

    initial begin
        // Sumador de 4 bits
        for (int i = 0; i < 16; i++) for (int j = 0; j < 16; j++) for (int c = 0; c < 2; c++) begin
            a4 = i; b4 = j; c4 = c; #1;
            if ({co4_e, s4_e} !== {co4_b, s4_b}) begin
                fallos++; $display("FALLO sumador 4: %0d + %0d + %0d", i, j, c);
            end
        end
        $display("sumador de 4 bits: 512 casos revisados");

        // Sumador de 8 bits
        for (int i = 0; i < 256; i++) for (int j = 0; j < 256; j++) for (int c = 0; c < 2; c++) begin
            a8 = i; b8 = j; c8 = c; #1;
            if ({co8_e, s8_e} !== {co8_b, s8_b}) begin
                fallos++; $display("FALLO sumador 8: %0d + %0d + %0d", i, j, c);
            end
        end
        $display("sumador de 8 bits: 131072 casos revisados");

        // ALU de 3 bits (todas las operaciones, incluidas las que no existen)
        for (int o = 0; o < 8; o++) for (int i = 0; i < 8; i++) for (int j = 0; j < 8; j++) begin
            op3 = o; a3 = i; b3 = j; #1;
            if (r3_e !== r3_b || f3_e !== f3_b) begin
                fallos++; $display("FALLO ALU 3: op=%0d a=%0d b=%0d -> %0d/%b vs %0d/%b", o, i, j, r3_e, f3_e, r3_b, f3_b);
            end
        end
        $display("ALU de 3 bits: 512 casos revisados");

        // ALU de 4 bits
        for (int o = 0; o < 8; o++) for (int i = 0; i < 16; i++) for (int j = 0; j < 16; j++) begin
            op4 = o; a4u = i; b4u = j; #1;
            if (r4_e !== r4_b || f4_e !== f4_b) begin
                fallos++; $display("FALLO ALU 4: op=%0d a=%0d b=%0d -> %0d/%b vs %0d/%b", o, i, j, r4_e, f4_e, r4_b, f4_b);
            end
        end
        $display("ALU de 4 bits: 2048 casos revisados");

        // Decodificador
        for (int i = 0; i < 16; i++) begin
            x = i; #1;
            if (seg_e !== seg_b) begin
                fallos++; $display("FALLO hex: %h -> %b vs %b", x, seg_e, seg_b);
            end
        end
        $display("decodificador: 16 casos revisados");

        if (fallos == 0) $display("TODAS LAS PRUEBAS PASARON: cada par hace lo mismo");
        else             $display("HUBO %0d FALLO(S)", fallos);
        $finish;
    end

endmodule
