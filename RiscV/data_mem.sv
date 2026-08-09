`timescale 1ns/1ps
module data_mem #(
  parameter WIDTH = 32,
  parameter DEPTH = 16            // bits de dirección por BYTE -> 2^DEPTH bytes totales
)(
  input  logic             clk,
  input  logic             rst,          // (no borra la RAM en síntesis)
  input  logic [WIDTH-1:0] data_in,
  input  logic [DEPTH-1:0] addr,         // byte address
  input  logic             wr,
  input  logic             rd,
  input  logic             one_byte,
  input  logic             two_bytes,
  input  logic             four_bytes,
  output logic [WIDTH-1:0] data_out
);
  // ======= Organización en PALABRAS de 32b =======
  localparam WDEPTH = (DEPTH>=2) ? (DEPTH-2) : 1;  // bits para indexar palabras
  localparam WORDS  = (1<<WDEPTH);

  // BRAM de 32b con byte-enables
  (* ram_style="block" *) logic [31:0] mem [0:WORDS-1];

  // Particionado de dirección
  wire [WDEPTH-1:0] widx   = addr[DEPTH-1:2];  // índice de palabra
  wire [1:0]        byteOfs= addr[1:0];        // desplazamiento dentro de la palabra

  // ======= ESCRITURA con byte-enables =======
  logic [3:0] be;      // byte enables
  logic [31:0] wdata;  // data alineada al byteOfs para el caso byte/halfword

  always_comb begin
    be    = 4'b0000;
    wdata = 32'h0000_0000;

    unique case (1'b1)
      four_bytes: begin
        be    = 4'b1111;
        wdata = data_in;
      end
      two_bytes: begin
        // RISC-V exige alineación a 16 bits; igual manejamos cualquier ofs
        unique case (byteOfs)
          2'b00: begin be=4'b0011; wdata[15:0] = data_in[15:0]; end
          2'b01: begin be=4'b0110; wdata[23:8] = data_in[15:0]; end
          2'b10: begin be=4'b1100; wdata[31:16]= data_in[15:0]; end
          default: begin be=4'b0000; end // (2'b11) evitar write cruzado
        endcase
      end
      one_byte: begin
        unique case (byteOfs)
          2'b00: begin be=4'b0001; wdata[7:0]   = data_in[7:0];  end
          2'b01: begin be=4'b0010; wdata[15:8]  = data_in[7:0];  end
          2'b10: begin be=4'b0100; wdata[23:16] = data_in[7:0];  end
          2'b11: begin be=4'b1000; wdata[31:24] = data_in[7:0];  end
        endcase
      end
      default: begin be=4'b0000; end
    endcase
  end

  always_ff @(posedge clk) begin
    if (wr) begin
      if (be[0]) mem[widx][7:0]   <= wdata[7:0];
      if (be[1]) mem[widx][15:8]  <= wdata[15:8];
      if (be[2]) mem[widx][23:16] <= wdata[23:16];
      if (be[3]) mem[widx][31:24] <= wdata[31:24];
    end
  end

  // ======= LECTURA SINCRÓNICA (1 puerto) =======
  logic [31:0] rword;
  logic [1:0]  r_ofs;
  logic        rd_q;

  always_ff @(posedge clk) begin
    if (rd) begin
      rword <= mem[widx];   // 1 sola lectura al BRAM -> inferible
      r_ofs <= byteOfs;
    end
    rd_q <= rd;
  end

  // Selección/masking posterior a la lectura
  always_ff @(posedge clk) begin
    if (rd_q) begin
      if (four_bytes) begin
        // para LW alineado (ofs=00) rword está ok; si llegara desalineado, se rota
        unique case (r_ofs)
          2'b00: data_out <= rword;
          2'b01: data_out <= {rword[23:0], 8'h00};
          2'b10: data_out <= {rword[15:0], 16'h0000};
          2'b11: data_out <= {rword[7:0],  24'h000000};
        endcase
      end else if (two_bytes) begin
        unique case (r_ofs)
          2'b00: data_out <= {16'h0000, rword[15:0]};
          2'b01: data_out <= {16'h0000, rword[23:8]};
          2'b10: data_out <= {16'h0000, rword[31:16]};
          default: data_out <= 32'h0000_0000; // (2'b11) cruzaría palabra
        endcase
      end else if (one_byte) begin
        unique case (r_ofs)
          2'b00: data_out <= {24'h0, rword[7:0]};
          2'b01: data_out <= {24'h0, rword[15:8]};
          2'b10: data_out <= {24'h0, rword[23:16]};
          2'b11: data_out <= {24'h0, rword[31:24]};
        endcase
      end else begin
        data_out <= 32'h0000_0000;
      end
    end else begin
      data_out <= 32'h0000_0000;
    end
  end
endmodule
