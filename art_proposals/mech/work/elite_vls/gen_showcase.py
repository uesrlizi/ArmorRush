# -*- coding: utf-8 -*-
"""精英·导弹车（车体+肩部垂发舱一体） 光栅自验（PIL 代用管线，编辑器开着不跑 Godot）。

只支持本项目用到的平涂子集：rect / polygon / line（fill+opacity，无曲线）。
产出：
  elite_vls_showcase.png  单体 ×5 / 镜像 ×3 / 族内同框（杂兵-精英-玩家）+ 标注
像素断言：色板对账 + 关键结构取样（两仓口/舱壁/舱体/裙座/红条/头/眼/腿/足板/斜削）。
"""
import os
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
ASSETS = os.path.join(ROOT, "assets")
OUT = os.path.dirname(os.path.abspath(__file__))

SS = 8  # 超采样倍率（平涂形状，格中心取样即精确色）


def parse_color(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5))


def draw_svg(svg_path, scale=1.0):
    tree = ET.parse(svg_path)
    root = tree.getroot()
    vb = [float(v) for v in root.get("viewBox").split()]
    W, H = int(vb[2] * scale), int(vb[3] * scale)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for el in root:
        tag = el.tag.split("}")[-1]
        if tag == "line":
            x1, y1 = float(el.get("x1")) * scale, float(el.get("y1")) * scale
            x2, y2 = float(el.get("x2")) * scale, float(el.get("y2")) * scale
            color = parse_color(el.get("stroke"))
            d = ImageDraw.Draw(img)
            d.line([(x1, y1), (x2, y2)], fill=color + (255,),
                   width=max(1, round(float(el.get("stroke-width", 1)) * scale)))
            continue
        if el.get("fill") in (None, "none"):
            continue
        if tag == "rect":
            x, y = float(el.get("x", 0)) * scale, float(el.get("y", 0)) * scale
            w, h = float(el.get("width")) * scale, float(el.get("height")) * scale
            pts = [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
        elif tag == "polygon":
            nums = [float(v) for v in el.get("points").replace(",", " ").split()]
            pts = [(nums[i] * scale, nums[i + 1] * scale) for i in range(0, len(nums), 2)]
        else:
            continue
        color = parse_color(el.get("fill"))
        alpha = int(float(el.get("opacity", 1.0)) * 255)
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).polygon(pts, fill=color + (alpha,))
        img = Image.alpha_composite(img, layer)
    return img, W, H


def sample(img, lx, ly):
    return img.getpixel((int(lx * SS + SS / 2), int(ly * SS + SS / 2)))


def near(c, ref, tol=3):
    return all(abs(a - b) <= tol for a, b in zip(c[:3], ref))


# ---- 1) 一体车身：渲染 + 像素断言 ----
elite, EW, EH = draw_svg(os.path.join(ASSETS, "elite_mortar_body.svg"), scale=SS)
assert (EW, EH) == (60 * SS, 80 * SS), "viewBox 与 width/height 不一致"

checks = [
    ("左仓口深缝", sample(elite, 38.5, 1.5), (23, 21, 20)),
    ("右仓口深缝", sample(elite, 49.5, 1.5), (23, 21, 20)),
    ("顶缘亮舱壁×3", sample(elite, 44, 1.5), (69, 61, 57)),
    ("舱体主色", sample(elite, 40, 12), (51, 46, 44)),
    ("仓间延伸缝", sample(elite, 44, 12), (42, 37, 36)),
    ("裙座暗色", sample(elite, 42, 27.5), (40, 35, 34)),
    ("舱红条(0.85)", sample(elite, 40, 30), (223, 74, 59)),
    ("舱尾散热栅", sample(elite, 50, 29.1), (26, 24, 23)),
    ("头亮色", sample(elite, 25, 22), (69, 61, 57)),
    ("眼缝红", sample(elite, 19, 26.5), (255, 81, 64)),
    ("hull主色", sample(elite, 30, 55), (51, 46, 44)),
    ("前斜面受光条", sample(elite, 4.7, 44), (58, 52, 49)),
    ("尾侧散热栅", sample(elite, 48, 44.6), (42, 37, 36)),
    ("远侧腿暗档", sample(elite, 50, 70), (40, 35, 34)),
    ("胯部关节缝", sample(elite, 38, 65), (23, 21, 20)),
    ("远侧脚暗色", sample(elite, 50, 79), (23, 21, 20)),
    ("近侧大腿", sample(elite, 26, 71), (51, 46, 44)),
    ("亮色足板", sample(elite, 30, 78), (69, 61, 57)),
]
fails = []
for name, got, want in checks:
    ok = near(got, want)
    print("%s %-12s got=%s want=%s" % ("PASS" if ok else "FAIL", name, got[:3], want))
    if not ok:
        fails.append(name)

c = sample(elite, 55.0, 24.9)  # 舱底斜削右楔口（裙座外侧）
ok = c[3] == 0
print("%s %s got=%s" % ("PASS" if ok else "FAIL", "舱底斜削镂空", c))
if not ok:
    fails.append("舱底斜削镂空")
