# -*- coding: utf-8 -*-
"""第四章 v2「珊瑚能量武器化」单位/特效烘焙：精英与 BOSS 按能力重设计，
覆写 assets/world_4/ 原名（tscn 引用不动）；v1 闪电版美术被本脚本取代。

产物：
  enemy_coral_elite_body.svg  60x80    精英重设计「海葵」炮台车（背驮海葵发射器）
  boss_coral_body.svg         300x180  BOSS 重设计「鮟鱇」v2（背炮+钓灯+腹闸）
  boss_coral_gun.svg          120x40   BOSS 钓灯臂 v3（鮟鱇拟饵：贝塞尔细竿+灯球+垂须）
  fx_coral_orb.svg            36x36    珊瑚重弹：软辉能量球（CoralOrb）
  fx_coral_bolt.svg           30x12    钓灯能量束：平滑波浪红带（直射弹，noodle 语汇）
  fx_coral_tide.svg           84x52    珊瑚潮涌浪剪影（CoralTide）

锚点账（v2，覆写 v1；详见 提案_v2_珊瑚重设计.md §4）：
  精英：眼 (19,26.5) 不变；ArmPivot 画布 (44,8)、Muzzle 画布 (44,6)=海葵口；
        旧 VLS 双仓口锚点作废。
  BOSS：独眼条带 y60..66 含 (55,63)、Rotor/TailRotor 画布 (272,64)/(272,112)
        沿用；Cannon/Muzzle 画布 (150,28)（背炮口）；ArmPivot 画布 (86,42)
        （钓灯臂根）、Muzzle=臂局部 (-94,14)（钓灯球心，尖端画布≈(-8,56)）；
        BayPort 画布 (150,174)（腹下放电舱内）。
FX 语汇：能量武器=柔光+粒群+平滑波浪；禁锯齿/高频白芯（闪电感清零）。
色板沿用章四：珊瑚 #ff5a33/#ff7a45/#ffb36b、余烬 #ff9c5a、白热芯 #ffd9a0；
敌营亮钢蓝 LIGHT #9fb0d8 / BODY #5d6d94 / BELLY #3f4c6e / GAP #262f4a。
ThorVG 硬约束：无 filter/pattern/use/text/transform；无 rect+rotate。
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
from generate_proposals import Svg, f  # noqa: E402

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "world_4"))

# ---- 章四色板（同 bake_coral_assets.py） ----
CORAL = "#ff5a33"
CORAL_HI = "#ff7a45"
CORAL_CORE = "#ffb36b"
EMBER = "#ff9c5a"
WHITE_HOT = "#ffd9a0"
LIGHT = "#9fb0d8"
BODY = "#5d6d94"
BELLY = "#3f4c6e"
GAP = "#262f4a"
RED = "#ff4640"
YELLOW = "#d8a021"
CORAL_LAMP = "#ff7a45"
DUCK_DARK = "#141a30"


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


def _tentacle(s: Svg, cx: float, cy: float, deg: float, r0: float, r1: float,
              w0: float, w1: float, color: str) -> None:
    """海葵触须：从环心沿 deg 方向的锥形棒（基宽 w0、梢宽 w1）。"""
    a = math.radians(deg)
    dx, dy = math.cos(a), math.sin(a)
    px, py = -dy, dx
    b = (cx + r0 * dx, cy + r0 * dy)
    t = (cx + r1 * dx, cy + r1 * dy)
    s.poly([
        (b[0] + w0 * px, b[1] + w0 * py),
        (b[0] - w0 * px, b[1] - w0 * py),
        (t[0] - w1 * px, t[1] - w1 * py),
        (t[0] + w1 * px, t[1] + w1 * py),
    ], color)


def elite_body():
    """精英 v2「海葵」炮台车 60x80，地面 y=80。
    比例账（按能力反推）：珊瑚重弹 Ø36 → 海葵口内径 6.4（出膛挤压读法）→
    菌冠环 r6.5 + 触须 5 根（外径 13）包络炮口；基座 (36..58, 14..26)；
    底盘沿 v1 语言（前声呐锥+悬浮裙+底缘珊瑚辉光）。
    锚点：眼 (19,26.5)=halo r5.3/core r2.4（不变）；ArmPivot 画布 (44,8)、
    Muzzle 画布 (44,6)=海葵口心；旧 VLS 双仓口锚点作废（提案_v2 §4）。"""
    s = Svg(60, 80)
    # ---- 悬浮裙（无履带；底缘珊瑚辉光=磁浮语义） ----
    s.poly([(8, 64), (52, 64), (56, 72), (46, 77), (14, 77), (4, 72)], BELLY)
    for tx in range(14, 48, 7):
        s.rect(tx, 66, 2, 7, GAP, 0.85)
    s.glow_ellipse(30, 77, 26, 4, CORAL_LAMP, 0.25)
    s.rect(10, 75.5, 40, 2, CORAL_LAMP, 0.85)
    # ---- 车体（低滑翔舰体） ----
    s.poly([(4, 44), (58, 44), (60, 52), (58, 62), (48, 68), (14, 68), (4, 60)], BODY)
    s.poly([(4, 44), (58, 44), (57.5, 46.5), (4.5, 46.5)], LIGHT, 0.7)
    # ---- 前部声呐锥 ----
    s.poly([(2, 56), (8, 50), (10, 50), (10, 66), (4, 66), (0, 60)], BELLY)
    s.line(0, 60, 4, 66, LIGHT, 2, 0.7)
    # ---- 驾驶眼塔 + 独眼（锚点不变） ----
    s.poly([(8, 22), (30, 22), (32, 28), (32, 44), (8, 44)], BODY)
    s.rect(8, 22, 22, 3, LIGHT)
    s.rect(12, 23, 14, 7, GAP)
    s.circle(19, 26.5, 5.3, RED, 0.22)
    s.circle(19, 26.5, 2.4, RED, 0.95)
    s.rect(10, 33, 20, 4, GAP)
    # ---- 连接甲板 + 侧舷细节 ----
    s.rect(28, 26, 12, 18, BODY)
    s.rect(28, 26, 12, 2.5, LIGHT, 0.7)
    for i, hx in enumerate(range(14, 52, 5)):     # 危险黄警示带
        s.rect(hx, 56, 2.5, 3.5, YELLOW if i % 2 == 0 else GAP, 0.8)
    # ---- 背驮海葵发射器（能力签名件） ----
    s.poly([(32, 26), (58, 26), (56, 14), (36, 14)], BODY)        # 基座
    s.rect(36, 14, 20, 2, LIGHT)
    s.rect(52, 27, 6, 9, BELLY)                                   # 尾部储能罐
    s.circle(55, 25.5, 1.2, CORAL_LAMP, 0.9)
    # 菌冠环 + 触须（包络炮口；触须尖=珊瑚光点）
    for deg, r1 in ((-152, 12.5), (-122, 14.0), (-90, 15.0), (-58, 14.0), (-28, 12.5)):
        _tentacle(s, 44.0, 10.0, deg, 5.0, r1, 1.6, 0.6, BODY)
        a = math.radians(deg)
        s.circle(44 + (r1 + 0.6) * math.cos(a), 10 + (r1 + 0.6) * math.sin(a),
                 1.2, CORAL_LAMP, 0.9)
    s.circle(44, 10, 6.5, BELLY)                  # 冠环
    s.circle(44, 10, 6.5, BODY, 0.0)
    s.circle(44, 8, 3.2, GAP)                     # 口（=Muzzle 画布 (44,6) 邻域）
    s.circle(44, 7, 1.5, CORAL, 0.95)             # 口内珊瑚芯（能量就绪灯）
    return s


def boss_body():
    """BOSS v2 深海猎杀舰「鮟鱇」300x180=碰撞体 body_size，原点(150,90)，原生朝左。
    造型按能力布挂件：楔形猎杀舰 + **背驮大口径珊瑚重炮**（技能A，炮口画布
    (150,28)）+ **艏部钓灯臂座**（直射，ArmPivot 画布 (86,42)，球=独件）+
    **腹下吊挂放电舱**（技能B 投放口，画布 (150,174)）+ 尾部涵道/浮筒（围绕
    既有桨节点画布 (272,64)/(272,112)）+ 侧舷珊瑚生长簇。
    沿用锚点：独眼条带 y60..66 含 (55,63)（EyeGlow 节点 (-95,-27) 照摆）。
    v1 的背脊垂发 4 仓口作废（弹雨语法不随舰过章）。"""
    s = Svg(300, 180)
    # ---- 尾鳍（先画，被舰体压住） ----
    s.poly([(246, 28), (272, 2), (292, 4), (284, 36)], BODY)
    s.poly([(272, 2), (292, 4), (290, 10), (275, 9)], LIGHT)
    s.poly([(248, 116), (270, 142), (290, 140), (282, 112)], BELLY)
    # ---- 龙骨 + 悬浮辉光 ----
    s.poly([(40, 112), (240, 108), (232, 134), (60, 134)], BELLY)
    s.glow_ellipse(140, 138, 110, 9, CORAL_LAMP, 0.28)
    s.rect(70, 131, 150, 2.5, CORAL_LAMP, 0.7)
    # ---- 尾部涵道座（桨独件画布 (272,64)）+ 下浮筒（风扇独件画布 (272,112)） ----
    s.poly([(250, 40), (298, 40), (298, 88), (250, 88)], BODY)
    s.rect(250, 40, 48, 4, LIGHT)
    s.circle(272, 64, 18, DUCK_DARK, 0.9)
    s.circle(272, 64, 18, GAP, 0.0)
    s.circle(272, 64, 21, BODY, 0.0)
    s.rect(260, 96, 26, 30, BELLY)
    s.rect(260, 96, 26, 3, LIGHT, 0.6)
    s.rect(268, 102, 10, 18, GAP, 0.85)
    # ---- 主舰体（加重楔形 + 眉眶） ----
    s.poly([(4, 62), (36, 40), (150, 34), (240, 38), (290, 54), (294, 84),
            (258, 110), (60, 114), (18, 98)], BODY)
    s.poly([(36, 40), (150, 34), (240, 38), (286, 53), (284, 58), (239, 42),
            (149, 38), (40, 44)], LIGHT, 0.7)
    # 眉眶（钓灯臂的肩座隆起）
    s.poly([(66, 40), (110, 34), (140, 37), (136, 47), (96, 49), (68, 48)], BODY)
    s.poly([(66, 40), (110, 34), (138, 36.5), (135, 40), (108, 42), (70, 43.5)],
           LIGHT, 0.8)
    # 板缝 + 舷窗带
    s.rect(116, 44, 2.5, 66, GAP, 0.35)
    s.rect(196, 42, 2.5, 66, GAP, 0.35)
    s.rect(70, 90, 180, 2.5, GAP, 0.3)
    for wi, wx in enumerate(range(150, 236, 18)):
        if wi in (1, 4):
            s.rect(wx, 70, 8, 7, CORAL_LAMP, 0.85)
        else:
            s.rect(wx, 70, 8, 7, GAP, 0.9)
    # 艇鼻帽
    s.poly([(2, 66), (20, 58), (20, 92), (2, 80)], BELLY)
    # ---- 背驮大口径珊瑚重炮（技能A；炮口画布 (150,28)） ----
    s.poly([(198, 40), (250, 40), (244, 14), (206, 14)], BODY)    # 炮塔
    s.rect(206, 14, 40, 3, LIGHT)
    s.rect(150, 22, 62, 12, BODY)                 # 粗管（从炮口座到炮塔）
    s.rect(150, 22, 62, 2.5, LIGHT, 0.6)
    for gx in (166, 184, 202):                    # 珊瑚辉光环（能量就绪度）
        s.rect(gx, 20, 4, 16, CORAL_LAMP, 0.8 if gx != 184 else 0.55)
    s.rect(144, 19, 10, 18, GAP)                  # 炮口座
    s.rect(147, 24, 4, 8, CORAL, 0.9)             # 口内珊瑚芯
    s.rect(210, 32, 22, 3, YELLOW, 0.7)           # 炮塔警示条
    # ---- 艏部钓灯臂座（直射；球=独件 boss_coral_gun） ----
    s.circle(86, 42, 4, GAP)                      # 臂根 joint（=ArmPivot）
    # ---- 腹下吊挂放电舱（技能B 投放口，画布 (150,174)） ----
    s.rect(146, 134, 8, 22, BELLY)                # 吊杆
    s.poly([(134, 156), (166, 156), (170, 174), (130, 174)], BODY)
    s.rect(134, 156, 32, 3, LIGHT, 0.7)
    s.rect(132, 170, 36, 6, GAP)
    s.rect(136, 172, 28, 2.5, CORAL_LAMP, 0.9)    # 闸口珊瑚辉光缝
    # ---- 侧舷珊瑚生长簇（阵营珊瑚灯语言） ----
    for cx, cy, scale in ((58, 96, 1.0), (226, 92, 0.85)):
        s.line(cx, cy, cx - 6 * scale, cy - 10 * scale, CORAL, 2.2, 0.55)
        s.line(cx, cy, cx + 5 * scale, cy - 8 * scale, CORAL, 1.8, 0.45)
        s.line(cx - 6 * scale, cy - 10 * scale, cx - 8 * scale, cy - 15 * scale,
               CORAL, 1.6, 0.4)
        s.circle(cx - 8 * scale, cy - 15 * scale, 1.4, CORAL_CORE, 0.9)
        s.circle(cx + 5 * scale, cy - 8 * scale, 1.2, CORAL_HI, 0.8)
    # ---- 独眼条带（沿用锚点） ----
    s.rect(38, 57, 34, 12, RED, 0.18)
    s.rect(42, 60, 26, 6, RED, 0.95)
    return s


def boss_gun():
    """BOSS 钓灯臂 120x40（tscn：ArmPivot 画布 (86,42)→Visuals (-64,-48)，
    sprite offset(-100,-12)=枢端画布 (100,12)；Muzzle=臂局部 (-94,14)=球心）。
    v3 重画（2026-11-03 用户「炮管一点都不像钓灯，重画」）：鮟鱇拟饵——细竿
    从弓部后上方抬起、过前缘后垂下（二次贝塞尔采样，根粗梢细），端头吊珊瑚
    灯球，球后两根垂须。普攻已改径向爆闪，发射位=灯球本体（锚点一像素不动）。
    纯平涂分层圆=假渐变，ADD 辉光由引擎侧材质叠。"""
    s = Svg(120, 40)
    # 主竿：P0(100,10) 枢端 → P1(52,-6) 抬头控制点 → P2(7,21) 挂球点；
    # 采样贝塞尔+法向偏移做锥形（根半宽 2.4 → 梢 1.1），上下面合成填充条。
    p0, p1, p2 = (100.0, 10.0), (52.0, -6.0), (7.0, 21.0)
    n_seg = 16
    upper, lower, mid = [], [], []
    for i in range(n_seg + 1):
        t = i / n_seg
        u = 1.0 - t
        x = u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0]
        y = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]
        dx = 2 * u * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0])
        dy = 2 * u * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1])
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln
        hw = 2.4 - 1.3 * t
        upper.append((x + nx * hw, y + ny * hw))
        lower.append((x - nx * hw, y - ny * hw))
        mid.append((x, y))
    s.poly(upper + lower[::-1], BODY)
    # 竿背高光：沿上缘一条细亮线（受光面读法，弹体三层语汇的减档）
    s.path("M " + " L ".join(f"{f(x)},{f(y)}" for x, y in upper),
           stroke=LIGHT, w=1.0, opacity=0.85)
    # 竿顶信号灯（章节灯点语汇，钉在弧顶段）
    s.circle(mid[7][0], mid[7][1] - 1.2, 1.1, CORAL_LAMP, 0.9)
    # 灯球（球心画布 (6,26)=Muzzle 锚点不动）：软晕+灯罩壳+珊瑚内层+白热芯
    s.circle(6, 26, 7.5, CORAL, 0.14)   # 软晕（贴画布左缘，裁 1px 无碍）
    s.circle(6, 26, 6.4, BELLY)         # 灯罩壳
    s.circle(6, 26, 4.8, CORAL_HI, 0.95)
    s.circle(6, 26, 2.2, WHITE_HOT)
    s.circle(5.2, 25.2, 0.9, "#fff1dd") # 白热点
    s.line(7.5, 20.0, 6.8, 22.0, BELLY, 1.4)  # 挂环（竿梢→球顶）
    # 垂须两根（球后下方拖出，拟饵的须）
    s.path("M 9,31 Q 16,34 24,33", stroke=BELLY, w=1.0, opacity=0.9)
    s.path("M 8,33 Q 13,38 20,37.5", stroke=BELLY, w=0.8, opacity=0.75)
    return s


def fx_orb():
    """珊瑚重弹 36x36：软辉能量球（分层圆=平涂假渐变，外晕→中层→珊瑚体→
    白热芯）。CoralOrb 的 Sprite；尾迹=coral_embers 粒子（不在贴图里）。"""
    s = Svg(36, 36)
    s.circle(18, 18, 16, CORAL, 0.14)
    s.circle(18, 18, 11.5, CORAL_HI, 0.32)
    s.circle(18, 18, 8, CORAL, 0.85)
    s.circle(18, 18, 4.6, WHITE_HOT, 0.95)
    s.circle(18, 18, 2.0, "#fff1dd", 1.0)
    return s


def fx_bolt():
    """钓灯能量束矢弹 28x10（+X=飞行方向）：plasma_bolt.svg 六边形能量镖几何
    原样只换珊瑚家配色（波浪 noodle 版被否，用户钦定「像电浆弹一样只换色」
    ——本函数曾是 noodle 版，2026-11-03 对齐磁盘定稿，烘焙不再覆写它）。
    深珊瑚壳+珊瑚鞘+白热芯+尾部弧须；ADD 材质在场景。"""
    s = Svg(28, 10)
    s.poly([(2, 5), (9, 2), (22, 2.5), (26, 5), (22, 7.5), (9, 8)], "#b53722")
    s.poly([(5, 5), (10, 3.2), (21, 3.6), (24, 5), (21, 6.4), (10, 6.8)],
           CORAL_HI, 0.9)
    s.poly([(7, 4.6), (14, 3.9), (22, 4.6), (22, 5.4), (14, 6.1), (7, 5.4)],
           "#fff1dd")
    s.line(1, 3.5, 5, 4.6, CORAL_HI, 1.1, 0.8)
    s.line(1, 6.5, 5, 5.4, CORAL_HI, 1.1, 0.8)
    return s


if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)
    save(elite_body(), "enemy_coral_elite_body.svg", """第四章精英 v2「海葵」炮台车 60x80，地面 y=80。
