module tb_select_storage;
    logic       clk  = 0;
    logic       rst;
    logic       step = 0;
    logic       ser  = 0;
    logic [1:0] s    = 2'b00;
    logic [8:0] src1, src2, src3;

    int         errors = 0;
    logic [8:0] m1, m2, m3;    // valores esperados de los 3 registros

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

    always #5 clk = ~clk;      // periodo de 10 ns

    // Un pulso de step de exactamente un ciclo de clk, con un hueco después
    task automatic pulse(input logic bit_in);
        @(posedge clk); #1;
        ser = bit_in;               // ser primero
        @(posedge clk); #1;
        step = 1;                   // step un ciclo después
        @(posedge clk); #1;
        step = 0;
        repeat (2) @(posedge clk);
    endtask

    task automatic check(input string name, input logic [8:0] e1, e2, e3);
        if (src1 !== e1 || src2 !== e2 || src3 !== e3) begin
            $error("%s: esperado %b %b %b, obtenido %b %b %b (q=%b)", name, e1, e2, e3, src1, src2, src3, dut.q);
            errors++;
        end
    endtask

    // Envía 9 bits (MSB primero) con s = sel y verifica el resultado
    task automatic send_word(input logic [8:0] word, input logic [1:0] sel);
        s = sel;
        for (int i = 8; i >= 0; i--)
            pulse(word[i]);                       // 9 bits de la palabra (MSB primero)
        repeat (3) @(posedge clk); #1;
        check("tras 9 pulsos, aun sin guardar", m1, m2, m3);

        pulse(1'b1);                              // 10.o pulso: bit de relleno
        repeat (3) @(posedge clk); #1;

        case (sel)
            2'b00: m1 = word;
            2'b01: m2 = word;
            2'b10: m3 = word;
            default: ;
        endcase
        check($sformatf("tras 10 pulsos con s=%b", sel), m1, m2, m3);
    endtask

    initial begin
        m1 = '0; m2 = '0; m3 = '0;

        // Reset (activo en bajo)
        rst = 0;
        repeat (3) @(posedge clk);
        #1 rst = 1;
        repeat (2) @(posedge clk);
        check("despues del reset", 9'b0, 9'b0, 9'b0);

        send_word(9'b001_010_100, 2'b00);   // guarda en src1
        send_word(9'b011_100_010, 2'b01);   // guarda en src2
        send_word(9'b100_001_011, 2'b10);   // guarda en src3
        send_word(9'b100_100_000, 2'b11);   // s=11: no debe escribir en ninguno
        send_word(9'b010_011_001, 2'b00);   // sobrescribe src1

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errores", errors);
        $finish;
    end
endmodule