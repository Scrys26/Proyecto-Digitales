// ============================================================================
// mando_ja_mmio.sv
// ----------------
// "Mando" de 7 botones conectado a los pines JA (o donde tÃº quieras) que
// genera las seÃ±ales MANDO_DAT y MANDO_STA para el SoC.
//
// - MANDO_DAT (0x0001_0000):
//       [7:4] = fila (0..9)
//       [3:0] = columna (0..9)
//   El resto de bits se dejan en 0.
//
// - MANDO_STA (0x0001_0004):
//       bit0 = BTN_CONFIRM
//       bit1 = BTN_CANCEL
//       bit2 = BTN_ROTATE
//   (coincide con tus .eqv del ensamblador).
//
// Los 4 botones de direcciÃ³n SOLO afectan la posiciÃ³n (fila, col).
// Los 3 botones de acciÃ³n se exportan como niveles; el ensamblador hace
// la detecciÃ³n de flanco usando MSTA_PREV.
// ============================================================================

`timescale 1ns/1ps

module mando_ja_mmio (
    input  logic clk,
    input  logic rst,

    // Botones de direcciÃ³n (desde JA o botones de la FPGA)
    input  logic btn_up,
    input  logic btn_down,
    input  logic btn_left,
    input  logic btn_right,

    // Botones de acciÃ³n (mapeados a MANDO_STA)
    input  logic btn_confirm,   // BTN_CONFIRM (bit0)
    input  logic btn_cancel,    // BTN_CANCEL  (bit1)
    input  logic btn_rotate,    // BTN_ROTATE  (bit2)

    // Salidas hacia el SoC (soc_mmio_block)
    output logic [31:0] mando_dat_o,
    output logic [31:0] mando_sta_o
);

    // ------------------------------------------------------------------------
    // 1) Registro de fila/columna (cursor lÃ³gico 10x10)
    // ------------------------------------------------------------------------
    logic [3:0] row;  // 0..9
    logic [3:0] col;  // 0..9

    // Registros para detectar flanco de subida en las direcciones
    logic up_q, down_q, left_q, right_q;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            row     <= 4'd0;
            col     <= 4'd0;
            up_q    <= 1'b0;
            down_q  <= 1'b0;
            left_q  <= 1'b0;
            right_q <= 1'b0;
        end else begin
            // Muestra estados anteriores de los botones de direcciÃ³n
            up_q    <= btn_up;
            down_q  <= btn_down;
            left_q  <= btn_left;
            right_q <= btn_right;

            // Flancos de subida
            if (btn_up & ~up_q) begin
                // mover hacia "arriba" si no estamos ya en la fila 0
                if (row > 4'd0)
                    row <= row - 4'd1;
            end

            if (btn_down & ~down_q) begin
                // mover hacia "abajo" si no estamos en la fila 9
                if (row < 4'd9)
                    row <= row + 4'd1;
            end

            if (btn_left & ~left_q) begin
                // mover hacia la izquierda si no estamos en la col 0
                if (col > 4'd0)
                    col <= col - 4'd1;
            end

            if (btn_right & ~right_q) begin
                // mover hacia la derecha si no estamos en la col 9
                if (col < 4'd9)
                    col <= col + 4'd1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // 2) Empaquetar MANDO_DAT: [7:4]=row, [3:0]=col (resto 0)
    // ------------------------------------------------------------------------
    always_comb begin
        mando_dat_o       = 32'h0000_0000;
        mando_dat_o[7:4]  = row;
        mando_dat_o[3:0]  = col;
    end

    // ------------------------------------------------------------------------
    // 3) Empaquetar MANDO_STA: bits de acciÃ³n
    //     bit0 = CONFIRM, bit1 = CANCEL, bit2 = ROTATE
    //     El ensamblador detecta flancos comparando con MSTA_PREV en RAM.
    // ------------------------------------------------------------------------
    always_comb begin
        mando_sta_o       = 32'h0000_0000;
        mando_sta_o[0]    = btn_confirm;
        mando_sta_o[1]    = btn_cancel;
        mando_sta_o[2]    = btn_rotate;
        // el resto de bits quedan en 0 (por ahora sin uso)
    end

endmodule
