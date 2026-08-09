// ============================================================================
// remote_board_mmio.sv
// MMIO 10x10 (100 bytes) para barcos remotos (PC)
// - Dirección base: BASE_ADDR (ej. 0x0001_0200)
// - CPU accede con LB/SB a BASE_ADDR + idx  (idx = row*10 + col, 0..99)
//   0 = vacío, 1 = barco, 2 = golpeado (opcional)
// ============================================================================
module remote_board_mmio #(
    parameter logic [31:0] BASE_ADDR = 32'h0001_0200,
    parameter int          CELLS     = 100
)(
    input  logic        clk,
    input  logic        rst,

    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        we_i,
    input  logic        re_i,
    output logic [31:0] rdata_o
);
    // Mem 100 bytes
    logic [7:0] mem [0:CELLS-1];

    logic        in_range;
    logic [31:0] addr_off;
    logic [6:0]  idx;      // 0..99

    always_comb begin
        if (addr_i >= BASE_ADDR && addr_i < (BASE_ADDR + CELLS)) begin
            in_range = 1'b1;
            addr_off = addr_i - BASE_ADDR;
            idx      = addr_off[6:0];
        end else begin
            in_range = 1'b0;
            addr_off = 32'd0;
            idx      = 7'd0;
        end
    end

    integer i;
    always_ff @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < CELLS; i++) begin
                mem[i] <= 8'd0;
            end
        end else if (we_i && in_range) begin
            mem[idx] <= wdata_i[7:0];
        end
    end

    always_comb begin
        if (re_i && in_range)
            rdata_o = {24'h0, mem[idx]};
        else
            rdata_o = 32'h0000_0000;
    end

endmodule