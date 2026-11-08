# -*- coding: utf-8 -*-
"""第九章「雷暴线场」单位/危险件烘焙：架线与引雷能力套件。

产物（art_proposals/storm_ch9/units/）：
  enemy_storm_walker_body.svg  56x52   步行者换皮「线场巡检」
  enemy_storm_walker_arm.svg   48x28   步行者枪臂
  enemy_storm_drone.svg        38x42   无人机换皮「巡线飞眼」
  enemy_storm_drone_arm.svg    32x16   无人机枪臂
  enemy_storm_shield_body.svg  56x52   盾卫换皮「绝缘屏盾卫」
  enemy_storm_elite_body.svg   60x80   精英「架线」放线车（预教跨缆）
  enemy_storm_elite_arm.svg    34x44   精英双管桩炮架（固定射角不俯仰）
  boss_storm_body.svg          300x180 BOSS「引雷」浮空巡线舰（门型横担）
  boss_storm_arm.svg           96x44   BOSS 前臂绝缘子串（俯仰真瞄，末端放电球=Muzzle，hover 370 时世界 y=370-64=306）
  fx_storm_stake_high.svg      28x118  高缆桩 H=110（双绝缘子盘）锚点=底部接地点 (14,116)
  fx_storm_stake_low.svg       32x48   低缆桩 H=40（短粗）锚点=底部接地点 (16,46)
  fx_storm_rod.svg             36x140  引雷针 针尖 120，锚点=底部接地点 (18,138)
  fx_storm_arc_lash.svg        128x24  普攻断缆弧弹，锚点=中心 (64,12)

参照系=威胁设计_ch9.md §0（唯一口径）。危险件：节点 origin=接地点，
节点局部=(canvas-anchor)*scale；桩顶/针尖=origin+(0,-H)：
  高桩 顶 (14,6)=局部 (0,-110)；低桩 顶 (16,6)=局部 (0,-40)；针尖 (18,18)=局部 (0,-120)。

单位锚点（与第八章既有单位逐像素同位，worlds.md §3 锚点钉死）：
  步行者：眼 (15.5,18.3) halo r5.3/core r2.4；肩 joint (16,24)；地面 y=50。
  枪臂：肩 joint (36,8)、Muzzle 臂画布 (6,15)。
  无人机：眼 (12,14.4) halo r4.4/core r2.0；ArmPivot (15.2,21)；臂 joint (28,8)、Muzzle (13,11)。
  盾卫：眼 (23.5,18.3)；肩 joint (24,24)。
  精英：眼 (19,26.5)；ArmPivot 画布 (44,12)→局部 (14,-28)；臂 34x44 枢端 (17,40)，
        炮口画布 (17,6)=Muzzle 臂局部 (0,-34)。地面 y=80。
  BOSS：独眼条带 y60..66 含 (55,63)；ArmPivot 画布 (150,26)→局部 (0,-64)；
        臂 96x44 枢端 (78,22)，放电球画布 (10,22)=Muzzle 臂局部 (-68,0)；
        BayPort 画布 (150,168)→局部 (0,78)（腹舱双桩口）；
        RodPorts 背部三孔 画布 (206,52)/(230,56)/(254,60)→局部 (56,-38)/(80,-34)/(104,-30)；
        举升喷口 (110,156)/(210,156)。
色板（提案_ch9 §4 焦铁墨紫族）：LIGHT #5a5068 / BODY #3a3346 / BELLY #262032 /
  GAP #191524 / 独眼 #ff4640 / 装饰紫 #6e52a0；危险件带电 芯 #f0e6ff+外辉 #c9a6ff；绝缘子瓷 #b0a4bc 族。
ThorVG 硬约束：无 filter/pattern/use/text/transform；无 rect+rotate。
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))
from generate_proposals import Svg, f, glow_dot  # noqa: E402

OUT = os.path.join(HERE, "units")

LIGHT = "#5a5068"
BODY = "#3a3346"
BELLY = "#262032"
GAP = "#191524"
RED = "#ff4640"
YELLOW = "#d8a021"
VIOLET = "#6e52a0"      # 装饰紫（低明度：Z 标/航标/警示杠，非危险件）
LIVE_CORE = "#f0e6ff"   # 危险件带电芯（高明度白紫）
LIVE_GLOW = "#c9a6ff"   # 危险件带电外辉
WHITE = "#f2f0ff"
PORCE = "#b0a4bc"       # 绝缘子瓷
PORCE_DK = "#7e7290"
CABLE = "#6a6470"


def save(s, name, comment=""):
    head = f"<!-- {comment.strip()} -->\n" if comment else ""
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(s.w)} {f(s.h)}" '
           f'width="{f(s.w)}" height="{f(s.h)}">\n{head}<defs>\n' + "\n".join(s.defs)
           + "\n</defs>\n" + "\n".join(s.body) + "\n</svg>\n")
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as fp:
        fp.write(svg)
    print(name)


def insulator(s, cx, y0, n, r=4.0, step=4.0, col=PORCE):
    """竖直绝缘子串：n 片瓷盘（椭圆）自 y0 向下。"""
    for i in range(n):
        y = y0 + i * step
        s.ellipse(cx, y + 0.8, r, 1.5, PORCE_DK)
        s.ellipse(cx, y, r, 1.4, col)


# ---------------- 杂兵 ----------------
def walker_body():
    s = Svg(56, 52)
    s.poly([(24, 32), (29, 32), (27, 41), (31, 46), (26, 50), (21, 41)], BELLY)
    s.poly([(38, 32), (43, 32), (41, 41), (45, 46), (40, 50), (35, 41)], BELLY)
    # 背负线盘（巡检读法）
    s.circle(37, 10, 6.5, BELLY)
    s.circle(37, 10, 3.6, CABLE)
    s.circle(37, 10, 1.4, GAP)
    s.poly([(8, 14), (30, 12), (42, 16), (46, 24), (42, 33), (10, 33), (5, 26), (5, 19)], BODY)
    s.poly([(8, 14), (30, 12), (42, 16), (43.5, 19), (9.5, 17)], LIGHT)
    # 背顶避雷短针 + 雷光紫灯
    s.line(28, 13, 28, 3.5, GAP, 1.6)
    s.circle(28, 3.2, 1.4, VIOLET, 0.95)
    s.circle(15.5, 18.3, 6.6, GAP)
    s.rect(9.5, 14.5, 12, 7.5, GAP)
    s.circle(15.5, 18.3, 5.3, RED, 0.22)
    s.circle(15.5, 18.3, 2.4, RED, 0.95)
    s.rect(10, 31.5, 34, 1.5, GAP, 0.8)
    s.poly([(10, 33), (42, 33), (38, 37), (14, 37)], BELLY)
    # 侧舷电蚀闪电纹
    s.path("M 26 25 L 31 25 L 29 28 L 35 28", stroke=VIOLET, w=1.4, opacity=0.85)
    s.poly([(11, 33), (16, 33), (15, 41), (19, 46), (14, 50), (8, 42)], BODY)
    s.poly([(30, 33), (35, 33), (35, 42), (39, 46), (34, 50), (29, 42)], BODY)
    s.rect(12, 48.5, 9, 1.8, BELLY)
    s.rect(30, 48.5, 9, 1.8, BELLY)
    s.circle(16, 24, 3.5, GAP)
    return s


def walker_arm():
    s = Svg(48, 28)
    s.circle(36, 8, 3.5, BELLY)
    s.rect(33, 8, 6, 10, BELLY)
    s.rect(17, 10, 19, 9, BODY)
    s.rect(17, 10, 19, 2.5, LIGHT)
    s.rect(5, 12.2, 13, 4, GAP)
    for rx_ in (8, 11.5, 15):            # 管身瓷环（绝缘读法）
        s.rect(rx_, 11.2, 1.6, 6, PORCE_DK)
    s.rect(1, 11, 6, 7, BODY)
    s.rect(1, 13.6, 2.2, 2.8, GAP)
    s.rect(21, 19, 10, 4, BELLY)
    s.circle(33, 13.5, 1.3, VIOLET, 0.9)
    return s


def drone_body():
    s = Svg(38, 42)
    s.line(20, 5.5, 20, 2.5, GAP, 1.2)
    s.circle(20, 2.4, 1.3, VIOLET, 0.95)
    s.ellipse(20, 12, 15, 7, BODY)
    s.ellipse(20, 10.5, 13, 4.5, LIGHT, 0.85)
    s.ellipse(20, 14, 15, 3, BELLY)
    for ax in (8, 32):
        s.line(ax, 15, ax, 20, GAP, 1.2, 0.9)
        insulator(s, ax, 20, 2, r=2.2, step=2.4)
    s.poly([(9, 19), (29, 19), (32, 24), (28, 31), (10, 31), (6, 24)], BODY)
    s.poly([(9, 19), (29, 19), (30, 21), (10, 21)], LIGHT, 0.8)
    s.poly([(11, 28), (27, 28), (25, 31), (13, 31)], BELLY)
    s.rect(7.5, 11.5, 9, 6, GAP)
    s.circle(12, 14.4, 4.4, RED, 0.22)
    s.circle(12, 14.4, 2.0, RED, 0.95)
    # 腹挂巡线钩（挂线滑轮）
    s.rect(18.5, 31, 2.5, 4, GAP)
    s.circle(19.75, 37.5, 3.2, BELLY)
    s.circle(19.75, 37.5, 1.4, CABLE)
    s.rect(15, 22.5, 8, 2.2, VIOLET, 0.8)
    return s


def drone_arm():
    s = Svg(32, 16)
    s.circle(28, 8, 2.5, BELLY)
    s.rect(18, 6.5, 10, 5.5, BODY)
    s.rect(18, 6.5, 10, 2, LIGHT)
    s.rect(13.5, 8, 5, 3, GAP)
    s.rect(11, 7.5, 3, 4.5, BODY)
    s.circle(11.8, 9.5, 1.0, GAP)
    s.circle(25, 10.5, 1.0, VIOLET, 0.9)
    return s


def shield_body():
    s = Svg(56, 52)
    s.poly([(12, 42), (18, 42), (16, 50), (9, 50)], BELLY)
    s.rect(46, 18, 6, 15, BELLY)
    s.line(44, 11, 47, 3, GAP, 1.5)
    s.circle(47.3, 2.5, 1.3, VIOLET, 0.95)
    s.poly([(25, 10), (45, 10), (49, 18), (49, 36), (42, 42), (28, 42), (25, 38)], BODY)
    s.poly([(25, 10), (45, 10), (46.5, 13.5), (26.5, 13.5)], LIGHT)
    s.rect(31, 17, 11, 3.5, GAP)
    # 塔盾=绝缘屏：竖瓷伞裙
    s.poly([(5, 10), (22, 10), (25, 14), (25, 44), (21, 47), (7, 47), (4, 42), (4, 14)], BODY)
    s.poly([(4, 14), (7, 11.5), (7, 45), (4, 40)], LIGHT, 0.6)
    for sy in range(15, 45, 5):
        s.rect(7, sy, 15, 2.2, PORCE_DK, 0.75)
        s.rect(7, sy, 15, 0.9, PORCE, 0.6)
    s.path("M 17 18 L 11 28 L 16 28 L 10 40", stroke=VIOLET, w=1.8, opacity=0.8)
    s.rect(6, 47, 13, 3, BELLY)
    s.rect(18, 14, 10, 8, GAP)
    s.circle(23.5, 18.3, 5.3, RED, 0.22)
    s.circle(23.5, 18.3, 2.4, RED, 0.95)
    s.circle(24, 24, 3.5, GAP)
    s.poly([(30, 42), (36, 42), (38, 49), (31, 49)], BODY)
    s.rect(29, 47.5, 11, 2.2, BELLY)
    s.rect(32, 34, 9, 2.5, VIOLET, 0.8)
    return s


# ---------------- 精英「架线」放线车 ----------------
def elite_body():
    s = Svg(60, 80)
    s.rect(4, 58, 54, 8, BELLY)
    for wx, wy, r in ((14, 70, 8), (32, 72, 7), (48, 70, 8)):
        s.circle(wx, wy, r, GAP)
        s.circle(wx, wy, r - 3.2, BODY)
        s.circle(wx, wy, 1.6, BELLY, 0.9)
    s.poly([(4, 42), (58, 42), (58, 58), (4, 58)], BODY)
    s.poly([(4, 42), (58, 42), (57, 44.5), (5, 44.5)], LIGHT, 0.7)
    for i, hx in enumerate(range(22, 56, 6)):
        s.rect(hx, 52, 2.5, 3.5, VIOLET if i % 2 == 0 else GAP, 0.8)
    # 驾驶眼塔
    s.poly([(8, 22), (30, 22), (32, 28), (32, 42), (8, 42)], BODY)
    s.rect(8, 22, 22, 3, LIGHT)
    s.rect(12, 23, 14, 7, GAP)
    s.circle(19, 26.5, 5.3, RED, 0.22)
    s.circle(19, 26.5, 2.4, RED, 0.95)
    s.rect(10, 33, 20, 4, GAP)
    s.poly([(2, 50), (8, 46), (10, 46), (10, 60), (4, 60), (0, 56)], BELLY)
    # 炮架基座（臂=独立件，塔环 (44,12)）
    s.poly([(37, 44), (51, 44), (49, 16), (39, 16)], BODY)
    s.rect(39, 14, 10, 2.5, LIGHT)
    s.circle(44, 12, 4.5, GAP)
    s.circle(44, 12, 2.2, BELLY)
    # 放线绞盘（能力签名件：大线鼓+备桩）
    s.circle(28, 48, 7, BELLY)
    s.circle(28, 48, 5, CABLE)
    s.circle(28, 48, 2.2, GAP)
    s.path("M 28 41 Q 40 36 41 22", stroke=CABLE, w=1.3, opacity=0.9)
    s.rect(52, 26, 4, 18, BELLY)                 # 尾部备桩架
    insulator(s, 54, 28, 3, r=2.6, step=3.6)
    s.circle(55, 22, 1.4, VIOLET, 0.95)
    return s


def elite_arm():
    """双管桩炮架 34x44，枢端 (17,40)，炮口中心 (17,6)=Muzzle 臂局部 (0,-34)。"""
    s = Svg(34, 44)
    s.rect(10, 32, 14, 10, BELLY)
    s.circle(17, 40, 3.4, BELLY)
    # 双管（高/低桩各一管：左细高、右粗短的口径读法）
    s.rect(11, 8, 5, 26, BODY)
    s.rect(18, 8, 6, 26, BODY)
    s.rect(11, 8, 1.6, 26, LIGHT, 0.8)
    s.rect(18, 8, 1.8, 26, LIGHT, 0.8)
    s.rect(9.5, 4, 8, 5, GAP)                    # 炮口箍
    s.rect(16.5, 4, 9, 5, GAP)
    s.circle(13.5, 6, 1.6, PORCE)                # 管口露桩顶瓷盘
    s.circle(21, 6, 2.0, PORCE)
    s.rect(9, 20, 17, 3, BELLY)                  # 管箍
    s.circle(26, 28, 1.2, VIOLET, 0.9)
    return s


# ---------------- BOSS「引雷」浮空巡线舰 ----------------
def boss_body():
    s = Svg(300, 180)
    # 船体：门型横担下的检修舱
    s.poly([(8, 84), (36, 54), (140, 52), (238, 56), (286, 66), (294, 90),
            (288, 122), (244, 146), (186, 162), (118, 164), (64, 154), (22, 126)], BODY)
    s.poly([(36, 54), (140, 52), (238, 56), (282, 65), (278, 71), (236, 62),
            (140, 58), (42, 60)], LIGHT, 0.7)
    s.poly([(22, 126), (64, 154), (118, 164), (186, 162), (240, 146),
            (230, 138), (120, 152), (66, 140), (30, 118)], BELLY)
    s.rect(60, 92, 170, 2, GAP, 0.3)
    # 门型横担（两立柱+横梁，签名件）
    s.rect(96, 8, 8, 48, BELLY)                  # 前立柱 x96..104
    s.rect(196, 8, 8, 50, BELLY)                 # 后立柱
    s.rect(70, 4, 160, 10, BODY)                 # 横梁 y4..14
    s.rect(70, 4, 160, 2.5, LIGHT, 0.8)
    for lx in range(78, 226, 12):                # 桁格
        s.line(lx, 6.5, lx + 6, 14, GAP, 1.2, 0.6)
    # 横担两端垂绝缘子串（后端；前端=独立臂件位 ArmPivot 在 (150,26) 中央座）
    s.line(226, 14, 226, 20, GAP, 1.6)
    insulator(s, 226, 22, 5, r=5, step=4.5)
    s.circle(226, 46, 3.2, BELLY)
    s.line(74, 14, 74, 20, GAP, 1.6)
    insulator(s, 74, 22, 5, r=5, step=4.5)
    s.circle(74, 46, 3.2, BELLY)
    # ArmPivot 枢座 (150,26)：座裙底 54 埋进甲板
    s.rect(136, 14, 28, 40, BELLY)
    s.rect(138, 14, 24, 3, LIGHT, 0.7)
    s.circle(150, 26, 5, GAP)
    s.circle(172, 36, 1.8, WHITE, 0.9)
    # 背部 RodPorts 三孔（针露头）
    for rx, ry in ((206, 52), (230, 56), (254, 60)):
        s.rect(rx - 7, ry - 2, 14, 8, GAP)
        s.rect(rx - 4.5, ry, 9, 4, "#0d0a14")
        s.line(rx, ry + 2, rx, ry - 8, PORCE, 1.6)
        s.circle(rx, ry - 8.5, 1.6, VIOLET, 0.95)
    # 腹舱双桩口 BayPort (150,168)
    s.rect(128, 150, 44, 14, GAP)
    s.rect(128, 150, 44, 3, LIGHT, 0.5)
    s.rect(132, 157, 16, 8, "#0d0a14")
    s.rect(152, 157, 16, 8, "#0d0a14")
    s.circle(140, 161, 2.2, PORCE, 0.9)
    s.circle(160, 161, 2.2, PORCE, 0.9)
    s.circle(150, 146, 1.8, VIOLET, 0.95)
    # 舷窗带 + 驾驶楼
    for wx in range(214, 270, 14):
        s.rect(wx, 78, 7, 6, "#d8c8f0", 0.7)
    s.poly([(110, 60), (134, 58), (132, 76), (112, 78)], GAP, 0.9)
    s.poly([(114, 62), (130, 60), (129, 66), (115, 67)], "#d8c8f0", 0.6)
    glow_dot(s, 200, 4, VIOLET, r=2.2, halos=((5, 0.35), (9, 0.13)))   # 横担顶航标
    glow_dot(s, 286, 92, VIOLET, r=1.8, halos=((4, 0.35), (8, 0.13)))  # 舷尾航标
    # 举升喷口位
    s.rect(98, 148, 24, 10, BELLY)
    s.rect(198, 142, 24, 10, BELLY)
    s.ellipse(110, 160, 10, 3, VIOLET, 0.35)
    s.ellipse(210, 154, 10, 3, VIOLET, 0.35)
    # 艏锥 + 独眼条带（锚点 y60..66 含 (55,63)）
    s.poly([(0, 82), (14, 74), (20, 74), (20, 98), (6, 92)], BELLY)
    s.rect(38, 57, 34, 12, RED, 0.18)
    s.rect(42, 60, 26, 6, RED, 0.95)
    # 舷侧闪电纹 + 警示杠
    s.path("M 150 96 L 168 96 L 160 108 L 184 108", stroke=VIOLET, w=2.2, opacity=0.85)
    for i, hx in enumerate(range(88, 116, 7)):
        s.rect(hx, 128, 3, 4, VIOLET if i % 2 == 0 else GAP, 0.8)
    return s


def boss_arm():
    """前臂绝缘子串 96x44（横置，俯仰真瞄）。枢端 (78,22)，放电球 (10,22)=Muzzle。"""
    s = Svg(96, 44)
    s.rect(74, 12, 10, 20, BELLY)
    s.circle(78, 22, 4.4, BELLY)
    s.circle(78, 22, 2.0, LIGHT)
    s.rect(60, 19, 16, 6, BODY)                  # 连接金具
    s.rect(60, 19, 16, 1.8, LIGHT, 0.8)
    s.line(18, 22, 62, 22, GAP, 2.4)             # 芯棒
    for i in range(9):                           # 横置瓷伞裙
        x = 22 + i * 4.6
        s.ellipse(x + 0.8, 22, 1.5, 7.5, PORCE_DK)
        s.ellipse(x, 22, 1.4, 7.2, PORCE)
    s.rect(16, 18, 5, 8, BODY)                   # 均压环座
    s.circle(10, 22, 7, BELLY)                   # 放电球
    s.circle(10, 22, 5, LIVE_GLOW, 0.55)
    s.circle(10, 22, 3, WHITE, 0.95)
    return s


# ---------------- 危险件 ----------------
def stake_high():
    """28x118，接地 (14,116)，顶 (14,6) = 局部 (0,-110)。"""
    s = Svg(28, 118)
    s.poly([(6, 116), (22, 116), (18, 108), (10, 108)], BELLY)   # 地锚脚
    s.rect(11.5, 20, 5, 90, BODY)
    s.rect(11.5, 20, 1.6, 90, LIGHT, 0.8)
    for y in (40, 70, 96):
        s.rect(10, y, 8, 2.4, GAP)
    insulator(s, 14, 10, 2, r=9, step=6)         # 双绝缘子盘（高桩标志）
    s.rect(12, 4, 4, 4, GAP)                     # 缆夹（顶=6）
    return s


def stake_low():
    """32x48，接地 (16,46)，顶 (16,6) = 局部 (0,-40)。"""
    s = Svg(32, 48)
    s.poly([(2, 46), (30, 46), (26, 38), (6, 38)], BELLY)
    s.rect(9, 12, 14, 28, BODY)
    s.rect(9, 12, 3, 28, LIGHT, 0.8)
    for i, y in enumerate(range(16, 38, 5)):     # 斜警示杠
        s.rect(13, y, 9, 2.5, PORCE_DK if i % 2 == 0 else GAP, 0.8)
    s.ellipse(16, 10, 9, 2.4, PORCE)
    s.rect(14, 4, 4, 4, GAP)
    return s


def rod():
    """36x140，接地 (18,138)，针尖 (18,18) = 局部 (0,-120)。杆宽 8（实机比例），
    针顶避雷头 + 充能环（直径 28：r14 环心 (18,34)）。"""
    s = Svg(36, 140)
    s.poly([(6, 138), (30, 138), (24, 126), (12, 126)], BELLY)       # 地锚脚
    s.rect(14, 46, 8, 81, BODY)                                      # 杆身 x14..22 宽 8
    s.rect(14, 46, 2.4, 81, LIGHT, 0.85)
    for y in (60, 84, 108):                                          # 杆箍
        s.rect(12.5, y, 11, 3, GAP)
    # 充能环件（直径 28，暗瓷环；充能时由代码点亮）
    s.circle(18, 34, 14, GAP)
    s.circle(18, 34, 11.5, PORCE_DK)
    s.circle(18, 34, 9, BELLY)
    s.circle(18, 34, 5, BODY)
    # 避雷头（三叉针头 + 中针，针尖 (18,18)）
    s.poly([(18, 18), (20.6, 34), (15.4, 34)], PORCE)
    s.line(12, 32, 10.5, 23, PORCE, 1.6)
    s.line(24, 32, 25.5, 23, PORCE, 1.6)
    s.circle(18, 34, 2.2, PORCE)
    return s


def arc_lash():
    """128x24，锚点中心 (64,12)，+X=飞行方向。"""
    s = Svg(128, 24)
    d = "M 6 14 Q 34 6 64 12 T 122 10"
    s.path(d, stroke=LIVE_GLOW, w=9, opacity=0.45, cap="round")
    s.path(d, stroke=BODY, w=4.5, cap="round")
    s.path(d, stroke=LIVE_CORE, w=1.6, opacity=0.95, cap="round")
    s.circle(122, 10, 3.5, LIVE_CORE, 0.95)
    s.circle(6, 14, 2.5, LIVE_GLOW, 0.8)
    return s


ITEMS = [
    (walker_body, "enemy_storm_walker_body.svg", "第九章步行者换皮「线场巡检」56x52 地面 y=50。眼 (15.5,18.3)；肩 joint (16,24)。"),
    (walker_arm, "enemy_storm_walker_arm.svg", "第九章步行者枪臂 48x28。肩 joint (36,8)；Muzzle 臂画布 (6,15)。"),
    (drone_body, "enemy_storm_drone.svg", "第九章无人机换皮「巡线飞眼」38x42。眼 (12,14.4)；ArmPivot (15.2,21)。"),
    (drone_arm, "enemy_storm_drone_arm.svg", "第九章无人机枪臂 32x16。joint (28,8)；Muzzle (13,11)。"),
    (shield_body, "enemy_storm_shield_body.svg", "第九章盾卫换皮「绝缘屏盾卫」56x52 地面 y=50。眼 (23.5,18.3)；肩 joint (24,24)。"),
    (elite_body, "enemy_storm_elite_body.svg", "第九章精英「架线」放线车 60x80 地面 y=80。眼 (19,26.5)；ArmPivot 画布 (44,12)=局部 (14,-28)，固定射角不俯仰。"),
    (elite_arm, "enemy_storm_elite_arm.svg", "第九章精英双管桩炮架 34x44。枢端 (17,40)；炮口 (17,6)=Muzzle 臂局部 (0,-34)，ThreatFlash 挂此。"),
    (boss_body, "boss_storm_body.svg", "第九章 BOSS「引雷」浮空巡线舰 300x180=碰撞体，原点 (150,90)，原生朝左，hover 370 船底 460。独眼条带 y60..66 含 (55,63)；ArmPivot (150,26)=局部 (0,-64)；BayPort (150,168)=局部 (0,78)；RodPorts (206,52)/(230,56)/(254,60)=局部 (56,-38)/(80,-34)/(104,-30)。"),
    (boss_arm, "boss_storm_arm.svg", "第九章 BOSS 前臂绝缘子串 96x44（俯仰真瞄）。枢端 (78,22)；放电球 (10,22)=Muzzle 臂局部 (-68,0)。"),
    (stake_high, "fx_storm_stake_high.svg", "高缆桩 28x118。锚点画布 (ax,ay)=(14,116) 底部接地点；缆端=桩顶 (14,6)=局部 (0,-110)。"),
    (stake_low, "fx_storm_stake_low.svg", "低缆桩 32x48。锚点画布 (ax,ay)=(16,46) 底部接地点；缆端=桩顶 (16,6)=局部 (0,-40)。"),
    (rod, "fx_storm_rod.svg", "引雷针 36x140。锚点画布 (ax,ay)=(18,138) 底部接地点；针尖 (18,18)=局部 (0,-120)；杆宽 8，充能环直径 28。"),
    (arc_lash, "fx_storm_arc_lash.svg", "普攻断缆弧弹 128x24，锚点中心 (64,12)，+X=飞行方向；带电读色 芯 #f0e6ff+外辉 #c9a6ff，普通混合不 ADD。"),
]

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn, name, c in ITEMS:
        save(fn(), name, c)
