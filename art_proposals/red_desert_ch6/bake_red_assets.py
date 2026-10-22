# -*- coding: utf-8 -*-
"""第六章「赤沙矿区」环境烘焙：六件套 + 斗轮巨机（独层地标）。

产物（assets/world_6/）：
  env_red_far.svg          1024x1300  远景条：白热天光渐变+尘带+远峡壁+电塔列
  env_red_wheel.svg        3200x900   独层地标：斗轮挖掘机（tile 3200 同屏一份）
  env_red_mid.svg          2048x520   中景条：输送栈桥/矿仓群/井架（三段各异）
  env_red_ground_top.svg   640x66     表面带=拆地块 v2 @ THEMES.p6_desert（bake_band）
  env_red_ground_fill.svg  16x256     立面渐变（bake_fill）
  env_red_ground.svg       256x480    兜底地面条（GroundStrip）
  env_red_deck.svg         720x26     脚手架断桥桥面

画布账：far 底=世界 730（画布 y = 世界 y + 570）；mid 底=世界 700（画布 y =
世界 y − 180）；wheel 独层条带位 (8,270) 居中挂载（画布 y = 世界 y + 180，
同五章天梯缆账）。far 两侧留空 24px、mid 两侧留空 40px（平铺接缝规矩）。
条带里不画唯一地标：白热日与斗轮巨机都走独层不在远条（太阳与巨机挤不进
[1200+半宽, 3200−1200−半宽] 安全带，白热天光由天顶渐变+尘带承担）。
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

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "world_6"))

# ---- 章六色板（同提案 red_desert） ----
SKY_STOPS = [(0, "#b8d0dc", 1), (0.5, "#ded0b4", 1), (1, "#f0cfa2", 1)]
DUST = "#e6cba2"        # 地平尘霞/沙暴横掠
MESA = "#b87a50"        # 远峡壁/沙梁剪影
MESA_LINE = "#a87450"   # 峡壁层理横线
POLE = "#8a5a3c"        # 电塔列
TRUSS = "#7e3c28"       # 栈桥桁架（锈红）
SILO = "#6e3424"        # 矿仓筒体
SILO_DEEP = "#5e2c1e"   # 矿仓顶/暗部
RIM = "#d98c5e"         # 受光顶缘
LAMP = "#ffb347"        # 矿灯金
MACHINE = "#8f5c3c"     # 斗轮巨机主体（独层）
MACHINE_DEEP = "#7a4a2e"
ORE = "#3f1d12"         # 矿石/暗部


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
    """远景条 1024x1300：白热天光渐变 + 高天尘带 + 远峡壁（右高左低两翼）
    + 电塔列 + 地平尘霞。画布 y = 世界 y + 570：峡壁脚画布 1150（世界 580，
    藏进地块后）。两侧 24px 留空。种子 6061。"""
    rng = random.Random(6061)
    s = Svg(1024, 1300)
    s.rect(0, 0, 1024, 1300, s.vgrad("sky", SKY_STOPS))
    # 高天尘带（白热天光的横掠纹；平铺安全=通长淡带，非地标）
    for yy, op in ((260, 0.12), (360, 0.08), (470, 0.06)):
        s.rect(0, yy, 1024, 26, "#e9d6b4", op)
    # ---- 远峡壁（右翼高台地层理）+ 左翼低沙梁 ----
    mesa_r = [(760, 1300), (800, 1000), (840, 940), (880, 966), (930, 900),
              (964, 922), (996, 878), (1024, 892), (1024, 1300)]
    s.poly(mesa_r, MESA, 0.62)
    for x0, x1, yy in ((790, 850, 1120), (830, 910, 1064), (870, 970, 1000),
                       (910, 1010, 936), (950, 1024, 872)):
        s.line(x0, yy, x1, yy, MESA_LINE, 1.4, 0.55)
    ridge_l = [(0, 1300), (30, 1116), (86, 1102), (150, 1114), (206, 1300)]
    s.poly(ridge_l, MESA, 0.45)
    # ---- 电塔列（重复构件，平铺安全）----
    towers = [(300, 96), (500, 110), (700, 100), (900, 116)]
    for i, (px, ph) in enumerate(towers):
        base = 1156
        s.line(px, base, px, base - ph, POLE, 2.0, 0.6)
        s.line(px - 12, base - ph * 0.72, px + 12, base - ph * 0.72, POLE, 1.4, 0.6)
        s.line(px - 8, base - ph * 0.9, px + 8, base - ph * 0.9, POLE, 1.2, 0.6)
        s.line(px - 7, base, px - 2, base - ph * 0.55, POLE, 1.0, 0.55)
        s.line(px + 7, base, px + 2, base - ph * 0.55, POLE, 1.0, 0.55)
        if i:
            qx = towers[i - 1][0]
            y0w, y1w = 1156 - towers[i - 1][1] * 0.9, 1156 - ph * 0.9
            s.path("M %s,%s Q %s,%s %s,%s" % (f(qx), f(y0w),
                   f((qx + px) / 2), f((y0w + y1w) / 2 + 8), f(px), f(y1w)),
                   stroke=POLE, w=0.9, opacity=0.5)
    # 地平尘霞
    haze = s.vgrad("haze", [(0, DUST, 0.0), (1, DUST, 0.34)])
    s.rect(0, 1000, 1024, 156, haze)
    return s


def wheel_strip():
    """独层地标：斗轮挖掘机 3200x900（透明底）。条带位 (8,270) 居中挂载：
    画布 y0=世界 −180（画布 y = 世界 y + 180，同天梯缆账）；机座画布 840=
    世界 660 沉进远景地面线。地标 tex_x=1620（画布 x）：总 extent
    [1245,1860]（半宽 375 ∈ [1200+375, 3200−1200−375]=[1575,1825] ✓，
    防回绕弹切）。原生朝左（斗轮臂伸向玩家侧）。种子 6062。"""
    rng = random.Random(6062)
    s = Svg(3200, 900)
    # ---- 机座履带台（双支座）----
    s.rect(1560, 806, 300, 34, MACHINE_DEEP, 0.92)
    s.rect(1560, 806, 300, 4, RIM, 0.7)
    for tx in (1576, 1816):
        s.rect(tx, 838, 68, 22, MACHINE_DEEP, 0.92)
    # ---- 主体车架 + 驾驶舱 + 顶塔 ----
    s.rect(1600, 640, 240, 170, MACHINE, 0.95)
    s.rect(1600, 640, 240, 6, RIM, 0.8)
    s.rect(1650, 556, 110, 88, MACHINE, 0.95)      # 舱体
    s.rect(1650, 556, 110, 5, RIM, 0.8)
    s.rect(1688, 512, 34, 48, MACHINE, 0.95)       # 顶塔
    # 舱窗（矿灯金）
    for wx, wy in ((1666, 586), (1694, 586), (1722, 586), (1666, 616), (1722, 616)):
        s.rect(wx, wy, 12, 10, LAMP, 0.85)
    glow_dot(s, 1705, 506, "#ff4640", r=2.4)
    # ---- 斗轮臂：从舱体斜向上到左端，末端斗轮 ----
    s.poly([(1660, 610), (1352, 448), (1362, 424), (1676, 586)], MACHINE, 0.95)
    s.poly([(1672, 596), (1370, 448), (1374, 440), (1678, 586)], MACHINE_DEEP, 0.85)
    wcx, wcy, wcr = 1322.0, 420.0, 76.0
    s.circle(wcx, wcy, wcr + 5, MACHINE_DEEP, 0.95)          # 轮缘外圈
    s.circle(wcx, wcy, wcr - 16, "#c9a274", 0.35)            # 轮内透天微尘
    for i in range(8):                                       # 辐条 + 轮缘铲斗
        aa = i * 3.14159265 / 4.0 + 0.26
        s.line(wcx, wcy, wcx + (wcr - 10) * cos_(aa), wcy + (wcr - 10) * sin_(aa),
               MACHINE_DEEP, 4.0, 0.95)
        bx = wcx + (wcr + 2) * cos_(aa)
        by = wcy + (wcr + 2) * sin_(aa)
        s.rect(bx - 7, by - 7, 14, 14, MACHINE_DEEP, 0.95)   # 铲斗（方斗）
    s.circle(wcx, wcy, 9, MACHINE_DEEP, 0.95)                # 轮毂
    glow_dot(s, wcx, wcy - wcr - 12, "#ff4640", r=2.2)
    # 卸料臂（向右后方的悬臂输送带）
    s.poly([(1836, 620), (1960, 566), (1966, 580), (1842, 636)], MACHINE, 0.9)
    s.rect(1952, 556, 16, 12, MACHINE, 0.9)
    glow_dot(s, 1960, 552, LAMP, r=2.0, halos=((4, 0.35), (8, 0.12)))
    # ---- 机座尘雾（沉入远景地面的柔读法）----
    for ex, ey, rx, ry, op in ((1710, 852, 190, 22, 0.5), (1560, 860, 130, 16, 0.4),
                               (1860, 858, 120, 15, 0.35)):
        s.ellipse(ex, ey, rx, ry, "#d9b98c", op)
    # 环境沙暴横掠（独层内的风纹，几笔即可）
    for _ in range(8):
        lx = rng.uniform(400, 2800)
        ly = rng.uniform(300, 760)
        ln = rng.uniform(60, 150)
        s.line(lx, ly, lx - ln, ly + ln * 0.05, DUST, 2.0, rng.uniform(0.12, 0.24))
    return s


def cos_(a: float) -> float:
    import math
    return math.cos(a)


def sin_(a: float) -> float:
    import math
    return math.sin(a)


def mid_strip():
    """中景条 2048x520（透明底，tile 2048）：三段各异矿区构筑。
    世界 y：画布 520=世界 700；构筑脚画布 460..500（世界 640..680，
    贴地块顶后方）。两侧 40px 留空。种子 6063。"""
    rng = random.Random(6063)
    s = Svg(2048, 520)

    # ---- A 段：桁架输送栈桥（长跨 + A 形排架腿）----
    bx0, bx1, by0, by1 = 60.0, 700.0, 200.0, 226.0
    s.line(bx0, by0, bx1, by0, TRUSS, 5)
    s.line(bx0, by1, bx1, by1, TRUSS, 5)
    n = int((bx1 - bx0) // 34)
    for i in range(n + 1):
        vx = bx0 + i * 34
        s.line(vx, by0, vx, by1, TRUSS, 1.6)
        if i < n:
            if i % 2 == 0:
                s.line(vx, by0, vx + 34, by1, TRUSS, 1.6)
            else:
                s.line(vx, by1, vx + 34, by0, TRUSS, 1.6)
    s.rect(bx0, by0 - 6, bx1 - bx0, 6, SILO_DEEP)     # 传送带罩
    for px in (140, 380, 620):                        # A 形支腿
        s.poly([(px - 16, 486), (px - 3, by1), (px + 3, by1), (px + 8, 486)], TRUSS, 0.95)
        s.poly([(px + 16, 486), (px + 3, by1), (px - 3, by1), (px - 8, 486)], TRUSS, 0.95)
        s.line(px - 13, 458, px + 13, 458, TRUSS, 2, 0.95)
        glow_dot(s, px, by1 + 3, LAMP, r=1.8, halos=((4, 0.35), (8, 0.12)))

    # ---- B 段：矿仓群（筒体+锥顶+仓间连桥）----
    for cx, cw, ch in ((860, 44, 116), (916, 48, 132), (982, 42, 104)):
        top = 492 - ch
        s.rect(cx, top, cw, ch, SILO, 0.94)
        s.poly([(cx - 4, top), (cx + cw + 4, top), (cx + cw / 2, top - 16)], SILO_DEEP, 0.94)
        s.line(cx - 4, top + 16, cx + cw + 4, top + 16, SILO_DEEP, 1.6, 0.9)
        s.rect(cx + 8, top + 30, cw - 16, 8, SILO_DEEP, 0.6)   # 仓身箍带
    s.line(852, 420, 1030, 420, SILO_DEEP, 2, 0.9)     # 仓间连桥
    glow_dot(s, 940, 372, LAMP, r=2.2, halos=((5, 0.4), (9, 0.15)))

    # ---- C 段：钻井井架 + 半埋管廊 ----
    dx = 1500.0
    s.line(dx - 30, 492, dx, 330, TRUSS, 3.2)
    s.line(dx + 30, 492, dx, 330, TRUSS, 3.2)
    for yy in range(350, 480, 26):
        t = (yy - 330.0) / 162.0
        half = 30.0 * t
        s.line(dx - half, yy, dx + half, yy, TRUSS, 1.6, 0.95)
    s.rect(dx - 8, 306, 16, 26, SILO_DEEP)             # 顶滑轮座
    s.circle(dx, 302, 6, TRUSS)
    glow_dot(s, dx, 294, "#ff4640", r=2.0)
    # 半埋管廊（三节，沙掩下缘）
    for i in range(3):
        px = 1620 + i * 74
        s.rect(px, 470, 66, 26, SILO, 0.95)
        s.ellipse(px + 33, 470, 33, 10, RIM, 0.55)     # 管口受光
        s.ellipse(px + 33, 498, 40, 8, "#c9a274", 0.5)  # 掩埋沙
    # 背景沙暴横掠（段间留白处）
    for _ in range(9):
        lx = rng.uniform(80, 1960)
        ly = rng.uniform(260, 430)
        ln = rng.uniform(40, 100)
        s.line(lx, ly, lx - ln, ly + ln * 0.05, DUST, 1.8, rng.uniform(0.14, 0.3))
    # 底部尘雾
    g = s.vgrad("fog", [(0, DUST, 0.0), (1, DUST, 0.4)])
    s.rect(0, 452, 2048, 68, g)
    return s


def ground_fallback():
    """兜底地面条 256x480（GroundStrip）：沙层断面=立面渐变 + 层理 +
    半埋矿石闪点 + 岩块。同 world_3 env_snow_ground 的用法（region 6400x480，
    scroll=1 钉屏幕）。种子 6064。"""
    rng = random.Random(6064)
    s = Svg(256, 480)
    body = s.vgrad("grd", [(0, "#9a4527", 1), (0.42, "#62281a", 1), (1, "#3f1a10", 1)])
    s.rect(0, 0, 256, 480, body)
    for ty, op in ((60, 0.3), (140, 0.24), (240, 0.18), (360, 0.12)):
        s.rect(0, ty, 256, 2, "#7a321e", op)
    # 半埋矿石（暗壳+金闪点）
    for _ in range(10):
        ox = rng.uniform(16, 240)
        oy = rng.uniform(80, 440)
        ow = rng.uniform(8, 18)
        s.poly([(ox, oy), (ox + ow, oy - 5), (ox + ow * 2, oy), (ox + ow, oy + 5)], ORE)
        if rng.random() < 0.6:
            s.circle(ox + ow, oy - 1, 1.4, LAMP, 0.7)
    return s


def deck():
    """栈桥桥面 720x26（脚手架断桥件）：矿区钢板 + 格栅 + 桁架 + 金位标灯。
    行走面=顶缘（受光锈橙 3px + 钢板 7px），桁架收在下 16px。"""
    s = Svg(720, 26)
    s.rect(0, 0, 720, 3, RIM)                  # 顶缘受光（白热天光）
    s.rect(0, 3, 720, 7, "#4e2418")            # 钢桥面板
    for gx in range(9, 720, 18):               # 格栅纹
        s.line(gx, 4.5, gx, 9.5, SILO_DEEP, 1.6, 0.6)
    s.rect(0, 10, 720, 2.5, ORE)               # 前缘口
    for lx in range(60, 720, 120):             # 金位标灯
        s.circle(lx, 11.2, 1.2, LAMP, 0.85)
    for i in range(18):                        # 桁架腹杆
        x0 = i * 40.0
        if i % 2 == 0:
            s.line(x0, 12.5, x0 + 40, 24.5, SILO_DEEP, 2.0)
        else:
            s.line(x0, 24.5, x0 + 40, 12.5, SILO_DEEP, 2.0)
    s.line(0, 24.5, 720, 24.5, SILO_DEEP, 2.0)  # 下弦
    return s


def main():
    os.makedirs(ASSETS, exist_ok=True)
    save(far_strip(), "env_red_far.svg", """第六章远景条 1024x1300（视差 0.9，tile 1024）：白热天光渐变
