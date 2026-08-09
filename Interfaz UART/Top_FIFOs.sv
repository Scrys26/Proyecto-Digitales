`timescale 1ns/1ps

module Top_FIFOs (
    // Señales de Reloj y Reset
    input logic clk,
    input logic reset,

    // Señales de la Interfaz con el Agente Externo (Bus de 32 bits)
    input logic wr_i,
    input logic [31:0] entrada_i,
    input logic rd_control_rx_i, // Pulso RD de FIFO RX (Activación del LATCH)
    
    // Señales de Interfaz con el UART
    input logic [7:0] in_fifo_rx,
    input logic wr_rx_i,
    input logic rd_tx_i,

    // Salidas
    output logic [7:0] out_fifo_tx,
    output logic [31:0] out_fifo_rx, // Salida de 32 bits (Dato de FIFO RX)
    output logic [10:0] status_fifo_tx,
    output logic [10:0] status_fifo_rx,
    output logic busy_o
);

    //----Señales Internas----
    logic srst;

    // Para TX
    logic [7:0] din8_tx;
    logic [8:0] data_count_fifo_TX;
    logic wr_fifo_tx; 
    logic full_fifo_TX, empty_fifo_TX;
    
    // Registro que LATCHEA el dato de salida de la FIFO RX (CORRECCIÓN)
    logic [31:0] out_fifo_rx_reg; 
    
    // Para RX
    logic [7:0] dout8_rx; // Salida de 8 bits de la FIFO RX
    logic [8:0] data_count_fifo_RX;
    logic full_fifo_RX, empty_fifo_RX;


    //-----RESET------
    always_ff @(posedge clk or posedge reset) begin
    if (reset)
        srst <= 1;
    else
        srst <= 0;
    end

    //==========================================
    // FIFO TX (Transmisión)
    //==========================================
    
    fifo_generator_0 fifo_TX (
        .clk(clk),
        .srst(srst),
        .din(din8_tx),
        .wr_en(wr_fifo_tx),
        .rd_en(rd_tx_i), 
        .dout(out_fifo_tx),
        .full(full_fifo_TX),
        .empty(empty_fifo_TX),
        .data_count(data_count_fifo_TX)
    );

    adapta_TX adaptador_TX (
        .clk_16mhz_i(clk),
        .rst(srst),
        .wr_en(wr_i),
        .din32(entrada_i),
        .dout8(din8_tx),
        .wr_fifo(wr_fifo_tx),
        .busy(busy_o)
    );

    //==========================================
    // FIFO RX (Recepción)
    //==========================================
    
    fifo_generator_1 fifo_RX(
        .clk(clk),
        .srst(srst),
        .din(in_fifo_rx),
        .wr_en(wr_rx_i),
        .rd_en(rd_control_rx_i), // Pulso de lectura desde el Control UART
        .dout(dout8_rx), // Dato de 8 bits que sale
        .full(full_fifo_RX),
        .empty(empty_fifo_RX),
        .data_count(data_count_fifo_RX)
    );
    
    // ==========================================
// LATCH de Salida RX (CORRECCIÓN: capturar after-read)
// ==========================================
logic rd_control_rx_q;

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        out_fifo_rx_reg <= 32'hFFFFFFFF; // o 0 si prefieres
        rd_control_rx_q <= 1'b0;
    end else begin
        // Registramos la señal de lectura (pulse)
        rd_control_rx_q <= rd_control_rx_i;

        // Cuando la señal registrada fue 1 significa que en el ciclo anterior
        // solicitamos rd_en a la FIFO y ahora dout8_rx ya está estable:
        if (rd_control_rx_q) begin
            out_fifo_rx_reg <= {24'b0, dout8_rx};
        end
        // Si quieres, puedes mantener else para conservar el valor anterior
    end
end


    // Conecta el registro latcheado al puerto de salida (¡Ahora es estable!)
    assign out_fifo_rx = out_fifo_rx_reg;

    //==========================================
    // Asignación de Status
    //==========================================
    assign status_fifo_tx = {full_fifo_TX, empty_fifo_TX, data_count_fifo_TX};
    assign status_fifo_rx = {full_fifo_RX, empty_fifo_RX, data_count_fifo_RX};

endmodule