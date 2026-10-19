module mux_2_1_param #(
  parameter N = 8
)(
  input logic [N - 1: 0] a, 
  input logic [N - 1: 0] b, 
  input logic sel, 

  output logic [N - 1 : 0] y 
);  

  genvar i; 
  generate 
      for (i = 0; i < N; i++) begin : mux_bit
        mux_2_1 u_mux_per_bit(
          .a(a[i]),
          .b(b[i]),
          .sel(sel),
          .y(y[i])
        );
      end 
  endgenerate 
  
endmodule