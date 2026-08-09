`timescale 1ns / 1ps

module uart_control_reg (
    input  logic        clk,             // reloj
    input  logic        rst,             // reset asíncrono 
    input  logic        wr_reg,          // enable de escritura al registro de control
    input  logic [31:0] entrada_i,       // dato escrito por el agente externo

    // Bus S/C/DC 
    input  logic        scdc_ftxf_i,     // FIFO TX llena
    input  logic        scdc_rxav_i,     // RX tiene datos
    input  logic [8:0]  scdc_bytes_tx_i, // conteo FIFO TX
    input  logic [8:0]  scdc_bytes_rx_i, // conteo FIFO RX

    // Control interno de bits WC
    input  logic        scdc_set_enviar_i,
    input  logic        scdc_clr_enviar_i,
    input  logic        scdc_set_leer_i,
    input  logic        scdc_clr_leer_i,

    // Salidas hacia el bloque de control UART
    output logic        enviar_o,
    output logic        leer_o,

    // Lectura externa del registro de control 
    output logic [31:0] out_reg_o
);

    // -------------------------------
    // Parámetros de bits
    // -------------------------------
    localparam int BIT_ENVIAR   = 0;
    localparam int BIT_FTXF     = 1;
    localparam int BIT_LEER     = 2;
    localparam int BIT_RXAV     = 3;
    localparam int LO_BYTES_TX  = 20;
    localparam int HI_BYTES_TX  = 28;
    localparam int LO_BYTES_RX  = 8;
    localparam int HI_BYTES_RX  = 16;

    // -------------------------------
    // Registros internos (WC)
    // -------------------------------
    logic enviar_q, leer_q;

    // -------------------------------
    // Estados RO
    // -------------------------------
    logic ftxf_q, rxav_q;
    logic [8:0] bytes_tx_q, bytes_rx_q;

    // -------------------------------
    // Detectar flancos de escritura externa
    // -------------------------------
    logic enviar_prev, leer_prev;

    // -------------------------------
    // Actualización de bits WC (One-shot)
    // -------------------------------
   // uart_control_reg
// ...
// -------------------------------
// Actualización de bits WC (Nivel)
// -------------------------------
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        enviar_q <= 1'b0;
        leer_q   <= 1'b0;
        enviar_prev <= 1'b0;
        leer_prev   <= 1'b0;
    end else begin
        // Capturar la escritura del agente externo (flanco positivo)
        logic ext_set_enviar = wr_reg && entrada_i[BIT_ENVIAR] && !enviar_prev;
        logic ext_set_leer   = wr_reg && entrada_i[BIT_LEER] && !leer_prev;

        // -----------------------
        // PRIORIDAD CONTROL INTERNO (Clear/Set)
        // -----------------------
        if (scdc_clr_enviar_i) begin
            enviar_q <= 1'b0;
        end else if (ext_set_enviar && !scdc_ftxf_i) begin
            // Solo establecemos si la FIFO TX no está llena
            enviar_q <= 1'b1;
        end else if (scdc_set_enviar_i) begin
            // Set interno (si fuera necesario, aquí no lo es pero se mantiene la estructura)
            enviar_q <= 1'b1;
        end
        // Si no hay acción de control interno ni set externo, mantiene su valor.

        if (scdc_clr_leer_i) begin
            leer_q <= 1'b0;
        end else if (ext_set_leer && scdc_rxav_i) begin
            // Solo establecemos si la FIFO RX tiene datos (RXAV)
            leer_q <= 1'b1;
        end else if (scdc_set_leer_i) begin
            // Set interno (si fuera necesario)
            leer_q <= 1'b1;
        end
        // Si no hay acción de control interno ni set externo, mantiene su valor.

        // -----------------------
        // Guardar estados anteriores (para edge detection)
        // -----------------------
        enviar_prev <= entrada_i[BIT_ENVIAR];
        leer_prev   <= entrada_i[BIT_LEER];
    end
end

    // -------------------------------
    // Actualización de estado RO
    // -------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ftxf_q     <= 1'b0;
            rxav_q     <= 1'b0;
            bytes_tx_q <= '0;
            bytes_rx_q <= '0;
        end else begin
            ftxf_q     <= scdc_ftxf_i;
            rxav_q     <= scdc_rxav_i;
            bytes_tx_q <= scdc_bytes_tx_i;
            bytes_rx_q <= scdc_bytes_rx_i;
        end
    end

    // -------------------------------
    // Salidas
    // -------------------------------
    assign enviar_o = enviar_q;
    assign leer_o   = leer_q;

    always_comb begin
        out_reg_o = '0;
        out_reg_o[BIT_ENVIAR]               = enviar_q;
        out_reg_o[BIT_FTXF]                 = ftxf_q;
        out_reg_o[BIT_LEER]                 = leer_q;
        out_reg_o[BIT_RXAV]                 = rxav_q;
        out_reg_o[HI_BYTES_TX:LO_BYTES_TX]  = bytes_tx_q;
        out_reg_o[HI_BYTES_RX:LO_BYTES_RX]  = bytes_rx_q;
    end

endmodule
