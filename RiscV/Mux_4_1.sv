`timescale 1ns/1ps
module mux_4_1 #(parameter WIDTH=32) (
  input  logic  [WIDTH-1:0] A, B, C, D,
  input  logic  [1:0]       sel,
  output logic [WIDTH-1:0]  out
);
  always_comb begin
    unique case (sel)
      2'h0: out = A;
      2'h1: out = B;
      2'h2: out = C;
      2'h3: out = D;
      default: out = A; // corta X
    endcase
  end
endmodule
