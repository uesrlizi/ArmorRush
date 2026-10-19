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
  boss_snow_body.svg         300x180   BOSS 换皮：武装飞艇「白鲸」（整体重设计）
  boss_snow_gun.svg          110x32    BOSS 机枪臂换皮
  boss_snow_rotor.svg        84x16     BOSS 尾推螺旋桨 blade bar（侧视刃边）
  boss_snow_tailrotor.svg    56x56     BOSS 侧置风扇（整周旋转，四叶）

骨架对齐账（换皮铁律：美术重画、锚点不动）：
  步行者：眼 (15.5,18.3)；肩 joint (16,24)；地面 y=50
  无人机：眼 (12,14.4)；枪口=臂画布 (13,11)
  盾卫：  眼 (23.5,18.3)；肩 joint (24,24)
  精英：  眼 (19,26.5)；两仓口画布 (38.5,1.5)/(49.5,1.5)（=pivot±5.5）
  BOSS：  眼条带 y60..66 含 (55,63)；导弹仓口画布 x 83/105/167/189 @ y26；
          枪口=臂画布 (2,~4)（flip_v 后贴艇艏下颌）；
          尾推桨 bar 心=节点 (120,-18)→画布(270,72)；侧风扇心=节点 (122,20)→画布(272,110)

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

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets"))

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


def boss_body():
    s = Svg(300, 180)
    # ---- 尾鳍（先画，被气囊压住）----
    s.poly([(244, 34), (274, 4), (294, 4), (288, 40)], BODY)       # 上垂尾
    s.poly([(274, 4), (294, 4), (292, 10), (276, 10)], LIGHT)
    s.poly([(246, 112), (272, 142), (292, 142), (286, 108)], BELLY)  # 下垂尾
    # ---- 吊舱（挂在气囊下，先画）----
    s.rect(80, 108, 4, 12, GAP)                    # 吊杆
    s.rect(140, 108, 4, 12, GAP)
    s.poly([(44, 118), (152, 118), (158, 128), (150, 142), (58, 142), (40, 130)], BODY)
    s.poly([(44, 118), (152, 118), (153, 122), (46, 122)], LIGHT, 0.7)
    s.rect(70, 124, 62, 6, GAP)                    # 舷窗带
    s.rect(62, 133, 30, 3, RED, 0.8)               # 敌识别条
    s.circle(100, 144, 3, RED, 0.22)               # 艇腹灯
    s.circle(100, 144, 1.4, RED, 0.85)
    # ---- 侧风扇短舱（右后下，风扇独件整周转）----
    s.rect(252, 94, 46, 30, BODY)
    s.rect(252, 94, 46, 4, LIGHT)
    s.rect(248, 100, 8, 18, BELLY)                 # 支撑
    # ---- 气囊（大椭球，雪地迷彩）----
    s.poly(_ellipse_pts(152, 72, 146, 52), BODY)
    s.poly([(30, 46), (80, 28), (150, 22), (120, 44), (60, 56)], CAMO, 0.4)   # 迷彩块
    s.poly([(180, 26), (240, 34), (264, 52), (200, 46), (172, 36)], CAMO, 0.32)
    s.poly([(60, 34), (110, 24), (160, 21), (210, 24), (196, 32), (150, 30), (104, 34), (72, 40)], LIGHT, 0.4)
    # 板缝
    s.rect(110, 26, 2.5, 88, GAP, 0.35)
    s.rect(190, 24, 2.5, 92, GAP, 0.35)
    s.rect(70, 70, 164, 2.5, GAP, 0.3)
    # 艇鼻帽
    s.poly([(6, 66), (22, 58), (22, 86), (6, 78)], BELLY)
    # ---- 背脊垂发甲板（4 仓口=BOSS_RAIN_COUNT 1:1，仓口画布 x 83/105/167/189 @ y26）----
    s.poly([(60, 34), (74, 18), (198, 18), (212, 34)], BODY)
    s.poly([(74, 18), (198, 18), (196, 22), (76, 22)], LIGHT)
    for mx in (83, 105, 167, 189):                 # 仓口深缝
        s.rect(mx - 5, 23.5, 10, 5, GAP)
        s.rect(mx - 7, 29, 14, 2, LIGHT, 0.6)
    for i, hx in enumerate(range(64, 200, 12)):    # 甲板前缘警示
        s.rect(hx, 34, 6, 4, YELLOW if i % 2 == 0 else GAP, 0.6)
    s.rect(120, 38, 28, 3, RED, 0.75)
    # ---- 独眼条带（眼条 y60..66 含 (55,63)，骑在艇鼻）----
    s.rect(38, 57, 34, 12, RED, 0.18)
    s.rect(42, 60, 26, 6, RED, 0.95)
    # 尾推桨座（桨 bar 独件在画布 (270,72)）
    s.poly([(286, 60), (300, 60), (300, 84), (286, 84)], BELLY)
    return s


