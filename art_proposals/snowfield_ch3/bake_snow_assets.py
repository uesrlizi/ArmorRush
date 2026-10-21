# -*- coding: utf-8 -*-
"""方案三「雪原警戒点」游戏素材烘焙（第三章换皮）：把提案拆成游戏用的 SVG。

产物直接写入 2d-ac/assets/（命名 *_snow_*）：
  env_snow_far.svg           1024x1300 远景条（冰白天空+远岭+雷达塔/掩体）
  env_snow_mid.svg           2048x520  中景条（半埋运输机/倾覆货车/雷达车+雪堆电线）
  env_snow_ground.svg        256x480   兜底地面条
  env_snow_ground_top.svg    256x56    地块表面带（雪盖公路）
  env_snow_ground_fill.svg   16x256    地块填充竖向渐变
  env_snow_deck.svg          720x26    栈桥桥面（积雪钢板）
  enemy_snow_walker_body.svg 56x52     步行者换皮：四足炮台
  enemy_snow_walker_arm.svg  48x28     步行者枪臂换皮（长管炮）
  enemy_snow_drone.svg       38x42     无人机换皮：四旋翼侦察机
  enemy_snow_drone_arm.svg   32x16     无人机枪臂换皮
  enemy_snow_shield_body.svg 56x52     盾卫换皮：塔盾重步卫
  enemy_snow_elite_body.svg  60x80     精英换皮：铲雪履带垂发车
  boss_snow_body.svg         260x180   BOSS v3 强袭悬空机甲「哨兵」（右肩双仓+电浆重炮+布雷舱）
  boss_snow_gun.svg          130x40    哨兵电浆重炮臂（pivot (112,20)，枪口臂局部 (-104,0)）
  boss_snow_body.svg         260x180   BOSS v3 强袭悬空机甲「哨兵」（右肩双仓+电浆重炮+布雷舱）
  boss_snow_gun.svg          130x40    哨兵电浆重炮臂（pivot (112,20)，枪口臂局部 (-104,0)）
  plasma_bolt.svg            28x10     电浆矢弹（哨兵直射弹 plasma_bolt.tscn 本体）
  missile_plasma.svg         32x16     电浆矢弹（v2：PlasmaMissile 本体）
  fx_plasma_bolt.svg         28x10     电弧段贴图（v2：尾迹/爆闪粒子）
  fx_plasma_mine.svg         44x44     电浆浮雷（v2：PlasmaMine 本体）

骨架对齐账（换皮铁律：美术重画、锚点不动）：
  步行者：眼 (15.5,18.3)；肩 joint (16,24)；地面 y=50
  无人机：眼 (12,14.4)；枪口=臂画布 (13,11)
  盾卫：  眼 (23.5,18.3)；肩 joint (24,24)
  精英：  眼 (19,26.5)；两仓口画布 (38.5,1.5)/(49.5,1.5)（=pivot±5.5）
  BOSS：  眼条带 y60..66 含 (55,63)；导弹仓口画布 x 83/105/167/189 @ y26；
          枪口=臂画布 (2,~4)（flip_v 后贴艇艏下颌）；
          尾推桨 bar 心=节点 (120,-18)→画布(270,72)；侧风扇心=节点 (122,20)→画布(272,110)
          v2 布雷闸锚画布 (100,140)=BayPort Visuals (-50,50)

色板（提案三「高调冰白」）：天空 #d4e2ea→#f7fafb、远岭 #c2d2db、
军事剪影 #8ba0ab、机残骸 #5a6a74、信号红 #e23d3d、路中线黄 #c9b23c。
机甲（敌营近黑随章转冷蓝灰）：LIGHT #5d6c76 / BODY #39444d / BELLY #2a333a /
GAP #161c21 + 雪地迷彩 #aab8c2 —— 暗色机体在雪上辨识度最高（提案原话）。
ThorVG 硬约束：无 filter/pattern/use/text/transform；平铺接缝两侧留空。单位件坐标全手排。
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
from generate_proposals import Svg, f  # noqa: E402

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "world_3"))

# ---- 环境色板（提案三「雪原警戒点」） ----
# 天光账（2026-10-19 三轮修订）：首版 #f7fafb 纸白段拉太宽 → 亮黄弹/焰芯隐形；
# 二版压到阴天冰蓝仍不够（用户否掉描边方案，点名 UE 自发光思路 + 授权再降天空）。
# 定稿=暮色暴风雪档：天顶 #7e93a4（可飞区亮度 ~0.55，琥珀弹+光晕对比充足），
# 贴地仍留雪光；雪岭改亮于天（雪面反光），军事剪影随天加深保轮廓。
SKY_STOPS = [(0, "#7e93a4", 1), (0.5, "#9cb1bf", 1), (1, "#c6d4dd", 1)]
RIDGE_A = "#dde8ed"   # 远岭第一层（雪面反光，亮于天）
RIDGE_B = "#c6d5de"   # 远岭第二层（略近略暗）
FAR_MIL = "#6f8291"   # 远景军事设施剪影（随天加深）
HAZE = "#b9c9d4"      # 雾带/雪雾
MID_HULL = "#5a6a74"  # 中景机残骸/车体
MID_SHADE = "#46545e"
MID_DARK = "#3a4750"
POLE = "#6e8694"
SNOW = "#e9f1f5"
SNOW_HI = "#f7fafb"
ROAD = "#56626c"
ROAD_DEEP = "#333d45"
RED = "#e23d3d"
YELLOW = "#c9b23c"
FILL_STOPS = [(0, "#5a6670", 1), (0.45, "#39434c", 1), (1, "#232a31", 1)]

# ---- 机甲色板（敌营近黑，随章转冷蓝灰） ----
LIGHT = "#5d6c76"
BODY = "#39444d"
BELLY = "#2a333a"
GAP = "#161c21"
CAMO = "#aab8c2"  # 雪地迷彩块

# ---- 电浆系（v2 能力化新增：电浆导弹/浮雷；亮背景章靠饱和冰蓝+白热芯对抗天光） ----
PLASMA_BLUE = "#7fd0ff"   # 电离鞘（饱和冰蓝）
PLASMA_WHITE = "#eaf6ff"  # 白热芯
PLASMA_DEEP = "#2b6ea0"   # 深电蓝（电离球壳/矢弹外壳）


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
    """远景条 1024x1300：冰白天空 + 两层雪岭 + 雷达塔/掩体剪影 + 雪雾。
    比例账：远岭峰高 80..220（占画布下 1/6）；雷达塔全高 ~340（桁架收分）；
    掩体 92x34 平顶。两侧 24px 留空=接缝纯天空。画布底 1300=世界 730。种子 3031。"""
    rng = random.Random(3031)
    s = Svg(1024, 1300)
    s.rect(0, 0, 1024, 1300, s.vgrad("sky", SKY_STOPS))
    # 隐日（白盘光晕；天压暗后亮度跟着降半档，不做刺眼白洞）
    s.glow_ellipse(760, 240, 120, 100, "#ffffff", 0.32)
    s.glow_ellipse(760, 240, 55, 46, "#ffffff", 0.55)

    BASE = 1300.0
    # 远岭两层（锯齿雪脊，两侧留空）
    for color, hmin, hmax, step in ((RIDGE_A, 140, 260, (110, 190)), (RIDGE_B, 70, 150, (90, 150))):
        pts_ = [(24, BASE)]
        x = 24.0
        while x < 980:
            x += rng.uniform(*step)
            pts_.append((min(x, 1000), BASE - rng.uniform(hmin, hmax)))
        pts_.append((1000, BASE))
        s.poly(pts_, color)
    # 远景军事剪影（在岭上）
    # 雷达塔（桁架收分 + 天线 + 警灯）
    tx = 210.0
    s.line(tx - 22, BASE, tx - 5, BASE - 320, FAR_MIL, 3)
    s.line(tx + 22, BASE, tx + 5, BASE - 320, FAR_MIL, 3)
    yy = BASE - 30
    while yy > BASE - 300:
        t = (BASE - yy) / 320.0
        xl = tx - 22 + 17 * t
        xr = tx + 22 - 17 * t
        s.line(xl, yy, xr, yy - 26, FAR_MIL, 1.4, 0.9)
        s.line(xr, yy, xl, yy - 26, FAR_MIL, 1.4, 0.9)
        yy -= 26
    s.rect(tx - 26, BASE - 330, 52, 5, FAR_MIL)
    s.circle(tx, BASE - 342, 11, FAR_MIL)
    s.line(tx, BASE - 342, tx + 10, BASE - 352, FAR_MIL, 1.5)
    s.line(tx, BASE - 320, tx, BASE - 372, FAR_MIL, 2.5)
    s.circle(tx, BASE - 376, 3, RED, 0.85)
    # 掩体两座（平顶 + 顶缘积雪）
    for bx, bw, bh in ((520, 96, 40), (842, 72, 30)):
        s.rect(bx, BASE - bh, bw, bh, FAR_MIL, 0.95)
        s.rect(bx - 4, BASE - bh - 6, bw + 8, 6, "#eef4f7", 0.95)
        s.rect(bx + bw * 0.35, BASE - bh + 12, 18, 9, MID_DARK, 0.9)
    # 雪雾带 + 风掠线 + 雪点
    g = s.vgrad("hz", [(0, HAZE, 0), (1, HAZE, 0.5)])
    s.rect(0, 1010, 1024, 290, g)
    for _ in range(8):
        lx = rng.uniform(60, 900)
        ly = rng.uniform(120, 620)
        ln = rng.uniform(40, 90)
        s.line(lx, ly, lx - ln, ly + ln * 0.06, "#ffffff", 2, rng.uniform(0.18, 0.32), cap="round")
    for _ in range(12):
        s.circle(rng.uniform(40, 984), rng.uniform(200, 900), rng.uniform(1, 2), "#ffffff", rng.uniform(0.4, 0.8))
    return s


def mid_strip():
    """中景条 2048x520（透明底，tile 2048）：两段各异——
    A 半埋运输机残骸 + 雪堆 + 电线杆；B 倾覆货运车厢 + 集装箱 + 雷达车。
    世界 y：画布 520=世界 700（地形顶之下）。两侧 40px 留空。种子 3032。"""
    rng = random.Random(3032)
    s = Svg(2048, 520)
    BASE = 520.0

    # ---- A 段：半埋运输机残骸（机头朝左，腹埋雪中）----
    s.rect(300, 402, 260, 46, MID_HULL)          # 机身
    s.rect(300, 432, 260, 16, MID_SHADE)         # 腹部阴影
    s.rect(310, 420, 240, 5, "#c24438", 0.8)     # 红识别带
    for i in range(11):                          # 舷窗
        s.rect(322 + i * 20, 410, 7, 8, "#2e3840", 0.9)
    s.poly([(508, 402), (548, 348), (566, 348), (560, 402)], "#54646e")   # 垂尾
    s.poly([(548, 348), (566, 348), (564, 356), (550, 356)], "#6d7d88")   # 尾顶受光
    s.poly([(380, 448),  (452, 448), (432, 472), (362, 470)], "#4c5a64")  # 断翼残段
    s.rect(396, 462, 32, 14, MID_SHADE)          # 发动机短舱（半埋）
    s.poly([(560, 440), (582, 452), (576, 466), (552, 456)], MID_DARK)    # 尾部撕裂口
    s.circle(556, 352, 2.2, RED, 0.85)           # 尾顶警灯
    # 盖雪（压住腹缘=半埋感）
    s.ellipse(350, 452, 96, 13, SNOW)
    s.ellipse(505, 456, 84, 11, SNOW)
    s.ellipse(430, 476, 60, 9, SNOW, 0.85)
    # 雪堆
    for mx, mw, mh in ((140, 170, 20), (660, 130, 14), (860, 200, 24)):
        s.ellipse(mx, BASE, mw / 2, mh, "#dbe6ec")
    # 电线杆 + 垂线
    poles = [(640, 3), (800, -2), (960, 2)]
    for i, (px, tilt) in enumerate(poles):
        s.line(px, BASE, px + tilt * 0.4, BASE - 54, POLE, 2.5, 0.9)
        s.line(px - 9 + tilt, BASE - 48, px + 9 + tilt, BASE - 48, POLE, 2, 0.9)
        s.line(px + tilt, BASE - 54, px + tilt, BASE - 60, POLE, 1.5, 0.9)
        if i:
            qx, qt = poles[i - 1]
            x0w, x1w = qx + qt, px + tilt
            s.path(f"M {f(x0w)},{f(BASE - 60)} Q {f((x0w + x1w) / 2)},{f(BASE - 51)} {f(x1w)},{f(BASE - 60)}",
                   stroke=POLE, w=1.1, opacity=0.7)

    # ---- B 段：倾覆货运车厢 + 集装箱 + 雷达车 ----
    s.poly([(1150, 424), (1404, 410), (1408, 452), (1154, 466)], MID_HULL)  # 倾覆车厢体
    s.poly([(1150, 424), (1404, 410), (1402, 419), (1152, 433)], "#6d7d88")  # 侧板受光
    s.rect(1240, 424, 34, 40, MID_SHADE)          # 车门
    s.line(1257, 424, 1257, 462, MID_DARK, 2)
    s.rect(1330, 418, 34, 40, MID_SHADE, 0.9)     # 第二车门
    s.poly([(1148, 424), (1406, 410), (1404, 419), (1150, 433)], SNOW)      # 顶盖积雪
    s.circle(1160, 452, 2.0, RED, 0.8)            # 尾端红灯
    # 集装箱
    s.rect(1470, 428, 130, 36, "#4e5d68")
    s.rect(1470, 428, 130, 5, "#6d7d88")
    for gx in range(1484, 1596, 16):
        s.line(gx, 436, gx, 460, MID_DARK, 1.6, 0.7)
    s.poly([(1468, 428), (1602, 428), (1600, 435), (1470, 435)], SNOW, 0.9)
    # 雷达车
    s.rect(1660, 442, 96, 26, MID_HULL)
    s.rect(1660, 442, 96, 5, "#6d7d88")
    s.rect(1666, 430, 30, 14, MID_SHADE)          # 驾驶室
    s.rect(1670, 433, 10, 6, "#2e3840", 0.9)      # 车窗
    s.line(1730, 442, 1730, 416, POLE, 2.5)
    s.ellipse(1730, 412, 11, 5, "#6d7d88")        # 雷达碟
    s.line(1730, 412, 1737, 406, POLE, 1.5)
    s.circle(1730, 404, 2.2, RED, 0.85)
    for wx in (1676, 1700, 1724):                 # 车轮（半埋）
        s.circle(wx, 470, 7, MID_DARK)
    # 雪堆盖脚
    for mx, mw, mh in ((1240, 220, 18), (1560, 150, 14), (1800, 190, 20), (1980, 120, 12)):
        s.ellipse(mx, BASE, mw / 2, mh, "#dbe6ec")

    # 底部雪雾
    g = s.vgrad("fog", [(0, HAZE, 0), (1, HAZE, 0.42)])
    s.rect(0, 438, 2048, 82, g)
    return s


def ground_top():
    """地块表面带 256x56（横向平铺）：雪盖公路。
    比例账：顶缘雪檐 3px（受光）、中线黄虚线 y26、底缘暗 5px；
    雪斑/裂缝距边 >=6px，接缝=纯路面。种子 3033。"""
    rng = random.Random(3033)
    s = Svg(256, 56)
    s.rect(0, 0, 256, 56, ROAD)
    s.rect(0, 0, 256, 3, "#eef4f7")            # 顶缘雪檐（受光）
    s.rect(0, 3, 256, 1.5, "#f2f7f9", 0.6)     # 雪檐柔边
    s.rect(0, 51, 256, 5, ROAD_DEEP)           # 底缘压暗
    # 车辙（两条横向暗带）
    s.line(0, 14, 256, 14, "#49555f", 3, 0.5)
    s.line(0, 40, 256, 40, "#49555f", 3, 0.5)
    # 中线黄虚线（两段，接缝处留空）
    s.rect(18, 26, 26, 4, YELLOW, 0.5)
    s.rect(146, 26, 26, 4, YELLOW, 0.5)
    # 雪斑（不规则亮块）
    for sx, sw, sh in ((40, 34, 5), (110, 22, 4), (196, 30, 6), (226, 16, 4)):
        s.ellipse(sx, rng.uniform(8, 46), sw / 2, sh / 2, "#e8eff3", 0.8)
    # 裂缝
    for cx, cy in ((70, 10), (160, 34), (216, 18)):
        pts_ = [(cx, cy)]
        px, py = cx, cy
        for _ in range(3):
            px += rng.uniform(8, 16)
            py += rng.uniform(5, 10)
            pts_.append((px, py))
        s.path("M " + " L ".join(f"{f(a)},{f(b)}" for a, b in pts_), stroke=ROAD_DEEP, w=1.3, opacity=0.85)
    # 雪点
    for _ in range(10):
        s.circle(rng.uniform(6, 250), rng.uniform(6, 48), rng.uniform(0.8, 1.6), "#ffffff", rng.uniform(0.5, 0.85))
    return s


def ground_fill():
    """地块填充 16x256 竖向渐变（路床向深处压暗）。"""
    s = Svg(16, 256)
    s.rect(0, 0, 16, 256, s.vgrad("fillg", FILL_STOPS))
    return s


def ground_strip():
    """兜底地面条 256x480（GroundStrip，位于世界 664..1144）：表面带 + 深处渐变。"""
    s = Svg(256, 480)
    src = ground_top()
    s.body.extend(src.body)
    s.defs.extend(src.defs)
    g = s.vgrad("deepg", [(0, "#39434c", 1), (1, "#232a31", 1)])
    s.rect(0, 56, 256, 424, g)
    return s


def deck():
    """栈桥桥面 720x26：积雪钢板 + 格栅纹 + 桁架腹杆。
    行走面=顶缘（雪檐 3px + 钢板 7px），桁架收在下 16px。"""
    s = Svg(720, 26)
    s.rect(0, 0, 720, 3, "#f2f7f9")            # 顶缘雪檐
    s.rect(0, 3, 720, 7, "#4d5963")            # 钢桥面板
    for gx in range(9, 720, 18):               # 格栅纹
        s.line(gx, 4.5, gx, 9.5, "#2f3941", 1.6, 0.6)
    s.rect(0, 10, 720, 2.5, "#232a31")         # 前缘口
    for i in range(18):                        # 桁架腹杆
        x0 = i * 40.0
        if i % 2 == 0:
            s.line(x0, 12.5, x0 + 40, 24.5, "#2f3941", 2.0)
        else:
            s.line(x0, 24.5, x0 + 40, 12.5, "#2f3941", 2.0)
    s.line(0, 24.5, 720, 24.5, "#2f3941", 2.0)  # 下弦
    return s


# ============================================================
# 敌人单位（骨架锚点与一/二章逐点对齐；造型第三章全重画）
# ============================================================
def walker_body():
    """步行者换皮「四足炮台」56x52，地面 y=50。
    比例账：车体 44x14（4..48 x 20..34，低矮驮载）；四足（远侧一对 BELLY、
    近侧一对 BODY）踏地 y50；前置小头楔 y13..20 托独眼。
    骨架：眼 (15.5,18.3)=halo r5.3/core r2.4；肩 joint (16,24)。前缘 x<6 留空给枪臂。"""
    s = Svg(56, 52)
    # 远侧足对（先画，暗一档）
    s.poly([(22, 30), (26, 30), (24, 40), (27, 47), (22, 50), (19, 40)], BELLY)
    s.poly([(36, 30), (40, 30), (39, 40), (42, 47), (37, 50), (34, 40)], BELLY)
    # 排气背囊 + 天线
    s.rect(41, 12, 7, 9, BODY)
    s.rect(40.5, 10, 8, 3, GAP)
    s.line(37, 13, 40, 5, GAP, 1.5)
    s.circle(40.3, 4.5, 1.3, RED, 0.9)
    # 头楔（前顶，托独眼）
    s.poly([(8, 13), (26, 13), (29, 20), (6, 20)], BODY)
    s.poly([(8, 13), (26, 13), (27, 15.5), (8, 15.5)], LIGHT)
    s.rect(9, 15, 12, 6.5, GAP)
    s.circle(15.5, 18.3, 5.3, RED, 0.22)
    s.circle(15.5, 18.3, 2.4, RED, 0.95)
    # 车体（低矮驮板）
    s.poly([(6, 20), (46, 20), (50, 26), (46, 34), (8, 34), (4, 27)], BODY)
    s.poly([(6, 20), (46, 20), (47.5, 23), (7.5, 23)], LIGHT)
    s.rect(8, 32.5, 38, 1.5, GAP, 0.8)
    # 侧舷危险黄警示段
    for i, hx in enumerate(range(24, 44, 5)):
        s.rect(hx, 26, 2.5, 3, YELLOW if i % 2 == 0 else GAP, 0.8)
    # 近侧足对（踏地）
    s.poly([(10, 34), (15, 34), (14, 41), (18, 47), (13, 50), (7, 42)], BODY)
    s.poly([(28, 34), (33, 34), (33, 42), (37, 47), (32, 50), (27, 42)], BODY)
    # 足垫
    s.rect(11, 48.5, 9, 1.8, BELLY)
    s.rect(29, 48.5, 9, 1.8, BELLY)
    # 肩 joint（枪臂挂点）
    s.circle(16, 24, 3.5, GAP)
    return s


def walker_arm():
    """步行者枪臂换皮 48x28：长管炮（细长管 + 顶置瞄具，与二章弹鼓箱形拉开）。
    肩 joint (36,8)、枪口尖端 ~(2,14)（Muzzle=臂画布 (6,15) 落在膛口座内）。"""
    s = Svg(48, 28)
    s.circle(36, 8, 3.5, BELLY)
    s.rect(33, 8, 6, 10, BELLY)
    s.rect(16, 10, 20, 9, BODY)          # 机匣
    s.rect(16, 10, 20, 2.5, LIGHT)
    s.rect(24, 6.5, 7, 4, GAP)           # 顶置瞄具
    s.rect(4, 12.5, 13, 4, GAP)          # 长管
    s.rect(1, 11, 5, 7, BODY)            # 膛口座
    s.rect(1, 13.8, 2.2, 2.4, GAP)       # 膛口
    s.rect(20, 19, 9, 3, BELLY)          # 下挂导轨
    s.circle(32, 13.5, 1.3, RED, 0.9)
    return s


def drone_body():
    """无人机换皮「四旋翼侦察机」38x42（悬浮）。
    侧视语义：两只可见旋翼=刃边短横条（不画椭圆盘面），臂斜撑到中央舱体；
    腹挂传感器球。骨架：眼 (12,14.4)=halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。"""
    s = Svg(38, 42)
    # 尾鳍（右）
    s.poly([(29, 16), (35, 11), (36, 15), (31, 20)], BODY)
    # 旋翼（刃边横条 + 桨毂）
    for rx in (2, 23):
        s.rect(rx, 3, 13, 2.5, GAP)
        s.rect(rx + 2, 3.6, 4, 1.3, LIGHT, 0.85)
    s.rect(7, 3, 3, 2.5, BODY)
    s.rect(28, 3, 3, 2.5, BODY)
    # 斜撑臂
    s.poly([(8, 5.5), (10.5, 5.5), (14, 16), (11, 17)], BODY)
    s.poly([(29.5, 5.5), (32, 5.5), (28, 16), (25, 17)], BODY)
    # 中央舱体
    s.poly([(9, 16), (29, 16), (32, 22), (27, 30), (11, 30), (6, 22)], BODY)
    s.poly([(9, 16), (29, 16), (30, 18.5), (10, 18.5)], LIGHT, 0.8)
    s.poly([(11, 26), (27, 26), (25, 30), (13, 30)], BELLY)
    # 眼窝 + 独眼（节点位）
    s.rect(7, 12.5, 9, 4.5, GAP)
    s.circle(12, 14.4, 4.4, RED, 0.22)
    s.circle(12, 14.4, 2.0, RED, 0.95)
    # 检修黄带
    s.rect(16, 21.5, 6, 2.5, YELLOW, 0.8)
    # 腹挂传感器球
    s.rect(18, 30, 2.5, 3, GAP)
    s.circle(19.2, 35, 3.2, BELLY)
    s.circle(19.2, 35, 1.3, RED, 0.9)
    # 起落橇
    s.rect(12, 30, 2, 6, GAP)
    s.rect(25, 30, 2, 6, GAP)
    s.rect(8, 36, 22, 2, BELLY)
    return s


def drone_arm():
    """无人机枪臂换皮 32x16。肩 joint (28,8)、枪口尖端 ~(12,9.5)（Muzzle=臂画布 (13,11)）。"""
    s = Svg(32, 16)
    s.circle(28, 8, 2.5, BELLY)
    s.rect(18, 6.5, 10, 5.5, BODY)
    s.rect(18, 6.5, 10, 2, LIGHT)
    s.rect(13.5, 8, 5, 3, GAP)
    s.rect(11, 7.5, 3, 4.5, BODY)
    s.circle(11.8, 9.5, 1.0, GAP)
    s.circle(25, 10.5, 1.0, RED, 0.9)
    return s


def shield_body():
    """盾卫换皮「塔盾重步卫」56x52，地面 y=50。
    比例账：通高塔盾 4..25 x 10..47（占前 40% 全高）；后置舱体 25..49 x 10..42；
    双足踏地。骨架：眼 (23.5,18.3)=halo r5.3/core r2.4（盾/舱交界窝）；
    肩 joint (24,24)（复用本章枪臂）。"""
    s = Svg(56, 52)
    # 远侧足（暗）
    s.poly([(12, 42), (18, 42), (16, 50), (9, 50)], BELLY)
    # 排气筒 + 天线
    s.rect(46, 18, 6, 15, BELLY)
    s.rect(45.5, 15, 7, 3.5, GAP)
    s.line(43, 10, 46, 3, GAP, 1.5)
    s.circle(46.3, 2.5, 1.2, RED, 0.9)
    # 舱体（后置）
    s.poly([(25, 10), (45, 10), (49, 18), (49, 36), (42, 42), (28, 42), (25, 38)], BODY)
    s.poly([(25, 10), (45, 10), (46.5, 13.5), (26.5, 13.5)], LIGHT)
    s.rect(31, 17, 11, 3.5, GAP)         # 观察缝
    # 塔盾（通高，前缘受光 + 斜纹黄）
    s.poly([(5, 10), (22, 10), (25, 14), (25, 44), (21, 47), (7, 47), (4, 42), (4, 14)], BODY)
    s.poly([(4, 14), (7, 11.5), (7, 45), (4, 40)], LIGHT, 0.6)
    s.poly([(11, 24), (14.5, 22), (14.5, 42), (11, 42)], YELLOW, 0.8)
    s.poly([(17, 24), (20.5, 22), (20.5, 42), (17, 42)], GAP)
    # 盾底滑鞋
    s.rect(6, 47, 13, 3, BELLY)
    # 眼窝 + 独眼（节点位，盾/舱交界）
    s.rect(18, 14, 10, 8, GAP)
    s.circle(23.5, 18.3, 5.3, RED, 0.22)
    s.circle(23.5, 18.3, 2.4, RED, 0.95)
    # 肩 joint + 近侧足 + 识别条
    s.circle(24, 24, 3.5, GAP)
    s.poly([(30, 42), (36, 42), (38, 49), (31, 49)], BODY)
    s.rect(29, 47.5, 11, 2.2, BELLY)
    s.rect(32, 34, 9, 2.5, RED, 0.8)
    return s


def elite_body():
    """精英换皮「铲雪履带垂发车」60x80，地面 y=80。
    比例账（功能反推）：弹径 5.6 → 仓口宽 9 → 方舱双盖 x 34..43/45..54（=pivot±5.5）；
    舱深=方舱高 34；前置铲雪犁 0..14；履带裙 6..54 y64..76 + 接地垫 y76..80。
    骨架：眼 (19,26.5)=halo r5.3/core r2.4；两仓口 (38.5,1.5)/(49.5,1.5)。"""
    s = Svg(60, 80)
    # 天线 + 警灯
    s.line(28, 22, 31, 12, GAP, 1.5)
    s.circle(31.3, 11.5, 1.3, RED, 0.9)
    # 垂发方舱（平顶双盖，与二章双立管拉开）
    s.rect(32, 4, 24, 34, BODY)
    s.rect(32, 4, 24, 3, LIGHT)
    s.rect(34, 0, 9, 6, GAP)             # 仓口盖 A（Muzzle 38.5,1.5）
    s.rect(45, 0, 9, 6, GAP)             # 仓口盖 B（Muzzle 49.5,1.5）
    s.rect(33, 7, 10, 1.5, LIGHT, 0.6)
    s.rect(44, 7, 11, 1.5, LIGHT, 0.6)
    for vy in (14, 22, 30):              # 舱面肋
        s.rect(34, vy, 20, 1.5, GAP, 0.6)
    s.rect(34, 30, 16, 2.5, RED, 0.8)
    # 回旋座
    s.rect(30, 38, 28, 6, BELLY)
    # 车体
    s.poly([(4, 44), (58, 44), (60, 52), (60, 66), (52, 74), (12, 74), (4, 64)], BODY)
    s.poly([(4, 44), (58, 44), (57.5, 46.5), (4.5, 46.5)], LIGHT, 0.7)
    # 驾驶舱 + 眼
    s.poly([(8, 22), (30, 22), (32, 28), (32, 44), (8, 44)], BODY)
    s.rect(8, 22, 22, 3, LIGHT)
    s.rect(12, 23, 14, 7, GAP)
    s.circle(19, 26.5, 5.3, RED, 0.22)
    s.circle(19, 26.5, 2.4, RED, 0.95)
    s.rect(10, 33, 20, 4, GAP)
    # 铲雪犁（前下，斜刃受光）
    s.poly([(2, 56), (10, 48), (14, 48), (14, 70), (6, 70), (0, 62)], BELLY)
    s.line(0, 62, 6, 70, LIGHT, 2, 0.7)
    # 危险黄警示带
    for i, hx in enumerate(range(18, 54, 5)):
        s.rect(hx, 58, 2.5, 3.5, YELLOW if i % 2 == 0 else GAP, 0.8)
    # 履带裙 + 接地垫
    s.rect(6, 64, 48, 12, BELLY)
    for tx in range(10, 52, 6):
        s.rect(tx, 66, 2, 8, GAP, 0.85)
    s.rect(6, 76, 48, 4, GAP)
    s.rect(6, 76, 48, 1.5, LIGHT, 0.55)
    return s


# ============================================================
# BOSS 武装飞艇「白鲸」（300x180，整体重设计：椭圆气囊 + 背脊垂发 + 吊舱 + 尾推桨）
# ============================================================
def _ellipse_pts(cx, cy, rx, ry, n=16):
    pts_ = []
    for i in range(n):
        a = TAU_PI * i / n
        pts_.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    return pts_


TAU_PI = math.tau






# ============================================================
# 电浆系（v2 能力化新增：电浆导弹 / 浮雷）
# ============================================================
def plasma_missile():
    """电浆矢弹 32x16，原点(16,8)，+X=弹头（rotation 沿速度方向转整弹，同 mortar_shell）。
    造型账：软电离光晕（rgrad 冰蓝，ADD 粒子层之外的本体辉光）→ 深电蓝矢形壳
    （尾 x4 → 鼻 x29，最宽 ±3.8 @x16）→ 冰蓝内鞘 → 白热芯（贯穿前段）→
    尾部三根电弧须（锯齿短线，引擎侧粒子会持续甩弧，本体只给静态根）。"""
    s = Svg(32, 16)
    s.glow_ellipse(16, 8, 15, 7, PLASMA_BLUE, 0.55)
    s.poly([(4, 8), (9, 5.2), (16, 4.2), (23, 5.4), (29, 8), (23, 10.6),
            (16, 11.8), (9, 10.8)], PLASMA_DEEP)
    s.poly([(7, 8), (12, 6.1), (18, 5.4), (24, 6.6), (27, 8), (24, 9.4),
            (18, 10.6), (12, 9.9)], PLASMA_BLUE, 0.9)
    s.poly([(9, 8), (15, 6.6), (25, 7.6), (25, 8.4), (15, 9.4)], PLASMA_WHITE)
    s.line(2, 8, 6, 8, PLASMA_BLUE, 1.4, 0.9)
    s.line(1, 5.5, 5, 7, PLASMA_BLUE, 1.1, 0.7)
    s.line(1, 10.5, 5, 9, PLASMA_BLUE, 1.1, 0.7)
    return s


def plasma_bolt():
    """电弧段贴图 28x10（粒子用：随机旋转、ADD、短寿）。锯齿折线两遍出层次：
    底层宽线冰蓝晕 + 顶层细线白热芯；两端收细（首尾点向内半格）。"""
    s = Svg(28, 10)
    zig = [(3, 5), (8, 2.5), (13, 7), (18, 3), (23, 6.5), (25.5, 4.8)]
    for (x1, y1), (x2, y2) in zip(zig, zig[1:]):
        s.line(x1, y1, x2, y2, PLASMA_BLUE, 3.2, 0.7)
    for (x1, y1), (x2, y2) in zip(zig, zig[1:]):
        s.line(x1, y1, x2, y2, PLASMA_WHITE, 1.3, 0.95)
    return s


def plasma_mine():
    """电浆浮雷 v2 64x64，原点(32,32)（雷体中心=判定圆心，判定不变纯视觉放大）。
    水雷剪影签名：球壳 r16 + **8 根电极柱**（r16→r23，宽 4.4，45° 步进；柱尖
    冰蓝=电离触点）——「浮雷」第一眼就读出来，不再是"卡住的导弹"。
    造型账：电离光晕（rgrad 冰蓝 r30）→ 电极柱 ×8（LIGHT 柱体+PLASMA_BLUE 尖）
    → 深电蓝球壳 → 北极高光弧（LIGHT 0.35）→ 赤道缝（GAP 2px 弦线）
    → 核心独眼红（敌语汇：halo r12 + 红盘 r7 + 白热 r3）。
    引信快闪/蓄能呼吸由引擎侧 modulate 脉冲，贴图不负责任何状态色。"""
    s = Svg(64, 64)
    s.glow_ellipse(32, 32, 30, 30, PLASMA_BLUE, 0.5)
    for deg in range(0, 360, 45):                   # 8 根电极柱
        a = math.radians(deg)
        dx, dy = math.cos(a), math.sin(a)
        px, py = -dy, dx
        inner = (32 + 16 * dx, 32 + 16 * dy)
        outer = (32 + 23 * dx, 32 + 23 * dy)
        s.poly([(inner[0] + 2.2 * px, inner[1] + 2.2 * py),
                (inner[0] - 2.2 * px, inner[1] - 2.2 * py),
                (outer[0] - 2.2 * px, outer[1] - 2.2 * py),
                (outer[0] + 2.2 * px, outer[1] + 2.2 * py)], LIGHT)
        s.circle(outer[0], outer[1], 1.6, PLASMA_BLUE, 0.95)
    s.circle(32, 32, 16, PLASMA_DEEP)
    s.circle(29.5, 29.5, 9, PLASMA_BLUE, 0.25)      # 北极高光（左上偏移小内圆）
    s.line(17, 36, 47, 36, GAP, 2.0, 0.8)           # 赤道缝
    s.line(22, 24, 28, 30, PLASMA_BLUE, 1.6, 0.9)   # 壳面静态弧 ×3
    s.line(28, 30, 35, 24, PLASMA_BLUE, 1.6, 0.9)
    s.line(38, 42, 43, 36, PLASMA_BLUE, 1.3, 0.8)
    s.line(20, 42, 25, 38, PLASMA_BLUE, 1.3, 0.8)
    s.glow_ellipse(32, 32, 12, 12, RED, 0.5)
    s.circle(32, 32, 7, RED)
    s.circle(32, 32, 3, "#ffd9d4")
    return s


def plasma_bolt_fx():
    """电浆矢弹贴图 28x10（普攻直射弹 plasma_bolt.tscn 本体，+X 弹头）。
    与亮黄水滴机枪弹彻底分家：六边形能量镖（深电蓝壳+冰蓝鞘+白热芯）+
    尾部两根电弧须。ADD 混合由场景材质给，贴图只管形。"""
    s = Svg(28, 10)
    s.poly([(2, 5), (9, 2), (22, 2.5), (26, 5), (22, 7.5), (9, 8)], PLASMA_DEEP)
    s.poly([(5, 5), (10, 3.2), (21, 3.6), (24, 5), (21, 6.4), (10, 6.8)],
           PLASMA_BLUE, 0.9)
    s.poly([(7, 4.6), (14, 3.9), (22, 4.6), (22, 5.4), (14, 6.1), (7, 5.4)],
           PLASMA_WHITE)
    s.line(1, 3.5, 5, 4.6, PLASMA_BLUE, 1.1, 0.8)
    s.line(1, 6.5, 5, 5.4, PLASMA_BLUE, 1.1, 0.8)
    return s


def sentinel_body():
    """第三章 BOSS v3 强袭悬空机甲「哨兵」260x180=碰撞体 body_size，原点(130,90)，
    原生朝左。从零设计（非白鲸改）：右肩单 Pod（双仓）+ 单臂电浆重炮 + 反关节
    悬垂双腿 + 背包双喷口。比例账见 提案_v3_哨兵重设计.md §1。
    v3b：砍掉前（左）肩 Pod——弹雨只留右肩双仓口，4 发回绕复用（同 ch1 phase2
    惯例），前肩腾空后独眼/重炮剪影更突出（用户返工：留右边发射仓+两枪口）。
    骨架锚点（Visuals = 画布 − (130,90)）：
      独眼 (70,58)→EyeGlow (-60,-32) scale1.2；
      弹雨仓口 ×2 (151/167, 26)→(21/37, -64)，弹雨预警 (159,26)→(29,-64)；
      炮臂枢 (86,86)→ArmPivot (-44,-4)、枪口=臂局部 (-104,0)（见 sentinel_gun）；
      布雷闸 (122,138)→BayPort (-8,48)；
      推进焰节点 ×2 (218,62)/(218,90)→(88,-28)/(88,0)（fx_flame 琥珀 ADD，_tick_visual 脉动）。"""
    s = Svg(260, 180)
    # ---- 远侧腿（BELLY 压暗，先画被躯干压住）----
    s.poly([(116, 126), (148, 132), (146, 152), (120, 146)], BELLY)
    s.poly([(120, 146), (144, 152), (148, 170), (124, 172)], BELLY)
    s.poly([(120, 170), (150, 172), (152, 178), (118, 178)], BELLY)
    s.circle(134, 132, 5, GAP)
    # ---- 背包推进器（挂躯干后，双喷口朝后）----
    s.poly([(150, 44), (196, 50), (196, 108), (150, 104)], BODY)
    s.poly([(150, 44), (196, 50), (196, 55), (150, 49)], LIGHT)
    s.line(152, 50, 152, 104, GAP, 2, 0.7)           # 背包-躯干分缝
    for y0 in (52, 80):                              # 双喷口（出口心 ~(215,y0+10)）
        s.poly([(196, y0), (215, y0 + 6), (215, y0 + 14), (196, y0 + 20)], BELLY)
        s.poly([(197, y0 + 4), (212, y0 + 8), (212, y0 + 12), (197, y0 + 16)], GAP)
    # ---- 后肩 Pod（双仓）----
    s.poly([(142, 42), (172, 42), (170, 50), (144, 50)], BODY)        # Pod 颈座
    s.poly([(140, 46), (138, 24), (143, 16), (171, 16), (176, 24), (174, 46)], BODY)
    s.poly([(143, 16), (171, 16), (170, 20), (144, 20)], LIGHT)
    s.rect(146, 23, 10, 6, GAP)                      # 仓口 (151,26)
    s.rect(162, 23, 10, 6, GAP)                      # 仓口 (167,26)
    s.rect(144, 29, 14, 2, LIGHT, 0.6)
    s.rect(160, 29, 14, 2, LIGHT, 0.6)
    s.poly([(140, 32), (160, 30), (158, 42), (142, 44)], CAMO, 0.3)
    # ---- 躯干 ----
    s.poly([(66, 50), (150, 46), (172, 54), (172, 100), (160, 112), (78, 112),
            (62, 102), (62, 62)], BODY)
    s.poly([(66, 50), (112, 48), (108, 58), (68, 60)], LIGHT, 0.85)   # 胸甲受光
    s.rect(78, 108, 82, 4, BELLY)
    s.rect(120, 52, 2, 56, GAP, 0.5)                 # 板缝
    s.rect(66, 78, 104, 2, GAP, 0.4)
    for vy in (60, 70, 80):                          # 后侧散热栅
        s.rect(150, vy, 16, 3, GAP)
    s.rect(70, 96, 26, 5, RED, 0.85)                 # 敌识别条
    s.poly([(80, 64), (120, 60), (112, 76), (76, 80)], CAMO, 0.35)    # 雪地迷彩
    s.poly([(130, 88), (162, 86), (158, 100), (128, 100)], CAMO, 0.3)
    s.rect(56, 51.5, 28, 13, GAP)                    # 独眼窝
    s.circle(70, 58, 6.5, RED)                       # 独眼（halo 走 EyeGlow 节点）
    s.line(60, 52, 52, 38, LIGHT, 2)                 # 天线
    s.circle(51.5, 37, 1.5, RED, 0.9)
    # ---- 裙甲 + 布雷闸 ----
    s.poly([(84, 112), (150, 112), (154, 126), (146, 142), (88, 142), (80, 126)], BODY)
    s.rect(84, 112, 66, 3, LIGHT, 0.7)
    s.rect(104, 134, 36, 8, GAP)                     # 布雷闸（锚 (122,138)=BayPort）
    s.rect(104, 134, 36, 2, LIGHT, 0.6)
    for i, bx in enumerate(range(106, 138, 6)):      # 闸口黄黑警示边
        s.rect(bx, 140, 3, 2, YELLOW if i % 2 == 0 else GAP, 0.85)
    # ---- 近侧腿（反关节悬垂）----
    s.poly([(92, 126), (128, 130), (124, 152), (96, 148)], BODY)
    s.poly([(98, 146), (124, 152), (130, 172), (104, 174)], BODY)
    s.poly([(100, 172), (132, 174), (134, 178), (96, 178)], BELLY)
    s.line(98, 146, 124, 152, LIGHT, 1.5, 0.6)
    s.circle(110, 130, 6, GAP)                       # 髋关节
    s.circle(118, 150, 5, GAP)                       # 膝关节
    s.rect(108, 164, 14, 3, GAP)                     # 胫部挂载
    # ---- 前肩 Pod 已砍（v3b：弹雨只留右肩双仓口；前肩腾空突出独眼与重炮）----
    return s


def sentinel_gun():
    """哨兵电浆重炮臂 130x40（ArmPivot 挂件，pivot=肩关节画布 (112,20)）。
    枪口轴线 y20，枪口尖端 (8,20)=Muzzle（臂局部 (-104,0)）。
    造型：肩关节座 + 机匣 + 重管（L/D≈6.4）+ 三道冰蓝电浆线圈（弹种签名色，
    与 plasma_bolt/mine 同语言）+ 膛口白热芯。管口径 10（直射矢弹出膛余量）。"""
    s = Svg(130, 40)
    s.rect(96, 4, 32, 32, BODY)                      # 肩关节座
    s.rect(96, 4, 32, 5, LIGHT)
    s.circle(112, 20, 8, GAP)                        # 枢轴销
    s.rect(94, 6, 10, 4, GAP)                        # 排气栅
    s.rect(58, 10, 42, 22, BODY)                     # 机匣
    s.rect(58, 10, 42, 5, LIGHT)
    s.rect(58, 27, 42, 5, BELLY)
    s.rect(64, 28, 16, 3, RED, 0.85)                 # 敌识别条
    s.rect(14, 15, 48, 11, BODY)                     # 重管
    s.rect(14, 15, 48, 3, LIGHT, 0.6)
    for fx in (24, 34, 44):                          # 散热鳍
        s.rect(fx, 13, 2.5, 15, GAP)
    for cx in (29, 39, 49):                          # 电浆线圈（签名冰蓝）
        s.rect(cx, 16, 3, 9, PLASMA_BLUE, 0.9)
    s.rect(10, 13, 6, 15, LIGHT)                     # 膛口环
    s.rect(6, 17, 5, 7, GAP)                         # 膛口
    s.rect(7, 18.5, 3, 4, PLASMA_WHITE, 0.95)        # 白热芯
    return s


if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)
    save(far_strip(), "env_snow_far.svg", """第三章「雪原警戒点」远景条 1024x1300（HillsStrip，tile 1024 视差 0.9）。
