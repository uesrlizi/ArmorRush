# -*- coding: utf-8 -*-
"""第二章换皮交付 showcase：锈雨废都（章1）vs 精炼所工业带（章2）同框对照。
单位 2x、环境 0.35x 光栅拼图，深底、标注、现役 vs 新皮。"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
GODOT = "C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
RENDER = os.path.join(HERE, "render")
PIL_OK = True
from PIL import Image, ImageDraw, ImageFont  # noqa: E402


def raster(rel_svg: str, out_name: str, scale: float) -> Image.Image:
    out = os.path.join(RENDER, out_name)
    if not os.path.exists(out):
        subprocess.run([GODOT, "--headless", "--path", ROOT, "--script",
                        "res://art_proposals/raster_svg.gd", "--",
                        "res://" + rel_svg, "res://art_proposals/refinery_ch2/render/" + out_name,
                        str(scale)], check=True, capture_output=True)
    return Image.open(out).convert("RGBA")


def label(draw, xy, text, size=22, color=(232, 236, 230)):
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", size)
    except OSError:
        font = ImageFont.load_default()
    draw.text(xy, text, font=font, fill=color)


def fit(img, w=None, h=None):
    r = 1.0
    if w is not None:
        r = w / img.width
    if h is not None:
        r = min(r, h / img.height)
    return img.resize((max(1, int(img.width * r)), max(1, int(img.height * r))), Image.NEAREST)


# 想看的单位对（章1 资产名, 章2 资产名, 展示名）
UNITS = [
    ("enemy_walker_body", "enemy_ref_walker_body", "步行者"),
    ("enemy_drone", "enemy_ref_drone", "无人机"),
    ("enemy_shield_body", "enemy_ref_shield_body", "盾卫"),
    ("elite_mortar_body", "enemy_ref_elite_body", "精英·导弹车"),
]
BOSSES = [("boss_dreadnought_body", "boss_ref_body", "BOSS")]

pad = 28
cell_w, cell_h = 300, 280
cols = len(UNITS)
W = pad * 2 + cols * cell_w
H = pad * 2 + 60 + cell_h + 360 + 320
sheet = Image.new("RGBA", (W, H), (24, 28, 26, 255))
draw = ImageDraw.Draw(sheet)

label(draw, (pad, 16), "第二章「精炼所工业带」换皮对照 —— 每格上：现役（锈雨废都） / 下：新皮（本章）", 26)

# ---- 单位对照 ----
y0 = 60
for c, (old, new, name) in enumerate(UNITS):
    x = pad + c * cell_w
    old_img = fit(raster(f"assets/{old}.svg", f"show_{old}.png", 2.0), cell_w - 60, 100)
    new_img = fit(raster(f"assets/{new}.svg", f"show_{new}.png", 2.0), cell_w - 60, 100)
    draw.rectangle([x, y0, x + cell_w - 12, y0 + cell_h - 16], fill=(33, 38, 35, 255))
    sheet.alpha_composite(old_img, (x + (cell_w - 12 - old_img.width) // 2, y0 + 8))
    sheet.alpha_composite(new_img, (x + (cell_w - 12 - new_img.width) // 2, y0 + 118))
    label(draw, (x + 8, y0 + cell_h - 40), name, 22)

# ---- BOSS 对照 ----
y1 = y0 + cell_h + 24
bx = pad
draw.rectangle([bx, y1, bx + 560, y1 + 320], fill=(33, 38, 35, 255))
old_boss = fit(raster("assets/boss_dreadnought_body.svg", "show_boss_old.png", 1.6), 520, 130)
new_boss = fit(raster("assets/boss_ref_body.svg", "show_boss_new.png", 1.6), 520, 130)
sheet.alpha_composite(old_boss, (bx + (560 - old_boss.width) // 2, y1 + 12))
sheet.alpha_composite(new_boss, (bx + (560 - new_boss.width) // 2, y1 + 168))
label(draw, (bx + 8, y1 + 288), "BOSS：重型武直（上）→「钢嵴」浮空炮舰（下）", 22)

# ---- 环境条带（章2）----
label(draw, (bx + 600, y1 - 2), "环境（章2 新皮）", 24)
env_far = fit(raster("assets/env_ref_far.svg", "show_far.png", 0.28), 520, 180)
env_mid = fit(raster("assets/env_ref_mid.svg", "show_mid.png", 0.28), 520, 90)
ground = fit(raster("assets/env_ref_ground_top.svg", "show_ground.png", 1.2), 520, 40)
deck = fit(raster("assets/env_ref_deck.svg", "show_deck.png", 0.7), 520, 30)
sheet.alpha_composite(env_far, (bx + 600, y1 + 26))
sheet.alpha_composite(env_mid, (bx + 600, y1 + 26 + env_far.height + 10))
sheet.alpha_composite(ground, (bx + 600, y1 + 26 + env_far.height + 10 + env_mid.height + 12))
sheet.alpha_composite(deck, (bx + 600, y1 + 26 + env_far.height + 10 + env_mid.height + 12 + ground.height + 10))
label(draw, (bx + 600, y1 + 26 + env_far.height + 10 + env_mid.height + 12 + ground.height + 10 + deck.height + 4),
      "远景 1024x1300 / 中景 2048x520 / 地表带 256x56 / 栈桥 720x26", 17, (150, 158, 152))

out = os.path.join(HERE, "refinery_ch2_showcase.png")
sheet.convert("RGB").save(out)
print("showcase ->", out)
