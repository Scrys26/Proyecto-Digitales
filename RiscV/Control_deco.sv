`timescale 1ns/1ps
module control_deco #(parameter WIDTH=32, parameter INST_SIZE = 32) (
  input  logic  [WIDTH-1:0] instr,
  input  logic              comparison,
  output logic [1:0]        if_mux_sel,   // 0: pc+4, 1: J/BR, 2: JALR
  output logic              ex_mux_sel,   // 0: rs2, 1: imm
  output logic [1:0]        wb_mux_sel,   // 0: ALU, 1: MEM, 2: PC+4, 3: PC+IMM
  output logic              reg_file_rd,  // no usado
  output logic              reg_file_wr,
  output logic              mem_read,
  output logic              mem_write,
  output logic              one_byte,
  output logic              two_bytes,
  output logic              four_bytes
);
  localparam ALI_OP    = 7'b0010011;
  localparam AL_OP     = 7'b0110011;
  localparam MEM_WR_OP = 7'b0100011;
  localparam MEM_RD_OP = 7'b0000011;
  localparam BR_OP     = 7'b1100011;
  localparam JALR      = 7'b1100111;
  localparam JAL       = 7'b1101111;
  localparam LUI       = 7'b0110111;
  localparam AUIPC     = 7'b0010111;

  logic [6:0] opcode;  logic [2:0] func3;
  assign opcode = instr[6:0];
  assign func3  = instr[14:12];

  always_comb begin
    if_mux_sel   = 2'd0;  ex_mux_sel = 1'b0;  wb_mux_sel = 2'd0;
    reg_file_rd  = 1'b0;  reg_file_wr = 1'b0;
    mem_read     = 1'b0;  mem_write   = 1'b0;
    one_byte     = 1'b0;  two_bytes   = 1'b0;  four_bytes = 1'b0;

    unique case (opcode)
      AL_OP:    begin ex_mux_sel=0; reg_file_wr=1; wb_mux_sel=2'd0; end
      ALI_OP:   begin ex_mux_sel=1; reg_file_wr=1; wb_mux_sel=2'd0; end
      MEM_RD_OP:begin ex_mux_sel=1; reg_file_wr=1; mem_read=1; wb_mux_sel=2'd1;
                       unique case(func3)
                         3'b000,3'b100: one_byte=1;
                         3'b001,3'b101: two_bytes=1;
                         default:       four_bytes=1;
                       endcase
                 end
      MEM_WR_OP:begin ex_mux_sel=1; mem_write=1;
                       unique case(func3)
                         3'b000: one_byte=1;
                         3'b001: two_bytes=1;
                         default: four_bytes=1;
                       endcase
                 end
      BR_OP:    begin if_mux_sel = (comparison) ? 2'd1 : 2'd0; end
      JAL:      begin if_mux_sel=2'd1; reg_file_wr=1; wb_mux_sel=2'd2; end
      JALR:     begin if_mux_sel=2'd2; reg_file_wr=1; wb_mux_sel=2'd2; ex_mux_sel=1; end
      LUI:      begin ex_mux_sel=1; reg_file_wr=1; wb_mux_sel=2'd0; end   // <- ALU (inmediato)
      AUIPC:    begin ex_mux_sel=1; reg_file_wr=1; wb_mux_sel=2'd3; end   // <- PC+IMM
      default:  ;
    endcase
  end
endmodule