c = sample(elite, 0.7, 49)  # 鼻尖贴左缘（最外圈是受光条）
ok = near(c, (58, 52, 49))
print("%s %s got=%s" % ("PASS" if ok else "FAIL", "鼻尖满幅", c))
if not ok:
    fails.append("鼻尖满幅")
bbox = elite.getbbox()
ok = bbox == (0, 0, 60 * SS, 80 * SS)
print("%s %s bbox=%s" % ("PASS" if ok else "FAIL", "画布=包围盒", bbox))
if not ok:
    fails.append("画布=包围盒")

# ---- 2) showcase ----
walker, WW, WH = draw_svg(os.path.join(ASSETS, "enemy_walker_body.svg"), scale=SS)
player, PW2, PH2 = draw_svg(os.path.join(ASSETS, "player_mech_body.svg"), scale=SS)

DARK = (20, 19, 18, 255)
FG = (232, 228, 222, 255)
DIM = (150, 144, 136, 255)
ACC = (255, 81, 64, 255)
canvas = Image.new("RGBA", (1480, 760), DARK)
d = ImageDraw.Draw(canvas)
try:
    font = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 22)
    small = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 17)
except OSError:
    font = small = ImageFont.load_default()

d.text((36, 24), "精英·导弹车 — 车体+肩部垂发舱 一体构图 提案 v2（PIL 代用栅格，平涂）", font=font, fill=FG)

# A: 单体 ×5 + 结构点名
ex, ey, k = 70, 110, 5
solo = elite.resize((EW * k // SS, EH * k // SS), Image.NEAREST)
canvas.alpha_composite(solo, (ex, ey))
d.text((ex, ey + solo.height + 10), "单体 ×5（60×80 px）", font=small, fill=DIM)
d.text((ex + 15 * k, ey + 24 * k), "←头 16×14", font=small, fill=FG)
d.text((ex + 34 * k, ey + 2 * k - 20), "两仓口（=一轮 2 发）", font=small, fill=ACC)
d.text((ex + 34 * k, ey + 40 * k), "垂发舱 24×34 高过头", font=small, fill=FG)

# B: 镜像 ×3（ArmPivot scale.x=-1 不变式：仓口仍朝天）
mir = elite.transpose(Image.FLIP_LEFT_RIGHT).resize((EW * 3 // SS, EH * 3 // SS), Image.LANCZOS)
mx = 470
canvas.alpha_composite(mir, (mx, 130))
d.text((mx, 130 + mir.height + 10), "镜像朝右 ×3（垂发仍朝天）", font=small, fill=DIM)

# C: 族内同框 ×2.5（杂兵 52 / 精英 80 / 玩家 104，地线对齐）
k3 = 5 // 2
gx, gy = 800, 560  # 地线
for img, w, h, name in ((walker, WW, WH, "杂兵 56×52"), (elite, EW, EH, "精英 60×80"), (player, PW2, PH2, "玩家 72×104")):
    r = img.resize((w * k3 // SS, h * k3 // SS), Image.LANCZOS)
    canvas.alpha_composite(r, (gx, gy - r.height))
    d.text((gx, gy + 8), name, font=small, fill=DIM)
    gx += max(r.width + 50, 130)
d.line([(780, gy), (1240, gy)], fill=(70, 66, 62, 255), width=2)
d.text((800, 130), "族内同框 ×2.5（地线对齐）", font=small, fill=FG)

# 右侧备注栏
nx = 1180
d.line([(nx - 30, 90), (nx - 30, 700)], fill=(60, 56, 52, 255), width=2)
notes = [
    ("构图（一体，非拼挂件）", FG),
    ("头 16×14 前置+红眼缝", DIM),
    ("垂发舱 24×34 后置高过头", DIM),
    ("两仓口 = ELITE_VOLLEY 2 发", DIM),
    ("", FG),
    ("比例账", FG),
    ("弹径 5.6 → 仓口 9×2+壁2", DIM),
    ("→ 舱宽 24 / 舱高 34", DIM),
    ("全高 80 = 杂兵×1.54", DIM),
    ("= 玩家×0.77 矮壮重甲", DIM),
    ("", FG),
    ("挂点（世界系）", FG),
    ("ArmPivot(14,-38.5) 舱口正中", DIM),
    ("Muzzle(0,0) 仓列 ±5.5", DIM),
    ("feet_offset 40 / body 60×80", DIM),
    ("", FG),
    ("色板同族（平涂无描边）", FG),
    ("332e2c / 282322", DIM),
    ("453d39 / 171514", DIM),
    ("ff5140 眼缝+舱红条", DIM),
]
ty = 110
for text, color in notes:
    d.text((nx, ty), text, font=small, fill=color)
    ty += 30

canvas.convert("RGB").save(os.path.join(OUT, "elite_vls_showcase.png"))
print("\n%d 项断言失败" % len(fails) if fails else "\n全部断言通过")
raise SystemExit(1 if fails else 0)
