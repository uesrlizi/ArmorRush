# -*- coding: utf-8 -*-
"""第八章「镜盐之原」环境烘焙：六件套 + 搁浅采盐联合机地标（独层）。

产物（assets/world_8/）：
  env_salt_far.svg         1024x1300  远景条：黄昏杏金→绯粉天 + 外缘山脉 + 盐晶塔簇 + 霞带
  env_salt_harvester.svg   3200x900   独层地标：搁浅采盐联合机（tile 3200 同屏一份）
  env_salt_mid.svg         2048x520   中景条：泵站+卤水罐+管桥 / 盐田台地+镜洼+堆盐机 / 晾盐架+灯塔桅
  env_salt_ground_top.svg  640x66     表面带=拆地块 v2 @ THEMES.p8_salt（复用 bake_ground_v2.bake_band）
  env_salt_ground_fill.svg 16x256     立面渐变（复用 bake_ground_v2.bake_fill）
  env_salt_ground.svg      256x480    兜底条（=表面带内容 + 深处渐变）
  env_salt_deck.svg        720x26     盐壳栈桥桥面（脚手架件）

画布账：far 底=世界 730（画布 y = 世界 y + 570）；mid 底=世界 700（画布 y = 世界 y − 180；
地形顶 664=mid 画布 484，落地件脚必须 ≥484——v1 算错成 400..470 整排悬空）；
harvester 条带位 (8,270) 居中挂载：画布 y0=世界 −180（画布 y = 世界 y + 180）。
条带里不画太阳（唯一地标规矩；黄昏光交给天顶渐变+霞带承担，同六章教训）。
§6 明度自查：天顶 #b8824e / 中带 #dca878 落中调，最亮的绯粉地平带 #f0b890
沉在远条底部（地形后方）——战斗带（世界 300..660）落在 #dca878 中调区，
白特效与墨青绿敌营都读得出。ThorVG 硬约束：无 filter/pattern/use/text/
transform；无 rect+rotate。色板=提案 v1 §0（proposal_8_salt_mirror）。
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

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "world_8"))

# ---- 章八色板（提案 v1 §0 正本色板；§6 自查：战斗带落中调见头注）----
SKY_STOPS = [(0, "#b8824e", 1), (0.5, "#dca878", 1), (1, "#f0b890", 1)]
FOG_COLOR = "#dca884"   # 暖金霞雾（AerialFog 同值）
TOWER = "#8a6e5e"       # 盐晶塔（前排）
TOWER_BACK = "#9c8270"  # 盐晶塔（雾中后排）
TOWER_HI = "#f0e2c4"    # 塔尖受光棱线
HAR = "#6a4a3c"         # 联合机车体（锈褐）
HAR_MID = "#5a4234"     # 履带座/暗部
HAR_DK = "#4a3628"      # 深锈/接地阴影
HAR_HI = "#7e5c4c"      # 车体受光
MID = "#8a7460"         # 泵站小屋
MID_DK = "#6a5846"      # 管/腿/桁架
PIPE = "#7a6552"        # 出盐管
PINK = "#f2789f"        # 盐田粉（本章信号色：航旗/信号灯）
SALT_WHITE = "#e8dcc0"  # 盐霜/盐堆
MIRROR = "#4aa89a"      # 镜洼青绿
MIRROR_SHINE = "#8ad0c0"  # 镜洼浅光
MIRROR_SKY = "#f6b898"  # 镜面映霞
GLINT = "#ffd8b0"       # 霞光碎条
CLOUD = "#f2d0ac"       # 高天薄云


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


def _crystal(s, rng, cx, base, w, h, color, op=0.85):
    """盐晶塔：棱柱尖塔剪影（4-5 点多面体轮廓）+ 塔尖受光棱线。"""
    s.poly([(cx - w / 2, base), (cx - w * 0.2, base - h * 0.7),
            (cx, base - h), (cx + w * 0.25, base - h * 0.6),
            (cx + w / 2, base)], color, op)
    s.line(cx, base - h, cx + w * 0.12, base - h * 0.45, TOWER_HI, 1.6, 0.6)
    if rng.random() < 0.4:  # 副晶（塔肩小尖）
        sx = cx + w * rng.uniform(0.3, 0.45)
        s.poly([(sx - 6, base), (sx, base - h * 0.35), (sx + 7, base)], color, op * 0.9)


def _range(s, base_y, terms, color, op, step=8):
    """周期山脊剪影（tile 1024 无缝）：顶线 y(x)=base_y−Σ amp·sin(2πkx/1024+φ)，
    k 取整数=两端同高，平铺接缝零错位。"""
    import math
    pts = [(0, 1300)]
    for x in range(0, 1025, step):
        y = base_y - sum(a * math.sin(2 * math.pi * k * x / 1024.0 + ph) for a, k, ph in terms)
        pts.append((x, y))
    pts.append((1024, 1300))
    s.poly(pts, color, op)


def far_strip():
    """远景条 1024x1300：黄昏天（杏金→绯粉）+ 高天薄云 + 霞带 + 盐原外缘山脉
    （后排雾山 + 前排平顶盐崖）+ 盐晶塔两簇 + 稀疏后排孤晶 + 蜃气横掠 + 底部雾带。
    画布 y = 世界 y + 570（地形顶 664 = 画布 1234）：雾山顶 ~画布 860..1000
    （世界 290..430）、盐崖顶 ~1010..1090、晶簇最高 ~画布 830（世界 260）——
    v2（2026-11-06 用户报「背景空」）：v1 只有细晶尖且大半埋在地形与底雾里，
    体量对齐前七章（峡壁/楼群占画面 40~70% 高）。种子 9091。"""
    import math
    rng = random.Random(9091)
    s = Svg(1024, 1300)
    s.rect(0, 0, 1024, 1300, s.vgrad("sky", SKY_STOPS))
    # 高天薄云横条（三条，低对比）
    for cy2, rx2, op in ((96, 200, 0.2), (150, 260, 0.15), (220, 180, 0.12)):
        s.ellipse(rng.uniform(260, 760), cy2, rx2, 9, CLOUD, op)
    # ---- 霞带（地平热气光，不画太阳盘）----
    s.glow_ellipse(512, 1180, 430, 46, "#f6c8a0", 0.4)
    s.glow_ellipse(330, 1164, 250, 26, "#f6b898", 0.26)
    # ---- 后排雾山（盐原外缘山脉，淡、宽、连绵）----
    _range(s, 930, ((60, 1, 0.6), (38, 3, 2.1), (16, 7, 4.0), (9, 13, 1.1)), "#b0866a", 0.42,
           step=32)  # 粗步长=折线棱面（山不是果冻）
    # 山脊盐雪棱（顶线受光，细）
    for x in range(64, 1000, 96):
        y = 930 - sum(a * math.sin(2 * math.pi * k * x / 1024.0 + ph)
                      for a, k, ph in ((60, 1, 0.6), (38, 3, 2.1), (16, 7, 4.0), (9, 13, 1.1)))
        s.line(x - 14, y + 6, x + 10, y + 1, TOWER_HI, 1.4, 0.35)
    # ---- 前排平顶盐崖（地层横纹，比雾山实）----
    _range(s, 1060, ((26, 2, 1.3), (14, 5, 0.2), (6, 11, 2.7)), "#9a7a64", 0.62, step=24)
    for yy, op in ((1130, 0.3), (1165, 0.22), (1200, 0.16)):
        s.rect(0, yy, 1024, 3, "#e8d2b0", op)    # 盐层横纹（通长=平铺安全；须低于崖顶最低处 ~1106）
    # ---- 盐晶塔两簇（成簇高耸=远景主体块；脚落画布 1250 藏地形后）----
    for cx0, n, hmax in ((250.0, 5, 420.0), (730.0, 4, 360.0)):
        for i in range(n):
            ox = (i - (n - 1) / 2) * rng.uniform(34, 48)
            h = hmax * (1.0 - abs(i - (n - 1) / 2) * rng.uniform(0.16, 0.24))
            _crystal(s, rng, cx0 + ox, 1250, rng.uniform(60, 96), h, TOWER, 0.86)
        glow_dot(s, cx0, 1250 - hmax - 8, PINK, r=2.0, halos=((5, 0.32), (9, 0.12)))
    # 后排孤晶（雾中，稀）
    for tx in (90.0, 480.0, 560.0, 930.0):
        _crystal(s, rng, tx, 1250, rng.uniform(36, 52), rng.uniform(170, 250),
                 TOWER_BACK, 0.5)
    # 蜃气横掠（暖亮细线）
    for _ in range(10):
        lx, ly = rng.uniform(80, 980), rng.uniform(180, 420)
        ln = rng.uniform(40, 110)
        s.line(lx, ly, lx - ln, ly + ln * 0.04, GLINT, 1.6, rng.uniform(0.14, 0.3))
    # 底部霞雾（只压塔脚一条，不再洗掉主体）
    fog = s.vgrad("fog", [(0, FOG_COLOR, 0.0), (0.6, FOG_COLOR, 0.36), (1, FOG_COLOR, 0.0)])
    s.rect(0, 1170, 1024, 100, fog)
    return s


def harvester_strip():
    """独层地标：搁浅采盐联合机 3200x900（透明底）。条带位 (8,270)、region 900
    → 居中挂载：画布 y0=世界 −180，画布 y = 世界 y + 180。整机跨画布
    x 1260..1965（半宽 365：tex_x=1600 ∈ [1565,1835] ✓ 防回绕弹切，worlds.md §5）。
    巨型斗轮沉进盐层（轮底画布 862=世界 682，地形会盖住下半）——「搁浅锈在
    原地还在开机」：驾驶楼亮窗+信号粉灯+轮鼓还转。种子 9092。"""
    import math
    rng = random.Random(9092)
    s = Svg(3200, 900)
    # 接地阴影（先画）
    s.ellipse(1600, 866, 350, 10, HAR_DK, 0.5)
    # ---- 履带座 + 承重轮（暗带）----
    s.rect(1300, 836, 600, 22, HAR_MID, 0.95)
    for wx in (1330, 1410, 1490, 1770, 1850):
        s.circle(wx, 846, 13, HAR_DK, 0.95)
        s.circle(wx, 846, 5, HAR_MID, 0.95)
    # ---- 巨型斗轮（左端，下半沉进盐层）----
    wcx, wcy, wr = 1360.0, 756.0, 100.0
    s.circle(wcx, wcy, wr, HAR, 0.95)
    s.circle(wcx, wcy, wr - 12, HAR_MID, 0.95)
    s.circle(wcx, wcy, 26, HAR_DK, 0.95)
    s.circle(wcx, wcy, 10, HAR, 0.9)
    for i in range(6):  # 辐条
        ang = i * math.pi / 3.0
        s.line(wcx + 12 * math.cos(ang), wcy + 12 * math.sin(ang),
               wcx + (wr - 14) * math.cos(ang), wcy + (wr - 14) * math.sin(ang),
               HAR_DK, 4, 0.9)
    for i in range(12):  # 轮缘斗齿（采盐斗）
        ang = i * math.pi / 6.0
        bx = wcx + (wr + 6) * math.cos(ang)
        by = wcy + (wr + 6) * math.sin(ang)
        s.rect(bx - 4, by - 4, 9, 9, HAR_MID, 0.95)
    # ---- 车体（低宽联合机平台）----
    s.rect(1430, 700, 470, 116, HAR, 0.95)
    s.rect(1430, 700, 470, 7, HAR_HI, 0.8)
    s.rect(1430, 806, 470, 10, HAR_DK, 0.9)
    for vx in (1520, 1620, 1760, 1840):  # 板缝
        s.line(vx, 707, vx, 806, HAR_DK, 2.2, 0.5)
    # 侧舷盐霜（车体下缘盐渍，本章信号白）
    for fx2 in (1450, 1550, 1700, 1850):
        s.ellipse(fx2, 812, rng.uniform(18, 30), 5, SALT_WHITE, 0.5)
    # 锈流（竖向）
    for rx2 in (1470, 1660, 1800):
        s.line(rx2, 706, rx2 + 4, 804, HAR_DK, 3, 0.35)
    # ---- 驾驶楼（亮窗=还在开机）----
    s.rect(1560, 622, 96, 78, HAR, 0.95)
    s.rect(1560, 622, 96, 6, HAR_HI, 0.85)
    s.rect(1576, 640, 40, 26, "#f0d0a8", 0.85)          # 亮窗（暖光）
    s.line(1576, 653, 1616, 653, HAR_MID, 2, 0.9)
    s.rect(1630, 644, 14, 20, "#2e2620", 0.9)           # 观察缝
    glow_dot(s, 1608, 614, PINK, r=2.6, halos=((6, 0.4), (11, 0.15)))  # 楼顶信号灯
    # ---- 输送臂（挑向右上，桁架）+ 臂端卸料斗 ----
    s.line(1830, 716, 1958, 560, HAR, 7, 0.95)
    s.line(1846, 728, 1952, 590, HAR, 3.4, 0.95)
    for i in range(4):  # 桁架腹杆
        t0 = 0.16 + i * 0.2
        ax = 1830 + (1958 - 1830) * t0
        ay = 716 + (560 - 716) * t0
        s.line(ax, ay, ax - 16, ay + 26, HAR_MID, 2.2, 0.9)
    s.rect(1930, 540, 36, 26, HAR, 0.95)                # 卸料斗
    s.rect(1930, 540, 36, 4, HAR_HI, 0.8)
    glow_dot(s, 1948, 534, PINK, r=2.0, halos=((5, 0.35), (9, 0.13)))
    # ---- 舷侧绞盘 + 缆线（打捞/采盐缆）----
    s.circle(1740, 760, 15, HAR_DK, 0.95)
    s.circle(1740, 760, 7, HAR, 0.9)
    s.line(1740, 775, 1836, 812, HAR_DK, 1.6, 0.7)
    # ---- 盐堆靠 hull（采出的盐）----
    s.poly([(1440, 836), (1490, 800), (1540, 836)], SALT_WHITE, 0.9)
    s.poly([(1860, 836), (1900, 810), (1940, 836)], SALT_WHITE, 0.8)
    # 船位旗杆（艉部，信号粉旗=还在运作）
    s.line(1880, 700, 1880, 640, MID_DK, 2.4, 0.95)
    s.poly([(1880, 642), (1906, 650), (1880, 658)], PINK, 0.9)
    return s


def mid_strip():
    """中景条 2048x520（透明底，tile 2048）：三段各异——泵站+卤水罐+出盐管桥 /
    盐田台地（镜洼坐台面）+ 堆盐机长臂+盐山 / 晾盐架+灯塔桅+盐堆。
    画布 y=世界 y−180：地形顶 664 = 画布 484——**所有落地件脚一律落画布 492..500**
    （世界 672..680，藏进地块顶后方，同六章 486..500 账）。v2（2026-11-06 用户报
    「中景悬空」）：v1 脚在 400..470=世界 580..650，比地面高 14..84px 整排浮空，
    且最高件仅 ~160px；v2 最高件顶 ~画布 210（世界 390），对齐六章体量。
    两侧 40px 留空。种子 9093。"""
    rng = random.Random(9093)
    s = Svg(2048, 520)
    FOOT = 496.0   # 落地脚线（画布；世界 676）

    def pond(cx_, w, cy_):
        """镜洼（压扁光纹条画法=ch7 浪纹 v2 同语言，ry≤5 禁睡莲读法）：
        青绿浅水面 + 映霞反光条 + 受光亮线。cy_=所坐台面 y（水面嵌在台面里）。"""
        ry = rng.uniform(3.2, 5.0)
        cy_ = cy_ + ry * 0.6
        s.ellipse(cx_, cy_, w / 2, ry, MIRROR, 0.85)
        s.ellipse(cx_, cy_ - ry * 0.3, w / 2 - 10, ry * 0.5, MIRROR_SKY, 0.6)
        s.line(cx_ - w / 2 + 8, cy_ + ry * 0.4, cx_ + w / 2 - 6, cy_ + ry * 0.4,
               GLINT, 1.3, 0.6)
        s.line(cx_ - w / 2 + 14, cy_ - ry * 0.4, cx_ + w / 2 - 18, cy_ - ry * 0.4,
               MIRROR_SHINE, 1.0, 0.5)

    def terrace(x0, x1, top):
        """盐田台地：梯形土台（侧坡落脚线）+ 盐壳顶缘亮线 + 立面层理。"""
        s.poly([(x0, FOOT + 4), (x0 + 18, top), (x1 - 18, top), (x1, FOOT + 4)],
               "#988670", 0.95)
        s.line(x0 + 18, top + 1.2, x1 - 18, top + 1.2, "#dccfae", 2.4, 0.75)
        for yy in (top + 20, top + 38):
            if yy < FOOT - 4:
                s.line(x0 + 26, yy, x1 - 26, yy, "#7e6e5a", 1.4, 0.45)

    # ---- A 段：泵站小屋 + 卤水罐 + 出盐管桥（左）----
    ax, at = 100.0, 300.0
    s.rect(ax, at, 132, FOOT - at, MID, 0.95)
    s.poly([(ax - 8, at), (ax + 140, at), (ax + 66, at - 24)], "#7a6552", 0.95)
    s.rect(ax + 26, FOOT - 64, 24, 64, "#5f4e3e", 0.95)      # 门（落地）
    s.rect(ax + 78, at + 22, 18, 14, "#f0d0a8", 0.75)        # 亮窗
    s.rect(ax + 78, at + 70, 18, 14, "#f0d0a8", 0.55)
    s.line(ax + 112, at - 6, ax + 112, at - 40, MID_DK, 2, 0.95)   # 旗杆
    s.poly([(ax + 112, at - 38), (ax + 136, at - 31), (ax + 112, at - 24)], PINK, 0.9)
    # 卤水罐（高架储罐：罐体+四腿+爬梯）
    tx0, tw, tt, tb = 290.0, 92.0, 214.0, 330.0
    for lx in (tx0 + 6, tx0 + tw - 6):
        s.line(lx, tb, lx - 10 if lx < tx0 + tw / 2 else lx + 10, FOOT, MID_DK, 3.4, 0.95)
    s.line(tx0 + 2, 410, tx0 + tw - 2, 410, MID_DK, 2, 0.9)  # 腿间横撑
    s.line(tx0 - 2, 440, tx0 + tw + 2, 360, MID_DK, 1.6, 0.85)
    s.rect(tx0, tt, tw, tb - tt, "#7e6a56", 0.95)
    s.ellipse(tx0 + tw / 2, tt, tw / 2, 8, "#9a836c", 0.95)  # 罐顶
    s.rect(tx0 + 10, tt + 40, tw - 20, 5, MID_DK, 0.6)       # 罐箍
    s.rect(tx0 + 10, tt + 80, tw - 20, 5, MID_DK, 0.6)
    s.line(tx0 + tw - 14, tt, tx0 + tw - 14, FOOT, MID_DK, 1.4, 0.8)  # 爬梯
    glow_dot(s, tx0 + tw / 2, tt - 10, PINK, r=2.0, halos=((5, 0.35), (9, 0.13)))
    # 出盐管桥：小屋→罐→泵座，排架腿全落脚线
    for py2 in (342, 354):
        s.line(ax + 132, py2, 600, py2, PIPE, 4, 0.95)
    for lx in (470.0, 560.0):
        s.line(lx - 12, FOOT, lx, 356, MID_DK, 2.6, 0.95)
        s.line(lx + 12, FOOT, lx, 356, MID_DK, 2.6, 0.95)
        s.line(lx - 8, 430, lx + 8, 430, MID_DK, 1.8, 0.9)
    s.rect(588, 330, 30, FOOT - 330, MID_DK, 0.95)           # 泵座立管（落地）
    s.rect(582, 324, 42, 10, PIPE, 0.95)
    # ---- B 段：盐田台地（镜洼坐台面）+ 堆盐机 + 盐山（中）----
    terrace(700.0, 980.0, 440.0)
    pond(840.0, 180.0, 440.0)
    s.poly([(730, 440), (752, 426), (774, 440)], SALT_WHITE, 0.95)   # 台上小盐堆
    # 堆盐机：履带座落地 + 立柱 + 斜挑长臂 + 拉索，臂端卸料落到盐山顶
    s.rect(1000, 470, 90, FOOT - 470 + 2, HAR_MID, 0.95)
    for wx in (1014, 1045, 1076):
        s.circle(wx, FOOT - 4, 8, HAR_DK, 0.95)
    s.rect(1030, 300, 16, 172, MID_DK, 0.95)                 # 立柱
    s.line(1036, 452, 1290, 226, PIPE, 8, 0.95)              # 输送臂（上弦）
    s.line(1046, 462, 1290, 244, PIPE, 3.4, 0.95)            # 下弦
    for i in range(6):                                       # 桁架腹杆
        t0 = 0.1 + i * 0.15
        bx = 1036 + (1290 - 1036) * t0
        by = 452 + (226 - 452) * t0
        s.line(bx, by, bx + 14, by + 14, MID_DK, 2.0, 0.9)
    s.line(1038, 300, 1180, 352, MID_DK, 1.4, 0.8)           # 拉索
    s.rect(1280, 218, 26, 30, MID, 0.95)                     # 臂端卸料头
    glow_dot(s, 1293, 212, PINK, r=2.0, halos=((5, 0.35), (9, 0.13)))
    s.line(1293, 250, 1296, 330, SALT_WHITE, 3, 0.45)        # 落盐流
    s.poly([(1150, FOOT + 4), (1294, 330), (1440, FOOT + 4)], SALT_WHITE, 0.95)  # 盐山
    s.poly([(1294, 330), (1440, FOOT + 4), (1340, FOOT + 4)], "#cdbf9e", 0.7)    # 背光面
    # ---- C 段：晾盐架 + 灯塔桅 + 盐堆 + 旗（右）----
    cx2 = 1620.0
    for lx in (cx2 - 76, cx2, cx2 + 76):                     # A 字架 ×3（落地）
        s.line(lx - 20, FOOT, lx, 372, MID_DK, 2.8, 0.95)
        s.line(lx + 20, FOOT, lx, 372, MID_DK, 2.8, 0.95)
        s.line(lx - 12, 440, lx + 12, 440, MID_DK, 1.6, 0.9)
    s.line(cx2 - 92, 372, cx2 + 92, 372, PIPE, 5, 0.95)      # 横管
    for px in range(int(cx2) - 66, int(cx2) + 76, 26):       # 吊晒盐盘
        s.line(px, 374, px, 392, MID_DK, 1.6, 0.9)
        s.rect(px - 10, 392, 20, 6, SALT_WHITE, 0.85)
    # 灯塔桅（格构，信号粉顶灯=竖向主体块）
    mx = 1760.0
    s.line(mx - 22, FOOT, mx - 4, 212, MID_DK, 3, 0.95)
    s.line(mx + 22, FOOT, mx + 4, 212, MID_DK, 3, 0.95)
    for yy in range(240, int(FOOT), 34):
        half = 4 + 18 * (yy - 212) / (FOOT - 212)
        s.line(mx - half, yy, mx + half, yy + 17, MID_DK, 1.4, 0.85)
        s.line(mx + half, yy, mx - half, yy + 17, MID_DK, 1.4, 0.85)
    s.rect(mx - 12, 200, 24, 14, MID, 0.95)
    glow_dot(s, mx, 194, PINK, r=2.6, halos=((6, 0.4), (11, 0.15)))
    s.poly([(1820, FOOT + 4), (1878, 424), (1936, FOOT + 4)], SALT_WHITE, 0.95)  # 大盐堆
    s.line(1972, FOOT, 1972, 390, MID_DK, 2.4, 0.95)          # 旗杆（落地）
    s.poly([(1972, 392), (1996, 400), (1972, 408)], PINK, 0.9)
    # 底部霞雾（融进地形后方）
    g = s.vgrad("fog", [(0, FOG_COLOR, 0), (1, FOG_COLOR, 0.3)])
    s.rect(0, 444, 2048, 76, g)
    # 盐尘点（稀）
    for _ in range(12):
        s.circle(rng.uniform(60, 1990), rng.uniform(200, 420), rng.uniform(1, 2),
                 "#f8e8cc", rng.uniform(0.15, 0.4))
    return s


def ground_fallback():
    """兜底条 256x480（GroundStrip 默认 tile 256）：= 表面带内容（单变体）
    + 深处盐层渐变。种子 3111（与表面带 A 半幅同花）。"""
    th = gv.THEMES["p8_salt"]
    s = Svg(256, 480)
    s.rect(0, 2.5, 256, 53.5, th["band"])
    gv.band_detail(s, th, 0.0, 0.0, 256.0, 56.0, 1.0, random.Random(3111))
    s.rect(0, 53.6, 256, 2.4, th["band_edge"])
    s.rect(0, 0, 256, 2.8, th["top_line"])
    s.rect(0, 56, 256, 10, th["face_hi"])
    ao = s.vgrad("fbao", [(0, th["ao"], 0.8), (1, th["ao"], 0.0)])
    s.rect(0, 56, 256, 10, ao)
    deep = s.vgrad("fbdeep", [(0, th["face_lo"], 1), (0.5, "#4a3e2e", 1), (1, "#3a3024", 1)])
    s.rect(0, 66, 256, 414, deep)
    for ty, op in ((120, 0.3), (210, 0.22), (310, 0.15), (410, 0.1)):  # 深层层理
        s.line(0, ty, 256, ty, "#2e2620", 2, op)
    s.rect(0, 66, 3, 414, th["seam"], 0.5)
    s.rect(253, 66, 3, 414, th["seam"], 0.5)
    return s


def deck():
    """盐壳栈桥桥面 720x26（脚手架件）：盐壳亮缘 + 旧钢板面（板缝/锈箍）
    + 盐霜斑 + 桁架。行走面=顶缘（盐壳白 3px + 桥面 7px），桁架收在下 16px。"""
    s = Svg(720, 26)
    s.rect(0, 0, 720, 3, "#e8d8bc")             # 顶缘盐壳受光
    s.rect(0, 3, 720, 7, "#8a7a62")             # 旧钢板面
    for gx in range(12, 720, 60):               # 板缝
        s.line(gx, 3.5, gx, 9.5, "#6a5c48", 1.4, 0.6)
    for fx2 in (90, 300, 520, 660):             # 盐霜斑
        s.ellipse(fx2, 5.5, 14, 2.2, SALT_WHITE, 0.6)
    s.rect(0, 10, 720, 2.5, "#4a3e2e")          # 前缘口
    for lx in range(60, 720, 120):              # 信号粉位标灯
        s.circle(lx, 11.2, 1.3, PINK, 0.85)
    for i in range(18):                         # 桁架腹杆
        x0 = i * 40.0
        if i % 2 == 0:
            s.line(x0, 12.5, x0 + 40, 24.5, "#5c4f3c", 2.0)
        else:
            s.line(x0, 24.5, x0 + 40, 12.5, "#5c4f3c", 2.0)
    s.line(0, 24.5, 720, 24.5, "#5c4f3c", 2.0)  # 下弦
    return s


def main():
    os.makedirs(ASSETS, exist_ok=True)
    save(far_strip(), "env_salt_far.svg", """第八章远景条 1024x1300（视差 0.9，tile 1024）：黄昏天
