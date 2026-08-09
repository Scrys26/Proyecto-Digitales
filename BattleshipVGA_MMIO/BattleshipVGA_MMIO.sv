// ============================================================================
// BattleshipVGA_MMIO
// ------------------
// - CPU escribe en 0x0001_0060 .. 0x0001_00FF  (ventana VGA del SoC)
// - Este módulo decodifica internamente:
//
//   * 0x0001_0060 .. 0x0001_00xx : celdas del tablero (row/col/state)
//   * 0x0001_006C               : VGA_CUR_ROW   (fila cursor [3:0])
//   * 0x0001_007C               : VGA_CUR_COL   (col  cursor [3:0])
//   * 0x0001_008C               : VGA_CUR_CTRL  (bit0 = enable cursor)
//   * 0x0001_009C               : VGA_SPLASH_CTRL (bit0 = splash ON/OFF)
//
//   El splash es una imagen 640x232 centrada verticalmente.
//   Mientras splash_en_reg = 1:
//      - Dentro del rectángulo del logo se ve la ROM.
//      - Fuera de ese rectángulo se ve fondo azul celeste.
// ============================================================================

`timescale 1ns/1ps

module BattleshipVGA_MMIO #(
    parameter int CELL_SIZE  = 32
)(
    input  logic        clk,         // 100 MHz
    input  logic        rst,         // reset global

    // --- MMIO desde soc_mmio_block (dominio SoC) ---
    input  logic [31:0] vga_waddr_i, // PADDR cuando vga_we_i = 1
    input  logic [31:0] vga_wdata_i, // PWDATA (usamos [1:0] para celda)
    input  logic        vga_we_i,    // pulso de escritura (SoC)

    // --- VGA físico ---
    output logic        Hsync,
    output logic        Vsync,
    output logic [3:0]  vgaRed,
    output logic [3:0]  vgaGreen,
    output logic [3:0]  vgaBlue
);

    // ------------------------------------------------------------------------
    // 1) Tablero base
    // ------------------------------------------------------------------------
    logic       clk_25M;
    logic       in_vis, in_board, on_grid, text_on;
    logic [9:0] x_rel, y_rel;
    logic [9:0] x_vis, y_vis;
    logic [3:0] base_r, base_g, base_b;

    Tablero u_tab (
        .clk          (clk),
        .Hsync        (Hsync),
        .Vsync        (Vsync),
        .vgaRed       (base_r),
        .vgaGreen     (base_g),
        .vgaBlue      (base_b),

        .clk_25M_tap  (clk_25M),
        .in_vis_tap   (in_vis),
        .in_board_tap (in_board),
        .x_rel_tap    (x_rel),
        .y_rel_tap    (y_rel),
        .on_grid_tap  (on_grid),
        .text_on_tap  (text_on),
        .x_vis_tap    (x_vis),
        .y_vis_tap    (y_vis)
    );

    // ------------------------------------------------------------------------
    // 2) Sincronización MMIO -> clk_25M
    // ------------------------------------------------------------------------
    localparam logic [31:0] VGA_BASE        = 32'h0001_0060;
    localparam logic [31:0] VGA_CUR_ROW     = 32'h0001_006C;
    localparam logic [31:0] VGA_CUR_COL     = 32'h0001_007C;
    localparam logic [31:0] VGA_CUR_CTRL    = 32'h0001_008C;
    localparam logic [31:0] VGA_SPLASH_CTRL = 32'h0001_009C;

    logic        we_meta, we_sync, we_prev;
    logic [31:0] addr_meta, addr_sync;
    logic [31:0] data_meta, data_sync;

    always_ff @(posedge clk_25M or posedge rst) begin
        if (rst) begin
            we_meta   <= 1'b0;
            we_sync   <= 1'b0;
            we_prev   <= 1'b0;
            addr_meta <= 32'h0;
            addr_sync <= 32'h0;
            data_meta <= 32'h0;
            data_sync <= 32'h0;
        end else begin
            we_meta <= vga_we_i;
            we_sync <= we_meta;
            we_prev <= we_sync;

            addr_meta <= vga_waddr_i;
            addr_sync <= addr_meta;

            data_meta <= vga_wdata_i;
            data_sync <= data_meta;
        end
    end

    wire we_pulse = we_sync & ~we_prev;

    // ------------------------------------------------------------------------
    // 3) MMIO -> board_logic + cursor + SPLASH
    // ------------------------------------------------------------------------
    logic        bl_wr_en;
    logic [3:0]  bl_wr_row, bl_wr_col;
    logic [1:0]  bl_wr_state;

    logic        cur_en_reg;
    logic [3:0]  cur_row_reg, cur_col_reg;

    logic        splash_en_reg;   // 0 = OFF, 1 = ON

    always_ff @(posedge clk_25M or posedge rst) begin
        if (rst) begin
            bl_wr_en      <= 1'b0;
            bl_wr_row     <= 4'd0;
            bl_wr_col     <= 4'd0;
            bl_wr_state   <= 2'b00;

            cur_en_reg    <= 1'b0;
            cur_row_reg   <= 4'd0;
            cur_col_reg   <= 4'd0;

            splash_en_reg <= 1'b1;   // splash ON tras reset
        end else begin
            bl_wr_en <= 1'b0;

            if (we_pulse) begin
                if (addr_sync == VGA_CUR_ROW) begin
                    cur_row_reg <= data_sync[3:0];
                end
                else if (addr_sync == VGA_CUR_COL) begin
                    cur_col_reg <= data_sync[3:0];
                end
                else if (addr_sync == VGA_CUR_CTRL) begin
                    cur_en_reg <= data_sync[0];
                end
                else if (addr_sync == VGA_SPLASH_CTRL) begin
                    splash_en_reg <= data_sync[0];  // bit0 = enable splash
                end
                else if (addr_sync >= VGA_BASE &&
                         addr_sync <  (VGA_BASE + 32'h00000100)) begin
                    logic [31:0] off;
                    off = addr_sync - VGA_BASE;

                    bl_wr_en    <= 1'b1;
                    bl_wr_row   <= off[7:4];
                    bl_wr_col   <= off[3:0];
                    bl_wr_state <= data_sync[1:0];
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // 4) board_logic: memoria 10x10 + cursor
    // ------------------------------------------------------------------------
    logic [3:0] cell_r, cell_g, cell_b;
    logic       cell_painted;

    logic [3:0] cur_r, cur_g, cur_b;
    logic       cursor_on;

    board_logic #(
        .CELL_SIZE (CELL_SIZE),
        .CURSOR_THK(2)
    ) u_bl (
        .clk          (clk_25M),
        .rst          (rst),

        .in_board     (in_board),
        .x_rel        (x_rel),
        .y_rel        (y_rel),
        .on_grid      (on_grid),
        .text_on      (text_on),

        .wr_en        (bl_wr_en),
        .wr_col       (bl_wr_col),
        .wr_row       (bl_wr_row),
        .wr_state     (bl_wr_state),

        .cur_en       (cur_en_reg),
        .cur_col      (cur_col_reg),
        .cur_row      (cur_row_reg),

        .pix_r        (cell_r),
        .pix_g        (cell_g),
        .pix_b        (cell_b),
        .cell_painted (cell_painted),

        .cur_r        (cur_r),
        .cur_g        (cur_g),
        .cur_b        (cur_b),
        .cursor_on    (cursor_on)
    );

    // ------------------------------------------------------------------------
    // 5) Splash ROM 640x232 centrada verticalmente
    // ------------------------------------------------------------------------
    localparam int SPLASH_W  = 640;
    localparam int SPLASH_H  = 232;
    localparam int SPLASH_Y0 = (480 - SPLASH_H) / 2;  // = 124

    logic [3:0] splash_r, splash_g, splash_b;

    // Coordenadas dentro de la ventana splash
    wire [9:0] sx = x_vis;                  // 0..639
    wire [9:0] sy = y_vis - SPLASH_Y0;     // 0..231 (cuando está dentro)

    // Indica si el píxel actual está dentro del rectángulo del logo
    wire in_splash_area =
        in_vis &&
        (y_vis >= SPLASH_Y0) &&
        (y_vis <  SPLASH_Y0 + SPLASH_H);

    splash_rom #(
        .W       (SPLASH_W),
        .H       (SPLASH_H)
    ) u_splash (
        .clk (clk_25M),
        .x   (sx),
        .y   (sy),
        .r   (splash_r),
        .g   (splash_g),
        .b   (splash_b)
    );

    // ------------------------------------------------------------------------
    // 6) Mezcla final de colores
    // ------------------------------------------------------------------------
    always_comb begin
        if (!in_vis) begin
            vgaRed   = 4'h0;
            vgaGreen = 4'h0;
            vgaBlue  = 4'h0;
        end
        else if (splash_en_reg) begin
            // SPLASH ACTIVO:
            //  - Dentro de la ventana: logo (ROM).
            //  - Fuera de la ventana: azul celeste tipo tablero.
            if (in_splash_area) begin
                vgaRed   = splash_r;
                vgaGreen = splash_g;
                vgaBlue  = splash_b;
            end
            else begin
                // Azulito igual al tablero (R=9, G=D, B=F)
                vgaRed   = 4'h9;
                vgaGreen = 4'hD;
                vgaBlue  = 4'hF;
            end
        end
        else if (cursor_on) begin
            vgaRed   = cur_r;
            vgaGreen = cur_g;
            vgaBlue  = cur_b;
        end
        else if (cell_painted) begin
            vgaRed   = cell_r;
            vgaGreen = cell_g;
            vgaBlue  = cell_b;
        end
        else begin
            vgaRed   = base_r;
            vgaGreen = base_g;
            vgaBlue  = base_b;
        end
    end

endmodule
