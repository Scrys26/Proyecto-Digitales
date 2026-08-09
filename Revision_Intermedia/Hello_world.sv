// Revision Intermedia, conexion entre RISC-V y UART

`timescale 1ns/1ps
module Hello_world #( 
  parameter WIDTH           = 32,
  parameter INST_MEM_DEPTH  = 8,
  parameter REG_FILE_DEPTH  = 5,
  parameter DATA_MEM_DEPTH  = 16,
  parameter INST_SIZE       = 32
)(
  input  logic clk,  
  input  logic rst,
  input  logic uart_rx,
  output logic uart_tx,
  output logic [15:0] led,
  output logic [6:0]  seg,   // activos en 0
  output logic [7:0]  an     // activos en 0
);

  // ----------------- PLL a 16 MHz -----------------
  logic clk_16mhz, pll_locked;
  clk_wiz_0 u_pll (
    .clk_out1 (clk_16mhz),
    .reset    (rst),
    .locked   (pll_locked),
    .clk_in1  (clk)
  );

  // ----------------- Reset sincronizado (activo en 1) -----------------
  logic rst_sync_ff1, rst_sync_ff2, rst_sync;
  always_ff @(posedge clk_16mhz or posedge rst) begin
    if (rst) begin
      rst_sync_ff1 <= 1'b1;
      rst_sync_ff2 <= 1'b1;
    end else begin
      rst_sync_ff1 <= 1'b0;
      rst_sync_ff2 <= rst_sync_ff1;
    end
  end
  assign rst_sync = rst_sync_ff2;

  // ----------------- Señales del core RISC-V (externas) -----------------
  logic [31:0] ProgAddress_o;
  logic [31:0] ProgIn_i;        // desde ROM externa
  logic [31:0] DataAddress_o;   // hacia RAM/MMIO
  logic [31:0] DataOut_o;       // store data
  logic [31:0] DataIn_i;        // desde RAM/MMIO
  logic        we_o;            // store
  logic        mem_read_o;      // load
  logic        one_b, two_b, four_b;
  logic [31:0] pc_out;

  // ----------------- ROM de instrucciones externa -----------------
  logic [WIDTH-1:0] instruction;

  inst_mem #(.WIDTH(WIDTH), .DEPTH(INST_MEM_DEPTH)) u_rom (
`ifdef MULTICYCLE
    .clk      (clk_16mhz),
