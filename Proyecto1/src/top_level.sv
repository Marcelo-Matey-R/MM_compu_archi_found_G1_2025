module top_level (
    input logic CLOCK_50,
    input  logic [4:0] SW,
    input  logic [2:0] KEY,       //activo bajo.
    output logic [3:0] LEDR,
    output logic [6:0] HEX0
);


    logic rst;
    logic rst_n;
    logic pulse_step;
    logic sync_sh_ld;
    assign rst_n = ~rst;

    reset_bridge U_RST_BTN (
        .clk(CLOCK_50),
        .async_rst_in(~KEY[0]),
        .sync_rst_out(rst)
    );

    sync_edge_detector U_STEP_BTN (
        .clk(CLOCK_50),
        .rst(rst),
        .async_in(~KEY[1]),
        .sync_out(),
        .pulse_out(pulse_step)
    );

    sync_edge_detector U_SH_LD_BTN (
        .clk(CLOCK_50),
        .rst(rst),
        .async_in(KEY[2]),
        .sync_out(sync_sh_ld),
        .pulse_out()
    );

    logic serial_out;
    logic [8:0] pass, keep_pass_open, keep_pass_close;
    logic open, close, valid;
    logic [6:0] seg;
    logic [2:0] bits;

    encoder_5_3 U_ENCODER_IN(.f(SW), .b(bits));

    sr_165 #(.N(3)) U_165 (
        .clk(CLOCK_50),
        .rst(rst_n),
        .sh(sync_sh_ld),
        .step(pulse_step),
        .d_in(bits),
        .qh(serial_out)
    );

    dsr_595 #(.N(9)) U_595 (
        .clk(CLOCK_50),
        .rst(rst_n),
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

    logic [3:0] pulse_cnt;       
    logic       aligned;

    always_ff @(posedge CLOCK_50, negedge rst_n) begin
        if (!rst_n) begin
            pulse_cnt <= 4'd0;
            
        end else if (pulse_step && pulse_cnt != 4'd10) begin
        pulse_cnt <= pulse_cnt + 4'd1; end
    end

    assign aligned = (pulse_cnt == 4'd10);

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
