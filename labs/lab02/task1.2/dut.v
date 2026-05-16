
`timescale 1ns/1ps
module dut (
  input wire clk,
  input wire d,
  input reset,
  output reg q
);
  always @(posedge clk or negedge reset) begin
    if (reset!=1)
      q <= 0;
    else
      q<=d;
  end
endmodule