`endif
    .rst      (rst_sync),
    .data_in  (32'b0),
    .addr     (ProgAddress_o),   // PC del core
    .wr       (1'b0),            // ROM => no escribir
    .rd       (1'b1),
    .data_out (instruction)
  );

  assign ProgIn_i = instruction;

  // ----------------- RAM de datos externa -----------------
  wire [WIDTH-1:0] mem_data_out;

  data_mem #(.WIDTH(WIDTH), .DEPTH(DATA_MEM_DEPTH)) u_ram (
    .clk        (clk_16mhz),
    .rst        (rst_sync),
    .data_in    (DataOut_o),                          // store data del core
    .addr       (DataAddress_o[DATA_MEM_DEPTH-1:0]),  // indexado bajo
    .wr         (we_o),
    .rd         (mem_read_o),
    .one_byte   (one_b),
    .two_bytes  (two_b),
    .four_bytes (four_b),
    .data_out   (mem_data_out)
  );

  assign DataIn_i = mem_data_out; // dato leido a WB del core

  // ----------------- Core uniciclo (mems externas) -----------------
  uniciclo #(
    .WIDTH(WIDTH),
    .INST_MEM_DEPTH(INST_MEM_DEPTH),
    .REG_FILE_DEPTH(REG_FILE_DEPTH),
    .DATA_MEM_DEPTH(DATA_MEM_DEPTH),
    .INST_SIZE(INST_SIZE)
  ) u_core (
    .clk_i          (clk_16mhz),
    .rst_i          (rst_sync),

    .ProgAddress_o  (ProgAddress_o),
    .ProgIn_i       (ProgIn_i),

    .DataAddress_o  (DataAddress_o),
    .DataOut_o      (DataOut_o),
    .DataIn_i       (DataIn_i),

    .we_o           (we_o),
    .mem_read_o     (mem_read_o),
    .one_byte_o     (one_b),
    .two_bytes_o    (two_b),
    .four_bytes_o   (four_b),

    .pc_out         (pc_out)
  );

  // ----------------- UART MMIO (0x0001_0044) -----------------
  localparam logic [31:0] UART_BASE_ADDR = 32'h0001_0040;
  localparam logic [31:0] UART_DATA_ADDR = 32'h0001_0044;

  logic [31:0] if_entrada_i;
  logic [31:0] if_salida_o;
  logic [10:0] status_fifo_tx; // {full, empty, count[8:0]}
  logic [10:0] status_fifo_rx; // {full, empty, count[8:0]}
  logic        RXAV, FTXF;

  // Write cuando el core hace store a 0x0001_0044
  logic hit_uart_data = (DataAddress_o == UART_DATA_ADDR);
  logic wr_i          = we_o & hit_uart_data;
  logic reg_sel_i     = 1'b1;  // 1 => registro de datos

  assign if_entrada_i = {24'h0, DataOut_o[7:0]}; // LSB a TX

  Interfaz_UART u_uartif (
    .clk            (clk_16mhz),
    .reset          (rst_sync),
    .wr_i           (wr_i),
    .reg_sel_i      (reg_sel_i),
    .entrada_i      (if_entrada_i),
    .uart_rx        (uart_rx),
    .uart_tx        (uart_tx),
    .status_fifo_tx (status_fifo_tx),
    .status_fifo_rx (status_fifo_rx),
    .salida_o       (if_salida_o),
    .RXAV           (RXAV),
    .FTXF           (FTXF)
  );

  // (Opcional) Si luego lees UART por MMIO, multiplexa DataIn_i con mem_data_out
  // según DataAddress_o. Por ahora, si solo TX, la RAM responde siempre.

  // ----------------- Display 7 segmentos: PC en HEX -----------------
  logic [19:0] mux_cnt;
  always_ff @(posedge clk_16mhz or posedge rst_sync) begin
    if (rst_sync) mux_cnt <= '0;
    else          mux_cnt <= mux_cnt + 20'd1;
  end

  logic [2:0] digit_sel = mux_cnt[16:14];

  logic [3:0] cur_nibble;
  always_comb begin
    unique case (digit_sel)
      3'd0: cur_nibble = pc_out[3:0];
      3'd1: cur_nibble = pc_out[7:4];
      3'd2: cur_nibble = pc_out[11:8];
      3'd3: cur_nibble = pc_out[15:12];
      3'd4: cur_nibble = pc_out[19:16];
      3'd5: cur_nibble = pc_out[23:20];
      3'd6: cur_nibble = pc_out[27:24];
      3'd7: cur_nibble = pc_out[31:28];
      default: cur_nibble = 4'h0;
    endcase
  end

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
      4'hF: hex_to_7seg = 7'b0001110;
      default: hex_to_7seg = 7'b1111111; // apagado
    endcase
  endfunction

  always_ff @(posedge clk_16mhz or posedge rst_sync) begin
    if (rst_sync) seg <= 7'b1111111;
    else          seg <= hex_to_7seg(cur_nibble);
  end

  always_ff @(posedge clk_16mhz or posedge rst_sync) begin
    if (rst_sync) an <= 8'hFF;
    else begin
      unique case (digit_sel)
        3'd0: an <= 8'b1111_1110;
        3'd1: an <= 8'b1111_1101;
        3'd2: an <= 8'b1111_1011;
        3'd3: an <= 8'b1111_0111;
        3'd4: an <= 8'b1110_1111;
        3'd5: an <= 8'b1101_1111;
        3'd6: an <= 8'b1011_1111;
        3'd7: an <= 8'b0111_1111;
        default: an <= 8'hFF;
      endcase
    end
  end

  // ----------------- LEDs de estado -----------------
  assign led[0]    = status_fifo_tx[9];   // TX empty
  assign led[1]    = status_fifo_tx[10];  // TX full
  assign led[2]    = status_fifo_rx[9];   // RX empty
  assign led[3]    = status_fifo_rx[10];  // RX full
  assign led[4]    = RXAV;                // RX tiene datos
  assign led[5]    = FTXF;                // TX FIFO full
  assign led[6]    = pll_locked;          // PLL lock
  assign led[15:7] = 9'h000;

endmodule

