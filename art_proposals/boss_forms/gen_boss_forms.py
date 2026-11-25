# -*- coding: utf-8 -*-
"""BOSS 形态重做：第六/八/九/十章 BOSS 机体（body）唯一生成器。

六章原先同用一套「艏锥+胖船体+独眼条带+舷窗带」的船形骨架，同屏读法撞车；
本脚本为其中四章按能力给出专属剪影：
  boss_red_body.svg     第六章「赤轮」  斗轮挖掘机（斜臂桁架+A 形桅+配重臂+回转机房）
  boss_salt_body.svg    第八章「盐磨」  聚光镜碟（3/4 视镜碟+焦点接收头+三撑杆）
  boss_storm_body.svg   第九章「引雷」  浮空电塔（横担桁架塔头+收腰塔身+举升舱+前部天线桅；
                        球状闪电语汇：机体上无电线/绝缘子串/导线读法，攻击读法全部走电珠）
  boss_sulfur_body.svg  第十章「井口」  自升式钻井平台（双桩腿上翘+井架+直升机坪生活楼）

产物写到 art_proposals/boss_forms/units/，人工拷进 assets/world_N/。
各章 bake_*_units.py 的 boss_body() 已改为转调本文件，重烘焙不会把旧船形写回。

锚点契约（与旧机体逐像素同位，玩法/探针账不动）：画布 300x180，原点 (150,90)，
局部=画布-(150,90)；碰撞体 280x150=画布 x10..290 y15..165；原生朝左。
  六  Wheel 毂 (44,120)；Rack 枢 (210,38)（架底画布 y42，座裙顶 38 重叠 4px）；
      BayPort (150,170)；举升喷口焰 (120,154)/(230,154)（节点位不变）。
      独眼改到驾驶室 (95,60)→EyeGlow 局部 (-55,-30)（斗轮最高斗沿在 x82 处 y70，眼带 y57..63 不被盖）。
  八  ArmPivot (150,26)（镜阵翼枢座=碟沿顶）；BayPort (150,168)；
      独眼改到焦点接收头 (69,90)→EyeGlow 局部 (-81,0)；
      举升喷口焰 (114,160)/(206,160)→Thruster 局部 (-36,70)/(56,70)。
  九  ArmPivot (40,20)（前部天线桅顶电珠=球状闪电出弹源，画布账：桅 x40、珠心 (40,20)，
      局部 (-110,-70)，固定天线不俯仰——tscn 侧覆写 _arm_tracks_pitch=false）；
      BayPort (150,168)；RodPorts (206,52)/(230,56)/(254,60)
      （右横担顶缘 y=42+(x-170)/6：206→48、230→52、254→56，孔顶 ry-2 全落横担内）；
      独眼沿用 (55,63)（左横担端传感舱）；旧举升喷口座 (110,160)/(190,160) 改挂侧置
      螺旋桨（prop_face.svg 竖置+prop_blades.svg 自转 12 rad/s，节点局部 (-40,62)/(40,62)=画布 (110,152)/(190,152)，
      机体上无焰无缆）。
  十  ArmPivot (150,26)（井架上段枢座）；NozzlePort (4,144)；DrillPort (150,168)（井架正下方
      防喷器组+导管+钻头）；VentPort (246,46)；独眼沿用 (55,63)（生活楼前脸）；
      举升喷口焰 (110,148)/(210,148)→局部 (-40,58)/(60,58)。
最低点：六=斗轮独立件（旧账 454 不变），机体 ≤166；八/九/十 ≤168（同旧腹口）。
ThorVG 硬约束：无 filter/pattern/use/text/transform；无 rect+rotate。
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))
from generate_proposals import Svg, f, glow_dot  # noqa: E402

OUT = os.path.join(HERE, "units")
RED = "#ff4640"
YELLOW = "#d8a021"


def save(s, name, comment):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(s.w)} {f(s.h)}" '
           f'width="{f(s.w)}" height="{f(s.h)}">\n<!-- {comment.strip()} -->\n<defs>\n'
           + "\n".join(s.defs) + "\n</defs>\n" + "\n".join(s.body) + "\n</svg>\n")
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as fp:
        fp.write(svg)
    print(name)


def beam(s, x1, y1, x2, y2, w, fill, opacity=None):
    """两点间实心梁（四边形，宽 w，垂直方向对称外扩）。返回上/下弦端点。"""
    dx, dy = x2 - x1, y2 - y1
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln * w / 2.0, dx / ln * w / 2.0
    a = (x1 + nx, y1 + ny)
    b = (x2 + nx, y2 + ny)
    c = (x2 - nx, y2 - ny)
    d = (x1 - nx, y1 - ny)
    s.poly([a, b, c, d], fill, opacity)
    return a, b, d, c


def webs(s, p0, p1, q0, q1, n, col, w=1.6, opacity=None):
    """桁架腹杆：上弦 p0→p1、下弦 q0→q1 之间 n 格之字。"""
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        ax = p0[0] + (p1[0] - p0[0]) * t0
        ay = p0[1] + (p1[1] - p0[1]) * t0
        bx = q0[0] + (q1[0] - q0[0]) * t1
        by = q0[1] + (q1[1] - q0[1]) * t1
        s.line(ax, ay, bx, by, col, w, opacity)


def eye_band(s, x, y):
    """独眼条带（同旧机体：外晕 34x12 + 芯 26x6），(x,y)=条带芯左上。"""
    s.rect(x - 4, y - 3, 34, 12, RED, 0.18)
    s.rect(x, y, 26, 6, RED, 0.95)


# ============================================================
# 第六章「赤轮」：斗轮挖掘机
# ============================================================
def red_body():
    LIGHT, BODY, BELLY, GAP = "#a85a3a", "#6e3424", "#4e2418", "#33180e"
    GOLD, RUST_RIM, WHITE_HOT = "#ffb347", "#d98c5e", "#f2f0ff"
    s = Svg(300, 180)
    # ---- A 形桅（机房前顶 → 顶点 (160,6)）----
    s.line(148, 54, 159, 6, BELLY, 5)
    s.line(176, 54, 161, 6, BELLY, 5)
    s.line(152, 36, 170, 36, GAP, 2)
    s.line(155, 22, 166, 22, GAP, 2)
    s.circle(160, 6, 4, BODY)
    s.circle(160, 6, 1.6, LIGHT)
    # ---- 拉索：桅顶→斗轮臂中前段 / 桅顶→配重 ----
    for o in (0, 3):
        s.line(159, 7 + o, 72, 100 + o, GAP, 1.3, 0.85)
        s.line(161, 7 + o, 262, 24 + o, GAP, 1.3, 0.85)
    # ---- 配重臂 + 配重块（右上）----
    a, b, d, c = beam(s, 232, 56, 266, 36, 12, BELLY)
    webs(s, a, b, d, c, 3, GAP, 1.4)
    s.poly([(254, 22), (294, 20), (296, 58), (258, 62)], BELLY)
    s.poly([(254, 22), (294, 20), (294, 25), (255, 27)], RUST_RIM, 0.7)
    for i, hx in enumerate(range(262, 292, 6)):
        s.rect(hx, 50, 3, 6, YELLOW if i % 2 == 0 else GAP, 0.85)
    # ---- 回转机房（x140..242）----
    s.poly([(144, 54), (232, 50), (242, 60), (242, 110), (146, 112), (138, 100)], BODY)
    s.poly([(144, 54), (232, 50), (238, 56), (146, 59)], LIGHT, 0.75)
    s.poly([(138, 100), (242, 98), (242, 110), (146, 112)], BELLY)
    s.rect(178, 60, 2.5, 38, GAP, 0.35)
    for wx in range(186, 234, 13):                       # 矿灯金舷窗
        s.rect(wx, 70, 7, 6, GOLD, 0.8)
    s.rect(150, 82, 22, 3, RED, 0.8)                     # 识别条
    # 背甲炮座（Rack 枢 (210,38)；架底画布 y42 压进座裙顶 38）
    s.rect(190, 38, 40, 14, BELLY)
    s.rect(192, 36, 36, 3, LIGHT, 0.7)
    s.circle(236, 46, 2, WHITE_HOT, 0.9)                 # 就绪白热灯
    # ---- 回转支承 + 举升底盘 ----
    s.rect(140, 110, 100, 12, GAP)
    for gx in range(146, 236, 10):
        s.rect(gx, 113, 5, 6, BELLY)
    s.poly([(116, 122), (246, 122), (254, 136), (238, 150), (122, 150), (108, 136)], BODY)
    s.poly([(116, 122), (246, 122), (250, 128), (112, 128)], LIGHT, 0.6)
    s.poly([(108, 136), (254, 136), (238, 150), (122, 150)], BELLY)
    for i, hx in enumerate(range(184, 226, 7)):          # 危险黄警示带
        s.rect(hx, 129, 3, 4, YELLOW if i % 2 == 0 else GAP, 0.8)
    # 举升喷口座（焰 (120,154)/(230,154)）
    s.rect(108, 144, 24, 10, BELLY)
    s.rect(218, 144, 24, 10, BELLY)
    # 腹舱口（BayPort (150,170)：凿岩装药出舱）
    s.rect(126, 148, 48, 16, GAP)
    s.rect(126, 148, 48, 3, LIGHT, 0.5)
    s.rect(132, 156, 36, 8, "#241008")
    s.circle(150, 144, 1.8, YELLOW, 0.9)
    # ---- 斗轮臂（毂 (44,120) → 机房前脸 (150,80)），开口桁架 + 输送带 ----
    a, b, d, c = beam(s, 44, 120, 150, 80, 18, BELLY)
    s.poly([a, b, (b[0] + 1.4, b[1] + 3.6), (a[0] + 1.4, a[1] + 3.6)], BODY)
    s.poly([d, c, (c[0] - 1.4, c[1] - 3.6), (d[0] - 1.4, d[1] - 3.6)], BODY)
    s.line(a[0], a[1], b[0], b[1], LIGHT, 1.6, 0.8)
    webs(s, a, b, d, c, 9, BODY, 2.2)
    s.line(60, 106, 146, 74, RUST_RIM, 1.6, 0.7)         # 输送带受光
    s.circle(44, 120, 9, BELLY)                          # 毂座（被斗轮毂盖住大半）
    # ---- 斗轮驾驶室（骑在斗轮臂上，独眼 (95,60)）----
    s.rect(92, 72, 10, 22, BELLY)                        # 立柱，脚埋进臂顶
    s.poly([(78, 50), (116, 47), (118, 74), (82, 78)], BODY)
    s.poly([(78, 50), (116, 47), (116, 51), (79, 54)], LIGHT, 0.8)
    s.poly([(78, 50), (82, 78), (74, 68)], BELLY)        # 前斜脸
    eye_band(s, 82, 57)
    s.rect(104, 64, 10, 6, GOLD, 0.55)                   # 侧窗
    return s


# ============================================================
# 第八章「盐磨」：聚光镜碟
# ============================================================
def salt_body():
    LIGHT, BODY, BELLY, GAP = "#4e6a5e", "#2e4a42", "#1e332e", "#142320"
    PINK, WHITE, SALT = "#f2789f", "#f2f0ff", "#e8dcc0"
    GLASS, GLASS_DK = "#c8dcd4", "#9fc4b8"
    s = Svg(300, 180)
    cx, cy, rx, ry = 168.0, 90.0, 40.0, 74.0          # 碟沿椭圆（3/4 视）
    # ---- 碟背壳：沿顶 (168,16) 向右鼓到 (292,90) 再回沿底 (168,164) ----
    s.path(f"M {f(cx)} {f(cy - ry)} A 124 74 0 0 1 {f(cx)} {f(cy + ry)} Z", fill=BODY)
    s.path(f"M {f(cx)} {f(cy - ry)} A 124 74 0 0 1 286 70", stroke=LIGHT, w=3, opacity=0.75)
    s.path(f"M 278 120 A 124 74 0 0 1 {f(cx)} {f(cy + ry)} L {f(cx)} 150 "
           f"A 110 62 0 0 0 268 116 Z", fill=BELLY)
    for k, op in ((0.55, 0.45), (0.8, 0.4)):                 # 背壳肋
        s.path(f"M {f(cx)} {f(cy - ry * k)} A {f(124 * k)} {f(ry * k)} 0 0 1 "
               f"{f(cx)} {f(cy + ry * k)}", stroke=GAP, w=2, opacity=op)
    s.line(cx, cy, 292, cy, GAP, 2, 0.4)
    glow_dot(s, 262, 42, PINK, r=1.8, halos=((4, 0.35), (8, 0.13)))   # 背壳信号灯
    # ---- 镜面：暗镜底 + 环形分块 + 斜向反光 ----
    s.ellipse(cx, cy, rx + 3, ry + 3, BELLY)                  # 碟沿厚度
    s.ellipse(cx, cy, rx, ry, LIGHT)
    for k in (0.72, 0.44):
        s.path(f"M {f(cx)} {f(cy - ry * k)} A {f(rx * k)} {f(ry * k)} 0 1 0 "
               f"{f(cx)} {f(cy + ry * k)} A {f(rx * k)} {f(ry * k)} 0 1 0 "
               f"{f(cx)} {f(cy - ry * k)}", stroke=GLASS_DK, w=1.4, opacity=0.9)
    for i in range(8):                                        # 径向分块缝
        t = i * math.pi / 4.0
        s.line(cx + rx * 0.2 * math.cos(t), cy + ry * 0.2 * math.sin(t),
               cx + rx * math.cos(t), cy + ry * math.sin(t), GLASS_DK, 1.2, 0.8)
    for (x0, y0, x1, y1, w, op) in ((140, 46, 164, 30, 3, 0.8), (136, 70, 176, 40, 2, 0.55),
                                    (176, 112, 196, 96, 2.4, 0.6)):
        s.line(x0, y0, x1, y1, GLASS, w, op, cap="round")
    s.path(f"M {f(cx)} {f(cy - ry)} A {f(rx)} {f(ry)} 0 0 0 {f(cx)} {f(cy + ry)}",
           stroke=GLASS, w=2, opacity=0.6)                    # 碟沿受光（左缘）
    s.circle(cx, cy, 7, BELLY)                                # 碟心毂
    s.circle(cx, cy, 3, GAP)
    # ---- 三撑杆：碟沿顶/碟心/碟沿底 → 焦点接收头 ----
    s.line(96, 84, 150, 30, BODY, 4.5)
    s.line(98, 90, cx - 6, cy, BODY, 3.5)
    s.line(96, 96, 140, 152, BODY, 4.5)
    s.line(96, 84, 150, 30, LIGHT, 1.4, 0.7)
    # ---- 镜阵翼枢座（ArmPivot (150,26)）：坐碟沿顶 ----
    s.rect(138, 18, 26, 18, BELLY)
    s.rect(140, 16, 22, 3, LIGHT, 0.7)
    s.circle(170, 30, 1.8, WHITE, 0.9)                        # 就绪白热灯
    # ---- 举升底舱 + 腹裂地锚口（BayPort (150,168)）----
    s.poly([(108, 146), (212, 146), (220, 156), (206, 166), (114, 166), (100, 156)], BODY)
    s.poly([(108, 146), (212, 146), (216, 151), (104, 151)], LIGHT, 0.6)
    s.rect(104, 152, 20, 10, BELLY)                           # 举升喷口座（焰 (114,160)）
    s.rect(196, 152, 20, 10, BELLY)                           # （焰 (206,160)）
    s.rect(128, 150, 44, 14, GAP)
    s.rect(128, 150, 44, 3, LIGHT, 0.5)
    s.rect(134, 158, 32, 8, "#0d1a15")
    for gx in range(140, 164, 8):
        s.line(gx, 158, gx, 166, BELLY, 1.6, 0.9)
    s.circle(150, 146, 1.8, PINK, 0.9)
    # ---- 焦点接收头（独眼 (69,90)；朝碟一侧=受热口）----
    s.poly([(52, 80), (60, 74), (94, 74), (102, 82), (102, 98), (94, 106),
            (60, 106), (48, 98)], BODY)
    s.poly([(60, 74), (94, 74), (100, 80), (56, 78)], LIGHT, 0.75)
    s.poly([(48, 98), (102, 98), (94, 106), (60, 106)], BELLY)
    eye_band(s, 56, 87)
    s.circle(104, 90, 9, PINK, 0.25)                          # 受热口（白热芯+盐田粉晕）
    s.circle(104, 90, 5, WHITE, 0.95)
    s.circle(104, 90, 2.4, PINK, 0.9)
    # 盐霜
    for (x, y, ex, ey) in ((236, 138, 12, 3), (206, 150, 9, 2.4), (74, 104, 8, 2)):
        s.ellipse(x, y, ex, ey, SALT, 0.45)
    return s


# ============================================================
# 第九章「引雷」：浮空电塔
# ============================================================
def storm_body():
    LIGHT, BODY, BELLY, GAP = "#5a5068", "#3a3346", "#262032", "#191524"
    VIOLET, WHITE = "#6e52a0", "#f2f0ff"
    PORCE, PORCE_DK = "#b0a4bc", "#7e7290"

    s = Svg(300, 180)
    # ---- 收腰塔身（横担底 → 举升舱），开口桁架 + 中轴脊槽 ----
    lx = lambda y: 106 + (y - 64) * 24 / 76            # 左主材 x(y)
    rx_ = lambda y: 194 - (y - 64) * 24 / 76
    s.rect(142, 64, 16, 78, BELLY)                       # 中轴脊槽（分段横撑=桁架脊读法）
    for y in range(74, 140, 12):
        s.line(143, y, 157, y, BODY, 2.2)
    s.rect(142, 64, 3, 78, LIGHT, 0.5)
    levels = (64, 90, 116, 140)
    for y0, y1 in zip(levels, levels[1:]):
        s.line(lx(y0), y0, rx_(y1), y1, BODY, 2.6)
        s.line(rx_(y0), y0, lx(y1), y1, BODY, 2.6)
    for y in levels[1:-1]:
        s.line(lx(y), y, rx_(y), y, BODY, 3)
    s.line(lx(64), 64, lx(140), 140, BODY, 6)
    s.line(rx_(64), 64, rx_(140), 140, BODY, 6)
    s.line(lx(64) - 1.5, 64, lx(140) - 1.5, 140, LIGHT, 1.6, 0.7)
    # ---- 塔头 + 两角（角=post 结构件，不再牵地线）----
    s.poly([(112, 16), (122, 16), (132, 44), (118, 44)], BODY)
    s.poly([(188, 16), (178, 16), (168, 44), (182, 44)], BODY)
    s.circle(117, 18, 3, BELLY)
    s.circle(183, 18, 3, BELLY)
    s.poly([(132, 12), (168, 12), (176, 44), (124, 44)], BODY)
    s.poly([(132, 12), (168, 12), (169, 16), (131, 16)], LIGHT, 0.8)
    s.rect(136, 16, 28, 20, BELLY)
    s.circle(150, 26, 5, GAP)
    s.circle(170, 36, 1.8, WHITE, 0.9)
    glow_dot(s, 150, 6, VIOLET, r=2.2, halos=((5, 0.35), (9, 0.13)))   # 塔顶航标
    # ---- 横担（左 (10,62)→中 (130..170,42)→右 (290,62)；底缘 y64 中→72 端）----
    s.poly([(10, 62), (130, 42), (170, 42), (290, 62), (290, 72), (170, 64),
            (130, 64), (10, 72)], BODY)
    s.poly([(10, 62), (130, 42), (170, 42), (290, 62), (290, 65.5), (170, 45.5),
            (130, 45.5), (10, 65.5)], LIGHT, 0.75)
    for x0 in range(80, 126, 14):                        # 左横担腹杆（实梁读法，不做细线）
        y_top = 42 + (130 - x0) / 6.0
        s.line(x0, y_top + 4, x0 + 7, 64 + (130 - x0 - 7) / 15.0, BODY, 2.2, 0.9)
    for x0 in range(176, 196, 14):                       # 右横担腹杆（避开针孔段）
        s.line(x0, 42 + (x0 - 170) / 6.0 + 4, x0 + 7, 64 + (x0 + 7 - 170) / 15.0, BODY, 2.2, 0.9)
    s.line(268, 59, 276, 70, BODY, 2.2, 0.9)
    # 背部 RodPorts 三孔（电珠出膛孔，锚点不动）
    for px, py in ((206, 52), (230, 56), (254, 60)):
        s.rect(px - 7, py - 2, 14, 8, GAP)
        s.rect(px - 4.5, py, 9, 4, "#0d0a14")
        s.line(px, py + 2, px, py - 8, PORCE, 1.6)
        s.circle(px, py - 8.5, 1.6, VIOLET, 0.95)
    # ---- 左横担端传感舱（独眼 (55,63)）----
    s.poly([(12, 60), (24, 52), (76, 50), (80, 58), (80, 78), (20, 80), (10, 72)], BODY)
    s.poly([(24, 52), (76, 50), (79, 55), (20, 56)], LIGHT, 0.8)
    s.poly([(10, 72), (80, 72), (80, 78), (20, 80)], BELLY)
    eye_band(s, 42, 60)
    # ---- 前部天线桅（固定，球状闪电出弹源）：座=传感舱顶 (33..47,48..54，舱顶缘
    #      y=52-0.0385(x-24)≈51.4，座底 54 埋入 2.6)；桅 x40 细桅（塔身主材语汇
    #      2.6px+受光棱，非炮管）；一节瓷瓶座双盘 y41..46；顶电珠座 (40,20)=
    #      ArmPivot/Muzzle 锚（亮珠本体=场景层 fx_ball_bolt.svg Sprite2D）。
    s.rect(33, 48, 14, 6, BODY)
    s.rect(33, 48, 14, 1.8, LIGHT, 0.7)
    s.line(40, 52, 40, 23, BODY, 2.6)
    s.line(39.1, 52, 39.1, 23, LIGHT, 1, 0.7)
    s.ellipse(40, 45.4, 2.5, 1.4, PORCE_DK)
    s.ellipse(40, 44.6, 2.5, 1.4, PORCE)
    s.ellipse(40, 42.2, 2.2, 1.2, PORCE_DK)
    s.ellipse(40, 41.4, 2.2, 1.2, PORCE)
    s.circle(40, 20, 6.5, VIOLET, 0.15)
    s.circle(40, 20, 3.2, GAP)
    # ---- 举升舱 + 腹舱双桩口（BayPort (150,168)）----
    s.poly([(92, 138), (208, 138), (218, 150), (200, 166), (100, 166), (82, 150)], BODY)
    s.poly([(92, 138), (208, 138), (213, 144), (87, 144)], LIGHT, 0.7)
    s.poly([(82, 150), (218, 150), (200, 166), (100, 166)], BELLY)
    s.rect(98, 152, 24, 10, GAP)                         # 螺旋桨座（Prop1 画布 (110,152)）
    s.rect(178, 152, 24, 10, GAP)                        # 螺旋桨座（Prop2 画布 (190,152)）
    s.rect(128, 150, 44, 16, GAP)
    s.rect(128, 150, 44, 3, LIGHT, 0.5)
    s.rect(132, 157, 16, 9, "#0d0a14")
    s.rect(152, 157, 16, 9, "#0d0a14")
    s.circle(140, 161, 2.2, PORCE, 0.9)
    s.circle(160, 161, 2.2, PORCE, 0.9)
    s.circle(150, 146, 1.8, VIOLET, 0.95)
    for i, hx in enumerate(range(100, 124, 6)):          # 舱面警示花砖（左）
        s.rect(hx, 143, 3, 4, VIOLET if i % 2 == 0 else GAP, 0.8)
    for i, hx in enumerate(range(178, 202, 6)):          # 舱面警示花砖（右，替换旧紫折线）
        s.rect(hx, 143, 3, 4, VIOLET if i % 2 == 0 else GAP, 0.8)
    return s


# ============================================================
# 第十章「井口」：自升式钻井平台
# ============================================================
def sulfur_body():
    LIGHT, BODY, BELLY, GAP, VOID = "#6a4456", "#4a2a3a", "#321c28", "#20121a", "#120a10"
    BLUE, BLUE_CORE, SULFUR, STEEL = "#48b4ff", "#c8ecff", "#c8b048", "#7a6a72"
    WIN = "#e0c8d4"

    def valve(cx, cy, r=2.6):
        s.circle(cx, cy, r, STEEL)
        s.circle(cx, cy, r - 1.1, BELLY)
        s.circle(cx, cy, 0.9, STEEL)

    def pilot(x, y, r=1.4):
        s.circle(x, y, r * 2.6, BLUE, 0.18)
        s.circle(x, y, r, BLUE, 0.95)

    def leg(c):
        """桩腿：双弦 + K 撑，y2..150；底 = 桩靴。"""
        s.rect(c - 9, 2, 4, 150, BODY)
        s.rect(c + 5, 2, 4, 150, BODY)
        s.rect(c - 9, 2, 1.4, 150, LIGHT, 0.7)
        for y in range(8, 148, 12):
            s.line(c - 6, y, c + 6, y + 6, GAP, 1.6)
            s.line(c + 6, y + 6, c - 6, y + 12, GAP, 1.6)
        s.rect(c - 10, 0, 20, 5, BELLY)                  # 腿顶帽
        s.poly([(c - 14, 150), (c + 14, 150), (c + 8, 164), (c - 8, 164)], BELLY)

    s = Svg(300, 180)
    # ---- 井架（井口正上方）：底 x118..182@y100 → 顶 x142..158@y14 ----
    def dl(y):
        return 118 + (100 - y) * 24 / 86
    def dr(y):
        return 182 - (100 - y) * 24 / 86
    girts = (100, 80, 60, 40, 22)
    for y0, y1 in zip(girts, girts[1:]):
        s.line(dl(y0), y0, dr(y1), y1, GAP, 1.5, 0.9)
        s.line(dr(y0), y0, dl(y1), y1, GAP, 1.5, 0.9)
    for y in girts[1:]:
        s.line(dl(y), y, dr(y), y, BODY, 2.4)
    s.line(dl(100), 100, dl(14), 14, BODY, 4.5)
    s.line(dr(100), 100, dr(14), 14, BODY, 4.5)
    s.line(dl(100) - 1.5, 100, dl(14) - 1.5, 14, LIGHT, 1.4, 0.7)
    s.rect(136, 6, 28, 10, BODY)                         # 天车
    s.rect(136, 6, 28, 2.5, LIGHT, 0.7)
    s.rect(140, 18, 20, 14, BELLY)                       # ArmPivot (150,26) 枢座
    s.circle(150, 26, 5, GAP)
    s.line(150, 32, 150, 88, STEEL, 1.4, 0.8)            # 大钩钢丝
    # ---- 双桩腿（腿先画，平台甲板压在中段=穿甲板读法）----
    leg(30)
    leg(270)
    # ---- 平台甲板 ----
    s.poly([(16, 100), (284, 100), (284, 126), (272, 134), (28, 134), (16, 126)], BODY)
    s.poly([(16, 100), (284, 100), (284, 104), (16, 104)], LIGHT, 0.75)
    s.poly([(16, 124), (284, 124), (272, 134), (28, 134)], BELLY)
    s.rect(40, 112, 220, 2, GAP, 0.35)
    # 桩腿升降室（甲板上套住桩腿）
    for c in (30, 270):
        s.rect(c - 15, 88, 30, 22, BELLY)
        s.rect(c - 15, 88, 30, 2.5, LIGHT, 0.6)
        s.rect(c - 9, 94, 4, 16, BODY)
        s.rect(c + 5, 94, 4, 16, BODY)
    # 钻台底座
    s.rect(112, 88, 76, 12, BELLY)
    s.rect(112, 88, 76, 2.5, LIGHT, 0.6)
    valve(128, 94, 3.2)
    valve(172, 94, 3.2)
    # 集输管廊（甲板上，井架 → 排烟囱）
    for py, col in ((92, BELLY), (96, GAP)):
        s.rect(190, py, 44, 3.4, col)
    # ---- 艉部排烟囱（VentPort (246,46)）----
    s.rect(236, 40, 20, 60, BELLY)
    s.rect(236, 40, 3, 60, LIGHT, 0.5)
    s.rect(233, 38, 26, 4, GAP)
    s.rect(239, 42, 14, 6, VOID)
    s.ellipse(246, 45, 6, 2.4, BLUE, 0.6)
    s.ellipse(246, 45, 3, 1.2, BLUE_CORE, 0.9)
    s.rect(222, 62, 8, 38, BELLY)                        # 副烟囱
    s.rect(220, 60, 12, 3, GAP)
    # ---- 生活楼 + 直升机坪（独眼 (55,63) 在楼前脸）----
    s.line(44, 50, 40, 70, BELLY, 3)                     # 机坪悬臂撑
    s.poly([(40, 54), (98, 52), (102, 100), (40, 100)], BODY)
    s.poly([(40, 54), (98, 52), (99, 57), (40, 58)], LIGHT, 0.75)
    for wy in (74, 86):                                  # 两层舷窗
        for wx in range(46, 96, 10):
            s.rect(wx, wy, 6, 5, WIN, 0.6)
    eye_band(s, 42, 60)
    s.poly([(34, 46), (108, 45), (110, 50), (32, 51)], BELLY)       # 机坪板
    s.rect(34, 45, 76, 1.6, LIGHT, 0.7)
    for nx in range(36, 110, 8):                                    # 机坪护网
        s.line(nx, 45, nx - 2, 41, STEEL, 1, 0.7)
    s.line(34, 41, 108, 40, STEEL, 1, 0.7)
    # ---- 艏部井口喷嘴（NozzlePort (4,144)）：甲板艏下角伸出 ----
    s.poly([(16, 118), (34, 124), (20, 150), (12, 140)], BELLY)
    s.line(26, 128, 14, 144, BODY, 9)
    s.line(26, 126, 15, 141, LIGHT, 2, 0.6)
    s.poly([(0, 134), (12, 136), (14, 152), (0, 154)], GAP)
    s.rect(11, 135, 3, 18, STEEL)
    s.circle(4, 144, 5.5, BLUE, 0.22)
    s.circle(4, 144, 3.2, BLUE, 0.9)
    s.circle(4, 144, 1.4, BLUE_CORE)
    # ---- 举升喷口座（焰 (110,148)/(210,148)）----
    s.rect(98, 134, 24, 12, BELLY)
    s.rect(198, 134, 24, 12, BELLY)
    # ---- 防喷器组 + 导管 + 钻头（DrillPort (150,168)）----
    s.rect(134, 134, 32, 18, BELLY)
    s.rect(134, 134, 32, 2.5, LIGHT, 0.5)
    s.rect(130, 140, 40, 5, GAP)
    valve(138, 148, 2.6)
    valve(162, 148, 2.6)
    s.rect(143, 152, 14, 10, BELLY)
    s.rect(145, 158, 10, 6, VOID)
    s.poly([(146, 162), (154, 162), (150, 169)], STEEL)
    pilot(150, 138, 1.4)
    # 警示杠 + 硫黄结壳
    for i, hx in enumerate(range(60, 92, 7)):
        s.rect(hx, 116, 3, 4, STEEL if i % 2 == 0 else GAP, 0.8)
    for (x, y, ex, ey) in ((196, 128, 7, 1.8), (82, 130, 6, 1.6), (262, 120, 5, 1.4)):
        s.ellipse(x, y, ex, ey, SULFUR, 0.4)
    return s


ITEMS = [
    (red_body, "boss_red_body.svg",
     "第六章 BOSS「赤轮」斗轮挖掘机 300x180，原点 (150,90)，原生朝左，碰撞体 280x150。"
     "Wheel 毂 (44,120)；Rack 枢 (210,38)（座裙顶 38）；BayPort (150,170)；举升焰 (120,154)/(230,154)；"
     "独眼 驾驶室 (95,60)=EyeGlow 局部 (-55,-30)。生成器 art_proposals/boss_forms/gen_boss_forms.py。"),
    (salt_body, "boss_salt_body.svg",
     "第八章 BOSS「盐磨」聚光镜碟 300x180，原点 (150,90)，原生朝左，碰撞体 280x150。"
     "ArmPivot (150,26)=碟沿顶镜阵翼枢座；BayPort (150,168)；举升焰 (114,160)/(206,160)=局部 (-36,70)/(56,70)；"
     "独眼 焦点接收头 (69,90)=EyeGlow 局部 (-81,0)。生成器 art_proposals/boss_forms/gen_boss_forms.py。"),
    (storm_body, "boss_storm_body.svg",
     "第九章 BOSS「引雷」浮空电塔 300x180，原点 (150,90)，原生朝左，碰撞体 280x150。"
     "ArmPivot (40,20)=前部天线桅顶电珠（局部 (-110,-70)，固定天线不俯仰）；BayPort (150,168)；"
     "RodPorts (206,52)/(230,56)/(254,60)（右横担顶缘 y=42+(x-170)/6）；"
     "侧置螺旋桨座 (110,152)/(190,152)=局部 (-40,62)/(40,62)；独眼 (55,63) 左横担传感舱。"
     "生成器 art_proposals/boss_forms/gen_boss_forms.py。"),
    (sulfur_body, "boss_sulfur_body.svg",
     "第十章 BOSS「井口」自升式钻井平台 300x180，原点 (150,90)，原生朝左，碰撞体 280x150。"
     "ArmPivot (150,26)=井架上段枢座；NozzlePort (4,144)；DrillPort (150,168)=防喷器组下钻头；VentPort (246,46)=排烟囱口；"
     "举升焰 (110,148)/(210,148)=局部 (-40,58)/(60,58)；独眼 (55,63) 生活楼前脸。生成器 art_proposals/boss_forms/gen_boss_forms.py。"),
]

BY_NAME = {name: fn for fn, name, _ in ITEMS}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn, name, c in ITEMS:
        save(fn(), name, c)
