# -*- coding: utf-8 -*-
"""第九章「雷暴线场」环境烘焙 + 单位件入库（assets/world_9/）。

产物：
  env_storm_far.svg          远景条 1024x1300（= gen_storm9.far9，视差 0.9，tile 1024）
  env_storm_mid.svg          中景条 2048x520（= gen_storm9.mid9，视差 0.55，tile 2048）
  env_storm_pylon.svg        独层地标：倒伏门型巨塔 3200x900（视差 0.9，tile 3200 同屏一份）
  env_storm_ground_top.svg   表面带 640x66（bake_ground_v2 @ THEMES.p9_storm，种子 3111/3222）
  env_storm_ground_fill.svg  立面 16x256
  env_storm_ground.svg       兜底条 256x480（表面带单变体 + 深处焦土渐变，种子 3111）
  env_storm_deck.svg         缆槽检修栈桥桥面 720x26（scaffold_9）
  + storm_ch9/units/*.svg 原样拷入（单位/危险件，bake_storm_units.py 为正本）

独层地标挂载账（worlds.md §5）：条带位 (8,270) 居中挂载 → 画布 y = 世界 y + 180；
地形顶 664 = 画布 844。tex_x=1600，整件 x∈[1208,1977] ⊂ [1200, 2000]（=[1200+半宽, 2000−半宽]）
的防回绕安全带（tile 3200）。塔根画布 852 = 世界 672（沉入地形 8px，地块盖住塔脚）。
"""
import os
import random
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "terrain_blocks")))
sys.path.insert(0, HERE)
from generate_proposals import Svg, f, glow_dot  # noqa: E402
import ground_v2 as gv  # noqa: E402
import bake_ground_v2 as bgv  # noqa: E402
import gen_storm9 as g9  # noqa: E402

ASSETS = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "world_9"))
UNITS = os.path.join(HERE, "units")

TH = gv.THEMES["p9_storm"]
SIG_DECOR = "#6e52a0"   # 装饰紫（R10：只用于航标/警示杠）
GIANT = "#4c4a56"       # 巨塔主材（远层塔 #46524f 与中景件 #5a5566 之间，景深不反）
GIANT_DK = "#38363f"
GIANT_HI = "#8e9ab0"    # 钢青受光棱


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


