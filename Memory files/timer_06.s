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

    .equ UART_BIT_ENVIAR, 0           # bit0: ENVIAR   (no lo usamos aquí)
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
# CONVENCIÓN DE ESTADOS VGA (ALINEADO CON board_logic)
# =========================
    .equ VGA_EMPTY,       0   # 00 = vacío / agua de fondo
    .equ VGA_SHIP_LOCAL,  1   # 01 = barco (local)
    .equ VGA_SHIP_REMOTE, 1   # 01 = barco (remoto, mismo código)
    .equ VGA_SHIP,        VGA_SHIP_LOCAL
    .equ VGA_MISS,        2   # 10 = fallo (agua azul)
    .equ VGA_HIT,         3   # 11 = acierto (rojo)

# =========================
# BARCOS
# =========================
    .equ SHIP_MAX,        5   # barcos: longitudes 5,4,3,2,1

# =========================
# TABLERO REMOTO (PC) – MMIO
# =========================
    .equ BOARD_SIZE,       100       # 10x10 celdas
    .equ BOARD_MMIO_BASE,  0x00010200  # debe coincidir con ADDR_BOARD_BASE del MMIO

# =========================
# FASES
# =========================
    .equ PHASE_PLACE,     0   # colocando barcos locales
    .equ PHASE_BATTLE,    1   # disparando a barcos remotos

# =========================
# TIMER MMIO (Timer_Top)
# =========================
    .equ TIM_CTRL,        0x00010050   # addr=0 en Timer_Top (CTRL/STATUS)
    .equ TIM_COUNTER,     0x00010054   # addr=1 en Timer_Top (LOAD/COUNT)

    .equ TIM_BIT_START,     0         # bit0 = START
    .equ TIM_BIT_AUTOREL,   1         # bit1 = AUTO_RELOAD
    .equ TIM_BIT_TIMEOUT,   2         # bit2 = TIMEOUT (flag)

    .equ TIM_START_MASK,    1         # (1 << 0) = 1
    .equ TIM_AUTOREL_MASK,  2         # (1 << 1) = 2
    .equ TIM_TIMEOUT_MASK,  4         # (1 << 2) = 4

    # Timer_Top se alimenta con clk_16mhz_i (16 MHz)
    # 30 s -> 16e6 * 30 = 480 000 000 cuentas
    .equ TURN_30S_TICKS,  480000000

# =========================
# REGS:
#   s0 = ships_placed (0..5)
#   s1 = MSTA_PREV (estado previo de botones)
#   s2 = fila actual (0..9)
#   s3 = columna actual (0..9)
#   s4 = flag lectura UART pendiente (0 = no, 1 = sí)
#   s5 = orientation (0 = horizontal, 1 = vertical)
#   s6 = len del barco actual (5,4,3,2,1)
#   s7 = fase de juego (0 = placement, 1 = battle)
#   s8 = current_turn (0 = Jugador1 VGA, 1 = Jugador2 PC)
# =========================


# ---------------------------------------------------------
# Programa principal (mando + VGA + barcos + TX/RX UART)
# ---------------------------------------------------------
_start:
    # Inicialización de estado
    li  s0, 0    # ships_placed = 0
    li  s2, 0    # fila
    li  s3, 0    # col
    li  s4, 0    # sin lectura UART pendiente
    li  s5, 0    # orientación: 0 = horizontal
    li  s6, 0    # len (se calcula en cada CONFIRM)
    li  s7, PHASE_PLACE   # fase inicial: colocación
    li  s8, 0    # turno inicial: Jugador 1 (VGA)

    # Inicializamos MSTA_PREV con el valor real de los botones
    li  t0, MANDO_STA
    lw  t1, 0(t0)
    mv  s1, t1    # MSTA_PREV = estado actual de botones

main:
loop:
############################################################
# Leer posición del mando: MANDO_DAT
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
# LED14   = Jugador 2
# LED15   = Jugador 1
############################################################
    li t5, 0            # LED[3:0] = col
    or t5, t5, s3
    # LED[7:4] = row
    slli t4, s2, 4
    or t5, t5, t4
    # LED[9:8] = ships_placed
    slli t4, s0, 8      # ships_placed << 8
    or t5, t5, t4

    # Indicador de turno
    li   t0, 0
    beqz s8, leds_p1        # s8==0 ? Jugador1
    li   t0, 0x4000         # Jugador2 ? LED14 = 1<<14
    j    leds_turn_done
leds_p1:
    li   t0, 0x8000         # Jugador1 ? LED15 = 1<<15
