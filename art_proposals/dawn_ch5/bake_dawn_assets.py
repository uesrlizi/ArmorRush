# -*- coding: utf-8 -*-
"""第五章「破晓云廊」环境烘焙：六件套 + 天梯缆地标（独层）。

产物（assets/world_5/）：
  env_dawn_far.svg         1024x1300  远景条：晨空渐变+细弧天带+浮空平台链+云海线
  env_dawn_ladder.svg      3200x900   独层地标：天梯缆塔（tile 3200 同屏一份）
  env_dawn_mid.svg         2048x520   中景条：浮空平台近景（三段各异）
  env_dawn_ground_top.svg  640x66     表面带=拆地块 v2 @ THEMES.p5_cloud（复用 bake_ground_v2.bake_band）
  env_dawn_girder.svg      320x28     桥式·箱梁（每块一幅，块间接缝烘在两端）
  env_dawn_brace.svg       168x84     桥式·剪刀撑（两柱之间梁下）
  env_dawn_column_1..3.svg 56x110/170/230  桥式·排架柱三档（按海面固定线自动选挡）
  env_dawn_ground.svg      3200x480   云海固定底层（GroundStrip scroll=1 钉屏幕）
  env_dawn_sea_front.svg   3200x150   云海前景云沿（SeaFront，遮柱脚）
  env_dawn_deck.svg        720x26     脚手架断桥桥面
（env_dawn_ground_fill.svg 已废弃删除：整面渐隐版被打回，桥式拆件取代。）

画布账：far 底=世界 730（画布 y = 世界 y + 570）；mid 底=世界 700（画布 y = 世界 y − 180）。
far 两侧留空 24px、mid 两侧留空 40px（平铺接缝规矩）。
条带里不画唯一地标：天环只留"通长细弧带"当晨空纹理；天梯缆塔走独层
（tex_x=1600 ∈ [1200+半宽, 3200−1200−半宽]，防回绕弹切）。
ThorVG 硬约束：无 filter/pattern/use/text/transform；无 rect+rotate。
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

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "world_5"))

# ---- 章五色板（同提案 v1） ----
SKY_STOPS = [(0, "#33265a", 1), (0.45, "#8e5578", 1), (0.75, "#d8846e", 1), (1, "#f4b071", 1)]
GOLD = "#f4b071"        # 金霞
GOLD_HI = "#ffe2b0"     # 金屑/受光
RIM_WARM = "#e8b48a"    # 平台顶缘霞光描边
BODY = "#4e3c64"        # 平台/敌营主体（暗紫罗兰）
BODY_DEEP = "#443258"
BODY_DARK = "#3d3856"
BELLY = "#3a2c50"
CLOUD_LIT = "#fbeef0"   # 云顶受光
CLOUD_MID = "#e9d3de"
CLOUD_SHADE = "#a87c96"
CLOUD_DEEP = "#7a5f86"
STAR = "#ffe9c2"


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


def far_strip():
    """远景条 1024x1300：晨空渐变 + 通长细弧天带 + 浮空平台链 + 云海线。
    画布 y = 世界 y + 570：云海平线画布 1150..1250（世界 580..680，藏地块后）；
    平台链剪影画布 950..1090（世界 380..520）。种子 5051。"""
    rng = random.Random(5051)
    s = Svg(1024, 1300)
    s.rect(0, 0, 1024, 1300, s.vgrad("sky", SKY_STOPS))
    # 高天金屑
    for _ in range(16):
        s.circle(rng.uniform(24, 1000), rng.uniform(20, 520), rng.uniform(0.8, 1.8),
                 GOLD_HI, rng.uniform(0.15, 0.45))
    # 通长细弧天带（当晨空纹理平铺，非地标：整宽淡弧，无独立环心读法）
    for yy, op in ((300, 0.16), (360, 0.10), (430, 0.07)):
        s.path("M -20 %d Q 512 %d 1044 %d" % (yy + 60, yy, yy + 60),
               stroke="#f2c896", w=5, opacity=op)
    # ---- 远景浮空平台链（同一悬停高度的编队剪影）----
    x = 10.0
    while x < 1000:
        bw = rng.uniform(70, 130)
        by = 1000.0 + rng.uniform(-24, 28)
        s.rect(x, by, bw, rng.uniform(6, 9), BODY, 0.55)
        for _t in range(rng.randint(1, 2)):
            tw = rng.uniform(8, 17)
            th = rng.uniform(18, 52)
            tx = x + rng.uniform(5, max(7, bw - tw - 5))
            s.rect(tx, by - th, tw, th, BODY, 0.55)
            if rng.random() < 0.45:  # 天线
                s.line(tx + tw * 0.5, by - th, tx + tw * 0.5,
                       by - th - rng.uniform(7, 17), BODY, 1.2, 0.55)
        # 板底鳍（悬停下挂结构）
        s.poly([(x + bw * 0.24, by + 8), (x + bw * 0.40, by + 8),
                (x + bw * 0.33, by + rng.uniform(13, 19)), (x + bw * 0.26, by + rng.uniform(13, 19))],
               BODY, 0.55)
        s.circle(x + bw * rng.uniform(0.15, 0.8), by + rng.uniform(9, 12), 1.4,
                 "#ffc46a", 0.6)
        x += bw + rng.uniform(30, 76)
    # 云海（平线 1150 起，藏进地块后的世界 580..730）
    sea = s.vgrad("sea", [(0, CLOUD_LIT, 1), (0.35, "#dfc0cf", 1), (1, CLOUD_SHADE, 1)])
    s.rect(0, 1150, 1024, 150, sea)
    s.line(0, 1151, 1024, 1151, "#fdeee8", 2, 0.55)
    # 云顶亮团
    cx = -30.0
    while cx < 1050:
        crx = rng.uniform(34, 74)
        cry = rng.uniform(6, 13)
        cy = 1150 + rng.uniform(3, 22)
        s.ellipse(cx + crx, cy, crx, cry, CLOUD_LIT, rng.uniform(0.5, 0.8))
        s.ellipse(cx + crx, cy + cry * 0.7, crx * 0.9, cry * 0.5, CLOUD_SHADE, 0.35)
        cx += crx * rng.uniform(1.2, 1.9)
    # 云海下渐深（画布底 1300=世界 730，接 Terrain 立面）
    deep = s.vgrad("deep", [(0, CLOUD_SHADE, 0.0), (1, CLOUD_DEEP, 0.8)])
    s.rect(0, 1220, 1024, 80, deep)
    return s


def ladder_strip():
    """独层地标：天梯缆塔 3200x900（透明底）。条带位 (8,270)、region 900 高
    → 条带**居中挂载**：画布 y0=世界 -180，画布 900 高=世界 -180..720。
    塔基画布 840=世界 660（沉进云海线/地形顶后方），塔身升到画布 120
    （世界 -60，接近出画顶），出画斜缆继续向上。地标 tex_x=1600（画布 x），
    含斜缆半宽 ~300：1600 ∈ [1500, 1700] ✓ 防回绕弹切。种子 5052。"""
    rng = random.Random(5052)
    s = Svg(3200, 900)
    cx = 1600.0
    base = 840.0
    TOWER = BODY_DEEP
    # 基座平台（沉入云海）
    s.rect(cx - 52, base - 12, 104, 14, TOWER, 0.9)
    s.rect(cx - 52, base - 12, 104, 2.5, RIM_WARM, 0.8)
    s.ellipse(cx, base, 78, 9, CLOUD_LIT, 0.45)
    # 塔身（收分双柱 + 横撑，y 828 → 120）
    s.poly([(cx - 17, base - 12), (cx - 8, 120), (cx - 3, 120), (cx - 7, base - 12)], TOWER, 0.95)
    s.poly([(cx + 17, base - 12), (cx + 8, 120), (cx + 3, 120), (cx + 7, base - 12)], TOWER, 0.95)
    yy = base - 40
    while yy > 150:
        t = (base - yy) / (base - 120)
        half = 15.0 - 9.0 * t
        s.line(cx - half, yy, cx + half, yy, TOWER, 3.0, 0.9)
        s.line(cx - half, yy, cx + half, yy - 34, TOWER, 1.6, 0.7)
        yy -= 34
    # 顶舱 + 出画斜缆（爬升缆向上出画）
    s.rect(cx - 14, 108, 28, 16, TOWER, 0.95)
    s.rect(cx - 14, 108, 28, 2.5, RIM_WARM, 0.85)
    s.line(cx - 6, 108, cx - 300, -40, "#5a446e", 3, 0.9)
    s.line(cx + 6, 108, cx + 200, -40, "#5a446e", 2, 0.7)
    # 配重块（挂在左缆上）
    s.rect(cx - 180, 340, 26, 12, TOWER, 0.95)
    # 爬升舱（右缆上小舱 + 暖金窗）
    s.rect(cx + 100, 480, 16, 12, TOWER, 0.95)
    s.rect(cx + 103, 483, 10, 4, "#ffc46a", 0.85)
    # 警灯
    glow_dot(s, cx, 104, "#ff4640", r=2.4)
    glow_dot(s, cx - 167, 346, "#ff4640", r=1.8)
    # 环塔云雾（塔基入云的柔读法）
    for ex, ey, rx, ry, op in ((cx - 60, base - 4, 70, 12, 0.5), (cx + 55, base + 4, 60, 10, 0.4),
                               (cx + 10, base - 26, 90, 14, 0.3)):
        s.ellipse(ex, ey, rx, ry, CLOUD_LIT, op)
        s.ellipse(ex, ey + ry * 0.6, rx * 0.85, ry * 0.5, CLOUD_SHADE, 0.3)
    return s


def mid_strip():
    """中景条 2048x520（透明底，tile 2048）：三段各异浮空平台。
    世界 y：画布 520=世界 700；平台板画布 360..480（世界 540..660，
    贴地块顶后方）。剪影 BODY + 顶缘霞光描边 + 暖金窗。两侧 40px 留空。
    种子 5053。"""
    rng = random.Random(5053)
    s = Svg(2048, 520)

    # ---- A 段：作业平台（龙门架塔 + 板下机库）----
    plx, ply = 58.0, 380.0
    s.rect(plx, ply, 244, 15, BODY, 0.94)
    s.line(plx, ply, plx + 244, ply, RIM_WARM, 2.2, 0.85)
    s.rect(plx + 30, ply - 78, 34, 78, BODY, 0.94)
    s.line(plx + 30, ply - 78, plx + 64, ply - 78, RIM_WARM, 1.8, 0.8)
    s.line(plx + 47, ply - 78, plx + 47, ply - 102, BODY, 2.2, 0.94)
    s.poly([(plx + 118, ply), (plx + 176, ply), (plx + 170, ply - 44), (plx + 124, ply - 44)],
           BODY, 0.94)
    s.line(plx + 124, ply - 44, plx + 170, ply - 44, RIM_WARM, 1.6, 0.75)
    s.rect(plx + 88, ply + 15, 56, 22, BODY_DEEP, 0.94)          # 板下机库
    for wx, wy in ((plx + 40, ply - 62), (plx + 52, ply - 62), (plx + 40, ply - 44),
                   (plx + 134, ply - 30), (plx + 152, ply - 30)):
        s.rect(wx, wy, 6, 7, "#ffc46a", 0.85)                    # 暖金窗
    glow_dot(s, plx + 47, ply - 106, "#ff4640", r=2.4)
    # 平台底鳍 + 云絮
    s.poly([(plx + 190, ply + 15), (plx + 214, ply + 15), (plx + 206, ply + 30),
            (plx + 196, ply + 30)], BODY_DEEP, 0.9)
    s.ellipse(plx + 120, ply + 44, 130, 16, CLOUD_LIT, 0.5)
    s.ellipse(plx + 120, ply + 52, 110, 10, CLOUD_SHADE, 0.3)

    # ---- B 段：停泊平台（桅杆 + 碟形天线 + 系缆）----
    prx, pry = 880.0, 420.0
    s.rect(prx, pry, 226, 13, BODY, 0.94)
    s.line(prx, pry, prx + 226, pry, RIM_WARM, 2.2, 0.85)
    s.rect(prx + 148, pry - 56, 30, 56, BODY, 0.94)
    s.line(prx + 163, pry - 56, prx + 163, pry - 86, BODY, 2, 0.94)
    s.ellipse(prx + 163, pry - 94, 13, 9, BODY_DEEP, 0.94)
    for wx in (prx + 24, prx + 48, prx + 72, prx + 96):
        s.rect(wx, pry - 26, 6, 7, "#ffc46a", 0.8)
    glow_dot(s, prx + 163, pry - 100, "#ff4640", r=2.2)
    # 系留缆（斜下出段的货舱）
    s.line(prx + 30, pry + 6, prx - 60, pry + 90, "#5a446e", 1.8, 0.8)
    s.rect(prx - 78, pry + 88, 34, 18, BODY_DEEP, 0.92)
    s.ellipse(prx + 113, pry + 26, 120, 14, CLOUD_LIT, 0.45)

    # ---- C 段：断桥残段（薄箱梁 + 垂缆 + 尾灯）----
    bx = 1440.0
    s.rect(bx, 400, 300, 13, BODY, 0.94)
    s.line(bx, 400, bx + 300, 400, RIM_WARM, 2.2, 0.85)
    s.rect(bx, 413, 300, 8, BODY_DEEP, 0.94)                     # 箱梁
    for vx in range(int(bx) + 20, int(bx) + 300, 40):            # 腹杆
        s.line(vx, 413, vx + 20, 421, BODY_DARK, 1.6, 0.9)
    # 断口（右端撕裂）
    s.poly([(bx + 282, 400), (bx + 300, 400), (bx + 300, 421), (bx + 288, 421)], "#2a1f3e")
    for cx2 in (bx + 60, bx + 150, bx + 240):                    # 垂缆
        s.line(cx2, 421, cx2 - 6, 470, "#5a446e", 1.4, 0.7)
        s.circle(cx2 - 6, 471, 1.6, "#ffc46a", 0.8)
    glow_dot(s, bx + 20, 403, "#ff4640", r=2.0)
    # 背景云絮（段间留白处，拉开云海纵深）
    for ex, ey, rx, ry, op in ((700, 300, 150, 22, 0.4), (1340, 250, 110, 18, 0.32),
                               (1900, 340, 130, 20, 0.36)):
        s.ellipse(ex, ey, rx, ry, CLOUD_MID, op)
        s.ellipse(ex, ey + ry * 0.6, rx * 0.85, ry * 0.5, CLOUD_SHADE, 0.25)
    # 底部雾
    g = s.vgrad("fog", [(0, "#d8a89f", 0), (1, "#d8a89f", 0.4)])
    s.rect(0, 448, 2048, 72, g)
    return s


def bake_girder(th):
    """桥式·箱梁 320x28（terrain.gd 桥式模式，每块一幅）：band_edge 梁体
    + face_lo 底缘暗线 + 两端块间接缝（桥式模式下 terrain.gd 不再画缝）。"""
    s = Svg(320, 28)
    s.rect(0, 0, 320, 28, th["band_edge"])
    s.rect(0, 25, 320, 3, th["face_lo"])
    for ex in (0.6, 319.4):
        s.line(ex, 0, ex, 28, th["seam"], 2.4, 0.6)
    return s


def bake_brace(th):
    """桥式·剪刀撑 168x84（每块一幅，挂两柱之间梁下）：X 交叉斜撑。"""
    s = Svg(168, 84)
    s.line(2, 2, 166, 82, th["pier"], 3.2, 0.55)
    s.line(166, 2, 2, 82, th["pier"], 3.2, 0.55)
    return s


def bake_column(th, h):
    """桥式·排架柱 48xh（挡位件：terrain.gd 按「海面固定线−柱顶」选挡）。
    **实色细柱**（2026-10-22 二轮修：半透明渐隐柱让海透过来=前后关系读反，
    原图柱子就是不透明的实色剪影）；宽 20（原图细柱比例），底缘微暗即可，
    柱脚入海由前景云沿（env_dawn_sea_front）遮挡，不在柱上烘云团
    （云团烘在会动的柱上=在静止海面上滑动，穿帮）。"""
    s = Svg(48, h)
    pier = th["pier"]
    s.rect(14, 0, 20, h, pier)
    s.rect(14, 0, 5, h, th["face_lo"], 0.6)      # 柱身背光侧
    s.rect(30, 0, 4, h, "#6a5478", 0.35)         # 柱身受光侧微亮
    return s


def bake_sea(th):
    """云海·固定底层 3200x480（GroundStrip：scroll_scale=1 钉死在屏幕上）。
    **按原图重修（2026-10-22 二轮）**：原图云面=平缓浅色薰衣草底 + 椭圆云垫
    （更暗一档的低透明大垫）——不是高对比泡团。整幅调平调浅：平线亮边 +
    三条浅云带 + 椭圆云垫阵列，全部低对比大笔触；左右 60px 留空（wrap 缝
    安全）。种子 5055。"""
    rng = random.Random(5055)
    s = Svg(3200, 480)
    g = s.vgrad("seab", [(0, "#ecd2da", 1), (0.32, "#c9a4bc", 1),
                         (0.66, "#a8849e", 1), (1, "#7a6288", 1)])
    s.rect(0, 0, 3200, 480, g)
    s.line(0, 1.5, 3200, 1.5, "#fdeee8", 3, 0.55)  # 平线亮边（受光云顶）
    # ---- 浅云带（三条平缓横带，低对比）----
    for by, bh, op in ((46, 26, 0.30), (150, 40, 0.24), (300, 56, 0.20)):
        x = 60.0
        while x < 3060:
            rx = rng.uniform(190, 380)
            s.ellipse(x + rx * 0.5, by + rng.uniform(-10, 10), rx, bh,
                      "#f2dde4", op)
            x += rx * rng.uniform(1.2, 1.9)
    # ---- 椭圆云垫阵列（原图签名件：比底色暗一档的大扁垫）----
    for i in range(14):
        rx = rng.uniform(120, 260)
        ry = rx * rng.uniform(0.16, 0.22)
        cx = rng.uniform(140, 3060)
        cy = rng.uniform(120, 430)
        pad = "#8a6c92"
        s.ellipse(cx, cy, rx, ry, pad, rng.uniform(0.22, 0.34))
        s.ellipse(cx, cy - ry * 0.35, rx * 0.86, ry * 0.6, "#dcc2d2", 0.30)
    return s


def bake_sea_front(th):
    """云海·前景云沿 3200x150（SeaFront：画在 Terrain 之后=遮住柱脚，
    scroll_scale=1 静态）。云沿顶缘不规则（云团高低错落），柱子由此
    「没入海面」；底缘 40px 渐隐融进云海底色（同族浅色，接缝不可见）。
    种子 5056。"""
    rng = random.Random(5056)
    s = Svg(3200, 150)
    body = s.vgrad("seaf", [(0, "#d4b8ca", 1), (0.55, "#b892ac", 1),
                            (0.78, "#a8849e", 1), (1.0, "#a8849e", 0.0)])
    # 云沿顶缘：错落云团（先画团，再垫实体，顶缘=团的弧）
    x = 20.0
    while x < 3160:
        rx = rng.uniform(60, 150)
        ry = rng.uniform(20, 42)
        s.ellipse(x + rx * 0.5, 52 + rng.uniform(-14, 16), rx, ry, "#d4b8ca", 1.0)
        x += rx * rng.uniform(0.7, 1.2)
    s.rect(0, 44, 3200, 106, body)
    # 云沿顶受光
    x = 20.0
    while x < 3160:
        rx = rng.uniform(50, 120)
        s.ellipse(x + rx * 0.5, 46 + rng.uniform(-10, 12), rx, 12,
                  "#f0d8de", 0.5)
        x += rx * rng.uniform(0.9, 1.5)
    return s


def deck():
    """栈桥桥面 720x26（脚手架断桥件）：晨光钢板 + 格栅 + 桁架 + 金位标灯。
    行走面=顶缘（霞光 3px + 钢板 7px），桁架收在下 16px。"""
    s = Svg(720, 26)
    s.rect(0, 0, 720, 3, RIM_WARM)             # 顶缘霞光（受晨光）
    s.rect(0, 3, 720, 7, BODY_DARK)            # 钢桥面板
    for gx in range(9, 720, 18):               # 格栅纹
        s.line(gx, 4.5, gx, 9.5, BELLY, 1.6, 0.6)
    s.rect(0, 10, 720, 2.5, "#2a1f3e")         # 前缘口
    for lx in range(60, 720, 120):             # 金位标灯
        s.circle(lx, 11.2, 1.2, "#ffc46a", 0.85)
    for i in range(18):                        # 桁架腹杆
        x0 = i * 40.0
        if i % 2 == 0:
            s.line(x0, 12.5, x0 + 40, 24.5, BELLY, 2.0)
        else:
            s.line(x0, 24.5, x0 + 40, 12.5, BELLY, 2.0)
    s.line(0, 24.5, 720, 24.5, BELLY, 2.0)     # 下弦
    return s


def main():
    os.makedirs(ASSETS, exist_ok=True)
    save(far_strip(), "env_dawn_far.svg", """第五章远景条 1024x1300（视差 0.9，tile 1024）：晨空渐变
