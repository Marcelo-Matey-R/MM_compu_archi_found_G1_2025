module sync_edge_detector (
    input  logic clk,
    input  logic rst,
    input  logic async_in,  //pin crudo de KEY
    output logic sync_out,  //senal ya sincronizada
    output logic pulse_out  //pulso de un ciclo en el flanco de subida (presionar boton)
);
  logic sync_ff1;
  logic sync_ff2;

  logic sync_out_prev;


  always_ff @(posedge clk) begin
    if (rst) begin
      sync_ff1 <= 1'b0;
      sync_ff2 <= 1'b0;
    end else begin
      sync_ff1 <= async_in;
      sync_ff2 <= sync_ff1;

    end
  end


  assign sync_out = sync_ff2;

  always_ff @(posedge clk) begin
    if (rst) begin
      sync_out_prev <= 1'b0;
    end else begin
      sync_out_prev <= sync_out;
    end
  end


  assign pulse_out = sync_out & (!sync_out_prev);


endmodule