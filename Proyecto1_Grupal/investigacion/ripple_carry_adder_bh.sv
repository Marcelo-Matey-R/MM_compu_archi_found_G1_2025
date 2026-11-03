module ripple_carry_adder_bh #(parameter N = 4) (
    input  logic [N-1:0] a,
    input  logic [N-1:0] b,
    input  logic         cin,
    output logic [N-1:0] sum,
    output logic         cout
);
    // Operación aritmética conductual directa (inferencia de sumador)
    logic [N:0] temp_sum;

    always_comb begin
        temp_sum = {1'b0, a} + {1'b0, b} + cin;
        sum      = temp_sum[N-1:0];
        cout     = temp_sum[N];
    end

endmodule
