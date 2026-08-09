# README – Proyecto Final

## Introducción
Este proyecto implementa el juego completo de **Batalla Naval** sobre un sistema embebido basado en un **microprocesador RISC‑V rv32i**, construido dentro de una FPGA Nexys‑4 DDR. El sistema integra múltiples periféricos mapeados en memoria (MMIO), un controlador VGA para representar el tablero del jugador, una interfaz UART para comunicación bidireccional con una aplicación Python (Jugador 2), un mando físico personalizado para navegación/selección, y un temporizador de turnos totalmente programable.  

El propósito del proyecto es demostrar la capacidad de diseñar, integrar y programar una arquitectura digital completa, desde el hardware en SystemVerilog hasta la lógica del juego escrita completamente en ensamblador RISC‑V.

---

## Resumen del Sistema

El sistema está compuesto por seis grandes bloques:

### 1. **Microprocesador RISC‑V rv32i (núcleo uniciclo)**
Ejecuta el juego completo en ensamblador. Soporta todas las instrucciones rv32i necesarias para control de flujo, operaciones aritméticas, acceso a memoria y periféricos mapeados en direcciones específicas.

### 2. **Memoria ROM (Instrucciones)**
- Dirección base: `0x0000_0000`  
- Almacena el programa ensamblador del juego.  
- Generada con un archivo `.mem`.

### 3. **Memoria RAM (Datos)**
- Dirección base: `0x0000_2000`  
- Guarda información temporal y variables internas del sistema.

### 4. **Ventana MMIO (0x0001_0000 – 0x0001_FFFF)**
A través del módulo `soc_mmio_block`, la CPU interactúa con todos los periféricos:  
- Mando físico (botones filtrados).  
- LEDs.  
- Displays de 7 segmentos.  
- UART (TX/RX) con FSM y FIFOs.  
- Timer programable (30s por turno).  
- Interfaz VGA (cursor, celdas, splash screen).  

### 5. **Controlador VGA**
Genera señal estándar 640×480@60Hz.  
Renderiza 10×10 celdas, cursor, colores y estados del tablero.

### 6. **Jugador 2 – Aplicación Python**
Se comunica por UART (115200 bps).  
Recibe la posición de barcos del Jugador 1, envía su propio tablero, selecciona disparos y recibe resultados.

---

## 2. Arquitectura del Sistema y Mapa de Memoria

### 2.1 Visión General de la Arquitectura

El sistema completo desarrollado para el proyecto **Batalla Naval** se basa en un microcontrolador RISC‑V monociclo personalizado, ampliado con un conjunto de periféricos mapeados en memoria (MMIO) y un flujo de datos que interconecta ROM, RAM, UART, Timer, VGA y el Mando del jugador.  
La comunicación entre todos los módulos sigue una estructura ordenada basada en el bus **APB‑lite**, asegurando transacciones simples y sincronizadas a reloj.

La figura siguiente  resume la arquitectura general:


<img src ="https://raw.githubusercontent.com/Scrys26/Proyecto-Digitales/refs/heads/main/Figuras/Top.png" width="350">
<img src ="https://gitlab.com/el3313-ii2025-g1/proyecto/-/raw/Final/Figuras/Top%20(2).png?ref_type=heads" width="350">
<img src ="https://gitlab.com/el3313-ii2025-g1/proyecto/-/raw/Final/Figuras/Top%20(3).png?ref_type=heads" width="350">
En este diagrama se observa:

- ROM de instrucciones conectada al PC de la CPU.  
- RAM de datos disponible para la lógica del juego.  
- Bloque MMIO actuando como puente entre CPU y periféricos.  
- Controlador VGA para desplegar el tablero local.  
- UART para comunicación bidireccional con la PC.  
- Timer programable de 30 s por turno.  
- Mando físico del jugador 1 conectado por puerto JA.

---

### 2.2 Mapa de Memoria Completo del SoC

El espacio de memoria está organizado de forma clara:

| Región | Dirección Base | Dirección Final | Descripción |
|--------|----------------|-----------------|-------------|
| **ROM (Programa)** | 0x0000_0000 | 0x0000_1FFF | Instrucciones del juego Batalla Naval |
| **RAM (Datos)** | 0x0000_2000 | 0x0000_2FFF | Variables, buffers y almacenamiento temporal |
| **MMIO (Periféricos)** | 0x0001_0000 | 0x0001_FFFF | Direcciones de control de periféricos |

#### Detalle de Periféricos MMIO

| Periférico | Dirección | Uso |
|------------|-----------|-----|
| **Mando – DATA** | 0x0001_0000 | Fila/columna del cursor |
| **Mando – STA** | 0x0001_0004 | Bits de botones (Confirm, Cancel, Rotate) |
| **LEDs** | 0x0001_0010 | Monitoreo de estado |
| **Display 7 segmentos P1** | 0x0001_0020 | Marcador jugador 1 |
| **Display 7 segmentos P2** | 0x0001_0024 | Marcador jugador 2 |
| **UART Control Register** | 0x0001_0040 | Bits enviar/leer, RXAV, FTXF |
| **UART Data** | 0x0001_0044 | Canal TX/RX de bytes |
| **Timer – CTRL** | 0x0001_0050 | Bits START, AUTORELOAD, TIMEOUT |
| **Timer – COUNT** | 0x0001_0054 | Valor de carga y cuenta decreciente |
| **VGA – Base tablero** | 0x0001_0060 | Celdas 10×10 del Jugador 1 |
| **VGA – Cursor Row** | 0x0001_006C | Fila del cursor |
| **VGA – Cursor Col** | 0x0001_007C | Columna del cursor |
| **VGA – Cursor Ctrl** | 0x0001_008C | Activación del cursor |
| **VGA – Splash Ctrl** | 0x0001_009C | Activación de pantalla de inicio |
| **Tablero remoto (PC)** | 0x0001_0200 | 100 bytes | Tablero de Jugador 2 (PC) |

---

## Periférico UART – Interfaz y Funcionamiento

El UART implementa comunicación **bidireccional a 115200 bps 8N1**.  
Está compuesto por:

- FIFO TX (salida)  
- FIFO RX (entrada)  
- Registro de control (RW + RW1C)  
- Mux/Demux  
- Adaptadores de ancho  
- FSM de control (TX/RX)

<img src ="https://gitlab.com/el3313-ii2025-g1/proyecto/-/raw/Final/Figuras/uart_top.png?ref_type=heads" width="350">

### Encabezado del módulo de control

```systemverilog
// uart_control_reg.sv
module uart_control_reg #(
  parameter RESET_VALUE = 32'h0,
  parameter RW1C_MASK   = 32'h0000_0003
)(
  input  logic clk, rst,
  input  logic write,
  input  logic [31:0] wdata,
  ...
);
```

Bits importantes:

- `enviar` (bit0, RW1C)  
- `leer` (bit1, RW1C)  
- `FTXF` (bit2, RO)  
- `RXAV` (bit3, RO)  

---

## Controlador VGA – Tablero Batalla Naval

### 1. Descripción general y bloques

El subsistema VGA genera la salida de vídeo 640×480@60 Hz para mostrar el **tablero de Batalla Naval**, el **cursor** y una **pantalla de splash** inicial.  
Se diseñó de forma **modular**, separando:

- **`Tablero.sv`** – genera sincronismos VGA (HS/VS), coordenadas de píxel y el tablero base centrado con rejilla y rótulos A–J / 1–10.
- **`board_logic.sv`** – mantiene la **matriz de estado 10×10** (barco, fallo, acierto) y dibuja el relleno de cada celda y el marco de **cursor**.
- **`splash_rom.sv`** – ROM de imagen 12 bits (0xRGB) leída con `$readmemh`, usada para el logo/splash inicial.
- **`BattleshipVGA_MMIO.sv`** – puente entre la CPU y la VGA. Decodifica escrituras MMIO, sincroniza dominios de reloj y mezcla las capas (splash, cursor, celdas, fondo).

Diagrama de alto nivel :

```text
CPU (RISC-V) ── soc_mmio_block ──► BattleshipVGA_MMIO
                                      │
                                      ├─► board_logic (estado 10×10 + cursor)
                                      ├─► splash_rom (logo)
                                      └─► Tablero (timing VGA + fondo)
                                               │
                                         HS / VS / RGB
```


---

### 2. Decodificación MMIO y mapa VGA

La CPU actualiza el tablero y el cursor escribiendo en un rango MMIO específico.  
`BattleshipVGA_MMIO` recibe estas señales desde `soc_mmio_block`:

```verilog
input  logic [31:0] vga_waddr_i; // dirección MMIO escrita por la CPU
input  logic [31:0] vga_wdata_i; // datos (usamos [1:0] como estado de celda)
input  logic        vga_we_i;    // pulso de escritura
```

Direcciones relevantes:

- **0x0001_0060 – 0x0001_00FF** → celdas tablero (row/col/state).  
- **0x0001_006C** → `VGA_CUR_ROW`  (fila cursor `[3:0]`).  
- **0x0001_007C** → `VGA_CUR_COL`  (columna cursor `[3:0]`).  
- **0x0001_008C** → `VGA_CUR_CTRL` (bit0 = enable cursor).  
- **0x0001_009C** → `VGA_SPLASH_CTRL` (bit0 = splash ON/OFF).

Ejemplo de escritura de una celda (vista desde hardware):

```verilog
else if (addr_sync >= VGA_BASE &&
         addr_sync <  (VGA_BASE + 32'h00000100)) begin
    logic [31:0] off;
    off = addr_sync - VGA_BASE;

    bl_wr_en    <= 1'b1;
    bl_wr_row   <= off[7:4];     // fila 0..9
    bl_wr_col   <= off[3:0];     // columna 0..9
    bl_wr_state <= data_sync[1:0]; // 00=vacío, 01=barco, 10=fallo, 11=acierto
end
```


---

### 3. Generación de señal VGA – `Tablero.sv`

#### 3.1 Timing 640×480 y ventana visible

`Tablero` toma el reloj de 100 MHz, lo divide a ~25 MHz (`clock_divider`) y genera contadores horizontal y vertical para producir HS/VS y coordenadas `(x_vis, y_vis)` dentro de la zona visible 640×480.

```verilog
clock_divider       VGA_Clock_gen (clk, clk_25M);
horizontal_counter  VGA_Horiz     (clk_25M, enable_V_Counter, H_Count_Value);
vertical_counter    VGA_Verti     (clk_25M, enable_V_Counter, V_Count_Value);

// HS/VS activos en alto (forma "compatible" con el monitor usado)
assign Hsync = (H_Count_Value < 16'd96);
assign Vsync = (V_Count_Value < 16'd2);
```

La ventana visible se define recortando los porches y la zona de sincronismo:

```verilog
localparam int H_VIS_START = 144;
localparam int H_VIS_END   = 783;
localparam int V_VIS_START = 35;
localparam int V_VIS_END   = 514;

logic in_vis = (H_Count_Value >= H_VIS_START && H_Count_Value <= H_VIS_END &&
                V_Count_Value >= V_VIS_START && V_Count_Value <= V_VIS_END);

logic [9:0] x_vis = in_vis ? (H_Count_Value - H_VIS_START) : 10'd0;
logic [9:0] y_vis = in_vis ? (V_Count_Value - V_VIS_START) : 10'd0;
```

#### 3.2 Tablero centrado y rótulos A–J / 1–10

Se reserva un cuadrado de **10×10 celdas de 32×32 px** (320×320) centrado dentro de los 640×480 píxeles.  
Las líneas de la rejilla y el marco se generan a partir de `x_rel` y `y_rel`, y encima de ellas se pintan los rótulos A–J (superior) y 1–10 (izquierda) usando una fuente 8×8 embebida (`font8x8`).

```verilog
localparam int CELLS     = 10;
localparam int CELL_SIZE = 32;         // 10*32 = 320
localparam int BOARD_W   = CELLS * CELL_SIZE;
localparam int BOARD_H   = CELLS * CELL_SIZE;
localparam int X0        = (640 - BOARD_W)/2; // 160
localparam int Y0        = (480 - BOARD_H)/2; // 80;

logic in_board =
    in_vis &&
    (x_vis >= X0) && (x_vis < X0 + BOARD_W) &&
    (y_vis >= Y0) && (y_vis < Y0 + BOARD_H);
```


---

### 4. Memoria de estado, colores y cursor – `board_logic.sv`

#### 4.1 Matriz 10×10 y estados de celda

`board_logic` mantiene una matriz de 10×10 con 2 bits por celda:

- `00` → vacío  
- `01` → barco  
- `10` → fallo (disparo al agua)  
- `11` → acierto (barco impactado)  

```verilog
logic [1:0] cell_state [0:9][0:9];

always_ff @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < 10; i++)
          for (j = 0; j < 10; j++)
            cell_state[i][j] <= 2'b00;
    end else if (wr_en) begin
        if (wr_row < 10 && wr_col < 10) begin
            logic [1:0] st_old = cell_state[wr_row][wr_col];

            // No dejar que un MISS borre un barco ya colocado
            if (st_old == 2'b01 && wr_state == 2'b10)
                cell_state[wr_row][wr_col] <= 2'b01;
            else
                cell_state[wr_row][wr_col] <= wr_state;
        end
    end
end
```

#### 4.2 Pintado por celda

A partir de `x_rel` y `y_rel`, se obtiene `(row_idx, col_idx)` y el módulo decide el color interno de la celda (sin pisar la rejilla ni el texto):

