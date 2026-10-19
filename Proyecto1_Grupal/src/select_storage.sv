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
    logic [3:0] count_res;
    logic neg_count1, neg_count2;
    logic last;
    logic step_last;
    logic done;


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

    not U_NOT(neg_count1, count[1]);
    not U_NOT2(neg_count2, count[2]);
    and U_AND(last, neg_count1, count[0], neg_count2, count[3]);
    and U_AND2(step_last, last, step);
    mux_2_1_param #(.N(4)) U_COUNT(
        .a(count_next),
        .b('0),
        .sel(last),
        .y(count_res)
    );

    always_ff @(posedge clk, negedge rst) begin
        if(!rst) begin
            count <= '0;
            done <= 1'b0;
        end
        else begin
            done <= step_last;
            if(step) begin
                count <= count_res;
            end
        end
    end


    not U_NOT3(ns0, s[0]);
    not U_NOT4(ns1, s[1]);

    and U_AND3(we1, done, ns1,  ns0);    // s = 00
    and U_AND4(we2, done, ns1,  s[0]);   // s = 01
    and U_AND5(we3, done, s[1], ns0);    // s = 10

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