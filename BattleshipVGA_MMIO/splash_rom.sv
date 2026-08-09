// splash_rom.sv  �" ROM de imagen 12-bit (R[11:8] G[7:4] B[3:0]) para $readmemh
module splash_rom #(
    parameter int W   = 320,
    parameter int H   = 120

) (
    input  logic        clk,       // cualquier clk; sólo lectura sync
    input  logic  [9:0] x,         // 0..W-1
    input  logic  [9:0] y,         // 0..H-1
    output logic [3:0]  r, g, b
);
    localparam int NPIX = W*H;

    // Memoria: 12-bit por pixel (0xRGB)
    logic [11:0] mem [0:NPIX-1];

    initial begin
        $readmemh("logo.mem", mem);
    end

    logic [11:0] pix;
    always_ff @(posedge clk) begin
        if (x < W && y < H)
            pix <= mem[y*W + x];
        else
            pix <= 12'h000;   // negro fuera
    end

    assign r = pix[11:8];
    assign g = pix[7:4];
    assign b = pix[3:0];
endmodule