#b8d0dc→#ded0b4→#f0cfa2 + 高天尘带 + 远峡壁（右翼地层理）+ 电塔列 +
地平尘霞（画布 1150=世界 580 藏地块后）。画布底=世界 730。两侧 24px 留空。
太阳/斗轮巨机走独层不在本条（唯一地标规矩）。种子 6061。""")
    save(wheel_strip(), "env_red_wheel.svg", """第六章独层地标：斗轮挖掘机 3200x900（视差 0.9，tile 3200 同屏一份）。
地标 tex_x=1620，总 extent [1245,1860]（∈[1575,1825] 防回绕弹切，
worlds.md §5）。条带位 (8,270) 居中挂载：画布 y0=世界 −180；机座画布
840=世界 660 沉远景地面线。原生朝左。种子 6062。""")
    save(mid_strip(), "env_red_mid.svg", """第六章中景条 2048x520（视差 0.55，tile 2048，透明底）：三段各异
矿区构筑（桁架输送栈桥/矿仓群/井架+半埋管廊）。画布 520=世界 700。
两侧 40px 留空。种子 6063。""")
    th = gv.THEMES["p6_desert"]
    with open(os.path.join(ASSETS, "env_red_ground_top.svg"), "w", encoding="utf-8") as fp:
        text = bgv.bake_band("red", th)
        fp.write(text)
        print("env_red_ground_top.svg:", len(text) // 1024, "KB")
    with open(os.path.join(ASSETS, "env_red_ground_fill.svg"), "w", encoding="utf-8") as fp:
        text = bgv.bake_fill(th)
        fp.write(text)
        print("env_red_ground_fill.svg:", len(text) // 1024, "KB")
    save(ground_fallback(), "env_red_ground.svg", """第六章兜底地面条 256x480（GroundStrip）：沙层断面渐变+层理+
半埋矿石闪点。种子 6064。""")
    save(deck(), "env_red_deck.svg", """第六章栈桥桥面 720x26（脚手架断桥件）：受光锈橙顶缘+矿区钢板格栅+
桁架+金位标灯。scaffold_6 pier_color=#4e2418。""")
    print("red desert chapter env baked.")


if __name__ == "__main__":
    main()
