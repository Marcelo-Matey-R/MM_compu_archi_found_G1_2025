module top_exp_adder #(
    parameter int N     = 8,
    parameter int BEHAV = 0
) (
    input  logic         clk,
    input  logic [N-1:0] a_in,
    input  logic [N-1:0] b_in,
    input  logic         cin_in,
    output logic [N-1:0] s_out,
    output logic         cout_out
);

    logic [N-1:0] a_r, b_r, s;
    logic cin_r, cout;

    always_ff @(posedge clk) begin
        a_r      <= a_in;
        b_r      <= b_in;
        cin_r    <= cin_in;
        s_out    <= s;
        cout_out <= cout;
    end

    generate
        if (BEHAV == 0) begin : estructural
            ripple_adder #(.N(N)) U_DUT (
                .a(a_r), .b(b_r), .c_in(cin_r), .res(s), .c_out(cout)
            );
        end else begin : behavioral
            ripple_carry_adder_bh #(.N(N)) U_DUT (
                .a(a_r), .b(b_r), .cin(cin_r), .sum(s), .cout(cout)
            );
        end
    endgenerate

endmodule
