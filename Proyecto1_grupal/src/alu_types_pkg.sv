package alu_types_pkg;
typedef enum logic [2 : 0] {
    ADD_OP = 3'b000,
    SUB_OP = 3'b001,
    MUL_OP = 3'b010,
    ROL_OP = 3'b011,
    ROR_OP = 3'b100
} alu_op_e;

typedef struct packed {
    logic zero;
    logic overflow;
    logic negative;
    logic carry;
} alu_flags_t;


endpackage