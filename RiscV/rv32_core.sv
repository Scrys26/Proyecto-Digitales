`timescale 1ns/1ps
// ============================================================================
// TOP single-cycle con interfaz "académica":
//  - ProgAddress_o[31:0] : PC (dirección de programa)
//  - ProgIn_i   [31:0]   : instrucción desde ROM externa 
//  - DataAddress_o[31:0] : dirección efectiva hacia RAM (ALU = base+imm)
//  - DataOut_o  [31:0]   : dato a escribir (rs2 -> store)
//  - DataIn_i   [31:0]   : dato desde RAM externa 
//  - we_o                 : write enable de datos
//  - clk_i, rst_i         : reloj y reset
// ============================================================================

module uniciclo #(
  parameter WIDTH           = 32,
  parameter INST_MEM_DEPTH  = 8,   
  parameter REG_FILE_DEPTH  = 5,
  parameter DATA_MEM_DEPTH  = 16,
  parameter INST_SIZE       = 32
)(
  input  logic              clk_i,
  input  logic              rst_i,

  // ROM externa
  output logic [31:0]       ProgAddress_o,
  input  logic [31:0]       ProgIn_i,

  // RAM / MMIO externos
  output logic [31:0]       DataAddress_o,
  output logic [31:0]       DataOut_o,
  input  logic [31:0]       DataIn_i,

  // strobes/controles de datos
  output logic              we_o,         // write enable
  output logic              mem_read_o,   // read enable
  output logic              one_byte_o,
  output logic              two_bytes_o,
  output logic              four_bytes_o,

  // debug
  output logic [WIDTH-1:0]  pc_out
);

  // ---------------- Señales internas ----------------
  wire [WIDTH-1:0] pc_next, pc_4;
  wire [WIDTH-1:0] instruction = ProgIn_i;

  wire [WIDTH-1:0] rs1_data, rs2_data;
  wire [WIDTH-1:0] immediate;

  wire [WIDTH-1:0] alu_b_sel, alu_out;
  wire [WIDTH-1:0] pc_plus_imm;
  wire [WIDTH-1:0] jalr_target;

  wire [WIDTH-1:0] wb_data;

  wire [1:0]       if_mux_sel;
  wire             ex_mux_sel;
  wire [1:0]       wb_mux_sel;
  wire             comparison;
  wire             reg_file_wr;
  wire             mem_write, mem_read;

  wire             one_byte, two_bytes, four_bytes;

  // ---------------- IF: PC ----------------
  register #(.WIDTH(WIDTH)) u_pc (
    .clk     (clk_i),
    .rst     (rst_i),
    .data_in (pc_next),
    .wr      (1'b1),
    .data_out(pc_out)
  );

  adder #(.WIDTH(WIDTH)) u_pc_plus4 (
    .A   (pc_out),
    .B   (32'd4),
    .out (pc_4)
  );

  // ---------------- ID ----------------
  reg_file #(.WIDTH(WIDTH), .DEPTH(REG_FILE_DEPTH)) u_rf (
    .clk              (clk_i),
    .rst              (rst_i),
    .write_data       (wb_data),
    .write_register   (instruction[11:7]),
    .wr               (reg_file_wr),
    .read_register_1  (instruction[19:15]),
    .read_register_2  (instruction[24:20]),
    .rd               (1'b1),
    .read_data_1      (rs1_data),
    .read_data_2      (rs2_data)
  );

  imm_gen #(.WIDTH(WIDTH)) u_imm (
    .instr    (instruction),
    .data_out (immediate)
  );

  // ---------------- EX ----------------
  mux_2_1 #(.WIDTH(WIDTH)) u_ex_mux (
    .A   (rs2_data),
    .B   (immediate),
    .sel (ex_mux_sel),
    .out (alu_b_sel)
  );

  alu #(.WIDTH(WIDTH)) u_alu (
    .data_in_1  (rs1_data),
    .data_in_2  (alu_b_sel),
    .func3      (instruction[14:12]),
    .func7      (instruction[31:25]),
    .opcode     (instruction[6:0]),
    .data_out   (alu_out),
    .zero       (/*unused*/),
    .comparison (comparison)
  );

  adder #(.WIDTH(WIDTH)) u_pc_plus_imm (
    .A   (pc_out),
    .B   (immediate),
    .out (pc_plus_imm)
  );

  assign jalr_target = alu_out & ~32'd1;

  // ---------------- WB (DataIn_i viene de RAM/MMIO externos) ----------------
  mux_4_1 #(.WIDTH(WIDTH)) u_wb_mux (
    .A   (alu_out),
    .B   (DataIn_i),   // <--- antes era mem_data_out interno
    .C   (pc_4),
    .D   (pc_plus_imm),
    .sel (wb_mux_sel),
    .out (wb_data)
  );

  // ---------------- CONTROL ----------------
  control_deco #(.INST_SIZE(INST_SIZE)) u_ctrl (
    .instr       (instruction),
    .comparison  (comparison),
    .if_mux_sel  (if_mux_sel),
    .ex_mux_sel  (ex_mux_sel),
    .wb_mux_sel  (wb_mux_sel),
    .reg_file_rd (/*unused*/),
    .reg_file_wr (reg_file_wr),
    .mem_read    (mem_read),
    .mem_write   (mem_write),
    .one_byte    (one_byte),
    .two_bytes   (two_bytes),
    .four_bytes  (four_bytes)
  );

  // ---------------- NEXT PC ----------------
  mux_4_1 #(.WIDTH(WIDTH)) u_if_mux (
    .A   (pc_4),
    .B   (pc_plus_imm),
    .C   (jalr_target),
    .D   (pc_4),
    .sel (if_mux_sel),
    .out (pc_next)
  );

  // ---------------- Mapeo de puertos externos ----------------
  assign ProgAddress_o = pc_out;     // dirección de programa (PC)

  assign DataAddress_o = alu_out;    // dirección efectiva (RAM/MMIO)
  assign DataOut_o     = rs2_data;   // dato a escribir (stores)

  assign we_o          = mem_write;  // write enable externo
  assign mem_read_o    = mem_read;   // read enable externo

  assign one_byte_o    = one_byte;
  assign two_bytes_o   = two_bytes;
  assign four_bytes_o  = four_bytes;

endmodule
