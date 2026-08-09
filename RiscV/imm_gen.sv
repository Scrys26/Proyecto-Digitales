module imm_gen #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0] instr,
  output logic [WIDTH-1:0] data_out
);
  localparam ALI_OP    = 7'b0010011;
  localparam MEM_WR_OP = 7'b0100011;
  localparam MEM_RD_OP = 7'b0000011;
  localparam BR_OP     = 7'b1100011;
  localparam JALR      = 7'b1100111;
  localparam JAL       = 7'b1101111;
  localparam LUI       = 7'b0110111;
  localparam AUIPC     = 7'b0010111;

  logic [6:0] opcode;
  logic [2:0] func3;
  assign opcode = instr[6:0];
  assign func3  = instr[14:12];

  always_comb begin
    unique case (opcode)
      ALI_OP: begin
        // slli/srli/srai usan shamt (5 bits) sin sign-extend
        if (func3 == 3'b001 || func3 == 3'b101)
          data_out = {27'b0, instr[24:20]};
        else
          data_out = {{20{instr[31]}}, instr[31:20]};
      end
      MEM_WR_OP: data_out = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S
      MEM_RD_OP: data_out = {{20{instr[31]}}, instr[31:20]};              // I
      BR_OP:     data_out = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}; // B
      JALR:      data_out = {{20{instr[31]}}, instr[31:20]};              // I
      JAL:       data_out = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}; // J
      LUI:       data_out = {instr[31:12], 12'b0};                        // U
      AUIPC:     data_out = {instr[31:12], 12'b0};                        // U
      default:   data_out = '0;
    endcase
  end
endmodule