#33265a→#8e5578→#d8846e→#f4b071 + 通长细弧天带（当纹理平铺）+ 浮空平台链剪影
+ 云海平线（画布 1150=世界 580）。画布底=世界 730。两侧 24px 留空。种子 5051。""")
    save(ladder_strip(), "env_dawn_ladder.svg", """第五章独层地标：天梯缆塔 3200x900（视差 0.9，tile 3200 同屏一份）。
地标 tex_x=1600（含斜缆半宽 ~300：∈[1500,1700]，防回绕弹切，worlds.md §5）。
条带位 (8,270) 居中挂载：画布 y0=世界 -180；塔基画布 840=世界 660 沉云海。
种子 5052。""")
    save(mid_strip(), "env_dawn_mid.svg", """第五章中景条 2048x520（视差 0.55，tile 2048，透明底）：三段各异
浮空平台（作业/停泊/断桥残段）。画布 520=世界 700。两侧 40px 留空。种子 5053。""")
    th = gv.THEMES["p5_cloud"]
    with open(os.path.join(ASSETS, "env_dawn_ground_top.svg"), "w", encoding="utf-8") as fp:
        text = bgv.bake_band("dawn", th)
        fp.write(text)
        print("env_dawn_ground_top.svg:", len(text) // 1024, "KB")
    for name, tex in (("girder", bake_girder(th)), ("brace", bake_brace(th)),
                      ("column_1", bake_column(th, 110)),
                      ("column_2", bake_column(th, 170)),
                      ("column_3", bake_column(th, 230))):
        save(tex, f"env_dawn_{name}.svg", f"""第五章桥式·{name} 件（terrain.gd 桥式模式：
