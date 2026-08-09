`timescale 1ns/1ps
module reg_file #(parameter WIDTH=32, parameter DEPTH=5) (
  input  logic               clk,
  input  logic               rst,
  input  logic [WIDTH-1:0]   write_data,
  input  logic [DEPTH-1:0]   write_register,
  input  logic               wr,
  input  logic [DEPTH-1:0]   read_register_1,
  input  logic [DEPTH-1:0]   read_register_2,
  input  logic               rd, // ignorado
  output logic [WIDTH-1:0]   read_data_1,
  output logic [WIDTH-1:0]   read_data_2
);
  logic [WIDTH-1:0] registers [0:(1<<DEPTH)-1];
  integer i;
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (i=0;i<(1<<DEPTH);i++) registers[i] <= '0;
    end else begin
      registers[0] <= '0;
      if (wr && (write_register!='0)) begin
        registers[write_register] <= write_data;
        
      end
    end
  end
  assign read_data_1 = registers[read_register_1];
  assign read_data_2 = registers[read_register_2];
endmodule
