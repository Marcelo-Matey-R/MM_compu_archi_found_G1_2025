module tb_shift_left_rotator_n #(
    parameter N = 8
)(
    output int   errors = 0,
    output logic done   = 0
);
    localparam S = $clog2(N);

    logic [N-1:0] a, y, exp;
    logic [S-1:0] sh;
    int sh_reference;

    shift_left_rotator #(.N(N)) dut (.a(a), .sh(sh), .y(y));

    initial begin
        for (int v = 0; v < 2**N; v++) begin
            a = v;
            for (int i = 0; i < 2**S; i++) begin
                sh = i;
                sh_reference = i % N; #10;
                exp = (a << sh_reference) | (a >> (N-sh_reference));
                if (y !== exp) begin
                    $error("N=%0d a=%b sh=%0d: esperado %b, obtenido %b", N, a, i, exp, y);
                    errors++;
                end
            end
        end
        done = 1;
    end
endmodule

module tb_shift_left_rotator;
    localparam int NMIN = 2;
    localparam int NMAX = 10;

    int errors [NMIN:NMAX];
    logic [NMAX:NMIN] done;

    genvar g;
    generate
        for (g = NMIN; g <= NMAX; g++) begin : gen_n
            tb_shift_left_rotator_n #(.N(g)) t (
                .errors(errors[g]),
                .done  (done[g])
            );
        end
    endgenerate

    initial begin
        int total = 0;
        wait (&done);
        for (int n = NMIN; n <= NMAX; n++) begin
            if (errors[n] != 0)
                $display("N=%0d: %0d errores", n, errors[n]);
            total += errors[n];
        end
        if (total == 0) $display("TEST PASSED (N=%0d..%0d)", NMIN, NMAX);
        else            $display("TEST FAILED: %0d errores", total);
        $finish;
    end
endmodule