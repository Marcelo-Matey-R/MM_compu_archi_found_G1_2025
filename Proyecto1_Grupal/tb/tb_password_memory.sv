`timescale 1ns/1ps

module tb_password_memory;

    logic clk = 0;
    logic rst = 0;
    logic [8:0] code = 0;
    logic toggle = 0;

    logic hit, full;
    logic [3:0] used;

    password_memory dut (
        .clk(clk), .rst(rst), .code(code), .toggle(toggle),
        .hit(hit), .full(full), .used(used)
    );

    always #10 clk = ~clk;

    int fallos = 0;

    task automatic check(input logic cond, input string msg);
        if (!cond) begin
            $display("FALLO: %s (code=%0o hit=%b full=%b used=%b)", msg, code, hit, full, used);
            fallos++;
        end else begin
            $display("OK:    %s", msg);
        end
    endtask

    // Pone un codigo (3 digitos en octal: 9'o315 = 3,1,5) sin hacer nada
    task automatic poner(input logic [8:0] c);
        code = c;
        #1;
    endtask

    // Pone un codigo y da el pulso de toggle (agregar o borrar)
    task automatic toggle_code(input logic [8:0] c);
        code = c;
        @(negedge clk);
        toggle = 1;
        @(negedge clk);
        toggle = 0;
        #1;
    endtask

    initial begin
        // 1. Reset: memoria vacia. Ojo: code = 000 no debe dar hit aunque las ranuras esten en 0
        repeat (2) @(negedge clk);
        poner(9'o000);
        check(used == 4'b0000 && !hit && !full, "reset: memoria vacia y 000 no es valida");
        rst = 1;

        // 2. Agregar 315
        toggle_code(9'o315);
        check(used == 4'b0001 && hit, "agregar 315 va a la ranura 0 y ya es valida");
        poner(9'o314);
        check(!hit, "314 no es valida");

        // 3. Agregar 042, 501, 233
        toggle_code(9'o042);
        check(used == 4'b0011, "042 va a la ranura 1");
        toggle_code(9'o501);
        check(used == 4'b0111, "501 va a la ranura 2");
        toggle_code(9'o233);
        check(used == 4'b1111 && full, "233 va a la ranura 3 y la memoria queda llena");

        poner(9'o315); check(hit, "315 sigue siendo valida");
        poner(9'o042); check(hit, "042 es valida");
        poner(9'o501); check(hit, "501 es valida");
        poner(9'o233); check(hit, "233 es valida");

        // 4. Llena: una nueva no se guarda
        toggle_code(9'o111);
        check(used == 4'b1111 && !hit, "con la memoria llena 111 no se guarda");

        // 5. Repetir 042 la borra
        toggle_code(9'o042);
        check(used == 4'b1101 && !hit && !full, "repetir 042 la borra (ranura 1 libre)");
        poner(9'o315); check(hit, "las demas siguen validas");

        // 6. La siguiente nueva va a la primera libre (ranura 1)
        toggle_code(9'o000);
        check(used == 4'b1111 && hit && full, "000 entra en la ranura 1, que era la primera libre");

        // 7. Borrar 315 y 233, luego agregar una: va a la ranura 0
        toggle_code(9'o315);
        toggle_code(9'o233);
        check(used == 4'b0110, "borrar 315 y 233 deja libres las ranuras 0 y 3");
        toggle_code(9'o444);
        check(used == 4'b0111 && hit, "444 entra en la ranura 0 (la menor libre)");
        poner(9'o233); check(!hit, "233 ya no es valida");

        // 8. Sin pulso no cambia nada
        poner(9'o555);
        repeat (5) @(negedge clk);
        check(used == 4'b0111 && !hit, "sin toggle no se escribe nada");

        // 9. Reset borra todas
        #3 rst = 0;
        #1;
        poner(9'o444);
        check(used == 4'b0000 && !hit, "reset borra todas las contrasenias");

        if (fallos == 0) $display("TODAS LAS PRUEBAS PASARON");
        else             $display("HUBO %0d FALLO(S)", fallos);
        $finish;
    end

endmodule
