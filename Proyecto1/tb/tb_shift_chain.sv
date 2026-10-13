module tb_shift_chain;

    logic       clk;
    logic       rst;
    logic       step;
    logic       sh_ld;
    logic [2:0] d_in;
    logic       qh;
    logic [8:0] q;

    sr_165 #(.N(3)) U_165 (
        .clk(clk), .rst(rst), .sh(sh_ld), .step(step),
        .d_in(d_in), .qh(qh)
    );

    dsr_595 #(.N(9)) U_595 (
        .clk(clk), .rst(rst), .step(step), .ser(qh), .q(q)
    );

    logic [2:0] words [3];
    logic [8:0] esperado;
    logic       exp_qh;

    always #10 clk = ~clk;                 // 50 MHz

    initial begin
        clk = 0;
        step = 0; sh_ld = 1; d_in = 0; rst = 0;

        // Reset de 3 ciclos
        for (int i = 0; i < 3; i++) @(negedge clk);
        rst = 1;
        @(negedge clk);

        words[0] = 3'b101;
        words[1] = 3'b011;
        words[2] = 3'b110;
        esperado = {words[0], words[1], words[2]};

        for (int k = 0; k < 3; k++) begin

            // Cargar (sh_ld activo en bajo), 2 ciclos
            d_in  = words[k];
            sh_ld = 0;
            for (int i = 0; i < 2; i++) @(negedge clk);
            sh_ld = 1;                          // pasa a modo desplazar
            @(negedge clk);

            if (qh !== words[k][2])
                $error("Carga %0d: qh=%b, esperaba %b", k, qh, words[k][2]);

            // 3 pulsos de step de un ciclo
            for (int j = 0; j < 3; j++) begin
                step = 1; @(negedge clk);
                step = 0; @(negedge clk);

                // tras 1 step sale w[1], tras 2 sale w[0], tras 3 sale 0
                if (j == 0)      exp_qh = words[k][1];
                else if (j == 1) exp_qh = words[k][0];
                else             exp_qh = 1'b0;

                if (qh !== exp_qh)
                    $error("Palabra %0d, paso %0d: qh=%b, esperaba %b",
                           k, j+1, qh, exp_qh);
            end
        end

        // Pulso 10: q alcanza al shift_reg
        step = 1; @(negedge clk);
        step = 0; @(negedge clk);

        if (q === esperado) $display("PASS: q = %b", q);
        else                $error("FAIL: q = %b, esperado = %b", q, esperado);

        // q no debe cambiar si no hay step (20 ciclos)
        for (int i = 0; i < 20; i++) @(negedge clk);
        if (q !== esperado) $error("q cambio sin step: %b", q);

        $stop;
    end

endmodule