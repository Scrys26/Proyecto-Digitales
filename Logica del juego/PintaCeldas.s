    .text
    .globl _start

    # =========================
    #  DIRECCIONES MMIO
    # =========================
    .equ MANDO_DAT,     0x00010000   # [7:4]=fila, [3:0]=col
    .equ MANDO_STA,     0x00010004   # bits de botones

    .equ LEDS,          0x00010010

    # Registros de cursor VGA
    .equ VGA_CUR_ROW,   0x00010070   # fila  (bits [3:0])
    .equ VGA_CUR_COL,   0x00010074   # col   (bits [3:0])
    .equ VGA_CUR_CTRL,  0x00010078   # bit0 = enable cursor

    # Base de celdas VGA (BattleshipVGA_MMIO)
    .equ VGA_BASE,      0x00010060   # ADDR_CELL = BASE + (row<<4) + col

    # Máscaras de botones en MANDO_STA
    .equ BIT_CONFIRM,   1            # bit0
    .equ BIT_CANCEL,    2            # bit1
    .equ BIT_ROTATE,    4            # bit2

    # Convención de estado (vga_wdata[1:0]):
    #   0: vacío
    #   1: barco
    #   2: fallo (agua)
    #   3: impacto

# s0 = modo actual (1..3)
# s1 = MSTA_PREV (valor anterior de MANDO_STA)
# s2 = fila actual (0..9)
# s3 = columna actual (0..9)

_start:
    li      s0, 1          # modo inicial: 1 = barco
    li      s1, 0          # sin botones previos
    li      s2, 0          # fila
    li      s3, 0          # columna

main:
loop:
    ############################################################
    # 1) Leer posición del mando: MANDO_DAT
    ############################################################
    li      t0, MANDO_DAT
    lw      t1, 0(t0)           # t1 = MANDO_DAT

    # col = t1[3:0]
    andi    t2, t1, 0xF         # t2 = col (0..9)

    # row = (t1 >> 4) & 0xF
    srli    t3, t1, 4           # t3 = t1 >> 4
    andi    t3, t3, 0xF         # t3 = row (0..9)

    # Guardar fila/col en s2/s3 para usarlos luego
    mv      s2, t3              # fila
    mv      s3, t2              # col

    ############################################################
    # 2) Actualizar cursor VGA por MMIO
    ############################################################

    # Escribir fila en VGA_CUR_ROW (bits [3:0])
    li      t0, VGA_CUR_ROW
    andi    t4, s2, 0xF         # asegurar solo 4 bits
    sw      t4, 0(t0)

    # Escribir columna en VGA_CUR_COL (bits [3:0])
    li      t0, VGA_CUR_COL
    andi    t4, s3, 0xF
    sw      t4, 0(t0)

    # Habilitar cursor (VGA_CUR_CTRL bit0 = 1)
    li      t0, VGA_CUR_CTRL
    li      t4, 1               # bit0 = 1 → cursor ON
    sw      t4, 0(t0)

    ############################################################
    # 3) Debug en LEDs:
    #    LED[3:0]  = col
    #    LED[7:4]  = row
    #    LED[9:8]  = modo actual (1,2,3)
    ############################################################
    li      t5, 0

    # LED[3:0] = col
    or      t5, t5, s3          # col

    # LED[7:4] = row
    slli    t4, s2, 4           # row << 4
    or      t5, t5, t4

    # LED[9:8] = modo (s0)
    slli    t4, s0, 8           # modo << 8
    or      t5, t5, t4

    li      t0, LEDS
    sw      t5, 0(t0)

    ############################################################
    # 4) Leer estado de botones: MANDO_STA
    ############################################################
    li      t0, MANDO_STA
    lw      t6, 0(t0)           # t6 = MANDO_STA (botones actuales)

    ############################################################
    # 5) Detectar flancos de subida y actuar
    ############################################################

    # ------------------------
    # 5.1) CONFIRM: escribir celda con modo actual (s0)
    # ------------------------
    li      t0, BIT_CONFIRM     # máscara bit CONFIRM
    and     t1, t6, t0          # t1 = bit actual
    and     t4, s1, t0          # t4 = bit previo

    beqz    t1, no_confirm      # si actual = 0, no hay flanco
    bnez    t4, no_confirm      # si previo = 1, ya estaba pulsado

    # => Flanco de subida en CONFIRM

    # Calcular dirección de celda:
    # addr = VGA_BASE + (row << 4) + col
    li      t2, VGA_BASE
    slli    t3, s2, 4           # (row << 4)
    add     t3, t3, s3          # + col
    add     t2, t2, t3          # t2 = dirección final

    # Dato: estado actual (s0) en bits [1:0]
    andi    t1, s0, 0x3
    sw      t1, 0(t2)

no_confirm:

    # ------------------------
    # 5.2) CANCEL: limpiar celda (estado 0)
    # ------------------------
    li      t0, BIT_CANCEL
    and     t1, t6, t0          # bit actual
    and     t4, s1, t0          # bit previo

    beqz    t1, no_cancel
    bnez    t4, no_cancel       # si ya estaba pulsado, nada

    # => Flanco de subida en CANCEL

    li      t2, VGA_BASE
    slli    t3, s2, 4
    add     t3, t3, s3
    add     t2, t2, t3          # t2 = dirección celda

    li      t1, 0               # estado 0 = vacío
    sw      t1, 0(t2)

no_cancel:

    # ------------------------
    # 5.3) ROTATE: cambiar modo (1->2->3->1...)
    # ------------------------
    li      t0, BIT_ROTATE
    and     t1, t6, t0          # bit actual
    and     t4, s1, t0          # bit previo

    beqz    t1, no_rotate
    bnez    t4, no_rotate       # si previo era 1, no es flanco

    # => Flanco de subida en ROTATE
    addi    s0, s0, 1           # modo++

    # Si s0 >= 4, volver a 1
    li      t3, 4
    blt     s0, t3, rotate_ok   # si s0 < 4, está bien (1..3)
    li      s0, 1               # si llegó a 4, reiniciar a 1
rotate_ok:

no_rotate:

    ############################################################
    # 6) Guardar MSTA_PREV para el siguiente ciclo
    ############################################################
    mv      s1, t6

    ############################################################
    # 7) Loop infinito
    ############################################################
    j       loop
