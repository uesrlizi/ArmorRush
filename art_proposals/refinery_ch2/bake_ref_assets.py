# -*- coding: utf-8 -*-
"""方案二「精炼所工业带」游戏素材烘焙（第二章换皮）：把提案拆成游戏用的 SVG。

产物直接写入 2d-ac/assets/：
  env_ref_far.svg           1024x1300 远景条（天空渐变+烟囱群+冷却塔，HillsStrip 换装）
  env_ref_mid.svg           1024x520  中景条（透明底塔群/管廊/火炬，MidStrip 换装）
  env_ref_ground.svg        256x480   兜底地面条（GroundStrip 换装）
  env_ref_ground_top.svg    256x56    地块表面带（terrain.gd 每块平铺，256 相位对齐）
  env_ref_ground_fill.svg   16x256    地块填充竖向渐变（拉伸用）
  env_ref_deck.svg          720x26    栈桥桥面（scaffold_ch2 换装）
  enemy_ref_walker_body.svg 56x52     步行者换皮：履带炮车（骨架锚点与锈雨版逐点对齐）
  enemy_ref_walker_arm.svg  48x28     步行者枪臂换皮
  enemy_ref_drone.svg       38x42     无人机换皮：涵道巡检单元
  enemy_ref_drone_arm.svg   32x16     无人机枪臂换皮
  enemy_ref_shield_body.svg 56x52     盾卫换皮：破门盾车
  enemy_ref_elite_body.svg  60x80     精英换皮：双管臼炮运载车
  boss_ref_body.svg         300x180   BOSS 换皮：「钢嵴」浮空炮舰（整体重设计）
  boss_ref_gun.svg          110x32    BOSS 机枪臂换皮
  boss_ref_rotor.svg        84x16     BOSS 尾部涡轮 blade bar（侧视刃边）
  boss_ref_tailrotor.svg    56x56     BOSS 尾部环护风扇（整周旋转）

骨架对齐账（换皮铁律：美术重画、锚点不动，tscn 才不用逐个重调）：
  步行者：眼 (15.5,18.3)；肩 joint (16,24)；地面 y=50
  无人机：眼 (12,14.4)；枪口=臂画布 (13,11)
  盾卫：  竝 (23.5,18.3)；肩 joint (24,24)
  精英：  眼 (19,26.5)；两仓口画布 (38.5,1.5)/(49.5,1.5)（=pivot±5.5）
  BOSS：  眼条带 y60..66 含 (55,63)；导弹仓口画布 x 83/105/167/189 @ y26；
          枪口=臂画布 (2,~4)（flip_v 后贴下颌）；尾风扇心 (272,62)；涡轮 bar 心=新节点位

ThorVG 硬约束与提案一致：无 filter/pattern/use/text/transform（禁 rect+rotate）；
横向平铺的纹理两侧留空或纯色延伸，保证接缝不可见。单位件坐标全部手排。
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
from generate_proposals import Svg, f  # noqa: E402

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "world_2"))

# ---- 环境色板（提案二「精炼所工业带」） ----
SKY_STOPS = [(0, "#a9bcb2", 1), (0.42, "#9db1a6", 1), (0.68, "#8ba398", 1), (1.0, "#6f857b", 1)]
FAR_A = "#6f8880"   # 远景第一层（烟囱细杆，最浅）
FAR_B = "#5a736c"   # 远景第二层（块状厂房）
HAZE = "#93a89e"    # 雾带
MID = "#38504a"     # 中景塔体
MID_DARK = "#2f443f"
MID_LINE = "#2a3c37"
TRUSS = "#2c403a"
GROUND_TOP = "#39453f"
GROUND_EDGE = "#55695f"
GROUND_DEEP = "#222b28"
SEAM = "#242e29"
FILL_STOPS = [(0, "#3a4640", 1), (0.4, "#2e3a34", 1), (1, "#1f2823", 1)]
RED = "#ff4640"
YELLOW = "#d8a021"
FLAME = "#ff8c3a"
FLAME2 = "#ffc46a"
STEAM = "#c5d2ca"

# ---- 机甲色板（敌营阵营语言：近黑剪影 + 信号色；随章转冷绿灰） ----
LIGHT = "#4d5348"   # 受光顶面
BODY = "#303429"    # 主装甲
BELLY = "#252820"   # 腹面/暗部
GAP = "#161811"     # 缝隙/最深结构


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


# ============================================================
# 环境条带
# ============================================================
def far_strip():
    """远景条 1024x1300：天空渐变 + 两层烟囱/厂房剪影 + 冷却塔地标。
    比例账：烟囱杆 w16..36 h240..430（细高 1:12..1:14，工业烟囱真实细比）；
    厂房块 w40..90 h180..380；冷却塔全宽 ~120 全高 300（双曲收腰 hw 62→44→56）。
    两侧 24px 留空 = 平铺接缝纯天空。世界 y：画布底 1300=世界 730（低于全部地形顶）。"""
    rng = random.Random(2021)
    s = Svg(1024, 1300)
    s.rect(0, 0, 1024, 1300, s.vgrad("sky", SKY_STOPS))

    BASE = 1300.0
    # 第一层：细烟囱杆群（带顶帽/副管）
    x = 24.0
    while x < 950 - 40:
        w = rng.uniform(16, 36)
        h = rng.uniform(240, 430)
        top = BASE - h
        s.rect(x, top, w, h, FAR_A, 0.5)
        if rng.random() < 0.45:  # 顶帽
            s.rect(x - 3, top - 5, w + 6, 5, FAR_A, 0.5)
        if rng.random() < 0.3:  # 副管（贴杆细线）
            s.rect(x + w + 2, top + h * 0.3, 3, h * 0.55, FAR_A, 0.45)
        x += w + rng.uniform(26, 62)
    # 第二层：块状厂房（平顶/锯齿顶/圆顶罐）
    x = 24.0
    while x < 940 - 90:
        w = rng.uniform(40, 90)
        h = rng.uniform(180, 380)
        top = BASE - h
        kind = rng.random()
        if kind < 0.25:  # 锯齿顶厂房
            n = rng.randint(2, 4)
            seg = w / n
            pts_ = [(x, BASE), (x, top)]
            for i in range(n):
                pts_.append((x + seg * i + seg * 0.55, top))
                pts_.append((x + seg * (i + 1), top + seg * 0.35))
            pts_.append((x + w, BASE))
            s.poly(pts_, FAR_B, 0.75)
        elif kind < 0.5:  # 圆顶储罐
            th = h * 0.45
            s.rect(x, BASE - th, w, th, FAR_B, 0.75)
            s.ellipse(x + w / 2, BASE - th, w / 2, 10, FAR_B, 0.75)
        else:  # 平顶厂房
            s.rect(x, top, w, h, FAR_B, 0.75)
            if rng.random() < 0.4:
                s.rect(x + w * 0.2, top - 12, 5, 12, FAR_B, 0.75)
        x += w + rng.uniform(34, 76)

    # 地标：冷却塔（双曲收腰剪影，hw 底 62 → 腰 44 → 顶 56）
    cx = 520.0
    right, left = [], []
    for i in range(13):
        t = i / 12.0
        yy = BASE - 300 * t
        hw = 62 + (44 - 62) * t + 12 * (t * t)
        right.append((cx + hw, yy))
        left.append((cx - hw, yy))
    s.poly(right + left[::-1], FAR_B, 0.85)
    s.glow_ellipse(cx, BASE - 306, 70, 18, STEAM, 0.10)  # 塔顶蒸汽

    # 管廊桥（细横线 + 立柱）
    s.rect(40, BASE - 190, 380, 5, FAR_B, 0.55)
    for px in (90, 200, 310, 405):
        s.rect(px - 3, BASE - 185, 6, 185, FAR_B, 0.55)

    # 地平线雾带 + 连片火炬微光 + 蒸汽浮点
    g = s.vgrad("hz", [(0, HAZE, 0), (1, HAZE, 0.38)])
    s.rect(0, 1040, 1024, 260, g)
    s.glow_ellipse(836, 1268, 80, 22, FLAME, 0.10)
    s.glow_ellipse(836, 1268, 34, 11, FLAME2, 0.14)
    for _ in range(10):
        s.circle(rng.uniform(40, 984), rng.uniform(540, 1000), rng.uniform(1, 2), STEAM, rng.uniform(0.12, 0.3))
    return s


def _tower(s: Svg, cx: float, w: float, h: float, base: float, ring_gap: float) -> None:
    """蒸馏塔：直筒 + 顶盖 + 平台环/栏杆 + 竖梯（中景楼群的工业同位素）。"""
    top = base - h
    hw = w / 2
    s.rect(cx - hw, top, w, h, MID)
    s.ellipse(cx, top, hw, 5.5, MID_DARK)  # 顶盖
    yy = top + 30
    while yy < base - 12:
        s.rect(cx - hw - 4, yy, w + 8, 4.5, MID_DARK)           # 平台环
        s.line(cx - hw - 4, yy - 7, cx + hw + 4, yy - 7, MID_LINE, 1.1, 0.9)   # 栏杆扶手
        px = cx - hw - 4
        while px <= cx + hw + 4:
            s.line(px, yy - 7, px, yy, MID_LINE, 0.9, 0.8)      # 栏杆立柱
            px += 14
        yy += ring_gap
    s.line(cx - hw * 0.45, top + 10, cx - hw * 0.45, base - 6, MID_LINE, 1.1, 0.85)  # 竖梯
    ry = top + 16
    while ry < base - 10:
        s.line(cx - hw * 0.45 - 3.5, ry, cx - hw * 0.45 + 3.5, ry, MID_LINE, 0.9, 0.7)
        ry += 11


def mid_strip():
    """中景条 2048x520（透明底，tile 2048 翻倍变化周期）：四段各异构图——
    A 蒸馏塔群 / B 桁架管廊 / C 储罐+球罐 / D 火炬塔+厂房。
    世界 y：画布 520=世界 700（地形顶之下，塔脚被地块盖住）。两侧 40px 留空。"""
    rng = random.Random(2022)
    s = Svg(2048, 520)
    BASE = 520.0

    # ---- A 段（0..512）：蒸馏塔群 ----
    _tower(s, 120, 58, 250, BASE, 36)
    _tower(s, 218, 44, 190, BASE, 30)
    for yy in (300, 330):  # 塔间连管
        s.line(150, yy, 196, yy, MID_DARK, 4.5)
    s.circle(120, BASE - 262, 2.2, RED, 0.9)  # 塔顶警灯

    # ---- B 段（512..1024）：桁架管廊一跨 ----
    bx0, bx1, by0, by1 = 560.0, 980.0, 208.0, 240.0
    s.line(bx0, by0, bx1, by0, TRUSS, 4.5)
    s.line(bx0, by1, bx1, by1, TRUSS, 4.5)
    n = int((bx1 - bx0) // 34)
    for i in range(n + 1):
        vx = bx0 + i * 34
        s.line(vx, by0, vx, by1, TRUSS, 1.8)
        if i < n:
            if i % 2 == 0:
                s.line(vx, by0, vx + 34, by1, TRUSS, 1.8)
            else:
                s.line(vx, by1, vx + 34, by0, TRUSS, 1.8)
    s.rect(bx0, by1, bx1 - bx0, 4.5, MID_DARK)
    for px in (620, 920):
        s.rect(px - 6, by1 + 4, 12, BASE - by1 - 4, TRUSS)
    for gx in (620, 920):  # 廊柱警灯
        s.glow_ellipse(gx, by1 + 8, 6, 3, RED, 0.3)
        s.circle(gx, by1 + 8, 2.2, RED, 0.9)
    # 管廊顶输送管（贴上弦走管 + 小支柱，不悬空）
    s.line(bx0, by0 - 4, bx1, by0 - 4, MID_DARK, 4)
    for px in (bx0 + 40, (bx0 + bx1) / 2, bx1 - 40):
        s.line(px, by0 - 4, px, by0, MID_DARK, 2)

    # ---- C 段（1024..1536）：卧式储罐 + 球罐 + 竖管排 ----
    for tx in (1060, 1150):
        s.rect(tx, BASE - 34, 82, 30, MID)  # 卧式储罐
        s.line(tx + 41, BASE - 4, tx + 41, BASE, MID_DARK, 4)
        s.ellipse(tx + 41, BASE - 34, 41, 5, MID_DARK)
    sx0, sy0, sr = 1330.0, BASE - 66, 44  # 球罐（储气）
    s.circle(sx0, sy0, sr, MID)
    s.poly([(sx0 - 22, sy0 + sr - 6), (sx0 - 14, sy0 + sr + 22), (sx0 - 8, sy0 + sr + 22), (sx0 - 14, sy0 + sr - 2)], MID_DARK)
    s.poly([(sx0 + 22, sy0 + sr - 6), (sx0 + 14, sy0 + sr + 22), (sx0 + 8, sy0 + sr + 22), (sx0 + 14, sy0 + sr - 2)], MID_DARK)
    s.circle(sx0, sy0, sr * 0.55, MID_DARK, 0.35)  # 球罐赤道带阴影
    s.circle(sx0, sy0 - sr - 6, 2.2, RED, 0.85)
    for px in range(1420, 1520, 22):  # 竖管排
        s.rect(px, BASE - 58, 7, 58, MID_DARK)
        s.rect(px - 2, BASE - 62, 11, 5, MID_DARK)

    # ---- D 段（1536..2048）：火炬塔 + 小厂房 + 烟囱 ----
    s.rect(1620, BASE - 90, 96, 66, MID)  # 厂房块
    s.rect(1620, BASE - 90, 96, 6, MID_DARK)
    s.rect(1650, BASE - 118, 14, 28, MID)  # 天窗斗
    s.rect(1770, BASE - 150, 20, 150, MID)  # 烟囱
    s.rect(1766, BASE - 156, 28, 6, MID_DARK)
    s.rect(1888, BASE - 300, 13, 300, MID)  # 火炬塔身
    yy = int(BASE - 270)
    while yy < int(BASE) - 20:
        s.line(1882, yy, 1907, yy + 18, MID_LINE, 1.4, 0.9)
        s.line(1907, yy, 1882, yy + 18, MID_LINE, 1.4, 0.9)
        yy += 40
    fx, fy = 1894.5, BASE - 306
    s.poly([(fx, fy - 7), (fx - 9, fy + 9), (fx, fy + 15), (fx + 9, fy + 9)], FLAME, 0.85)
    s.poly([(fx, fy - 2), (fx - 5, fy + 9), (fx, fy + 13), (fx + 5, fy + 9)], FLAME2, 0.9)
    s.circle(fx, fy + 6, 3.5, "#fff3c4", 0.95)
    for i in range(5):  # 烟羽
        s.ellipse(fx + 14 + i * 20, fy - 4 - i * 15, 11 + i * 4, 7 + i * 2, STEAM, 0.18 - i * 0.03)
    s.circle(1888 + 6, BASE - 310, 2.2, RED, 0.9)  # 塔顶警灯

    # 底部雾脚
    g = s.vgrad("fog", [(0, HAZE, 0), (1, HAZE, 0.4)])
    s.rect(0, 440, 2048, 80, g)
    return s


def ground_top():
    """地块表面带 256x56（横向平铺）：精炼所钢板地面。
    比例账：板缝间距 64（=2 块地形花纹周期/板），顶缘受光 3px，格栅坑 32x8。
    花纹距边 >=6px，接缝=纯底色。"""
    rng = random.Random(2023)
    s = Svg(256, 56)
    s.rect(0, 0, 256, 56, GROUND_TOP)
    s.rect(0, 0, 256, 3, GROUND_EDGE)      # 顶缘受光
    s.rect(0, 51, 256, 5, GROUND_DEEP)     # 底缘压暗
    for sx in (62, 126, 190):              # 板缝
        s.rect(sx, 3, 2.5, 48, SEAM)
        s.rect(sx - 4.5, 6, 1.8, 1.8, GROUND_EDGE, 0.55)  # 铆钉
        s.rect(sx + 5.2, 6, 1.8, 1.8, GROUND_EDGE, 0.55)
        s.rect(sx - 4.5, 44, 1.8, 1.8, GROUND_EDGE, 0.45)
        s.rect(sx + 5.2, 44, 1.8, 1.8, GROUND_EDGE, 0.45)
    # 排水格栅坑
    s.rect(26, 24, 32, 9, SEAM)
    for i in range(4):
        s.line(28, 26 + i * 2.2, 56, 26 + i * 2.2, GROUND_TOP, 1.2)
    # 危险黄磨旧标线
    s.rect(148, 20, 26, 4, YELLOW, 0.22)
    s.rect(148, 20, 12, 4, YELLOW, 0.3)
    # 刮痕
    for _ in range(5):
        lx = rng.uniform(10, 240)
        ly = rng.uniform(8, 44)
        s.line(lx, ly, lx + rng.uniform(6, 14), ly + rng.uniform(-2, 2), GROUND_EDGE, 1.0, rng.uniform(0.3, 0.5))
    return s


def ground_fill():
    """地块填充 16x256 竖向渐变（横向拉伸 320、纵向拉到填充深度）。"""
    s = Svg(16, 256)
    s.rect(0, 0, 16, 256, s.vgrad("fillg", FILL_STOPS))
    return s


def ground_strip():
    """兜底地面条 256x480：表面带 + 深处渐变同款（GroundStrip，位于世界 664..1144）。"""
    s = Svg(256, 480)
    src = ground_top()
    s.body.extend(src.body)
    s.defs.extend(src.defs)
    g = s.vgrad("deepg", [(0, "#3a4640", 1), (1, "#1f2823", 1)])
    s.rect(0, 56, 256, 424, g)
    return s


def deck():
    """栈桥桥面 720x26：钢板桥面 + 格栅纹 + 桁架腹杆（精炼所管廊同款语言）。
    行走面=顶缘（碰撞 one_way 顶在 y-12.4），桁架收在下 16px 内。"""
    s = Svg(720, 26)
    s.rect(0, 0, 720, 10, "#31463f")           # 桥面板
    s.line(0, 1.2, 720, 1.2, "#4d635d", 2.0)   # 上缘受光
    for gx in range(9, 720, 18):               # 格栅纹
        s.line(gx, 3, gx, 9, SEAM, 1.6, 0.55)
    s.rect(0, 10, 720, 2.5, SEAM)              # 前缘口
    for i in range(18):                        # 桁架腹杆
        x0 = i * 40.0
        if i % 2 == 0:
            s.line(x0, 12.5, x0 + 40, 24.5, SEAM, 2.0)
        else:
            s.line(x0, 24.5, x0 + 40, 12.5, SEAM, 2.0)
    s.line(0, 24.5, 720, 24.5, SEAM, 2.0)      # 下弦
    return s


# ============================================================
# 敌人单位（骨架锚点与锈雨版逐点对齐）
# ============================================================
def walker_body():
    """步行者换皮「履带炮车」56x52，地面 y=50。
    比例账：履带全长 44（4..48）x 高 12（38..50，全高 0.23=重载低速）；
    炮塔 w 28（10..38）顶 y14（中置无人炮塔）；车体带 y30..38 布危险黄警示段。
    骨架：眼 (15.5,18.3)=halo r5.3/core r2.4（同锈雨版，EyeGlow 节点照摆）；
    肩 joint (16,24) r3.5（ArmPivot 挂点）。前缘 x<8 留空给枪臂扫掠。"""
    s = Svg(56, 52)
    # 排气竖筒（塔后，先画）
    s.rect(43, 14, 7, 26, BODY)
    s.rect(42.5, 11.5, 8, 3.5, GAP)
    for vy in (20, 26, 32):
        s.rect(43, vy, 7, 2, BELLY, 0.85)
    # 天线 + 警灯
    s.line(39, 14, 42, 5, GAP, 1.5)
    s.circle(42.3, 4.5, 1.3, RED, 0.9)
    # 炮塔（前斜后直，顶面受光）
    s.poly([(12, 14), (34, 14), (38, 20), (36, 30), (14, 30), (10, 22)], BODY)
    s.poly([(12, 14), (34, 14), (36, 18), (13, 18)], LIGHT)
    s.rect(20, 21, 13, 3, GAP)  # 观察缝
    # 独眼（EyeGlow 节点位，画底衬）
    s.circle(15.5, 18.3, 5.3, RED, 0.22)
    s.circle(15.5, 18.3, 2.4, RED, 0.95)
    # 车体带 + 受光窄条 + 危险黄警示段
    s.poly([(6, 30), (46, 30), (48, 38), (4, 38)], BODY)
    s.poly([(6, 30), (46, 30), (45.5, 32), (6.5, 32)], LIGHT)
    for i, hx in enumerate(range(8, 44, 5)):
        s.rect(hx, 34.5, 2.5, 3, YELLOW if i % 2 == 0 else GAP, 0.85)
    # 履带（带体 + 上下缘 + 轮组）
    s.rect(4, 38, 44, 12, BELLY)
    s.rect(4, 38, 44, 2, GAP)
    s.rect(4, 48, 44, 2, GAP)
    for wx in (10.5, 19.5, 28.5, 37.5):
        s.circle(wx, 44, 3.6, GAP)
        s.circle(wx, 44, 1.3, LIGHT, 0.8)
    s.circle(44.5, 44, 4, GAP)   # 驱动轮
    s.circle(44.5, 44, 1.5, LIGHT, 0.8)
    # 肩 joint（枪臂挂点）
    s.circle(16, 24, 3.5, GAP)
    return s


def walker_arm():
    """步行者枪臂换皮 48x28。肩 joint (36,8) r3.5、枪口尖端 ~(2,14)（Muzzle=臂画布(6,15) 落在膛口内）。
    造型：箱形机匣 + 下挂弹鼓 + 短膛管（与锈雨版细长管拉开轮廓）。"""
    s = Svg(48, 28)
    s.circle(36, 8, 3.5, BELLY)          # 肩 joint
    s.rect(33, 8, 6, 10, BELLY)          # 肩套
    s.rect(12, 10, 22, 9, BODY)          # 机匣
    s.rect(12, 10, 22, 2.5, LIGHT)       # 匣顶受光
    s.rect(14, 13, 7, 3, GAP, 0.7)       # 退壳口
    s.circle(30, 13.5, 1.3, RED, 0.9)    # 传感器
    s.rect(5, 12, 8, 5, GAP)             # 膛管
    s.rect(2, 11, 6, 7, BODY)            # 膛口座
    s.rect(1.5, 13.5, 2.5, 2, GAP)       # 膛口
    s.circle(24, 20, 4.5, BELLY)         # 弹鼓
    s.circle(24, 20, 2.2, GAP)
    return s


def drone_body():
    """无人机换皮「涵道巡检单元」38x42（悬浮）。
    比例账：风扇舱 w22（8..30）x h10（顶置）+ 泪滴舱体 w28 h20（15..35）；
    舱底起落橇。骨架：眼 (12,14.4)=halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。"""
    s = Svg(38, 42)
    # 尾鳍（上下）
    s.poly([(26, 13), (34, 7), (35, 11), (29, 17)], BODY)
    s.poly([(26, 27), (33, 33), (28, 34), (23, 30)], BELLY)
    # 风扇舱（顶置涵道：顶缘受光 + 刃缝槽 + 桨叶反光）
    s.rect(8, 1, 22, 10, BODY)
    s.rect(8, 1, 22, 2.5, LIGHT)
    s.rect(8, 3.5, 2.5, 7.5, GAP)
    s.rect(27.5, 3.5, 2.5, 7.5, GAP)
    s.rect(10.5, 4.5, 17, 5, GAP)
    s.rect(12, 6, 4, 2, LIGHT, 0.9)
    s.rect(20, 6, 4, 2, LIGHT, 0.9)
    # 挂柱（深缝柱，读出舱/体分离）
    s.rect(12, 11, 3, 4, GAP)
    s.rect(23, 11, 3, 4, GAP)
    # 泪滴舱体（前尖后圆）
    s.poly([(8, 15), (30, 15), (33, 23), (26, 35), (12, 35), (5, 23)], BODY)
    s.poly([(8, 15), (30, 15), (31, 18), (9, 18)], LIGHT, 0.8)
    s.poly([(11, 30), (27, 30), (24, 35), (14, 35)], BELLY)
    # 眼窝 + 独眼（节点位，骑在舱颈）
    s.rect(8, 12.5, 9, 4.5, GAP)
    s.circle(12, 14.4, 4.4, RED, 0.22)
    s.circle(12, 14.4, 2.0, RED, 0.95)
    # 危险黄检修带 + 腹灯
    s.rect(15, 27.5, 4.5, 2.5, YELLOW, 0.85)
    s.rect(21, 27.5, 4.5, 2.5, YELLOW, 0.85)
    s.circle(20, 32, 4.4, RED, 0.2)
    s.circle(20, 32, 1.9, RED, 0.9)
    # 起落橇
    s.rect(11, 35, 2, 4, GAP)
    s.rect(25, 35, 2, 4, GAP)
    s.rect(8, 39, 22, 2, BELLY)
    return s


def drone_arm():
    """无人机枪臂换皮 32x16。肩 joint (28,8) r2.5；枪口尖端 ~(11.8,9.5)（Muzzle=臂画布(13,11)）。"""
    s = Svg(32, 16)
    s.circle(28, 8, 2.5, BELLY)
    s.rect(17, 6.5, 11, 5.5, BODY)
    s.rect(17, 6.5, 11, 2, LIGHT)
    s.rect(12.8, 8, 4.2, 3, GAP)
    s.rect(11, 7.5, 2.5, 4, BODY)
    s.circle(11.8, 9.5, 1.0, GAP)
    s.circle(25, 10.5, 1.0, RED, 0.9)
    return s


def shield_body():
    """盾卫换皮「破门盾车」56x52，地面 y=50。
    比例账：盾锹（前）w 22（4..26）x 高 32（14..46）圆楔形八边切角；
    驾驶舱 w 25（25..50）顶 y14；三轮 r4.2（cy45）。骨架：眼 (23.5,18.3)=halo r5.3/core r2.4；
    肩 joint (24,24)（复用 walker 换皮枪臂，tscn 同锈雨盾卫布局）。"""
    s = Svg(56, 52)
    # 排气筒（舱后）
    s.rect(47, 20, 6, 16, BELLY)
    s.rect(46.5, 17, 7, 3.5, GAP)
    # 天线
    s.line(44, 16, 47, 8, GAP, 1.5)
    s.circle(47.3, 7.5, 1.2, RED, 0.9)
    # 驾驶舱（后高前低楔形）
    s.poly([(26, 14), (46, 14), (50, 22), (50, 38), (44, 44), (28, 44), (25, 40)], BODY)
    s.poly([(26, 14), (46, 14), (47.5, 17.5), (27.5, 17.5)], LIGHT)
    s.rect(29, 20, 12, 3.5, GAP)  # 观察缝
    # 轮组（三轮）
    for wx in (14, 29, 43.5):
        s.circle(wx, 45, 4.2, GAP)
        s.circle(wx, 45, 1.4, LIGHT, 0.8)
    # 盾锹（前圆楔 + 受光前缘 + 危险黄斜纹）
    s.poly([(5, 12), (21, 14), (26, 22), (26, 40), (18, 46), (8, 46), (4, 36), (4, 16)], BODY)
    s.poly([(4, 16), (8, 13.5), (8, 45), (4, 38)], LIGHT, 0.55)
    s.rect(10, 24, 2.5, 18, YELLOW, 0.85)
    s.rect(15, 24, 2.5, 18, GAP)
    s.rect(20, 24, 2.5, 18, YELLOW, 0.85)
    # 盾底滑鞋
    s.rect(6, 46, 12, 3, BELLY)
    # 盾/舱分缝（体块分离）
    s.rect(23.8, 15, 2.2, 30, GAP)
    # 眼窝 + 独眼（节点位，骑在盾锹上沿）
    s.rect(19, 14.5, 9, 6.5, GAP)
    s.circle(23.5, 18.3, 5.3, RED, 0.22)
    s.circle(23.5, 18.3, 2.4, RED, 0.95)
    # 肩 joint + 敌识别条
    s.circle(24, 24, 3.5, GAP)
    s.rect(30, 40, 10, 2.5, RED, 0.8)
    return s


def elite_body():
    """精英换皮「双管臼炮运载车」60x80，地面 y=80。
    比例账（功能反推）：飞行弹径 5.6 → 仓口宽 9 → 双管各 w8 壁距 3（34.5..42.5 / 45.5..53.5）；
    管长 32（顶 0..车台 36）= 4x 弹径，仰射 75° 舱口朝天；车台 w26（32..58）h8；
    车体 w54 h32（44..76）+ 履板 y76..80。全高 80（与锈雨精英同档）。
    骨架：眼 (19,26.5)=halo r5.3/core r2.4（驾驶舱观察窗上）；两仓口 (38.5,1.5)/(49.5,1.5)；
    ArmPivot 画布 (44,1.5)。视角：纯侧视，管口=顶缘平齐深缝，无朝向镜头的截面。"""
    s = Svg(60, 80)
    # 天线 + 警灯
    s.line(30, 22, 33, 12, GAP, 1.5)
    s.circle(33.3, 11.5, 1.3, RED, 0.9)
    # 双联臼炮管（顶缘平齐仓口深缝）
    for tx in (34.5, 45.5):
        s.rect(tx, 4, 8, 32, BODY)
        s.rect(tx - 0.5, 0, 9, 6, GAP)          # 管口箍
        s.rect(tx + 2, 1, 5, 3.5, GAP)          # 仓口深缝（Muzzle 落点）
        s.rect(tx, 6, 8, 3, LIGHT)              # 受光带
    s.rect(33, 14, 22, 3, BELLY)                # 管间箍带
    s.rect(33, 24, 22, 3, BELLY)
    # 回旋台
    s.poly([(32, 36), (58, 36), (56, 44), (34, 44)], BELLY)
    for gx in (36, 42, 48, 54):
        s.rect(gx, 34.5, 2, 1.5, GAP)
    # 车体（前斜首 + 封尾）
    s.poly([(4, 44), (56, 44), (58, 52), (58, 68), (50, 76), (10, 76), (4, 68)], BODY)
    s.poly([(4, 44), (56, 44), (55.5, 46.5), (4.5, 46.5)], LIGHT, 0.7)
    # 驾驶舱（前置方舱 + 眼）
    s.poly([(8, 20), (30, 20), (32, 26), (32, 44), (8, 44)], BODY)
    s.rect(8, 20, 22, 3, LIGHT)
    s.rect(12, 23, 14, 7, GAP)                  # 眼窝带
    s.circle(19, 26.5, 5.3, RED, 0.22)
    s.circle(19, 26.5, 2.4, RED, 0.95)
    s.rect(10, 33, 20, 4, GAP)                  # 观察窗
    # 弹药舱细节 + 敌识别条
    for vy in (52, 55):
        s.rect(36, vy, 12, 1.2, GAP, 0.8)
    s.rect(36, 58, 12, 2.5, RED, 0.8)
    # 危险黄警示带
    for i, hx in enumerate(range(8, 52, 5)):
        s.rect(hx, 70, 2.5, 3.5, YELLOW if i % 2 == 0 else GAP, 0.85)
    # 轮组 + 履板
    for wx in (13, 30, 47):
        s.circle(wx, 71.5, 4.8, GAP)
        s.circle(wx, 71.5, 1.5, LIGHT, 0.8)
    s.rect(6, 76, 48, 4, BELLY)
    s.rect(6, 76, 48, 1.5, LIGHT, 0.6)
    return s


# ============================================================
# BOSS「钢嵴」浮空炮舰（300x180，整体重设计：低矮重驳船 + 尾部涡轮 + 背部垂发甲板）
# ============================================================
def boss_body():
    s = Svg(300, 180)
    # ---- 主舰体（低矮驳船，一直延伸到舰尾承载涡轮舱）----
    s.poly([(10, 80), (28, 56), (268, 56), (274, 64), (274, 124), (252, 142), (40, 142), (16, 118)], BODY)
    s.poly([(28, 56), (268, 56), (270, 62), (30, 62)], LIGHT)       # 上缘受光
    s.poly([(40, 142), (46, 128), (244, 128), (252, 142)], BELLY)   # 腹面
    s.rect(104, 62, 3, 64, GAP, 0.55)                               # 板缝
    s.rect(158, 62, 3, 64, GAP, 0.4)
    s.rect(40, 94, 200, 3, GAP, 0.4)
    for cx in (84, 121, 158):                                       # 悬浮井微光
        s.ellipse(cx, 142.5, 15, 3.5, STEAM, 0.14)
    s.poly([(52, 142), (60, 142), (56, 154), (47, 154)], GAP)       # 腹鳍
    s.poly([(182, 142), (190, 142), (186, 154), (177, 154)], GAP)
    for i, hx in enumerate(range(44, 232, 10)):                     # 侧舷危险黄
        s.rect(hx, 118, 5, 4, YELLOW if i % 2 == 0 else GAP, 0.7)
    # ---- 尾部涡轮舱（骑在舰尾甲板上，风扇 bar 独件在刃缝槽内转）----
    s.poly([(206, 28), (296, 28), (298, 44), (292, 58), (206, 58)], BODY)   # 舰尾甲板
    s.poly([(206, 28), (296, 28), (295, 32), (207, 32)], LIGHT, 0.6)
    s.poly([(212, 28), (218, 2), (290, 2), (294, 28)], BODY)        # 涡轮罩
    s.poly([(218, 2), (290, 2), (288, 8), (220, 8)], LIGHT)         # 罩顶受光
    s.rect(218, 8, 72, 20, GAP)                                     # 刃缝槽（bar 心画布 (254,18)）
    s.circle(226, 5, 3, RED, 0.25)                                  # 警灯
    s.circle(226, 5, 1.4, RED, 0.9)
    s.poly([(294, 32), (300, 38), (300, 52), (294, 56)], BELLY)     # 尾锥
    s.poly([(264, 58), (282, 58), (280, 74), (266, 74)], BODY)      # 尾风扇座（挂舰尾侧腹）
    # ---- 背部垂发甲板（4 仓口=BOSS_RAIN_COUNT 1:1，仓口画布 x 83/105/167/189 @ y26）----
    s.poly([(62, 28), (206, 28), (212, 48), (206, 58), (68, 58)], BODY)
    s.poly([(62, 28), (206, 28), (205, 33), (63, 33)], LIGHT)
    for mx in (83, 105, 167, 189):                                  # 仓口深缝
        s.rect(mx - 5, 25, 10, 5, GAP)
        s.rect(mx - 7, 31, 14, 2, LIGHT, 0.6)                       # 口框
    for i, hx in enumerate(range(66, 200, 12)):                     # 甲板前缘警示
        s.rect(hx, 52, 6, 4, YELLOW if i % 2 == 0 else GAP, 0.6)
    s.rect(118, 44, 28, 3, RED, 0.75)                               # 敌识别条
    # ---- 舰桥（独眼条带 y60..66 含 (55,63)）----
    s.poly([(20, 34), (58, 34), (64, 84), (16, 84)], BODY)
    s.poly([(20, 34), (58, 34), (56.5, 39), (21.5, 39)], LIGHT)
    s.rect(26, 46, 18, 8, GAP)                                      # 观察窗
    s.rect(38, 57, 34, 12, RED, 0.18)                               # 眼晕
    s.rect(42, 60, 26, 6, RED, 0.95)                                # 独眼条带
    s.rect(36, 18, 3, 16, GAP)                                      # 桅杆
    s.circle(37.5, 16.5, 3, RED, 0.25)
    s.circle(37.5, 16.5, 1.4, RED, 0.9)
    # ---- 舰艏撞角 ----
    s.poly([(2, 90), (16, 78), (16, 120), (6, 112)], BELLY)
    s.line(2, 90, 6, 112, LIGHT, 2, 0.5)
    s.circle(7, 84, 3, RED, 0.22)
    s.circle(7, 84, 1.4, RED, 0.85)
    return s


def boss_gun():
    """BOSS 机枪臂换皮 110x32（flip_v 后贴舰艏下颌，枪带画布 y85..117 不遮独眼）。
    枪口轴线在画布顶 y0..8（flip_v 落到下颌线），枪口尖端画布 (2,~4)=Muzzle。
    造型：并列双管 + 方形弹舱 + 挂座，轮廓与锈雨单管重机匣拉开。"""
    s = Svg(110, 32)
    s.rect(10, 0, 42, 3, BODY)          # 上管
    s.rect(10, 5, 42, 3, BODY)          # 下管
    for rx in (22, 34, 46):             # 散热肋
        s.rect(rx, 0, 3, 8, GAP)
    s.rect(0, 0, 12, 9, BODY)           # 双孔膛口座
    s.rect(0, 1, 4, 2, GAP)
    s.rect(0, 6, 4, 2, GAP)
    s.rect(52, 0, 40, 24, BODY)         # 机匣/弹舱
    s.rect(52, 0, 40, 5, LIGHT)
    s.rect(52, 19, 40, 5, BELLY)
    s.rect(64, 24, 22, 6, BELLY)        # 弹鼓箱
    s.rect(92, 6, 12, 14, GAP)          # 挂座
    s.rect(88, 9, 6, 3, GAP, 0.9)
    s.rect(88, 15, 6, 3, GAP, 0.9)
    return s


def boss_rotor():
    """BOSS 尾部涡轮 blade bar 84x16（侧视刃边，画布心=节点心）。
    节点位：boss_ch2.tscn Rotor=(104,-72) → 舰体画布 (254,18)，bar 覆盖 x212..296，
    落在涡轮罩刃缝槽（218..290）内、桨尖出槽 6px 读作盘面掠过罩壁。"""
    s = Svg(84, 16)
    s.rect(2, 5, 80, 6, GAP)            # 桨叶刃条
    s.rect(8, 6, 14, 4, LIGHT, 0.75)    # 反光段（不对称，旋转可读）
    s.rect(46, 6, 14, 4, LIGHT, 0.55)
    s.rect(36, 2, 12, 12, BODY)         # 毂
    s.rect(40, 6, 4, 4, GAP)
    return s


def boss_tailrotor():
    """BOSS 尾部环护风扇 56x56（整周旋转，画布心=节点 (272,96)，挂在舰尾侧腹风扇座上）。
    侧视语义：风扇盘平行屏幕→正圆成立。环护圈 + 三叶 120° 手工预算（绕 28,28）。
    桨叶用受光 LIGHT（暗对暗会隐形），毂 BELLY+GAP。"""
    s = Svg(56, 56)
    c = 28.0
    # 三叶：内缘 r6、外缘 r19、叶宽半 3.5，角度 90/210/330
    s.poly([(24.5, 22), (31.5, 22), (31.5, 9), (24.5, 9)], LIGHT)
    s.poly([(21.06, 27.97), (24.55, 34.03), (13.3, 40.53), (9.8, 34.47)], LIGHT)
    s.poly([(31.45, 21.97), (34.95, 28.03), (46.2, 21.53), (42.7, 15.47)], LIGHT)
    # 环护圈（风扇罩，工业语言）
    s.body.append(f'<circle cx="28" cy="28" r="26" fill="none" stroke="{BODY}" stroke-width="3.5"/>')
    s.circle(c, c, 6, BELLY)
    s.circle(c, c, 2.5, GAP)
    return s


if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)
    save(far_strip(), "env_ref_far.svg", """第二章「精炼所工业带」远景条 1024x1300（HillsStrip，tile 1024 视差 0.9）。
