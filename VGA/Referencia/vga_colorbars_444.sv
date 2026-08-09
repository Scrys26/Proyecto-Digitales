// vga_colorbars_444.sv
module vga_colorbars_444 (
  input  logic        clk_pix,
  input  logic        rst,
  input  logic        de,
  input  logic [9:0]  x,
  input  logic [9:0]  y,
  output logic [3:0]  r,
  output logic [3:0]  g,
  output logic [3:0]  b
);
  logic [3:0] r_i, g_i, b_i;

  always_comb begin
    if (de) begin
      unique case (x[9:7])
        3'b000: begin r_i=4'hF; g_i=4'h0; b_i=4'h0; end // rojo
        3'b001: begin r_i=4'h0; g_i=4'hF; b_i=4'h0; end // verde
        3'b010: begin r_i=4'h0; g_i=4'h0; b_i=4'hF; end // azul
        3'b011: begin r_i=4'hF; g_i=4'hF; b_i=4'h0; end // amarillo
        3'b100: begin r_i=4'h0; g_i=4'hF; b_i=4'hF; end // cian
        3'b101: begin r_i=4'hF; g_i=4'h0; b_i=4'hF; end // magenta
        3'b110: begin r_i=4'hF; g_i=4'hF; b_i=4'hF; end // blanco
        default:begin r_i=4'h0; g_i=4'h0; b_i=4'h0; end // negro
      endcase
    end else begin
      r_i=4'h0; g_i=4'h0; b_i=4'h0;
    end
  end

  assign r = r_i;
  assign g = g_i;
  assign b = b_i;
endmodule
