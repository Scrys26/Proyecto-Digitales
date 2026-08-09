module Interfaz_UART (
    input  logic        clk,
    input  logic        reset,
    input  logic        wr_i, 
    input  logic        reg_sel_i,          // demux: 0=reg, 1=fifo
    input  logic [31:0] entrada_i,
    input  logic        uart_rx,
    output logic        uart_tx,
    output  logic [10:0] status_fifo_tx,// {full, empty, count[8:0]}
    output logic [10:0] status_fifo_rx, // {full, empty, count[8:0]}
    output logic [31:0] salida_o,
    output logic RXAV, 
    output logic FTXF
);

    // Control reg -> FSM
    logic enviar_reg, leer_reg;

    // FIFOs
    logic [7:0]  out_fifo_tx;    // -> UART TX
    logic [31:0] out_fifo_rx;    // <- Adaptador RX
    logic        valid_o;
    
    logic        busy_i;

    // Señales FSM <-> FIFOs/UART
    logic fifo_tx_rd, fifo_rx_wr, fifo_rx_rd;
    logic tx_start, clr_enviar, clr_leer;
    logic rx_data_rdy, tx_rdy;
    logic rx_overflow;
    logic clr_overflow;  // por ahora atado a 0 (puedes exponerlo si quieres que software lo limpie)

    // UART RX/TX (8-bit)
    logic [7:0] in_fifo_rx;

    // demux/mux
    logic wr_reg, wr_fifo;
    logic [31:0] out_reg_o;

    // limpiar overflow (no implementado en reg aún)
    assign clr_overflow = 1'b0;

    // Evitar señales flotantes si no usas busy
    assign busy_i = 1'b0;

    // --------------------
    // Instancias
    // --------------------

    // DEMUX escritura (reg o fifo)
    demux demux_inst (
        .reg_sel_i (reg_sel_i),
        .wr_i      (wr_i),
        .wr_reg    (wr_reg),
        .wr_fifo   (wr_fifo)
    );

    // MUX de lectura (reg o fifo)
    Mux2_1 mux_inst (
        .out_reg   (out_reg_o),
        .out_fifo  (out_fifo_rx),
        .reg_sel_i (reg_sel_i),
        .salida_o  (salida_o)
    );

    // Registro de control (usa la versión corregida que latch hasta clear)
    uart_control_reg uart_control_inst (
        .clk                 (clk),
        .rst                 (reset),
        .wr_reg              (wr_reg),
        .entrada_i           (entrada_i),

        .scdc_ftxf_i         (status_fifo_tx[10]),   // FULL TX
        .scdc_rxav_i         (~status_fifo_rx[9]),   // RXAV = !EMPTY RX
        .scdc_bytes_tx_i     (status_fifo_tx[8:0]),
        .scdc_bytes_rx_i     (status_fifo_rx[8:0]),

        .scdc_set_enviar_i   (1'b1),                 
        .scdc_clr_enviar_i   (clr_enviar),           // limpia por FSM
        .scdc_set_leer_i     (1'b0),
        .scdc_clr_leer_i     (clr_leer),

        .enviar_o            (enviar_reg),
        .leer_o              (leer_reg),
        .out_reg_o           (out_reg_o)
    );

    // FIFOs + adaptadores
    Top_FIFOs top_fifos_inst (
        .clk          (clk),
        .reset        (reset),
        .wr_i         (wr_fifo),        // 32b hacia FIFO TX mediante adapta_TX
        .entrada_i    (entrada_i),

        .rd_control_rx_i      (fifo_rx_rd),     // pop 32b del adapta_RX (desde FIFO RX)
        .in_fifo_rx   (in_fifo_rx),     // 8b desde UART RX a FIFO RX
        .wr_rx_i      (fifo_rx_wr),     // push FIFO RX (desde FSM al llegar byte)
        .rd_tx_i      (fifo_tx_rd),     // pop FIFO TX (hacia UART TX)

        .out_fifo_tx  (out_fifo_tx),    // 8b hacia UART TX
        .out_fifo_rx  (out_fifo_rx),    // 32b hacia mux

        .status_fifo_tx (status_fifo_tx),
        .status_fifo_rx (status_fifo_rx),

        .busy_o       (1'b0)
    );


        // FSM de control UART
    uart_control_fsm uart_fsm_inst (
        .clk           (clk),
        .reset         (reset),

        .enviar_reg    (enviar_reg),
        .leer_reg      (leer_reg),
        .rx_data_rdy   (rx_data_rdy),
        .tx_rdy        (tx_rdy),

        .fifo_tx_empty (status_fifo_tx[9]),
        .fifo_tx_full  (status_fifo_tx[10]),
        .fifo_rx_empty (status_fifo_rx[9]),
        .fifo_rx_full  (status_fifo_rx[10]),

        .fifo_tx_rd    (fifo_tx_rd),
        .fifo_rx_wr    (fifo_rx_wr),
        .fifo_rx_rd    (fifo_rx_rd),
        .tx_start      (tx_start),
        .clr_enviar    (clr_enviar),
        .clr_leer      (clr_leer),

        .RXAV          (RXAV),
        .FTXF          (FTXF),

        .clr_overflow  (clr_overflow),
        .rx_overflow   (rx_overflow)
    );

    // UART (VHDL)
    UART uart_inst (
        .clk         (clk),
        .reset       (reset),
        .tx_start    (tx_start),

        .tx_rdy      (tx_rdy),
        .rx_data_rdy (rx_data_rdy),

        .data_in     (out_fifo_tx),
        .data_out    (in_fifo_rx),
        .rx          (uart_rx),
        .tx          (uart_tx)
    );

endmodule
