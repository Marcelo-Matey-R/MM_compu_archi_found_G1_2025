module shift_left_rotator #(
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
    assign new_a = {1'b0, a[N-1:1]};

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
        .a(a),
        .sh(sh),
        .y(left)
    );

    shift_right #(.N(N)) sr(
        .a(new_a),
        .sh(amt),
        .y(right)
    );

    or_nbit #(.N(N)) U_OR(
        .src1(right),
        .src2(left),
        .y(y)
    );

endmodule