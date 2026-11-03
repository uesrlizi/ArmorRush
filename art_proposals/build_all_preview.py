# -*- coding: utf-8 -*-
"""把 7 套已实装提案 + 3 套新提案拼成一张总览预览图 proposals_all_preview.png。"""
import os

from PIL import Image, ImageDraw, ImageFont

import generate_proposals as gp
from generate_proposals2 import NEW_PROPOSALS
from generate_proposals3 import NEW_PROPOSALS as NEW_PROPOSALS3

HERE = os.path.dirname(os.path.abspath(__file__))
BG = (16, 18, 22)
FG = (232, 236, 242)
GREY = (154, 162, 173)
M, G = 30, 26
IMG_W, IMG_H = 980, 441
TITLE_H, DESC_H, CHIP_H = 38, 24, 34
CELL_H = TITLE_H + DESC_H + IMG_H + CHIP_H
HEADER_H = 84
COLS, ROWS = 2, 5
W = M * 2 + IMG_W * COLS + G * (COLS - 1)
H = HEADER_H + CELL_H * ROWS + M

FONT = "C:/Windows/Fonts/msyh.ttc"


def F(size):
    return ImageFont.truetype(FONT, size)


ALL = list(gp.PROPOSALS) + list(NEW_PROPOSALS) + list(NEW_PROPOSALS3)

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)
f_head, f_note, f_title, f_desc, f_chip = F(30), F(15), F(24), F(15), F(13)

d.text((M, 24), "Armor Rush 场景美术提案 · 7 实装 + 3 新案", font=f_head, fill=FG)
d.text((M, 62), "画布 1200×540 = 视口 2400×1080 的一半（20:9）；地面线 y=330。手写矢量 / Godot 同源光栅。逐案细览：gallery.html",
       font=f_note, fill=GREY)

for i, (fname, _fn, title, desc, palette, layer_note) in enumerate(ALL):
    col, row = i % COLS, i // COLS
    x0 = M + col * (IMG_W + G)
    y0 = HEADER_H + row * CELL_H
    d.text((x0, y0 + 2), title, font=f_title, fill=FG)
    d.text((x0, y0 + TITLE_H + 2), desc, font=f_desc, fill=GREY)
    png = os.path.join(HERE, fname.replace(".svg", ".png"))
    im = Image.open(png).resize((IMG_W, IMG_H), Image.LANCZOS)
    img.paste(im, (x0, y0 + TITLE_H + DESC_H))
    cy = y0 + TITLE_H + DESC_H + IMG_H + 10
    cx = x0
    for c in palette:
        d.rounded_rectangle((cx, cy, cx + 16, cy + 16), 3, fill=c, outline=(70, 76, 86))
        d.text((cx + 22, cy + 1), c, font=f_chip, fill=GREY)
        cx += 22 + 13 * len(c) + 14

out = os.path.join(HERE, "proposals_all_preview.png")
img.save(out)
print("OK", out, img.size)