天空渐变 #a9bcb2→#6f857b；两层烟囱/厂房剪影（FAR_A 细杆 0.5 / FAR_B 块状 0.75）+
冷却塔地标（双曲收腰 hw 62→44→56，h300）+ 管廊桥 + 地平线雾带。
两侧 24px 留空=平铺接缝纯天空；画布底 1300=世界 730（低于全部地形顶）。种子 2021。""")
    save(mid_strip(), "env_ref_mid.svg", """第二章中景条 2048x520 透明底（MidStrip，tile 2048 翻倍变化周期压重复感）。
四段各异构图：A 蒸馏塔群（平台环+栏杆+竖梯）/ B 桁架管廊 / C 卧式储罐+球罐+竖管排 /
D 厂房+烟囱+火炬塔（火焰+烟羽）。色板 MID #38504a 族 + 警灯红 + 危险黄。
两侧 40px 留空；画布底=世界 700。种子 2022。""")
    save(ground_top(), "env_ref_ground_top.svg", """第二章地块表面带 256x56（terrain.gd 平铺，256 相位对齐）。
精炼所钢板地面：板缝间距 64 + 铆钉 + 排水格栅 + 磨旧危险黄标线 + 刮痕。
顶缘受光 3px / 底缘压暗 5px；花纹距边 >=6px，接缝纯底色。种子 2023。""")
    save(ground_fill(), "env_ref_ground_fill.svg", """第二章地块填充 16x256 竖向渐变（terrain.gd 横向拉伸 320、纵向拉到填充深度）。""")
    save(ground_strip(), "env_ref_ground.svg", """第二章兜底地面条 256x480（GroundStrip，位于世界 664..1144）：
