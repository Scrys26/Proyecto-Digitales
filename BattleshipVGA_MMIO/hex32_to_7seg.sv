// ============================================================================
// disp_hex32_simple.sv
// Muestra 32 bits en 8 dígitos HEX (7-segmentos activos en 0)
// Escaneo para Nexys4: segmentos[6:0] + anodos[7:0] (activos en 0)
// ============================================================================
module disp_hex32_simple #(
  parameter int CNT_W = 20,     // ancho del contador
  parameter int HI    = 12,     // bit alto usado para selección de dígito
  parameter int LO    = 10      // bit bajo usado para selección de dígito
)(
  input  logic        clk,      // clk de 16 MHz
  input  logic        rst,      // activo en 1
  input  logic [31:0] value,    // valor a mostrar
  output logic [6:0]  seg,      // segmentos (activos en 0)
  output logic [7:0]  an        // ánodos (activos en 0)
);

  // ----------------- divisor y selección de dígito -----------------
  logic [CNT_W-1:0] mux_cnt;
  always_ff @(posedge clk or posedge rst) begin
    if (rst) mux_cnt <= '0;
    else     mux_cnt <= mux_cnt + {{(CNT_W-1){1'b0}},1'b1};
  end

  logic [2:0] digit_sel;
  assign digit_sel = mux_cnt[HI:LO];  // por defecto mux_cnt[12:10]

  // ----------------- nibble actual -----------------
  logic [3:0] cur_nibble;
  always_comb begin
    unique case (digit_sel)
      3'd0: cur_nibble = value[3:0];
      3'd1: cur_nibble = value[7:4];
      3'd2: cur_nibble = value[11:8];
      3'd3: cur_nibble = value[15:12];
      3'd4: cur_nibble = value[19:16];
      3'd5: cur_nibble = value[23:20];
      3'd6: cur_nibble = value[27:24];
      3'd7: cur_nibble = value[31:28];
      default: cur_nibble = 4'h0;
    endcase
  end

  // ----------------- decoder HEX → 7 segmentos -----------------
  function automatic [6:0] hex_to_7seg (input logic [3:0] x);
    unique case (x)
      4'h0: hex_to_7seg = 7'b1000000;
      4'h1: hex_to_7seg = 7'b1111001;
      4'h2: hex_to_7seg = 7'b0100100;
      4'h3: hex_to_7seg = 7'b0110000;
      4'h4: hex_to_7seg = 7'b0011001;
      4'h5: hex_to_7seg = 7'b0010010;
      4'h6: hex_to_7seg = 7'b0000010;
      4'h7: hex_to_7seg = 7'b1111000;
      4'h8: hex_to_7seg = 7'b0000000;
      4'h9: hex_to_7seg = 7'b0010000;
      4'hA: hex_to_7seg = 7'b0001000;
      4'hB: hex_to_7seg = 7'b0000011;
      4'hC: hex_to_7seg = 7'b1000110;
      4'hD: hex_to_7seg = 7'b0100001;
      4'hE: hex_to_7seg = 7'b0000110;
      4'hF: hex_to_7seg = 7'b1111111;  // <<< F = BLANCO (todos apagados)
      default: hex_to_7seg = 7'b1111111;
    endcase
  endfunction

  // ----------------- registros de salida -----------------
  always_ff @(posedge clk or posedge rst) begin
    if (rst) seg <= 7'b1111111;
    else     seg <= hex_to_7seg(cur_nibble);
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) an <= 8'hFF;
    else begin
      unique case (digit_sel)
        3'd0: an <= 8'b1111_1110;  // dígito 0 (derecha)
        3'd1: an <= 8'b1111_1101;  // dígito 1
        3'd2: an <= 8'b1111_1011;  // dígito 2
        3'd3: an <= 8'b1111_0111;  // dígito 3
        3'd4: an <= 8'b1110_1111;  // dígito 4
        3'd5: an <= 8'b1101_1111;  // dígito 5
        3'd6: an <= 8'b1011_1111;  // dígito 6
        3'd7: an <= 8'b0111_1111;  // dígito 7 (izquierda)
        default: an <= 8'hFF;
      endcase
    end
  end

endmodule