leds_turn_done:
    or   t5, t5, t0

    li t0, LEDS
    sw t5, 0(t0)

############################################################
# Leer estado de botones: MANDO_STA
############################################################
    li t0, MANDO_STA
    lw t6, 0(t0)        # t6 = MANDO_STA (botones actuales)

############################################################
# Chequear timeout de turno (solo en fase batalla)
############################################################
    li   t0, PHASE_BATTLE
    bne  s7, t0, skip_turn_timeout   # solo en batalla

    # Leer registro de control del timer
    li   t0, TIM_CTRL
    lw   t1, 0(t0)
    andi t2, t1, TIM_TIMEOUT_MASK
    beqz t2, skip_turn_timeout       # TIMEOUT = 0 ? nada

    # TIMEOUT = 1 -> jugador activo pierde su turno
    jal  ra, advance_turn            # alterna jugador
    jal  ra, start_turn_timer        # reinicia timer para el nuevo jugador

skip_turn_timeout:

############################################################
# CONFIRM: según fase ? colocar barco o disparar
############################################################
    li  t0, BIT_CONFIRM  # máscara bit CONFIRM
    and t1, t6, t0       # t1 = bit actual
    and t4, s1, t0       # t4 = bit previo
    beqz t1, no_confirm  # actual = 0 ? nada
    bnez t4, no_confirm  # previo = 1 ? ya estaba pulsado ? no flanco

    # Flanco en CONFIRM: decidir por fase
    li  t0, PHASE_PLACE
    beq s7, t0, confirm_place
    j   confirm_shot

# ---------------------------------------------------------
# FASE COLOCACIÓN: CONFIRM coloca barco actual (5,4,3,2,1)
#                  y lo manda al PC (state=1)
# ---------------------------------------------------------
confirm_place:
    # ¿Quedan barcos por colocar? (s0 < SHIP_MAX)
    li  t2, SHIP_MAX
    bge s0, t2, no_confirm   # si s0 >= 5 ? ya no colocar más

    # len = 5 - ships_placed  ? 5,4,3,2,1
    li  t0, 5
    sub s6, t0, s0           # s6 = len (NO tocar en los loops)

    # ------------------------------------
    # Orientación: s5 = 0 ? H, s5 = 1 ? V
    # ------------------------------------
    beqz s5, place_horizontal

    ########################################################
    # Colocación VERTICAL (s5 = 1)
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
    # Colocación HORIZONTAL (s5 = 0)
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

    # Si acabamos de colocar el último barco, pasar a fase batalla
    li   t0, SHIP_MAX
    bne  s0, t0, no_confirm
    li   s7, PHASE_BATTLE    # ahora CONFIRM será disparo

    # Iniciar turno 1 con timer de 30 s
    li   s8, 0               # turno Jugador1
    jal  ra, start_turn_timer

    j    no_confirm

# ---------------------------------------------------------
# FASE BATALLA: CONFIRM hace DISPARO contra barcos remotos
#               usando la tabla lógica REMOTA por MMIO
# ---------------------------------------------------------
confirm_shot:
    # Solo Jugador1 (s8=0) puede disparar con CONFIRM
    bnez s8, no_confirm

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

    # Preparar coord para enviar al PC (si en el futuro quieres mandar resultado)
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
    # MISS (no había barco remoto)
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

    # Disparó Jugador1 ? pasa turno a Jugador2 y reinicia timer
    jal  ra, advance_turn
    jal  ra, start_turn_timer

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
    jal  ra, uart_send_byte     # estado vacío

no_cancel:

############################################################
# ROTATE: cambiar orientación H<->V
############################################################
    li  t0, BIT_ROTATE
    and t1, t6, t0          # bit actual
    and t4, s1, t0          # bit previo

    beqz t1, no_rotate
    bnez t4, no_rotate      # ya estaba pulsado ? nada

    # flanco en ROTATE ? toggle orientación (NO toca ships_placed)
    xori s5, s5, 1          # 0 -> 1, 1 -> 0

no_rotate:

############################################################
# Guardar MSTA_PREV para el siguiente ciclo
############################################################
    mv s1, t6

############################################################
# UART RX: handshake en 2 fases
#   - PHASE_PLACE: barcos del PC ? BOARD_MMIO_BASE
#   - PHASE_BATTLE: si turno PC (s8=1) ? DISPARO Jugador2
############################################################
    # ¿Tenemos lectura pendiente?
    bnez s4, rx_do_read      # s4 != 0 ? ya pedimos LEER, toca leer DAT