高调冰白：天空 #d4e2ea→#f7fafb + 隐日白盘；两层雪岭（#c2d2db/#b0c3cf）+
雷达塔（桁架收分+警灯）与积雪掩体剪影 #8ba0ab + 雪雾带 + 风掠线。
两侧 24px 留空=平铺接缝纯天空；画布底 1300=世界 730。种子 3031。""")
    save(mid_strip(), "env_snow_mid.svg", """第三章中景条 2048x520 透明底（MidStrip，tile 2048）。
两段各异：A 半埋运输机残骸（红识别带+断翼+盖雪）+雪堆+电线杆垂线 /
B 倾覆货运车厢+集装箱+雷达车。剪影 #5a6a74 族 + 信号红。两侧 40px 留空。
画布底=世界 700。种子 3032。""")
    save(ground_top(), "env_snow_ground_top.svg", """第三章地块表面带 256x56（terrain.gd 平铺，256 相位对齐）。
雪盖公路：顶缘雪檐 3px 受光 + 车辙 + 中线黄虚线 + 雪斑 + 裂缝 + 雪点；
底缘压暗 5px；花纹距边 >=6px。种子 3033。""")
    save(ground_fill(), "env_snow_ground_fill.svg", """第三章地块填充 16x256 竖向渐变（路床向深处压暗，保HUD底衬可读）。""")
    save(ground_strip(), "env_snow_ground.svg", """第三章兜底地面条 256x480（GroundStrip，位于世界 664..1144）：
