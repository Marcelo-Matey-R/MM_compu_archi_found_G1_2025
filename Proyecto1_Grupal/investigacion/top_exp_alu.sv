import alu_types_pkg::*;

// ALU de N bits entre registros.
//   BEHAV = 0 -> alu_nbit (estructural, la del proyecto)
//   BEHAV = 1 -> alu_nbit_bh (behavioral)

module top_exp_alu #(
    parameter int N     = 8,
    parameter int BEHAV = 0
) (
    input  logic         clk,
    input  logic [N-1:0] a_in,
    input  logic [N-1:0] b_in,
    input  logic [2:0]   op_in,
    output logic [N-1:0] r_out,
    output logic [3:0]   flags_out
);

    logic [N-1:0] a_r, b_r, r;
    logic [2:0]   op_r;
    alu_flags_t   flags;

    always_ff @(posedge clk) begin
        a_r       <= a_in;
        b_r       <= b_in;
        op_r      <= op_in;
        r_out     <= r;
        flags_out <= flags;
    end

    generate
        if (BEHAV == 0) begin : estructural
            alu_nbit #(.N(N)) U_DUT (
                .a(a_r), .b(b_r), .alu_control(alu_op_e'(op_r)), .result(r), .flags(flags)
            );
        end else begin : behavioral
            alu_nbit_bh #(.N(N)) U_DUT (
                .a(a_r), .b(b_r), .alu_control(alu_op_e'(op_r)), .result(r), .flags(flags)
            );
        end
    endgenerate

endmodule
