module Interfaz_Registros (
    input  logic        clk,
    input  logic        reset,
    input  logic  [0:0] addr_i,          // 0=control, 1=dato
    input  logic        write_i,
    input  logic [31:0] data_in,
    output logic [31:0] data_out,

    input  logic        timeout_flag_i,
    input  logic [31:0] count_value_i,
    output logic        start_bit_o,
    output logic        autoreload_bit_o,
    output logic [31:0] load_value_o
);
    logic [31:0] control_rdata, data_rdata;
    logic        we_ctrl, we_data;

    assign we_ctrl = write_i & (addr_i == 1'b0);
    assign we_data = write_i & (addr_i == 1'b1);

    Registro_Control u_ctrl (
        .clk(clk), .reset(reset),
        .we(we_ctrl), .wdata(data_in),
        .timeout_flag_i(timeout_flag_i),
        .rdata(control_rdata),
        .start_bit(start_bit_o),
        .autoreload_bit(autoreload_bit_o)
    );

    Registro_Datos u_data (
        .clk(clk), .reset(reset),
        .we(we_data), .wdata(data_in),
        .count_value_i(count_value_i),
        .rdata(data_rdata),
        .load_value_o(load_value_o)
    );

    always_comb begin
        data_out = (addr_i == 1'b0) ? control_rdata : data_rdata;
    end
endmodule
