.text
    .globl _start

    # =========================
    #  DIRECCIONES MMIO
    # =========================
    .equ MANDO_DAT,     0x00010000   # [7:4]=fila, [3:0]=col
    .equ MANDO_STA,     0x00010004   # bits de botones
    .equ LEDS,          0x00010010

    # Registros de cursor VGA (ya probados)
    .equ VGA_CUR_ROW,   0x0001006C   # fila  (bits [3:0])
    .equ VGA_CUR_COL,   0x0001007C   # col   (bits [3:0])
    .equ VGA_CUR_CTRL,  0x0001008C   # bit0 = enable cursor

    # Base de celdas VGA
    .equ VGA_BASE,      0x00010060   # ADDR_CELL = BASE + (row<<4) + col

    # Máscaras de botones en MANDO_STA (bits)
    .equ BIT_CONFIRM,   1            # bit0
    .equ BIT_CANCEL,    2            # bit1
    .equ BIT_ROTATE,    4            # bit2

    # Barcos: longitudes 5,4,3,2,1
    .equ SHIP_MAX,      5            # cantidad de barcos

    # Convención de estado en vga_wdata[1:0]:
    #   0: vacío
    #   1: barco
    #   2: fallo (agua)
    #   3: impacto

    # Uso de registros:
    #   s0 = ships_placed (0..5)
    #   s1 = MSTA_PREV (estado previo de botones)
    #   s2 = fila actual (0..9)
    #   s3 = columna actual (0..9)
    #   s4 = orientation (0 = horizontal, 1 = vertical)
    #   a0 = len (longitud del barco actual)

_start:
    # --------------------------------------------
    # Inicialización de estado
    # --------------------------------------------
    li      s0, 0          # ships_placed = 0
    li      s2, 0          # fila
    li      s3, 0          # col
    li      s4, 0          # orientación inicial: horizontal

    # Inicializar MSTA_PREV leyendo el hardware
    li      t0, MANDO_STA
    lw      t1, 0(t0)      # t1 = estado actual botones
    mv      s1, t1         # s1 = MSTA_PREV = valor real

main:
loop:
    ############################################################
    #  Leer posición del mando: MANDO_DAT
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
    #  Escribir cursor VGA por MMIO
    ############################################################
    li      t0, VGA_CUR_ROW
    andi    t4, s2, 0xF
    sw      t4, 0(t0)

    li      t0, VGA_CUR_COL
    andi    t4, s3, 0xF
    sw      t4, 0(t0)

    li      t0, VGA_CUR_CTRL
    li      t4, 1
    sw      t4, 0(t0)

    ############################################################
    #  Debug en LEDs:
    #    LED[3:0]  = col
    #    LED[7:4]  = row
    #    LED[9:8]  = ships_placed
    ############################################################
    li      t5, 0
    or      t5, t5, s3          # col
    slli    t4, s2, 4
    or      t5, t5, t4          # row
    slli    t4, s0, 8
    or      t5, t5, t4          # ships_placed
    li      t0, LEDS
    sw      t5, 0(t0)

    ############################################################
    # Leer estado de botones: MANDO_STA
    ############################################################
    li      t0, MANDO_STA
    lw      t6, 0(t0)           # t6 = MANDO_STA (botones actuales)

    ############################################################
    #  CONFIRM: colocar barco actual (5,4,3,2,1) según s0
    ############################################################
    li      t0, BIT_CONFIRM
    and     t1, t6, t0          # t1 = bit actual (CONFIRM)
    and     t4, s1, t0          # t4 = bit previo

    beqz    t1, no_confirm      # actual = 0 ? nada
    bnez    t4, no_confirm      # previo = 1 ? no es flanco ?

    # ¿Quedan barcos por colocar? (s0 < SHIP_MAX)
    li      t2, SHIP_MAX
    bge     s0, t2, no_confirm  # si s0 >= 5 ? ya no colocar más

    # len = 5 - ships_placed  (usar a0, NO t6)
    li      t0, 5
    sub     a0, t0, s0          # a0 = len (5,4,3,2,1)

    # ------------------------------------
    # Orientación: s4 = 0 ? H, s4 = 1 ? V
    # ------------------------------------
    beqz    s4, place_horizontal

    ############################################################
    # Colocación VERTICAL (s4 = 1)
    ############################################################
    # start_row <= 10 - len
    li      t0, 10
    sub     t1, t0, a0          # t1 = 10 - len
    mv      t2, s2              # t2 = start_row provisional

    ble     s2, t1, row_ok_v
    mv      t2, t1              # si no cabe, lo pegamos al borde
row_ok_v:
    li      t3, 0               # k = 0
vert_loop:
    bge     t3, a0, vert_done   # k >= len ? fin

    # row_k = start_row + k
    add     t4, t2, t3          # t4 = row_k

    # addr = VGA_BASE + (row_k << 4) + col
    li      t0, VGA_BASE
    slli    t1, t4, 4
    add     t1, t1, s3
    add     t0, t0, t1

    li      t5, 1               # estado 1 = BARCO
    sw      t5, 0(t0)

    addi    t3, t3, 1
    j       vert_loop

vert_done:
    j       placed_done

    ############################################################
    # Colocación HORIZONTAL (s4 = 0)
    ############################################################
place_horizontal:
    # start_col <= 10 - len
    li      t0, 10
    sub     t1, t0, a0          # t1 = 10 - len
    mv      t2, s3              # t2 = start_col provisional

    ble     s3, t1, col_ok_h
    mv      t2, t1              # si no cabe, lo pegamos al borde
col_ok_h:
    li      t3, 0               # k = 0
horiz_loop:
    bge     t3, a0, horiz_done  # k >= len ? fin

    # col_k = start_col + k
    add     t4, t2, t3          # t4 = col_k

    # addr = VGA_BASE + (row << 4) + col_k
    li      t0, VGA_BASE
    slli    t1, s2, 4
    add     t1, t1, t4
    add     t0, t0, t1

    li      t5, 1               # estado 1 = BARCO
    sw      t5, 0(t0)

    addi    t3, t3, 1
    j       horiz_loop

horiz_done:
    # cae en placed_done

placed_done:
    addi    s0, s0, 1           # ships_placed++

no_confirm:

    ############################################################
    # CANCEL: limpiar SOLO la celda actual
    ############################################################
    li      t0, BIT_CANCEL
    and     t1, t6, t0          # bit actual (usa MANDO_STA real en t6)
    and     t4, s1, t0          # bit previo

    beqz    t1, no_cancel
    bnez    t4, no_cancel       # ya estaba pulsado ? nada

    # => flanco en CANCEL ? borrar celda actual
    li      t2, VGA_BASE
    slli    t3, s2, 4
    add     t3, t3, s3
    add     t2, t2, t3
    li      t1, 0
    sw      t1, 0(t2)

no_cancel:

    ############################################################
    # ROTATE: cambiar orientación H?V
    ############################################################
    li      t0, BIT_ROTATE
    and     t1, t6, t0          # bit actual (MANDO_STA)
    and     t4, s1, t0          # bit previo

    beqz    t1, no_rotate
    bnez    t4, no_rotate

    # flanco en ROTATE ? toggle
    xori    s4, s4, 1

no_rotate:

    ############################################################
    # Guardar MSTA_PREV para el siguiente ciclo
    ############################################################
    mv      s1, t6              # MSTA_PREV = MANDO_STA real

    ############################################################
    # Loop infinito
    ############################################################
    j       loop