#b8824e→#dca878→#f0b890（杏金→绯粉，战斗带落中调）+ 高天薄云 + 霞带（画布 1180=世界 610）
+ 盐原外缘山脉（后排雾山+前排平顶盐崖，k 整数正弦=无缝）+ 盐晶塔两簇 + 孤晶
+ 蜃气横掠 + 底部霞雾。画布底=世界 730（地形顶 664=画布 1234）。v2 体量版。
不画太阳（唯一地标规矩）。种子 9091。""")
    save(harvester_strip(), "env_salt_harvester.svg", """第八章独层地标：搁浅采盐联合机 3200x900（视差 0.9，tile 3200 同屏一份）。
地标 tex_x=1600（整机半宽 365：∈[1565,1835]，防回绕弹切，worlds.md §5）。
条带位 (8,270) 居中挂载：画布 y0=世界 -180；轮底画布 862=世界 682
（沉进盐层，地形盖住下半）。种子 9092。""")
    save(mid_strip(), "env_salt_mid.svg", """第八章中景条 2048x520（视差 0.55，tile 2048，透明底）：三段各异
（泵站+卤水罐+出盐管桥/盐田台地+镜洼+堆盐机+盐山/晾盐架+灯塔桅+盐堆）+ 信号粉旗。
画布 520=世界 700，落地脚线画布 496（世界 676，藏地块顶 664 后方）。两侧 40px 留空。镜洼=压扁光纹条画法（ry≤5，ch7 浪纹 v2 同语言）。
种子 9093。""")
    th = gv.THEMES["p8_salt"]
    with open(os.path.join(ASSETS, "env_salt_ground_top.svg"), "w", encoding="utf-8") as fp:
        text = bgv.bake_band("salt", th)
        fp.write(text)
        print("env_salt_ground_top.svg:", len(text) // 1024, "KB")
    with open(os.path.join(ASSETS, "env_salt_ground_fill.svg"), "w", encoding="utf-8") as fp:
        text = bgv.bake_fill(th)
        fp.write(text)
        print("env_salt_ground_fill.svg:", len(text) // 1024, "KB")
    save(ground_fallback(), "env_salt_ground.svg", """第八章兜底条 256x480（GroundStrip 默认 tile 256）：表面带内容（单变体）
+ 深处盐层渐变。种子 3111。""")
    save(deck(), "env_salt_deck.svg", """第八章盐壳栈桥桥面 720x26（脚手架件）：盐壳亮缘+旧钢板面+盐霜斑
+桁架+信号粉位标灯。scaffold_8 pier_color=#6e5f4a。""")
    print("salt mirror chapter env baked.")


if __name__ == "__main__":
    main()
