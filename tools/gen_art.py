#!/usr/bin/env python3
# Генератор пиксель-арта (16-бит стиль) для скина "Zen": камни, рука, фон.
# Рисуем на маленькой сетке, потом увеличиваем NEAREST — получаются чёткие пиксели.
import math
from PIL import Image, ImageDraw

OUT = "/Users/marcopolo/Downloads/balance-tower/assets/zen/"


def save_scaled(img, scale, name):
    w, h = img.size
    img.resize((w * scale, h * scale), Image.NEAREST).save(OUT + name)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def make_stone(name, light, mid, dark, edge, hi):
    W, H = 60, 20
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    cx, cy = W / 2.0, H / 2.0 + 0.5
    rx, ry = 28.0, 8.6
    for y in range(H):
        for x in range(W):
            dx = (x + 0.5 - cx) / rx
            dy = (y + 0.5 - cy) / ry
            d = dx * dx + dy * dy
            if d <= 1.0:
                vy = (y + 0.5 - (cy - ry)) / (2 * ry)
                if d > 0.82:
                    c = edge
                elif vy < 0.28:
                    c = light
                elif vy < 0.60:
                    c = mid
                else:
                    c = dark
                px[x, y] = c + (255,)
    for hx, hy in [(int(cx - 10), int(cy - 4)), (int(cx - 8), int(cy - 4)),
                   (int(cx - 9), int(cy - 3)), (int(cx - 11), int(cy - 3))]:
        if 0 <= hx < W and 0 <= hy < H and px[hx, hy][3] > 0:
            px[hx, hy] = hi + (255,)
    save_scaled(im, 6, name)


def make_hand(name):
    W, H = 34, 30
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    skin = (233, 197, 158, 255)
    mid = (210, 164, 122, 255)
    dark = (170, 126, 90, 255)
    out = (104, 74, 52, 255)
    fx = [5, 10, 15, 20]  # короткие толстые пальцы, почти вплотную
    # --- силуэт (обводка) ---
    d.ellipse([3, 0, 27, 16], fill=out)            # крупная тыльная сторона ладони
    d.ellipse([23, 8, 33, 21], fill=out)           # большой палец сбоку
    for x in fx:
        d.rounded_rectangle([x, 13, x + 5, 24], radius=2, fill=out)
    # --- кожа (инсет на 1px) ---
    d.ellipse([4, 1, 26, 15], fill=skin)
    d.ellipse([24, 9, 32, 20], fill=skin)
    for x in fx:
        d.rounded_rectangle([x + 1, 13, x + 4, 23], radius=1, fill=skin)
    # --- тень: основание пальцев темнее + кончики ---
    d.rectangle([5, 12, 25, 16], fill=mid)
    for x in fx:
        d.line([x + 1, 22, x + 4, 22], fill=mid)
        d.line([x + 1, 23, x + 4, 23], fill=dark)
    save_scaled(im, 7, name)


def make_background(name):
    W, H = 120, 213
    im = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    px = im.load()
    d = ImageDraw.Draw(im)
    hy = int(H * 0.60)
    sky = [(44, 40, 86), (92, 60, 110), (176, 96, 110), (228, 142, 92), (245, 198, 120)]
    # sky bands
    for y in range(hy):
        t = y / float(hy)
        seg = t * (len(sky) - 1)
        i = min(int(seg), len(sky) - 2)
        c = lerp(sky[i], sky[i + 1], seg - i)
        c = tuple((v // 16) * 16 for v in c)  # лёгкая постеризация под 16-бит
        for x in range(W):
            px[x, y] = c + (255,)
    # sun
    sx, syc, sr = int(W * 0.5), int(hy - H * 0.05), int(H * 0.075)
    d.ellipse([sx - sr, syc - sr, sx + sr, syc + sr], fill=(250, 226, 170, 255))
    d.ellipse([sx - sr + 2, syc - sr + 2, sx + sr - 2, syc + sr - 2], fill=(252, 240, 205, 255))
    # mountains (two layers)
    def mountains(base, amp, color):
        pts = [(0, H)]
        for x in range(0, W + 1, 1):
            yv = base + int(amp * (math.sin(x * 0.10) * 0.6 + math.sin(x * 0.23 + 1) * 0.4))
            pts.append((x, yv))
        pts.append((W, H))
        d.polygon(pts, fill=color)
    mountains(hy - 14, 8, (84, 66, 112, 255))
    mountains(hy - 4, 6, (60, 48, 92, 255))
    # pagoda silhouette on the right
    pg = (38, 32, 58, 255)
    bx, by = int(W * 0.78), hy - 6
    for k, wdt in enumerate([10, 8, 6]):
        yy = by - k * 7
        d.polygon([(bx - wdt, yy), (bx + wdt, yy), (bx + wdt - 2, yy - 3),
                   (bx - wdt + 2, yy - 3)], fill=pg)
        d.rectangle([bx - wdt + 2, yy, bx + wdt - 2, yy + 4], fill=pg)
    d.rectangle([bx - 2, by - 22, bx + 2, by], fill=pg)
    # water
    for y in range(hy, H):
        t = (y - hy) / float(H - hy)
        c = lerp((96, 78, 120), (54, 44, 86), t)
        for x in range(W):
            px[x, y] = c + (255,)
    # sun reflection shimmer
    for y in range(hy, H, 2):
        ww = 3 + (y - hy) // 6
        for x in range(sx - ww, sx + ww):
            if 0 <= x < W:
                px[x, y] = (236, 168, 110, 255)
    save_scaled(im, 5, name)


make_stone("stone.png", (180, 170, 156), (138, 128, 114), (92, 84, 72), (64, 58, 48), (214, 206, 192))
make_stone("stone2.png", (192, 176, 150), (150, 132, 106), (104, 90, 70), (72, 62, 48), (224, 210, 188))
make_stone("stone3.png", (160, 162, 170), (120, 124, 136), (82, 86, 98), (56, 60, 70), (200, 204, 214))
make_hand("hand.png")
make_background("background.png")
print("done")
