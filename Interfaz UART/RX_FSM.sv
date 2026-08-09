module uart_rx_fsm (
  input  logic clk,
  input  logic reset,

  input  logic rx_data_rdy,    // señal del bloque UART (puede permanecer más de 1 ciclo)
  input  logic leer_reg,       // petición de lectura desde registro
  input  logic fifo_rx_empty,
  input  logic fifo_rx_full,

  output logic fifo_rx_wr,     // pulso 1c para escribir FIFO RX
  output logic fifo_rx_rd,     // pulso 1c para leer FIFO RX (cuando se procesa leer_reg)
  output logic clr_leer,       // pulso 1c para limpiar el bit leer en el registro
  output logic rx_pending_edge // (opcional) indica que se detectó un byte listo
);

  typedef enum logic [1:0] { RX_IDLE, RX_PUSH, RX_POP } rx_state_t;
  rx_state_t state, nxt;

  // Edge detector para rx_data_rdy (0->1)
  logic rx_data_rdy_q;
  logic rx_data_rdy_posedge;
  logic post_reset_enable;

// 2. Lógica de habilitación post-reset
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        post_reset_enable <= 1'b0;
    end else begin
        // Permite la habilitación un ciclo después de que reset baja
        post_reset_enable <= 1'b1; 
    end
end  
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) rx_data_rdy_q <= 1'b0;
    else       rx_data_rdy_q <= rx_data_rdy;
  end
  assign rx_data_rdy_posedge = (~rx_data_rdy_q) & rx_data_rdy;

  always_comb begin
    nxt = state;
    fifo_rx_wr = 1'b0;
    fifo_rx_rd = 1'b0;
    clr_leer   = 1'b0;
    rx_pending_edge = 1'b0;

    unique case (state)
      
      RX_IDLE: begin
        // Prioridad 1: Hay un dato nuevo de la UART (Push a FIFO)
        if (rx_data_rdy_posedge && !fifo_rx_full  && post_reset_enable) begin // <-- INICIO DEL IF
          nxt = RX_PUSH;
        end 
        // Prioridad 2: El agente externo solicita leer Y HAY DATOS
        else if (leer_reg && !fifo_rx_empty) begin 
          // Si se solicita lectura y hay datos disponibles -> pop
          nxt = RX_POP;
        end
        // Si no ocurre nada, se queda en RX_IDLE
      end // <-- FIN DEL ESTADO RX_IDLE

      RX_PUSH: begin
        fifo_rx_wr = 1'b1;      // generar escritura a FIFO RX
        rx_pending_edge = 1'b1;
        nxt = RX_IDLE;
      end

      RX_POP: begin
        fifo_rx_rd = 1'b1;      // generar lectura FIFO RX
        clr_leer   = 1'b1;      // limpiar petición leer
        nxt = RX_IDLE;
      end

      default: nxt = RX_IDLE; // <-- Este es el default correcto
    endcase
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) state <= RX_IDLE;
    else       state <= nxt;
  end

endmodule
