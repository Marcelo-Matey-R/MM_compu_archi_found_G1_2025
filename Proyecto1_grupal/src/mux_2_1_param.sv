module mux_2_1_param #(
  parameter N = 8
)(
  input logic [N - 1: 0] a, 
  input logic [N - 1: 0] b, 
  input logic sel, 

  output logic [N - 1 : 0] y 
); 
  

  logic neg_sel; 
  not U_NOT(neg_sel, sel); 

  genvar i; 
  generate 
      for (i = 0; i < N; i++) begin 
        logic a_out, b_out; 

        and U_AND(a_out, a[i], neg_sel); 
        and U_AND2(b_out, b[i], sel); 
        or U_OR(y[i], a_out, b_out); 


      end 
  endgenerate 
  
endmodule