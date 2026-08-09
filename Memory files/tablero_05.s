.text
    .globl _start

# =========================
# DIRECCIONES MMIO
# =========================
    .equ MANDO_DAT,     0x00010000    # [7:4]=fila, [3:0]=col
    .equ MANDO_STA,     0x00010004    # bits de botones
    .equ LEDS,          0x00010010

    # Registros de cursor VGA
    .equ VGA_CUR_ROW,   0x0001006C   # fila  (bits [3:0])
    .equ VGA_CUR_COL,   0x0001007C   # col   (bits [3:0])
    .equ VGA_CUR_CTRL,  0x0001008C   # bit0 = enable cursor
    
    # Base de celdas VGA
    .equ VGA_BASE,      0x00010060   # ADDR_CELL = BASE + (row<<4) + col

# =========================
# UART MMIO (Interfaz_UART)
# =========================
    .equ UART_CSR,        0x00010040   # uart_control_reg (reg_sel=0)
    .equ UART_DAT,        0x00010044   # Top_FIFOs        (reg_sel=1)

    .equ UART_BIT_ENVIAR, 0           # bit0: ENVIAR   (no lo usamos aqu?)
    .equ UART_BIT_FTXF,   1           # bit1: FTXF (TX llena)
    .equ UART_BIT_LEER,   2           # bit2: LEER
    .equ UART_BIT_RXAV,   3           # bit3: RXAV (hay dato)

    .equ UART_RXAV_MASK,  0x00000008  # (1 << UART_BIT_RXAV)
    .equ UART_LEER_MASK,  0x00000004  # (1 << UART_BIT_LEER)

# =========================
# BOTONES DEL MANDO
# =========================
    .equ BIT_CONFIRM,   1   # bit0
    .equ BIT_CANCEL,    2   # bit1
    .equ BIT_ROTATE,    4   # bit2
    
# =========================
# CONVENCI?N DE ESTADOS VGA (ALINEADO CON board_logic)
# =========================
    .equ VGA_EMPTY,       0   # 00 = vac?o / agua de fondo
    .equ VGA_SHIP_LOCAL,  1   # 01 = barco (local)
    .equ VGA_SHIP_REMOTE, 1   # 01 = barco (remoto, mismo c?digo)
    .equ VGA_SHIP,        VGA_SHIP_LOCAL
    .equ VGA_MISS,        2   # 10 = fallo (agua azul)
    .equ VGA_HIT,         3   # 11 = acierto (rojo)

# =========================
# BARCOS
# =========================
    .equ SHIP_MAX,        5   # barcos: longitudes 5,4,3,2,1

# =========================
# TABLERO REMOTO (PC) ? MMIO
# =========================
    .equ BOARD_SIZE,       100       # 10x10 celdas
    .equ BOARD_MMIO_BASE,  0x00010200  # debe coincidir con ADDR_BOARD_BASE del MMIO

# =========================
# FASES
# =========================
    .equ PHASE_PLACE,     0   # colocando barcos locales
    .equ PHASE_BATTLE,    1   # disparando a barcos remotos

# =========================
# REGS:
#   s0 = ships_placed (0..5)
#   s1 = MSTA_PREV (estado previo de botones)
#   s2 = fila actual (0..9)
#   s3 = columna actual (0..9)
#   s4 = flag lectura UART pendiente (0 = no, 1 = s?)
#   s5 = orientation (0 = horizontal, 1 = vertical)
#   s6 = len del barco actual (5,4,3,2,1)
#   s7 = fase de juego (0 = placement, 1 = battle)
# =========================


# ---------------------------------------------------------
# Programa principal (mando + VGA + barcos + TX/RX UART)
# ---------------------------------------------------------
_start:
    # Inicializaci?n de estado
    li  s0, 0    # ships_placed = 0
    li  s2, 0    # fila
    li  s3, 0    # col
    li  s4, 0    # sin lectura UART pendiente
    li  s5, 0    # orientaci?n: 0 = horizontal
    li  s6, 0    # len (se calcula en cada CONFIRM)
    li  s7, PHASE_PLACE   # fase inicial: colocaci?n

    # Inicializamos MSTA_PREV con el valor real de los botones
    li  t0, MANDO_STA
    lw  t1, 0(t0)
    mv  s1, t1    # MSTA_PREV = estado actual de botones

