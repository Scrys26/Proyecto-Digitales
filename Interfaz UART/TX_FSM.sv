`timescale 1ns / 1ps

// ----------------------------------------------------------------------------
// uart_tx_fsm.sv
// FSM dedicada a TX: envía ráfagas mientras enviar_reg == 1 y FIFO TX no esté vacía.
// ----------------------------------------------------------------------------
module uart_tx_fsm (
  input  logic clk,
  input  logic reset,

  input  logic enviar_reg,      // nivel desde registro de control
  input  logic tx_rdy,          // indica fin de transmisión / ready
  input  logic fifo_tx_empty,
  input  logic fifo_tx_full,    // no usado para la lógica pero expuesto si se necesita

  output logic fifo_tx_rd,      // pulso 1c para leer FIFO TX
  output logic tx_start,        // pulso 1c para latchear/transmitir dato
  output logic clr_enviar       // pulso 1c que limpia el bit enviar en el registro
);

  typedef enum logic [1:0] { TX_IDLE, TX_POP, TX_SEND } tx_state_t;
  tx_state_t state, nxt;

  // TX idle tracking: cuando tx_start se aserta, tx_idle -> 0; cuando tx_rdy se aserta -> 1
  logic tx_idle;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) tx_idle <= 1'b1;
    else begin
      if (tx_start)      tx_idle <= 1'b0; // comenzamos transmisión
      else if (tx_rdy)   tx_idle <= 1'b1; // transmisor listo otra vez / transmisión terminada
    end
  end

  // Lógica combinacional
 always_comb begin
  nxt = state;
  fifo_tx_rd = 1'b0;
  tx_start   = 1'b0;
  clr_enviar = 1'b0;

  unique case (state)
    TX_IDLE: begin
      // Si se solicita envío y hay datos -> empezar
      if (enviar_reg && !fifo_tx_empty) begin // <--- ¡QUITAMOS && tx_idle!
        nxt = TX_POP;
      end else begin
        // Solo para ser limpio (la lógica externa ya lo maneja)
        // Eliminamos el 'if (enviar_reg && fifo_tx_empty && tx_idle)' interno
      end
    end

    TX_POP: begin
        fifo_tx_rd = 1'b1;
        nxt = TX_SEND;
    end

    TX_SEND: begin
      tx_start = 1'b1;
      if (tx_rdy) begin
        if (!fifo_tx_empty) nxt = TX_POP;      // enviar siguiente byte
        else nxt = TX_IDLE;                    // todo enviado, ir a IDLE
      end else nxt = TX_SEND;
    end

    default: nxt = TX_IDLE;
  endcase
  
  // Lógica de salida: clr_enviar (debes mantener esta lógica fuera del case)
  // Limpieza por finalización de ráfaga
  if (nxt == TX_IDLE && state == TX_SEND && tx_rdy && fifo_tx_empty) begin
    clr_enviar = 1'b1; 
  end 
  // Limpieza por intento de enviar sin datos. Aquí S�? necesitamos tx_idle 
  // para asegurarnos de que la FSM está completamente libre para la limpieza.
  else if (state == TX_IDLE && enviar_reg && fifo_tx_empty && tx_idle) begin
    clr_enviar = 1'b1; 
  end
end

  // FF de estado
  always_ff @(posedge clk or posedge reset) begin
    if (reset) state <= TX_IDLE;
    else       state <= nxt;
  end

endmodule