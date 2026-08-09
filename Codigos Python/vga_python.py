import tkinter as tk

try:
    import serial
    HAS_SERIAL = True
except ImportError:
    HAS_SERIAL = False

# ============================================
# CONFIGURACIÓN
# ============================================

N         = 10        # 10x10
CELL_SIZE = 35
MARGIN    = 50

# --- UART / RISC-V ---
USE_UART    = True          # Poner True para usar la FPGA
SERIAL_PORT = "COM6"        # Ajusta según tu PC
BAUDRATE    = 115200

# Color VGA base (4 bits -> 8 bits)
BOARD_COLOR = "#99DDFF"     # base_r=9, base_g=D, base_b=F


class BattleshipUARTBoard:
    """
    Tablero simple 10x10:

    - Cursor se mueve con flechas (Up, Down, Left, Right).
    - SPACE: pinta la celda actual en gris y envía coord por UART
      usando el formato: byte = (fila<<4) | col.
    - Además: recibe desde la FPGA paquetes de 2 bytes:
          [0] = coord = (fila<<4) | col
          [1] = estado = 0..3
      y actualiza el tablero para sincronizar con el VGA.
    """

    def __init__(self, root, use_uart=False, port=None, baudrate=115200):
        self.root = root
        self.root.title("Battleship – PC <-> FPGA por UART")

        self.use_uart = use_uart
        self.port = port
        self.baudrate = baudrate
        self.ser = None

        # Estado del tablero: 0 = vacío, 1 = barco, 2 = fallo, 3 = impacto
        self.board = [[0 for _ in range(N)] for _ in range(N)]

        # Cursor lógico
        self.cur_row = 0
        self.cur_col = 0

        # Construir GUI
        self._build_gui()

        # Inicializar UART
        self._init_uart()

    # ---------------- UART ----------------

    def _init_uart(self):
        if not self.use_uart:
            self.status_var.set("UART desactivado (USE_UART=False). Solo pinta en PC.")
            return

        if not HAS_SERIAL:
            self.status_var.set("ERROR: pyserial no instalado. Ejecuta: pip install pyserial")
            return

        try:
            self.status_var.set(f"Abriendo puerto serie {self.port}...")
            self.root.update_idletasks()
            # timeout pequeño / no bloqueante
            self.ser = serial.Serial(self.port, self.baudrate, timeout=0)
            self.status_var.set(f"Conectado a {self.port}. Flechas + SPACE, y recibe del VGA.")
            # Empezar a hacer polling del RX
            self.root.after(20, self._poll_uart_rx)
        except Exception as e:
            self.status_var.set(f"ERROR UART: {e}. Trabajando solo en modo local.")
            self.ser = None
            self.use_uart = False

    def _send_coord(self, fila, col):
        """Envía un byte coord = (fila<<4) | col por UART (PC -> FPGA)."""
        coord = ((fila & 0x0F) << 4) | (col & 0x0F)
        if self.ser is not None:
            try:
                self.ser.write(bytes([coord]))
            except Exception as e:
                self.status_var.set(f"ERROR envío UART: {e}")

    def _poll_uart_rx(self):
        """
        Lee paquetes desde la FPGA:
          coord = (fila<<4) | col
          state = 0..3
        y actualiza el tablero.
        """
        if self.ser is not None:
            try:
                while self.ser.in_waiting >= 2:
                    data = self.ser.read(2)
                    if len(data) < 2:
                        break
                    coord = data[0]
                    state = data[1]

                    fila = (coord >> 4) & 0x0F
                    col  = coord & 0x0F

                    if 0 <= fila < N and 0 <= col < N:
                        self.board[fila][col] = state
                        color = self._color_for_state(state)
                        self._paint_cell(fila, col, color)
            except Exception as e:
                self.status_var.set(f"ERROR lectura UART: {e}")

        # reprogramar el polling
        self.root.after(20, self._poll_uart_rx)

    # ---------------- GUI ----------------

    def _build_gui(self):
        width  = MARGIN + N * CELL_SIZE + 50
        height = MARGIN + N * CELL_SIZE + 60

        self.canvas = tk.Canvas(self.root, width=width, height=height, bg="white")
        self.canvas.pack()

        self.status_var = tk.StringVar()
        self.status_label = tk.Label(self.root, textvariable=self.status_var)
        self.status_label.pack(fill="x")

        self.status_var.set("Flechas: mover cursor | SPACE: pintar (PC->FPGA). "
                            "VGA->PC se actualiza por UART.")

        # Matriz de IDs de rectángulos
        self.rects = [[None for _ in range(N)] for _ in range(N)]
        self._draw_board()

        # Rectángulo del cursor (overlay)
        self.cursor_rect = self._create_cursor_rect(self.cur_row, self.cur_col)

        # Eventos de teclado
        self.canvas.focus_set()
        self.canvas.bind("<Up>", self._on_key)
        self.canvas.bind("<Down>", self._on_key)
        self.canvas.bind("<Left>", self._on_key)
        self.canvas.bind("<Right>", self._on_key)
        self.canvas.bind("<space>", self._on_space)

    def _draw_board(self):
        letras = "ABCDEFGHIJ"

        # Letras arriba
        for col in range(N):
            x = MARGIN + col * CELL_SIZE + CELL_SIZE / 2
            y = MARGIN - 20
            self.canvas.create_text(x, y, text=letras[col], font=("Arial", 12))

        # Números a la izquierda
        for fila in range(N):
            x = MARGIN - 20
            y = MARGIN + fila * CELL_SIZE + CELL_SIZE / 2
            self.canvas.create_text(x, y, text=str(fila + 1), font=("Arial", 12))

        # Marco
        x0 = MARGIN
        y0 = MARGIN
        x1 = MARGIN + N * CELL_SIZE
        y1 = MARGIN + N * CELL_SIZE
        self.canvas.create_rectangle(x0, y0, x1, y1, outline="black", width=2)

        # Celdas
        for fila in range(N):
            for col in range(N):
                xs = MARGIN + col * CELL_SIZE
                ys = MARGIN + fila * CELL_SIZE
                xe = xs + CELL_SIZE
                ye = ys + CELL_SIZE
                rect = self.canvas.create_rectangle(
                    xs, ys, xe, ye,
                    outline="black",
                    fill=BOARD_COLOR     # FONDO VGA BASE
                )
                self.rects[fila][col] = rect

    def _create_cursor_rect(self, fila, col):
        xs = MARGIN + col * CELL_SIZE
        ys = MARGIN + fila * CELL_SIZE
        xe = xs + CELL_SIZE
        ye = ys + CELL_SIZE
        return self.canvas.create_rectangle(
            xs, ys, xe, ye,
            outline="red", width=3
        )

    def _move_cursor_rect(self):
        xs = MARGIN + self.cur_col * CELL_SIZE
        ys = MARGIN + self.cur_row * CELL_SIZE
        xe = xs + CELL_SIZE
        ye = ys + CELL_SIZE
        self.canvas.coords(self.cursor_rect, xs, ys, xe, ye)

    # ---------------- Manejo de teclado ----------------

    def _on_key(self, event):
        key = event.keysym
        if key == "Up":
            if self.cur_row > 0:
                self.cur_row -= 1
        elif key == "Down":
            if self.cur_row < N - 1:
                self.cur_row += 1
        elif key == "Left":
            if self.cur_col > 0:
                self.cur_col -= 1
        elif key == "Right":
            if self.cur_col < N - 1:
                self.cur_col += 1

        self._move_cursor_rect()

    def _on_space(self, event):
        fila = self.cur_row
        col  = self.cur_col

        self.board[fila][col] = 1
        self._paint_cell(fila, col, "gray70")

        self._send_coord(fila, col)

    # ---------------- Utilidad pintar ----------------

    def _paint_cell(self, fila, col, color):
        rect_id = self.rects[fila][col]
        self.canvas.itemconfig(rect_id, fill=color)

    def _color_for_state(self, state):
        """
        Mapea estado (0..3) a colores:
        0: vacío      -> color base (#99DDFF)
        1: barco      -> azul
        2: fallo/agua -> celeste
        3: impacto    -> rojo
        """
        if state == 0:
            return BOARD_COLOR
        elif state == 1:
            return "steelblue"
        elif state == 2:
            return "blue"
        elif state == 3:
            return "red"
        else:
            return "gray70"


# ============================================
# main
# ============================================

if __name__ == "__main__":
    root = tk.Tk()
    app = BattleshipUARTBoard(
        root,
        use_uart=USE_UART,
        port=SERIAL_PORT,
        baudrate=BAUDRATE
    )
    root.mainloop()
