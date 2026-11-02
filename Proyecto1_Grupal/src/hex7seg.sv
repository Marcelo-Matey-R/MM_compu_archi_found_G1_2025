// Decodificador de hexadecimal (0 a F) a display de siete segmentos.
// Salida activa en bajo, como los HEX de la tarjeta: seg[k] = 1 apaga el segmento.
//
//        a
//      -----
//   f |     | b
//     |  g  |
//      -----
//   e |     | c
//     |     |
//      -----
//        d
//
// seg[0] = a, seg[1] = b, ... seg[6] = g
//
// Como la salida es activa en bajo, cada segmento es la suma de productos de los
// digitos donde ese segmento va APAGADO (son pocos, asi las ecuaciones salen cortas).
// x = {x3 x2 x1 x0}, digitos: 0 1 2 3 4 5 6 7 8 9 A b C d E F
//
//   seg  apagado en      ecuacion
//   a    1 4 b d         !x3!x2!x1 x0 + !x3 x2!x1!x0 + x3!x2 x1 x0 + x3 x2!x1 x0
//   b    5 6 b C E F     x2 x1!x0 + x3 x2!x0 + x3 x1 x0 + !x3 x2!x1 x0
//   c    2 C E F         x3 x2!x0 + x3 x2 x1 + !x3!x2 x1!x0
//   d    1 4 7 A F       x2 x1 x0 + !x3!x2!x1 x0 + !x3 x2!x1!x0 + x3!x2 x1!x0
//   e    1 3 4 5 7 9     !x3 x0 + !x3 x2!x1 + !x2!x1 x0
//   f    1 2 3 7 d       !x3!x2 x0 + !x3!x2 x1 + !x3 x1 x0 + x3 x2!x1 x0
//   g    0 1 7 C         !x3!x2!x1 + !x3 x2 x1 x0 + x3 x2!x1!x0

module hex7seg (
    input  logic [3:0] x,
    output logic [6:0] seg          // activo en bajo
);

    logic x0, x1, x2, x3;
    logic n0, n1, n2, n3;

    assign x0 = x[0];
    assign x1 = x[1];
    assign x2 = x[2];
    assign x3 = x[3];

    not U_N0(n0, x0);
    not U_N1(n1, x1);
    not U_N2(n2, x2);
    not U_N3(n3, x3);

    // ---------------- a: apagado en 1, 4, b, d ----------------
    logic a1, a2, a3, a4;
    and U_A1(a1, n3, n2, n1, x0);   // 1
    and U_A2(a2, n3, x2, n1, n0);   // 4
    and U_A3(a3, x3, n2, x1, x0);   // b
    and U_A4(a4, x3, x2, n1, x0);   // d
    or  U_A (seg[0], a1, a2, a3, a4);

    // ---------------- b: apagado en 5, 6, b, C, E, F ----------------
    logic b1, b2, b3, b4;
    and U_B1(b1, x2, x1, n0);       // 6, E
    and U_B2(b2, x3, x2, n0);       // C, E
    and U_B3(b3, x3, x1, x0);       // b, F
    and U_B4(b4, n3, x2, n1, x0);   // 5
    or  U_B (seg[1], b1, b2, b3, b4);

    // ---------------- c: apagado en 2, C, E, F ----------------
    logic c1, c2, c3;
    and U_C1(c1, x3, x2, n0);       // C, E
    and U_C2(c2, x3, x2, x1);       // E, F
    and U_C3(c3, n3, n2, x1, n0);   // 2
    or  U_C (seg[2], c1, c2, c3);

    // ---------------- d: apagado en 1, 4, 7, A, F ----------------
    logic d1, d2, d3, d4;
    and U_D1(d1, x2, x1, x0);       // 7, F
    and U_D2(d2, n3, n2, n1, x0);   // 1
    and U_D3(d3, n3, x2, n1, n0);   // 4
    and U_D4(d4, x3, n2, x1, n0);   // A
    or  U_D (seg[3], d1, d2, d3, d4);

    // ---------------- e: apagado en 1, 3, 4, 5, 7, 9 ----------------
    logic e1, e2, e3;
    and U_E1(e1, n3, x0);           // 1, 3, 5, 7
    and U_E2(e2, n3, x2, n1);       // 4, 5
    and U_E3(e3, n2, n1, x0);       // 1, 9
    or  U_E (seg[4], e1, e2, e3);

    // ---------------- f: apagado en 1, 2, 3, 7, d ----------------
    logic f1, f2, f3, f4;
    and U_F1(f1, n3, n2, x0);       // 1, 3
    and U_F2(f2, n3, n2, x1);       // 2, 3
    and U_F3(f3, n3, x1, x0);       // 3, 7
    and U_F4(f4, x3, x2, n1, x0);   // d
    or  U_F (seg[5], f1, f2, f3, f4);

    // ---------------- g: apagado en 0, 1, 7, C ----------------
    logic g1, g2, g3;
    and U_G1(g1, n3, n2, n1);       // 0, 1
    and U_G2(g2, n3, x2, x1, x0);   // 7
    and U_G3(g3, x3, x2, n1, n0);   // C
    or  U_G (seg[6], g1, g2, g3);

endmodule
