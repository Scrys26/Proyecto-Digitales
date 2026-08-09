`timescale 1ns/1ps
module mux_2_1 #(parameter WIDTH=32) (
  input  logic  [WIDTH-1:0] A,
  input  logic  [WIDTH-1:0] B,
  input  logic              sel,
  output logic [WIDTH-1:0]  out
);
  always_comb begin
    unique case (sel)
      1'b0: out = A;
      1'b1: out = B;
      default: out = A; // corta X
    endcase
  end
endmodule
