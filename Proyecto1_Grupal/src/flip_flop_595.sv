module flip_flop_595 (
    input logic clk,
    input logic rst,
    input logic en,
    input logic d_in,
    output logic q
);
    logic d_write;

    mux_2_1 U_MUX_WRITE(
        .a(q),
        .b(d_in),
        .sel(en),
        .y(d_write)
    );

    always_ff @( posedge clk, negedge rst ) begin
        if(!rst) begin
            q <= 0;
        end else begin
            q <= d_write;
        end
    end
endmodule