骨架：眼 (19,26.5) 不变；ArmPivot 画布 (44,8)、Muzzle 画布 (44,6)=海葵口
（v2 锚点，旧 VLS 双仓口作废）。造型：低滑翔底盘（声呐锥+悬浮裙+底缘珊瑚
辉光）+ 背驮海葵发射器（菌冠触须环包络炮口，触须尖珊瑚光点）。
色板：LIGHT #9fb0d8/BODY #5d6d94/BELLY #3f4c6e/GAP #262f4a + 珊瑚灯。
提案=同目录 提案_v2_珊瑚重设计.md §4。""")
    save(boss_body(), "boss_coral_body.svg", """第四章 BOSS v2 深海猎杀舰「鮟鱇」300x180=碰撞体，原点(150,90)，原生朝左。
能力布挂件：背驮大口径珊瑚重炮（炮口画布 (150,28)=Cannon/Muzzle）+ 艏部
钓灯臂座（ArmPivot 画布 (86,42)，球=独件）+ 腹下吊挂放电舱（画布 (150,174)
=BayPort）+ 尾部涵道/浮筒（桨独件画布 (272,64)/(272,112) 沿用）。
沿用锚点：独眼条带 y60..66 含 (55,63)。v1 背脊垂发 4 仓口作废。
提案=同目录 提案_v2_珊瑚重设计.md §4。""")
    save(boss_gun(), "boss_coral_gun.svg", """第四章 BOSS 钓灯臂 v3（鮟鱇拟饵）120x40（tscn offset(-100,-12)，枢端画布 (100,12)；球心 (6,26)=Muzzle 锚点）。
Muzzle=臂局部 (-94,14)=灯球心（尖端画布≈(-8,56)，出画惯例同 ch1）。
拟饵=爆闪发射位：贝塞尔细竿抬起垂下 + 灯球 + 垂须；普攻径向爆闪从球心齐放。""")
    save(fx_orb(), "fx_coral_orb.svg", """珊瑚重弹贴图 36x36：软辉能量球（分层圆平涂假渐变+白热芯）。
CoralOrb 本体；尾迹=coral_embers 粒子。能量语汇=柔光，无锯齿无电芯。""")
    save(fx_bolt(), "fx_coral_bolt.svg", """钓灯能量束矢弹 28x10（+X=飞行方向）：plasma_bolt 六边形能量镖几何
原样只换珊瑚家配色（深珊瑚壳+珊瑚鞘+白热芯+尾部弧须；ADD 材质在场景）。
coral_bolt.tscn=bullet.gd 纯换皮。""")
    print("coral chapter v2 units baked.")
