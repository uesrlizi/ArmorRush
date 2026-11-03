# -*- coding: utf-8 -*-
"""第七章「溺海都会」环境烘焙：六件套 + 桥式件 + 倾覆巨舰地标（独层）。

产物（assets/world_7/）：
  env_sea_far.svg          1024x1300  远景条：青绿高调天 + 沉没天际线（楼体入水即断）+ 远海带
  env_sea_wreck.svg        3200x900   独层地标：倾覆巨舰（龙骨朝天，tile 3200 同屏一份）
  env_sea_mid.svg          2048x520   中景条：屋顶孤岛 + 残货船艏 + 航标浮标（三段各异）
  env_sea_ground_top.svg   640x66     表面带=拆地块 v2 @ THEMES.p7_sea（复用 bake_ground_v2.bake_band）
  env_sea_girder.svg       320x28     桥式·箱梁（每块一幅，块间接缝烘在两端）
  env_sea_brace.svg        168x84     桥式·剪刀撑
  env_sea_column_1..3.svg  48x110/170/230  桥式·排架柱三档（按海面固定线自动选挡）
  env_sea_ground.svg       3200x480   海面固定底层（GroundStrip：青绿海 + 日光碎光路 + 浪纹）
  env_sea_sea_front.svg    3200x150   前景浪沿（SeaFront，遮柱脚=柱子没入海面）
  env_sea_deck.svg         720x26     海堤公路断桥桥面（脚手架件）

画布账：far 底=世界 730（画布 y = 世界 y + 570）；mid 底=世界 700（画布 y = 世界 y − 180）；
wreck 条带位 (8,270) 居中挂载：画布 y0=世界 −180（画布 y = 世界 y + 180）。
海平线=世界 560（far 画布 1130 / mid 画布 380 / wreck 画布 740）：桥面 664/600 档上方
露出一条远海带，536 档被桥面盖住。far 两侧留空 24px、mid 两侧留空 40px。
条带里不画唯一地标（巨舰/太阳走独层或不画）。ThorVG 硬约束：无 filter/pattern/use/
text/transform；无 rect+rotate。色板=提案 v1 §0。
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "terrain_blocks")))
from generate_proposals import Svg, f, glow_dot  # noqa: E402
import ground_v2 as gv  # noqa: E402
import bake_ground_v2 as bgv  # noqa: E402

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "world_7"))

# ---- 章七色板（v2 天光压暗：v1 照搬提案高调色板=天空近白，特效可读性
#      崩掉，雪原初版同罪——亮背景章的压暗天光规矩 §6 必须主动校验，提案
#      色板只定色相不定明度）。战斗带落中调 #8fb8b2：白溅花读得出、暗壳
#      弹也读得出。青绿色相不变。 ----
SKY_STOPS = [(0, "#5e8a8f", 1), (0.5, "#8fb8b2", 1), (1, "#b7d5cd", 1)]
FOG_COLOR = "#a3c4bc"   # 海雾（AerialFog 同值）
SEA_HI = "#5fc0b0"      # 远海受光
SEA_LO = "#2e948a"      # 远海深
SEA_NEAR_HI = "#3aa89c" # 近海（桥下）亮
SEA_NEAR_LO = "#175a58" # 近海深
FOAM = "#eafaf2"        # 白沫
FOAM_SOFT = "#d6f2e8"
GLITTER = "#f2fffa"
FAR_TOWER = "#5f8f89"   # 沉没楼群（远；v2 随天光压暗）
FAR_WIN = "#4a7a74"
HULL = "#5f8a84"        # 倾覆巨舰壳
HULL_DK = "#4a726e"
HULL_TEAR = "#496f6a"
MID = "#4a7a74"         # 中景屋顶孤岛
MID_DK = "#3f6a64"
RUST = "#7a5a3c"        # 锈流
RUST_HULL = "#7a4a3c"   # 残货船
RUST_HULL_HI = "#8f5a48"
RUST_CHAIN = "#5e3628"
BUOY = "#ff5a3c"        # 浮标橙（本章信号色）
RED = "#ff4640"


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


def _tower(s, rng, tx, tw, th, sea, color, win, op=0.85):
    """沉没楼体：入水即断（无地面接触），顶缘小破损 + 稀窗 + 偶发天线/倾斜。"""
    top = sea - th
    lean = rng.uniform(-6, 6) if rng.random() < 0.35 else 0.0
    s.poly([(tx, sea), (tx + lean * 0.3, top + rng.uniform(2, 10)),
            (tx + tw * 0.5, top), (tx + tw, top + rng.uniform(2, 12)), (tx + tw, sea)],
           color, op)
    if rng.random() < 0.5:
        ax = tx + tw * 0.4 + lean * 0.4
        s.line(ax, top + 4, ax + lean, top - rng.uniform(12, 28), color, 1.4, op)
    for _ in range(rng.randint(2, 5)):
        s.rect(tx + rng.uniform(4, max(5, tw - 7)), top + rng.uniform(10, max(12, th - 14)),
               2.5, 4, win, 0.8)
    # 水线泡沫（楼体入水处）
    s.ellipse(tx + tw * 0.5, sea + 1.5, tw * 0.55, 2.2, FOAM, 0.45)


def far_strip():
    """远景条 1024x1300：青绿高调天 + 沉没天际线 + 远海带。
    画布 y = 世界 y + 570：海平线画布 1130（世界 560）；楼群画布 760..1130
    （世界 190..560，楼顶在桥面上空可见）。种子 7071。"""
    rng = random.Random(7071)
    s = Svg(1024, 1300)
    s.rect(0, 0, 1024, 1300, s.vgrad("sky", SKY_STOPS))
    # 高天薄云带（三条通长浅弧，当天空纹理平铺）
    for yy, op in ((260, 0.16), (420, 0.12), (640, 0.09)):
        s.path("M -20 %d Q 512 %d 1044 %d" % (yy + 40, yy, yy + 40),
               stroke="#dceeea", w=22, opacity=op)
    # 地平线雾带（海雾压低楼脚对比）
    SEA = 1130.0
    # ---- 远海带（画布 1130..1300 = 世界 560..730）----
    sea = s.vgrad("sea", [(0, SEA_HI, 1), (1, SEA_LO, 1)])
    s.rect(0, SEA, 1024, 1300 - SEA, sea)
    s.line(0, SEA, 1024, SEA, FOAM, 2, 0.7)
    # 远海碎光（横向短划，低对比）
    for _ in range(90):
        gx = rng.uniform(24, 1000)
        gy = SEA + 4 + rng.uniform(0, 160)
        s.line(gx, gy, gx + rng.uniform(6, 18), gy, GLITTER, 1.4, rng.uniform(0.18, 0.42))
    # ---- 沉没天际线（两层：后排淡、前排实）----
    x = 30.0
    while x < 990:
        tw = rng.uniform(26, 46)
        th = rng.uniform(80, 200)
        _tower(s, rng, x, tw, th, SEA, "#7fa39e", "#5d837e", 0.6)   # 后排（雾中）
        x += tw + rng.uniform(18, 60)
    x = 46.0
    while x < 980:
        tw = rng.uniform(30, 52)
        th = rng.uniform(110, 300)
        _tower(s, rng, x, tw, th, SEA, FAR_TOWER, FAR_WIN, 0.88)    # 前排
        x += tw + rng.uniform(40, 110)
    # 零星航标灯（楼顶红点，稀）
    for _ in range(3):
        glow_dot(s, rng.uniform(80, 960), SEA - rng.uniform(150, 290), RED, r=1.8,
                 halos=((4, 0.3), (8, 0.12)))
    # 海雾带（压楼脚，横跨）
    fog = s.vgrad("fog", [(0, FOG_COLOR, 0.0), (0.6, FOG_COLOR, 0.5), (1, FOG_COLOR, 0.0)])
    s.rect(0, SEA - 90, 1024, 130, fog)
    return s


def wreck_strip():
    """独层地标：倾覆巨舰 3200x900（透明底）。条带位 (8,270)、region 900 高
    → 居中挂载：画布 y0=世界 −180，画布 y = 世界 y + 180。海平线画布 740
    （世界 560）；龙骨顶画布 ~560（世界 380）。舰身 x 1260..1940（半宽 340），
    tex_x=1600 ∈ [1540,1860] ✓ 防回绕弹切。种子 7072。"""
    rng = random.Random(7072)
    s = Svg(3200, 900)
    cx = 1600.0
    SEA = 740.0
    # 龙骨朝天的壳体（棱脊）
    hull = [(cx - 340, SEA), (cx - 300, SEA - 40), (cx - 240, SEA - 90), (cx - 160, SEA - 130),
            (cx - 60, SEA - 160), (cx + 40, SEA - 172), (cx + 140, SEA - 164), (cx + 220, SEA - 140),
            (cx + 290, SEA - 100), (cx + 330, SEA - 50), (cx + 340, SEA)]
    s.path("M " + " L ".join(f"{f(px)},{f(py)}" for px, py in hull), fill=HULL, opacity=0.95)
    # 龙骨脊线 + 纵向板缝 + 垂向肋骨刻
    s.path("M " + " L ".join(f"{f(px)},{f(py + 6)}" for px, py in hull[1:-1]),
           stroke=HULL_DK, w=3, opacity=0.6)
    s.line(cx - 280, SEA - 60, cx + 300, SEA - 66, HULL_DK, 2, 0.55)
    s.line(cx - 200, SEA - 24, cx + 240, SEA - 28, HULL_DK, 1.6, 0.5)
    for i in range(1, 10):
        px, py = hull[i]
        s.line(px, py + 10, px + 3, py + 40, HULL_DK, 2.2, 0.55)
    # 右段撕裂破口（深腔）
    s.poly([(cx + 200, SEA - 140), (cx + 262, SEA - 118), (cx + 250, SEA - 70), (cx + 190, SEA - 96)],
           "#2d4a46", 0.95)
    s.line(cx + 200, SEA - 140, cx + 262, SEA - 118, HULL_TEAR, 2, 0.8)
    # 舭龙骨/锈流
    for lx in (cx - 120, cx + 60, cx + 180):
        s.line(lx, SEA - 150, lx + 8, SEA - 8, RUST, 3, 0.35)
    # 螺旋桨轴架（舰艉露出：倾覆的签名读法）
    s.rect(cx - 352, SEA - 54, 30, 10, HULL_DK, 0.95)
    s.circle(cx - 366, SEA - 50, 16, HULL_DK, 0.95)
    for a in range(3):
        import math
        ang = a * 2.094 + 0.4
        s.line(cx - 366, SEA - 50, cx - 366 + 24 * math.cos(ang), SEA - 50 + 24 * math.sin(ang),
               HULL, 5, 0.9)
    # 脱落的艏楼段（漂在舰侧）+ 桅杆 + 航标红灯
    s.rect(cx + 330, SEA - 36, 60, 26, HULL, 0.95)
    s.rect(cx + 330, SEA - 36, 60, 4, "#86b0aa", 0.8)
    s.line(cx + 360, SEA - 36, cx + 360, SEA - 80, HULL, 3, 0.95)
    glow_dot(s, cx + 360, SEA - 84, RED, r=2.6, halos=((6, 0.35), (11, 0.13)))
    # 水线阴影 + 泡沫
    s.ellipse(cx, SEA + 3, 360, 9, "#1f6a66", 0.45)
    s.ellipse(cx - 40, SEA + 1, 300, 5, FOAM, 0.55)
    s.ellipse(cx + 360, SEA + 2, 50, 4, FOAM, 0.5)
    # 水下沉影（半透明壳的延伸，入水即渐隐）
    sub = s.vgrad("sub", [(0, HULL_DK, 0.45), (1, HULL_DK, 0.0)])
    s.rect(cx - 300, SEA + 4, 620, 60, sub)
    return s


def mid_strip():
    """中景条 2048x520（透明底，tile 2048）：三段各异——屋顶孤岛（水塔）/
    残货船艏（右倾插水）/ 屋顶平台 + 航标浮标。世界 y：画布 520=世界 700；
    海平线画布 380（世界 560），结构体 300..380 露在桥面上空。两侧 40px 留空。
    种子 7073。"""
    rng = random.Random(7073)
    s = Svg(2048, 520)
    SEA = 380.0

    def foam(cx_, w, op=0.55):
        s.ellipse(cx_, SEA + 2, w, 7, FOAM, op)

    # ---- A 段：屋顶孤岛（水塔 + 锈流 + 天线）----
    ax, at = 128.0, 318.0
    s.rect(ax, at, 118, SEA - at + 60, MID, 0.95)      # 楼体入水后继续向下（被桥面盖住）
    s.rect(ax + 14, at - 20, 26, 20, MID_DK, 0.95)     # 水塔
    s.poly([(ax + 14, at - 20), (ax + 40, at - 20), (ax + 27, at - 30)], MID_DK, 0.95)
    s.rect(ax + 66, at - 10, 34, 10, MID_DK, 0.95)
    s.line(ax + 96, at, ax + 96, at - 34, MID_DK, 2, 0.95)
    glow_dot(s, ax + 96, at - 36, RED, r=2.0)
    for rx_ in (ax + 30, ax + 74):
        s.line(rx_, at + 8, rx_ + 3, SEA - 6, RUST, 2.4, 0.4)
    for wx in (ax + 12, ax + 44, ax + 86):
        s.rect(wx, at + 14, 5, 7, "#223f3a", 0.8)
    foam(ax + 59, 78)
    # ---- B 段：残货船艏（左中，右倾插水；锈色=与青绿环境的补色）----
    bx = 560.0
    s.poly([(bx, SEA - 2), (bx + 62, SEA - 46), (bx + 150, SEA - 58), (bx + 176, SEA - 40), (bx + 132, SEA - 2)],
           RUST_HULL, 0.95)
    s.line(bx + 62, SEA - 46, bx + 150, SEA - 58, RUST_HULL_HI, 2, 0.9)
    s.rect(bx + 80, SEA - 70, 26, 14, RUST_HULL, 0.95)
    s.line(bx + 93, SEA - 70, bx + 93, SEA - 86, RUST_HULL, 2, 0.95)
    glow_dot(s, bx + 93, SEA - 88, RED, r=1.8)
    for chx in range(int(bx + 32), int(bx + 68), 9):
        s.circle(chx, SEA - 8 + (chx - bx - 32) * 0.3, 1.6, RUST_CHAIN, 0.8)
    foam(bx + 132, 60, 0.6)
    # ---- C 段：屋顶平台（右）+ 栈桥残段 ----
    cx2, ct = 1420.0, 334.0
    s.rect(cx2, ct, 92, SEA - ct + 60, MID, 0.95)
    s.rect(cx2 + 58, ct - 14, 20, 14, MID_DK, 0.95)
    s.rect(cx2 - 60, ct + 30, 60, 6, MID_DK, 0.9)       # 断栈桥板
    for px in (cx2 - 48, cx2 - 20):
        s.line(px, ct + 36, px, SEA, MID_DK, 2, 0.8)
    for wx in (cx2 + 10, cx2 + 36):
        s.rect(wx, ct + 12, 5, 7, "#223f3a", 0.8)
    foam(cx2 + 46, 62, 0.5)
    # ---- 航标浮标 ×3（本章信号色，分散在段间水面）----
    for bxx in (380.0, 1060.0, 1760.0):
        s.poly([(bxx - 7, SEA + 10), (bxx + 7, SEA + 10), (bxx + 4, SEA), (bxx - 4, SEA)], BUOY, 0.95)
        glow_dot(s, bxx, SEA + 1, RED, r=1.8, halos=((4, 0.35), (8, 0.12)))
        s.line(bxx - 9, SEA + 12, bxx + 9, SEA + 12, FOAM, 1.4, 0.5)
    # 背景碎光（段间水面）
    for _ in range(40):
        gx = rng.uniform(60, 1990)
        gy = SEA + rng.uniform(4, 40)
        s.line(gx, gy, gx + rng.uniform(8, 22), gy, GLITTER, 1.4, rng.uniform(0.2, 0.45))
    # 底部雾（融进桥面后方）
    g = s.vgrad("fog", [(0, FOG_COLOR, 0), (1, FOG_COLOR, 0.3)] )
    s.rect(0, 440, 2048, 80, g)
    return s


def bake_girder(th):
    """桥式·箱梁 320x28：band_edge 梁体 + face_lo 底缘暗线 + 两端块间接缝。"""
    s = Svg(320, 28)
    s.rect(0, 0, 320, 28, th["band_edge"])
    s.rect(0, 25, 320, 3, th["face_lo"])
    s.rect(0, 0, 320, 2, th["band_light"], 0.35)   # 梁顶受光细线（海光）
    for ex in (0.6, 319.4):
        s.line(ex, 0, ex, 28, th["seam"], 2.4, 0.6)
    return s


def bake_brace(th):
    """桥式·剪刀撑 168x84：X 交叉斜撑。"""
    s = Svg(168, 84)
    s.line(2, 2, 166, 82, th["pier"], 3.2, 0.55)
    s.line(166, 2, 2, 82, th["pier"], 3.2, 0.55)
    return s


def bake_column(th, h):
    """桥式·排架柱 48xh（实色细柱，宽 20；五章二轮定案：不渐隐、不烘云/浪）。
    柱脚入海由前景浪沿（env_sea_sea_front）遮挡。海堤柱身带水线锈渍（底段）。"""
    s = Svg(48, h)
    pier = th["pier"]
    s.rect(14, 0, 20, h, pier)
    s.rect(14, 0, 5, h, th["face_lo"], 0.6)       # 背光侧
    s.rect(30, 0, 4, h, "#4d6058", 0.4)           # 受光侧微亮（海光）
    s.rect(14, h - 26, 20, 26, RUST, 0.22)        # 水线锈渍
    s.rect(14, h - 6, 20, 6, "#2e4a44", 0.5)      # 浪打湿的柱脚
    return s


def bake_sea(th):
    """海面·固定底层 3200x480（GroundStrip）：青绿海体 + 平线亮边 + 低对比浪带
    + 日光碎光路（一条，tile 3200 同屏至多一份）+ 零星漂浮残板。左右 60px 留空
    （wrap 缝安全）。种子 7075。"""
    rng = random.Random(7075)
    s = Svg(3200, 480)
    g = s.vgrad("seab", [(0, SEA_NEAR_HI, 1), (0.3, "#2e948a", 1),
                         (0.68, "#1f7570", 1), (1, SEA_NEAR_LO, 1)])
    s.rect(0, 0, 3200, 480, g)
    s.line(0, 1.5, 3200, 1.5, FOAM, 3, 0.6)
    # ---- 浪纹（横向细长条纹，低对比，越深越稀）：v1 椭圆浪带（ry 7..14）读成
    #      睡莲/云垫与五章云海撞读法，v2 压扁拉长成水面光纹（ry 2..4）----
    for by, op, n in ((40, 0.26, 30), (120, 0.2, 26), (230, 0.15, 20), (360, 0.1, 16)):
        for _ in range(n):
            rx = rng.uniform(120, 320)
            cx = rng.uniform(80, 3120)
            yy = by + rng.uniform(-16, 16)
            s.ellipse(cx, yy, rx, rng.uniform(2.0, 4.0), "#8fdcce", op)
            s.ellipse(cx + rx * 0.25, yy + 6, rx * 0.6, rng.uniform(1.5, 3.0), "#145e5a", op * 0.9)
    # ---- 日光碎光路（纵向一束，碎短划密→疏）----
    gx0 = 1600.0
    gy = 6.0
    while gy < 470:
        spread = 40 + gy * 0.22
        for _ in range(2 if gy < 260 else 1):
            gx = gx0 + rng.uniform(-spread, spread)
            s.line(gx, gy, gx + rng.uniform(10, 26), gy, GLITTER, 1.8,
                   rng.uniform(0.25, 0.6) * (1.0 - gy / 620.0))
        gy += rng.uniform(4, 8)
    # ---- 漂浮残板（稀，暗）----
    for _ in range(9):
        px = rng.uniform(120, 3080)
        py = rng.uniform(60, 440)
        pw = rng.uniform(26, 70)
        s.rect(px, py, pw, 4, "#2a4a44", 0.55)
        s.ellipse(px + pw * 0.5, py + 5, pw * 0.6, 2.5, FOAM, 0.25)
    return s


def bake_sea_front(th):
    """海面·前景浪沿 3200x150（SeaFront：画在 Terrain 之后遮柱脚，与地面同速）。
    顶缘=错落浪冠（白沫椭圆高低起伏），柱子由此「没入海面」；底缘 40px 渐隐
    融进海底色。种子 7076。"""
    rng = random.Random(7076)
    s = Svg(3200, 150)
    body = s.vgrad("seaf", [(0, "#2f9a90", 1), (0.5, "#227a74", 1),
                            (0.78, "#1f7570", 1), (1.0, "#1f7570", 0.0)])
    # 浪冠团（先画团，再垫实体，顶缘=团的弧）
    x = 20.0
    while x < 3160:
        rx = rng.uniform(50, 130)
        ry = rng.uniform(14, 30)
        s.ellipse(x + rx * 0.5, 52 + rng.uniform(-12, 14), rx, ry, "#2f9a90", 1.0)
        x += rx * rng.uniform(0.7, 1.2)
    s.rect(0, 44, 3200, 106, body)
    # 浪冠白沫（顶受光）+ 碎沫点
    x = 20.0
    while x < 3160:
        rx = rng.uniform(40, 110)
        s.ellipse(x + rx * 0.5, 44 + rng.uniform(-9, 10), rx, 7, FOAM, rng.uniform(0.45, 0.7))
        x += rx * rng.uniform(0.9, 1.5)
    for _ in range(120):
        s.circle(rng.uniform(20, 3180), rng.uniform(34, 60), rng.uniform(1.0, 2.4), FOAM_SOFT,
                 rng.uniform(0.3, 0.6))
    # 浪沿下的暗浪纹
    for _ in range(30):
        wx = rng.uniform(60, 3100)
        wy = rng.uniform(70, 110)
        s.ellipse(wx, wy, rng.uniform(60, 160), 4, "#145e5a", 0.35)
    return s


def deck():
    """海堤公路断桥桥面 720x26（脚手架件）：混凝土路面 + 护栏立柱 + 航标橙灯
    + 桁架。行走面=顶缘（亮线 3px + 路面 7px），桁架收在下 16px。"""
    s = Svg(720, 26)
    s.rect(0, 0, 720, 3, "#a9c4b8")             # 顶缘受光（海光）
    s.rect(0, 3, 720, 7, "#4a5f57")             # 混凝土路面
    for gx in range(12, 720, 24):               # 路面伸缩缝
        s.line(gx, 3.5, gx, 9.5, "#37453e", 1.4, 0.6)
    s.rect(0, 10, 720, 2.5, "#22312b")          # 前缘口
    for lx in range(60, 720, 120):              # 航标橙灯
        s.circle(lx, 11.2, 1.3, BUOY, 0.9)
    for i in range(18):                         # 桁架腹杆
        x0 = i * 40.0
        if i % 2 == 0:
            s.line(x0, 12.5, x0 + 40, 24.5, "#2d3f38", 2.0)
        else:
            s.line(x0, 24.5, x0 + 40, 12.5, "#2d3f38", 2.0)
    s.line(0, 24.5, 720, 24.5, "#2d3f38", 2.0)  # 下弦
    return s


def main():
    os.makedirs(ASSETS, exist_ok=True)
    save(far_strip(), "env_sea_far.svg", """第七章远景条 1024x1300（视差 0.9，tile 1024）：青绿高调天
