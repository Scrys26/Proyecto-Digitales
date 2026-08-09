// ===================== TOP 640x480: tablero centrado + rotulos =====================
module Tablero (
    input  logic       clk,
    output logic       Hsync,
    output logic       Vsync,
    output logic [3:0] vgaRed,
    output logic [3:0] vgaGreen,
    output logic [3:0] vgaBlue
);
    // -------------------- Modulos --------------------
    logic        clk_25M;
    logic        enable_V_Counter;
    logic [15:0] H_Count_Value;
    logic [15:0] V_Count_Value;

    clock_divider       VGA_Clock_gen (clk, clk_25M);
    horizontal_counter  VGA_Horiz     (clk_25M, enable_V_Counter, H_Count_Value);
    vertical_counter    VGA_Verti     (clk_25M, enable_V_Counter, V_Count_Value);

    // HS/VS 
    assign Hsync = (H_Count_Value < 16'd96);
    assign Vsync = (V_Count_Value < 16'd2);

    // -------------------- Ventana visible 640x480 --------------------
    localparam int H_VIS_START = 144;
    localparam int H_VIS_END   = 783;  // inclusive
    localparam int V_VIS_START = 35;
    localparam int V_VIS_END   = 514;  // inclusive

    logic in_vis = (H_Count_Value >= H_VIS_START && H_Count_Value <= H_VIS_END &&
                    V_Count_Value >= V_VIS_START && V_Count_Value <= V_VIS_END);

    // Coordenadas relativas visibles (0..639 / 0..479)
    logic [9:0] x_vis = in_vis ? (H_Count_Value - H_VIS_START) : 10'd0;
    logic [9:0] y_vis = in_vis ? (V_Count_Value - V_VIS_START) : 10'd0;

    // -------------------- Tablero 10�10 centrado (320x320) --------------------
    localparam int CELLS      = 10;
    localparam int CELL_SIZE  = 32;                    // 10*32 = 320
    localparam int BOARD_W    = CELLS * CELL_SIZE;     // 320
    localparam int BOARD_H    = CELLS * CELL_SIZE;     // 320
    localparam int X0         = (640 - BOARD_W)/2;     // 160
    localparam int Y0         = (480 - BOARD_H)/2;     // 80

    localparam int FRAME_THK  = 2;   // marco externo
    localparam int GRID_THK   = 1;   // lineas internas (1 px)

    logic in_board =
        in_vis &&
        (x_vis >= X0) && (x_vis < X0 + BOARD_W) &&
        (y_vis >= Y0) && (y_vis < Y0 + BOARD_H);

    logic [9:0] x_rel = x_vis - X0; // validos cuando in_board=1
    logic [9:0] y_rel = y_vis - Y0;

    // a) Marco (2 px)
    logic on_frame =
        in_board && (
            (x_rel < FRAME_THK) ||
            ((BOARD_W-1) - x_rel < FRAME_THK) ||
            (y_rel < FRAME_THK) ||
            ((BOARD_H-1) - y_rel < FRAME_THK)
        );

    // b) Lineas internas cada 32 px (usar bits: 32 == 2^5)
    logic on_vline = in_board && (x_rel[4:0] == 5'd0) && (x_rel != 10'd0) && (x_rel != BOARD_W-1);
    logic on_hline = in_board && (y_rel[4:0] == 5'd0) && (y_rel != 10'd0) && (y_rel != BOARD_H-1);
    logic on_grid  = on_frame | on_vline | on_hline;

    // -------------------- Texto: A-J arriba, 1-10 a la izquierda --------------------
    localparam int TEXT_W = 8;
    localparam int TEXT_H = 8;
    localparam int GAP_TOP  = 10; // separacion tablero-arriba
    localparam int GAP_LEFT = 10; // separacion tablero-izquierda

    // --- Rotulos superiores (A..J centrados en cada celda) ---
    localparam int TOP_Y0    = Y0 - GAP_TOP - TEXT_H;          // y inicial top
    localparam int TXT_PAD_X = (CELL_SIZE - TEXT_W)/2;         // 12

    logic in_top_band = in_vis && (y_vis >= TOP_Y0) && (y_vis < TOP_Y0 + TEXT_H);
    logic [3:0] col_idx   = (x_vis - X0) >> 5;                 // 0..9
    logic [9:0] x_off_col = (x_vis - X0) - {col_idx,5'b0};     // x % 32
    logic [9:0] x_glyph   = x_off_col - TXT_PAD_X;             // 0..7
    logic [9:0] y_glyph_t = y_vis - TOP_Y0;                    // 0..7
    logic in_top_slot = in_top_band && (x_vis >= X0) && (x_vis < X0 + BOARD_W) &&
                        (x_glyph < TEXT_W);

    // --- Rotulos izquierdos (1..10) ---
    localparam int LEFT_AREA_W = (2*TEXT_W + 1);               // 17 px
    localparam int LEFT_X0     = X0 - GAP_LEFT - LEFT_AREA_W;
    localparam int TXT_PAD_Y   = (CELL_SIZE - TEXT_H)/2;       // 12

    logic in_left_band = in_vis && (x_vis >= LEFT_X0) && (x_vis < LEFT_X0 + LEFT_AREA_W);
    logic [3:0] row_idx   = (y_vis - Y0) >> 5;                 // 0..9
    logic [9:0] y_off_row = (y_vis - Y0) - {row_idx,5'b0};     // y % 32
    logic [9:0] y_glyph_l = y_off_row - TXT_PAD_Y;             // 0..7
    logic [9:0] x_off_left= x_vis - LEFT_X0;                   // 0..16
    logic       slot_1    = (x_off_left >= (TEXT_W + 1));      // 2d digito
    logic [9:0] x_glyph_l = x_off_left - (slot_1 ? (TEXT_W + 1) : 0); // 0..7
    logic in_left_slot = in_left_band && (y_vis >= Y0) && (y_vis < Y0 + BOARD_H) &&
                         (y_glyph_l < TEXT_H) && (x_glyph_l < TEXT_W);

    // -------------------- Fuente 8x8 (A-J, 0-9 y ' ') --------------------
    function automatic logic [7:0] font8x8 (input logic [7:0] ch, input logic [2:0] r);
        case (ch)
        // A..J
        "A": case(r) 
        0:font8x8=8'b00111100;
        1:font8x8=8'b01000010;
        2:font8x8=8'b01000010;
        3:font8x8=8'b01111110;
        4:font8x8=8'b01000010;
        5:font8x8=8'b01000010;
        6:font8x8=8'b01000010;
        7:font8x8=8'b00000000;

         endcase
        "B": case(r)

        0:font8x8=8'b01111100;
        1:font8x8=8'b01000010;
        2:font8x8=8'b01111100;
        3:font8x8=8'b01000010;
        4:font8x8=8'b01000010;
        5:font8x8=8'b01111100;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;
        
        endcase
        "C": case(r) 
        0:font8x8=8'b00111110;
        1:font8x8=8'b01000000;
        2:font8x8=8'b01000000;
        3:font8x8=8'b01000000;
        4:font8x8=8'b01000000;
        5:font8x8=8'b00111110;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase

        "D": case(r) 
        0:font8x8=8'b01111100;
        1:font8x8=8'b01000010;
        2:font8x8=8'b01000010;
        3:font8x8=8'b01000010;
        4:font8x8=8'b01000010;
        5:font8x8=8'b01111100;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;
        endcase

        "E": case(r) 
        0:font8x8=8'b01111110;
        1:font8x8=8'b01000000;
        2:font8x8=8'b01111100;
        3:font8x8=8'b01000000;
        4:font8x8=8'b01000000;
        5:font8x8=8'b01111110;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        "F": case(r) 
        0:font8x8=8'b01111110;
        1:font8x8=8'b01000000;
        2:font8x8=8'b01111100;
        3:font8x8=8'b01000000;
        4:font8x8=8'b01000000;
        5:font8x8=8'b01000000;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        "G": case(r) 
        0:font8x8=8'b00111110;
        1:font8x8=8'b01000000;
        2:font8x8=8'b01001110;
        3:font8x8=8'b01000010;
        4:font8x8=8'b01000010;
        5:font8x8=8'b00111100;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        "H": case(r) 
        0:font8x8=8'b01000010;
        1:font8x8=8'b01000010;
        2:font8x8=8'b01111110;
        3:font8x8=8'b01000010;
        4:font8x8=8'b01000010;
        5:font8x8=8'b01000010;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        "I": case(r) 
        0:font8x8=8'b00111100;
        1:font8x8=8'b00011000;
        2:font8x8=8'b00011000;
        3:font8x8=8'b00011000;
        4:font8x8=8'b00011000;
        5:font8x8=8'b00111100;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        "J": case(r) 
        0:font8x8=8'b00011110;
        1:font8x8=8'b00000100;
        2:font8x8=8'b00000100;
        3:font8x8=8'b01000100;
        4:font8x8=8'b01000100;
        5:font8x8=8'b00111000;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        // 0..9
        "0": case(r) 
        0:font8x8=8'b00111100;
        1:font8x8=8'b01000110;
        2:font8x8=8'b01001010;
        3:font8x8=8'b01010010;
        4:font8x8=8'b01100010;
        5:font8x8=8'b00111100;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        "1": case(r) 
        0:font8x8=8'b00011000;
        1:font8x8=8'b00111000;
        2:font8x8=8'b00011000;
        3:font8x8=8'b00011000;
        4:font8x8=8'b00011000;
        5:font8x8=8'b00111100;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        "2": case(r)
         0:font8x8=8'b00111100;
         1:font8x8=8'b01000010;
         2:font8x8=8'b00000100;
         3:font8x8=8'b00011000;
         4:font8x8=8'b00100000;
         5:font8x8=8'b01111110;
         6:font8x8=8'b00000000;
         7:font8x8=8'b00000000;

         endcase
        "3": case(r) 
        0:font8x8=8'b00111100;
        1:font8x8=8'b00000010;
        2:font8x8=8'b00011100;
        3:font8x8=8'b00000010;
        4:font8x8=8'b01000010;
        5:font8x8=8'b00111100;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        "4": case(r) 
        0:font8x8=8'b00000100;
        1:font8x8=8'b00010100;
        2:font8x8=8'b00100100;
        3:font8x8=8'b01111110;
        4:font8x8=8'b00000100;
        5:font8x8=8'b00000100;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        "5": case(r) 
        0:font8x8=8'b01111110;
        1:font8x8=8'b01000000;
        2:font8x8=8'b01111100;
        3:font8x8=8'b00000010;
        4:font8x8=8'b01000010;
        5:font8x8=8'b00111100;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        "6": case(r) 
        0:font8x8=8'b00111100;
        1:font8x8=8'b01000000;
        2:font8x8=8'b01111100;
        3:font8x8=8'b01000010;
        4:font8x8=8'b01000010;
        5:font8x8=8'b00111100;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        "7": case(r) 
        0:font8x8=8'b01111110;
        1:font8x8=8'b00000010;
        2:font8x8=8'b00000100;
        3:font8x8=8'b00001000;
        4:font8x8=8'b00010000;
        5:font8x8=8'b00010000;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        "8": case(r) 
        0:font8x8=8'b00111100;
        1:font8x8=8'b01000010;
        2:font8x8=8'b00111100;
        3:font8x8=8'b01000010;
        4:font8x8=8'b01000010;
        5:font8x8=8'b00111100;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;

        endcase
        "9": case(r) 
        0:font8x8=8'b00111100;
        1:font8x8=8'b01000010;
        2:font8x8=8'b00111110;
        3:font8x8=8'b00000010;
        4:font8x8=8'b00000100;
        5:font8x8=8'b00111000;
        6:font8x8=8'b00000000;
        7:font8x8=8'b00000000;
        
        endcase
        " ": font8x8 = 8'b00000000; // espacio
        default: font8x8 = 8'b00000000;
        endcase
    endfunction

    // Selecci�n de caracteres
    logic [7:0] top_char   = ("A" + col_idx); // 0->'A', 9->'J'
    logic [3:0] row_num    = row_idx + 1;
    logic [3:0] tens       = (row_num >= 10) ? 4'd1 : 4'd0;
    logic [3:0] ones       = (row_num >= 10) ? 4'd0 : row_num;  // 10 -> '0'
    logic [7:0] left_char0 = (tens == 0) ? " " : ("0" + tens);
    logic [7:0] left_char1 = "0" + ones;

    // Bits de la fuente (bit7 = columna izquierda)
    logic [7:0] top_row_bits   = font8x8(top_char,   y_glyph_t[2:0]);
    logic [7:0] left_row_bits0 = font8x8(left_char0, y_glyph_l[2:0]);
    logic [7:0] left_row_bits1 = font8x8(left_char1, y_glyph_l[2:0]);

    // Pick de bit (MSB = columna izquierda)
    logic top_bit_on   = in_top_slot  && top_row_bits  [7 - x_glyph  [2:0]];
    logic left_bit_on0 = in_left_slot && !slot_1 && left_row_bits0 [7 - x_glyph_l[2:0]];
    logic left_bit_on1 = in_left_slot &&  slot_1 && left_row_bits1 [7 - x_glyph_l[2:0]];
    logic text_on      = top_bit_on | left_bit_on0 | left_bit_on1;

    // -------------------- Colores (4 bits por canal) --------------------
    // Fondo visible = blanco; texto y l�neas = negro; fuera de visible = negro
    assign vgaRed   = in_vis ? ( (text_on || on_grid) ? 4'h0 : 4'hF ) : 4'h0;
    assign vgaGreen = in_vis ? ( (text_on || on_grid) ? 4'h0 : 4'hF ) : 4'h0;
    assign vgaBlue  = in_vis ? ( (text_on || on_grid) ? 4'h0 : 4'hF ) : 4'h0;

endmodule