```verilog
logic [3:0] col_idx = x_rel[9:5]; // x_rel / 32
logic [3:0] row_idx = y_rel[9:5]; // y_rel / 32
logic [4:0] lx      = x_rel[4:0]; // 0..31 dentro de celda
logic [4:0] ly      = y_rel[4:0];

logic inside_cell_interior = (lx != 5'd0) && (ly != 5'd0);

always_comb begin
    cell_painted = 1'b0;
    pix_r = 4'h0; pix_g = 4'h0; pix_b = 4'h0;

    if (in_board && inside_cell_interior && !on_grid && !text_on) begin
        unique case (st_cur)
            2'b01: begin // barco
                cell_painted = 1'b1;
                pix_r = 4'h8; pix_g = 4'h8; pix_b = 4'h8;
            end
            2'b10: begin // fallo (agua)
                cell_painted = 1'b1;
                pix_r = 4'h0; pix_g = 4'h0; pix_b = 4'hF;
            end
            2'b11: begin // acierto
                cell_painted = 1'b1;
                pix_r = 4'hF; pix_g = 4'h0; pix_b = 4'h0;
            end
            default: ;
        endcase
    end
end
```

#### 4.3 Cursor con marco coloreado

El cursor se dibuja como un **marco interno** dentro de la celda seleccionada (sin borrar el contenido). Su posición se controla vía MMIO escribiendo `cur_row`, `cur_col` y `cur_en`.

```verilog
logic is_cur_cell = in_board && cur_en &&
                    (col_idx == cur_col) && (row_idx == cur_row);

always_comb begin
    cursor_on = 1'b0;
    cur_r = 4'h0; cur_g = 4'h0; cur_b = 4'h0;

    if (is_cur_cell && on_inner_border) begin
        cursor_on = 1'b1;
        cur_r = CUR_R; cur_g = CUR_G; cur_b = CUR_B; // color configurado por parámetro
    end
end
```

---

### 5. Pantalla de Splash – `splash_rom.sv`

`splash_rom` implementa una ROM 12-bit (0xRGB) donde se carga una imagen preprocesada del logo del juego mediante `$readmemh`.  
El módulo recibe coordenadas `(x, y)` dentro de la ventana del splash y entrega `r, g, b` correspondientes.

```verilog
module splash_rom #(
    parameter int W = 640,
    parameter int H = 232
) (
    input  logic        clk,
    input  logic [9:0]  x,   // 0..W-1
    input  logic [9:0]  y,   // 0..H-1
    output logic [3:0]  r, g, b
);
    localparam int NPIX = W*H;
    logic [11:0] mem [0:NPIX-1];

    initial begin
        $readmemh("BattleShip22.mem", mem);
    end

    logic [11:0] pix;
    always_ff @(posedge clk) begin
        if (x < W && y < H)
            pix <= mem[y*W + x];
        else
            pix <= 12'h9DF; // azul celeste por fuera
    end

    assign r = pix[11:8];
    assign g = pix[7:4];
    assign b = pix[3:0];
endmodule
```

En `BattleshipVGA_MMIO`, el splash se muestra centrado verticalmente:

```verilog
localparam int SPLASH_W  = 640;
localparam int SPLASH_H  = 232;
localparam int SPLASH_Y0 = (480 - SPLASH_H) / 2; // 124 aprox

wire in_splash_area =
    in_vis &&
    (y_vis >= SPLASH_Y0) &&
    (y_vis <  SPLASH_Y0 + SPLASH_H);
```

<img src ="https://gitlab.com/el3313-ii2025-g1/proyecto/-/raw/Final/Figuras/WhatsApp%20Image%202025-11-26%20at%209.19.27%20PM.jpeg?ref_type=heads" width="350">


---

### 6. Mezcla final de capas – `BattleshipVGA_MMIO.sv`

La prioridad de pintado se define así:

1. **Zona no visible** → pantalla negra.  
2. Si `splash_en_reg = 1`:
   - Dentro del área del logo → píxeles de `splash_rom`.
   - Fuera del logo → fondo azul celeste uniforme (R=9, G=D, B=F).
3. Si el splash está apagado:
   - Si `cursor_on = 1` → color del cursor.
   - Si `cell_painted = 1` → color de la celda (barco/fallo/acierto).
   - En caso contrario → color base del `Tablero` (fondo + rejilla + texto).

```verilog
always_comb begin
    if (!in_vis) begin
        vgaRed   = 4'h0;
        vgaGreen = 4'h0;
        vgaBlue  = 4'h0;
    end
    else if (splash_en_reg) begin
        if (in_splash_area) begin
            vgaRed   = splash_r;
            vgaGreen = splash_g;
            vgaBlue  = splash_b;
        end else begin
            vgaRed   = 4'h9;
            vgaGreen = 4'hD;
            vgaBlue  = 4'hF;
        end
    end
    else if (cursor_on) begin
        vgaRed   = cur_r;
        vgaGreen = cur_g;
        vgaBlue  = cur_b;
    end
    else if (cell_painted) begin
        vgaRed   = cell_r;
        vgaGreen = cell_g;
        vgaBlue  = cell_b;
    end
    else begin
        vgaRed   = base_r;
        vgaGreen = base_g;
        vgaBlue  = base_b;
    end
end
```

Con este esquema, la CPU solo necesita:

- Encender/apagar el splash mediante `VGA_SPLASH_CTRL`.
- Actualizar celdas escribiendo estados en el rango `0x0001_0060..0x0001_00FF`.
- Mover el cursor escribiendo en `VGA_CUR_ROW`, `VGA_CUR_COL` y `VGA_CUR_CTRL`.

El resto del pipeline (timing VGA, rejilla, texto, splash, mezcla de colores) se maneja completamente en hardware, garantizando una visualización fluida a 60 Hz sin carga adicional para el procesador.


## Temporizador – Periférico Timer_Top

### 3. Descripción general y bloques

El periférico **Timer** proporciona retardos programables y generación de eventos de timeout dentro del SoC. Se diseñó para ser **simple de mapear en MMIO** y fácil de reutilizar desde software RISC‑V.

Bloques principales:

- **`Timer_Top.sv`** – módulo superior; conecta registros, lógica de control y contador descendente. Exporta el puerto MMIO (`addr_i`, `data_in`, `data_out`, `write_i`) y la salida `timeout_o`.  
- **`Interfaz_Registros.sv`** – decodifica la dirección `addr_i` para separar **registro de control** y **registro de datos**; entrega hacia afuera bits ya decodificados (`start_bit_o`, `autoreload_bit_o`, `load_value_o`) y recibe de vuelta `timeout_flag_i` y `count_value_i`.  
- **`Registro_Control.sv`** – contiene los bits de configuración y estado del temporizador (start, autoreload, timeout_flag).  
- **`Registro_Datos.sv`** – almacena el valor de recarga (`load_value`) y expone el valor de cuenta actual (`count_value_i`) para lectura desde software.  
- **`Control.sv`** – máquina de estados mínima que genera **enable**, **load_en** y latchea el **timeout_flag** a partir de `start_bit`, `autoreload_bit` y el pulso `timeout_in`.  
- **`Contador_descendente.sv`** – contador N‑bits que decrece, genera un pulso de **timeout** de un ciclo al pasar de 1→0 y se recarga con `load_en`.

Diagrama de alto nivel del temporizador dentro del SoC:

<img src ="https://gitlab.com/el3313-ii2025-g1/proyecto/-/raw/Final/Figuras/Timer%20(2).png?ref_type=heads" width="350">

> ```text
> CPU (APB/MMIO) ──► Timer_Top ──► Control + Contador_descendente ──► timeout_o
>                      │
>                      └── Interfaz_Registros (Registro_Control / Registro_Datos)
> ```

---

### 3. Mapa de registros y protocolo de acceso

El temporizador se ve desde software como **dos direcciones MMIO**. En el diseño del SoC, estas direcciones se ubican típicamente en:

- `0x0001_0050` → registro de **control y estado**  
- `0x0001_0054` → registro de **datos (load / count)**  

Dentro del periférico se usan 1 bit de dirección:

| Señal `addr_i` | Registro              | Descripción principal                          |
|----------------|-----------------------|-----------------------------------------------|
| `0`            | **Registro de Control** | `start_bit`, `autoreload_bit`, `timeout_flag` |
| `1`            | **Registro de Datos**   | `load_value` (escritura) / `count_value` (lectura) |

La lógica de decodificación en `Interfaz_Registros` es:

```systemverilog
// Escritura a control o datos según addr_i
assign we_ctrl = write_i & (addr_i == 1'b0);
assign we_data = write_i & (addr_i == 1'b1);

always_comb begin
    // Lectura combinacional según la misma dirección
    data_out = (addr_i == 1'b0) ? control_rdata : data_rdata;
end
```

#### Campos típicos del registro de control

A nivel de comportamiento, el registro de control se usa así:

- **bit 0 – `start_bit` (R/W):**  
  - Software escribe un `1` para **arrancar una cuenta**.  
  - Internamente se detecta el **flanco de subida** para generar un pulso de carga y limpiar el `timeout_flag`.

- **bit 1 – `autoreload_bit` (R/W):**  
  - Si vale `1`, cuando el contador llega a cero se recarga automáticamente (`autoload`) y el temporizador sigue corriendo.  
  - Si vale `0`, el temporizador se detiene al finalizar la cuenta.

- **bit 2 – `timeout_flag` (RO):**  
  - Se pone en `1` cuando el contador llega a cero.  
  - Se limpia automáticamente en el siguiente `start`.

El registro de datos se interpreta como:

- **Escritura (`addr_i = 1`, `write_i = 1`):** valor de recarga `load_value`.  
- **Lectura (`addr_i = 1`, `write_i = 0`):** valor actual del contador `count_value_i`.

---

### 3. Flujo funcional de operación

El comportamiento típico del temporizador se resume en los siguientes pasos:

1. **Configuración del período**  
   - Software escribe el valor deseado de cuenta (en ciclos de reloj) en el **registro de datos** (`addr_i = 1`).  
   - Este valor se almacena en `load_value_o` mediante `Registro_Datos`.

2. **Arranque del temporizador**  
   - Software escribe en el **registro de control** con `start_bit = 1` y el valor deseado para `autoreload_bit`.  
   - El módulo `Control` detecta el **flanco de subida** de `start_bit` y:
     - Limpia el `timeout_flag`.  
     - Pone `running <= 1` (habilita el temporizador).  
     - Genera un pulso registrado `load_en` para cargar el contador.

3. **Conteo descendente**  
   - Mientras `enable_timer = 1` y `load_en = 0`, el módulo `Contador_descendente` decrementa `counter_reg` en cada flanco de reloj.  
   - Si `counter_reg` ya está en 0, permanece en 0 hasta recibir un nuevo `load_en`.

4. **Generación del timeout**  
   - Cuando el contador pasa de 1→0, se genera un pulso **`timeout` de un ciclo** (`timeout_sig`) y se latcha `timeout_flag = 1`.  
   - Al mismo tiempo, la salida `timeout_o` se eleva durante un ciclo, lista para usarse como evento externo (por ejemplo, para cambiar de fase en la FSM del juego).

5. **Autoreload o parada**  
   - Si `autoreload_bit = 1`, ante cada `timeout_in` el módulo `Control`:
     - Mantiene `running = 1`.  
     - Emite un nuevo pulso de `load_en` para recargar el contador con `load_value`.  
   - Si `autoreload_bit = 0`, al ocurrir `timeout_in`:
     - Pone `running = 0` y el temporizador se detiene en cero hasta un nuevo `start`.

6. **Lectura de estado desde software**  
   - El procesador puede leer el **registro de control** (`addr_i = 0`) para consultar `timeout_flag`.  
   - También puede leer el **registro de datos** (`addr_i = 1`) para ver el `count_value` actual.

---

###  Detalles de implementación clave

#### Detección de flanco de `start_bit` y generación de `load_en`

Para que el temporizador sea robusto frente a escrituras de software, la señal `start_bit` no se usa directamente como `load_en`. En su lugar, `Control` implementa un **detector de flanco sincronizado**:

```systemverilog
// Muestreo doble de start_bit para detectar flanco de subida
logic start_q, start_qq;
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        start_q  <= 1'b0;
        start_qq <= 1'b0;
    end else begin
        start_q  <= start_bit;   // valor actual del registro
        start_qq <= start_q;     // valor del ciclo anterior
    end
end

wire start_rise = start_q & ~start_qq;  // pulso 1 ciclo cuando start pasa 0→1

// Generación de load_en registrado
always_ff @(posedge clk or posedge reset) begin
    if (reset) load_en <= 1'b0;
    else       load_en <= start_rise | (timeout_in & autoreload_bit);
end
```

Con esto se garantiza:

- `load_en` dura exactamente **un ciclo completo** de reloj.  
- No depende de la duración del pulso de software (puede escribir `start_bit=1` y luego volver a 0 sin problemas).  
- Se vuelve a generar un `load_en` automáticamente cada vez que se produce un `timeout` y `autoreload_bit=1`.

#### Contador descendente con pulso de timeout limpio

El contador se implementa de forma que el `timeout` sea un **único pulso** al cruzar de 1→0:

```systemverilog
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        counter_reg <= '0;
        timeout     <= 1'b0;
    end else begin
        timeout <= 1'b0;  // por defecto

        if (load_en) begin
            counter_reg <= load_value;
        end else if (enable) begin
            if (counter_reg > '0) begin
                if (counter_reg == {{(WIDTH-1){1'b0}},1'b1}) begin
                    // 1 → 0: generar timeout
                    timeout     <= 1'b1;
                    counter_reg <= '0;
                end else begin
                    counter_reg <= counter_reg - 1'b1;
                end
            end
        end
    end
end
```

