`timescale 1ns/1ps

module tb_password_ver;

    logic [8:0] close_pass, open_pass, d_in;
    logic       open, close, invalid;

    int errors = 0;
    int tests  = 0;

    password_ver dut (
        .close_pass(close_pass),
        .open_pass (open_pass),
        .d_in      (d_in),
        .open      (open),
        .close     (close),
        .invalid   (invalid)
    );

    // Empaqueta 3 dígitos (base 5) en 9 bits: {d2, d1, d0}
    function automatic logic [8:0] pack(int d2, int d1, int d0);
        return {3'(d2), 3'(d1), 3'(d0)};
    endfunction

    // Aplica entradas, espera y compara contra el modelo de referencia
    task automatic check(input logic [8:0] op, cp, din);
        logic exp_open, exp_close, exp_invalid;

        open_pass  = op;
        close_pass = cp;
        d_in       = din;
        #1;

        exp_open    = (din == op);
        exp_close   = (din == cp);
        exp_invalid = ~(exp_open ^ exp_close);   // xnor, igual que el DUT

        tests++;
        if (open !== exp_open || close !== exp_close || invalid !== exp_invalid) begin
            errors++;
            $error("FALLO: open_pass=%0d%0d%0d close_pass=%0d%0d%0d d_in=%0d%0d%0d | open=%b(%b) close=%b(%b) invalid=%b(%b)",
                   op[8:6], op[5:3], op[2:0],
                   cp[8:6], cp[5:3], cp[2:0],
                   din[8:6], din[5:3], din[2:0],
                   open, exp_open, close, exp_close, invalid, exp_invalid);
        end
    endtask

    logic [8:0] op_set [4];
    logic [8:0] cp_set [4];

    initial begin
        $display("=== password_ver_tb: inicio ===");

        // 1. Casos dirigidos
        check(pack(1,2,3), pack(4,3,2), pack(1,2,3));  // coincide open
        check(pack(1,2,3), pack(4,3,2), pack(4,3,2));  // coincide close
        check(pack(1,2,3), pack(4,3,2), pack(0,0,0));  // ninguna coincide
        check(pack(1,2,3), pack(4,3,2), pack(1,2,4));  // difiere en 1 digito (LSD)
        check(pack(1,2,3), pack(4,3,2), pack(0,2,3));  // difiere en 1 digito (MSD)
        check(pack(1,2,3), pack(1,2,3), pack(1,2,3));  // claves iguales, coincide ambas
        check(pack(1,2,3), pack(1,2,3), pack(3,2,1));  // claves iguales, no coincide
        check(pack(0,0,0), pack(4,4,4), pack(0,0,0));  // extremos
        check(pack(0,0,0), pack(4,4,4), pack(4,4,4));
        check(pack(1,2,3), pack(4,3,2), pack(3,2,1));  // digitos permutados
        check(pack(1,2,3), pack(4,3,2), pack(7,7,7));  // digitos fuera de rango (5-7)

        // 2. Barrido exhaustivo de d_in (512 valores) para varios pares de claves
        op_set[0] = pack(1,2,3); cp_set[0] = pack(4,3,2);
        op_set[1] = pack(0,0,0); cp_set[1] = pack(4,4,4);
        op_set[2] = pack(2,2,2); cp_set[2] = pack(2,2,2);   // claves iguales
        op_set[3] = pack(0,1,2); cp_set[3] = pack(0,1,3);   // claves casi iguales

        foreach (op_set[k])
            for (int v = 0; v < 512; v++)
                check(op_set[k], cp_set[k], v[8:0]);

        // 3. Aleatorio (incluye digitos invalidos)
        repeat (2000)
            check($urandom_range(511), $urandom_range(511), $urandom_range(511));

        $display("=== Fin: %0d pruebas, %0d errores ===", tests, errors);
        if (errors == 0) $display("TODAS LAS PRUEBAS PASARON");
        else             $display("HAY FALLOS");
        $finish;
    end

endmodule