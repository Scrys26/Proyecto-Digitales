`timescale 1ns/1ps

module demux (
    input  logic wr_i,
    input  logic reg_sel_i,
    output logic wr_reg,
    output logic wr_fifo
);

    always_comb begin
        // valores por defecto
        wr_reg  = 0;
        wr_fifo = 0;

        case (reg_sel_i)
            1'b0: begin
                wr_reg  = wr_i;
                wr_fifo = 0;
            end
            1'b1: begin
                wr_fifo = wr_i;
                wr_reg  = 0;
            end
            default: begin
                wr_reg  = 0;
                wr_fifo = 0;
            end
        endcase
    end

endmodule