Esta implementación evita que el `timeout` se repita mientras el contador permanece en 0 y simplifica su uso desde otras FSMs del sistema.

---

###  Integración típica en el SoC

En el bloque MMIO principal (`soc_mmio_block`), el temporizador se conecta como un periférico más:

```systemverilog
Timer_Top u_timer (
    .clk       (clk),
    .reset     (rst),
    .addr_i    (tim_addr),      // bit 0 de la dirección MMIO
    .data_in   (pwdata),
    .data_out  (tim_rdata),
    .write_i   (tim_we),
    .timeout_o (tim_timeout)
);
```

- `tim_timeout` puede usarse como **señal de evento** para la lógica de juego (cambio de fase, límite de tiempo de turno, etc.).  
- `tim_rdata` se multiplexa junto con el resto de periféricos para formar `prdata` en la ventana MMIO.

Con este diseño, el temporizador queda totalmente controlable desde software RISC‑V mediante solo **dos direcciones MMIO**, pero internamente mantiene una arquitectura bien estructurada y fácil de extender (por ejemplo, para añadir interrupciones o más modos de operación en el futuro).


## Periférico MMIO del SoC 

### 1. Descripción general y bloques

El módulo **`soc_mmio_block`** implementa la **ventana de periféricos mapeados en memoria (MMIO)** del SoC, en el rango `0x0001_0000 – 0x0001_FFFF`.  
Traduce las operaciones de **load/store** del núcleo RISC‑V hacia periféricos discretos:

- **Mando / Control** (solo lectura) – coordenadas del cursor y estado de botones (`MANDO_DAT`, `MANDO_STA`).  
- **LEDs** – registro RW de 16 bits visibles en la Nexys.  
- **Display de 7 segmentos** – dos dígitos independientes RW.  
- **UART** – interfaz con el periférico de comunicación serie (`Interfaz_UART`).  
- **Timer** – conexión al temporizador general (`Timer_Top`).  
- **VGA** – puerto abstracto para el tablero del Jugador 1.  
- **Tablero remoto** – ventana MMIO para almacenar el estado del tablero del PC (jugador 2).  

Diagrama de alto nivel :  

```text
CPU RISC-V
   | addr_i, wdata_i, we_i, re_i
   v
+---------------------+
|   soc_mmio_block    |
|  (decodificación)   |
+---------------------+
  | MANDO   | LEDs/7seg  | UART | TIMER | VGA | BOARD_REMOTO |
```

---

### 2. Decodificación de direcciones

El bloque usa una **comparación de los 16 bits altos** de la dirección para detectar si una operación cae dentro de la ventana MMIO:

```verilog
assign mmio_hit_o = (addr_i[31:16] == MMIO_BASE[31:16]);
```

Luego, define **constantes de dirección** para cada periférico:

```verilog
localparam logic [31:0]
  ADDR_CTRL_IN_DATA   = 32'h0001_0000, // MANDO_DAT
  ADDR_CTRL_BTN_STATE = 32'h0001_0004, // MANDO_STA
  ADDR_LEDS_DATA      = 32'h0001_0010,
  ADDR_SEG_DIG0       = 32'h0001_0020,
  ADDR_SEG_DIG1       = 32'h0001_0024,
  ADDR_UART_CTRLSTAT  = 32'h0001_0040,
  ADDR_UART_DATA      = 32'h0001_0044,
  ADDR_TIM_CTRLSTAT   = 32'h0001_0050,
  ADDR_TIM_COUNTER    = 32'h0001_0054,
  ADDR_VGA_BASE       = 32'h0001_0060,
  ADDR_VGA_LIMIT      = 32'h0001_00FF,
  ADDR_BOARD_BASE     = 32'h0001_0200,
  ADDR_BOARD_LIMIT    = 32'h0001_0263;
```

A partir de estas constantes se generan **señales de selección** por periférico, por ejemplo:

```verilog
wire sel_leds      = mmio_hit_o && (addr_i == ADDR_LEDS_DATA);
wire sel_seg0      = mmio_hit_o && (addr_i == ADDR_SEG_DIG0);
wire sel_seg1      = mmio_hit_o && (addr_i == ADDR_SEG_DIG1);
wire sel_vga       = mmio_hit_o &&
                     (addr_i >= ADDR_VGA_BASE) &&
                     (addr_i <= ADDR_VGA_LIMIT);
wire sel_board     = mmio_hit_o &&
                     (addr_i >= ADDR_BOARD_BASE) &&
                     (addr_i <= ADDR_BOARD_LIMIT);
```

De esta forma, el bloque actúa como un **decoder** de direcciones y genera `sel_*` que se usarán para escritura/lectura en cada periférico.

---

### 3. LEDs y display de 7 segmentos

Los periféricos **LEDs** y **7 segmentos** se implementan con el registro genérico **`mmio_reg`**, que soporta bits RW, RO y *write‑1‑to‑clear* (RW1C).

#### 3.1 LEDs (registro RW de 32 bits)

```verilog
logic [31:0] leds_q;
logic [31:0] leds_rdata;

mmio_reg #(
  .RESET_VALUE(32'h0000_0000),
  .RW1C_MASK  (32'h0000_0000),
  .RO_MASK    (32'h0000_0000)
) u_leds (
  .clk        (clk),
  .rst        (rst),
  .sel_i      (sel_leds),
  .we_i       (we_i),
  .wdata_i    (wdata_i),
  .rdata_o    (leds_rdata),
  .set_bits_i (32'h0000_0000),
  .ro_bits_i  (32'h0000_0000),
  .q          (leds_q)
);

assign leds_o = leds_q[15:0];
```

- La CPU escribe en `ADDR_LEDS_DATA` para actualizar `leds_q`.  
- Sólo los bits `[15:0]` se conectan físicamente a la tarjeta (`leds_o`).  
- En lectura (`load`), la CPU ve el valor completo de 32 bits.

#### 3.2 Display de 7 segmentos

Se usan **dos instancias** de `mmio_reg` para cada dígito:

```verilog
mmio_reg u_seg0 ( ... .sel_i(sel_seg0), .q(seg0_q) );
mmio_reg u_seg1 ( ... .sel_i(sel_seg1), .q(seg1_q) );

assign seg_digit0_o = seg0_q[7:0];
assign seg_digit1_o = seg1_q[7:0];
```

- El software escribe el patrón codificado para cada dígito en `ADDR_SEG_DIG0` y `ADDR_SEG_DIG1`.  
- En hardware, sólo se usan los 8 bits bajos para cada display.


---

### 4. Interfaz con UART

La conexión con el periférico **UART** se realiza de forma directa, reutilizando la lógica de **registro de control/datos** implementada en `Interfaz_UART`.

```verilog
always_comb begin
  uart_entrada_o  = wdata_i;

  if (sel_uart_data)
    uart_reg_sel_o = 1'b1;
  else
    uart_reg_sel_o = 1'b0;

  uart_wr_o = we_i && (sel_uart_ctrl || sel_uart_data);
end
```

- `ADDR_UART_CTRLSTAT` → acceso al **registro de control/estado** (cuando `reg_sel=0`).  
- `ADDR_UART_DATA` → acceso a **registros de datos/FIFO** (cuando `reg_sel=1`).  
- Las lecturas desde cualquiera de las dos direcciones retornan `uart_salida_i`:

```verilog
sel_uart_ctrl,
sel_uart_data : rdata_o = uart_salida_i;
```

El bloque MMIO no interpreta el significado de los bits del UART, solo **firma** las lecturas/escrituras y entrega los buses hacia el módulo especializado.

---

### 5. Interfaz con el Timer (`Timer_Top`)

El temporizador del sistema se mapea en dos direcciones consecutivas:

- `ADDR_TIM_CTRLSTAT` → registro de control/estado (`addr=0`).  
- `ADDR_TIM_COUNTER` → valor de conteo (`addr=1`).  

La lógica de conexión es:

```verilog
always_comb begin
  tim_addr_o  = (sel_tim_cnt) ? 1'b1 : 1'b0; // 0: CTRL, 1: COUNTER
  tim_wdata_o = wdata_i;
  tim_wr_o    = we_i && (sel_tim_ctrl || sel_tim_cnt);
end
```

En lectura, cualquier acceso a estas direcciones retorna el bus `tim_rdata_i`:

```verilog
sel_tim_ctrl,
sel_tim_cnt : rdata_o = tim_rdata_i;
```

Así, el **núcleo RISC‑V** puede:

1. Configurar el timer escribiendo en la dirección de control.  
2. Cargar el valor de cuenta inicial.  
3. Leer el valor actual del contador o la bandera de `timeout` según la implementación de `Timer_Top`.

---

### 6. Puerto MMIO hacia VGA (tablero local)

La ventana **VGA** ocupa el rango `0x0001_0060 – 0x0001_00FF`. Cada dirección representa una celda del tablero o un registro de control interno del componente VGA.

```verilog
wire sel_vga = mmio_hit_o &&
               (addr_i >= ADDR_VGA_BASE) &&
               (addr_i <= ADDR_VGA_LIMIT);

always_comb begin
  vga_we_o    = we_i && sel_vga;
  vga_waddr_o = addr_i;
  vga_wdata_o = wdata_i;
end
```

- En escritura, la CPU genera `vga_we_o=1` y entrega dirección/datos al módulo `BattleshipVGA_MMIO`.  
- Ese módulo decodifica internamente si la escritura es sobre una **celda** del tablero, el **cursor** o el **control del splash**.

---

### 7. Tablero remoto MMIO (jugador PC)

Para el tablero del jugador remoto (PC) se reservó una ventana MMIO separada:

- Base: `ADDR_BOARD_BASE = 0x0001_0200`  
- Límite: `ADDR_BOARD_LIMIT = 0x0001_0263` (100 bytes, 10×10)

La selección es:

```verilog
wire sel_board = mmio_hit_o &&
                 (addr_i >= ADDR_BOARD_BASE) &&
                 (addr_i <= ADDR_BOARD_LIMIT);
```

Este espacio se atiende con el módulo **`remote_board_mmio`**:

```verilog
remote_board_mmio #(
  .BASE_ADDR(ADDR_BOARD_BASE),
  .CELLS    (100)
) u_remote_board (
  .clk     (clk),
  .rst     (rst),
  .addr_i  (addr_i),
  .wdata_i (wdata_i),
  .we_i    (we_i),
  .re_i    (re_i),
  .rdata_o (board_rdata)
);
```

- La CPU puede **escribir** aquí la información recibida por UART desde el PC (posiciones de barcos/enemigo).  
- También puede **leer** este espacio para consultar estado o depuración.  
- En la multiplexación final de lectura, si `sel_board=1`, `rdata_o` se toma de `board_rdata`:

```verilog
sel_board : rdata_o = board_rdata;
```
---

### 8. Multiplexor global de lectura

Finalmente, todas las rutas de lectura convergen en un **multiplexor único** que alimenta `rdata_o` hacia el núcleo RISC‑V.  
Este mux se implementa con un `case` sobre las señales de selección `sel_*`:

```verilog
always_comb begin
  rdata_o = 32'h0000_0000;

  if (re_i && mmio_hit_o) begin
    unique case (1'b1)
      sel_ctrl_in   : rdata_o = ctrl_in_data_i;
      sel_ctrl_btn  : rdata_o = ctrl_btn_state_i;

      sel_leds      : rdata_o = leds_rdata;
      sel_seg0      : rdata_o = seg0_rdata;
      sel_seg1      : rdata_o = seg1_rdata;

      sel_uart_ctrl,
      sel_uart_data : rdata_o = uart_salida_i;

      sel_tim_ctrl,
      sel_tim_cnt   : rdata_o = tim_rdata_i;

      sel_board     : rdata_o = board_rdata;

      default       : rdata_o = 32'h0000_0000;
    endcase
  end
end
```

De este modo:

- Solo si `re_i=1` y la dirección cae en la ventana MMIO (`mmio_hit_o=1`), se produce una lectura válida.  
- Cada periférico responde únicamente cuando su señal `sel_*` está activa.  
- El resto del espacio de direcciones se considera **no mapeado** (retorna 0).

---

Con este diseño, `soc_mmio_block` actúa como el **hub central** de periféricos del SoC: encapsula todo el **mapeo de direcciones**, desacopla la lógica del CPU de los detalles de cada módulo físico (UART, Timer, VGA, Mando, tableros) y permite extender el sistema agregando nuevos periféricos sin modificar la arquitectura del procesador.

## Mando tipo JA – Generador de MANDO_DAT / MANDO_STA

### 1. Descripción general

El módulo **`mando_ja_mmio`** implementa un control tipo “mando” de **7 botones** conectado al cabezal **JA** (o botones de la Nexys 4).  
Su función es traducir eventos físicos de botones a dos registros de 32 bits que el SoC lee como MMIO:

- **`MANDO_DAT` (0x0001_0000)**  
  - `[7:4]` → fila del cursor (0..9).  
  - `[3:0]` → columna del cursor (0..9).  
  - Resto de bits en **0**.

- **`MANDO_STA` (0x0001_0004)**  
  - `bit0` → `BTN_CONFIRM` (confirmar / disparar / aceptar).  
  - `bit1` → `BTN_CANCEL`  (cancelar / regresar).  
  - `bit2` → `BTN_ROTATE`  (rotar barco).  
  - Bits restantes en **0** (reservados).

