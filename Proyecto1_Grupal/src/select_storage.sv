module select_storage(
    input logic clk,
    input logic rst,
    input logic step,
    input logic ser,
    input logic [1:0] s,
    output logic [8:0] src1,
    output logic [8:0] src2,
    output logic [8:0] src3
);
    logic [8:0] q;
    logic ns0, ns1;
    logic we1, we2, we3;
    logic [3:0] count;
    logic [3:0] count_next;
    logic neg_count0, neg_count2;
    logic full;

    dsr_595 #(.N(9)) U_595 (
        .clk(clk),
        .rst(rst),
        .step(step),
        .ser(ser),
        .q(q)
    );

    ripple_adder #(.N(4)) U_CALC_CNT(
        .a(count),
        .b(4'b0001),
        .c_in(1'b0),
        .res(count_next),
        .c_out()
    );

    not U_NOT(neg_count0, count[0]);
    not U_NOT2(neg_count2, count[2]);
    and U_AND(full, neg_count0, count[1], neg_count2, count[3]);

    always_ff @(posedge clk, negedge rst) begin
        if (!rst) count <= '0;
        else if (full) count <= '0;
        else if (step) count <= count_next;
    end


    not U_NOT3(ns0, s[0]);
    not U_NOT4(ns1, s[1]);

    and U_AND2(we1, full, ns1,  ns0);    // s = 00
    and U_AND3(we2, full, ns1,  s[0]);   // s = 01
    and U_AND4(we3, full, s[1], ns0);    // s = 10

    always_ff @( posedge clk, negedge rst ) begin
        if(!rst) begin
            src1 <= '0;
            src2 <= '0;
            src3 <= '0;
        end else begin
            if(we1) src1 <= q;
            if(we2) src2 <= q;
            if(we3) src3 <= q;
        end
    end

endmodule