rx_check_new:
    # Fase 0: todavía no hemos pedido LEER, miramos RXAV
    li   t0, UART_CSR
    lw   t1, 0(t0)
    andi t1, t1, UART_RXAV_MASK
    beqz t1, no_rx_data      # RXAV=0 ? nada que hacer

    # Hay datos: pedimos a la FSM que saque uno a UART_DAT
    li   t0, UART_CSR
    li   t1, UART_LEER_MASK
    sw   t1, 0(t0)

    li   s4, 1               # marcar que hay lectura pendiente
    j    no_rx_data          # leeremos en el próximo loop

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

    # Debug en LEDs con coord recibida (ignora turno por simplicidad aquí)
    li   t5, 0
    or   t5, t5, s3           # col
    slli t4, s2, 4            # row
    or   t5, t5, t4
    li   t0, LEDS
    sw   t5, 0(t0)

    # Seleccionar según fase
    li   t0, PHASE_PLACE
    beq  s7, t0, rx_place_ship

    li   t0, PHASE_BATTLE
    beq  s7, t0, rx_battle

    j    no_rx_data

# ----------------------------
# UART RX en PHASE_PLACE:
#   PC manda barcos remotos ? BOARD_MMIO_BASE[idx] = 1
# ----------------------------
rx_place_ship:
    # idx = row*10 + col
    slli t0, s2, 3           # row*8
    slli t1, s2, 1           # row*2
    add  t0, t0, t1          # row*10
    add  t0, t0, s3          # idx = row*10 + col

    li   t2, BOARD_MMIO_BASE
    add  t2, t2, t0          # t2 = BOARD_MMIO_BASE + idx

    li   t3, 1
    sb   t3, 0(t2)           # escribir 1 = barco remoto

    j    no_rx_data

# ----------------------------
# UART RX en PHASE_BATTLE:
#   Turno Jugador2 (PC) ? disparo contra tablero REMOTO
#   (por ahora SOLO consume el disparo y pasa turno)
# ----------------------------
rx_battle:
    # Solo cuenta si es turno del Jugador2
    li   t0, 1
    bne  s8, t0, no_rx_data

    # Aquí podrías en el futuro decidir HIT/MISS contra tablero local,
    # pero por ahora solo consumimos el disparo y alternamos turno.
    jal  ra, advance_turn
    jal  ra, start_turn_timer
    j    no_rx_data


no_rx_data:

############################################################
# Loop infinito
############################################################
    j loop


# ---------------------------------------------------------
# Subrutina: start_turn_timer
#   Configura Timer_Top para contar 30 s y lo arranca.
#   Usa: t0, t1
# ---------------------------------------------------------
start_turn_timer:
    # Cargar valor de 30 s en TIM_COUNTER
    li   t0, TIM_COUNTER
    li   t1, TURN_30S_TICKS
    sw   t1, 0(t0)

    # Forzar flanco de START: 0 -> 1 (con AUTORELOAD=1)
    li   t0, TIM_CTRL
    li   t1, 0
    sw   t1, 0(t0)          # start_bit = 0
    li   t1, 3              # START=1, AUTORELOAD=1
    sw   t1, 0(t0)          # start_bit: 0 -> 1 ? flanco

    ret

# ---------------------------------------------------------
# Subrutina: advance_turn
#   Alterna entre Jugador1 (VGA) y Jugador2 (PC)
#   y ENVÍA por UART un paquete especial:
#      coord = 0xFF
#      state = 0x00 ? turno VGA
#      state = 0x01 ? turno PC
# ---------------------------------------------------------
advance_turn:
    # Alternar turno: s8 = s8 XOR 1
    xori s8, s8, 1

    # Enviar paquete de cambio de turno por UART
    li   t0, UART_DAT

    # coord = 0xFF
    li   t1, 0xFF
    sw   t1, 0(t0)

    # state = 0x00 si turno VGA (s8=0), 0x01 si turno PC (s8=1)
    beqz s8, adv_p1
    li   t1, 1
    j    adv_send_state
adv_p1:
    li   t1, 0
adv_send_state:
    sw   t1, 0(t0)

    ret


# ---------------------------------------------------------
# Subrutina: uart_send_byte
#   Entrada: a0 = byte a enviar (solo usa [7:0])
# ---------------------------------------------------------
uart_send_byte:
    li   t0, UART_DAT
    andi a0, a0, 0xFF       # asegurar solo 8 bits
    sw   a0, 0(t0)
    ret
