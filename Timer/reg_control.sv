module Registro_Control (
    input  logic        clk,
    input  logic        reset,
    input  logic        we,               // escritura
    input  logic [31:0] wdata,
    input  logic        timeout_flag_i,   

    output logic [31:0] rdata,            // lectura
    output logic        start_bit,        // bit0
    output logic        autoreload_bit    // bit1
);
    logic [31:0] reg_q;

 
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_q <= 32'd0;
        end else if (we) begin
          
            reg_q <= { wdata[31:3], reg_q[2], wdata[1:0] };
        end
    end

    always_comb begin
        rdata            = reg_q;
        rdata[2]         = timeout_flag_i; 
    end

    assign start_bit       = reg_q[0];
    assign autoreload_bit  = reg_q[1];
endmodule
