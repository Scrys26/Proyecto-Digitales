`timescale 1ns/1ps
// Adaptador corregido para manejar la escritura de 8 bits desde un bus de 32 bits.
// Asume que el dato válido (el carácter ASCII) siempre se encuentra en din32[7:0].
module adapta_TX(
    input  logic             clk_16mhz_i,
    input  logic             rst,
    input  logic             wr_en,    // Señal de escritura (del ROM Sender)
    input  logic [31:0]      din32,    // Bus de entrada de 32 bits (entrada_i)
    output logic [7:0]       dout8,    // Salida de 8 bits al FIFO TX IN
    output logic             wr_fifo,  // Señal de escritura para el FIFO TX WR
    output logic             busy      // Señal para indicar que la escritura fue procesada
);
 
    // Conectividad de Datos: Extraer SOLO el byte menos significativo
    // Asumimos que el carácter ASCII de la ROM está ubicado en din32[7:0].
    assign dout8 = din32[7:0];
 
    // Conectividad de Control: Simplemente pasar la señal de escritura
    // Cuando el agente externo activa wr_en, escribimos UN solo byte al FIFO.
    // Usamos un registro para sincronizar la salida, si es necesario, pero
    // para una simple transferencia de pulso, podemos pasarlo directamente:
    assign wr_fifo = wr_en;
    // busy: En este adaptador simple, no estamos "ocupados" en ciclos. 
    // La escritura es instantánea (un ciclo de reloj).
    assign busy = 1'b0;
 
endmodule