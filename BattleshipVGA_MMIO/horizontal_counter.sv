`timescale 1ns/1ps
module horizontal_counter  (
    input  logic       clk_25MHz,
    output logic       enable_V_Counter = 1'b0,
    output logic [15:0] H_Count_Value   = 16'd0
);
    always_ff @(posedge clk_25MHz) begin
        if (H_Count_Value < 16'd800) begin
            H_Count_Value    <= H_Count_Value + 16'd1;
            enable_V_Counter <= 1'b0;
        end else begin
            H_Count_Value    <= 16'd0;
            enable_V_Counter <= 1'b1;
        end
    end
endmodule
