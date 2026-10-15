module shift_right_rotator #(
    parameter N = 8,
    localparam S = $clog2(N)
) (
    input  logic [N-1:0] a,
    input  logic [S-1:0] sh,
    output logic [N-1:0] y
);
    logic [S-1:0] neg_sh;
    logic [S-1:0] amt;
    logic [N-1:0] left, right, new_a;
    assign new_a = {a[N-2:0], 1'b0};

    not_nbit #(.N(S)) U_NOT(
        .src(sh),
        .neg_src(neg_sh)
    ); 

    ripple_adder #(.N(S)) calc_amt(
        .a(S'(N-1)),
        .b(neg_sh),
        .c_in(1'b1),
        .res(amt),
        .c_out()
    );
    
    shift_left #(.N(N)) sl(
        .a(new_a),
        .sh(amt),
        .y(left)
    );

    shift_right #(.N(N)) sr(
        .a(a),
        .sh(sh),
        .y(right)
    );

    or_nbit #(.N(N)) U_OR(
        .src1(right),
        .src2(left),
        .y(y)
    );

endmodule