import pygame
import sys

try:
    import serial
    HAS_SERIAL = True
except ImportError:
    HAS_SERIAL = False

# ============================================
# CONFIGURACIÓN
# ============================================

N = 10          # 10x10
CELL_SIZE = 35
MARGIN = 50
USE_UART = True
SERIAL_PORT = "COM6"
BAUDRATE = 115200

# Nombre del archivo de imagen de splash
SPLASH_IMAGE_FILE = "battleship_splash.png"

# Colores
WHITE       = (255, 255, 255)
BLACK       = (0, 0, 0)
RED         = (255, 0, 0)
GRAY        = (180, 180, 180)
STEELBLUE   = (128, 128, 128)  # barcos propios
DARKBLUE    = (0, 0, 200)      # agua / fallo
CELSTE_VGA  = (150, 215, 255)  # fondo tablero
GREEN       = (0, 150, 0)

# Código especial para avisar HIT del Jugador 2 a la FPGA
P2_HIT_CODE = 0xFE

# ============================================
# CLASE TABLERO
# ============================================

class BattleshipGame:
    def __init__(self):
        pygame.init()
        self.width  = MARGIN + N * CELL_SIZE + 50
        self.height = MARGIN + N * CELL_SIZE + 60
        self.screen = pygame.display.set_mode((self.width, self.height))
        pygame.display.set_caption("Battleship – PC <-> FPGA")
        self.clock = pygame.time.Clock()
        self.font = pygame.font.SysFont("Arial", 16)

        # Fuente un poco más grande para el splash
        self.font_big = pygame.font.SysFont("Arial", 24)

        # UART
        self.ser = None
        if USE_UART and HAS_SERIAL:
            try:
                self.ser = serial.Serial(SERIAL_PORT, BAUDRATE, timeout=0.01)
                print(f"[INFO] UART abierto en {SERIAL_PORT} a {BAUDRATE} bps")
            except Exception as e:
                print(f"[ERROR] No se pudo abrir {SERIAL_PORT}: {e}")
                self.ser = None
        elif USE_UART and not HAS_SERIAL:
            print("[WARN] pyserial no instalado.")
            self.ser = None

        # Cargar imagen de splash (si existe)
        self.splash_image = None
        self.load_splash_assets()

        # Mostrar pantalla de bienvenida ANTES de iniciar el juego
        self.show_splash()

        # Inicializa todo el estado del juego
        self.reset_game(init_uart=False)

    # ---------------- SPLASH ----------------
    def load_splash_assets(self):
        """Intenta cargar la imagen de splash y aplicarle un zoom centrado."""
        try:
            img = pygame.image.load(SPLASH_IMAGE_FILE).convert_alpha()

            # Factor de zoom (1.0 = original, >1 = más grande)
            ZOOM = 0.60

            w, h = img.get_size()
            new_w = int(w * ZOOM)
            new_h = int(h * ZOOM)

            img_zoom = pygame.transform.smoothscale(img, (new_w, new_h))

            # Superficie final del tamaño de la ventana
            self.splash_image = pygame.Surface(
                (self.width, self.height), pygame.SRCALPHA
            )
            self.splash_image.fill(CELSTE_VGA)

            rect = img_zoom.get_rect(center=(self.width // 2,
                                             self.height // 2))
            self.splash_image.blit(img_zoom, rect)

            print("[INFO] Imagen de splash cargada con zoom.")
        except Exception as e:
            print(f"[WARN] No se pudo cargar la imagen de splash: {e}")
            self.splash_image = None

    def show_splash(self):
        in_splash = True
        while in_splash:
            self.clock.tick(60)

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_RETURN:
                        in_splash = False

            if self.splash_image is not None:
                self.screen.blit(self.splash_image, (0, 0))
            else:
                self.screen.fill(CELSTE_VGA)
                text = self.font_big.render(
                    "KARINA Y RANDY BATTLESHIP", True, BLACK
                )
                text_rect = text.get_rect(center=(self.width // 2,
                                                  self.height // 2))
                self.screen.blit(text, text_rect)

            msg = "Presiona ENTER para comenzar"
            text2 = self.font.render(msg, True, BLACK)
            text2_rect = text2.get_rect(
                midbottom=(self.width // 2, self.height - 20)
            )
            self.screen.blit(text2, text2_rect)

            pygame.display.flip()

    # ---------------- RESET JUEGO ----------------
    def reset_game(self, init_uart=True):
        """
        Soft reset del juego en PC.
        """
        self.board = [[0 for _ in range(N)] for _ in range(N)]
        self.enemy_board = [[0 for _ in range(N)] for _ in range(N)]

        self.cur_row = 0
        self.cur_col = 0

        # Colocación de barcos
        self.ship_sizes = [5, 4, 3, 2, 1]
        self.current_ship_idx = 0
        self.placing_horizontal = True
        self.placing_ship = False
        self.temp_ship_coords = []

        self.phase = "placement"  # "placement" o "battle"

        # Turno visto desde el PC
        self.current_turn = "vga"   # empieza VGA

        # Marcador Jugador 2 (PC)
        self.score_pc = 0

        # <<< NUEVO: bandera de fin de juego >>>
        self.game_over = False

        if init_uart and self.ser is not None:
            try:
                self.ser.reset_input_buffer()
            except Exception as e:
                print(f"[UART RESET ERROR] {e}")

        print("[INFO] RESET juego en PC")

    # ---------------- UART ----------------
    def send_to_fpga(self, coord):
        """Envía UN byte al SoC (coord o código especial)."""
        if self.ser is None:
            return
        try:
            self.ser.write(bytes([coord & 0xFF]))
        except Exception as e:
            print(f"[UART ERROR] {e}")

    def poll_uart_rx(self):
        """
        Recibe desde la FPGA:

        1) Paquetes de cambio de turno:
           coord = 0xFF, state = 0x00/0x01
        2) Paquetes coord/state normales:
           state == 1 -> barco enemigo (VGA)
        3) (Opcional futuro) Paquete especial de victoria:
           coord = 0xFE, state = 0x01 -> gana Jugador 1 (VGA)
        """
        if self.ser is None:
            return
        try:
            while self.ser.in_waiting >= 2:
                data = self.ser.read(2)
                if len(data) < 2:
                    break
                coord = data[0]
                state = data[1]

                # <<< NUEVO: mensaje especial de victoria desde la FPGA >>>
                if coord == 0xFE:
                    if state == 1:
                        print("[UART] ¡Jugador 1 (VGA) ha ganado con 15 impactos!")
                    elif state == 2:
                        print("[UART] ¡Jugador 2 (PC) ha ganado (mensaje desde FPGA)!")
                    else:
                        print(f"[UART] Paquete de victoria desconocido: state={state}")
                    self.game_over = True
                    self.current_turn = None
                    continue

                # Paquete de cambio de turno
                if coord == 0xFF:
                    if state == 0:
                        self.current_turn = "vga"
                        print("[UART] Turno cambiado a VGA (Jugador1)")
                    elif state == 1:
                        self.current_turn = "pc"
                        print("[UART] Turno cambiado a PC (Jugador2)")
                    else:
                        print(f"[UART] Paquete de turno desconocido: state={state}")
                    continue

                # Coordenadas normales
                fila = (coord >> 4) & 0x0F
                col  = coord & 0x0F
                if not (0 <= fila < N and 0 <= col < N):
                    continue

                if state == 1:
                    # Barco enemigo (VGA) durante colocación
                    self.enemy_board[fila][col] = 1
                elif state in (2, 3) and self.phase == "battle":
                    # reservado (si algún día la FPGA reporta hit/miss)
                    pass

        except Exception as e:
            print(f"[UART RX ERROR] {e}")

    # ---------------- UTILIDADES ----------------
    def color_for_state(self, row, col, own=True):
        if own:
            state = self.board[row][col]
        else:
            state = self.enemy_board[row][col]

        if own:
            if state == 0:
                return CELSTE_VGA
            elif state == 1:
                return STEELBLUE
            elif state == 2:
                return DARKBLUE
            elif state == 3:
                return RED
            else:
                return GRAY
        else:
            if state == 2:
                return DARKBLUE   # MISS
            elif state == 3:
                return RED        # HIT
            else:
                return CELSTE_VGA

    def can_place_ship(self, row, col, size, horizontal):
        coords = []
        for i in range(size):
            r = row
            c = col
            if horizontal:
                c += i
            else:
                r += i
            if r >= N or c >= N:
                return None
            if self.board[r][c] != 0:
                return None
            coords.append((r, c))
        return coords

    # ---------------- DIBUJO ----------------
    def draw_board(self):
        self.screen.fill(WHITE)

        # Letras arriba
        letras = "ABCDEFGHIJ"
        for col in range(N):
            x = MARGIN + col * CELL_SIZE + CELL_SIZE // 2
            y = MARGIN - 20
            text_surf = self.font.render(letras[col], True, BLACK)
            text_rect = text_surf.get_rect(center=(x, y))
            self.screen.blit(text_surf, text_rect)

        # Números izquierda
        for fila in range(N):
            x = MARGIN - 20
            y = MARGIN + fila * CELL_SIZE + CELL_SIZE // 2
            text_surf = self.font.render(str(fila + 1), True, BLACK)
            text_rect = text_surf.get_rect(center=(x, y))
            self.screen.blit(text_surf, text_rect)

        # Marco del tablero
        x0 = MARGIN
        y0 = MARGIN
        x1 = MARGIN + N * CELL_SIZE
        y1 = MARGIN + N * CELL_SIZE
        pygame.draw.rect(self.screen, BLACK, (x0, y0, x1 - x0, y1 - y0), 2)

        # Celdas propias
        for fila in range(N):
            for col in range(N):
                x = MARGIN + col * CELL_SIZE
                y = MARGIN + fila * CELL_SIZE
                rect = pygame.Rect(x, y, CELL_SIZE, CELL_SIZE)
                pygame.draw.rect(
                    self.screen,
                    self.color_for_state(fila, col, True),
                    rect
                )
                pygame.draw.rect(self.screen, BLACK, rect, 1)

        # Barco temporal
        if self.phase == "placement" and self.placing_ship and self.temp_ship_coords:
            for r, c in self.temp_ship_coords:
                x = MARGIN + c * CELL_SIZE
                y = MARGIN + r * CELL_SIZE
                rect = pygame.Rect(x, y, CELL_SIZE, CELL_SIZE)
                pygame.draw.rect(self.screen, STEELBLUE, rect.inflate(-4, -4))

        # Cursor
        x = MARGIN + self.cur_col * CELL_SIZE
        y = MARGIN + self.cur_row * CELL_SIZE
        cursor_rect = pygame.Rect(x, y, CELL_SIZE, CELL_SIZE)
        pygame.draw.rect(self.screen, RED, cursor_rect, 3)

        # Overlay enemigo: solo HIT/MISS
        for fila in range(N):
            for col in range(N):
                state = self.enemy_board[fila][col]
                if state in (2, 3):
                    x = MARGIN + col * CELL_SIZE
                    y = MARGIN + fila * CELL_SIZE
                    rect = pygame.Rect(x, y, CELL_SIZE, CELL_SIZE)
                    pygame.draw.rect(
                        self.screen,
                        self.color_for_state(fila, col, False),
                        rect.inflate(-10, -10)
                    )

        # Marcador simple del Jugador 2 en la ventana
        score_text = self.font.render(f"P2 Hits: {self.score_pc}", True, BLACK)
        self.screen.blit(score_text, (MARGIN, self.height - 30))

        # Mensaje de fin de juego (opcional)
        if self.game_over:
            msg = "JUEGO TERMINADO"
            text_surf = self.font.render(msg, True, RED)
            text_rect = text_surf.get_rect(
                center=(self.width // 2, self.height - 30)
            )
            self.screen.blit(text_surf, text_rect)

        pygame.display.flip()

    # ---------------- LOOP PRINCIPAL ----------------
    def run(self):
        running = True
        while running:
            self.clock.tick(60)
            self.poll_uart_rx()

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    running = False

                elif event.type == pygame.KEYDOWN:

                    # RESET (C)
                    if event.key == pygame.K_c:
                        self.reset_game()
                        continue

                    # Cursor
                    if event.key == pygame.K_UP:
                        self.cur_row = max(0, self.cur_row - 1)
                    elif event.key == pygame.K_DOWN:
                        self.cur_row = min(N - 1, self.cur_row + 1)
                    elif event.key == pygame.K_LEFT:
                        self.cur_col = max(0, self.cur_col - 1)
                    elif event.key == pygame.K_RIGHT:
                        self.cur_col = min(N - 1, self.cur_col + 1)

                    # ------------- FASE COLOCACIÓN -------------
                    if self.phase == "placement":
                        if event.key == pygame.K_r:
                            self.placing_horizontal = not self.placing_horizontal

                        elif event.key == pygame.K_e:
                            self.placing_ship = False
                            self.temp_ship_coords.clear()

                        elif event.key == pygame.K_SPACE:
                            if self.current_ship_idx < len(self.ship_sizes):
                                size = self.ship_sizes[self.current_ship_idx]
                                coords = self.can_place_ship(
                                    self.cur_row,
                                    self.cur_col,
                                    size,
                                    self.placing_horizontal
                                )
                                if coords:
                                    self.temp_ship_coords = coords
                                    self.placing_ship = True

                        elif event.key == pygame.K_RETURN:
                            if self.placing_ship:
                                for r, c in self.temp_ship_coords:
                                    self.board[r][c] = 1
                                self.placing_ship = False
                                self.temp_ship_coords.clear()
                                self.current_ship_idx += 1

                        elif event.key == pygame.K_q:
                            for fila in range(N):
                                for col in range(N):
                                    if self.board[fila][col] == 1:
                                        coord = ((fila & 0x0F) << 4) | (col & 0x0F)
                                        self.send_to_fpga(coord)
                            self.placing_ship = False
                            self.temp_ship_coords.clear()
                            self.phase = "battle"
                            self.current_turn = "vga"
                            print("[INFO] Barcos enviados a FPGA, transición a batalla; turno = VGA")

                    # ------------- FASE BATALLA -------------
                    elif self.phase == "battle":
                        if event.key == pygame.K_w:
                            # <<< NUEVO: si el juego terminó, bloquear disparo >>>
                            if self.game_over:
                                print("[PC] El juego ya terminó, disparo ignorado")
                                continue

                            if self.current_turn != "pc":
                                print("[PC] No es tu turno, disparo ignorado")
                                continue

                            r = self.cur_row
                            c = self.cur_col
                            enemy_state = self.enemy_board[r][c]
                            own_state   = self.board[r][c]

                            hit = False

                            if enemy_state == 1:
                                # HIT sobre barco VGA
                                if self.enemy_board[r][c] != 3:
                                    self.enemy_board[r][c] = 3
                                    # contador local (0..15)
                                    if self.score_pc < 15:
                                        self.score_pc += 1
                                    hit = True
                                print(f"[PC] HIT sobre barco VGA en ({r},{c}), score_pc={self.score_pc}")

                                # <<< NUEVO: victoria Jugador 2 cuando llega a 15 hits >>>
                                if self.score_pc >= 15 and not self.game_over:
                                    self.game_over = True
                                    print("[PC] ¡Jugador 2 (PC) ha ganado con 15 impactos!")

                            elif own_state == 1:
                                print(f"[PC] Disparo sobre barco propio en ({r},{c}), SIN marcar en tablero")

                            else:
                                if enemy_state != 3:
                                    self.enemy_board[r][c] = 2
                                print(f"[PC] MISS sobre VGA en ({r},{c})")

                            # Primero: si fue HIT nuevo, avisamos a la FPGA con 0xFE
                            if hit:
                                print("[PC] Enviando código HIT (0xFE) a la FPGA")
                                self.send_to_fpga(P2_HIT_CODE)

                            # Después: enviamos la coordenada real del disparo,
                            # solo si el juego no terminó en este disparo.
                            if not self.game_over:
                                coord = ((r & 0x0F) << 4) | (c & 0x0F)
                                print(f"[PC] Disparo enviado a FPGA coord=0x{coord:02X}")
                                self.send_to_fpga(coord)
                            else:
                                print("[PC] No se envía disparo a FPGA porque el juego ya terminó")
                            # El cambio de turno lo hace la FPGA (advance_turn)

            self.draw_board()

        if self.ser is not None:
            self.ser.close()
        pygame.quit()
        sys.exit()


# ============================================
# MAIN
# ============================================

if __name__ == "__main__":
    app = BattleshipGame()
    app.run()
