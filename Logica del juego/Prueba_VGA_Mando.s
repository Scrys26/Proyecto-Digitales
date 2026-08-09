    .text
    .globl _start

    # =========================
    #  DIRECCIONES MMIO
    # =========================
    .equ MANDO_DAT,     0x00010000   # [7:4]=fila, [3:0]=col
    .equ LEDS,          0x00010010

    # Registros de cursor VGA
    .equ VGA_CUR_ROW,   0x00010070   # fila  (bits [3:0])
    .equ VGA_CUR_COL,   0x00010074   # col   (bits [3:0])
    .equ VGA_CUR_CTRL,  0x00010078   # bit0 = enable cursor

_start:
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

    ############################################################
    # 2) Escribir cursor VGA por MMIO
    ############################################################

    # Escribir fila en VGA_CUR_ROW (bits [3:0])
    li      t0, VGA_CUR_ROW
    andi    t4, t3, 0xF         # asegurar solo 4 bits
    sw      t4, 0(t0)

    # Escribir columna en VGA_CUR_COL (bits [3:0])
    li      t0, VGA_CUR_COL
    andi    t4, t2, 0xF
    sw      t4, 0(t0)

    # Habilitar cursor (VGA_CUR_CTRL bit0 = 1)
    li      t0, VGA_CUR_CTRL
    li      t4, 1               # bit0 = 1 → cursor ON
    sw      t4, 0(t0)

    ############################################################
    # 3) Debug en LEDs:
    #    LED[3:0]  = col
    #    LED[7:4]  = row
    ############################################################
    li      t5, 0

    # LED[3:0] = col
    or      t5, t5, t2

    # LED[7:4] = row
    slli    t3, t3, 4
    or      t5, t5, t3

    li      t0, LEDS
    sw      t5, 0(t0)

    ############################################################
    # 4) Loop infinito
    ############################################################
    j       loop
