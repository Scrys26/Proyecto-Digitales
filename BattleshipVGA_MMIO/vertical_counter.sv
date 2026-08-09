`timescale 1ns/1ps
module vertical_counter(
    input  logic       clk_25MHz,
    input  logic       enable_V_Counter,
    output logic [15:0] V_Count_Value = 16'd0
);
    always_ff @(posedge clk_25MHz) begin
        if (enable_V_Counter) begin
            if (V_Count_Value <= 16'd524)
                V_Count_Value <= V_Count_Value + 16'd1;
            else
                V_Count_Value <= 16'd0; // reset
        end
    end
endmodule
