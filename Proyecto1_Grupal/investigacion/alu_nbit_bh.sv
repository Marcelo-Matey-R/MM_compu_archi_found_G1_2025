import alu_types_pkg::*;


module alu_nbit_bh #(
    parameter int N = 3
)(
    input  logic [N-1:0] a,
    input  logic [N-1:0] b,
    input  alu_op_e      alu_control,
    output logic [N-1:0] result,
    output alu_flags_t   flags
);

    localparam S = $clog2(N);

    logic sub;
    logic [N-1:0] b_operand;
    logic [N:0]   arit;
    logic [2*N-1:0] mul;
    logic [S-1:0] k;
    logic [N-1:0] rol, ror;

    assign sub       = (alu_control == SUB_OP);
    assign b_operand = sub ? ~b : b;
    assign arit      = {1'b0, a} + {1'b0, b_operand} + sub;
    assign mul       = a * b;

    assign k   = b[S-1:0];
    assign rol = (a << k) | (a >> (N - k));
    assign ror = (a >> k) | (a << (N - k));

    always_comb begin
        case (alu_control)
            ADD_OP:  result = arit[N-1:0];
            SUB_OP:  result = arit[N-1:0];
            MUL_OP:  result = mul[N-1:0];
            ROL_OP:  result = rol;
            ROR_OP:  result = ror;
            // 110 no es una operacion, pero la estructural decodifica por bits
            // (bit 2 = 1 y bit 0 = 0 -> ROR), asi que aqui se copia para que sean identicas
            alu_op_e'(3'b110): result = ror;
            default: result = '0;
        endcase
    end

    assign flags.carry    = arit[N];
    assign flags.negative = result[N-1];
    assign flags.zero     = (result == '0);
    assign flags.overflow = (a[N-1] == b_operand[N-1]) && (arit[N-1] != a[N-1]);

endmodule
