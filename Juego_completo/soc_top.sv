// ============================================================================
// soc_top.sv
// SoC RISC-V uniciclo + ROM + RAM + MMIO + UART + TIMER + VGA Battleship
// ============================================================================

module soc_top (
    input  logic        clk,          // 100 MHz de la FPGA
    input  logic        rst,          // reset global activo en 1

    // --------- Mando físico (7 botones, típicamente en JA) ---------
    input  logic        ja_up,
    input  logic        ja_down,
    input  logic        ja_left,
    input  logic        ja_right,
    input  logic        ja_confirm,
    input  logic        ja_cancel,
    input  logic        ja_rotate,

    // UART física
    input  logic        uart_rx,
    output logic        uart_tx,

    // LEDs y 7 segmentos "crudos"
    output logic [15:0] leds_o,
    output logic [7:0]  display0_o,   // SEG_D0 (0x0001_0020)
    output logic [7:0]  display1_o,   // SEG_D1 (0x0001_0024)

    // VGA físico (hacia Nexys)
    output logic        Hsync,
    output logic        Vsync,
    output logic [3:0]  vgaRed,
    output logic [3:0]  vgaGreen,
    output logic [3:0]  vgaBlue
);

    // ------------------------------------------------------------------------
    // 0) Mando lógico MMIO: genera MANDO_DAT / MANDO_STA para el SoC
    // ------------------------------------------------------------------------
    logic [31:0] mando_dat;
    logic [31:0] mando_sta;

    mando_ja_mmio u_mando (
        .clk         (clk),
        .rst         (rst),
        .btn_up      (ja_up),
        .btn_down    (ja_down),
        .btn_left    (ja_left),
        .btn_right   (ja_right),
        .btn_confirm (ja_confirm),
        .btn_cancel  (ja_cancel),
        .btn_rotate  (ja_rotate),
        .mando_dat_o (mando_dat),
        .mando_sta_o (mando_sta)
    );

    // ------------------------------------------------------------------------
    // 1) Señales del núcleo RISC-V uniciclo
    // ------------------------------------------------------------------------
    logic [31:0] ProgAddress_o;
    logic [31:0] ProgIn_i;

    logic [31:0] DataAddress_o;
    logic [31:0] DataOut_o;
    logic [31:0] DataIn_i;

    logic        we_o;         // store
    logic        mem_read_o;   // load
    logic        one_b, two_b, four_b;
    logic [31:0] pc_out;       // opcional (para debug en 7seg si quieres)

    // ------------------------------------------------------------------------
    // 2) ROM de instrucciones
    // ------------------------------------------------------------------------
    localparam int INST_MEM_WIDTH = 32;
    localparam int INST_MEM_DEPTH = 15; // bits de dirección (2^15 bytes = 32kB)

    logic [INST_MEM_WIDTH-1:0] instruction;

    inst_mem #(
        .WIDTH(INST_MEM_WIDTH),
        .DEPTH(INST_MEM_DEPTH)
    ) u_rom (
    `ifdef MULTICYCLE
        .clk      (clk),
    `endif
        .rst      (rst),
        .data_in  (32'b0),            // ROM => ignorado
        .addr     (ProgAddress_o),    // PC del core
        .wr       (1'b0),
        .rd       (1'b1),
        .data_out (instruction)
    );

    assign ProgIn_i = instruction;

    // ------------------------------------------------------------------------
    // 3) RAM de datos
    //    Región lógica en el mapa: 0x0000_2000 – 0x0000_2FFF
    // ------------------------------------------------------------------------
    localparam int DATA_MEM_WIDTH = 32;
    localparam int DATA_MEM_DEPTH = 16; // como en tu ejemplo (14 bits de addr)

    logic [DATA_MEM_WIDTH-1:0] data_mem_rdata;
    logic                      ram_wr, ram_rd;
    wire                       is_data_ram;

    // Detecta si la dirección cae en la ventana de RAM de datos
    assign is_data_ram =
        (DataAddress_o >= 32'h0000_2000) &&
        (DataAddress_o <  32'h0000_3000);

    assign ram_wr = we_o        && is_data_ram;
    assign ram_rd = mem_read_o  && is_data_ram;

    data_mem #(
        .WIDTH(DATA_MEM_WIDTH),
        .DEPTH(DATA_MEM_DEPTH)
    ) u_ram (
        .clk        (clk),
        .rst        (rst),
        .data_in    (DataOut_o),
        .addr       (DataAddress_o[DATA_MEM_DEPTH-1:0]),
        .wr         (ram_wr),
        .rd         (ram_rd),
        .one_byte   (one_b),
        .two_bytes  (two_b),
        .four_bytes (four_b),
        .data_out   (data_mem_rdata)
    );

    // ------------------------------------------------------------------------
    // 4) Bloque MMIO (MANDO / LEDs / 7seg / UART / TIMER / VGA)
    // ------------------------------------------------------------------------
    logic [31:0] mmio_rdata;
    logic        mmio_hit;

    // UART <-> MMIO
    logic        uart_wr;
    logic        uart_reg_sel;
    logic [31:0] uart_entrada;
    logic [31:0] uart_salida;

    // TIMER <-> MMIO
    logic        tim_wr;
    logic  [0:0] tim_addr;
    logic [31:0] tim_wdata;
    logic [31:0] tim_rdata;

    // VGA <-> MMIO
    logic        vga_we;
    logic [31:0] vga_waddr;
    logic [31:0] vga_wdata;

    soc_mmio_block #(
        .MMIO_BASE(32'h0001_0000)
    ) u_mmio (
        .clk        (clk),
        .rst        (rst),

        .addr_i     (DataAddress_o),
        .wdata_i    (DataOut_o),
        .we_i       (we_o),
        .re_i       (mem_read_o),
        .rdata_o    (mmio_rdata),
        .mmio_hit_o (mmio_hit),

        // MANDO: ahora vienen del mando_ja_mmio
        .ctrl_in_data_i   (mando_dat),
        .ctrl_btn_state_i (mando_sta),

        // LEDs / 7seg (salida directa a puertos de este top)
        .leds_o       (leds_o),
        .seg_digit0_o (display0_o),
        .seg_digit1_o (display1_o),

        // UART hacia Interfaz_UART
        .uart_wr_o       (uart_wr),
        .uart_reg_sel_o  (uart_reg_sel),
        .uart_entrada_o  (uart_entrada),
        .uart_salida_i   (uart_salida),

        // Timer hacia Timer_Top
        .tim_wr_o     (tim_wr),
        .tim_addr_o   (tim_addr),
        .tim_wdata_o  (tim_wdata),
        .tim_rdata_i  (tim_rdata),

        // VGA hacia BattleshipVGA_MMIO
        .vga_we_o     (vga_we),
        .vga_waddr_o  (vga_waddr),
        .vga_wdata_o  (vga_wdata)
    );

    // ------------------------------------------------------------------------
    // 5) Multiplexor de lectura para el núcleo (DataIn_i)
    // ------------------------------------------------------------------------
    always_comb begin
        // Por defecto, 0
        DataIn_i = 32'h0000_0000;

        if (mmio_hit) begin
            // Lectura de periféricos
            DataIn_i = mmio_rdata;
        end else if (is_data_ram) begin
            // Lectura de RAM
            DataIn_i = data_mem_rdata;
        end
        // Si quisieras ROM legible por DataAddress, aquí se podría agregar
    end

    // ------------------------------------------------------------------------
    // 6) Núcleo uniciclo (memoria de datos externa + ROM externa)
    // ------------------------------------------------------------------------
    uniciclo #(
        .WIDTH          (32),
        .INST_MEM_DEPTH (INST_MEM_DEPTH),
        .REG_FILE_DEPTH (5),
        .DATA_MEM_DEPTH (DATA_MEM_DEPTH),
        .INST_SIZE      (32)
    ) u_core (
        .clk_i          (clk),
        .rst_i          (rst),

        .ProgAddress_o  (ProgAddress_o),
        .ProgIn_i       (ProgIn_i),

        .DataAddress_o  (DataAddress_o),
        .DataOut_o      (DataOut_o),
        .DataIn_i       (DataIn_i),

        .we_o           (we_o),
        .mem_read_o     (mem_read_o),
        .one_byte_o     (one_b),
        .two_bytes_o    (two_b),
        .four_bytes_o   (four_b),

        .pc_out         (pc_out)     // opcional, sin uso aquí
    );

    // ------------------------------------------------------------------------
    // 7) UART física: Interfaz_UART
    // ------------------------------------------------------------------------
    logic [10:0] status_fifo_tx;
    logic [10:0] status_fifo_rx;
    logic        RXAV, FTXF;   // si tu versión los tiene; si no, ignóralos

    Interfaz_UART u_uartif (
        .clk            (clk),
        .reset          (rst),
        .wr_i           (uart_wr),
        .reg_sel_i      (uart_reg_sel),
        .entrada_i      (uart_entrada),
        .uart_rx        (uart_rx),
        .uart_tx        (uart_tx),
        .status_fifo_tx (status_fifo_tx),
        .status_fifo_rx (status_fifo_rx),
        .salida_o       (uart_salida),
        .RXAV           (RXAV),
        .FTXF           (FTXF)
    );

    // ------------------------------------------------------------------------
    // 8) Timer: Timer_Top
    // ------------------------------------------------------------------------
    logic timeout_pulse;

    Timer_Top u_timer (
        .clk       (clk),
        .reset     (rst),
        .addr_i    (tim_addr),    // 0 => CTRL, 1 => COUNTER
        .data_in   (tim_wdata),
        .data_out  (tim_rdata),
        .write_i   (tim_wr),
        .timeout_o (timeout_pulse)
    );
    // Puedes usar timeout_pulse para debug o IRQ más adelante.

    // ------------------------------------------------------------------------
    // 9) VGA Battleship: módulo MMIO -> tablero VGA
    // ------------------------------------------------------------------------
    BattleshipVGA_MMIO #(
        .CELL_SIZE (32)
    ) u_vga (
        .clk         (clk),          // mismo clk de 100 MHz del SoC
        .rst         (rst),

        .vga_waddr_i (vga_waddr),
        .vga_wdata_i (vga_wdata),
        .vga_we_i    (vga_we),

        .Hsync       (Hsync),
        .Vsync       (Vsync),
        .vgaRed      (vgaRed),
        .vgaGreen    (vgaGreen),
        .vgaBlue     (vgaBlue)
    );

endmodule
