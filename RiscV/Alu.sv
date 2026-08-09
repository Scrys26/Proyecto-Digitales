module alu #(parameter WIDTH=32) (
  input  logic  [WIDTH-1:0] data_in_1,
  input  logic  [WIDTH-1:0] data_in_2,
  input  logic  [2:0]       func3,
  input  logic  [6:0]       func7,
  input  logic  [6:0]       opcode,
  output logic [WIDTH-1:0]  data_out,
  output logic              zero,
  output logic              comparison
);
  localparam ALI_OP    = 7'b0010011;
  localparam AL_OP     = 7'b0110011;
  localparam MEM_WR_OP = 7'b0100011;
  localparam MEM_RD_OP = 7'b0000011;
  localparam BR_OP     = 7'b1100011;
  localparam JALR_OP   = 7'b1100111;
  localparam LUI_OP    = 7'b0110111;
  localparam AUIPC_OP  = 7'b0010111;

  logic [4:0] shamt;
  assign shamt = data_in_2[4:0];

  always_comb begin
    data_out   = '0;
    comparison = 1'b0;

    unique case (opcode)
      ALI_OP: begin
        unique case (func3)
          3'b000: data_out = $signed(data_in_1) + $signed(data_in_2); // addi
          3'b001: data_out = data_in_1 << shamt;                      // slli
          3'b010: data_out = ($signed(data_in_1) <  $signed(data_in_2)) ? 32'd1 : 32'd0; // slti
          3'b011: data_out = ( data_in_1       <   data_in_2      ) ? 32'd1 : 32'd0;     // sltiu
          3'b100: data_out = data_in_1 ^ data_in_2;                   // xori
          3'b101: data_out = (func7 == 7'b0100000) ? ($signed(data_in_1) >>> shamt)      // srai
                                                     : (data_in_1 >> shamt);             // srli
          3'b110: data_out = data_in_1 | data_in_2;                   // ori
          3'b111: data_out = data_in_1 & data_in_2;                   // andi
        endcase
      end

      AL_OP: begin
        unique case (func3)
          3'b000: data_out = (func7 == 7'b0100000) ? ($signed(data_in_1) - $signed(data_in_2)) // sub
                                                    : ($signed(data_in_1) + $signed(data_in_2)); // add
          3'b001: data_out = data_in_1 << shamt;                    // sll
          3'b010: data_out = ($signed(data_in_1) <  $signed(data_in_2)) ? 32'd1 : 32'd0; // slt
          3'b011: data_out = ( data_in_1       <   data_in_2      ) ? 32'd1 : 32'd0;     // sltu
          3'b100: data_out = data_in_1 ^ data_in_2;                 // xor
          3'b101: data_out = (func7 == 7'b0100000) ? ($signed(data_in_1) >>> shamt)      // sra
                                                    : (data_in_1 >> shamt);              // srl
          3'b110: data_out = data_in_1 | data_in_2;                 // or
          3'b111: data_out = data_in_1 & data_in_2;                 // and
        endcase
      end

      MEM_WR_OP,
      MEM_RD_OP,
      JALR_OP,
      AUIPC_OP: data_out = $signed(data_in_1) + $signed(data_in_2); // direcciones/base+offset

      LUI_OP:   data_out = data_in_2; // lui

      BR_OP: begin
        unique case (func3)
          3'b000: comparison = ($signed(data_in_1) == $signed(data_in_2)); // beq
          3'b001: comparison = ($signed(data_in_1) != $signed(data_in_2)); // bne
          3'b100: comparison = ($signed(data_in_1) <  $signed(data_in_2)); // blt
          3'b101: comparison = ($signed(data_in_1) >= $signed(data_in_2)); // bge
          3'b110: comparison = ( data_in_1        <   data_in_2       );   // bltu
          3'b111: comparison = ( data_in_1        >=  data_in_2       );   // bgeu
          default: comparison = 1'b0;
        endcase
      end

      default: begin
        data_out   = '0;
        comparison = 1'b0;
      end
    endcase
  end

  assign zero = (data_out == '0);

endmodule
