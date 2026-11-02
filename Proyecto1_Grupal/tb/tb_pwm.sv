`timescale 1ns/1ps
import alu_types_pkg::*;

module tb_pwm;
    localparam N       = 3;
    localparam PERIODO = (1 << N) - 1;   // 7 pasos por periodo (cnt de 0 a 6)

    logic         clk = 0;
    logic         rst;
    logic         step;
    logic [N-1:0] src1, src2;
    alu_op_e      op_code;
    logic         pwm_out;

    int errores = 0;

    pwm #(.N(N)) dut (
        .clk(clk), .rst(rst), .step(step),
        .src1(src1), .src2(src2), .op_code(op_code),
        .pwm_out(pwm_out),
        .vel()
    );

    // Reloj de 10 ns
    always #5 clk = ~clk;

    // Modelo de referencia: contador y salida esperada
    logic [N-1:0] ref_cnt;
    logic [N-1:0] vel_esperada;
    logic         pwm_esperado;

    assign vel_esperada = src1 + src2;           // la ALU hace suma
    assign pwm_esperado = (ref_cnt < vel_esperada);

    always_ff @(posedge clk or negedge rst) begin
        if (!rst)      ref_cnt <= '0;
        else if (step) ref_cnt <= (ref_cnt == PERIODO - 1) ? '0 : ref_cnt + 1'b1;
    end

    // Chequeo ciclo a ciclo (en el flanco de bajada, ya estable)
    always @(negedge clk) begin
        if (rst && pwm_out !== pwm_esperado) begin
            errores++;
            $error("[%0t] pwm_out=%b esperado=%b (cnt=%0d vel=%0d)",
                   $time, pwm_out, pwm_esperado, ref_cnt, vel_esperada);
        end
    end

    // Prueba una velocidad: reset, y cuenta los ciclos en alto de un periodo
    task automatic probar_velocidad(input logic [N-1:0] v);
        int altos = 0;
        src1 = v;
        src2 = '0;
        step = 0;
        rst  = 0;
        repeat (2) @(negedge clk);
        rst  = 1;
        step = 1;

        repeat (PERIODO) begin
            @(negedge clk);
            if (pwm_out) altos++;
        end

        if (altos !== v) begin
            errores++;
            $error("vel=%0d: ciclos en alto=%0d (esperado %0d)", v, altos, v);
        end else begin
            $display("vel=%0d OK: %0d/%0d ciclos en alto (%0.1f %%)",
                     v, altos, PERIODO, 100.0 * altos / PERIODO);
        end
    endtask

    initial begin
        op_code = ADD_OP;   // <-- cambia por el nombre real de la suma en alu_types_pkg
        src1 = '0;
        src2 = '0;
        step = 0;
        rst  = 1;

        // 1. Todas las velocidades (0 a 7) con step siempre activo; vel = 7 debe dar 100 %
        for (int v = 0; v <= PERIODO; v++)
            probar_velocidad(v[N-1:0]);

        // 2. step intermitente (un pulso cada 4 ciclos), velocidad 3
        src1 = 3; src2 = 0;
        rst = 0; step = 0;
        repeat (2) @(negedge clk);
        rst = 1;
        repeat (PERIODO * 2) begin
            step = 1;
            @(negedge clk);
            step = 0;
            repeat (3) @(negedge clk);
        end

        // 3. Cambio de velocidad en medio de la simulación
        step = 1;
        src1 = 2;
        repeat (PERIODO) @(negedge clk);
        src1 = 6;
        repeat (PERIODO) @(negedge clk);

        // 4. Reset asíncrono a mitad de periodo
        #3 rst = 0;
        #2 rst = 1;
        repeat (PERIODO) @(negedge clk);

        if (errores == 0) $display("TODAS LAS PRUEBAS PASARON");
        else              $display("%0d ERRORES", errores);
        $finish;
    end

endmodule