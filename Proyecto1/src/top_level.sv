module top_level (
    input logic CLK_50,
    input  logic [4:0] SW,
    input  logic [2:0] KEY,       //activo bajo.
    output logic [3:0] LEDR,
    output logic [6:0] HEX0
);


    logic rst;
    logic pulse_step;
    logic sync_sh_ld;

    reset_bridge U_RST_BTN (
        .clk(CLK_50),
        .async_rst_in(~KEY[0]),
        .sync_rst_out(rst)
    );

    sync_edge_detector U_STEP_BTN (
        .clk(CLK_50),
        .rst(rst),
        .async_in(~KEY[1]),
        .sync_out(),
        .pulse_out(pulse_step)
    );

    sync_edge_detector U_SH_LD_BTN (
        .clk(CLK_50),
        .rst(rst),
        .async_in(KEY[2]),
        .sync_out(sync_sh_ld),
        .pulse_out()
    );

    logic serial_out;
    logic [8:0] pass;
    logic open, close, valid;
    logic [6:0] seg;
    logic [2:0] bits;

    encoder_5_3 U_ENCODER_IN(SW, bits);

    sr_165 #(.N(3)) U_165 (
        .clk(CLK_50),
        .rst(rst),
        .sh(sync_sh_ld),
        .step(pulse_step),
        .d_in(bits),
        .qh(serial_out)
    );

    dsr_595 #(.N(9)) U_595 (
        .clk(CLK_50),
        .rst(rst),
        .step(pulse_step),
        .ser(serial_out),
        .q(pass)
    );

    password U_PASSWORD (
        .d_in(pass),
        .open(open),
        .close(close),
        .valid(valid)
    );

    logic [3:0] pulse_cnt;       // satura en 10
    logic [1:0] phase;           // n mod 3
    logic       aligned;

    always_ff @(posedge CLK_50, negedge rst) begin
        if (!rst) begin
            pulse_cnt <= 4'd0;
            phase     <= 2'd0;
        end else if (sync_sh_ld) begin
            if (pulse_cnt != 4'd10) pulse_cnt <= pulse_cnt + 4'd1;
            phase <= (phase == 2'd2) ? 2'd0 : phase + 2'd1;
        end
    end

    assign aligned = (pulse_cnt == 4'd10) && (phase == 2'd1);

    logic open_show, close_show;
    assign open_show  = open  & aligned;
    assign close_show = close & aligned;

    hex_decoder U_HEX (
        .open (open_show),
        .close(close_show),
        .valid(valid),
        .seg(seg)
    );

    assign HEX0 = seg;                 // activo en bajo
    assign LEDR = {serial_out, bits};

endmodule
