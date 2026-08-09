module video_board_10x10 (
    input  logic        clk,
    input  logic        reset,
    input  logic        p_tick,
    input  logic        video_on,
    input  logic [9:0]  pixel_x,
    input  logic [9:0]  pixel_y,
    input  logic [99:0] cells,       // lo dejamos, pero no pintaremos celdas
    output logic [3:0]  vga_r,
    output logic [3:0]  vga_g,
    output logic [3:0]  vga_b
);
    localparam int CELL_W = 64;
    localparam int CELL_H = 48;

    // Columna y fila
    logic [3:0] col, row;
    assign col = pixel_x[9:6];             // 0..9
    assign row = pixel_y / CELL_H;         // 0..9

    // y % 48 = y - row*(32+16)
    logic [9:0] y_mod48;
    assign y_mod48 = pixel_y - {row,5'b0} - {row,4'b0};

    // Grid en negro: lneas en mltiplos de 64 (x) y 48 (y)
    logic grid_on;
    assign grid_on = (pixel_x[5:0] == 6'd0) || (y_mod48 == 10'd0);

    // Colores
    // Fondo BLANCO
    localparam logic [3:0] R_BG = 4'hF, G_BG = 4'hF, B_BG = 4'hF;
    // Grid NEGRO
    localparam logic [3:0] R_GRID = 4'h0, G_GRID = 4'h0, B_GRID = 4'h0;

    // (Opcional) si en el futuro quieres celdas activas, define aqu sus colores.
    // Por ahora, las ignoramos para que no se dibujen.
    // logic cell_on = cells[row*10 + col];

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            vga_r <= '0; vga_g <= '0; vga_b <= '0;
        end else if (p_tick) begin
            if (video_on) begin
                if (grid_on) begin
                    // Grid negro sobre fondo blanco
                    vga_r <= R_GRID; vga_g <= G_GRID; vga_b <= B_GRID;
                end else begin
                    // Fondo blanco
                    vga_r <= R_BG; vga_g <= G_BG; vga_b <= B_BG;
                end
            end else begin
                // Fuera de ventana visible: negro (o si prefieres, tambin blanco)
                vga_r <= 4'h0; vga_g <= 4'h0; vga_b <= 4'h0;
            end
        end
    end
endmodule
