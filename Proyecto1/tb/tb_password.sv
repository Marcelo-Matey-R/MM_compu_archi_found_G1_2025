module tb_password;

    logic [8:0] d_in;
    logic       open, close, valid;

    password U_DUT (
        .d_in(d_in),
        .open(open),
        .close(close),
        .valid(valid)
    );

    // Cada dígito base 5 va en 3 bits
    localparam logic [8:0] CLOSE_PASS = 9'b100_011_001;   // 431
    localparam logic [8:0] OPEN_PASS  = 9'b100_011_010;   // 432

    logic exp_open, exp_close, exp_valid;
    int   casos = 0;

    initial begin

        // Casos de la especificación
        d_in = CLOSE_PASS; #10;
        if (!(close === 1'b1 && open === 1'b0 && valid === 1'b1))
            $error("431: close=%b open=%b valid=%b", close, open, valid);

        d_in = OPEN_PASS; #10;
        if (!(open === 1'b1 && close === 1'b0 && valid === 1'b1))
            $error("432: close=%b open=%b valid=%b", close, open, valid);

        // Barrido de todas las combinaciones
        for (int n = 0; n < 125; n++) begin
            d_in = 9'(n);

            #10;
            casos++;

            exp_close = (d_in == CLOSE_PASS);
            exp_open  = (d_in == OPEN_PASS);
            exp_valid = exp_close ^ exp_open;

            if (close !== exp_close || open !== exp_open || valid !== exp_valid)
                $error("d_in = %0d%0d%0d (%b): close=%b open=%b valid=%b, esperaba %b %b %b",
                       d_in[8:6], d_in[5:3], d_in[2:0], d_in,
                       close, open, valid,
                       exp_close, exp_open, exp_valid);
        end

        $display("Termino el test: %0d casos revisados", casos);
        $stop;
    end

endmodule