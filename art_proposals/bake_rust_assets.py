# -*- coding: utf-8 -*-
"""方案一「锈雨废都」游戏素材烘焙：把提案拆成 WorldStrip / 地形 / 断桥平台用的 SVG。

产物直接写入 2d-ac/assets/：
  env_rust_far.svg         1024x1300 远景条（天空渐变+城市剪影，HillsStrip 换装）
  env_rust_mid.svg         1024x520  中景条（透明底楼群，新增 MidStrip）
  env_rust_ground.svg      256x480   兜底地面条（GroundStrip 换装）
  env_rust_ground_top.svg  256x56    地块表面带（terrain.gd 每块平铺，256 相位对齐）
  env_rust_ground_fill.svg 16x256    地块填充竖向渐变（拉伸用）
  env_rust_deck.svg        720x36    断桥桥面（scaffold 换装，长 720 ≈ 原脚手架 2.8 倍）

ThorVG 硬约束与提案一致：无 filter/pattern/use/text；横向平铺的纹理两侧留空或
花纹不越界，保证接缝不可见。种子固定，重跑一致。
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_proposals import Svg, f  # noqa: E402

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets"))

INK = "#57544a"       # 中景楼体
INK_FAR_A = "#9a9078" # 远景第一层（最远，最浅）
INK_FAR_B = "#857a5e" # 远景第二层
LIT = "#ffa04a"       # 钠灯橙
SLAB = "#63604f"      # 楼层板受光
GROUND_TOP = "#4d4a40"
GROUND_EDGE = "#6b6659"
GROUND_DEEP = "#3a382f"


def save(s: Svg, name: str) -> None:
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {s.w} {s.h}" '
        f'width="{s.w}" height="{s.h}">\n<defs>\n' + "\n".join(s.defs) + "\n</defs>\n"
        + "\n".join(s.body) + "\n</svg>\n"
    )
    with open(os.path.join(ASSETS, name), "w", encoding="utf-8") as fp:
        fp.write(svg)
    print(f"{name}: {len(svg) // 1024} KB")


# ---- 远景条：天空渐变 + 两层城市剪影 + 巨构/起重机地标 ----
def far_strip():
    rng = random.Random(901)
    s = Svg(1024, 1300)  # 底边=世界 y700（低于全部地形档顶），顶边在可视区外
    sky = s.vgrad("sky", [(0, "#b3a97f", 1), (0.39, "#b3a97f", 1), (0.62, "#c9b88e", 1),
                          (0.9, "#a89a76", 1), (1, "#9c8f6e", 1)])
    s.rect(0, 0, 1024, 1300, sky)
    # 注意：横平铺 1024px 下画面同屏会出现 2~3 份纹理，太阳这类"唯一地标"不能画进条带

    BASE = 1300.0
    # 远景两层：破损天际线（两侧 20px 留空保证平铺接缝 = 纯天空）
    for color, op, hmin, hmax, step in ((INK_FAR_A, 0.55, 220, 420, (46, 90)),
                                        (INK_FAR_B, 0.8, 300, 560, (56, 105))):
        x = 24.0
        while x < 1000 - 60:
            w = rng.uniform(38, 84)
            h = rng.uniform(hmin, hmax)
            top = BASE - h
            n = rng.randint(3, 5)
            tops = [(x, top + rng.uniform(0, h * 0.15))]
            for i in range(1, n):
                tops.append((x + w * i / (n - 1), top + rng.uniform(0, h * 0.15)))
            tops.append((x + w, top + rng.uniform(0, h * 0.15)))
            s.poly([(x, BASE)] + tops + [(x + w, BASE)], color, op)
            if rng.random() < 0.35:
                ax = x + w * rng.uniform(0.2, 0.8)
                s.line(ax, top, ax, top - rng.uniform(16, 40), color, 1.6, op)
            x += w + rng.uniform(*step)

    # 地标：巨型板塔（含楼层线）+ 工程起重机剪影
    s.poly([(64, BASE), (64, BASE - 268), (84, BASE - 292), (180, BASE - 292),
            (188, BASE - 236), (188, BASE)], INK_FAR_B, 0.9)
    for i in range(8):
        yy = BASE - 26 - i * 32
        s.line(70, yy, 182, yy, "#6f6650", 1.6, 0.85)
    s.line(126, BASE - 292, 126, BASE - 336, INK_FAR_B, 3.2, 0.9)
    mx = 906.0
    s.line(mx, BASE, mx + 8, BASE - 330, INK_FAR_B, 3, 0.9)          # 起重机塔身
    s.line(mx - 62, BASE - 318, mx + 112, BASE - 332, INK_FAR_B, 2.4, 0.9)  # 臂架
    s.line(mx + 6, BASE - 326, mx - 48, BASE - 208, INK_FAR_B, 1.6, 0.8)    # 拉索
    s.line(mx + 96, BASE - 328, mx + 96, BASE - 284, INK_FAR_B, 1.4, 0.8)   # 吊索
    s.rect(mx + 90, BASE - 284, 12, 9, INK_FAR_B, 0.9)

    # 地平线雾带 + 远处火光（弱化，平铺重复时读作"连片火区"）+ 灰烬
    g = s.vgrad("hz", [(0, "#cabb8e", 0), (1, "#cabb8e", 0.4)])
    s.rect(0, 1080, 1024, 220, g)
    s.glow_ellipse(360, 1272, 90, 24, "#ff9b45", 0.13)
    s.glow_ellipse(360, 1272, 40, 12, "#ffab5c", 0.18)
    for _ in range(10):
        s.circle(rng.uniform(40, 984), rng.uniform(560, 1000), rng.uniform(1, 2), "#ddd3ac", rng.uniform(0.15, 0.4))
    return s


# ---- 中景条：透明底楼群（楼层线+点窗+垂缆），两侧 40px 留空 ----
def mid_strip():
    rng = random.Random(902)
    s = Svg(1024, 520)
    BASE = 520.0
    x = 42.0
    while x < 982 - 90:
        w = rng.uniform(90, 150)
        h = rng.uniform(150, 300)
        top = BASE - h
        lean = rng.uniform(-16, 16) if rng.random() < 0.3 else 0.0
        col_w = rng.choice((15, 17, 19))

        def sx(yy, _h=h, _lean=lean):
            return _lean * (BASE - yy) / _h

        n = rng.randint(3, 5)
        edge = []
        for i in range(n + 1):
            ex = x + w * i / n
            ey = top + (rng.uniform(4, 24) if 0 < i < n and i % 2 == 0 else rng.uniform(2, 10))
            edge.append((ex + sx(ey), ey))
        s.poly([(x, BASE)] + edge + [(x + w, BASE)], INK)
        yy = top + 14
        while yy < BASE - 6:
            off = sx(yy)
            s.line(x + 3 + off, yy, x + w - 3 + off, yy, SLAB, 1.0, 0.55)
            yy += 14
        wx = x + 10
        while wx < x + w - 12:
            wy = top + 16
            while wy < BASE - 14:
                off = sx(wy)
                r = rng.random()
                if r < 0.045:
                    s.rect(wx - 3 + off, wy - 3, 11, 12, LIT, 0.12)
                    s.rect(wx + off, wy, 5, 6, LIT, 0.9)
                elif r < 0.12:
                    s.rect(wx + off, wy, 5, 6, "#6e5836", 0.9)
                else:
                    s.rect(wx + off, wy, 5, 6, "#3b3931", 0.9)
                wy += 14
            wx += col_w
        if rng.random() < 0.4:
            dx = x + w * 0.5
            s.rect(dx - 7, BASE - 18, 14, 18, "#ff8c3a", 0.75)
            s.rect(dx - 12, BASE - 30, 24, 30, "#ff8c3a", 0.16)
        x += w + rng.uniform(10, 64)
    # 楼间垂缆
    s.path("M 130 300 Q 330 400 560 306", stroke="#2c2a24", w=1.5, opacity=0.8)
    s.path("M 600 316 Q 780 396 962 320", stroke="#2c2a24", w=1.5, opacity=0.8)
    # 底部雾脚，接缝处更柔
    g = s.vgrad("fog", [(0, "#cabb8e", 0), (1, "#cabb8e", 0.4)])
    s.rect(0, 440, 1024, 80, g)
    return s


# ---- 地块表面带 256x56（横向平铺，花纹不越界） ----
def ground_top():
    rng = random.Random(903)
    s = Svg(256, 56)
    s.rect(0, 0, 256, 56, GROUND_TOP)
    s.rect(0, 0, 256, 3, GROUND_EDGE)              # 顶缘受光线
    s.rect(0, 51, 256, 5, GROUND_DEEP)             # 底缘压暗
    for cx, cy in ((70, 18), (150, 30), (210, 12)):  # 裂缝（距边 >=6px）
        pts_ = [(cx, cy)]
        px, py = cx, cy
        for _ in range(3):
            px += rng.uniform(8, 18)
            py += rng.uniform(6, 12)
            pts_.append((px, py))
        s.path("M " + " L ".join(f"{f(a)},{f(b)}" for a, b in pts_), stroke="#2e2c26", w=1.4, opacity=0.9)
    s.rect(30, 26, 26, 4, "#c9b23c", 0.16)         # 旧路中线残段
    for _ in range(14):                            # 碎石点
        s.rect(rng.uniform(6, 244), rng.uniform(8, 46), rng.uniform(2, 5), rng.uniform(1.5, 3), "#5b564a", rng.uniform(0.5, 0.9))
    s.ellipse(120, 44, 26, 3.5, "#e09a55", 0.10)   # 湿渍
    return s


# ---- 地块填充竖向渐变 16x256（横向拉伸 320，纵向拉伸到 FILL_DEPTH-56） ----
def ground_fill():
    s = Svg(16, 256)
    g = s.vgrad("fillg", [(0, "#45423a", 1), (0.35, "#3b3830", 1), (1, "#2b2925", 1)])
    s.rect(0, 0, 16, 256, g)
    return s


# ---- 兜底地面条 256x480（GroundStrip：表面带 + 填充渐变同款） ----
def ground_strip():
    s = Svg(256, 480)
    src = ground_top()
    s.body.extend(src.body)
    s.defs.extend(src.defs)
    g = s.vgrad("deepg", [(0, "#45423a", 1), (1, "#2b2925", 1)])
    s.rect(0, 56, 256, 424, g)
    return s


# ---- 断桥桥面 720x26（照抄提案高架桥侧视：直板 + 上亮缘 + 下暗缘，端头切平，无任何破损细节） ----
def deck():
    s = Svg(720, 26)
    s.rect(0, 0, 720, 26, "#46433a")
    s.line(0, 1.5, 720, 1.5, "#5a574b", 2.0)   # 上缘亮边
    s.line(0, 24.5, 720, 24.5, "#37352d", 2.0) # 下缘暗边
    return s


if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)
    save(far_strip(), "env_rust_far.svg")
    save(mid_strip(), "env_rust_mid.svg")
    save(ground_top(), "env_rust_ground_top.svg")
    save(ground_fill(), "env_rust_ground_fill.svg")
    save(ground_strip(), "env_rust_ground.svg")
    save(deck(), "env_rust_deck.svg")
