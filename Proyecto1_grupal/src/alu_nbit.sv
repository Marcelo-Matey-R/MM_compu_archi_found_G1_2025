import alu_types_pkg::*;

module alu_nbit #(
    parameter int N = 3
)(
    input  logic [N-1:0] a,
    input  logic [N-1:0] b,
    input  alu_op_e      alu_control,
    output logic [N-1:0] result,
    output alu_flags_t   flags
);

    localparam S = $clog2(N);
    logic c_out;
    logic [N-1:0] b_operand;
    logic [N-1:0] b_neg;
    logic sel;
    logic [N-1:0] res_arit;
    logic [N-1:0] res_mul;
    logic [2N-1:0] full_mul;
    logic [N-1:0] res_rol;
    logic [N-1:0] res_ror;

    // Wires para la decodificación estructural de 'sel' (SUB_OP = 3'b001)
    logic not_c2, not_c1, and_w1;

    // Wires internos de cada flag (las compuertas solo pueden manejar wires,
    // no campos de la salida 'flags' directamente)
    logic flag_carry, flag_negative, flag_zero, flag_overflow;

    // 1. Decodificación estructural de 'sel'

    not U_NOT_C2 (not_c2, alu_control[2]);
    not U_NOT_C1 (not_c1, alu_control[1]);
    and U_AND_S1 (and_w1, not_c2, not_c1);
    and U_AND_S2 (sel,    and_w1, alu_control[0]);


    // 2. Inversión bit a bit estructural de b

    not_nbit #(.N(N)) U_NOT_B(
        .src(b),
        .neg_src(b_neg)
    );


    // 3. Instanciación del MUX parametrizado estructural

    mux_2_1_param #(.N(N)) MUX (
        .a(b),
        .b(b_neg),
        .sel(sel),
        .y(b_operand)
    );


    // 4. Sumador / Restador Estructural (Ripple Carry Adder)

    ripple_adder #(.N(N)) adder (
        .a(a),
        .b(b_operand),
        .res(res_arit),
        .c_in(sel),
        .c_out(c_out)
    );

    // 5. Multiplicacion
    product #(.N(N)) products (
    .src1(a),
    .src2(b),
    .y(full_mul)
    );

    assign res_mul = full_mul[N-1:0];

    // 6. Rotadores
    shift_left_rotator #(.N(N), .S(S)) leftRotator (
        .a(a),
        .sh(b[S-1:0]),
        .y(res_rol)
    );

    shift_right_rotator #(.N(N), .S(S)) rightRotator (
        .a(a),
        .sh(b[S-1:0]),
        .y(res_ror)
    );

    // 7. Flags

    // Carry
    assign flag_carry = c_out;

    // Negative
    assign flag_negative = result[N-1];

    // Zero: un 'nor' de compuerta solo mira 1 bit por entrada, así que
    // se hace una cadena de 'or' sobre todos los bits y se niega al final
    logic [N-1:0] or_chain;

    assign or_chain[0] = result[0];

    or_nbit #(.N(N-1)) U_OR_Z(
        .src1(or_chain[N-2:0]),
        .src2(result[N-1:1]),
        .y(or_chain[N-1:1])    
    );

    not U_NOT_ZERO (flag_zero, or_chain[N-1]);   // zero = 1 si ningún bit es 1

    // Overflow
    logic sign_a, sign_b_op, sign_res;
    logic xor_sign_ab, not_xor_sign, xor_sign_ar;

    assign sign_a    = a[N-1];
    assign sign_b_op = b_operand[N-1];
    assign sign_res  = res_arit[N-1];

    xor  U_XOR_AB  (xor_sign_ab,  sign_a, sign_b_op);
    not  U_NOT_XAB (not_xor_sign, xor_sign_ab);         // (sign_a == sign_b_op)
    xor  U_XOR_AR  (xor_sign_ar,  sign_res, sign_a);    // (sign_res != sign_a)
    and  U_AND_OVF (flag_overflow, not_xor_sign, xor_sign_ar);


    // 8. Se arma 'flags' en una sola asignación (por nombre de campo,
    // así no depende del orden de los campos en el struct)
    assign flags = '{carry:    flag_carry,
                     negative: flag_negative,
                     zero:     flag_zero,
                     overflow: flag_overflow};

endmodule