表面带内容同 ground_top + 深处渐变。""")
    save(deck(), "env_snow_deck.svg", """第三章栈桥桥面 720x26（scaffold_ch3 换装）：
顶缘雪檐 + 积雪钢板（格栅纹）+ 桁架腹杆。桥墩用色走 obstacle.pier_color（章配）。""")
    save(walker_body(), "enemy_snow_walker_body.svg", """第三章步行者「四足炮台」56x52，地面 y=50。
骨架对齐：眼 (15.5,18.3) halo r5.3/core r2.4；肩 joint (16,24) r3.5。
造型：低矮驮载车体 + 前置头楔 + 四足（远对 BELLY/近对 BODY）+ 背囊排气。
前缘 x<6 留空给枪臂。色板：LIGHT #5d6c76 / BODY #39444d / BELLY #2a333a / GAP #161c21 + 红/黄。""")
    save(walker_arm(), "enemy_snow_walker_arm.svg", """第三章步行者枪臂 48x28：长管炮（细长管+顶置瞄具+下挂导轨）。
肩 joint (36,8)、枪口尖端 ~(2,14)（Muzzle=臂画布 (6,15)）。""")
    save(drone_body(), "enemy_snow_drone.svg", """第三章无人机「四旋翼侦察机」38x42（悬浮）。
骨架对齐：眼 (12,14.4) halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。
造型：双刃边旋翼条 + 斜撑臂 + 中央舱体 + 腹挂传感器球 + 起落橇。""")
    save(drone_arm(), "enemy_snow_drone_arm.svg", """第三章无人机枪臂 32x16。肩 joint (28,8)、枪口尖端 ~(12,9.5)（Muzzle=臂画布 (13,11)）。""")
    save(shield_body(), "enemy_snow_shield_body.svg", """第三章盾卫「塔盾重步卫」56x52，地面 y=50。
骨架对齐：眼 (23.5,18.3) halo r5.3/core r2.4（盾/舱交界窝）；肩 joint (24,24)（复用本章枪臂）。
造型：通高塔盾（前缘受光+黄黑斜纹）+ 后置舱体 + 双足 + 滑鞋。""")
    save(elite_body(), "enemy_snow_elite_body.svg", """第三章精英「铲雪履带垂发车」60x80，地面 y=80。
骨架对齐：眼 (19,26.5)；两仓口 (38.5,1.5)/(49.5,1.5)=ArmPivot(44,1.5)±5.5；
造型：垂发方舱（平顶双盖）+ 前置铲雪犁 + 履带裙 + 雷达桅杆。""")
    save(plasma_missile(), "missile_plasma.svg", """电浆矢弹 32x16，原点(16,8)，+X=弹头（PlasmaMissile 挂 Sprite2D 随弹体轴转）。
白热芯+冰蓝电离鞘+深电蓝壳+尾部电弧须；尾迹/爆闪粒子见 plasma_missile.gd。
伤害模型=HeavyMissile 原样（换皮不换语法，见提案_v2 §1）。""")
    save(plasma_bolt(), "fx_plasma_bolt.svg", """电弧段贴图 28x10（fx 规约：粒子贴图，色相不带状态语义）。
宽线冰蓝晕+细线白热芯；missile_plasma_trail/plasma_burst/fx_plasma_mine 共用。""")
    save(plasma_mine(), "fx_plasma_mine.svg", """电浆浮雷 v2 64x64，原点(32,32)=判定圆心（plasma_mine.gd Sprite2D 本体；判定不变纯视觉放大）。
水雷剪影：球壳+8 电极柱（冰蓝触点）+独眼红核（敌语汇）+静态弧；
蓄能呼吸/引信快闪走 modulate 脉冲。v2=用户反馈"太小读不出是雷"返工。""")
    save(plasma_bolt_fx(), "plasma_bolt.svg", """电浆矢弹贴图 28x10（plasma_bolt.tscn 直射弹本体，+X 弹头）。
六边形能量镖：深电蓝壳+冰蓝鞘+白热芯+尾部电弧须；ADD 材质在场景。""")
    save(sentinel_body(), "boss_snow_body.svg", """第三章 BOSS v3 强袭悬空机甲「哨兵」260x180=碰撞体 body_size，原点(130,90)，原生朝左。
从零设计（白鲸整体废弃）：宽肩双 Pod（四联电浆垂发仓口 (71/87/151/167,26)）+
单臂电浆重炮（枢 (86,86)，见 sentinel_gun）+ 腰部布雷闸（锚 (122,138)=BayPort (-8,48)）+
反关节悬垂双腿 + 背包双喷口（推进焰节点 (218,62)/(218,90)→Visuals (88,-28)/(88,0)）。
独眼 (70,58)→EyeGlow (-60,-32) scale1.2。设计正本=提案_v3_哨兵重设计.md。""")
    save(sentinel_gun(), "boss_snow_gun.svg", """哨兵电浆重炮臂 130x40（ArmPivot 挂件，pivot=肩关节 (112,20)，tscn offset(-112,-20)）。
枪口轴线 y20、尖端 (8,20)=Muzzle（臂局部 (-104,0)）。三道冰蓝电浆线圈=弹种签名。""")
    print("snowfield chapter assets baked.")
