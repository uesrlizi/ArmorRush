# -*- coding: utf-8 -*-
"""第九章威胁件 1:1 自检帧（视口 2400x1080，玩家屏幕 x=400，BOSS 锚点屏幕 x=1800）。
帧1 threat_rod_row_ch9.png：引雷针列（针 px+1000/1300/1600，t0 地表 664）+ 杂兵天线并排 + BOSS 放电球位。
帧2 threat_span_states_ch9.png：跨缆四态（松弛灰/紧绷灰/爬电半程/带电），高缆与低缆各一行。
单位贴图全部 Godot(ThorVG) scale 1 光栅后按 §0 锚点贴入；缆为引擎 Line2D 语义，用 PIL 线段画。"""
import os
import subprocess

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
GODOT = "C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
UNITS = os.path.join(HERE, "units")
RENDER = os.path.join(UNITS, "render")
W, H = 2400, 1080
SKY, GROUND, BAND = (94, 106, 102), (69, 59, 74), (78, 68, 82)
CABLE_GRAY = (38, 32, 50)  # 未带电缆=敌营 BELLY 暗缆，与青灰天拉开明度
LIVE_CORE, LIVE_GLOW, DECOR = (240, 230, 255), (201, 166, 255), (110, 82, 160)


def raster1(name):
    out = os.path.join(RENDER, name.replace(".svg", "_x1.png"))
    rel = lambda p: "res://" + os.path.relpath(p, ROOT).replace("\\", "/")
    subprocess.run([GODOT, "--headless", "--path", ROOT, "--script", "res://art_proposals/raster_svg.gd",
                    "--", rel(os.path.join(UNITS, name)), rel(out), "1"], capture_output=True, text=True)
    return Image.open(out).convert("RGBA")


def paste(img, sprite, x, y, ax, ay):
    img.alpha_composite(sprite, (int(round(x - ax)), int(round(y - ay))))


def ground(img, g=664):
    d = ImageDraw.Draw(img)
    d.rectangle([0, g, W, H], fill=GROUND)
    d.rectangle([0, g, W, g + 6], fill=BAND)


def live_line(d, a, b):
    d.line([a, b], fill=LIVE_GLOW, width=9)
    d.line([a, b], fill=LIVE_CORE, width=3)


def frame_rods():
    img = Image.new("RGBA", (W, H), SKY + (255,))
    ground(img)
    d = ImageDraw.Draw(img)
    rod = raster1("fx_storm_rod.svg")
    walker = raster1("enemy_storm_walker_body.svg")
    drone = raster1("enemy_storm_drone.svg")
    boss = raster1("boss_storm_body.svg")
    arm = raster1("boss_storm_arm.svg")
    g = 664
    # 玩家判定盒 40x60（中心 g-30）
    d.rectangle([380, g - 60, 420, g], outline=(255, 238, 88), width=2)
    tips = []
    for sx in (1400, 1700, 2000):
        paste(img, rod, sx, g, 18, 138)
        tips.append((sx, g - 120))
    paste(img, walker, 2200, g, 28, 50)
    paste(img, drone, 2280, g - 90, 19, 21)
    paste(img, boss, 1800, 370, 150, 90)
    paste(img, arm, 1800, 370 - 64, 78, 22)
    muzzle = (1800 - 68, 370 - 64)
    d = ImageDraw.Draw(img)
    live_line(d, muzzle, tips[0])           # 主弧（示意：放电瞬间）
    live_line(d, tips[0], tips[1])          # 针1→针2 跳弧
    # 刻度：站立头顶线 g-60 / 弧带底 g-112
    for y, c in ((g - 60, (255, 238, 88)), (g - 112, LIVE_GLOW)):
        d.line([(1300, y), (2100, y)], fill=c, width=1)
    img.save(os.path.join(HERE, "threat_rod_row_ch9.png"))


def frame_spans():
    img = Image.new("RGBA", (W, H), SKY + (255,))
    d = ImageDraw.Draw(img)
    hi = raster1("fx_storm_stake_high.svg")
    lo = raster1("fx_storm_stake_low.svg")
    rows = ((480, hi, 14, 116, 110), (960, lo, 16, 46, 40))
    for g, stake, ax, ay, hgt in rows:
        d.rectangle([0, g, W, g + 100], fill=GROUND)
        d.rectangle([0, g, W, g + 6], fill=BAND)
        for i in range(4):
            x1 = 120 + i * 580
            x2 = x1 + 320
            paste(img, stake, x1, g, ax, ay)
            paste(img, stake, x2, g, ax, ay)
            d = ImageDraw.Draw(img)
            a, b = (x1, g - hgt), (x2, g - hgt)
            if i == 0:   # 松弛灰缆
                pts = [(x1 + t * 32, g - hgt + min(48, hgt * 0.6) * (1 - ((t - 5) / 5) ** 2)) for t in range(11)]
                d.line(pts, fill=CABLE_GRAY, width=3)
            elif i == 1:  # 紧绷灰缆
                d.line([a, b], fill=CABLE_GRAY, width=3)
            elif i == 2:  # 爬电半程
                d.line([a, b], fill=CABLE_GRAY, width=3)
                mx = (x1 + x2) / 2
                live_line(d, a, (mx, g - hgt))
                d.ellipse([mx - 9, g - hgt - 9, mx + 9, g - hgt + 9], fill=LIVE_CORE)
            else:          # 带电
                live_line(d, a, b)
            # 玩家判定盒（站立）
            d.rectangle([x1 + 140, g - 60, x1 + 180, g], outline=(255, 238, 88), width=2)
    img.save(os.path.join(HERE, "threat_span_states_ch9.png"))


if __name__ == "__main__":
    os.makedirs(RENDER, exist_ok=True)
    frame_rods()
    frame_spans()
    print("ok")