def pylon_strip():
    """倒伏门型巨塔 3200x900（透明底）。塔根坐地（画布 852=世界 672），主桁梁
    斜卧向右上，塔头断口挑在半空（画布 ~330=世界 150），横担悬垂绝缘子串
    末端坠缆落地（两端都接实物/入地）。桁格节间 ~92px ≈ 远层塔 3 倍。种子 9094。"""
    rng = random.Random(9094)
    s = Svg(3200, 900)
    root_x, root_y = 1300.0, 852.0
    head_x, head_y = 1880.0, 340.0
    s.ellipse(1500, 850, 220, 7, "#221c28", 0.5)  # 接地阴影
    # 双弦：下弦（近地）与上弦，间距 ~70 收窄到 ~44（透视收分）
    lo0, lo1 = (root_x, root_y), (head_x, head_y + 40)
    up0, up1 = (root_x - 30, root_y - 74), (head_x - 18, head_y)
    n = 7
    los = [_lerp(lo0, lo1, i / n) for i in range(n + 1)]
    ups = [_lerp(up0, up1, i / n) for i in range(n + 1)]
    for a, b, w in ((lo0, lo1, 12), (up0, up1, 10)):
        s.line(a[0], a[1], b[0], b[1], GIANT, w, 0.97)
    for i in range(n):  # 桁格 X 撑 + 竖腹杆
        s.line(los[i][0], los[i][1], ups[i + 1][0], ups[i + 1][1], GIANT, 4.0, 0.9)
        s.line(ups[i][0], ups[i][1], los[i + 1][0], los[i + 1][1], GIANT, 4.0, 0.9)
        s.line(los[i][0], los[i][1], ups[i][0], ups[i][1], GIANT_DK, 5.0, 0.95)
    s.line(lo1[0], lo1[1], up1[0], up1[1], GIANT_DK, 6.0, 0.95)
    # 上弦受光棱（钢青细线，压在弦上）
    s.line(up0[0] + 4, up0[1] - 3, up1[0] + 2, up1[1] - 3, GIANT_HI, 1.6, 0.55)
    # 塔根：两条塔腿坐地 + 基础墩（脚入地，地块盖住下半）
    s.poly([(root_x - 70, 860), (root_x - 36, root_y - 76), (root_x - 20, root_y - 70),
            (root_x - 48, 860)], GIANT_DK, 0.95)
    s.poly([(root_x - 6, 860), (root_x + 4, root_y - 4), (root_x + 20, root_y),
            (root_x + 16, 860)], GIANT_DK, 0.95)
    s.rect(root_x - 92, 840, 130, 20, "#4e4856", 0.95)
    s.rect(root_x - 92, 840, 130, 3, "#8a8492", 0.85)
    # 塔头横担（断口一侧=辨识轮廓：斜指天空的长桁梁 + 折断的横担）
    s.line(head_x - 60, head_y + 8, head_x + 70, head_y - 26, GIANT, 9, 0.97)
    s.line(head_x - 40, head_y + 30, head_x + 60, head_y + 4, GIANT, 6, 0.95)
    for bx in range(0, 5):  # 断口锯齿（露筋）
        x0 = head_x + 70 + bx * 5
        s.line(x0, head_y - 26 - bx * 2, x0 + 3, head_y - 36 - bx * 3, GIANT_HI, 1.6, 0.75)
    # 悬垂绝缘子串 ×2（横担端下垂，重力向下=世界竖直）
    strings = ((head_x - 50, head_y + 12), (head_x + 40, head_y - 14))
    for sx, sy in strings:
        s.line(sx, sy, sx, sy + 56, GIANT_DK, 2.4, 0.95)
        for d in range(6):
            s.ellipse(sx, sy + 8 + d * 8, 7, 2.6, "#b0a4bc", 0.9)
            s.ellipse(sx, sy + 8 + d * 8, 7, 1.0, "#7e7290", 0.8)
    # 坠缆：右串末端 → 落地（画布 852 入地，两端接实物 ✓）
    ex, ey = strings[1][0], strings[1][1] + 56
    s.path(f"M {f(ex)},{f(ey)} Q {f(ex + 40)},{f(ey + 260)} {f(1975)},{f(852)}",
           stroke=GIANT_DK, w=3.0, opacity=0.85, cap="round")
    # 左串末端短断头（悬垂 + 断口亮点，不拖出画）
    lx, ly = strings[0][0], strings[0][1] + 56
    s.line(lx, ly, lx - 6, ly + 30, GIANT_DK, 2.6, 0.9)
    s.circle(lx - 6, ly + 30, 2.2, GIANT_HI, 0.7)
    # 塔身航标灯（装饰紫，低明度）
    mid_ = _lerp(up0, up1, 0.55)
    glow_dot(s, mid_[0], mid_[1] - 6, SIG_DECOR, r=3.2, halos=((8, 0.35), (16, 0.14)))
    # 塔根碎砾堆（入地）
    for _ in range(6):
        rx = rng.uniform(root_x - 80, root_x + 120)
        rw = rng.uniform(16, 34)
        rh = rng.uniform(6, 14)
        s.poly([(rx, 856), (rx + rw * 0.5, 856 - rh), (rx + rw, 856)], "#403848", 0.95)
    return s


def ground_fallback():
    """兜底条 256x480（GroundStrip 默认 tile 256）：表面带内容（单变体）+ 深处焦土渐变。"""
    s = Svg(256, 480)
    s.rect(0, 2.5, 256, 53.5, TH["band"])
    gv.band_detail(s, TH, 0.0, 0.0, 256.0, 56.0, 1.0, random.Random(3111))
    s.rect(0, 53.6, 256, 2.4, TH["band_edge"])
    s.rect(0, 0, 256, 2.8, TH["top_line"])
    s.rect(0, 56, 256, 10, TH["face_hi"])
    ao = s.vgrad("fbao9", [(0, TH["ao"], 0.8), (1, TH["ao"], 0.0)])
    s.rect(0, 56, 256, 10, ao)
    deep = s.vgrad("fbdeep9", [(0, TH["face_lo"], 1), (0.5, "#241e2a", 1), (1, "#1a1620", 1)])
    s.rect(0, 66, 256, 414, deep)
    for ty, op in ((120, 0.3), (210, 0.22), (310, 0.15), (410, 0.1)):
        s.line(0, ty, 256, ty, TH["strata"], 2, op)
    s.rect(0, 66, 3, 414, TH["seam"], 0.5)
    s.rect(253, 66, 3, 414, TH["seam"], 0.5)
    return s