La CPU **no ve directamente los botones**, sino estos dos registros ya “empaquetados”, que se leen desde `soc_mmio_block` y se usan en el programa en ensamblador para mover el cursor y detectar acciones de juego.

---

### 2. Bloques y señales principales

Entradas físicas desde la placa:

- **Dirección (4 botones)**  
  - `btn_up`, `btn_down`, `btn_left`, `btn_right`  
  Controlan la posición **(fila, columna)** del cursor lógico en un tablero 10×10.

- **Acción (3 botones)**  
  - `btn_confirm` → confirmar acción (seleccionar celda, disparar, aceptar barco, etc.).  
  - `btn_cancel`  → cancelar acción (regresar de menú, borrar barco, etc.).  
  - `btn_rotate`  → rotar orientación del barco.

Salidas hacia el SoC (leídas por `soc_mmio_block`):

- `mando_dat_o[7:4]` = `row`, `mando_dat_o[3:0]` = `col`.  
- `mando_sta_o[2:0]` = `{btn_rotate, btn_cancel, btn_confirm}`.

Estas señales se conectan en `soc_mmio_block` a las direcciones `ADDR_CTRL_IN_DATA` y `ADDR_CTRL_BTN_STATE`, que luego el ensamblador accede con las etiquetas `MANDO_DAT` y `MANDO_STA`.

---

### 3. Movimiento del cursor 10×10 (row/col)

El módulo mantiene internamente dos registros de 4 bits:

- `row` – índice de fila (0..9).  
- `col` – índice de columna (0..9).  

Ambos se inicializan en **0** tras un `reset` y solo se actualizan con **flancos de subida** en los botones de dirección, para evitar repetir múltiples movimientos mientras el usuario mantiene el botón presionado.

```verilog
logic [3:0] row;  // 0..9
logic [3:0] col;  // 0..9

logic up_q, down_q, left_q, right_q;

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        row     <= 4'd0;
        col     <= 4'd0;
        up_q    <= 1'b0;
        down_q  <= 1'b0;
        left_q  <= 1'b0;
        right_q <= 1'b0;
    end else begin
        // Muestras previas de los botones de dirección
        up_q    <= btn_up;
        down_q  <= btn_down;
        left_q  <= btn_left;
        right_q <= btn_right;

        // Flanco de subida en UP: mover una fila hacia arriba (si es posible)
        if (btn_up & ~up_q) begin
            if (row > 4'd0)
                row <= row - 4'd1;
        end

        // Flanco de subida en DOWN: mover una fila hacia abajo (si es posible)
        if (btn_down & ~down_q) begin
            if (row < 4'd9)
                row <= row + 4'd1;
        end

        // Flanco de subida en LEFT: mover una columna hacia la izquierda
        if (btn_left & ~left_q) begin
            if (col > 4'd0)
                col <= col - 4'd1;
        end

        // Flanco de subida en RIGHT: mover una columna hacia la derecha
        if (btn_right & ~right_q) begin
            if (col < 4'd9)
                col <= col + 4'd1;
        end
    end
end
```

**Puntos clave:**

- Se guardan versiones anteriores de cada botón (`*_q`) para poder detectar el patrón `btn & ~btn_q` (**flanco de subida**).  
- El cursor está limitado al rango **0..9** en fila y columna, de modo que nunca sale del tablero.  
- Cada pulsación “discreta” mueve exactamente una celda el cursor.

---

### 4. Codificación de `MANDO_DAT`

Una vez actualizados `row` y `col`, el módulo forma el registro `mando_dat_o` de 32 bits, ubicando fila y columna en los nibbles bajos:

```verilog
always_comb begin
    mando_dat_o       = 32'h0000_0000;
    mando_dat_o[7:4]  = row; // fila  (0..9)
    mando_dat_o[3:0]  = col; // columna (0..9)
end
```

El resto de bits se mantiene en **0**, dejando espacio para posibles extensiones futuras (otros flags o campos adicionales).

Este registro se lee desde la CPU para saber la posición actual del cursor, por ejemplo:

```asm
    lw   t0, MANDO_DAT(gp)    # t0[7:4] = fila, t0[3:0] = col
```

---

### 5. Codificación de `MANDO_STA`

Los tres botones de acción se exportan como **niveles lógicos**, sin lógica de flanco dentro del hardware. La detección de flancos se realiza en ensamblador comparando con una copia previa de `MANDO_STA` almacenada en RAM.

```verilog
always_comb begin
    mando_sta_o       = 32'h0000_0000;
    mando_sta_o[0]    = btn_confirm; // bit0: CONFIRM
    mando_sta_o[1]    = btn_cancel;  // bit1: CANCEL
    mando_sta_o[2]    = btn_rotate;  // bit2: ROTATE
    // resto de bits = 0
end
```

En software se suele mantener una variable `MSTA_PREV` para hacer algo como:

```asm
    lw   t0, MANDO_STA(gp)     # estado actual de botones de acción
    lw   t1, MSTA_PREV(gp)     # estado anterior

    andi t2, t0, 0x1           # extraer bit0 (CONFIRM)
    andi t3, t1, 0x1
    beq  t2, t3, no_new_confirm

    # aquí se detectó un flanco en CONFIRM (cambio 0→1)
no_new_confirm:

    sw   t0, MSTA_PREV(gp)     # actualizar estado previo
```

De esta forma, el hardware se mantiene **simple y genérico**, y la lógica específica de juego (qué significa confirmar, cancelar o rotar) se implementa en el programa en ensamblador.

---


## Núcleo RISC‑V uniciclo 

Este módulo implementa un **procesador RISC‑V de un solo ciclo** con una interfaz “académica” clara hacia memorias externas:

- **ROM de programa** (instrucciones) a través de `ProgAddress_o` / `ProgIn_i`  
- **RAM/MMIO de datos** mediante `DataAddress_o`, `DataOut_o`, `DataIn_i`  
- Señales explícitas de control de memoria: `we_o`, `mem_read_o`, `one_byte_o`, `two_bytes_o`, `four_bytes_o`  

Todo el ciclo de ejecución de una instrucción (IF, ID, EX, MEM, WB) ocurre en **un solo ciclo de reloj**.

---

### 1. Puertos e interfaz externa

```verilog
module uniciclo #(
  parameter WIDTH           = 32,
  parameter INST_MEM_DEPTH  = 8,
  parameter REG_FILE_DEPTH  = 5,
  parameter DATA_MEM_DEPTH  = 16,
  parameter INST_SIZE       = 32
)(
  input  logic              clk_i,
  input  logic              rst_i,

  // ROM externa
  output logic [31:0]       ProgAddress_o,
  input  logic [31:0]       ProgIn_i,

  // RAM / MMIO externos
  output logic [31:0]       DataAddress_o,
  output logic [31:0]       DataOut_o,
  input  logic [31:0]       DataIn_i,

  // strobes/controles de datos
  output logic              we_o,         // write enable
  output logic              mem_read_o,   // read enable
  output logic              one_byte_o,
  output logic              two_bytes_o,
  output logic              four_bytes_o,

  // debug
  output logic [WIDTH-1:0]  pc_out
);
```

- `ProgAddress_o` → dirección de programa (PC) hacia la **ROM**.  
- `ProgIn_i` → instrucción leída desde ROM.  
- `DataAddress_o` / `DataOut_o` / `DataIn_i` → interfaz de **datos** hacia RAM o bloque MMIO.  
- `we_o` / `mem_read_o` → selectores de **escritura/lectura** de datos.  
- `one_byte_o`, `two_bytes_o`, `four_bytes_o` → tipo de acceso (byte, halfword o word).  
- `pc_out` → PC visible externamente para **debug** (uso en testbench o mapeo a 7 segmentos).  

---

### 2. Bloques principales internos

El núcleo está estructurado en bloques clásicos de un diseño de procesador:

- **Registro de programa (PC)** – `register`  
- **Sumadores** para `PC+4` y `PC+imm` – `adder`  
- **Registro de registros (reg_file)** – banco de 32 registros x 32 bits  
- **Generador de inmediatos (imm_gen)** – decodifica tipos I, S, B, U, J  
- **ALU** – operaciones aritmético‑lógicas y comparaciones de ramas  
- **Multiplexores** – seleccionan operandos ALU y datos de escritura de registro  
- **Unidad de control (control_deco)** – decodifica la instrucción y genera las señales de control globales  

Diagrama conceptual (a integrar por el estudiante):

> _[Figura_: diagrama de bloques uniciclo con IF/ID/EX/MEM/WB y buses de Prog/Data]_

---

### 3. Camino de instrucciones (IF) y PC

El PC se almacena en un registro y se actualiza cada ciclo según la lógica de salto/ramas:

```verilog
// Registro de PC
register #(.WIDTH(WIDTH)) u_pc (
  .clk     (clk_i),
  .rst     (rst_i),
  .data_in (pc_next),
  .wr      (1'b1),
  .data_out(pc_out)
);

// PC + 4
adder #(.WIDTH(WIDTH)) u_pc_plus4 (
  .A   (pc_out),
  .B   (32'd4),
  .out (pc_4)
);

// Multiplexor de próximo PC (señal if_mux_sel viene de control)
mux_4_1 #(.WIDTH(WIDTH)) u_if_mux (
  .A   (pc_4),        // secuencial
  .B   (pc_plus_imm), // ramas
  .C   (jalr_target), // JALR
  .D   (pc_4),        // reservado
  .sel (if_mux_sel),
  .out (pc_next)
);

assign ProgAddress_o = pc_out; // dirección hacia ROM
```

- **`pc_4`**: siguiente PC secuencial.  
- **`pc_plus_imm`**: destino de ramas (PC relativo).  
- **`jalr_target`**: destino absoluto AND ~1 (ajuste RISC‑V).  
- **`if_mux_sel`**: se define en `control_deco` según opcode, comparación de ramas, etc.

La instrucción actual entra directamente desde la ROM:

```verilog
wire [WIDTH-1:0] instruction = ProgIn_i;
```

---

### 4. Decodificación y banco de registros (ID)

En la etapa de decodificación se leen los registros fuente y se genera el inmediato:

```verilog
// Banco de registros
reg_file #(.WIDTH(WIDTH), .DEPTH(REG_FILE_DEPTH)) u_rf (
  .clk              (clk_i),
  .rst              (rst_i),
  .write_data       (wb_data),
  .write_register   (instruction[11:7]),   // rd
  .wr               (reg_file_wr),
  .read_register_1  (instruction[19:15]),  // rs1
  .read_register_2  (instruction[24:20]),  // rs2
  .rd               (1'b1),
  .read_data_1      (rs1_data),
  .read_data_2      (rs2_data)
);

// Generador de inmediatos
imm_gen #(.WIDTH(WIDTH)) u_imm (
  .instr    (instruction),
  .data_out (immediate)
);
```

- `reg_file_wr` controla la escritura en `rd` (bit de writeback desde `control_deco`).  
- `rs1_data` y `rs2_data` alimentan la **ALU** y el **camino de MEM** (stores).  
- `immediate` es el desplazamiento/constante según el tipo de instrucción.

---

### 5. Ejecución (EX): ALU y caminos de salto

La unidad de ejecución selecciona el segundo operando de la ALU y realiza la operación aritmético‑lógica o de comparación:

```verilog
// Selección segundo operando ALU: rs2 o inmediato
mux_2_1 #(.WIDTH(WIDTH)) u_ex_mux (
  .A   (rs2_data),
  .B   (immediate),
  .sel (ex_mux_sel),
  .out (alu_b_sel)
);

// ALU principal
alu #(.WIDTH(WIDTH)) u_alu (
  .data_in_1  (rs1_data),
  .data_in_2  (alu_b_sel),
  .func3      (instruction[14:12]),
  .func7      (instruction[31:25]),
  .opcode     (instruction[6:0]),
  .data_out   (alu_out),
  .zero       (/*unused*/),
  .comparison (comparison)
);

// PC + imm (para ramas PC‑relativas)
adder #(.WIDTH(WIDTH)) u_pc_plus_imm (
  .A   (pc_out),
  .B   (immediate),
  .out (pc_plus_imm)
);

// Destino JALR: LSB en 0
assign jalr_target = alu_out & ~32'd1;
```

- `ex_mux_sel` selecciona entre **registro** (`rs2`) o **inmediato** como segundo operando.  
- `alu_out` sirve tanto como **resultado ALU** como **dirección efectiva** de memoria.  
- `comparison` indica el resultado de comparaciones de ramas (igual, menor, mayor o igual, etc.) usado por el control.

---

### 6. Acceso a memoria (MEM) y bus externo

El diseño expone el acceso a datos a través de un bus simple, compatible con RAM o bloques MMIO:

```verilog
// Dirección efectiva hacia RAM/MMIO
assign DataAddress_o = alu_out;   // base + offset

// Dato a escribir (stores: contenido de rs2)
assign DataOut_o     = rs2_data;

// Señales de control de memoria
assign we_o          = mem_write; // escritura
assign mem_read_o    = mem_read;  // lectura

assign one_byte_o    = one_byte;
assign two_bytes_o   = two_bytes;
assign four_bytes_o  = four_bytes;
```

Las señales `mem_write`, `mem_read`, `one_byte`, `two_bytes`, `four_bytes` son generadas por el decodificador de control según el opcode (`SB`, `SH`, `SW`, `LB`, `LH`, `LW`, etc.).  
El dato leído desde memoria o MMIO (`DataIn_i`) entra luego en la etapa de **writeback**.

---

### 7. Writeback (WB)

El valor a escribir en el banco de registros se selecciona mediante un multiplexor de 4 entradas, gobernado por `wb_mux_sel`:

