# -*- coding: utf-8 -*-
"""第十章「硫焰地热田」环境烘焙 + 单位件入库（assets/world_10/）。

产物：
  env_sulfur_far.svg          远景条 1024x1300（= gen_sulfur10.far10，视差 0.9，tile 1024）
  env_sulfur_mid.svg          中景条 2048x520（= gen_sulfur10.mid10，视差 0.55，tile 2048）
  env_sulfur_derrick.svg      独层地标：倾斜巨型地热井架 3200x900（视差 0.9，tile 3200 同屏一份）
  env_sulfur_ground_top.svg   表面带 640x66（bake_ground_v2 @ THEMES.p10_sulfur，种子 3111/3222）
  env_sulfur_ground_fill.svg  立面 16x256
  env_sulfur_ground.svg       兜底条 256x480（表面带单变体 + 深处玄武渐变，种子 3111）
  env_sulfur_deck.svg         管廊检修栈桥桥面 720x26（scaffold_10）
  + sulfur_ch10/units/*.svg 原样拷入（单位/危险件，bake_sulfur_units.py 为正本）

独层地标挂载账（worlds.md §5）：条带位 (8,270) 居中挂载 → 画布 y = 世界 y + 180；
地形顶 664 = 画布 844。tex_x=1600，整件 x∈[1240,1960] ⊂ [1200,2000] 防回绕安全带。
钻台底座脚线画布 852 = 世界 672（沉入地形 8px，地块盖住底座脚）。
"""
import os
import random
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "terrain_blocks")))
sys.path.insert(0, HERE)
from generate_proposals import Svg, f  # noqa: E402
import ground_v2 as gv  # noqa: E402
import bake_ground_v2 as bgv  # noqa: E402
import gen_sulfur10 as g10  # noqa: E402

ASSETS = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "world_10"))
UNITS = os.path.join(HERE, "units")

TH = gv.THEMES["p10_sulfur"]
SIG = "#48b4ff"
SIG_CORE = "#c8ecff"
GIANT = "#56544c"       # 井架主材（远层壁 #4c4836 与中景管材 #5c5a52 之间）
GIANT_DK = "#3a3934"
GIANT_HI = "#9a9682"


def save(s: Svg, name: str, comment: str = "") -> None:
    doc = comment.strip("\n")
    head = f"<!-- {doc} -->\n" if doc else ""
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(s.w)} {f(s.h)}" '
        f'width="{f(s.w)}" height="{f(s.h)}">\n{head}<defs>\n' + "\n".join(s.defs)
        + "\n</defs>\n" + "\n".join(s.body) + "\n</svg>\n"
    )
    with open(os.path.join(ASSETS, name), "w", encoding="utf-8") as fp:
        fp.write(svg)
    print(f"{name}: {len(svg) // 1024} KB")


def _lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def derrick_strip():
    """倾斜巨型地热井架 3200x900（透明底）。钻台底座坐地（脚画布 852），两腿桁格
    斜挑向右上，架顶天车在画布 (1880,330)=世界 150，顶部放空烟；底座上司钻房，
    井口硫焰坐底座顶。种子 10104。"""
    rng = random.Random(10104)
    s = Svg(3200, 900)
    s.ellipse(1460, 850, 200, 7, "#1e1c18", 0.5)               # 接地阴影
    s.rect(1260, 816, 380, 36, GIANT_DK, 0.97)                 # 钻台底座
    s.rect(1260, 816, 380, 4, GIANT_HI, 0.6)
    for bx in range(1280, 1640, 60):                           # 底座桁格
        s.line(bx, 820, bx + 30, 850, GIANT, 3, 0.8)
        s.line(bx + 30, 820, bx, 850, GIANT, 3, 0.8)
    L0, R0 = (1300.0, 816.0), (1580.0, 816.0)
    lt, rt = (1844.0, 342.0), (1908.0, 350.0)
    s.line(L0[0], L0[1], lt[0], lt[1], GIANT, 12, 0.97)
    s.line(R0[0], R0[1], rt[0], rt[1], GIANT, 12, 0.97)
    n = 9
    for i in range(1, n + 1):
        a, b = _lerp(L0, lt, i / n), _lerp(R0, rt, i / n)
        a0, b0 = _lerp(L0, lt, (i - 1) / n), _lerp(R0, rt, (i - 1) / n)
        s.line(a[0], a[1], b[0], b[1], GIANT, 5, 0.92)
        s.line(a0[0], a0[1], b[0], b[1], GIANT_DK, 3, 0.85)
        s.line(b0[0], b0[1], a[0], a[1], GIANT_DK, 3, 0.85)
    s.line(L0[0] + 6, L0[1] - 4, lt[0] + 4, lt[1] - 2, GIANT_HI, 1.8, 0.5)   # 受光棱
    s.rect(1830, 318, 96, 32, GIANT_DK, 0.97)                  # 天车
    s.rect(1830, 318, 96, 4, GIANT_HI, 0.6)
    for i, (dy, r, op) in enumerate(((0, 18, 0.42), (-40, 26, 0.34), (-90, 34, 0.26),
                                     (-150, 42, 0.18), (-220, 50, 0.11))):
        s.circle(1878 + i * 8, 306 + dy, r, "#d8d4b4", op)     # 放空汽柱（根接天车）
    s.rect(1400, 756, 100, 60, "#4a4a46", 0.97)                # 司钻房
    s.rect(1400, 756, 100, 3, GIANT_HI, 0.6)
    s.rect(1418, 772, 28, 16, "#d6cc8a", 0.55)
    # 井口硫焰（坐底座顶 816）
    s.rect(1540, 796, 28, 20, GIANT_DK, 0.97)
    s.path("M 1542,796 Q 1534,770 1548,744 Q 1554,726 1556,712 Q 1562,734 1568,752 "
           "Q 1576,776 1566,796 Z", fill=SIG, opacity=0.9)
    s.path("M 1548,796 Q 1544,778 1552,760 Q 1556,750 1557,740 Q 1561,758 1563,770 "
           "Q 1566,784 1561,796 Z", fill=SIG_CORE, opacity=0.95)
    # 坠落管线：天车→底座右端（两端接实物）
    s.path("M 1900,350 Q 1760,640 1636,818", stroke=GIANT_DK, w=3, opacity=0.8, cap="round")
    for _ in range(6):                                         # 底座碎砾（入地）
        rx = rng.uniform(1260, 1600)
        rw, rh = rng.uniform(16, 30), rng.uniform(5, 12)
        s.poly([(rx, 856), (rx + rw * 0.5, 856 - rh), (rx + rw, 856)], "#34332f", 0.95)
    return s