def boss_gun():
    """BOSS 机枪臂换皮 110x32（flip_v 后挂艇鼻下颌，枪带画布 y85..117）。
    枪口轴线画布顶 y0..8，枪口尖端画布 (2,~4)=Muzzle。
    造型：单管重炮 + 散热套筒孔 + 后座筒（与前二章双管/机匣箱拉开）。"""
    s = Svg(110, 32)
    s.rect(8, 1, 48, 6, BODY)            # 单管
    s.rect(16, 0, 4, 8, GAP)             # 散热环
    s.rect(26, 0, 4, 8, GAP)
    s.rect(36, 0, 4, 8, GAP)
    s.rect(0, 0, 9, 8, BODY)             # 膛口座
    s.rect(0, 2.5, 3, 3, GAP)            # 膛口
    s.rect(56, 0, 40, 24, BODY)          # 机匣
    s.rect(56, 0, 40, 5, LIGHT)
    s.rect(56, 19, 40, 5, BELLY)
    s.rect(66, 24, 18, 6, BELLY)         # 弹箱
    s.rect(96, 6, 12, 12, GAP)           # 后座筒
    s.rect(92, 9, 5, 3, GAP, 0.9)
    s.rect(92, 15, 5, 3, GAP, 0.9)
    return s


def boss_rotor():
    """BOSS 尾推螺旋桨 blade bar 84x16（侧视刃边，画布心=节点心）。
    节点位：boss_ch3.tscn Rotor=(120,-18) → 艇体画布 (270,72)，bar 覆盖 x228..312
    （桨尖越出画布右缘=推桨在尾鳍之后，正常出画）。"""
    s = Svg(84, 16)
    s.rect(2, 6, 80, 4, GAP)             # 桨叶刃条
    s.rect(4, 6, 12, 4, LIGHT, 0.8)      # 桨尖反光
    s.rect(68, 6, 12, 4, LIGHT, 0.6)
    s.rect(38, 3, 8, 10, BODY)           # 桨毂
    s.rect(40.5, 6, 3, 4, GAP)
    return s


def boss_tailrotor():
    """BOSS 侧置风扇 56x56（整周旋转，画布心=节点 (272,110)，挂短舱侧面）。
    侧视语义：风扇盘平行屏幕→正圆成立；四叶 45/135/225/315（绕 28,28 手工预算，
    内缘 r6 外缘 r19 叶宽半 3.2），毂 BELLY + 红心。"""
    s = Svg(56, 56)

    def blade(deg):
        a = math.radians(deg)
        dx, dy = math.cos(a), math.sin(a)
        px, py = -dy, dx
        inner = (28 + 6 * dx, 28 + 6 * dy)
        outer = (28 + 19 * dx, 28 + 19 * dy)
        return [(inner[0] + 3.2 * px, inner[1] + 3.2 * py),
                (inner[0] - 3.2 * px, inner[1] - 3.2 * py),
                (outer[0] - 3.2 * px, outer[1] - 3.2 * py),
                (outer[0] + 3.2 * px, outer[1] + 3.2 * py)]

    for deg in (45, 135, 225, 315):
        s.poly(blade(deg), LIGHT)
    s.circle(28, 28, 6, BELLY)
    s.circle(28, 28, 2.5, RED, 0.9)
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
    save(boss_body(), "boss_snow_body.svg", """第三章 BOSS 武装飞艇「白鲸」300x180=碰撞体 body_size，原点(150,90)，原生朝左。
整体重设计：椭圆气囊（雪地迷彩块+板缝+艇鼻帽）/ 背脊垂发甲板（4 仓口画布
x 83/105/167/189 @ y26 = boss.gd MissilePorts 1:1）/ 下挂吊舱（舷窗+识别条）/
尾鳍×2 + 尾推桨座（bar 独件画布 (270,72)）+ 侧风扇短舱（圆扇独件画布 (272,110)）。
独眼条带 y60..66 含 (55,63)，EyeGlow 节点 (-95,-27) scale1.2 照摆；
机枪臂独件 pivot(-51,15) 枪带画布 y85..117（flip_v 贴艇鼻下颌）。""")
    save(boss_gun(), "boss_snow_gun.svg", """第三章 BOSS 机枪臂 110x32（tscn flip_v=true、offset(-95,-20)）。
枪口轴线画布顶 y0..8，枪口尖端 (2,~4)=Muzzle(-93,8)。单管重炮+散热环+后座筒。""")
    save(boss_rotor(), "boss_snow_rotor.svg", """第三章 BOSS 尾推螺旋桨 blade bar 84x16。
节点位（boss_ch3.tscn）Rotor=(120,-18) → 艇体画布 (270,72)；桨尖越出画布右缘
=推桨在尾鳍之后（正常出画，同章1旋翼 overshoot 语言）。""")
    save(boss_tailrotor(), "boss_snow_tailrotor.svg", """第三章 BOSS 侧置风扇 56x56（整周旋转，画布心=节点 (272,110)）。
风扇盘平行屏幕→正圆成立；四叶 45/135/225/315（绕 28,28 预算）+ 毂 + 红心。""")
    print("snowfield chapter assets baked.")