箱梁/剪刀撑/排架柱各自独立贴图，排架柱三档高度 110/170/230 按
「bridge_sea_y 固定海面线−柱顶」自动选挡，柱底统一钉在海面上）。""")
    old_fill = os.path.join(ASSETS, "env_dawn_ground_fill.svg")
    if os.path.exists(old_fill):
        os.remove(old_fill)
        print("env_dawn_ground_fill.svg removed (bridge parts replace it)")
    save(bake_sea(th), "env_dawn_ground.svg", """第五章云海·固定底层 3200x480（GroundStrip：scroll_scale=1 钉死在屏幕上
=「海面固定」）。按原图重修：平缓浅色薰衣草底+椭圆云垫阵列+浅云带，
低对比大笔触（旧高对比泡团版被打回）。两侧 60px 留空=wrap 缝安全。种子 5055。""")
    save(bake_sea_front(th), "env_dawn_sea_front.svg", """第五章云海·前景云沿 3200x150（SeaFront：场景里画在 Terrain 之后，
遮住柱脚=柱子「没入海面」的前后层级；scroll_scale=1 静态）。顶缘错落
云团+底缘 40px 渐隐融进云海底色。种子 5056。""")
    save(deck(), "env_dawn_deck.svg", """第五章栈桥桥面 720x26（脚手架断桥件）：霞光顶缘+钢板格栅+桁架
+金位标灯。scaffold_5 pier_color=#3a3550。""")
    print("dawn chapter env baked.")


if __name__ == "__main__":
    main()
