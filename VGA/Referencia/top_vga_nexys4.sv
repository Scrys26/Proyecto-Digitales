// top_vga_nexys4.sv
// Integra Clocking Wizard + controlador VGA. Reset por botón (activo bajo).
module top_vga_nexys4 (
  input  logic clk_100mhz,   // reloj de 100 MHz de la placa
  input  logic btn_reset_n,  // botón reset (activo en 0)
  output logic vga_hs,
  output logic vga_vs,
  output logic [3:0] vga_r,
  output logic [3:0] vga_g,
  output logic [3:0] vga_b
);
  // ----------------------------------------------------------------------------
  // 1) Generación de reloj de píxel (Clocking Wizard)
  //    Crea el IP en Vivado con nombre de módulo: clk_wiz_25m
  //    Entradas/salidas típicas: clk_in1, reset, clk_out1, locked
  // ----------------------------------------------------------------------------
  logic clk_pix, mmcm_locked;
  logic rst_pix;

  // Reset del MMCM (activo en 1)
  logic rst_mmcm = ~btn_reset_n;

  clk_wiz_25m u_clkgen (
    .clk_in1 (clk_100mhz),
    .reset   (rst_mmcm),
    .clk_out1(clk_pix),      // configura a 25.175 MHz (o 25.000 MHz)
    .locked  (mmcm_locked)
  );

  // Reset del dominio de píxel: liberado solo cuando el MMCM está locked
  always_ff @(posedge clk_pix or negedge btn_reset_n) begin
    if (!btn_reset_n) rst_pix <= 1'b1;
    else              rst_pix <= ~mmcm_locked;
  end

  // ----------------------------------------------------------------------------
  // 2) Controlador VGA
  // ----------------------------------------------------------------------------
  vga_controller_top u_vga (
    .clk_pix (clk_pix),
    .rst_pix (rst_pix),
    .vga_hs  (vga_hs),
    .vga_vs  (vga_vs),
    .vga_r   (vga_r),
    .vga_g   (vga_g),
    .vga_b   (vga_b)
  );

endmodule
