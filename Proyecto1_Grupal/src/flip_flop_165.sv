module flip_flop_165 (
    input logic clk,
    input logic rst,
    input logic load,
    input logic en,
    input logic d_ser,
    input logic d_par,
    output logic q
);
    logic d_load, d_write;
    mux_2_1 U_MUX_LOAD(
        .a(d_par),
        .b(d_ser),
        .sel(load),
        .y(d_load)
    );

    mux_2_1 U_MUX_WRITE(
        .a(q),
        .b(d_load),
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