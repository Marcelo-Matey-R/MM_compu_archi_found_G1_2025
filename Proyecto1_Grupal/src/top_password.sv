module top_password (
    input logic CLOCK_50,
    input logic [4:0] GPIO_INPUT,
    input logic [1:0] SW,
    input logic [2:0] KEY,       //activo bajo.
    output logic [3:0] LEDR,
    output logic [6:0] HEX0,
    output logic [2:0] GPIO_OUT
);


    logic rst;
    logic rst_n;
    logic pulse_step;
    logic sync_sh_ld;
    logic [4:0] sync_f;
    logic valid;
    assign rst_n = ~rst;

    reset_bridge U_RST_BTN (
        .clk(CLOCK_50),
        .async_rst_in(~KEY[0]),
        .sync_rst_out(rst)
    );

    sync_edge_detector U_F0 (
        .clk(CLOCK_50),
        .rst(rst),
        .async_in(GPIO_INPUT[0]),
        .sync_out(sync_f[0]),
        .pulse_out()
    );

    sync_edge_detector U_F1 (
        .clk(CLOCK_50),
        .rst(rst),
        .async_in(GPIO_INPUT[1]),
        .sync_out(sync_f[1]),
        .pulse_out()
    );
    
    sync_edge_detector U_F2 (
        .clk(CLOCK_50),
        .rst(rst),
        .async_in(GPIO_INPUT[2]),
        .sync_out(sync_f[2]),
        .pulse_out()
    );

    sync_edge_detector U_F3 (
        .clk(CLOCK_50),
        .rst(rst),
        .async_in(GPIO_INPUT[3]),
        .sync_out(sync_f[3]),
        .pulse_out()
    );

    sync_edge_detector U_F4 (
        .clk(CLOCK_50),
        .rst(rst),
        .async_in(GPIO_INPUT[4]),
        .sync_out(sync_f[4]),
        .pulse_out()
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
    logic [8:0] pass, storage_close, storage_open;
    logic open, close, invalid;
    logic [6:0] seg;
    logic [2:0] bits;

    encoder_inputs U_ENCODER_IN(.f(sync_f), .b(bits));

    sr_165 #(.N(3)) U_165 (
        .clk(CLOCK_50),
        .rst(rst_n),
        .sh(sync_sh_ld),
        .step(pulse_step),
        .d_in(bits),
        .qh(serial_out)
    );

    select_storage U_STORAGE_SELECTOR(
        .clk(CLOCK_50),
        .rst(rst_n),
        .step(pulse_step),
        .ser(serial_out),
        .s(SW[1:0]),
        .src1(storage_open),
        .src2(storage_close),
        .src3(pass)
    );

    password_ver U_PASSWORD (
        .close_pass(storage_close),
        .open_pass(storage_open),
        .d_in(pass),
        .open(open),
        .close(close),
        .invalid(invalid)
    );

       not U_NEG_INVALID(valid, invalid);

    // Modo verificacion: s = 10. En registro (00, 01) el resultado no cuenta.
    logic ns0, verify, reg_mode;
    logic open_v, close_v, invalid_v, valid_v;

    not U_NOT_S0  (ns0, SW[0]);
    and U_VERIFY  (verify, SW[1], ns0);
    not U_REG_MODE(reg_mode, verify);

    and U_OPEN_V   (open_v,    open,    verify);
    and U_CLOSE_V  (close_v,   close,   verify);
    and U_INVALID_V(invalid_v, invalid, verify);
    and U_VALID_V  (valid_v,   valid,   verify);

    hex_decoder U_HEX (
        .open (open_v),
        .close(close_v),
        .valid(valid_v),
        .seg(seg)
    );

    // Display activo en bajo: en modo registro todos los segmentos en 1 (apagado)
    or_nbit #(.N(7)) U_BLANK (
        .src1(seg),
        .src2({7{reg_mode}}),
        .y(HEX0)
    );

    assign LEDR = {serial_out, bits};
    assign GPIO_OUT = {open_v, close_v, invalid_v};

endmodule
