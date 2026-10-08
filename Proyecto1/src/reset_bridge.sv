module reset_bridge (
    input  logic clk,
    input  logic async_rst_in,
    output logic sync_rst_out
);
  logic rst_ff1;


  always_ff @(posedge clk or posedge async_rst_in) begin
    if (async_rst_in) begin
      rst_ff1 <= 1'b1;
      sync_rst_out <= 1'b1;
    end else begin
      rst_ff1 <= 1'b0;
      sync_rst_out <= rst_ff1;
    end
  end



endmodule