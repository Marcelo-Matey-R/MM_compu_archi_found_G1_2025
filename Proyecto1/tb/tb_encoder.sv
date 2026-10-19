module tb_encoder();

    logic [4:0] f;
    logic [2:0] bits;

    encoder_5_3 U_TB(
        .f(f),
        .b(bits)
    );

    logic [2:0] bits_esperados [5:0];
    logic [4:0] inputs  [5:0];



    initial begin
        inputs[0] = 5'b00001; bits_esperados[0] = 3'b000;
        inputs[1] = 5'b00011; bits_esperados[1] = 3'b001;
        inputs[2] = 5'b00111; bits_esperados[2] = 3'b010;
        inputs[3] = 5'b01111; bits_esperados[3] = 3'b011;
        inputs[4] = 5'b11111; bits_esperados[4] = 3'b100;

        for (int n = 0; n < 5; n++) begin
            f = inputs[n];
            #10;
            if (bits !== bits_esperados[n])
                $error("f = %b: bits = %b, esperaba %b", f, bits, bits_esperados[n]);
        end

        $display("Termino el test");
        $stop;

    end

endmodule