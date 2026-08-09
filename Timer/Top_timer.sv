module Timer_Top (
    input  logic        clk,
    input  logic        reset,
    input  logic [0:0]  addr_i,      // 0x...0050=control, 0x...0054=contador
    input  logic [31:0] data_in,
    output logic [31:0] data_out,
    input  logic        write_i,
    output logic        timeout_o
);
    logic        start_bit, autoreload_bit;
    logic [31:0] load_value;
    logic [31:0] count_value;
    logic        timeout_sig;
    logic        enable_timer;
    logic        load_en;
    logic        timeout_flag;

    Interfaz_Registros u_regs (
        .clk(clk),
        .reset(reset),
        .addr_i(addr_i),
        .write_i(write_i),
        .data_in(data_in),
        .data_out(data_out),

        .timeout_flag_i(timeout_flag),
        .count_value_i(count_value),
        .start_bit_o(start_bit),
        .autoreload_bit_o(autoreload_bit),
        .load_value_o(load_value)
    );

    Control u_ctrl (
        .clk(clk),
        .reset(reset),
        .start_bit(start_bit),
        .autoreload_bit(autoreload_bit),
        .timeout_in(timeout_sig),

        .enable_timer(enable_timer),
        .load_en(load_en),              
        .timeout_flag(timeout_flag)
    );

    Contador_descendente u_cnt (
        .clk(clk),
        .reset(reset),
        .enable(enable_timer),
        .load_en(load_en),            
        .load_value(load_value),
        .count_value(count_value),
        .timeout(timeout_sig)
    );

    assign timeout_o = timeout_sig;
endmodule