#5e8a8f→#8fb8b2→#b7d5cd（v2 压暗）+ 沉没天际线（楼体入水即断，双层）+ 远海带（画布 1130=世界 560）
+ 海雾带。画布底=世界 730。两侧 24px 留空。种子 7071。""")
    save(wreck_strip(), "env_sea_wreck.svg", """第七章独层地标：倾覆巨舰 3200x900（视差 0.9，tile 3200 同屏一份）。
地标 tex_x=1600（舰身半宽 340：∈[1540,1860]，防回绕弹切，worlds.md §5）。
条带位 (8,270) 居中挂载：画布 y0=世界 -180；海平线画布 740=世界 560，龙骨顶
画布 568=世界 388。种子 7072。""")
    save(mid_strip(), "env_sea_mid.svg", """第七章中景条 2048x520（视差 0.55，tile 2048，透明底）：三段各异
（屋顶孤岛水塔/残货船艏/屋顶平台+断栈桥）+ 航标浮标×3。画布 520=世界 700，
海平线画布 380=世界 560。两侧 40px 留空。种子 7073。""")
    th = gv.THEMES["p7_sea"]
    with open(os.path.join(ASSETS, "env_sea_ground_top.svg"), "w", encoding="utf-8") as fp:
        text = bgv.bake_band("sea", th)
        fp.write(text)
        print("env_sea_ground_top.svg:", len(text) // 1024, "KB")
    for name, tex in (("girder", bake_girder(th)), ("brace", bake_brace(th)),
                      ("column_1", bake_column(th, 110)),
                      ("column_2", bake_column(th, 170)),
                      ("column_3", bake_column(th, 230))):
        save(tex, f"env_sea_{name}.svg", f"""第七章桥式·{name} 件（terrain.gd 桥式模式：
箱梁/剪刀撑/排架柱各自独立贴图，排架柱三档高度 110/170/230 按
「bridge_sea_y 固定海面线−柱顶」自动选挡，柱底统一钉在海面上）。""")
    save(bake_sea(th), "env_sea_ground.svg", """第七章海面·固定底层 3200x480（GroundStrip，与地面同速）：
青绿海体+平线亮边+低对比浪带+日光碎光路（一束）+漂浮残板。
两侧 60px 留空=wrap 缝安全。种子 7075。""")
    save(bake_sea_front(th), "env_sea_sea_front.svg", """第七章海面·前景浪沿 3200x150（SeaFront：场景里画在 Terrain 之后，
遮住柱脚=柱子「没入海面」）。顶缘错落浪冠白沫+底缘渐隐融进海底色。种子 7076。""")
    save(deck(), "env_sea_deck.svg", """第七章海堤公路断桥桥面 720x26（脚手架件）：海光顶缘+混凝土路面
伸缩缝+航标橙灯+桁架。scaffold_7 pier_color=#37453e。""")
    print("drowned city chapter env baked.")


if __name__ == "__main__":
    main()
