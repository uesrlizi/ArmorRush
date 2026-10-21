# -*- coding: utf-8 -*-
"""把 4 套已实装提案 + 3 套新提案拼成一张总览预览图 proposals_all_preview.png。"""
import os

from PIL import Image, ImageDraw, ImageFont

import generate_proposals as gp
from generate_proposals2 import NEW_PROPOSALS

HERE = os.path.dirname(os.path.abspath(__file__))
BG = (16, 18, 22)
FG = (232, 236, 242)
GREY = (154, 162, 173)
M, G = 30, 26
IMG_W, IMG_H = 980, 441
TITLE_H, DESC_H, CHIP_H = 38, 24, 34
CELL_H = TITLE_H + DESC_H + IMG_H + CHIP_H
HEADER_H = 84
COLS, ROWS = 2, 4
W = M * 2 + IMG_W * COLS + G * (COLS - 1)
H = HEADER_H + CELL_H * ROWS + M

FONT = "C:/Windows/Fonts/msyh.ttc"


def F(size):
    return ImageFont.truetype(FONT, size)


ALL = list(gp.PROPOSALS) + list(NEW_PROPOSALS)

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)
f_head, f_note, f_title, f_desc, f_chip = F(30), F(15), F(24), F(15), F(13)

d.text((M, 24), "Armor Rush 场景美术提案 · 4 实装 + 3 新案", font=f_head, fill=FG)
d.text((M, 62), "画布 1200×540 = 视口 2400×1080 的一半（20:9）；地面线 y=330。手写矢量 / Godot 同源光栅。",
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

# 第 8 格：新案定位速览卡
x0 = M + 1 * (IMG_W + G)
y0 = HEADER_H + 3 * CELL_H
d.text((x0, y0 + 2), "新案定位速览", font=f_title, fill=FG)
lines = [
    ("#f4b071", "五 破晓云廊", "高空航线/云海：暖高调衬暗色机体；黄弹靠亮天承托（亮背景章规矩）"),
    ("#ffb347", "六 赤沙矿区", "荒漠矿区：白热天+赤红沙，黄弹可读性好；沙暴带浓度是唯一风险"),
    ("#5fc0b0", "七 溺海都会", "溺海沿岸：青绿海光，深色机体/红眼对比最强；反光带避开走弹区"),
]
ly = y0 + TITLE_H + 16
for c, name, note in lines:
    d.rounded_rectangle((x0, ly + 3, x0 + 14, ly + 17), 3, fill=c)
    d.text((x0 + 24, ly), name, font=F(17), fill=FG)
    d.text((x0 + 146, ly), note, font=f_note, fill=GREY)
    ly += 36
d.text((x0, ly + 6), "生成器 art_proposals/generate_proposals2.py（复用首批框架，种子固定可重跑）\n逐案细览含分层/视差账：gallery.html",
       font=f_note, fill=GREY)

out = os.path.join(HERE, "proposals_all_preview.png")
img.save(out)
print("OK", out, img.size)
