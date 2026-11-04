// decodificador de 7 segmentos entre registros.
//   BEHAV = 0 -> hex7seg (estructural, el del proyecto)
//   BEHAV = 1 -> hex7seg_decoder (behavioral, con case)

module top_exp_hex #(
    parameter int BEHAV = 0
) (
    input  logic       clk,
    input  logic [3:0] x_in,
    output logic [6:0] seg_out
);

    logic [3:0] x_r;
    logic [6:0] seg;

    always_ff @(posedge clk) begin
        x_r     <= x_in;
        seg_out <= seg;
    end

    generate
        if (BEHAV == 0) begin : estructural
            hex7seg U_DUT (.x(x_r), .seg(seg));
        end else begin : behavioral
            hex7seg_decoder U_DUT (.nibble(x_r), .segments(seg));
        end
    endgenerate

endmodule