```verilog
mux_4_1 #(.WIDTH(WIDTH)) u_wb_mux (
  .A   (alu_out),    // resultado ALU
  .B   (DataIn_i),   // lectura de RAM/MMIO
  .C   (pc_4),       // PC+4 (JAL / JALR)
  .D   (pc_plus_imm),// PC+imm (opcional)
  .sel (wb_mux_sel),
  .out (wb_data)
);
```

Casos típicos según instrucción:

- **`ADD`, `AND`, `OR`, etc.** → `wb_data = alu_out`  
- **`LW`, `LH`, `LB`** → `wb_data = DataIn_i`  
- **`JAL`, `JALR`** → `wb_data = pc_4` (dirección de retorno)  
- Otras variantes pueden usar `pc_plus_imm` para instrucciones específicas.

---

### 8. Unidad de control (`control_deco`)

El módulo `control_deco` recibe la instrucción completa y la señal `comparison` de la ALU y genera todas las señales de control:

```verilog
control_deco #(.INST_SIZE(INST_SIZE)) u_ctrl (
  .instr       (instruction),
  .comparison  (comparison),
  .if_mux_sel  (if_mux_sel),
  .ex_mux_sel  (ex_mux_sel),
  .wb_mux_sel  (wb_mux_sel),
  .reg_file_rd (/*unused*/),
  .reg_file_wr (reg_file_wr),
  .mem_read    (mem_read),
  .mem_write   (mem_write),
  .one_byte    (one_byte),
  .two_bytes   (two_bytes),
  .four_bytes  (four_bytes)
);
```

Responsabilidades principales de la unidad de control:

- Decodificar **opcode**, `funct3`, `funct7` para identificar el tipo de instrucción.  
- Decidir cuándo y qué escribir en el banco de registros (`reg_file_wr`).  
- Seleccionar el **próximo PC** (`if_mux_sel`) según saltos/ramas.  
- Habilitar lecturas/escrituras de memoria (`mem_read`, `mem_write`).  
- Determinar el tamaño del acceso (`one_byte`, `two_bytes`, `four_bytes`).  
- Configurar el camino de writeback (`wb_mux_sel`) según la instrucción.

---

Este diseño uniciclo prioriza la **claridad arquitectónica** (IF‑ID‑EX‑MEM‑WB en un solo ciclo) y expone una interfaz limpia para conectar memorias, periféricos MMIO y lógica de testbench o depuración.

## SoC RISC‑V Battleship – `soc_top.sv`

### 1. Descripción general

El módulo `soc_top` integra **todo el sistema en la FPGA**:

- Núcleo **RISC‑V uniciclo** (pipeline IF–ID–EX–WB en un solo ciclo).
- **ROM de instrucciones** (programa del juego en ensamblador).
- **RAM de datos** (pila, variables, buffers).
- Bloque **MMIO** con:
  - Mando físico de 7 botones (`mando_ja_mmio`).
  - **UART** reutilizada del **Laboratorio 3** (`Interfaz_UART` + FIFOs).
  - Temporizador programable (`Timer_Top`).
  - Control de **LEDs** y **display de 7 segmentos**.
  - Interfaz de video **VGA Battleship** (`BattleshipVGA_MMIO`).

Diagrama conceptual (referencia, la imagen se agrega luego):

![soc_top](Figuras/soc_top.png)

---

### 2. Reloj, reset y mando

#### 2.1 Generación de reloj y reset síncrono

```verilog
clk_wiz_0 clk_inst (
    .clk_out1 (clk_16mhz_i),
    .reset    (rst),
    .locked   (locked),
    .clk_in1  (clk)
);
```

- La FPGA entra con **100 MHz** (`clk`).  
- Un PLL (`clk_wiz_0`) genera un reloj intermedio de **~16 MHz** (`clk_16mhz_i`) para el **núcleo, memorias y periféricos**.  
- La señal `locked` indica que el PLL está estable.  
- Se genera un **reset sincronizado** a 16 MHz:

```verilog
always_ff @(posedge clk_16mhz_i or posedge rst) begin
    if (rst)
        rst_sync <= 1'b1;
    else if (!locked)
        rst_sync <= 1'b1;
    else
        rst_sync <= 1'b0;
end
```

> `rst_sync` se usa como reset global **síncrono** en casi todos los módulos.

#### 2.2 Mando físico → registros MMIO (`MANDO_DAT`, `MANDO_STA`)

El módulo `mando_ja_mmio` convierte 7 botones físicos en dos registros MMIO:

```verilog
mando_ja_mmio u_mando (
    .clk         (clk_16mhz_i),
    .rst         (rst_sync),
    .btn_up      (ja_up),
    .btn_down    (ja_down),
    .btn_left    (ja_left),
    .btn_right   (ja_right),
    .btn_confirm (ja_confirm),
    .btn_cancel  (ja_cancel),
    .btn_rotate  (ja_rotate),
    .mando_dat_o (mando_dat),
    .mando_sta_o (mando_sta)
);
```

- `mando_dat` → `MANDO_DAT` (0x0001_0000):  
  - `[7:4]` = fila (0..9), `[3:0]` = columna (0..9).
- `mando_sta` → `MANDO_STA` (0x0001_0004):  
  - bit0 = **CONFIRM**, bit1 = **CANCEL**, bit2 = **ROTATE**.

El núcleo accede estas coordenadas/flags leyendo MMIO a través de `soc_mmio_block`.

---

### 3. Memorias del sistema

#### 3.1 ROM de instrucciones (`inst_mem`)

```verilog
localparam int INST_MEM_WIDTH = 32;
localparam int INST_MEM_DEPTH = 15; // 2^15 bytes = 32 kB

inst_mem #(
    .WIDTH(INST_MEM_WIDTH),
    .DEPTH(INST_MEM_DEPTH)
) u_rom (
`ifdef MULTICYCLE
    .clk      (clk_16mhz_i),
`endif
    .rst      (rst_sync),
    .data_in  (32'b0),
    .addr     (ProgAddress_o),
    .wr       (1'b0),
    .rd       (1'b1),
    .data_out (instruction)
);

assign ProgIn_i = instruction;
```

- **ROM solo lectura**: se carga con el programa del juego (archivo `.mem`).  
- Interfaz simple:
  - `addr` = PC (`ProgAddress_o`).  
  - `data_out` = instrucción de 32 bits (`ProgIn_i`).  
- El núcleo **no puede escribir** la ROM (`wr = 0`).

> Esta memoria contiene toda la lógica de juego: fases, turnos, uso de UART, timer y VGA.

#### 3.2 RAM de datos (`data_mem`)

Región lógica en el mapa de memoria:

- **0x0000_2000 – 0x0000_2FFF** → RAM de datos (4 kB).

Detección de acceso:

```verilog
assign is_data_ram =
    (DataAddress_o >= 32'h0000_2000) &&
    (DataAddress_o <  32'h0000_3000);

assign ram_wr = we_o       && is_data_ram;
assign ram_rd = mem_read_o && is_data_ram;
```

Instancia de la RAM:

```verilog
localparam int DATA_MEM_WIDTH = 32;
localparam int DATA_MEM_DEPTH = 16; // usa bits [15:0] de la dirección

data_mem #(
    .WIDTH(DATA_MEM_WIDTH),
    .DEPTH(DATA_MEM_DEPTH)
) u_ram (
    .clk        (clk_16mhz_i),
    .rst        (rst_sync),
    .data_in    (DataOut_o),
    .addr       (DataAddress_o[DATA_MEM_DEPTH-1:0]),
    .wr         (ram_wr),
    .rd         (ram_rd),
    .one_byte   (one_b),
    .two_bytes  (two_b),
    .four_bytes (four_b),
    .data_out   (data_mem_rdata)
);
```

- Usa **señales de tamaño** (`one_b`, `two_b`, `four_b`) para soportar:
  - `lb/lh/lw` y `sb/sh/sw` del ISA RISC‑V.
- El núcleo ve esta RAM como **memoria principal** para:
  - Pila (`sp`).  
  - Variables globales y de juego.  
  - Buffers temporales (ej. datos UART).

#### 3.3 Mux de lectura: RAM vs MMIO

```verilog
always_comb begin
    DataIn_i = 32'h0000_0000;

    if (mmio_hit) begin
        DataIn_i = mmio_rdata;     // periféricos
    end else if (is_data_ram) begin
        DataIn_i = data_mem_rdata; // RAM
    end
end
```

- Si la dirección cae en **MMIO** → el dato viene de `soc_mmio_block`.  
- Si cae en **RAM de datos** → el dato viene de `data_mem`.  
- Si no cae en ninguna, el valor por defecto es 0 (espacio vacío).

---

### 4. Núcleo RISC‑V uniciclo

```verilog
uniciclo #(
    .WIDTH          (32),
    .INST_MEM_DEPTH (INST_MEM_DEPTH),
    .REG_FILE_DEPTH (5),
    .DATA_MEM_DEPTH (DATA_MEM_DEPTH),
    .INST_SIZE      (32)
) u_core (
    .clk_i          (clk_16mhz_i),
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
```

- **PC → ROM**: el núcleo genera `ProgAddress_o`.  
- **ALU → DataAddress_o**: direcciones efectivas para RAM/MMIO.  
- **Bus de datos**:
  - `DataOut_o` = dato para stores (`sw`, etc.).  
  - `DataIn_i`  = dato leído de RAM o periféricos.  
- Señales de control:
  - `we_o` / `mem_read_o` → habilitan escritura/lectura externa.  
  - `one_b`, `two_b`, `four_b` → tamaño de acceso.

---

### 5. Bloque MMIO y periféricos

#### 5.1 Bloque central MMIO (`soc_mmio_block`)

```verilog
soc_mmio_block #(
    .MMIO_BASE(32'h0001_0000)
) u_mmio (
    .clk        (clk_16mhz_i),
    .rst        (rst_sync),

    .addr_i     (DataAddress_o),
    .wdata_i    (DataOut_o),
    .we_i       (we_o),
    .re_i       (mem_read_o),
    .rdata_o    (mmio_rdata),
    .mmio_hit_o (mmio_hit),

    .ctrl_in_data_i   (mando_dat),
    .ctrl_btn_state_i (mando_sta),

    .leds_o       (leds_o),
    .seg_digit0_o (seg_digit0_score),
    .seg_digit1_o (seg_digit1_score),

    .uart_wr_o       (uart_wr),
    .uart_reg_sel_o  (uart_reg_sel),
    .uart_entrada_o  (uart_entrada),
    .uart_salida_i   (uart_salida),

    .tim_wr_o     (tim_wr),
    .tim_addr_o   (tim_addr),
    .tim_wdata_o  (tim_wdata),
    .tim_rdata_i  (tim_rdata),

    .vga_we_o     (vga_we),
    .vga_waddr_o  (vga_waddr),
    .vga_wdata_o  (vga_wdata)
);
```

Este módulo decodifica direcciones 0x0001_0000..0x0001_FFFF y reparte las transacciones hacia:

- Mando (`MANDO_DAT`, `MANDO_STA`).  
- LEDs (`0x0001_0010`).  
- **Display de 7 segmentos** (`0x0001_0020`, `0x0001_0024`).  
- **UART de Laboratorio 3** (`0x0001_0040`, `0x0001_0044`).  
- **Timer** (`0x0001_0050`, `0x0001_0054`).  
- **VGA Battleship** (`0x0001_0060`..`0x0001_00FF`).  
- Tablero remoto (0x0001_0200..0x0001_0263) en el proyecto completo.

El núcleo simplemente genera direcciones y datos; `soc_mmio_block` se encarga del **mapa de memoria de periféricos**.

---

### 6. UART física (reutilizada del Laboratorio 3)

```verilog
Interfaz_UART u_uartif (
    .clk            (clk_16mhz_i),
    .reset          (rst_sync),
    .wr_i           (uart_wr),
    .reg_sel_i      (uart_reg_sel),
    .entrada_i      (uart_entrada),
    .uart_rx        (uart_rx),
    .uart_tx        (uart_tx),
    .status_fifo_tx (status_fifo_tx),
    .status_fifo_rx (status_fifo_rx),
    .salida_o       (uart_salida),
    .RXAV           (RXAV),
    .FTXF           (FTXF)
);
```

- Es **exactamente la misma interfaz UART** desarrollada en el **Laboratorio 3**:
  - Periférico completo con **FIFOs TX/RX**, registro de control/estado y capa física 8N1.  
  - Frecuencia base: 16 MHz, **baud rate 115200 bps**.
- `soc_mmio_block` presenta esta UART al core mediante:
  - `ADDR_UART_CTRLSTAT = 0x0001_0040` (registro control/estado).  
  - `ADDR_UART_DATA     = 0x0001_0044` (lectura/escritura de datos).

> De esta forma, el **mismo diseño de UART** del laboratorio se reutiliza sin cambios como periférico estándar del SoC Battleship.

---

### 7. Timer programable (`Timer_Top`)

```verilog
Timer_Top u_timer (
    .clk       (clk_16mhz_i),
    .reset     (rst_sync),
    .addr_i    (tim_addr),   // 0 => CTRL, 1 => COUNTER
    .data_in   (tim_wdata),
    .data_out  (tim_rdata),
    .write_i   (tim_wr),
    .timeout_o (timeout_pulse)
);
```

- Direcciones MMIO:
  - `0x0001_0050` → registro de control/estado del timer.  
  - `0x0001_0054` → registro de carga/lectura del contador.
