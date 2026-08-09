`timescale 1ns/1ps
module tb_vga_frame_dump;

  // ---------------- Señales base ----------------
  logic clk   = 1'b0;
  logic reset = 1'b1;

  // vga_sync
  logic       hsync_n, vsync_n, video_on, p_tick;
  logic [9:0] pixel_x, pixel_y;

  // video_board_10x10
  logic [3:0] vga_r, vga_g, vga_b;
  logic [99:0] cells;

  // Reloj 100 MHz
  always #5 clk = ~clk;

  // DUT: sincronizador VGA 640x480@60 (25 MHz enable desde 100 MHz)
  vga_sync u_sync (
    .clk     (clk),
    .reset   (reset),
    .hsync_n (hsync_n),
    .vsync_n (vsync_n),
    .video_on(video_on),
    .p_tick  (p_tick),
    .pixel_x (pixel_x),
    .pixel_y (pixel_y)
  );

  // Mapa 10x10: diagonal + fila superior
  initial begin : INIT_CELLS
    integer i;
    cells = '0;
    for (i=0; i<10; i=i+1) begin
      cells[i*10 + i] = 1'b1; // diagonal
      cells[0*10 + i] = 1'b1; // fila 0
    end
  end

  // Generador de color del tablero
  video_board_10x10 u_board (
    .clk     (clk),
    .reset   (reset),
    .p_tick  (p_tick),
    .video_on(video_on),
    .pixel_x (pixel_x),
    .pixel_y (pixel_y),
    .cells   (cells),
    .vga_r   (vga_r),
    .vga_g   (vga_g),
    .vga_b   (vga_b)
  );

  // ---------------- Volcado PPM ----------------
  integer f;
  integer x, y;
  integer r8, g8, b8;

  // Duplica nibble 4b -> 8b (0..15 -> 0..255)
  function automatic integer expand4to8(input logic [3:0] v4);
    begin
      expand4to8 = (v4 << 4) | v4;
    end
  endfunction

  // Espera un tick de píxel en una coordenada concreta (x,y)
  task automatic wait_for_pixel(input integer tx, input integer ty);
    begin
      // Avanza hasta que el sincronizador esté en ese pixel visible y en un p_tick
      // (evaluado en posedge de clk para evitar muestras "entre ciclos")
      forever begin
        @(posedge clk);
        if (p_tick && video_on && pixel_x==tx[9:0] && pixel_y==ty[9:0])
          disable wait_for_pixel;
      end
    end
  endtask

  initial begin : TB_PROC
    // Reset breve
    repeat (10) @(posedge clk);
    reset = 1'b0;

    // Espera el inicio de un frame (flanco bajo de vsync_n, luego regreso a alto)
    @(posedge clk); wait (vsync_n==1'b1);
    @(posedge clk); wait (vsync_n==1'b0);
    @(posedge clk); wait (vsync_n==1'b1);

    // Abre archivo PPM en la carpeta de trabajo de xsim
    f = $fopen("frame.ppm","w");
    if (f==0) $fatal("No se pudo abrir frame.ppm para escritura.");

    // Cabecera PPM (P3 = texto)
    $fwrite(f, "P3\n640 480\n255\n");

    // Recorre toda la ventana visible y vuelca R,G,B
    for (y=0; y<480; y=y+1) begin
      for (x=0; x<640; x=x+1) begin
        wait_for_pixel(x, y);         // sincroniza con ese pixel
        r8 = expand4to8(vga_r);
        g8 = expand4to8(vga_g);
        b8 = expand4to8(vga_b);
        $fwrite(f, "%0d %0d %0d\n", r8, g8, b8);
      end
    end

    $fclose(f);
    $display("OK: frame.ppm generado (640x480).");
    $finish;
  end

endmodule
