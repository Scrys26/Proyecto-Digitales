// vga_controller_top.sv
// Salidas compatibles con Nexys-4: RGB 4-4-4, HS/VS activos en 0.
module vga_controller_top (
  input  logic        clk_pix,      // ~25.175 MHz
  input  logic        rst_pix,      // síncrono a clk_pix
  output logic        vga_hs,
  output logic        vga_vs,
  output logic [3:0]  vga_r,
  output logic [3:0]  vga_g,
  output logic [3:0]  vga_b
);
  logic de;
  logic [9:0] x, y;

  vga_timing_640x480 u_tim (
    .clk_pix (clk_pix),
    .rst     (rst_pix),
    .hsync   (vga_hs),
    .vsync   (vga_vs),
    .de      (de),
    .x       (x),
    .y       (y)
  );

  vga_colorbars_444 u_pat (
    .clk_pix (clk_pix),
    .rst     (rst_pix),
    .de      (de),
    .x       (x),
    .y       (y),
    .r       (vga_r),
    .g       (vga_g),
    .b       (vga_b)
  );
endmodule
