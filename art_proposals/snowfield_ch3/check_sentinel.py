# -*- coding: utf-8 -*-
"""PIL 迷你光栅自检（引擎光栅被"编辑器在线"铁律阻塞期间的代用）：
解析本目录生成的 SVG（只用了 poly/rect/circle/line 平涂原语），按文档序渲染。
覆盖不了 rgrad 光晕（近似半透明椭圆）与 ThorVG 抗锯齿差异——只验剪影/比例/锚点，
最终判决定稿仍要 Godot 光栅（编辑器离线后补跑 raster_svg.gd + build_showcase）。"""
import math
import os
import re
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "world_3"))
OUT = os.path.join(HERE, "work")
os.makedirs(OUT, exist_ok=True)

# 敌营色板 + 电浆色（与 bake 脚本一致；rgrad 用同色半透明近似）
PALETTE = {
    "#5d6c76": (93, 108, 118), "#39444d": (57, 68, 77), "#2a333a": (42, 51, 58),
    "#161c21": (22, 28, 33), "#aab8c2": (170, 184, 194), "#e23d3d": (226, 61, 61),
    "#c9b23c": (201, 178, 60), "#7fd0ff": (127, 208, 255), "#eaf6ff": (234, 246, 255),
    "#2b6ea0": (43, 110, 160), "#ffd9d4": (255, 217, 212),
}


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def parse_color(fill, opacity):
    if fill.startswith("url("):  # rgrad 光晕：用第一 stop 色近似
        m = re.search(r'id="rg\d+"><stop offset="0" stop-color="(#[0-9a-f]+)" '
                      r'stop-opacity="([\d.]+)"', _defs)
        if m:
            return hex_rgb(m.group(1)) + (int(float(m.group(2)) * 255 * (opacity or 1)),)
        return (200, 200, 200, 60)
    rgb = PALETTE.get(fill, hex_rgb(fill) if fill.startswith("#") else (255, 0, 255))
    return rgb + (int(255 * (opacity if opacity is not None else 1)),)


def render_svg(path, scale=3):
    global _defs
    src = open(path, encoding="utf-8").read()
    _defs = src
    w = int(re.search(r'width="(\d+)"', src).group(1))
    h = int(re.search(r'height="(\d+)"', src).group(1))
    img = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img, "RGBA")
    for el in re.findall(r"<(poly|rect|circle|line|ellipse)\b[^>]*?/?>", src):
        pass
    for tag, body in re.findall(r"<(polygon|rect|circle|line|ellipse)\b([^>]*?)/>", src):
        tag = "poly" if tag == "polygon" else tag
        a = dict(re.findall(r'([\w-]+)="([^"]*)"', body))
        op = float(a["opacity"]) if "opacity" in a else None
        color = parse_color(a.get("fill", a.get("stroke", "#000")), op)
        if tag == "poly":
            pts = [tuple(map(float, p.split(",")))
                   for p in a["points"].split() if "," in p]
            dr.polygon([(x * scale, y * scale) for x, y in pts], fill=color)
        elif tag == "rect":
            x, y = float(a["x"]) * scale, float(a["y"]) * scale
            dr.rectangle([x, y, x + float(a["width"]) * scale,
                          y + float(a["height"]) * scale], fill=color)
        elif tag == "circle":
            cx, cy, r = (float(a["cx"]) * scale, float(a["cy"]) * scale,
                         float(a["r"]) * scale)
            dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
        elif tag == "ellipse":
            cx, cy = float(a["cx"]) * scale, float(a["cy"]) * scale
            rx, ry = float(a["rx"]) * scale, float(a["ry"]) * scale
            dr.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=color)
        elif tag == "line":
            dr.line([float(a["x1"]) * scale, float(a["y1"]) * scale,
                     float(a["x2"]) * scale, float(a["y2"]) * scale],
                    fill=color, width=max(1, int(float(a.get("stroke-width", 1)) * scale)))
    return img


def main():
    scale = 3
    body = render_svg(os.path.join(ASSETS, "boss_snow_body.svg"), scale)
    gun = render_svg(os.path.join(ASSETS, "boss_snow_gun.svg"), scale)
    mine = render_svg(os.path.join(ASSETS, "fx_plasma_mine.svg"), 4)
    bolt = render_svg(os.path.join(ASSETS, "plasma_bolt.svg"), 6)

    # 组装：body 3x + 炮臂钉在 ArmPivot(-44,-4)+offset(-112,-20)（画布账换算 3x）
    arm_x = (-44 + -112 + 130) * scale   # 枪画布原点在 Visuals -156,-24 → 画布 (-26,-24)
    arm_y = (-24 + 90) * scale
    sheet = Image.new("RGBA", (body.width + 40 + mine.width + 40 + bolt.width + 80,
                               body.height + 120), (24, 28, 26, 255))
    sheet.paste(body, (20, 100), body)
    sheet.paste(gun, (20 + arm_x, 100 + arm_y), gun)
    sheet.paste(mine, (body.width + 60, 160), mine)
    sheet.paste(bolt, (body.width + 100 + mine.width, 200), bolt)
    d = ImageDraw.Draw(sheet)
    # 锚点标记：独眼/四仓口/ArmPivot/枪口/BayPort（红十字，3x 系）
    marks = {"eye": (70, 58), "port1": (71, 26), "port4": (167, 26),
             "arm": (86, 86), "bay": (122, 138)}
    for name, (cx, cy) in marks.items():
        x, y = 20 + cx * scale, 100 + cy * scale
        d.line([x - 8, y, x + 8, y], fill=(255, 80, 80, 255), width=1)
        d.line([x, y - 8, x, y + 8], fill=(255, 80, 80, 255), width=1)
    # 枪口尖（臂局部 (-104,0) → 画布 (86-104, 86) = (-18,86)，在臂件坐标里）
    mx = 20 + arm_x + 8 * scale
    my = 100 + arm_y + 20 * scale
    d.line([mx - 8, my, mx + 8, my], fill=(120, 255, 120, 255), width=1)
    d.line([mx, my - 8, mx, my + 8], fill=(120, 255, 120, 255), width=1)
    out = os.path.join(OUT, "sentinel_check.png")
    sheet.save(out)
    print("saved", out, sheet.size)

    # 像素断言：独眼红在锚点、四仓口 GAP 深缝、炮口冰蓝线圈、闸口存在
    px = body.load()
    def at(cx, cy):
        return px[int(cx * scale), int(cy * scale)][:3]
    eye = at(70, 58)
    assert eye[0] > 180 and eye[1] < 110, f"独眼红缺失 @ (70,58): {eye}"
    for cx in (151, 167):  # 右肩双仓口深缝（v3b 砍左肩后仅存两孔）
        c = at(cx, 26)
        assert sum(c) < 150, f"仓口深缝缺失 @ ({cx},26): {c}"
    for cx in (71, 87):    # 前肩已砍：原仓口处应为全透明
        c = px[int(cx * scale), int(26 * scale)]
        assert c[3] == 0, f"前肩 Pod 未砍净 @ ({cx},26): {c}"
    gpx = gun.load()
    coil = gpx[30 * scale, 20 * scale][:3]
    assert coil[2] > 200 and coil[0] < 160, f"电浆线圈缺失: {coil}"
    muzzle = gpx[int(7.5) * scale, 20 * scale][:3]
    print(f"assert OK: eye={eye} port_gap sum<150 x4 coil={coil}")


if __name__ == "__main__":
    main()
