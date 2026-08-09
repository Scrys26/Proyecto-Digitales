// vga_timing_640x480.sv
// HS/VS activos en 0, 640x480@60 (total 800x525), clk_pix ≈ 25.175 MHz.
module vga_timing_640x480 #(
  parameter int H_VISIBLE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48,
  parameter int V_VISIBLE = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33
)(
  input  logic clk_pix,
  input  logic rst,                // síncrono al clk_pix
  output logic hsync,              // activo en 0
  output logic vsync,              // activo en 0
  output logic de,                 // data enable (zona visible)
  output logic [9:0] x,            // 0..639 válido cuando de=1
  output logic [9:0] y             // 0..479 válido cuando de=1
);
  localparam int H_TOTAL = H_VISIBLE + H_FP + H_SYNC + H_BP; // 800
  localparam int V_TOTAL = V_VISIBLE + V_FP + V_SYNC + V_BP; // 525

  logic [9:0] hcnt, vcnt;

  always_ff @(posedge clk_pix) begin
    if (rst) begin
      hcnt <= 10'd0; vcnt <= 10'd0;
    end else begin
      if (hcnt == H_TOTAL-1) begin
        hcnt <= 10'd0;
        vcnt <= (vcnt == V_TOTAL-1) ? 10'd0 : vcnt + 10'd1;
      end else begin
        hcnt <= hcnt + 10'd1;
      end
    end
  end

  // HS/VS negativos
  assign hsync = ~((hcnt >= H_VISIBLE+H_FP) && (hcnt < H_VISIBLE+H_FP+H_SYNC));
  assign vsync = ~((vcnt >= V_VISIBLE+V_FP) && (vcnt < V_VISIBLE+V_FP+V_SYNC));

  assign de = (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);
  assign x  = de ? hcnt : 10'd0;
  assign y  = de ? vcnt : 10'd0;
endmodule