main:
loop:
############################################################
# Leer posici?n del mando: MANDO_DAT
############################################################
    li t0, MANDO_DAT
    lw t1, 0(t0)        # t1 = MANDO_DAT

    # col = t1[3:0]
    andi t2, t1, 0xF    # t2 = col (0..9)

    # row = (t1 >> 4) & 0xF
    srli t3, t1, 4      # t3 = t1 >> 4
    andi t3, t3, 0xF    # t3 = row (0..9)

    # Guardar fila/col en s2/s3 para usarlos luego
    mv s2, t3           # fila
    mv s3, t2           # col

############################################################
# Escribir cursor VGA por MMIO
############################################################
    # Escribir fila en VGA_CUR_ROW (bits [3:0])
    li t0, VGA_CUR_ROW
    andi t4, s2, 0xF    # asegurar solo 4 bits
    sw t4, 0(t0)

    # Escribir columna en VGA_CUR_COL (bits [3:0])
    li t0, VGA_CUR_COL
    andi t4, s3, 0xF
    sw t4, 0(t0)

    # Habilitar cursor (VGA_CUR_CTRL bit0 = 1)
    li t0, VGA_CUR_CTRL
    li t4, 1            # bit0 = 1 ? cursor ON
    sw t4, 0(t0)

############################################################
# Debug en LEDs:
# LED[3:0] = col
# LED[7:4] = row
# LED[9:8] = ships_placed (0..5)
############################################################
    li t5, 0            # LED[3:0] = col
    or t5, t5, s3
    # LED[7:4] = row
    slli t4, s2, 4
    or t5, t5, t4
    # LED[9:8] = ships_placed
    slli t4, s0, 8      # ships_placed << 8
    or t5, t5, t4
    li t0, LEDS
    sw t5, 0(t0)

############################################################
# Leer estado de botones: MANDO_STA
############################################################
    li t0, MANDO_STA
    lw t6, 0(t0)        # t6 = MANDO_STA (botones actuales)

############################################################
# CONFIRM: seg?n fase ? colocar barco o disparar
############################################################
    li  t0, BIT_CONFIRM  # m?scara bit CONFIRM
    and t1, t6, t0       # t1 = bit actual
    and t4, s1, t0       # t4 = bit previo
    beqz t1, no_confirm  # actual = 0 ? nada
    bnez t4, no_confirm  # previo = 1 ? ya estaba pulsado ? no flanco

    # Flanco en CONFIRM: decidir por fase
    li  t0, PHASE_PLACE
    beq s7, t0, confirm_place
    j   confirm_shot

# ---------------------------------------------------------
# FASE COLOCACI?N: CONFIRM coloca barco actual (5,4,3,2,1)
#                  y lo manda al PC (state=1)
# ---------------------------------------------------------
confirm_place:
    # ?Quedan barcos por colocar? (s0 < SHIP_MAX)
    li  t2, SHIP_MAX
    bge s0, t2, no_confirm   # si s0 >= 5 ? ya no colocar m?s

    # len = 5 - ships_placed  ? 5,4,3,2,1
    li  t0, 5
    sub s6, t0, s0           # s6 = len (NO tocar en los loops)

    # ------------------------------------
    # Orientaci?n: s5 = 0 ? H, s5 = 1 ? V
    # ------------------------------------
    beqz s5, place_horizontal

    ########################################################
    # Colocaci?n VERTICAL (s5 = 1)
    ########################################################
    # start_row <= 10 - len
    li  t0, 10
    sub t1, t0, s6          # t1 = 10 - len
    mv  t2, s2              # t2 = start_row provisional

    ble s2, t1, row_ok_v
    mv  t2, t1              # si no cabe, lo pegamos al borde
row_ok_v:
    li  t3, 0               # k = 0
vert_loop:
    bge t3, s6, vert_done   # k >= len ? fin

    # row_k = start_row + k
    add t4, t2, t3          # t4 = row_k

    # ---- Pintar en VGA ----
    # addr = VGA_BASE + (row_k << 4) + col (s3)
    li   t0, VGA_BASE
    slli t1, t4, 4
    add  t1, t1, s3
    add  t0, t0, t1

    li   t5, VGA_SHIP       # 1 = barco
    sw   t5, 0(t0)

    # ---- Enviar a PC por UART (coord + estado) ----
    # coord = (row_k << 4) | col
    slli t1, t4, 4
    or   t1, t1, s3         # t1 = coord
    mv   a0, t1
    jal  ra, uart_send_byte     # byte 1: coord

    li   a0, VGA_SHIP           # 1 = barco para Python
    jal  ra, uart_send_byte     # byte 2: estado

    addi t3, t3, 1
    j    vert_loop

vert_done:
    j placed_done

    ########################################################
    # Colocaci?n HORIZONTAL (s5 = 0)
    ########################################################