- Internamente integra:
  - Interfaz de registros (`Interfaz_Registros`).  
  - Lógica de control (`Control`) con `start_bit`, `autoreload_bit`, `timeout_flag`.  
  - Contador descendente (`Contador_descendente`) que genera `timeout` como pulso de 1 ciclo.
- `timeout_pulse` queda disponible para debug o futuras IRQs (no se usa aún como interrupción).

---

### 8. VGA Battleship (`BattleshipVGA_MMIO`)

```verilog
BattleshipVGA_MMIO #(
    .CELL_SIZE (32)
) u_vga (
    .clk         (clk),       // 100 MHz para VGA
    .rst         (rst_sync),

    .vga_waddr_i (vga_waddr),
    .vga_wdata_i (vga_wdata),
    .vga_we_i    (vga_we),

    .Hsync       (Hsync),
    .Vsync       (Vsync),
    .vgaRed      (vgaRed),
    .vgaGreen    (vgaGreen),
    .vgaBlue     (vgaBlue)
);
```

- El núcleo escribe en 0x0001_0060..0x0001_00FF (decodificado en `soc_mmio_block`).  
- `BattleshipVGA_MMIO` traduce estas escrituras a:
  - Actualizaciones de celdas del tablero 10x10.  
  - Posición del cursor.  
  - Activación/desactivación del **splash screen** inicial.

La señal de reloj VGA usa directamente los **100 MHz**, internamente divididos a 25 MHz dentro de `Tablero`.

---

### 9. Display de 7 segmentos – modo marcador

Los valores escritos por el core a:

- `0x0001_0020` → `seg_digit0_score` (P1 y P2 score).  
- `0x0001_0024` → `seg_digit1_score` (código de fase y turno).

Se empaquetan en un vector de 32 bits:

```verilog
always_comb begin
    sevenseg_value = 32'hFFFF_FFFF; // blanco por defecto

    sevenseg_value[3:0]   = seg_digit0_score[3:0]; // D0 = P1_SCORE
    sevenseg_value[7:4]   = seg_digit0_score[7:4]; // D1 = P2_SCORE

    sevenseg_value[27:24] = seg_digit1_score[3:0]; // D6 = PHASE_CODE
    sevenseg_value[31:28] = seg_digit1_score[7:4]; // D7 = TURN_CODE
end
```

Este valor alimenta al driver multiplexado `disp_hex32_simple`:

```verilog
disp_hex32_simple #(
    .CNT_W (20),
    .HI    (12),
    .LO    (10)
) u_disp (
    .clk   (clk_16mhz_i),
    .rst   (rst_sync),
    .value (sevenseg_value),
    .seg   (sevenseg_seg),
    .an    (sevenseg_an)
);

always_comb begin
    display0_o[6:0] = sevenseg_seg;
    display0_o[7]   = 1'b1;      // DP apagado
    display1_o      = sevenseg_an;
end
```

> El display se usa como **marcador del juego** (puntajes, fase y turno) controlado completamente desde el ensamblador a través de MMIO.

# Lógica del Juego en Ensamblador RISC‑V

## 1. Visión general

La lógica completa del juego **Batalla Naval** está implementada en ensamblador RISC‑V sobre el núcleo uniciclo.  
El programa se organiza como un gran bucle principal que lee continuamente el **mando físico**, actualiza el **cursor VGA**, atiende la **UART**, gestiona el **temporizador de turnos** y modifica tanto el **tablero local** como el **tablero remoto** mapeado en MMIO.

Todo el comportamiento del juego se basa en una pequeña **máquina de estados** codificada en registros:

- `s7` → **fase de juego**  
  - `PHASE_PLACE = 0` → Fase de colocación de barcos.  
  - `PHASE_BATTLE = 1` → Fase de batalla (disparos).  
- `s8` → **turno actual**  
  - `0` → Turno del Jugador 1 (VGA).  
  - `1` → Turno del Jugador 2 (PC).  
- `s11` → **estado global**  
  - `0` → Juego activo.  
  - `1` → Juego terminado (game over).

Los registros `s0..s10` almacenan el progreso de la partida (barcos colocados, orientación, scores, flags de UART, etc.), lo que permite que el programa mantenga todo el estado de juego exclusivamente en software.

---

## 2. Secuencia inicial: splash y configuración

Al arrancar, el programa:

1. **Enciende la pantalla de bienvenida (splash)** escribiendo `1` en `VGA_SPLASH_CTRL`.  
2. Espera primero a que el botón **CONFIRM** esté suelto (nivel 0) y luego a un **flanco 0→1** de CONFIRM sobre `MANDO_STA`.  
3. Cuando se detecta la pulsación, apaga el splash (`VGA_SPLASH_CTRL = 0`) y pasa al juego.

Después del splash:

- Inicializa:
  - `ships_placed` (`s0`) = 0.  
  - Cursor lógico `fila` (`s2`) y `col` (`s3`) = 0.  
  - `orientation` (`s5`) = 0 (horizontal).  
  - `score_p1` (`s9`) y `score_p2` (`s10`) = 0.  
  - `phase` (`s7`) = `PHASE_PLACE`.  
  - `current_turn` (`s8`) = 0 (Jugador 1).  
  - `game_over` (`s11`) = 0 (juego activo).  
- Inicializa el **estado previo de botones** `MSTA_PREV` (`s1`) leyendo `MANDO_STA`.  
- Pone los displays `DISP_P1` y `DISP_P2` en `00`.  
- Limpia el **tablero remoto** en `BOARD_MMIO_BASE` (100 bytes). Esto elimina cualquier “basura” previa dejando todas las celdas del enemigo en 0.

---

## 3. Bucle principal: lectura de mando y actualización de cursor

Dentro del label `loop` se ejecuta en cada iteración:

1. **Lectura de posición del mando** desde `MANDO_DAT`:
   - `col = [3:0]`, `row = [7:4]`.  
   - Se copian a `s2` (fila) y `s3` (columna).

2. **Actualización del cursor VGA** mediante MMIO:
   - Escritura de `s2` en `VGA_CUR_ROW`.  
   - Escritura de `s3` en `VGA_CUR_COL`.  
   - Escritura de `1` en `VGA_CUR_CTRL` para habilitar el cursor.

3. **Depuración en LEDs**:
   - LED[3:0] = columna.  
   - LED[7:4] = fila.  
   - LED[9:8] = `ships_placed` (0..5).  
   - LED14 / LED15 indican el **turno actual** (Jugador 1 o 2).

4. **Lectura de botones** desde `MANDO_STA` en `t6` para detectar flancos en CONFIRM, CANCEL y ROTATE comparando con `MSTA_PREV` (`s1`).

---

## 4. Temporizador de turnos y gestión de timeout

En **fase de batalla** (`s7 = PHASE_BATTLE`) y mientras el juego está activo (`s11 = 0`), el bucle:

1. Lee `TIM_CTRL` del periférico `Timer_Top`.  
2. Comprueba el bit `TIMEOUT` (`TIM_TIMEOUT_MASK`):
   - Si es 0 → No hay timeout, sigue el flujo normal.  
   - Si es 1 → Ha expirado el tiempo de turno (30 s).

Cuando se detecta `TIMEOUT = 1`:

- Se llama a `advance_turn` para alternar el turno (`s8 = s8 XOR 1`).  
- Se llama a `start_turn_timer` para reiniciar el timer del nuevo jugador.

La subrutina `start_turn_timer`:

- Escribe `TURN_30S_TICKS = 480000000` en `TIM_COUNTER`.  
- Genera un flanco controlado en `TIM_CTRL` (escribiendo primero 0 y luego `START=1, AUTORELOAD=1`) para activar la cuenta.  
- Si `game_over = 1`, no vuelve a arrancar el temporizador.

---

## 5. Fase de colocación de barcos (PHASE_PLACE)

En esta fase, cada pulsación de **CONFIRM** coloca un barco del Jugador 1 en el tablero VGA y lo notifica al PC por UART. El sistema mantiene:

- `ships_placed` (`s0`): cuántos barcos se han colocado (0..5).  
- `orientation` (`s5`): 0 = horizontal, 1 = vertical.  
- `len` (`s6`): longitud del barco actual, calculada como `5 – ships_placed`, lo que genera la secuencia de longitudes 5,4,3,2,1.

### 5.1 Detección de CONFIRM y selección de fase

Se detecta un **flanco** de CONFIRM:

