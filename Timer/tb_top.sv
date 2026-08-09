`timescale 1ns/1ps
module tb_timer_autocheck;

  // reloj en 100 MHz 
  logic clk = 0, reset = 1;
  always #5 clk = ~clk;

  logic [0:0]  addr_i;
  logic [31:0] data_in, data_out;
  logic        write_i;
  logic        timeout_o;

  // instabcia timer
  Timer_Top dut (
    .clk(clk),
    .reset(reset),
    .addr_i(addr_i),
    .data_in(data_in),
    .data_out(data_out),
    .write_i(write_i),
    .timeout_o(timeout_o)
  );

  // ====== Tareas de bus con timing correcto ======
  task bus_write(input bit addr, input logic[31:0] w);
    begin
      @(negedge clk);              // setup antes del flanco
      addr_i  = addr;
      data_in = w;
      write_i = 1'b1;
      @(posedge clk);              // la escritura se registra aquí
      @(negedge clk);
      write_i = 1'b0;
    end
  endtask

  task bus_read(input bit addr, output logic[31:0] r);
    begin
      @(negedge clk);
      addr_i = addr;
      // data_out es combinacional; espera un poco para estabilizar
      #1;
      r = data_out;
    end
  endtask

  // Pequeña ayuda para imprimir conteo y timeout
  task show(input string tag);
    logic [31:0] rd;
    begin
      bus_read(1'b1, rd);   // DATA (contador)
      $display("[%0t ns] %s count=%0d timeout=%0b", $time, tag, rd, timeout_o);
    end
  endtask

  // ====== TEST ======
  logic [31:0] rd;
  initial begin
    $display("==== INICIO TEST ====");
    repeat (3) @(posedge clk);
    reset = 0;

    // Escribir valor de carga
    bus_write(1'b1, 32'd30); 

    // Escribir CONTROL: start=1, autoreload=0
    bus_write(1'b0, 32'h0000_0001);

    // (opcional) limpiar start en el ciclo siguiente
    bus_write(1'b0, 32'h0000_0002);


    @(posedge clk);
    
    bus_read(1'b1, rd);
    $display("[%0t ns] post-load count=%0d timeout=%0b", $time, rd, timeout_o);
    if (rd !== 32'd30) $error("Se esperaba 10 justo después del load, obtuve %0d", rd);

    repeat (50) begin
      @(posedge clk);
      show("run ");
    end

    
    bus_read(1'b0, rd);
    $display("Control reg [2:0] = %b", rd[2:0]);

    $display("==== FIN TEST ====");
    $finish;
  end

endmodule
