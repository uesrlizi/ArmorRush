# -*- coding: utf-8 -*-
"""world_9 接地账合成对比帧（worlds.md §2 规约）：far+mid 按挂载账合成 +
664 地形顶线 + 三档地形近似，与前章（ch8 镜盐之原）同规格并排。

挂载账：far 条画布底=世界 730（贴图 1024x1300 → 帧内 top=-570，tile 1024 平铺）；
mid 条画布底=世界 700（2048x520 → top=180）；地形顶 664 红线。
帧=世界坐标系 2400x1080（视口宽）。输入=Godot 光栅 PNG（同源渲染）。
输出 storm_ch9/comp_ch8_ch9.png。
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 2400, 1080
GROUND_TOP = 664

# 章地形色（ground_v2 THEMES 同值：face_hi/band/top_line）
CH = {
    "ch8": {"face": "#a8967a", "band": "#b8a684", "top": "#e8d8bc",
            "far": "_salt_far.png", "mid": "_salt_mid.png",
            "label": "ch8 mirror-salt (prev chapter)"},
    "ch9": {"face": "#453b4a", "band": "#4e4452", "top": "#b0a4bc",
            "far": "env_storm_far.png", "mid": "env_storm_mid.png",
            "label": "ch9 storm-line (new)"},
}


def frame(spec):
    img = Image.new("RGB", (W, H))
    far = Image.open(os.path.join(HERE, spec["far"])).convert("RGBA")
    for x in (0, 1024, 2048):
        img.paste(far, (x, 730 - 1300), far)
    mid = Image.open(os.path.join(HERE, spec["mid"])).convert("RGBA")
    for x in (0, 2048):
        img.paste(mid, (x, 700 - 520), mid)
    # 地形近似：band 带（664..720）+ 立面色（720..H）+ 顶缘亮线
    d = ImageDraw.Draw(img)
    d.rectangle((0, GROUND_TOP, W, 720), fill=spec["band"])
    d.rectangle((0, 720, W, H), fill=spec["face"])
    d.rectangle((0, GROUND_TOP, W, GROUND_TOP + 3), fill=spec["top"])
    d.line((0, GROUND_TOP, W, GROUND_TOP), fill=(255, 60, 60), width=2)
    return img


def main():
    rows = [frame(CH[k]) for k in ("ch8", "ch9")]
    scale = 0.5
    sw, sh = int(W * scale), int(H * scale)
    rows = [r.resize((sw, sh), Image.LANCZOS) for r in rows]
    out = Image.new("RGB", (sw, sh * 2 + 8), (20, 20, 20))
    out.paste(rows[0], (0, 0))
    out.paste(rows[1], (0, sh + 8))
    d = ImageDraw.Draw(out)
    d.text((10, 4), CH["ch8"]["label"] + "   red line = terrain top y664", fill=(255, 255, 255))
    d.text((10, sh + 12), CH["ch9"]["label"] + "   red line = terrain top y664", fill=(255, 255, 255))
    p = os.path.join(HERE, "comp_ch8_ch9.png")
    out.save(p)
    print("OK", p, out.size)


if __name__ == "__main__":
    main()
