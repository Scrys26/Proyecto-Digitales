module uart_control_fsm (
  input  logic clk,
  input  logic reset,

  input  logic enviar_reg,
  input  logic leer_reg,
  input  logic rx_data_rdy,
  input  logic tx_rdy,
  input  logic fifo_tx_empty,
  input  logic fifo_tx_full,
  input  logic fifo_rx_empty,
  input  logic fifo_rx_full,

  output logic fifo_tx_rd,
  output logic fifo_rx_wr,
  output logic fifo_rx_rd,
  output logic tx_start,
  output logic clr_enviar,
  output logic clr_leer,

  output logic RXAV,
  output logic FTXF,

  input  logic clr_overflow,
  output logic rx_overflow
);

  // Instanciar TX FSM
  uart_tx_fsm u_tx (
    .clk(clk),
    .reset(reset),
    .enviar_reg(enviar_reg),
    .tx_rdy(tx_rdy),
    .fifo_tx_empty(fifo_tx_empty),
    .fifo_tx_full(fifo_tx_full),
    .fifo_tx_rd(fifo_tx_rd),
    .tx_start(tx_start),
    .clr_enviar(clr_enviar)
  );

  // Instanciar RX FSM
  logic rx_fsm_fifo_rx_wr;
  logic rx_fsm_fifo_rx_rd;
  logic rx_fsm_clr_leer;
  logic rx_fsm_pending;
  uart_rx_fsm u_rx (
    .clk(clk),
    .reset(reset),
    .rx_data_rdy(rx_data_rdy),
    .leer_reg(leer_reg),
    .fifo_rx_empty(fifo_rx_empty),
    .fifo_rx_full(fifo_rx_full),
    .fifo_rx_wr(rx_fsm_fifo_rx_wr),
    .fifo_rx_rd(rx_fsm_fifo_rx_rd),
    .clr_leer(rx_fsm_clr_leer),
    .rx_pending_edge(rx_fsm_pending)
  );

  // Passthrough de señales RX FSM a salidas top-level
  assign fifo_rx_wr = rx_fsm_fifo_rx_wr;
  assign fifo_rx_rd = rx_fsm_fifo_rx_rd;
  assign clr_leer   = rx_fsm_clr_leer;

  // Flags combinacionales
  assign RXAV = !fifo_rx_empty;
  assign FTXF = fifo_tx_full;

  // Sticky overflow para RX:
  logic rx_overflow_q;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) rx_overflow_q <= 1'b0;
    else begin
      // Si RX intenta escribir y FIFO estaba full -> overflow sticky
      if (rx_fsm_fifo_rx_wr && fifo_rx_full) rx_overflow_q <= 1'b1;
      else if (clr_overflow)                  rx_overflow_q <= 1'b0;
    end
  end
  assign rx_overflow = rx_overflow_q;

endmodule