def deck():
    """缆槽检修栈桥 720x26：钢青受光顶缘 + 盖板面（板缝）+ 前缘口装饰紫位标灯 + 桁架。"""
    s = Svg(720, 26)
    s.rect(0, 0, 720, 3, "#b0a4bc")
    s.rect(0, 3, 720, 7, "#5a5566")
    for gx in range(12, 720, 60):
        s.line(gx, 3.5, gx, 9.5, "#3a3542", 1.4, 0.7)
    s.rect(0, 10, 720, 2.5, "#2c2532")
    for lx in range(60, 720, 120):
        s.circle(lx, 11.2, 1.3, SIG_DECOR, 0.9)
    for i in range(18):
        x0 = i * 40.0
        if i % 2 == 0:
            s.line(x0, 12.5, x0 + 40, 24.5, "#3a3542", 2.0)
        else:
            s.line(x0, 24.5, x0 + 40, 12.5, "#3a3542", 2.0)
    s.line(0, 24.5, 720, 24.5, "#3a3542", 2.0)
    return s


def main():
    os.makedirs(ASSETS, exist_ok=True)
    save(g9.far9(), "env_storm_far.svg", """第九章远景条 1024x1300（视差 0.9，tile 1024）：雷暴青灰天
#3a4448→#566260→#787e78→#8e8e92（战斗带落中调）+ 低对比雷暴云横条 + 地平雷光紫软辉
+ 远山两排（k 整数正弦无缝）+ 门型铁塔群四座（顶=世界 314..336）+ 塔间垂弧导线 + 底雾压脚。
画布 y = 世界 y + 570。不画闪电盘（唯一地标规矩）。种子 9091。""")
    save(g9.mid9(), "env_storm_mid.svg", """第九章中景条 2048x520（视差 0.55，tile 2048，透明底）：四段各异
（断头高架墩/变压器台+电杆/塔基座残塔/警示牌+栅栏桩）+ 段间断缆垂弧。画布 y = 世界 y − 180；
落地件脚 488..500（地形顶 664=画布 484）。种子 9092。""")
    save(pylon_strip(), "env_storm_pylon.svg", """第九章独层地标：倒伏门型巨塔 3200x900（视差 0.9，tile 3200 同屏一份）。
tex_x=1600，整件 x 1208..1977 ⊂ [1200,2000] 防回绕安全带。条带位 (8,270) 居中挂载：画布 y = 世界 y + 180；
塔根画布 852 = 世界 672（沉入地形），塔头断口画布 ~340 = 世界 ~160。种子 9094。""")
    with open(os.path.join(ASSETS, "env_storm_ground_top.svg"), "w", encoding="utf-8") as fp:
        text = bgv.bake_band("storm", TH)
        fp.write(text)
        print("env_storm_ground_top.svg:", len(text) // 1024, "KB")
    with open(os.path.join(ASSETS, "env_storm_ground_fill.svg"), "w", encoding="utf-8") as fp:
        text = bgv.bake_fill(TH)
        fp.write(text)
        print("env_storm_ground_fill.svg:", len(text) // 1024, "KB")
    save(ground_fallback(), "env_storm_ground.svg", """第九章兜底条 256x480：表面带内容（单变体）+ 深处焦土渐变。种子 3111。""")
    save(deck(), "env_storm_deck.svg", """第九章缆槽检修栈桥 720x26（脚手架件）：钢青受光顶缘+盖板面+装饰紫位标灯+桁架。
scaffold_9 pier_color=#3a3542。""")
    for fn in sorted(os.listdir(UNITS)):
        if fn.endswith(".svg"):
            shutil.copyfile(os.path.join(UNITS, fn), os.path.join(ASSETS, fn))
            print("copy", fn)
    print("storm line chapter env baked.")


if __name__ == "__main__":
    main()
