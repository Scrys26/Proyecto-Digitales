// ============================================================================
// soc_mmio_block.sv
// Ventana MMIO: 0x0001_0000 - 0x0001_FFFF
// ============================================================================
module soc_mmio_block #(
  parameter logic [31:0] MMIO_BASE = 32'h0001_0000
)(
  input  logic        clk,
  input  logic        rst,

  // ---------- Bus desde el núcleo uniciclo ----------
  input  logic [31:0] addr_i,
  input  logic [31:0] wdata_i,
  input  logic        we_i,      // store
  input  logic        re_i,      // load
  output logic [31:0] rdata_o,
  output logic        mmio_hit_o, // 1 si la dirección cae en la ventana MMIO

  // ---------- MANDO / CONTROL (solo lectura) ----------
  input  logic [31:0] ctrl_in_data_i,    // MANDO_DAT: coordenadas, etc.
  input  logic [31:0] ctrl_btn_state_i,  // MANDO_STA: estado de botones

  // ---------- LEDs / 7 segmentos ----------
  output logic [15:0] leds_o,
  output logic [7:0]  seg_digit0_o,
  output logic [7:0]  seg_digit1_o,

  // ---------- UART (Interfaz_UART) ----------
  output logic        uart_wr_o,
  output logic        uart_reg_sel_o,
  output logic [31:0] uart_entrada_o,
  input  logic [31:0] uart_salida_i,

  // ---------- Timer (Timer_Top) ----------
  output logic        tim_wr_o,
  output logic  [0:0] tim_addr_o,
  output logic [31:0] tim_wdata_o,
  input  logic [31:0] tim_rdata_i,

  // ---------- VGA (tablero jugador 1) ----------
  output logic        vga_we_o,
  output logic [31:0] vga_waddr_o,
  output logic [31:0] vga_wdata_o
);

  // ---------------- Direcciones fijas ----------------
  localparam logic [31:0]
    ADDR_CTRL_IN_DATA   = 32'h0001_0000, // MANDO_DAT
    ADDR_CTRL_BTN_STATE = 32'h0001_0004, // MANDO_STA

    ADDR_LEDS_DATA      = 32'h0001_0010,

    ADDR_SEG_DIG0       = 32'h0001_0020,
    ADDR_SEG_DIG1       = 32'h0001_0024,

    ADDR_UART_CTRLSTAT  = 32'h0001_0040, // Interfaz_UART, reg_sel=0
    ADDR_UART_DATA      = 32'h0001_0044, // Interfaz_UART, reg_sel=1

    ADDR_TIM_CTRLSTAT   = 32'h0001_0050, // Timer_Top addr=0
    ADDR_TIM_COUNTER    = 32'h0001_0054, // Timer_Top addr=1

    ADDR_VGA_BASE       = 32'h0001_0060,
    ADDR_VGA_LIMIT      = 32'h0001_00FF,

    // --- NUEVO: tablero remoto 10x10 (100 bytes) ---
    ADDR_BOARD_BASE     = 32'h0001_0200,
    ADDR_BOARD_LIMIT    = 32'h0001_0263; // inclusive: 0x0200 + 99

  // ------------ Detección básica de ventana MMIO ------------
  // Comparamos solo los 16 bits altos: 0x0001_xxxx
  assign mmio_hit_o = (addr_i[31:16] == MMIO_BASE[31:16]);

  // Señales de selección por periférico
  wire sel_ctrl_in   = mmio_hit_o && (addr_i == ADDR_CTRL_IN_DATA);
  wire sel_ctrl_btn  = mmio_hit_o && (addr_i == ADDR_CTRL_BTN_STATE);
  wire sel_leds      = mmio_hit_o && (addr_i == ADDR_LEDS_DATA);
  wire sel_seg0      = mmio_hit_o && (addr_i == ADDR_SEG_DIG0);
  wire sel_seg1      = mmio_hit_o && (addr_i == ADDR_SEG_DIG1);
  wire sel_uart_ctrl = mmio_hit_o && (addr_i == ADDR_UART_CTRLSTAT);
  wire sel_uart_data = mmio_hit_o && (addr_i == ADDR_UART_DATA);
  wire sel_tim_ctrl  = mmio_hit_o && (addr_i == ADDR_TIM_CTRLSTAT);
  wire sel_tim_cnt   = mmio_hit_o && (addr_i == ADDR_TIM_COUNTER);
  wire sel_vga       = mmio_hit_o &&
                       (addr_i >= ADDR_VGA_BASE) &&
                       (addr_i <= ADDR_VGA_LIMIT);

  // --- NUEVO: selección tablero remoto ---
  wire sel_board     = mmio_hit_o &&
                       (addr_i >= ADDR_BOARD_BASE) &&
                       (addr_i <= ADDR_BOARD_LIMIT);

  // ------------------------------------------------------------------
  // 2. LEDs (RW) - registro de 32 bits, tú usarás solo [15:0]
  // ------------------------------------------------------------------
  logic [31:0] leds_q;
  logic [31:0] leds_rdata;

  mmio_reg #(
    .RESET_VALUE(32'h0000_0000),
    .RW1C_MASK  (32'h0000_0000),
    .RO_MASK    (32'h0000_0000)
  ) u_leds (
    .clk        (clk),
    .rst        (rst),
    .sel_i      (sel_leds),
    .we_i       (we_i),
    .wdata_i    (wdata_i),
    .rdata_o    (leds_rdata),
    .set_bits_i (32'h0000_0000),
    .ro_bits_i  (32'h0000_0000),
    .q          (leds_q)
  );

  assign leds_o = leds_q[15:0];

  // ------------------------------------------------------------------
  // 3. 7 segmentos - 2 registros RW de 8 bits
  // ------------------------------------------------------------------
  logic [31:0] seg0_q, seg1_q;
  logic [31:0] seg0_rdata, seg1_rdata;

  mmio_reg #(
    .RESET_VALUE(32'h0000_0000),
    .RW1C_MASK  (32'h0000_0000),
    .RO_MASK    (32'h0000_0000)
  ) u_seg0 (
    .clk        (clk),
    .rst        (rst),
    .sel_i      (sel_seg0),
    .we_i       (we_i),
    .wdata_i    (wdata_i),
    .rdata_o    (seg0_rdata),
    .set_bits_i (32'h0000_0000),
    .ro_bits_i  (32'h0000_0000),
    .q          (seg0_q)
  );

  mmio_reg #(
    .RESET_VALUE(32'h0000_0000),
    .RW1C_MASK  (32'h0000_0000),
    .RO_MASK    (32'h0000_0000)
  ) u_seg1 (
    .clk        (clk),
    .rst        (rst),
    .sel_i      (sel_seg1),
    .we_i       (we_i),
    .wdata_i    (wdata_i),
    .rdata_o    (seg1_rdata),
    .set_bits_i (32'h0000_0000),
    .ro_bits_i  (32'h0000_0000),
    .q          (seg1_q)
  );

  assign seg_digit0_o = seg0_q[7:0];
  assign seg_digit1_o = seg1_q[7:0];

  // ------------------------------------------------------------------
  // 4. UART - conexión directa a Interfaz_UART
  // ------------------------------------------------------------------
  always_comb begin
    uart_entrada_o  = wdata_i;

    if (sel_uart_data)
      uart_reg_sel_o = 1'b1;
    else
      uart_reg_sel_o = 1'b0;

    uart_wr_o = we_i && (sel_uart_ctrl || sel_uart_data);
  end

  // ------------------------------------------------------------------
  // 5. Timer - conexión directa a Timer_Top
  // ------------------------------------------------------------------
  always_comb begin
    tim_addr_o  = (sel_tim_cnt) ? 1'b1 : 1'b0; // 0: CTRL, 1: COUNTER
    tim_wdata_o = wdata_i;
    tim_wr_o    = we_i && (sel_tim_ctrl || sel_tim_cnt);
  end

  // ------------------------------------------------------------------
  // 6. VGA - puerto abstracto de escritura
  // ------------------------------------------------------------------
  always_comb begin
    vga_we_o    = we_i && sel_vga;
    vga_waddr_o = addr_i;
    vga_wdata_o = wdata_i;
  end

  // ------------------------------------------------------------------
  // 7. NUEVO: tablero remoto MMIO
  // ------------------------------------------------------------------
  logic [31:0] board_rdata;

  remote_board_mmio #(
    .BASE_ADDR(ADDR_BOARD_BASE),
    .CELLS    (100)
  ) u_remote_board (
    .clk     (clk),
    .rst     (rst),
    .addr_i  (addr_i),
    .wdata_i (wdata_i),
    .we_i    (we_i),
    .re_i    (re_i),
    .rdata_o (board_rdata)
  );

  // ------------------------------------------------------------------
  // 8. Mux de lectura global (rdata_o)
  //     Reescrito para usar los sel_* en vez de case(addr_i)
// ------------------------------------------------------------------
  always_comb begin
    rdata_o = 32'h0000_0000;

    if (re_i && mmio_hit_o) begin
      unique case (1'b1)
        sel_ctrl_in   : rdata_o = ctrl_in_data_i;
        sel_ctrl_btn  : rdata_o = ctrl_btn_state_i;

        sel_leds      : rdata_o = leds_rdata;
        sel_seg0      : rdata_o = seg0_rdata;
        sel_seg1      : rdata_o = seg1_rdata;

        sel_uart_ctrl,
        sel_uart_data : rdata_o = uart_salida_i;

        sel_tim_ctrl,
        sel_tim_cnt   : rdata_o = tim_rdata_i;

        sel_board     : rdata_o = board_rdata;  // <-- tablero remoto

        default       : rdata_o = 32'h0000_0000;
      endcase
    end
  end

endmodule