`timescale 1ns/1ps
module clock_divider #(
    parameter int div_value = 1
) (
    input  logic clk,
    output logic divide_clk = 1'b0
);
    integer counter_value = 0;

    always_ff @(posedge clk) begin
        if (counter_value == div_value) begin
            counter_value <= 0;
            divide_clk    <= ~divide_clk; // mismo comportamiento lógico
        end else begin
            counter_value <= counter_value + 1;
        end
    end
endmodule
