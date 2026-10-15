package alu_types_pkg;
typedef enum logic [2 : 0] {
    ADD_OP = 3'b000,
    SUB_OP = 3'b001,
    AND_OP = 3'b010,
    OR_OP = 3'b011,
    XOR_OP = 3'b100,
    SLL_OP = 3'b101,
    SRL_OP = 3'b110,
    SRA_OP = 3'b111
} alu_op_e;

typedef struct packed {
    logic zero;
    logic overflow;
    logic negative;
    logic carry;
} alu_flags_t;


endpackage