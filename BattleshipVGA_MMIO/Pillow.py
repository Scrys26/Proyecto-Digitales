from PIL import Image, ImageOps
import numpy as np

IN  = "battleship_splash.png"
OUT = "BattleShip23.mem"
W, H = 640, 232     # o el tamaño que estés usando ahora

# Azul "cielo" similar al de la imagen original
BG_COLOR = (116, 199, 227)   # (R, G, B) en 8 bits

im = Image.open(IN).convert("RGB")
im_fit = ImageOps.contain(im, (W, H))          # respeta aspect ratio

# FONDO AZUL en vez de negro
canvas = Image.new("RGB", (W, H), BG_COLOR)
x0 = (W - im_fit.width)//2
y0 = (H - im_fit.height)//2
canvas.paste(im_fit, (x0, y0))

arr = np.array(canvas, dtype=np.uint8)
r4 = (arr[:, :, 0] >> 4).astype(np.uint16)
g4 = (arr[:, :, 1] >> 4).astype(np.uint16)
b4 = (arr[:, :, 2] >> 4).astype(np.uint16)
rgb12 = (r4 << 8) | (g4 << 4) | b4  # 0xRGB

with open(OUT, "w") as f:
    for y in range(H):
        for x in range(W):
            f.write(f"{rgb12[y, x]:03X}\n")

print("MEM listo:", OUT, "| tamaño:", W, "x", H, "px")