place_horizontal:
    # start_col <= 10 - len
    li  t0, 10
    sub t1, t0, s6          # t1 = 10 - len
    mv  t2, s3              # t2 = start_col provisional

    ble s3, t1, col_ok_h
    mv  t2, t1              # si no cabe, lo pegamos al borde
col_ok_h:
    li  t3, 0               # k = 0
horiz_loop:
    bge t3, s6, horiz_done  # k >= len ? fin

    # col_k = start_col + k
    add t4, t2, t3          # t4 = col_k

    # ---- Pintar en VGA ----
    # addr = VGA_BASE + (row (s2) << 4) + col_k
    li   t0, VGA_BASE
    slli t1, s2, 4
    add  t1, t1, t4
    add  t0, t0, t1

    li   t5, VGA_SHIP       # 1 = barco
    sw   t5, 0(t0)

    # ---- Enviar a PC por UART (coord + estado) ----
    # coord = (row << 4) | col_k
    slli t1, s2, 4
    or   t1, t1, t4         # t1 = coord
    mv   a0, t1
    jal  ra, uart_send_byte     # byte 1: coord

    li   a0, VGA_SHIP           # 1 = barco para Python
    jal  ra, uart_send_byte     # byte 2: estado

    addi t3, t3, 1
    j    horiz_loop

horiz_done:
    # cae en placed_done

placed_done:
    addi s0, s0, 1           # ships_placed++  (5,4,3,2,1)

    # Si acabamos de colocar el ?ltimo barco, pasar a fase batalla
    li   t0, SHIP_MAX
    bne  s0, t0, no_confirm
    li   s7, PHASE_BATTLE    # ahora CONFIRM ser? disparo
    j    no_confirm

# ---------------------------------------------------------
# FASE BATALLA: CONFIRM hace DISPARO contra barcos remotos
#               usando la tabla l?gica REMOTA por MMIO
# ---------------------------------------------------------
# ---------------------------------------------------------
# FASE BATALLA: CONFIRM hace DISPARO contra barcos remotos
#               usando la tabla lógica REMOTA por MMIO
# ---------------------------------------------------------
confirm_shot:
    # idx = row*10 + col  (row = s2, col = s3)
    slli t0, s2, 3           # row*8
    slli t1, s2, 1           # row*2
    add  t0, t0, t1          # row*10
    add  t0, t0, s3          # idx = row*10 + col

    # Dirección MMIO = BOARD_MMIO_BASE + idx
    li   t2, BOARD_MMIO_BASE
    add  t2, t2, t0
    lbu  t3, 0(t2)           # t3 = tablero remoto[idx]
                             #   0 = vacío
                             #   1 = barco remoto
                             #   2 = barco remoto ya impactado

    # Preparar coord para enviar al PC
    slli t5, s2, 4
    or   t5, t5, s3          # t5 = coord (fila<<4 | col)

    # ¿Ya estaba impactado? (2) ? NO hacer nada (ni pintar ni enviar)
    li   t0, 2
    beq  t3, t0, shot_already_hit

    # ¿Hay barco remoto nuevo? (1) ? HIT y marcar como "impactado"
    li   t0, 1
    beq  t3, t0, shot_new_hit

    # En cualquier otro caso (0) ? MISS
    j    shot_miss

shot_new_hit:
    # Marcar tablero remoto como "ya impactado" (2)
    li   t0, 2
    sb   t0, 0(t2)           # mem[idx] = 2 = barco impactado

    # Pintar en VGA impacto (rojo)
    li   t4, VGA_HIT         # 3
    j    shot_paint_send

shot_miss:
    # MISS (no había barco remoto ni propio)
    li   t4, VGA_MISS        # 2
    j    shot_paint_send

shot_already_hit:
    # Ya se había impactado este barco antes:
    # NO cambiamos la VGA ni enviamos nada al PC.
    j    no_confirm

shot_paint_send:
    # Pintar en VGA la celda (s2,s3) con t4 (HIT o MISS)
    li   t2, VGA_BASE
    slli t0, s2, 4
    add  t0, t0, s3
    add  t2, t2, t0
    sw   t4, 0(t2)

 
    j    no_confirm

no_confirm:

############################################################
# CANCEL: limpiar SOLO la celda actual (y avisar a PC)
############################################################
    li  t0, BIT_CANCEL
    and t1, t6, t0          # bit actual
    and t4, s1, t0          # bit previo

    beqz t1, no_cancel
    bnez t4, no_cancel      # ya estaba pulsado ? nada

    # => flanco en CANCEL ? borrar celda actual en VGA
    li   t2, VGA_BASE
    slli t3, s2, 4
    add  t3, t3, s3
    add  t2, t2, t3
    li   t1, VGA_EMPTY
    sw   t1, 0(t2)

    # ---- Avisar a PC: coord + estado=0 ----
    slli t5, s2, 4
    or   t5, t5, s3         # t5 = coord
    mv   a0, t5
    jal  ra, uart_send_byte     # coord

    li   a0, VGA_EMPTY
    jal  ra, uart_send_byte     # estado vac?o

no_cancel:

############################################################
# ROTATE: cambiar orientaci?n H<->V
############################################################
    li  t0, BIT_ROTATE
    and t1, t6, t0          # bit actual
    and t4, s1, t0          # bit previo

    beqz t1, no_rotate
    bnez t4, no_rotate      # ya estaba pulsado ? nada

    # flanco en ROTATE ? toggle orientaci?n (NO toca ships_placed)
    xori s5, s5, 1          # 0 -> 1, 1 -> 0

no_rotate:

############################################################
# Guardar MSTA_PREV para el siguiente ciclo
############################################################
    mv s1, t6

############################################################
# UART RX: handshake en 2 fases
#          PC ? VGA, barcos del PC se guardan en tablero remoto MMIO
############################################################
    # ?Tenemos lectura pendiente?
    bnez s4, rx_do_read      # s4 != 0 ? ya pedimos LEER, toca leer DAT

rx_check_new:
    # Fase 0: todav?a no hemos pedido LEER, miramos RXAV
    li   t0, UART_CSR
    lw   t1, 0(t0)
    andi t1, t1, UART_RXAV_MASK
    beqz t1, no_rx_data      # RXAV=0 ? nada que hacer

    # Hay datos: pedimos a la FSM que saque uno a UART_DAT
    li   t0, UART_CSR
    li   t1, UART_LEER_MASK
    sw   t1, 0(t0)

    li   s4, 1               # marcar que hay lectura pendiente
    j    no_rx_data          # leeremos en el pr?ximo loop

rx_do_read:
    # Fase 1: ya pedimos LEER en el ciclo anterior, ahora leemos UART_DAT
    li   t0, UART_DAT
    lw   t1, 0(t0)
    andi t1, t1, 0xFF        # t1 = coord (fila<<4 | col)

    li   s4, 0               # limpiar flag pendiente

    # Decodificar fila/col de coord
    andi t2, t1, 0x0F        # col = nibble bajo
    srli t3, t1, 4
    andi t3, t3, 0x0F        # fila = nibble alto

    # Actualizar s2/s3 (cursor se mueve al punto del PC)
    mv   s2, t3
    mv   s3, t2

    # Actualizar cursor VGA con la coord recibida
    # fila
    li   t0, VGA_CUR_ROW
    andi t4, s2, 0x0F
    sw   t4, 0(t0)

    # columna
    li   t0, VGA_CUR_COL
    andi t4, s3, 0x0F
    sw   t4, 0(t0)

    # habilitar cursor
    li   t0, VGA_CUR_CTRL
    li   t4, 1
    sw   t4, 0(t0)

    # Debug en LEDs con coord recibida
    li   t5, 0
    or   t5, t5, s3           # col
    slli t4, s2, 4            # row
    or   t5, t5, t4
    li   t0, LEDS
    sw   t5, 0(t0)

    # ---- Actualizar tablero remoto: tablero[row*10+col] = 1 (MMIO) ----
    slli t0, s2, 3           # row*8
    slli t1, s2, 1           # row*2
    add  t0, t0, t1          # row*10
    add  t0, t0, s3          # idx = row*10 + col

    li   t2, BOARD_MMIO_BASE
    add  t2, t2, t0          # t2 = BOARD_MMIO_BASE + idx

    li   t3, 1
    sb   t3, 0(t2)           # escribir 1 = barco remoto

    # NOTA: ya NO pintamos el barco remoto en VGA.
    # Igual que en Python: los barcos enemigos son invisibles,
    # solo se verán los HIT/MISS que se dibujan en confirm_shot.


no_rx_data:

############################################################
# Loop infinito
############################################################
    j loop


# ---------------------------------------------------------
# Subrutina: uart_send_byte
#   Entrada: a0 = byte a enviar (solo usa [7:0])
# ---------------------------------------------------------
uart_send_byte:
    li   t0, UART_DAT
    andi a0, a0, 0xFF       # asegurar solo 8 bits
    sw   a0, 0(t0)
    ret