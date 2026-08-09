    .text
    .globl _start

    # Si ya tienes mmio.inc con estas .equ, puedes quitar estas 3 líneas
    .equ MANDO_DAT, 0x00010000
    .equ MANDO_STA, 0x00010004
    .equ LEDS,      0x00010010

_start:
    # t0 <- dir MANDO_DAT
    li   t0, MANDO_DAT
    # t1 <- dir MANDO_STA
    li   t1, MANDO_STA
    # t2 <- dir LEDS
    li   t2, LEDS

loop:
    # ------------------------------------------------------------
    # 1) Leer fila/columna desde MANDO_DAT
    #     [7:4] = fila, [3:0] = columna
    # ------------------------------------------------------------
    lw   t3, 0(t0)          # t3 = MANDO_DAT

    # col = bits [3:0]
    andi t4, t3, 0x000F     # t4 = col (4 bits)

    # row = bits [7:4]
    srli t5, t3, 4          # desplazar a LSB
    andi t5, t5, 0x000F     # t5 = row (4 bits)

    # empaquetar en LEDs[7:0] = {row, col}
    slli t5, t5, 4          # row << 4
    or   t6, t5, t4         # t6[7:4]=row, t6[3:0]=col

    # ------------------------------------------------------------
    # 2) Leer botones de acción desde MANDO_STA
    #     bit0 = CONFIRM, bit1 = CANCEL, bit2 = ROTATE
    #     los ponemos en LEDs[10:8]
    # ------------------------------------------------------------
    lw   t7, 0(t1)          # t7 = MANDO_STA
    andi t7, t7, 0x0007     # solo bits 2:0
    slli t7, t7, 8          # mover a bits 10:8

    # ------------------------------------------------------------
    # 3) Combinar todo en un solo valor y mandarlo a LEDs
    # ------------------------------------------------------------
    or   t6, t6, t7         # t6 = [10:8] botones, [7:4] row, [3:0] col
    sw   t6, 0(t2)          # escribir a LEDs

    j    loop               # repetir para siempre
