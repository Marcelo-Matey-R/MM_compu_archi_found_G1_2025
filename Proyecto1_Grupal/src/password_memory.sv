
module password_memory (
    input logic clk,
    input logic rst,                // activo en bajo
    input logic [8:0] code,         // {d1, d2, d3} de digit_capture
    input logic toggle,             // pulso de un ciclo: agregar o borrar 'code'

    output logic hit,               // code esta registrado
    output logic full,              // no hay ranuras libres
    output logic [3:0] used         // bits de valido (para ver en LEDs)
);

    logic [8:0] slot [4];           // contrasenias guardadas
    logic [3:0] v;                  // bit de valido de cada ranura
    logic [3:0] v_next;

    logic [3:0] match;              // code == slot[k]
    logic [3:0] hit_k;              // match y la ranura es valida
    logic [3:0] w;                  // primera ranura libre (solo un bit en 1)
    logic [3:0] we;                 // escribir code en la ranura k
    logic [3:0] borrar;             // borrar la ranura k

    logic nv0, nv1, nv2, nv3;

    not U_NV0(nv0, v[0]);
    not U_NV1(nv1, v[1]);
    not U_NV2(nv2, v[2]);
    not U_NV3(nv3, v[3]);

    assign w[0] = nv0;
    and U_W1(w[1], v[0], nv1);
    and U_W2(w[2], v[0], v[1], nv2);
    and U_W3(w[3], v[0], v[1], v[2], nv3);

    and U_FULL(full, v[0], v[1], v[2], v[3]);

   
    logic nhit, agregar;

    or  U_HIT(hit, hit_k[0], hit_k[1], hit_k[2], hit_k[3]);
    not U_NHIT(nhit, hit);
    and U_AGREGAR(agregar, toggle, nhit);

    
    genvar k;
    generate
        for (k = 0; k < 4; k++) begin : ranura
            logic [8:0] igual;      // bit a bit: code[i] == slot[k][i]
            logic [8:0] slot_next;
            logic nborrar, v_set;

            // Comparador (igual que en password_ver)
            xnor_nbit #(.N(9)) U_CMP (
                .src1(code),
                .src2(slot[k]),
                .y(igual)
            );

            and U_MATCH(match[k], igual[0], igual[1], igual[2], igual[3], igual[4],
                                  igual[5], igual[6], igual[7], igual[8]);

            and U_HIT_K(hit_k[k], match[k], v[k]);

            // Escribir o borrar
            and U_WE(we[k], agregar, w[k]);
            and U_BORRAR(borrar[k], toggle, hit_k[k]);

            // Siguiente bit de valido: (v + we) * !borrar
            or  U_VSET(v_set, v[k], we[k]);
            not U_NBORRAR(nborrar, borrar[k]);
            and U_VNEXT(v_next[k], v_set, nborrar);

            // Si we = 1 entra el codigo, si no se conserva
            mux_2_1_param #(.N(9)) U_MUX_SLOT (
                .a(slot[k]),
                .b(code),
                .sel(we[k]),
                .y(slot_next)
            );

            always_ff @(posedge clk, negedge rst) begin
                if (!rst) slot[k] <= '0;
                else      slot[k] <= slot_next;
            end
        end
    endgenerate

    always_ff @(posedge clk, negedge rst) begin
        if (!rst) v <= '0;
        else      v <= v_next;
    end

    assign used = v;

endmodule
