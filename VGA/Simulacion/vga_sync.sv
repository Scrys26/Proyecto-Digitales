// Genera HS/VS (activos en BAJO), pixel_x/y, video_on y p_tick (25 MHz)
// Entrada: clk = 100 MHz (Nexys 4 / Nexys 4 DDR)
module vga_sync (
    input  logic       clk,
    input  logic       reset,
    output logic       hsync_n,     // activo en bajo
    output logic       vsync_n,     // activo en bajo
    output logic       video_on,
    output logic       p_tick,      // 25 MHz enable (clk/4)
    output logic [9:0] pixel_x,     // 0..639
    output logic [9:0] pixel_y      // 0..479
);
    // --- ÷4 para 25 MHz desde 100 MHz ---
    logic [1:0] div;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) div <= 2'b00;
        else       div <= div + 2'b01;
    end
    assign p_tick = div[1];

    // --- Parámetros de timing VGA 640x480 ---
    localparam int HD = 640, HF = 16, HB = 48, HR = 96; // total H = 800
    localparam int VD = 480, VF = 10, VB = 33, VR = 2;  // total V = 525
    localparam int HMAX = HD+HF+HB+HR-1; // 799
    localparam int VMAX = VD+VF+VB+VR-1; // 524

    logic [9:0] h_cnt, v_cnt;

    // Contadores H/V avanzan a p_tick
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            h_cnt <= '0; v_cnt <= '0;
        end else if (p_tick) begin
            if (h_cnt == HMAX) begin
                h_cnt <= 10'd0;
                v_cnt <= (v_cnt == VMAX) ? 10'd0 : (v_cnt + 10'd1);
            end else begin
                h_cnt <= h_cnt + 10'd1;
            end
        end
    end

    // Ventanas de sincronía (VGA estándar: pulso activo en BAJO)
    logic hsync_p, vsync_p; // activos en ALTO internamente
    assign hsync_p = (h_cnt >= (HD+HB)) && (h_cnt <= (HD+HB+HR-1));
    assign vsync_p = (v_cnt >= (VD+VB)) && (v_cnt <= (VD+VB+VR-1));

    // Salidas
    assign pixel_x  = h_cnt;
    assign pixel_y  = v_cnt;
    assign video_on = (h_cnt < HD) && (v_cnt < VD);
    assign hsync_n  = ~hsync_p;
    assign vsync_n  = ~vsync_p;
endmodule
