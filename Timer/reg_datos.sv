module Registro_Datos (
    input  logic        clk,
    input  logic        reset,
    input  logic        we,             // escritura del valor a cargar
    input  logic [31:0] wdata,
    input  logic [31:0] count_value_i,  // valor actual del contador
    output logic [31:0] rdata,          // lectura
    output logic [31:0] load_value_o
);
    logic [31:0] load_q;

    always_ff @(posedge clk or posedge reset) begin
        if (reset)       load_q <= 32'd0;
        else if (we)     load_q <= wdata;
    end

    assign load_value_o = load_q;
    assign rdata        = count_value_i; // lectura devuelve el conteo actual
endmodule
