module tb_encoder_inputs();

    logic [5:0] f;
    logic [2:0] bits;

    encoder_inputs U_TB(
        .f(f),
        .b(bits)
    );

    logic [5:0] inputs [0:5];
    logic [2:0] bits_esperados [0:5];
    logic [2:0] esperado;

    initial begin
        inputs[0] = 6'b000_001; bits_esperados[0] = 3'b000;
        inputs[1] = 6'b000_011; bits_esperados[1] = 3'b001;
        inputs[2] = 6'b000_111; bits_esperados[2] = 3'b010;
        inputs[3] = 6'b001_111; bits_esperados[3] = 3'b011;
        inputs[4] = 6'b011_111; bits_esperados[4] = 3'b100;
        inputs[5] = 6'b111_111; bits_esperados[5] = 3'b101;

        for (int n = 0; n < 2**6; n++) begin
            f = n;

            // Por defecto (000000 o entrada inválida) se espera 000
            esperado = 3'b000;
            for (int k = 0; k < 6; k++) begin
                if (f === inputs[k])
                    esperado = bits_esperados[k];
            end

            #10;
            if (bits !== esperado)
                $error("f = %b: bits = %b, esperaba %b", f, bits, esperado);
        end

        $display("Termino el test");
        $stop;
    end

endmodule