- `t1 = bit CONFIRM actual`, `t4 = bit previo en `s1`.  
- Si `t1=1` y `t4=0` → flanco 0→1 válido.

Si el juego no ha terminado (`s11 = 0`):

- Si `s7 = PHASE_PLACE` → se llama a `confirm_place`.  
- Si `s7 = PHASE_BATTLE` → se salta a `confirm_shot`.

### 5.2 Colocación horizontal y vertical

En `confirm_place`:

1. Se verifica que `ships_placed < SHIP_MAX (5)`; si no, se ignora.  
2. Se calcula la longitud del barco: `s6 = 5 – s0`.

Luego, según `orientation` (`s5`):

- **Vertical (`s5 = 1`)**:
  - Se ajusta `start_row` para que el barco quepa en el tablero: `start_row ≤ 10 – len`.  
  - Se recorre `k` de 0 a `len-1`, para cada celda `(row_k, col)`:
    - Se calcula la dirección VGA: `addr = VGA_BASE + (row_k << 4) + col`.  
    - Se escribe `VGA_SHIP = 1` para marcar barco en `board_logic`.  
    - Se construye un byte `coord = (row_k << 4) | col` y se envían **dos bytes** por UART:
      - Byte 1: `coord`.  
      - Byte 2: `state = VGA_SHIP (1)`.

- **Horizontal (`s5 = 0`)**:
  - Se ajusta `start_col` para que el barco quepa: `start_col ≤ 10 – len`.  
  - Se recorre `k` de 0 a `len-1`, para cada celda `(row, col_k)`:
    - Se calcula `addr = VGA_BASE + (row << 4) + col_k`.  
    - Se escribe `VGA_SHIP = 1`.  
    - Se envía por UART el par `(coord, state)` igual que en el caso vertical.

Al finalizar la colocación:

- Se incrementa `ships_placed` (`s0++`).  
- Si `s0 == SHIP_MAX (5)`, se cambia a `PHASE_BATTLE` y:
  - Se fuerza `turno = Jugador 1` (`s8 = 0`).  
  - Se llama a `start_turn_timer` para iniciar el conteo de 30 s.

### 5.3 Cancelar último barco (CANCEL en PHASE_PLACE)

En fase de colocación, un flanco de **CANCEL** permite **deshacer el último barco colocado**:

1. Si `ships_placed = 0`, no hay nada que borrar.  
2. Se calcula la longitud del último barco: `len_last = 6 – ships_placed`.  
3. Se asume la orientación actual `s5` para reconstruir el barco a borrar:
   - Si `s5 = 1` → se recorre vertical.  
   - Si `s5 = 0` → se recorre horizontal.  
4. Para cada celda del barco:
   - Se escribe `VGA_EMPTY` en el tablero VGA.  
   - Se envía por UART el par `(coord, state=0)` para que el PC borre también ese barco.  
5. Se decrementa `ships_placed` (`s0--`).

Esta funcionalidad garantiza que el jugador pueda corregir errores de colocación manteniendo sincronizados tanto el tablero de la FPGA como el de Python.

### 5.4 Rotación de orientación (ROTATE)

Un flanco de **ROTATE** (bit correspondiente en `MANDO_STA`) conmuta la orientación:

- `s5 = s5 XOR 1`, alternando entre horizontal y vertical.  
- No modifica `ships_placed`; solo afecta la forma en que se colocará el siguiente barco o cómo se interpretará un CANCEL.

---

## 6. Fase de batalla (PHASE_BATTLE)

En esta fase, **CONFIRM** se interpreta como un **disparo** contra el tablero remoto, pero únicamente cuando:

- `s7 = PHASE_BATTLE`.  
- `s8 = 0` (turno del Jugador 1).  
- `game_over = 0`.

### 6.1 Cálculo de índice y lectura de tablero remoto

En `confirm_shot`:

1. Se calcula el índice lineal `idx = row*10 + col` usando `s2` (fila) y `s3` (columna).  
2. Se forma la dirección MMIO: `addr = BOARD_MMIO_BASE + idx`.  
3. Se lee `tablero[idx]` con `lbu`:
   - `0` → celda vacía (no hay barco enemigo).  
   - `1` → barco remoto no impactado.  
   - `2` → barco remoto ya impactado (hit previo).

### 6.2 Casos de disparo: HIT, MISS y celda ya impactada

Se construye también la coordenada compacta `coord = (fila << 4) | col` (por si se quisiera enviar el resultado al PC).

- Si `tablero[idx] = 2` (ya impactado):  
  - No se dibuja nada, no se envía nada y se retorna al bucle.

- Si `tablero[idx] = 1` (barco nuevo):
  - Se marca `tablero[idx] = 2` (barco impactado).  
  - Se llama a `score_p1_hit` para incrementar el puntaje del Jugador 1.  
  - Se selecciona `VGA_HIT = 3` como estado a pintar en VGA.

- En cualquier otro caso (`0`):
  - Se selecciona `VGA_MISS = 2` para pintar un fallo.

Finalmente, se pinta en VGA la celda `(row, col)` con `HIT` o `MISS`, y si **el juego no ha terminado**:

- Se llama a `advance_turn` para pasar el turno al Jugador 2.  
- Se reinicia el temporizador con `start_turn_timer`.

---

## 7. Protocolo UART y tablero remoto en FPGA

La comunicación UART se maneja en dos fases:

1. **Consulta de RXAV y petición de lectura**.  
2. **Lectura efectiva de UART_DAT** en la iteración siguiente.

El registro `s4` funciona como **flag de lectura pendiente**.

### 7.1 Fase de polling (sin lectura pendiente)

Si `s4 = 0`:

- Se lee `UART_CSR` y se comprueba el bit `RXAV`.  
- Si `RXAV = 1` (hay dato disponible), se escribe `UART_LEER_MASK` en `UART_CSR` para pedir la extracción de un byte hacia `UART_DAT`.  
- Se pone `s4 = 1` y se espera al siguiente ciclo de `loop` para leer efectivamente el dato.

### 7.2 Lectura del byte y clasificación por fase

Si `s4 = 1`:

- Se lee `UART_DAT` en `t1` y se enmascara a 8 bits.  
- Se limpia `s4 = 0`.  

Luego:

- Si `t1 = 0xFE` → código especial de **HIT Jugador 2** (`rx_p2_hit`).  
- En otro caso, se interpreta como **coordenada `(fila,col)`**:
  - col = nibble bajo, fila = nibble alto.  
  - Se actualizan `s2` y `s3`, y se mueve el cursor VGA a esa posición.  
  - Se reflejan estas coordenadas en los LEDs.

Según la fase:

- `PHASE_PLACE` → `rx_place_ship`: el PC envía barcos remotos.  
  - Se calcula `idx = row*10 + col`.  
  - Se escribe `1` en `BOARD_MMIO_BASE[idx]` para marcar barco enemigo en la memoria remota de la FPGA.

- `PHASE_BATTLE` → `rx_battle`: se interpreta como disparo del Jugador 2.  
  - Si el juego está activo (`s11 = 0`) y `s8 = 1` (turno PC), se llama a:
    - `advance_turn` → cambiar turno a Jugador 1.  
    - `start_turn_timer` → reiniciar contador.  
  - (La lógica completa de HIT/MISS contra el tablero local se deja preparada para una extensión futura.)

---

## 8. Manejo de scores, displays y condiciones de victoria

### 8.1 Puntuación del Jugador 1 (`score_p1_hit`)

Cada **HIT** del Jugador 1:

1. Incrementa `s9` saturado a 15.  
2. Calcula `decenas` y `unidades` mediante divisiones sucesivas por 10.  
3. Codifica `[7:4] = decenas`, `[3:0] = unidades` y lo escribe en `DISP_P1`.  
4. Si `s9` llega a 15 y el juego aún no había terminado (`s11 = 0`), llama a `game_over_p1`.

### 8.2 Puntuación del Jugador 2 (`rx_p2_hit` + `score_p2_update_display`)

Cuando la FPGA recibe el código `0xFE` por UART:

- Se incrementa `score_p2` (`s10`) saturado a 15.  
- Se llama a `score_p2_update_display`, que:
  - Convierte `s10` en decenas/unidades.  
  - Actualiza `DISP_P2` con el formato 00–15.  
- Si `s10 = 15` y `game_over = 0`, se llama a `game_over_p2`.

### 8.3 Rutinas de fin de juego

- **`game_over_p1`**:
  - Pone `s11 = 1` (juego terminado).  
  - Detiene el temporizador (`TIM_CTRL = 0`).  
  - Envía por UART el paquete especial:
    - Byte 1: `0xFE`.  
    - Byte 2: `1` (código de victoria P1).

- **`game_over_p2`**:
  - Pone `s11 = 1`.  
  - Detiene el temporizador.  
  - Envía:
    - Byte 1: `0xFE`.  
    - Byte 2: `2` (código de victoria P2).

Cualquier lógica posterior (mensajes en pantalla, reinicios, etc.) se deja a la aplicación Python, que interpreta estos códigos especiales y muestra el mensaje de ganador.

---

## 9. Cambio de turno y sincronización con Python

La subrutina `advance_turn` se encarga de:

1. Evitar cambios si `game_over = 1`.  
2. Alternar el turno: `s8 = s8 XOR 1` (0 ↔ 1).  
3. Enviar por UART un **paquete de cambio de turno**:

   - Byte 1: `0xFF` (coord especial).  
   - Byte 2:  
     - `0x00` si `s8 = 0` → turno VGA.  
     - `0x01` si `s8 = 1` → turno PC.

De esta forma, Python conoce siempre quién debe jugar y puede habilitar o bloquear la interacción del Jugador 2 en su interfaz gráfica.

---


## Aplicación Python – Jugador 2 (PC)

La aplicación en Python implementa al **Jugador 2** sobre PC usando `pygame` (interfaz gráfica) y `pyserial` (comunicación UART con la FPGA). Su función es complementar al SoC RISC‑V: primero coloca barcos propios, luego participa en la fase de batalla siguiendo el mismo protocolo de coordenadas que el procesador en la FPGA.

---

### 1. Entorno y configuración general

El script define primero la configuración global:

- Tamaño del tablero: `N = 10` (tablero 10×10).
- Tamaño de celda: `CELL_SIZE = 35` píxeles y margen `MARGIN = 50`.
- Uso de UART: `USE_UART = True`, puerto serie configurable (`SERIAL_PORT = "COM8"`) y `BAUDRATE = 115200`.
- Ruta de la imagen de splash: `SPLASH_IMAGE_FILE = "battleship_splash.png"`.
- Paleta de colores consistente con la VGA:
  - `CELSTE_VGA` como fondo de tablero.
  - `STEELBLUE` para barcos propios.
  - `DARKBLUE` para agua / fallo.
  - `RED` para impactos.
- Código especial `P2_HIT_CODE = 0xFE` para avisar a la FPGA cuando el Jugador 2 logra un HIT.

La clase principal **`BattleshipGame`** se encarga de inicializar Pygame, la ventana, las fuentes y, si está disponible, el puerto serie mediante `pyserial`.

---

### 2. Estructura de la clase `BattleshipGame`

En el constructor `__init__` se realizan tres pasos clave:

1. **Inicialización gráfica**
   - Se crea una ventana Pygame de tamaño proporcional al tablero (márgenes + 10×CELLSIZE).
   - Se seleccionan fuentes pequeñas (`font`) y grandes (`font_big`) para textos y la pantalla de splash.

2. **Inicialización UART**
   - Si `USE_UART` está activo y `pyserial` está instalado, se intenta abrir el puerto serie con un `timeout` pequeño.
   - En caso de error se informa por consola y se desactiva la UART (el juego puede correr solo en modo local sin comunicación real).

3. **Splash y reset de juego**
   - Se cargan los recursos de splash (`load_splash_assets`) y se muestra la pantalla de bienvenida (`show_splash`) antes de iniciar el juego.
   - Después del splash se llama a `reset_game(init_uart=False)` para inicializar los tableros y el estado lógico.

---

### 3. Pantalla de bienvenida (Splash)

La función `load_splash_assets`:

- Intenta cargar la imagen definida en `SPLASH_IMAGE_FILE`.
- Le aplica un factor de zoom (actualmente ≈ 0.60) para ajustarla a la ventana.
- Crea una superficie del tamaño completo de la ventana, pinta un fondo `CELSTE_VGA` y centra la imagen escalada en ella.
- Si la carga falla, se deja `self.splash_image = None` y se trabaja con un fallback textual.

La función `show_splash`:

- Ejecuta un bucle mientras `in_splash` sea `True`.
- Sale únicamente cuando el usuario presiona **ENTER**.
- Si existe `self.splash_image`, se dibuja directamente; de lo contrario:
  - Se pinta fondo celeste.
  - Se muestra el texto central `"KARINA Y RANDY BATTLESHIP"`.
- En la parte inferior se muestra el mensaje `"Presiona ENTER para comenzar"`.

Esta lógica es coherente con el comportamiento de la FPGA: ambos sistemas muestran un splash y esperan una acción del jugador antes de iniciar la lógica de juego.

---

### 4. Reset del juego en PC

La función `reset_game` realiza un “soft reset” del estado interno del jugador PC:

- **Tableros lógicos:**
  - `self.board`: tablero propio del PC (barcos de Jugador 2).
  - `self.enemy_board`: tablero enemigo, donde se representarán barcos y resultados asociados a la FPGA.
- **Cursor y orientación:**
  - `self.cur_row`, `self.cur_col` inicializados en 0.
  - `self.ship_sizes = [5, 4, 3, 2, 1]` con el índice `self.current_ship_idx` para llevar el progreso de la colocación.
  - `self.placing_horizontal = True` y `self.placing_ship = False`, más `self.temp_ship_coords` para la previsualización del barco.
- **Fases y turno:**
  - `self.phase = "placement"` (“placement” o “battle”).
  - `self.current_turn = "vga"` al inicio (el primer turno es del Jugador 1 VGA).
- **Marcadores y estado de fin de juego:**
  - `self.score_pc = 0` como contador de hits del Jugador 2.
  - `self.game_over = False` y `self.winner = None` para registrar el resultado final.
- **UART:**
  - Si `init_uart=True` y `self.ser` no es `None`, se limpian los buffers de entrada usando `reset_input_buffer()`.

---

### 5. Comunicación UART PC ↔ FPGA

#### 5.1 Envío PC→FPGA: `send_to_fpga`

La función `send_to_fpga(self, coord, value=None)` envia **un solo byte** hacia la FPGA:

- Se usa tanto para:
  - Coordenadas de barcos durante la fase de colocación.
  - Coordenadas de disparos durante la fase de batalla.
  - Códigos especiales, como `P2_HIT_CODE = 0xFE` para indicar un HIT del Jugador 2.
- El envío se realiza con:
  ```python
  self.ser.write(bytes([coord & 0xFF]))
  ```

#### 5.2 Recepción FPGA→PC: `poll_uart_rx`

Esta función procesa paquetes de **2 bytes** enviados desde la FPGA:

1. **Paquetes de cambio de turno**
   - Formato: `coord = 0xFF`, `state = 0x00/0x01`.
   - `state = 0x00` → `self.current_turn = "vga"`.
   - `state = 0x01` → `self.current_turn = "pc"`.
   - Se imprime por consola el cambio de turno.

2. **Paquetes de fin de juego**
   - Formato: `coord = 0xFE`, `state = 0x01/0x02`.
   - `state = 1` → gana Jugador 1 (VGA).
   - `state = 2` → gana Jugador 2 (PC).
   - Se actualiza:
     - `self.winner = "vga"` o `"pc"`.
     - `self.game_over = True`.

3. **Paquetes coordenada/estado normales**
   - `coord` contiene fila y columna empaquetadas: `fila = coord >> 4`, `col = coord & 0x0F`.
   - `state == 1` → barco enemigo (de la VGA) durante colocación; se marca `self.enemy_board[fila][col] = 1`.
   - `state == 2/3` en fase `"battle"` quedan reservados para una futura extensión donde la FPGA reporte HIT/MISS sobre el tablero del PC.

Con esta codificación, el PC se mantiene siempre sincronizado con el juego que corre en la FPGA (turnos, barcos enemigos y fin de juego).

---

### 6. Lógica de juego en PC

#### 6.1 Determinación de colores por estado

La función `color_for_state(row, col, own=True)` traduce los estados numéricos a colores:

- Tablero propio (`own=True`):
  - `0` → celda vacía (`CELSTE_VGA`).
  - `1` → barco (`STEELBLUE`).
  - `2` → fallo (`DARKBLUE`).
  - `3` → impacto (`RED`).
- Tablero enemigo (`own=False`):
  - `2` → MISS (azul).
  - `3` → HIT (rojo).
  - Otro valor → celda oculta (`CELSTE_VGA`).

#### 6.2 Colocación de barcos (fase `"placement"`)

La función `can_place_ship(row, col, size, horizontal)` verifica si un barco de longitud `size` cabe desde `(row,col)` en la orientación indicada:

- Recorre `size` celdas, ajustando `r` y `c` según `horizontal`.
- Si alguna celda se sale del tablero (`r >= N` o `c >= N`) o ya está ocupada (`self.board[r][c] != 0`), devuelve `None`.
- En caso válido, devuelve la lista de coordenadas.

En el bucle de eventos de `run`, durante `self.phase == "placement"`:

- Teclas de cursor (`UP`, `DOWN`, `LEFT`, `RIGHT`) mueven el cursor.
- `R` alterna la orientación (`self.placing_horizontal`).
- `E` cancela el barco temporal (`self.temp_ship_coords.clear()`).
- `SPACE` previsualiza el barco actual:
  - Calcula `coords = can_place_ship(...)`.
  - Si es válido, guarda la lista en `self.temp_ship_coords` y activa `self.placing_ship = True`.
- `ENTER` confirma el barco:
  - Marca las celdas definitivas (`self.board[r][c] = 1`).
  - Limpia el barco temporal y avanza `self.current_ship_idx`.
- `Q` envía todos los barcos ya colocados a la FPGA:
  - Recorre `self.board`; por cada celda con valor 1:
    ```python
    coord = ((fila & 0x0F) << 4) | (col & 0x0F)
    self.send_to_fpga(coord)
    ```
  - Cambia de fase a `"battle"` y fija `self.current_turn = "vga"`.

#### 6.3 Fase de batalla (phase `"battle"`)

En la fase de batalla, la clave es la tecla **W**:

- Primero se verifica:
  - Que `self.game_over` sea `False`.
  - Que `self.current_turn == "pc"` (si no, el disparo se ignora).
- Se toma la casilla objetivo `r = self.cur_row`, `c = self.cur_col`.
- Se lee el estado local:
  - `enemy_state = self.enemy_board[r][c]`.
  - `own_state = self.board[r][c]`.
- Se evalúa el disparo:
  - **HIT** si `enemy_state == 1`:
    - Si aún no se había marcado como impacto, se pone `self.enemy_board[r][c] = 3`.
    - Se incrementa el marcador local `self.score_pc` hasta un máximo de 15.
    - Si `self.score_pc >= 15` y no había `game_over`, se declara victoria local:
      - `self.game_over = True`.
      - Mensaje por consola indicando que el Jugador 2 ha ganado.
  - **Disparo sobre barco propio** (`own_state == 1`):
    - Se imprime un mensaje y no se modifica el tablero (ni cuenta como hit).
  - **MISS** en cualquier otro caso:
    - Si no era una celda ya impactada (`enemy_state != 3`), se marca `self.enemy_board[r][c] = 2`.

Tras determinar HIT/MISS:

- Si fue **HIT nuevo**, se envía primero el código especial:
  ```python
  self.send_to_fpga(P2_HIT_CODE)
  ```
- A continuación se envía la coordenada real del disparo:
  ```python
  coord = ((r & 0x0F) << 4) | (c & 0x0F)
  self.send_to_fpga(coord)
  ```
- El **cambio de turno** no lo hace el PC directamente: la FPGA enviará posteriormente un paquete `0xFF, state` que será procesado en `poll_uart_rx`.

---

### 7. Interfaz gráfica y marcador del Jugador 2

La función `draw_board` encapsula toda la lógica de dibujo:

1. Limpia la pantalla con fondo blanco.
2. Dibuja rótulos:
   - Letras `A..J` arriba.
   - Números `1..10` a la izquierda.
3. Dibuja el marco del tablero y todas las celdas propias, usando `color_for_state` para cada `(fila,col)`.
4. Si se está colocando un barco (`phase == "placement"` y `placing_ship` activo), dibuja un **overlay temporal** en las coordenadas `self.temp_ship_coords`.
5. Dibuja el cursor como un rectángulo rojo alrededor de la celda seleccionada.
6. Dibuja el overlay enemigo de HIT/MISS, reduciendo el tamaño del rectángulo para que se vea incrustado dentro de la celda.
7. Muestra un texto de marcador simple:
   - `P2 Hits: {self.score_pc}` en la parte inferior de la ventana.
8. Si `self.game_over` es `True`, muestra el mensaje `"JUEGO TERMINADO"` centrado en la parte inferior.

Finalmente, se actualiza la pantalla con `pygame.display.flip()`.

---

### 8. Bucle principal `run`

El método `run` es el loop principal del juego:

- Fija el framerate a 60 FPS con `self.clock.tick(60)`.
- Llama en cada ciclo a `self.poll_uart_rx()` para procesar cualquier mensaje pendiente desde la FPGA.
- Atiende eventos de Pygame:
  - `QUIT` para cerrar la aplicación.
  - Eventos `KEYDOWN` para:
    - Reset (`C`): llama a `reset_game`.
    - Movimiento de cursor (`UP/DOWN/LEFT/RIGHT`).
    - Acciones específicas según la fase (`placement` o `battle`) como se describió antes.
- Llama a `self.draw_board()` para refrescar la pantalla.
- Al salir del bucle:
  - Cierra el puerto serie si está abierto.
  - Cierra ordenadamente Pygame y sale del programa.

Con esta lógica, la aplicación Python actúa como un **segundo jugador completo**, sincronizado con la FPGA mediante un protocolo UART simple (coord/estado y códigos especiales), proporcionando interfaz gráfica, control local de barcos, disparos y un marcador independiente para el Jugador 2.
## Resultados y Análisis

### 1. Metodología de prueba

Para validar el funcionamiento del SoC **Battleship RISC‑V** se combinaron tres tipos de pruebas:

1. **Simulación RTL** en Vivado/ModelSim del módulo `soc_top`, utilizando:
   - ROM cargada con el programa completo del juego (todas las fases)
   - Estímulos UART que emulan a la aplicación Python (envío de tablero remoto y disparos).
2. **Pruebas en hardware** sobre la FPGA Nexys‑4 DDR, conectada a:
   - Monitor VGA 640×480@60 Hz.
   - PC con la aplicación Python (Jugador 2) vía UART 115200 bps.
   - Mando físico (botones en cabezal JA).
3. **Verificación cruzada** entre ambos mundos:
   - Comparación entre el estado interno del juego (registros/MMIO, RAM) y lo observado en VGA/Python.
   - Conteo de puntos y turnos tanto en el display de 7 segmentos como en la interfaz gráfica.

---

### 2. Resultados de simulación del SoC completo

#### 2.1 Evolución del juego en la forma de onda

En la simulación del `soc_top` se observaron las siguientes fases claramente diferenciadas:

- **Fase de Splash / Inicio**
  - Señal `VGA_SPLASH_CTRL` en alto hasta que el programa ejecuta la rutina de inicio.
  - El PC recorre secuencialmente la ROM y se ve el primer acceso a MMIO VGA únicamente para configurar el splash.

- **Fase de colocación de barcos (Jugador 1)**
  - Escrituras repetidas en el rango `0x0001_0060..0x0001_00FF` (celdas VGA) sincronizadas con los cambios de `MANDO_DAT`.
  - Se observa que cada pulso de `MANDO_STA` (CONFIRM) genera exactamente una actualización de celda en `board_logic`.

- **Fase de intercambio de disparos (Jugadores 1 y 2)**
  - Alternancia entre:
    - Escrituras en VGA para marcar **aciertos/fallos** locales.
    - Escrituras en `remote_board_mmio` (`0x0001_0200..0x0001_0263`) al recibir información vía UART.
  - La señal del **Timer** (`timeout_o`) se activa cuando expira el tiempo de turno, y el ensamblador responde cambiando de fase o forzando el cambio de jugador.

Estas formas de onda permiten verificar que la secuencia de estados del juego se corresponde con el diseño de alto nivel descrito en el README.
<img src ="https://gitlab.com/el3313-ii2025-g1/proyecto/-/raw/Final/Figuras/JuegoC%20(1).png?ref_type=heads" width="350">


#### 2.2 Verificación de Timer y VGA

- **Timer**
  - El registro de control responde correctamente a escrituras en `0x0001_0050`.
  - El pulso de `timeout_o` tiene duración de **un solo ciclo**, alineado con el paso de `counter_reg = 1 → 0`.
  - En modo *autoreload* se observa el patrón esperado: `timeout_o` periódico y recarga automática del contador.

<img src ="https://gitlab.com/el3313-ii2025-g1/proyecto/-/raw/Final/Figuras/timerw.png?ref_type=heads" width="350">

- **VGA**
  - Los contadores horizontales y verticales generan la temporización estándar 640×480@60 Hz.
  - La señal de video pasa por los tres modos previstos:
    1. **Zona no visible** → pantalla negra.
    2. **Splash activo** → imagen desde `splash_rom` centrada verticalmente.
    3. **Juego activo** → mezcla de fondo, rejilla, texto, celdas y cursor según la prioridad definida.

<img src ="https://gitlab.com/el3313-ii2025-g1/proyecto/-/raw/Final/Figuras/VGA.png?ref_type=heads" width="350">

---

### 3. Problema detectado: “celdas sucias” en el tablero remoto

Durante las primeras pruebas de integración con la aplicación Python (Jugador 2) se detectó un comportamiento anómalo:

- Algunas celdas del **tablero remoto** aparecían sobreescritas o con estados inconsistentes al iniciar la partida, pese a que los datos enviados por UART eran correctos.
- El problema se manifestaba de forma esporádica, lo que indicaba una posible colisión o reutilización incorrecta de direcciones en MMIO.

#### 3.1 Análisis de causa

A partir del mapa de memoria y de la observación de la forma de onda se identificaron dos factores clave:

1. El tablero remoto compartía espacio lógico con otras estructuras (VGA o buffers), lo que podía provocar que escrituras legítimas del juego modificaran posiciones ya destinadas a barcos enemigos.
2. No existía una **memoria dedicada** para el tablero del Jugador 2; en su lugar, se reutilizaban zonas pensadas para otros propósitos, aumentando el riesgo de “celdas sucias”.

Este análisis motivó la creación de un módulo específico para el tablero remoto, aislado por completo del resto de periféricos.

#### 3.2 Solución: módulo `remote_board_mmio`

Se implementó el módulo:

```systemverilog
module remote_board_mmio #(
    parameter logic [31:0] BASE_ADDR = 32'h0001_0200,
    parameter int          CELLS     = 100
)(
    input  logic        clk,
    input  logic        rst,

    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        we_i,
    input  logic        re_i,
    output logic [31:0] rdata_o
);
```

Características principales:

- Reserva explícitamente **100 bytes** consecutivos (10×10) en el rango `0x0001_0200..0x0001_0263`.
- Internamente mantiene un arreglo `mem[0:99]` independiente de VGA, RAM y otros periféricos.
- Soporta accesos `LB/SB` limpios desde el procesador, con lectura y escritura combinacional/secuencial sencilla.

Tras su integración:

- En simulación, cada escritura `SB` se traduce en un único cambio de `mem[idx]`, sin afectar otras posiciones.
- En la FPGA, el tablero remoto deja de mostrar celdas corruptas y coincide exactamente con la vista de la aplicación Python.

---

### 4. Pruebas en hardware y comportamiento observado

En la Nexys‑4 DDR, con el sistema completo integrado, se realizaron pruebas con usuarios reales manipulando el mando y jugando partidas completas contra la aplicación Python.

Observaciones principales:

1. **Estabilidad de la señal VGA**
   - El splash de inicio aparece centrado y estable  a 60 Hz.
   - El tablero de juego muestra líneas de rejilla definidas, rótulos A–J / 1–10 legibles y celdas coloreadas según su estado (barco, fallo, acierto).
   - El cursor se mueve suavemente una celda por pulsación, sin “saltos” ni pérdidas de posición.

2. **Interacción mando–CPU–VGA**
   - La posición `(fila, columna)` del cursor se actualiza inmediatamente al presionar los botones de dirección.
   - El botón **CONFIRM** registra disparos/confirmaciones una sola vez por pulsación, gracias a la lógica de flancos y al filtrado implementado en ensamblador.
   - No se detectaron rebotes visibles en el movimiento del cursor ni acciones repetidas no deseadas.

3. **Comunicación con la aplicación Python (Jugador 2)**
   - El intercambio de tableros (100 bytes) se realiza de forma confiable; los barcos del Jugador 2 en la PC coinciden con el tablero remoto almacenado en `remote_board_mmio`.
   - Los disparos del Jugador 1 se reflejan en la PC y viceversa, con consistencia en los estados de “hit/miss” en ambos lados.
   - No se observaron bloqueos ni pérdida de sincronización UART en las partidas ejecutadas.

4. **Uso del temporizador como límite de turno**
   - El tiempo máximo por turno se percibe claramente en el flujo del juego.
   - Al expirar el tiempo, el ensamblador realiza la transición de turno o fase de manera determinista, sin glitches visibles en VGA ni en el marcador de 7 segmentos.

5. **Marcador en display de 7 segmentos**
   - Los puntajes P1 y P2 se actualizan correctamente conforme se registran aciertos.
   - Los códigos de fase/turno en los dígitos más significativos permiten diagnosticar rápidamente en qué parte del flujo del juego se encuentra el sistema.

---
**Pruebas**

![sw](https://gitlab.com/el3313-ii2025-g1/proyecto/-/raw/Final/Figuras/Prueba_Completa.mp4?ref_type=heads)


**Tablero VGA**

<img src ="https://gitlab.com/el3313-ii2025-g1/proyecto/-/raw/Final/Figuras/a0fc13a6-f72b-455c-b1bc-c68c4f63fd46.jpg?ref_type=heads" width="350">

**Tablero Python**

<img src ="https://gitlab.com/el3313-ii2025-g1/proyecto/-/raw/Final/Figuras/Screenshot%202025-11-26%20220350.png?ref_type=heads" width="350">

**Splash Pyhton**

<img src ="https://gitlab.com/el3313-ii2025-g1/proyecto/-/raw/Final/Figuras/Screenshot%202025-11-26%20220717.png?ref_type=heads" width="350">

### 5. Síntesis del desempeño y posibles mejoras

En conjunto, los resultados de simulación y hardware muestran que:

- La arquitectura propuesta (núcleo RISC‑V uniciclo + MMIO estructurado) es suficiente para ejecutar el juego completo en tiempo real.
- La separación clara entre **tablero local VGA** y **tablero remoto MMIO** mejoró significativamente la robustez del sistema, eliminando problemas de “celdas sucias” y facilitando la depuración.
- El temporizador y la UART reutilizados de laboratorios previos se integran de forma natural en el SoC, demostrando la ventaja de un diseño modular.

Como trabajo futuro y posibles mejoras se identifican:

- Incorporar **interrupciones** por `timeout` o `RXAV` para reducir el sondeo (polling) en ensamblador y mejorar la eficiencia del procesador.
- Agregar mecanismos de **detección de errores** en UART (paridad, checksum sencillo por paquete) para robustecer aún más la comunicación con la PC.
- Extender el módulo `remote_board_mmio` con bits adicionales por celda (por ejemplo, para marcar barcos hundidos completamente o estados especiales de juego).

En su estado actual, el sistema cumple de forma satisfactoria con los objetivos planteados: ejecutar el juego Batalla Naval de manera autónoma sobre un SoC RISC‑V en FPGA, con una interacción fluida entre hardware dedicado (VGA, mando, temporizador) y lógica de alto nivel implementada 100 % en ensamblador.

