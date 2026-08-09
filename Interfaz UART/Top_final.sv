`timescale 1ns / 1ps

module Top_parte2 (
    input  logic         clk,
    input  logic         reset,
    input  logic [15:0] sw,        // switches físicos (SW0..SW13)
    input  logic         btnL,      // WR (mapeado a SW14 en XDC)
    input  logic         btnR,      // reg_sel (Pulso)
    //input  logic         btnRW,     // reg_sel (Nivel) <--- NUEVO PUERTO
    input  logic         uart_rx,
    output logic         uart_tx,
    output logic [15:0] led,       // LEDs
    output logic [6:0]  seg,       // segmentos (activos en 0)
    output logic [7:0]  an         // ánodos (activos en 0)
    
);

    // ----------------------
    // Reloj interno 16 MHz
    // ----------------------
    logic clk_16mhz_i, locked;

    clk_wiz_0 clk_inst (
        .clk_out1 (clk_16mhz_i),
        .reset    (reset),
        .locked   (locked),
        .clk_in1  (clk)
    );

    // ----------------------
    // Señales Interfaz UART
    // ----------------------
    logic        RXAV, FTXF;
    logic [10:0] status_fifo_tx;   // {full, empty, count[8:0]}
    logic [10:0] status_fifo_rx;   // {full, empty, count[8:0]}
    logic [31:0] salida_o;
    logic [31:0] entrada_i;

    // Dato a TX (desde switches)
    assign entrada_i = {18'b0, sw[13:0]};     // sw[13:0] -> bits [13:0]

    // ----------------------------------------------------
    // Botones (WR=Pulso Latch, reg_sel=Pulso OR Nivel)
    // ----------------------------------------------------
    logic wr_i_int;          // WR Pulse (desde btnL)
    logic reg_sel_pulse;     // Pulso de 1 ciclo (desde btnR)
    logic reg_sel_i_int;     // Señal final de reg_sel (Pulso OR Nivel)
    
    logic btnL_prev, btnR_prev;

    // ASIGNACIÓN CLAVE: reg_sel_i_int es el OR de btnRW (Nivel) y el pulso de btnR.
    assign reg_sel_i_int = reg_sel_pulse | sw[13]; 

    always_ff @(posedge clk_16mhz_i or posedge reset) begin
        if (reset) begin
            wr_i_int      <= 1'b0;
            reg_sel_pulse <= 1'b0;
            btnL_prev     <= 1'b0;
            btnR_prev     <= 1'b0;
        end else begin
            
            // --- Lógica de Pulso/Latch para WR (btnL) --- (Lógica de tu primer bloque)
            // Se activa en flanco de subida de btnL y se mantiene si el botón sigue
            // presionado Y la FIFO no está llena.
            if (btnL & ~btnL_prev)
                wr_i_int <= 1'b1;
            else if (status_fifo_tx[10] || btnL == 0) // FULL TX o botón liberado
                wr_i_int <= 1'b0;

            // --- Lógica de Pulso de 1 ciclo para reg_sel (btnR) --- (Lógica de tu primer bloque)
            // Genera un pulso de un ciclo al detectar el flanco de subida de btnR.
            if (btnR & ~btnR_prev)
                reg_sel_pulse <= 1'b1;
            else
                reg_sel_pulse <= 1'b0;

            // --- Actualizar estados previos ---
            btnL_prev <= btnL;
            btnR_prev <= btnR;
        end
    end


    // ----------------------
    // Interfaz UART
    // ----------------------
    Interfaz_UART u_if (
        .clk             (clk_16mhz_i),
        .reset           (reset),
        .wr_i            (wr_i_int),
        .reg_sel_i       (reg_sel_i_int), // Conectado a la señal OR (pulso de btnR O nivel de btnRW)
        .entrada_i       (entrada_i),
        .uart_rx         (uart_rx),
        .uart_tx         (uart_tx),
        .status_fifo_tx  (status_fifo_tx),
        .status_fifo_rx  (status_fifo_rx),
        .RXAV            (RXAV),
        .FTXF            (FTXF),
        .salida_o        (salida_o)
    );

    // ----------------------
    // Multiplexado 7-seg
    // ----------------------
    logic [15:0] mux_counter;
    logic [2:0]  disp_sel_reg;
    logic [7:0]  an_reg;
    logic [3:0]  bin_reg;

    // refresco (~122 Hz por digito con clk=16MHz)
    always_ff @(posedge clk_16mhz_i or posedge reset) begin
        if (reset) mux_counter <= 16'd0;
        else       mux_counter <= mux_counter + 16'd1;
    end

    always_ff @(posedge clk_16mhz_i or posedge reset) begin
        if (reset) begin
            disp_sel_reg <= 3'd0;
            an_reg       <= 8'hFF;
        end else begin
            disp_sel_reg     <= mux_counter[15:13]; // 0..7
            an_reg           <= 8'hFF;
            an_reg[disp_sel_reg] <= 1'b0;          // activo bajo
        end
    end
    assign an = an_reg;

    // ----------------------
    // Datos a mostrar (pares de digitos) - Usando la lógica de conteo de bytes de tu segundo bloque
    // ----------------------
    wire [7:0] tx_data_byte = entrada_i[7:0];
    wire [7:0] reg_data_byte = salida_o[7:0];

    wire [8:0] tx_bytes_9 = status_fifo_tx[8:0];
    wire [8:0] rx_bytes_9 = status_fifo_rx[8:0];

    // Mantenemos la lógica de visualización de conteo de bytes del segundo bloque
    wire [7:0] tx_bytes8 = tx_bytes_9[8:2]; 
    wire [7:0] rx_bytes8 = rx_bytes_9[7:0]; 
    
    always_ff @(posedge clk_16mhz_i or posedge reset) begin
        if (reset) begin
            bin_reg <= 4'h0;
        end else begin
            unique case (disp_sel_reg)
                3'd0: bin_reg <= tx_data_byte[3:0];     // an[0]
                3'd1: bin_reg <= tx_data_byte[7:4];     // an[1]
                3'd2: bin_reg <= reg_data_byte[3:0];    // an[2]
                3'd3: bin_reg <= reg_data_byte[7:4];    // an[3]
                3'd4: bin_reg <= tx_bytes8[3:0];        // an[4]
                3'd5: bin_reg <= tx_bytes8[7:4];        // an[5]
                3'd6: bin_reg <= rx_bytes8[3:0];        // an[6]
                3'd7: bin_reg <= rx_bytes8[7:4];        // an[7]
                default: bin_reg <= 4'h0;
            endcase
        end
    end

    // Decodificación a 7-seg (activos en 0)
    always_ff @(posedge clk_16mhz_i or posedge reset) begin
        if (reset) seg <= 7'b1111111;
        else begin
            unique case (bin_reg)
                4'h0: seg <= 7'b1000000;
                4'h1: seg <= 7'b1111001;
                4'h2: seg <= 7'b0100100;
                4'h3: seg <= 7'b0110000;
                4'h4: seg <= 7'b0011001;
                4'h5: seg <= 7'b0010010;
                4'h6: seg <= 7'b0000010;
                4'h7: seg <= 7'b1111000;
                4'h8: seg <= 7'b0000000;
                4'h9: seg <= 7'b0010000;
                4'hA: seg <= 7'b0001000;
                4'hB: seg <= 7'b0000011;
                4'hC: seg <= 7'b1000110;
                4'hD: seg <= 7'b0100001;
                4'hE: seg <= 7'b0000110;
                4'hF: seg <= 7'b0001110;
                default: seg <= 7'b1111111;
            endcase
        end
    end

    // ----------------------
    // LEDs de estado
    // ----------------------
    assign led[0]  = status_fifo_tx[9];   // TX empty
    assign led[1]  = status_fifo_tx[10];  // TX full
    assign led[2]  = status_fifo_rx[9];   // RX empty
    assign led[3]  = status_fifo_rx[10];  // RX full
    assign led[4]  = RXAV;                // RX tiene datos
    assign led[5]  = FTXF;                // TX llena
    assign led[6]  = 1'b0;
    assign led[7]  = 1'b0;
    assign led[8]  = 1'b0;
    assign led[9]  = 1'b0;
    assign led[10] = 1'b0;
    assign led[11] = 1'b0;
    assign led[12] = 1'b0;
    assign led[13] = locked;              // PLL lock
    assign led[14] = 1'b0;                // no exponer busy
    assign led[15] = 1'b0;                // no exponer valid
endmodule