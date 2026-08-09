`timescale 1ns/1ps
module inst_mem #(parameter WIDTH=32, parameter DEPTH=8) (
`ifdef MULTICYCLE
  input  logic             clk,
`endif
  input  logic             rst,          // no borra la ROM; solo por compatibilidad
  input  logic [WIDTH-1:0] data_in,      // ignorado (ROM)
  input  logic [DEPTH-1:0] addr,         // byte address (usamos [DEPTH-1:2])
  input  logic             wr,           // ignorado (ROM)
  input  logic             rd,
  output logic [WIDTH-1:0] data_out
);
  // Índice por palabra (32 bits = 4 bytes)
  localparam WDEPTH = (DEPTH>=2)?(DEPTH-2):1;
  localparam WORDS  = (1<<WDEPTH);

  // Fuerza inferencia a memoria de bloque si aplica
  (* rom_style="block", ram_style="block" *)
  logic [WIDTH-1:0] memory [0:WORDS-1];

  // Inicialización (sintetizable con Vivado)
  integer i;
  initial begin
    for (i=0; i<WORDS; i++) memory[i] = 32'h00000013; // NOP
    // Usa SIEMPRE el mismo nombre en hardware (agrega program.mem al proyecto)
    $readmemh("program.mem", memory);
  end

  wire [WDEPTH-1:0] word_idx = addr[DEPTH-1:2];

`ifdef MULTICYCLE
  // Lectura sincrónica (recomendada para BRAM)
  always_ff @(posedge clk) begin
    if (rd) data_out <= memory[word_idx];
  end
`else
  // Lectura combinacional (válida y simple si no tienes clk en esta instancia)
  always_comb begin
    data_out = rd ? memory[word_idx] : '0;
  end
`endif

endmodule