def ground_fallback():
    s = Svg(256, 480)
    s.rect(0, 2.5, 256, 53.5, TH["band"])
    gv.band_detail(s, TH, 0.0, 0.0, 256.0, 56.0, 1.0, random.Random(3111))
    s.rect(0, 53.6, 256, 2.4, TH["band_edge"])
    s.rect(0, 0, 256, 2.8, TH["top_line"])
    s.rect(0, 56, 256, 10, TH["face_hi"])
    ao = s.vgrad("fbao10", [(0, TH["ao"], 0.8), (1, TH["ao"], 0.0)])
    s.rect(0, 56, 256, 10, ao)
    deep = s.vgrad("fbdeep10", [(0, TH["face_lo"], 1), (0.5, "#1c1b1a", 1), (1, "#141312", 1)])
    s.rect(0, 66, 256, 414, deep)
    for ty, op in ((120, 0.3), (210, 0.22), (310, 0.15), (410, 0.1)):
        s.line(0, ty, 256, ty, TH["strata"], 2, op)
    s.rect(0, 66, 3, 414, TH["seam"], 0.5)
    s.rect(253, 66, 3, 414, TH["seam"], 0.5)
    return s


def deck():
    """管廊检修栈桥 720x26：硫黄淡亮顶缘 + 格栅板面 + 硫焰蓝位标灯 + 桁架。"""
    s = Svg(720, 26)
    s.rect(0, 0, 720, 3, "#c8bc78")
    s.rect(0, 3, 720, 7, "#5c5a52")
    for gx in range(12, 720, 60):
        s.line(gx, 3.5, gx, 9.5, "#3c3b36", 1.4, 0.7)
    s.rect(0, 10, 720, 2.5, "#2a2926")
    for lx in range(60, 720, 120):
        s.circle(lx, 11.2, 1.3, SIG, 0.9)
    for i in range(18):
        x0 = i * 40.0
        if i % 2 == 0:
            s.line(x0, 12.5, x0 + 40, 24.5, "#3c3b36", 2.0)
        else:
            s.line(x0, 24.5, x0 + 40, 12.5, "#3c3b36", 2.0)
    s.line(0, 24.5, 720, 24.5, "#3c3b36", 2.0)
    return s


def main():
    os.makedirs(ASSETS, exist_ok=True)
    save(g10.far10(), "env_sulfur_far.svg", """第十章远景条 1024x1300（视差 0.9，tile 1024）：硫烟赭橄榄天
#5a5632→#8a8348→#b2a866（战斗带落中调）+ 破火山口壁两排（k 整数正弦无缝）+ 硫烟柱 + 地平硫雾辉 + 底雾压脚。
画布 y = 世界 y + 570。种子 10101。""")
    save(g10.mid10(), "env_sulfur_mid.svg", """第十章中景条 2048x520（视差 0.55，tile 2048，透明底）：四段各异
（汽水分离塔/井口阀树+Ω 弯管/硫黄堆+斜槽/喷气孔围栏+警示牌）。画布 y = 世界 y − 180；落地件脚 488..500。""")
    save(derrick_strip(), "env_sulfur_derrick.svg", """第十章独层地标：倾斜巨型地热井架 3200x900（视差 0.9，tile 3200 同屏一份）。
tex_x=1600，整件 x 1240..1960 ⊂ [1200,2000] 防回绕安全带。条带位 (8,270) 居中挂载：画布 y = 世界 y + 180；
底座脚画布 852 = 世界 672（沉入地形），天车画布 ~330 = 世界 ~150。种子 10104。""")
    for name, text in (("env_sulfur_ground_top.svg", bgv.bake_band("sulfur", TH)),
                       ("env_sulfur_ground_fill.svg", bgv.bake_fill(TH))):
        with open(os.path.join(ASSETS, name), "w", encoding="utf-8") as fp:
            fp.write(text)
        print(name, len(text) // 1024, "KB")
    save(ground_fallback(), "env_sulfur_ground.svg", """第十章兜底条 256x480：表面带内容（单变体）+ 深处玄武渐变。种子 3111。""")
    save(deck(), "env_sulfur_deck.svg", """第十章管廊检修栈桥 720x26（脚手架件）。scaffold_10 pier_color=#3c3b36。""")
    for fn in sorted(os.listdir(UNITS)):
        if fn.endswith(".svg"):
            shutil.copyfile(os.path.join(UNITS, fn), os.path.join(ASSETS, fn))
            print("copy", fn)
    print("sulfur field chapter env baked.")


if __name__ == "__main__":
    main()
