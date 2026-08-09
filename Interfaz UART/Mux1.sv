`timescale 1ns/1ps

module Mux2_1 (
    input logic [31:0] out_reg,
    input logic [31:0] out_fifo,
    input logic reg_sel_i,

    output logic [31:0] salida_o
);

    always_comb begin 

        case (reg_sel_i)
            1'b0: salida_o= out_reg;
            1'b1: salida_o= out_fifo;
        endcase
    end

endmodule