module main_fsm #(
    parameter T_BITS = 25
) (
    input logic clk,
    input logic rst,                // activo en bajo

    input logic ready,
    input logic hit,
    input logic full,
    input logic vel_ok,
    input logic btn_admin,
    input logic btn_test,
    input logic motor_open,
    input logic motor_close,

    output logic door_toggle,
    output logic mem_toggle,
    output logic vel_fija,
    output logic listening,
    output logic [2:0] evento,
    output logic [2:0] state        // para ver el estado en LEDs
);

    logic [2:0] current_state;
    logic [2:0] next_state;

    always_ff @(posedge clk, negedge rst) begin
        if (!rst) current_state <= 3'b000;
        else      current_state <= next_state;
    end

    assign state = current_state;

    // ---------------- Negados ----------------
    logic S0, S1, S2, nS0, nS1, nS2;
    logic mov, nmov, nready, nhit, nfull, nadmin, td, ntd;

    assign S0 = current_state[0];
    assign S1 = current_state[1];
    assign S2 = current_state[2];

    not U_NS0(nS0, S0);
    not U_NS1(nS1, S1);
    not U_NS2(nS2, S2);

    or  U_MOV(mov, motor_open, motor_close);
    not U_NMOV(nmov, mov);
    not U_NREADY(nready, ready);
    not U_NHIT(nhit, hit);
    not U_NFULL(nfull, full);
    not U_NADMIN(nadmin, btn_admin);
    not U_NTD(ntd, td);

    // ---------------- Decodificador de estado ----------------
    logic ESPERA, ADMIN, VALIDA, MOVIENDO, PRUEBA_A, PRUEBA_B, REGISTRADA, INVALIDA;

    and U_D0(ESPERA,     nS2, nS1, nS0);
    and U_D1(ADMIN,      nS2, nS1, S0);
    and U_D2(VALIDA,     nS2, S1,  nS0);
    and U_D3(MOVIENDO,   nS2, S1,  S0);
    and U_D4(PRUEBA_A,   S2,  nS1, nS0);
    and U_D5(PRUEBA_B,   S2,  nS1, S0);
    and U_D6(REGISTRADA, S2,  S1,  nS0);
    and U_D7(INVALIDA,   S2,  S1,  S0);

    // ---------------- Transiciones ----------------
    // ok = hit + vel_ok * !full
    logic ok, nok, agregar_ok;
    and U_AGREGAR_OK(agregar_ok, vel_ok, nfull);
    or  U_OK(ok, hit, agregar_ok);
    not U_NOK(nok, ok);

    // desde ESPERA
    logic e_valida, e_invalida, e_admin, e_prueba;
    and U_E_VALIDA  (e_valida,   ESPERA, ready, hit, nmov);
    and U_E_INVALIDA(e_invalida, ESPERA, ready, nhit, nmov);
    and U_E_ADMIN   (e_admin,    ESPERA, nready, btn_admin, nmov);
    and U_E_PRUEBA  (e_prueba,   ESPERA, nready, nadmin, btn_test, nmov);

    // desde ADMIN
    logic a_registrada, a_invalida, a_queda;
    and U_A_REG  (a_registrada, ADMIN, ready, ok);
    and U_A_INV  (a_invalida,   ADMIN, ready, nok);
    and U_A_QUEDA(a_queda,      ADMIN, nready, nadmin);

    // desde VALIDA
    logic v_mover, v_queda;
    and U_V_MOVER(v_mover, VALIDA, td);
    and U_V_QUEDA(v_queda, VALIDA, ntd);

    // desde MOVIENDO
    logic m_queda;
    and U_M_QUEDA(m_queda, MOVIENDO, mov);

    // desde PRUEBA_A y PRUEBA_B
    logic pa_sigue, pa_queda, pb_queda;
    and U_PA_SIGUE(pa_sigue, PRUEBA_A, nmov);
    and U_PA_QUEDA(pa_queda, PRUEBA_A, mov);
    and U_PB_QUEDA(pb_queda, PRUEBA_B, mov);

    // desde REGISTRADA e INVALIDA
    logic r_queda, i_queda;
    and U_R_QUEDA(r_queda, REGISTRADA, ntd);
    and U_I_QUEDA(i_queda, INVALIDA, ntd);

    // ---------------- Siguiente estado ----------------
    // bit 2 en 1: PRUEBA_A, PRUEBA_B, REGISTRADA, INVALIDA
    logic nextS2, nextS1, nextS0;

    or U_NEXT_S2(nextS2, e_invalida, e_prueba, a_registrada, a_invalida,
                         pa_sigue, pa_queda, pb_queda, r_queda, i_queda);

    // bit 1 en 1: VALIDA, MOVIENDO, REGISTRADA, INVALIDA
    or U_NEXT_S1(nextS1, e_valida, e_invalida, a_registrada, a_invalida,
                         v_mover, v_queda, m_queda, r_queda, i_queda);

    // bit 0 en 1: ADMIN, MOVIENDO, PRUEBA_B, INVALIDA
    or U_NEXT_S0(nextS0, e_invalida, e_admin, a_invalida, a_queda,
                         v_mover, m_queda, pa_sigue, pb_queda, i_queda);

    assign next_state = {nextS2, nextS1, nextS0};

    // ---------------- Salidas ----------------
    or  U_DOOR(door_toggle, v_mover, e_prueba, pa_sigue);
    assign mem_toggle = a_registrada;

    logic e_mov;
    and U_E_MOV(e_mov, ESPERA, mov);
    or  U_VEL_FIJA(vel_fija, PRUEBA_A, PRUEBA_B, e_mov);

    logic esp_o_admin;
    or  U_ESP_ADMIN(esp_o_admin, ESPERA, ADMIN);
    and U_LISTEN(listening, esp_o_admin, nmov);

    logic m_abre, m_cierra;
    and U_M_ABRE  (m_abre,   MOVIENDO, motor_open);
    and U_M_CIERRA(m_cierra, MOVIENDO, motor_close);

    or U_EV2(evento[2], INVALIDA, m_abre, m_cierra);
    or U_EV1(evento[1], REGISTRADA, VALIDA, m_cierra);
    or U_EV0(evento[0], PRUEBA_A, PRUEBA_B, VALIDA, m_abre);

    // ---------------- Temporizador de sonidos cortos ----------------
    logic t_run;
    logic [T_BITS - 1:0] t_cnt;
    logic [T_BITS - 1:0] t_incr;
    logic [T_BITS - 1:0] t_next;

    or U_T_RUN(t_run, VALIDA, REGISTRADA, INVALIDA);

    ripple_adder #(.N(T_BITS)) U_T_INC (
        .a(t_cnt),
        .b({{(T_BITS - 1){1'b0}}, 1'b1}),
        .c_in(1'b0),
        .res(t_incr),
        .c_out()
    );

    // si t_run = 1 cuenta, si no vuelve a 0
    mux_2_1_param #(.N(T_BITS)) U_T_MUX (
        .a({T_BITS{1'b0}}),
        .b(t_incr),
        .sel(t_run),
        .y(t_next)
    );

    always_ff @(posedge clk, negedge rst) begin
        if (!rst) t_cnt <= '0;
        else      t_cnt <= t_next;
    end

    assign td = t_cnt[T_BITS - 1];

endmodule
