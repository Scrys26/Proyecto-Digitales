// Capa de estado + pintado por celda + CURSOR (marco).
module board_logic #(
    parameter int CELL_SIZE   = 32,
    parameter int CURSOR_THK  = 2,        // grosor del marco (px)
    parameter logic [3:0] CUR_R = 4'hF,   // color cursor
                              CUR_G = 4'h4,
                              CUR_B = 4'hF
)(
    input  logic        clk,
    input  logic        rst,          // sync reset

    // Geometría/pixeles desde Tablero
    input  logic        in_board,
    input  logic [9:0]  x_rel,
    input  logic [9:0]  y_rel,
    input  logic        on_grid,      // líneas (marco + internas)
    input  logic        text_on,      // rótulos

    // Puerto de actualización por celda
    input  logic        wr_en,
    input  logic  [3:0] wr_col,       // 0..9
    input  logic  [3:0] wr_row,       // 0..9
    input  logic  [1:0] wr_state,     // 00 vacío, 01 barco, 10 fallo, 11 acierto

    // Cursor (posición actual)
    input  logic        cur_en,       // habilita dibujar el cursor
    input  logic  [3:0] cur_col,      // 0..9
    input  logic  [3:0] cur_row,      // 0..9

    // Salidas: relleno de celda (acierto/fallo/barco) y cursor
    output logic  [3:0] pix_r,
    output logic  [3:0] pix_g,
    output logic  [3:0] pix_b,
    output logic        cell_painted,

    output logic  [3:0] cur_r,
    output logic  [3:0] cur_g,
    output logic  [3:0] cur_b,
    output logic        cursor_on
);

    // ------------------- Memoria de estado 10x10 -------------------
    // Convención:
    //   00 = vacío
    //   01 = barco (local o remoto)
    //   10 = fallo (agua)
    //   11 = acierto (impacto)
    logic [1:0] cell_state [0:9][0:9];

    integer i, j;
    always_ff @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 10; i++) begin
                for (j = 0; j < 10; j++) begin
                    cell_state[i][j] <= 2'b00;
                end
            end
        end else if (wr_en) begin
            if (wr_row < 10 && wr_col < 10) begin
                // Estado actual de la celda
                logic [1:0] st_old;
                st_old = cell_state[wr_row][wr_col];

                // Si ya había BARCO (01) y ahora la CPU escribe MISS (10),
                // ignoramos el MISS y dejamos el barco gris.
                if (st_old == 2'b01 && wr_state == 2'b10) begin
                    cell_state[wr_row][wr_col] <= 2'b01;  // mantener barco
                end else begin
                    // En cualquier otro caso, aceptamos la escritura normal
                    cell_state[wr_row][wr_col] <= wr_state;
                end
            end
        end
    end


    // ------------------- Decodificación de la celda del píxel -------------------
    logic [3:0] col_idx = x_rel[9:5]; // x_rel / 32
    logic [3:0] row_idx = y_rel[9:5]; // y_rel / 32

    logic [4:0] lx = x_rel[4:0];      // 0..31 dentro de celda
    logic [4:0] ly = y_rel[4:0];      // 0..31 dentro de celda

    // No dibujar sobre el grid (borde de 1 px)
    logic inside_cell_interior = (lx != 5'd0) && (ly != 5'd0);

    // Estado de la celda actual
    logic [1:0] st_cur;
    always_comb begin
        if (in_board && col_idx < 10 && row_idx < 10)
            st_cur = cell_state[row_idx][col_idx];
        else
            st_cur = 2'b00;
    end

    // ------------------- Colores -------------------
    localparam logic [3:0] R_RED   = 4'hF, G_RED   = 4'h0, B_RED   = 4'h0;
    localparam logic [3:0] R_BLUE  = 4'h0, G_BLUE  = 4'h0, B_BLUE  = 4'hF;

    // Barco (mismo color para local/remoto)
    localparam logic [3:0] R_SHIP  = 4'h8,
                           G_SHIP  = 4'h8,
                           B_SHIP  = 4'h8;

    always_comb begin
        cell_painted = 1'b0;
        pix_r = 4'h0; pix_g = 4'h0; pix_b = 4'h0;

        if (in_board && inside_cell_interior && !on_grid && !text_on) begin
            unique case (st_cur)
                2'b01: begin // barco
                    cell_painted = 1'b1;
                    pix_r = R_SHIP;
                    pix_g = G_SHIP;
                    pix_b = B_SHIP;
                end
                2'b10: begin // fallo (agua)
                    cell_painted = 1'b1;
                    pix_r = R_BLUE;
                    pix_g = G_BLUE;
                    pix_b = B_BLUE;
                end
                2'b11: begin // acierto
                    cell_painted = 1'b1;
                    pix_r = R_RED;
                    pix_g = G_RED;
                    pix_b = B_RED;
                end
                default: ;   // 00 vacío
            endcase
        end
    end

    // ------------------- CURSOR: marco dentro de la celda -------------------
    logic is_cur_cell = in_board && cur_en &&
                        (col_idx == cur_col) && (row_idx == cur_row);

    logic on_inner_border;
    always_comb begin
        // borde interno con grosor CURSOR_THK, sin tocar el pixel del grid (lx/ly==0)
        on_inner_border =
            (lx >= 5'd1 && ly >= 5'd1) &&                 // evita la línea del grid
            ( !on_grid && !text_on ) &&                   // no tocar grid/labels
            (
              (lx <  CURSOR_THK + 1) ||                   // borde izquierdo
              (ly <  CURSOR_THK + 1) ||                   // borde superior
              (lx > (5'd31 - CURSOR_THK)) ||              // borde derecho
              (ly > (5'd31 - CURSOR_THK))                 // borde inferior
            );
    end

    always_comb begin
        cursor_on = 1'b0;
        cur_r = 4'h0; cur_g = 4'h0; cur_b = 4'h0;

        if (is_cur_cell && on_inner_border) begin
            cursor_on = 1'b1;
            cur_r = CUR_R; cur_g = CUR_G; cur_b = CUR_B;
        end
    end

endmodule