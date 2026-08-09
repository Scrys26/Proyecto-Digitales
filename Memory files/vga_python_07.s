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
# CONVENCIÓN DE ESTADOS VGA
# =========================
    .equ VGA_EMPTY,       0
    .equ VGA_SHIP,        1
    .equ VGA_MISS,        2
    .equ VGA_HIT,         3
    
# =========================
# REGS:
#   s0 = modo actual de pintado (1..3)
#   s1 = MSTA_PREV (estado previo de botones)
#   s2 = fila actual (0..9)
#   s3 = columna actual (0..9)
#   s4 = flag lectura UART pendiente (0 = no, 1 = sí)
# =========================

# ---------------------------------------------------------
# Programa principal (lógica mando + VGA + TX/RX UART)
# ---------------------------------------------------------
_start:
    # Inicialización de modo y estado previo
    li s0, 1    # modo inicial: 1 = barco
    li s1, 0    # MSTA_PREV = 0
    li s2, 0    # fila
    li s3, 0    # col
    li s4, 0    # sin lectura UART pendiente

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
# LED[9:8] = modo actual (1,2,3)
############################################################
    li t5, 0            # LED[3:0] = col
    or t5, t5, s3
    # LED[7:4] = row
    slli t4, s2, 4
    or t5, t5, t4
    # LED[9:8] = modo actual (s0)
    slli t4, s0, 8      # modo << 8
    or t5, t5, t4
    li t0, LEDS
    sw t5, 0(t0)

############################################################
# Leer estado de botones: MANDO_STA
############################################################
    li t0, MANDO_STA
    lw t6, 0(t0)        # t6 = MANDO_STA (botones actuales)

############################################################
# Detectar flancos y pintar celdas (mando ? VGA + TX UART)
############################################################
# ------------------------
# CONFIRM: pintar celda con modo actual (s0)
# ------------------------
    li t0, BIT_CONFIRM  # máscara bit CONFIRM
    and t1, t6, t0      # t1 = bit actual
    and t4, s1, t0      # t4 = bit previo
    beqz t1, no_confirm # actual = 0 ? nada
    bnez t4, no_confirm # previo = 1 ? ya estaba pulsado
                        # => Flanco de subida en CONFIRM

    # addr = VGA_BASE + (row << 4) + col
    li t2, VGA_BASE
    slli t3, s2, 4      # (row << 4)
    add t3, t3, s3      # + col
    add t2, t2, t3      # t2 = dirección celda

    # Dato = modo actual en bits [1:0]
    andi t1, s0, 0x3
    sw t1, 0(t2)

    # --------- ENVIAR A PC POR UART ----------
    # Byte 1: coordenada = (fila<<4) | col
    slli t5, s2, 4          # fila en bits altos
    or   t5, t5, s3         # + col en bits bajos
    mv   a0, t5
    jal  ra, uart_send_byte

    # Byte 2: estado = modo actual (1..3)
    mv   a0, s0
    jal  ra, uart_send_byte
    # -----------------------------------------

no_confirm:
# ------------------------
# CANCEL: limpiar celda (estado = 0)
# ------------------------
    li t0, BIT_CANCEL
    and t1, t6, t0      # bit actual
    and t4, s1, t0      # bit previo
    beqz t1, no_cancel
    bnez t4, no_cancel  # ya estaba pulsado ? nada
                        # => Flanco de subida en CANCEL

    li t2, VGA_BASE
    slli t3, s2, 4
    add t3, t3, s3
    add t2, t2, t3      # t2 = dirección celda
    li t1, VGA_EMPTY    # estado 0 = vacío
    sw t1, 0(t2)

    # --------- ENVIAR A PC POR UART ----------
    # Byte 1: coordenada
    slli t5, s2, 4
    or   t5, t5, s3
    mv   a0, t5
    jal  ra, uart_send_byte

    # Byte 2: estado = 0 (vacío)
    li   a0, VGA_EMPTY
    jal  ra, uart_send_byte
    # -----------------------------------------

no_cancel:
# ------------------------
# ROTATE: cambiar modo (1->2->3->1...)
# ------------------------
    li t0, BIT_ROTATE
    and t1, t6, t0      # bit actual
    and t4, s1, t0      # bit previo
    beqz t1, no_rotate
    bnez t4, no_rotate  # si previo era 1, no es flanco
                        # => Flanco de subida en ROTATE

    addi s0, s0, 1      # modo++
    # Si s0 >= 4, volver a 1
    li t3, 4
    blt s0, t3, rotate_ok # si s0 < 4 ? ok (1..3)
    li s0, 1            # si llegó a 4 ? reinicia a 1

rotate_ok:
no_rotate:

############################################################
# Guardar MSTA_PREV para el siguiente ciclo
############################################################
    mv s1, t6

############################################################
# UART RX: handshake en 2 fases
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
    andi t1, t1, 0xFF        # t1 = coord

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

    # Pintar siempre "barco" en la celda recibida (VGA_SHIP)
    li   t0, VGA_BASE
    slli t1, s2, 4            # (row<<4)
    add  t1, t1, s3           # + col
    add  t0, t0, t1           # t0 = dirección celda

    li   t2, VGA_SHIP
    sw   t2, 0(t0)

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
