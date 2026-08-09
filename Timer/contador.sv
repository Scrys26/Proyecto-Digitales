module Contador_descendente #(
    parameter WIDTH = 32
)(
    input  logic             clk,
    input  logic             reset,
    input  logic             enable,        // habilita el decremento
    input  logic             load_en,      
    input  logic [WIDTH-1:0] load_value,    // valor a cargar
    output logic [WIDTH-1:0] count_value,   // valor actual
    output logic             timeout        // pulso 1 ciclo al llegar a 0
);

    logic [WIDTH-1:0] counter_reg;

    // timeout de 1 ciclo cuando (counter_reg == 1) y hay enable (se va a 0)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            counter_reg <= '0;
            timeout     <= 1'b0;
        end else begin
            // por defecto, timeout se limpia
            timeout <= 1'b0;

            if (load_en) begin
                counter_reg <= load_value;
            end else if (enable) begin
                if (counter_reg > '0) begin
                    if (counter_reg == {{(WIDTH-1){1'b0}},1'b1}) begin
                        // va a pasar de 1 a 0: generar pulso timeout
                        timeout     <= 1'b1;
                        counter_reg <= '0;
                    end else begin
                        counter_reg <= counter_reg - 1'b1;
                    end
                end
                // si ya está en 0 y no hay load_en, se queda en 0 sin repetir timeout
            end
        end
    end

    assign count_value = counter_reg;

endmodule
