module ripple_adder #(
    parameter int N = 8
) (
    input logic [N-1:0] a,
    input logic [N-1:0] b,
    output logic [N-1:0] res,
    output logic c_out
);

    // CORRECCIÓN 1: El vector de acarreos necesita N+1 bits (de 0 a N)
    logic [N:0] carry;

    // Acarreo inicial en cero para el bit menos significativo
    assign carry[0] = 1'b0;

    genvar i;
    generate
        for(i = 0; i < N; i++) begin : gen_adder
            full_adder u_adder(
                .a(a[i]),
                .b(b[i]),
                .c_in(carry[i]),       // Entra el acarreo anterior
                .s(res[i]),
                .c_out(carry[i+1])     // Sale el acarreo hacia el siguiente bit
            );
        end
    endgenerate

    // CORRECCIÓN 2: El c_out final es el último bit del vector de acarreos (carry[N])
    assign c_out = carry[N];
    
endmodule


