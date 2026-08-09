// ============================================================================
// mmio_reg.sv
// Registro MMIO genÃ©rico con soporte para:
//  - RESET_VALUE: valor tras reset
//  - RW1C_MASK  : bits "write-1-to-clear"
//  - RO_MASK    : bits de solo lectura (provenientes de ro_bits_i)
// Bus simple: sel_i + we_i (palabra completa, alineada a 32 bits).
// ============================================================================
module mmio_reg #(
  parameter logic [31:0] RESET_VALUE = 32'h0000_0000,
  parameter logic [31:0] RW1C_MASK   = 32'h0000_0000, // write-1-to-clear
  parameter logic [31:0] RO_MASK     = 32'h0000_0000  // bits RO (salen de ro_bits_i)
)(
  input  logic        clk,
  input  logic        rst,

  // Bus local
  input  logic        sel_i,      // este registro estÃ¡ siendo accedido
  input  logic        we_i,       // escritura (palabra completa)
  input  logic [31:0] wdata_i,    // dato escrito por la CPU
  output logic [31:0] rdata_o,    // dato leÃ­do

  // Entradas HW
  input  logic [31:0] set_bits_i, // eventos HW que ponen bits a '1'
  input  logic [31:0] ro_bits_i,  // valor de bits de solo lectura

  output logic [31:0] q           // valor interno del registro
);

  // Escritura habilitada
  wire wr_en = sel_i & we_i;

  // 1) Aplicar write-1-to-clear sobre el valor actual q
  wire [31:0] after_rw1c =
    wr_en ? (q & ~(wdata_i & RW1C_MASK)) : q;

  // 2) Escritura RW sobre bits que NO son RO
  wire [31:0] wr_mask = ~RO_MASK;

  wire [31:0] after_rw =
    wr_en
      ? ((after_rw1c & ~wr_mask) | (wdata_i & wr_mask))
      :  after_rw1c;

  // 3) Eventos HW (set_bits_i) tienen prioridad
  wire [31:0] next_q = after_rw | set_bits_i;

  // Registro
  always_ff @(posedge clk or posedge rst) begin
    if (rst) q <= RESET_VALUE;
    else     q <= next_q;
  end

  // Lectura: bits RW salen de q, bits RO de ro_bits_i
  always_comb begin
    rdata_o = (q & ~RO_MASK) | (ro_bits_i & RO_MASK);
  end

endmodule
