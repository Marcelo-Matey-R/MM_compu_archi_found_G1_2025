import alu_types_pkg::*;

module pwm #(
    parameter N = 3
) (
    input logic clk,
    input logic rst,
    input logic step,
    input logic [N-1:0] src1,
    input logic [N-1:0] src2,
    input alu_op_e op_code,
    
    output logic pwm_out,
    output logic [N-1:0] vel
);
    logic [N-1:0] cnt;
    logic [N-1:0] cnt_next;
    logic [N-1:0] neg_vel;
    logic neg_pwm;

    alu_nbit #(.N(N)) U_ALU(
        .a(src1),
        .b(src2),
        .alu_control(op_code),
        .result(vel),
        .flags()
    );
    not_nbit #(.N(N)) U_NEG_VEL(
        .src(vel),
        .neg_src(neg_vel)
    );


    ripple_adder #(.N(N)) U_CALC_CNT(
        .a(cnt),
        .b({{(N-1){1'b0}}, 1'b1}),
        .c_in(1'b0),
        .res(cnt_next),
        .c_out()
    );

    always_ff @( posedge clk, negedge rst ) begin
        if(!rst) begin
            cnt <= '0;
        end else if(step) begin
            cnt <= cnt_next;
        end
    end

    ripple_adder #(.N(N)) U_CMP(
        .a(cnt),
        .b(neg_vel),
        .c_in(1'b1),
        .res(),
        .c_out(neg_pwm)
    );

    not U_NOT(pwm_out, neg_pwm);

endmodule