表面带内容同 ground_top + 深处渐变。""")
    save(deck(), "env_ref_deck.svg", """第二章栈桥桥面 720x26（scaffold_ch2 换装）：
钢板桥面（格栅纹）+ 桁架腹杆。行走面=顶缘；桥墩用色走 obstacle.pier_color（章配）。""")
    save(walker_body(), "enemy_ref_walker_body.svg", """第二章步行者「履带炮车」56x52，地面 y=50。
骨架对齐：眼 (15.5,18.3) halo r5.3/core r2.4；肩 joint (16,24) r3.5。
造型：履带底盘（44x12，五轮）+ 中置无人炮塔 + 车体危险黄警示段 + 尾部排气筒。
前缘 x<8 留空给枪臂扫掠。色板：LIGHT #4d5348 / BODY #303429 / BELLY #252820 / GAP #161811 + 红/黄。""")
    save(walker_arm(), "enemy_ref_walker_arm.svg", """第二章步行者枪臂 48x28。肩 joint (36,8)、枪口尖端 ~(2,14)（Muzzle=臂画布 (6,15) 落在膛口座内）。
箱形机匣 + 下挂弹鼓 + 短膛管。""")
    save(drone_body(), "enemy_ref_drone.svg", """第二章无人机「涵道巡检单元」38x42（悬浮）。
骨架对齐：眼 (12,14.4) halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。
造型：顶置涵道风扇舱（刃缝槽+桨叶反光）+ 泪滴舱体 + 危险黄检修带 + 起落橇。""")
    save(drone_arm(), "enemy_ref_drone_arm.svg", """第二章无人机枪臂 32x16。肩 joint (28,8)、枪口尖端 ~(11.8,9.5)（Muzzle=臂画布 (13,11)）。""")
    save(shield_body(), "enemy_ref_shield_body.svg", """第二章盾卫「破门盾车」56x52，地面 y=50。
骨架对齐：眼 (23.5,18.3) halo r5.3/core r2.4（骑盾锹上沿）；肩 joint (24,24)（复用 walker 换皮枪臂）。
造型：前圆楔盾锹（危险黄斜纹）+ 后高驾驶舱 + 三轮底盘 + 滑鞋。""")
    save(elite_body(), "enemy_ref_elite_body.svg", """第二章精英「双管臼炮运载车」60x80，地面 y=80。
骨架对齐：眼 (19,26.5)；两仓口 (38.5,1.5)/(49.5,1.5)=ArmPivot(44,1.5)±5.5；
功能反推：弹径 5.6 → 仓口 9 → 双管 w8；管长 32=4x 弹径，仰射仓口朝天。""")
    save(boss_body(), "boss_ref_body.svg", """第二章 BOSS「钢嵴」浮空炮舰 300x180=碰撞体 body_size，原点(150,90)，原生朝左。
整体重设计：低矮武装驳船——舰艏撞角 / 舰桥独眼条带（y60..66 含 (55,63)，EyeGlow 节点
(-95,-27) scale1.2 照摆）/ 背部垂发甲板（4 仓口画布 x 83/105/167/189 @ y26 =
boss.gd MissilePorts 1:1）/ 尾部涡轮舱（blade bar 刃缝槽 x217..291 y8..28）+ 尾环护风扇（心 (272,62)）。
机枪臂独件 pivot(-51,15) 枪带画布 y85..117（flip_v 贴下颌，不遮独眼）。
色板同敌营：LIGHT/BODY/BELLY/GAP + 信号红 + 危险黄 + 蒸汽白。""")
    save(boss_gun(), "boss_ref_gun.svg", """第二章 BOSS 机枪臂 110x32（tscn flip_v=true、offset(-95,-20)，枪带贴舰艏下颌 y85..117）。
枪口轴线在画布顶 y0..8，枪口尖端画布 (2,~4)=Muzzle(-93,8)。
并列双管 + 方形弹舱 + 挂座。""")
    save(boss_rotor(), "boss_ref_rotor.svg", """第二章 BOSS 尾部涡轮 blade bar 84x16。
节点位（boss_ch2.tscn）Rotor=(103,-74) → 舰体画布 (253,16)；bar 覆盖 x211..295，
刃缝槽 217..291，桨尖出槽 6px 读作盘面掠过罩壁。侧视刃边不画椭圆盘面。""")
    save(boss_tailrotor(), "boss_ref_tailrotor.svg", """第二章 BOSS 尾部环护风扇 56x56（整周旋转，画布心=节点 (272,62)）。
风扇盘平行屏幕→正圆成立；环护圈（BODY w3.5）+ 三叶 120°（绕 28,28 手工预算）+ 毂。""")
    print("refinery chapter assets baked.")
