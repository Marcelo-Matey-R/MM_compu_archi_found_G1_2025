module tb_product;
    localparam int N = 4;

    logic [N-1:0]   a, b;
    logic [2*N-1:0] y, exp;
    int errors = 0;

    product #(.N(N)) dut (.src1(a), .src2(b), .y(y));

    initial begin
        for (int i = 0; i < 2**N; i++) begin
            for (int j = 0; j < 2**N; j++) begin
                a = i; b = j; #10;
                exp = a * b;
                if (y !== exp) begin
                    $error("%0d * %0d: esperado %0d, obtenido %0d", a, b, exp, y);
                    errors++;
                end
            end
        end

        if (errors == 0) $display("TEST PASSED (N=%0d)", N);
        else             $display("TEST FAILED: %0d errores", errors);
        $finish;
    end
endmodule