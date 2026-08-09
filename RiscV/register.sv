//Register: Simple parameterized register

module register #(parameter WIDTH=32) (
	
  input logic			   clk,
  input logic              rst,
  input logic  [WIDTH-1:0] data_in,
  input logic              wr,
  
  output logic [WIDTH-1:0] data_out

);
  
  always_ff @(posedge clk) begin
    if      (rst) data_out <= 0;
    else if (wr)  data_out <= data_in;
    else          data_out <= data_out;
  end
  
endmodule