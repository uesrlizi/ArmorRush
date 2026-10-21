# -*- coding: utf-8 -*-
"""2d-ac 场景美术提案 · 第二批：方案五~七。

复用 generate_proposals.py 的 Svg 框架（画布 1200x540，地面线 y=330，
玩家位 x=400 左 1/3 留空，两侧剪影道具让出中央 gameplay 视野）。
图元约束同第一批：只用 rect/polygon/path/circle/ellipse/line + 渐变，
不用 filter/pattern/use/text/image，也不用 <g transform>（坐标直接算死）。
种子固定，重跑结果一致。三个新方向的调色都刻意避开已实装四套的色域：
  一 锈雨废都=脏赭 / 二 精炼所=钢青绿 / 三 雪原=高调冰白 / 四 珊瑚夜=靛蓝夜+橙辉
  五 破晓云廊=金霞玫瑰（暖高调）/ 六 赤沙矿区=白热天+赤红沙（暖沙色但高饱和）
  七 溺海都会=青绿海光（冷高调，与二的暗钢绿区分）
"""
import math
import os
import random

import generate_proposals as gp
from terrain_blocks import ground_v2
from generate_proposals import (Svg, W, H, GROUND, f, glow_dot, haze_band,
                                arc_path)

OUT = os.path.dirname(os.path.abspath(__file__))


# ============================================================
# 方案五 · 破晓云廊（高空航线：云海 + 浮空平台 + 细碎天环 + 天梯缆）
# 坐标账：桥面(跑道)=y330；云海平线 y288；天空 0..288。
# ============================================================
def dawn_cloud():
    rng = random.Random(505)
    s = Svg()

    # 天空：紫夜 → 玫瑰 → 金霞。色带账 (0,#33265a)(0.45,#8e5578)(0.75,#d8846e)(1,#f4b071)
    sky = s.vgrad("sky5", [(0, "#33265a", 1), (0.45, "#8e5578", 1),
                           (0.75, "#d8846e", 1), (1, "#f4b071", 1)])
    s.rect(0, 0, W, GROUND, sky)

    # 低日：白金盘半浸在云海线上（盘心 y282，光晕下缘探进云带）
    s.glow_ellipse(872, 288, 170, 66, "#ffd9a0", 0.32)
    s.glow_ellipse(872, 284, 78, 36, "#ffe9c2", 0.55)
    s.ellipse(872, 282, 32, 15, "#fff3d8", 0.9)

    # 天穹巨环（侧视远环=两道近平行浅弧+连接刻度；与珊瑚夜的重粗暗环区分——这里是晨光里的细环）
    s.path(arc_path(600, -170, 330, 62, 118), stroke="#f2c896", w=8, opacity=0.5)
    s.path(arc_path(590, -184, 330, 72, 108), stroke="#f2c896", w=5, opacity=0.3)
    for ta in (78, 90, 102):  # 环面连接刻度
        a = math.radians(ta)
        s.line(590 + 330 * math.cos(a), -184 + 330 * math.sin(a),
               600 + 344 * math.cos(a), -170 + 344 * math.sin(a), "#f2c896", 2, 0.35)

    # 高天浮尘（金屑）
    for _ in range(16):
        s.circle(rng.uniform(0, W), rng.uniform(20, 200), rng.uniform(0.8, 1.8),
                 "#ffe2b0", rng.uniform(0.15, 0.45))

    # ---- 远景浮空平台链（0.9）：同一悬停高度的平台编队（底边 y245..263 窄带）----
    x = -20.0
    while x < W + 30:
        bw = rng.uniform(90, 170)
        by = 254.0 + rng.uniform(-7, 9)
        body = "#6b5480"
        s.rect(x, by, bw, rng.uniform(7, 10), body, 0.55)
        for _t in range(rng.randint(1, 2)):
            tw = rng.uniform(9, 20)
            th = rng.uniform(22, 62)
            tx = x + rng.uniform(6, max(8, bw - tw - 6))
            s.rect(tx, by - th, tw, th, body, 0.55)
            if rng.random() < 0.45:  # 天线
                s.line(tx + tw * 0.5, by - th, tx + tw * 0.5,
                       by - th - rng.uniform(8, 20), body, 1.2, 0.55)
        # 板底鳍 + 舷灯（悬停体的下挂结构）
        s.poly([(x + bw * 0.22, by + 9), (x + bw * 0.40, by + 9),
                (x + bw * 0.34, by + rng.uniform(15, 22)), (x + bw * 0.25, by + rng.uniform(15, 22))],
               body, 0.55)
        s.circle(x + bw * rng.uniform(0.15, 0.8), by + rng.uniform(10, 14), 1.6, "#ffc46a", 0.6)
        x += bw + rng.uniform(36, 90)

    # 天梯缆（左侧地标）：基座平台 + 出画斜缆 + 配重块 + 爬升灯
    s.rect(38, 272, 78, 14, "#5a446e", 0.62)
    s.rect(52, 244, 30, 28, "#5a446e", 0.62)
    s.line(66, 244, 34, -10, "#5a446e", 3, 0.62)
    s.rect(30, 96, 26, 9, "#5a446e", 0.62)          # 配重平台
    glow_dot(s, 56, 200, "#ffc46a", r=2.0, halos=((5, 0.4), (9, 0.16)))  # 爬升舱灯

    # ---- 云海（先铺整带，再压云顶亮团）----
    sea_top = 288.0
    upper = s.vgrad("cl5u", [(0, "#f4e0e4", 1), (1, "#c494ae", 1)])
    s.rect(0, sea_top, W, GROUND - sea_top, upper)
    lower = s.vgrad("cl5d", [(0, "#b489a4", 1), (0.55, "#7a5f86", 1), (1, "#453759", 1)])
    s.rect(0, GROUND, W, H - GROUND, lower)   # 桥下云海渐深（兼 HUD 深底）

    # 云海平线亮边 + 云顶亮团（受光面粉团 + 底影）
    s.line(0, sea_top + 1, W, sea_top + 1, "#fdeee8", 2, 0.55)
    cx = -30.0
    while cx < W + 40:
        crx = rng.uniform(42, 96)
        cry = rng.uniform(7, 16)
        cy = sea_top + rng.uniform(2, 20)
        s.ellipse(cx + crx, cy, crx, cry, "#fbeef0", rng.uniform(0.5, 0.85))
        s.ellipse(cx + crx, cy + cry * 0.7, crx * 0.9, cry * 0.55, "#a87c96", 0.35)
        cx += crx * rng.uniform(1.1, 1.8)
    # 侧远两团高积云（高度差拉开云海纵深；右团避开右停泊平台）
    for mx, my, mrx, mry, op in ((150, 262, 90, 20, 0.5), (1140, 242, 64, 13, 0.35)):
        s.ellipse(mx, my, mrx, mry, "#f6dde2", op)
        s.ellipse(mx, my + mry * 0.6, mrx * 0.9, mry * 0.5, "#9a708c", 0.3)

    # ---- 中景浮空平台两座（0.55，实色+霞光描边）----
    # 左：作业平台（龙门架塔 + 板下机库）
    plx, ply = 58.0, 300.0
    s.rect(plx, ply, 244, 15, "#4e3c64", 0.94)                       # 平台板
    s.line(plx, ply, plx + 244, ply, "#e8b48a", 2.2, 0.85)           # 顶缘霞光描边
    s.rect(plx + 30, ply - 78, 34, 78, "#4e3c64", 0.94)              # 塔A
    s.line(plx + 30, ply - 78, plx + 64, ply - 78, "#e8b48a", 1.8, 0.8)
    s.line(plx + 47, ply - 78, plx + 47, ply - 102, "#4e3c64", 2.2, 0.94)
    s.poly([(plx + 118, ply), (plx + 176, ply), (plx + 170, ply - 44), (plx + 124, ply - 44)],
           "#4e3c64", 0.94)                                          # 塔B（斜顶）
    s.line(plx + 124, ply - 44, plx + 170, ply - 44, "#e8b48a", 1.6, 0.75)
    s.rect(plx + 88, ply + 15, 56, 22, "#443258", 0.94)              # 板下机库
    for wx, wy in ((plx + 40, ply - 62), (plx + 52, ply - 62), (plx + 40, ply - 44),
                   (plx + 134, ply - 30), (plx + 152, ply - 30)):
        s.rect(wx, wy, 6, 7, "#ffc46a", 0.85)                        # 暖金窗
    glow_dot(s, plx + 47, ply - 106, "#ff4640", r=2.4)
    # 右：停泊平台（桅杆 + 碟形天线）
    prx, pry = 922.0, 308.0
    s.rect(prx, pry, 226, 13, "#4e3c64", 0.94)
    s.line(prx, pry, prx + 226, pry, "#e8b48a", 2.2, 0.85)
    s.rect(prx + 148, pry - 56, 30, 56, "#4e3c64", 0.94)
    s.line(prx + 163, pry - 56, prx + 163, pry - 86, "#4e3c64", 2, 0.94)
    s.ellipse(prx + 163, pry - 94, 13, 9, "#5c4774", 0.94)
    for wx in (prx + 24, prx + 48, prx + 72, prx + 96):
        s.rect(wx, pry - 26, 6, 7, "#ffc46a", 0.8)
    glow_dot(s, prx + 163, pry - 100, "#ff4640", r=2.2)

    # ---- 云上高架桥地块（拆地块 v2 桥面变体：走道带+薄箱梁+排架柱没入云海）----
    # 近层云顶团（桥面之下、排架之间）
    for cx2, cy2, rx2, ry2 in ((150, 388, 120, 20), (420, 420, 150, 24),
                               (760, 396, 130, 22), (1060, 432, 160, 26)):
        s.ellipse(cx2, cy2, rx2, ry2, "#e9d3de", 0.5)
        s.ellipse(cx2, cy2 + ry2 * 0.6, rx2 * 0.85, ry2 * 0.5, "#a87c96", 0.3)
    ground_v2.draw_ground_deck(s, "p5_cloud", k=1.0, fade=478.0)
    # 龙门架（右平地段）
    gx = 1100.0
    s.rect(gx - 4, 268, 8, 66, "#3d3856")
    s.rect(gx + 150, 268, 8, 66, "#3d3856")
    s.rect(gx - 10, 260, 176, 10, "#3d3856")
    s.line(gx - 10, 260, gx + 166, 260, "#e8b48a", 1.5, 0.6)
    glow_dot(s, gx + 44, 265, "#ffb347", r=2.0, halos=((5, 0.35), (9, 0.13)))
    glow_dot(s, gx + 112, 265, "#ffb347", r=2.0, halos=((5, 0.35), (9, 0.13)))

    # 前景流云（低层掠过地块立面）
    for fx, fy, frx, fry, op in ((120, GROUND + 44, 190, 22, 0.22), (620, GROUND + 58, 230, 26, 0.18),
                                 (1040, GROUND + 40, 170, 20, 0.2)):
        s.ellipse(fx, fy, frx, fry, "#e3ccdb", op)
    return s


# ============================================================
# 方案六 · 赤沙矿区（荒漠矿区：白热天光 + 赤红沙海 + 斗轮巨机 + 输送栈桥）
# 坐标账：地表 y330；远峡壁只占左右两翼，中央留开阔沙海。
# ============================================================
def red_desert():
    rng = random.Random(606)
    s = Svg()

    # 天空：淡蓝 → 沙色 → 地平尘霞。色带账 (0,#b8d0dc)(0.5,#ded0b4)(1,#f0cfa2)
    sky = s.vgrad("sky6", [(0, "#b8d0dc", 1), (0.5, "#ded0b4", 1), (1, "#f0cfa2", 1)])
    s.rect(0, 0, W, GROUND, sky)
    # 白热小日（高位、刺目）
    s.glow_ellipse(305, 104, 90, 76, "#fff6dd", 0.5)
    s.glow_ellipse(305, 104, 44, 38, "#fffdf2", 0.7)
    s.circle(305, 104, 20, "#fffef8", 0.95)

    # ---- 远景右翼：红峡台地（层理剪影）----
    mesa_r = [(988, GROUND), (1010, 262), (1046, 224), (1082, 246), (1120, 186),
              (1148, 202), (1172, 158), (1200, 170), (1200, GROUND)]
    s.poly(mesa_r, "#b87a50", 0.62)
    # 层理横线（手工：在台地体内画短横线）
    for x0, x1, yy in ((1000, 1060, 300), (1030, 1110, 276), (1060, 1160, 250),
                       (1090, 1190, 226), (1130, 1200, 196)):
        s.line(x0, yy, x1, yy, "#a87450", 1.4, 0.55)
    # 远景左翼：低沙梁
    ridge_l = [(0, GROUND), (40, 300), (110, 286), (190, 298), (260, GROUND)]
    s.poly(ridge_l, "#b87a50", 0.45)

    # ---- 远景地标：斗轮挖掘机（左侧，剪影 #9a6a48）----
    mec = "#9a6a48"
    s.rect(168, GROUND - 84, 118, 60, mec, 0.78)                     # 主体车架
    s.rect(196, GROUND - 118, 54, 36, mec, 0.78)                     # 驾驶舱体
    s.rect(214, GROUND - 134, 18, 18, mec, 0.78)
    # 履带支座
    for tx in (176, 262):
        s.rect(tx, GROUND - 30, 34, 30, mec, 0.78)
    # 斗轮臂：从车架斜向上到左上，末端斗轮
    s.line(196, GROUND - 108, 96, 168, mec, 9, 0.78)
    s.line(196, GROUND - 96, 98, 182, mec, 4, 0.78)
    wcx, wcy, wcr = 88.0, 156.0, 36.0
    # 斗轮=外圈 + 挖空(近似该高度的沙色天) + 辐条 + 轮缘铲斗
    s.circle(wcx, wcy, wcr + 2, mec, 0.78)
    s.circle(wcx, wcy, wcr - 8, "#d9ccb2", 0.92)
    for i in range(6):
        aa = math.radians(i * 60 + 15)
        s.line(wcx, wcy, wcx + (wcr - 6) * math.cos(aa), wcy + (wcr - 6) * math.sin(aa), mec, 2.6, 0.78)
        bx2, by2 = wcx + (wcr + 1) * math.cos(aa), wcy + (wcr + 1) * math.sin(aa)
        s.circle(bx2, by2, 4.2, mec, 0.78)                           # 轮缘铲斗
    s.circle(wcx, wcy, 5, mec, 0.78)
    glow_dot(s, 223, GROUND - 138, "#ffb347", r=2.2, halos=((5, 0.4), (9, 0.15)))

    # 中远电塔列（中央纵深；加高让塔头露出中段高台）
    pole = "#8a5a3c"
    towers = [(392, 122), (566, 110), (742, 116), (912, 102)]
    for i, (pxx, ph) in enumerate(towers):
        s.line(pxx, GROUND, pxx, GROUND - ph, pole, 2.2, 0.6)
        s.line(pxx - 14, GROUND - ph * 0.72, pxx + 14, GROUND - ph * 0.72, pole, 1.6, 0.6)
        s.line(pxx - 10, GROUND - ph * 0.9, pxx + 10, GROUND - ph * 0.9, pole, 1.4, 0.6)
        s.line(pxx - 8, GROUND, pxx - 2, GROUND - ph * 0.55, pole, 1.2, 0.55)
        s.line(pxx + 8, GROUND, pxx + 2, GROUND - ph * 0.55, pole, 1.2, 0.55)
        if i:
            qx = towers[i - 1][0]
            y0w, y1w = GROUND - towers[i - 1][1] * 0.9, GROUND - ph * 0.9
            s.path(f"M {f(qx)},{f(y0w)} Q {f((qx + pxx) / 2)},{f((y0w + y1w) / 2 + 10)} {f(pxx)},{f(y1w)}",
                   stroke=pole, w=1.0, opacity=0.5)

    haze_band(s, 216, GROUND, "#e6cba2", 0.3)

    # ---- 中景：输送栈桥 + 矿仓 ----
    # 桁架栈桥（锈红，跨中景；抬高避让中段 t2 高台顶 268）
    bx0, bx1, by0, by1 = 262.0, 930.0, 214.0, 240.0
    truss = "#7e3c28"
    s.line(bx0, by0, bx1, by0, truss, 5)
    s.line(bx0, by1, bx1, by1, truss, 5)
    n = int((bx1 - bx0) // 34)
    for i in range(n + 1):
        vx = bx0 + i * 34
        s.line(vx, by0, vx, by1, truss, 1.8)
        if i < n:
            if i % 2 == 0:
                s.line(vx, by0, vx + 34, by1, truss, 1.8)
            else:
                s.line(vx, by1, vx + 34, by0, truss, 1.8)
    s.rect(bx0, by0 - 6, bx1 - bx0, 6, "#6e3424")                    # 传送带罩
    for px in (350, 620, 890):                                       # 排架支腿(A形)
        s.poly([(px - 16, GROUND), (px - 3, by1), (px + 3, by1), (px + 8, GROUND)], truss, 0.95)
        s.poly([(px + 16, GROUND), (px + 3, by1), (px - 3, by1), (px - 8, GROUND)], truss, 0.95)
        s.line(px - 13, GROUND - 26, px + 13, GROUND - 26, truss, 2, 0.95)
        glow_dot(s, px, by1 + 3, "#ffb347", r=1.8, halos=((4, 0.35), (8, 0.12)))
    # 矿仓群（右中景；筒体落最低档带面）
    for cx, cw, ch in ((966, 40, 100), (1014, 44, 112), (1068, 38, 92)):
        top = GROUND - ch
        s.rect(cx, top, cw, ch, "#6e3424", 0.92)
        s.poly([(cx - 4, top), (cx + cw + 4, top), (cx + cw / 2, top - 16)], "#5e2c1e", 0.92)
        s.line(cx - 4, top + 14, cx + cw + 4, top + 14, "#5e2c1e", 1.6, 0.9)
    s.line(960, GROUND - 78, 1110, GROUND - 78, "#5e2c1e", 2, 0.9)   # 仓间连桥
    glow_dot(s, 1036, GROUND - 120, "#ffb347", r=2.2, halos=((5, 0.4), (9, 0.15)))

    # ---- 地表（拆地块 v2）----
    ground_v2.draw_ground(s, "p6_desert", bottom=H, k=1.0)
    # 半埋残骸（左平地段走道带上：车体+炮塔+断管，沙掩到车体下缘）
    s.poly([(36, 312), (90, 280), (166, 286), (196, 308), (188, 326), (44, 328)], "#4e2418")
    s.poly([(90, 280), (120, 258), (148, 264), (166, 286)], "#421e14")   # 炮塔
    s.line(148, 270, 208, 236, "#421e14", 2.8, 0.95)                     # 断管(上翘)
    s.line(40, 322, 188, 318, "#3a1a10", 2.6, 0.9)                       # 车体底线
    s.ellipse(178, 326, 66, 10, "#c97a52", 0.8)                          # 尾部掩埋沙
    s.ellipse(90, 332, 56, 8, "#d98c5e", 0.55)
    # 前景岩板 + 矿石（近相机剪影，压在块体立面前）
    s.poly([(1050, H), (1088, 468), (1150, 458), (1200, 474), (1200, H)], "#5e2a1c")
    s.poly([(980, H), (1006, 486), (1044, 482), (1058, H)], "#522418")
    for ox, oy, ow in ((1010, 500, 14), (1120, 492, 10), (60, 510, 16)):
        s.poly([(ox, oy), (ox + ow, oy - 6), (ox + ow * 2, oy), (ox + ow, oy + 6)], "#3f1d12")
    # 沙暴横掠（速度感）
    for _ in range(10):
        lx, ly = rng.uniform(60, W), rng.uniform(120, 300)
        ln = rng.uniform(46, 110)
        s.line(lx, ly, lx - ln, ly + ln * 0.06, "#eccfa4", 1.8, rng.uniform(0.16, 0.34), cap="round")
    return s


# ============================================================
# 方案七 · 溺海都会（沿岸战场：青绿海光 + 沉没天际线 + 倾覆巨舰 + 海堤公路）
# 坐标账：海平线 y308；海堤路 y330..386；近海 386..540。
# ============================================================
def drowned_city():
    rng = random.Random(707)
    s = Svg()

    # 天空：青绿高调。色带账 (0,#9ecdd2)(0.55,#cfe9e2)(1,#eef8f0)
    sky = s.vgrad("sky7", [(0, "#9ecdd2", 1), (0.55, "#cfe9e2", 1), (1, "#eef8f0", 1)])
    s.rect(0, 0, W, GROUND, sky)
    s.glow_ellipse(905, 96, 130, 100, "#ffffff", 0.32)

    # ---- 海平线与远海带 ----
    SEA = 308.0
    sea = s.vgrad("sea7", [(0, "#5fc0b0", 1), (1, "#2e948a", 1)])
    s.rect(0, SEA, W, GROUND - SEA, sea)
    s.line(0, SEA, W, SEA, "#eafaf2", 2, 0.7)

    # ---- 远景：沉没天际线（楼体入水即断，无地面接触）----
    far = "#7fb5ae"
    towers = [(52, 26, 96), (96, 40, 150), (156, 30, 120), (206, 48, 176), (272, 34, 132),
              (330, 26, 90), (470, 44, 140), (536, 30, 104), (588, 38, 158), (648, 30, 118),
              (942, 0, 0), (1010, 34, 120), (1064, 26, 88)]  # (x, w, h)；942 空位留给巨舰
    for tx, tw, th in towers:
        if tw == 0:
            continue
        top = SEA - th
        lean = rng.uniform(-6, 6) if rng.random() < 0.35 else 0.0
        # 楼体（顶缘小破损）
        s.poly([(tx, SEA), (tx + lean * 0.3, top + rng.uniform(2, 10)),
                (tx + tw * 0.5, top), (tx + tw, top + rng.uniform(2, 12)), (tx + tw, SEA)],
               far, 0.8)
        if rng.random() < 0.5:  # 天线
            s.line(tx + tw * 0.4 + lean * 0.4, top + 4, tx + tw * 0.4 + lean * 0.4 + lean,
                   top - rng.uniform(12, 28), far, 1.4, 0.8)
        # 稀窗（暗点）
        for _ in range(rng.randint(2, 4)):
            s.rect(tx + rng.uniform(4, tw - 7), top + rng.uniform(10, max(12, th - 12)),
                   2.5, 4, "#4a7a74", 0.8)
    # 远景倾覆巨舰（右）：龙骨朝天——棱脊壳体 + 垂向肋骨刻 + 断艏楼
    hull_pts = [(862, 308), (884, 282), (912, 266), (946, 256), (986, 250), (1030, 250),
                (1076, 256), (1116, 268), (1152, 286), (1180, 304), (1200, 308)]
    s.path("M " + " L ".join(f"{f(px)},{f(py)}" for px, py in hull_pts),
           fill="#5f8a84", opacity=0.9)
    for i in range(2, 9, 2):                                         # 龙骨肋骨刻
        px, py = hull_pts[i]
        s.line(px, py + 4, px + 2, py + 20, "#4a726e", 1.8, 0.8)
    s.line(884, 288, 1160, 282, "#4a726e", 1.4, 0.7)                 # 纵向板缝
    s.rect(962, 238, 30, 14, "#5f8a84", 0.9)                         # 脱落的艏楼段
    s.line(977, 238, 977, 220, "#5f8a84", 2, 0.9)
    glow_dot(s, 977, 218, "#ff4640", r=2.2, halos=((5, 0.35), (9, 0.13)))
    s.poly([(1116, 268), (1136, 258), (1150, 286)], "#496f6a", 0.9)  # 右段撕裂破口
    s.ellipse(1030, 308, 190, 6, "#1f6a66", 0.4)                     # 舰体水线阴影
    # 日光水路（日下碎光柱）
    gy = SEA + 3
    while gy < GROUND - 2:
        for _ in range(2):
            gx = 872 + rng.uniform(-26, 26)
            s.line(gx, gy, gx + rng.uniform(8, 20), gy, "#f2fffa", 1.6, rng.uniform(0.3, 0.6))
        gy += rng.uniform(3.5, 6)
    haze_band(s, 262, SEA, "#cfe9e2", 0.35)

    # ---- 中景：屋顶孤岛 + 残舰艏 ----
    mid = "#4a7a74"
    # 屋顶块A（带水塔与锈流）
    ax, at = 128.0, 262.0
    s.rect(ax, at, 118, SEA - at, mid, 0.95)
    s.rect(ax + 14, at - 20, 26, 20, "#3f6a64", 0.95)                # 水塔
    s.poly([(ax + 14, at - 20), (ax + 40, at - 20), (ax + 27, at - 30)], "#3f6a64", 0.95)
    s.rect(ax + 66, at - 10, 34, 10, "#3f6a64", 0.95)
    s.line(ax + 96, at, ax + 96, at - 34, "#3f6a64", 2, 0.95)
    glow_dot(s, ax + 96, at - 36, "#ff4640", r=2.0)
    for rx_ in (ax + 30, ax + 74):                                   # 锈流
        s.line(rx_, at + 8, rx_ + 3, SEA - 6, "#7a5a3c", 2.4, 0.4)
    s.ellipse(ax + 59, SEA + 2, 78, 8, "#eafaf2", 0.55)              # 水线泡沫
    # 屋顶块B（右平地段；588/940 处会被中段高台吃掉）
    bx2, bt = 1060.0, 278.0
    s.rect(bx2, bt, 92, SEA - bt, mid, 0.95)
    s.rect(bx2 + 58, bt - 14, 20, 14, "#3f6a64", 0.95)
    s.ellipse(bx2 + 46, SEA + 2, 62, 7, "#eafaf2", 0.5)
    # 残货船艏（左中，右倾插水）
    s.poly([(268, 306), (330, 262), (418, 250), (444, 268), (400, 306)], "#7a4a3c", 0.95)
    s.line(330, 262, 418, 250, "#8f5a48", 2, 0.9)                    # 甲板缘
    s.rect(348, 238, 26, 14, "#7a4a3c", 0.95)                        # 艏楼
    s.line(361, 238, 361, 222, "#7a4a3c", 2, 0.95)
    s.ellipse(400, 310, 60, 9, "#eafaf2", 0.6)                       # 船头破水泡沫
    for chx in range(300, 336, 9):                                   # 锚链入水
        s.circle(chx, 300 + (chx - 300) * 0.4, 1.6, "#5e3628", 0.8)
    # 浮标（信号红；挪到两侧平地段的水面露带）
    for bxx in (180, 1100):
        s.poly([(bxx - 7, SEA + 10), (bxx + 7, SEA + 10), (bxx + 4, SEA), (bxx - 4, SEA)],
               "#ff5a3c", 0.95)
        glow_dot(s, bxx, SEA + 1, "#ff4640", r=1.8, halos=((4, 0.35), (8, 0.12)))
        s.line(bxx - 9, SEA + 12, bxx + 9, SEA + 12, "#eafaf2", 1.4, 0.5)

    # ---- 跨海栈桥地块（拆地块 v2 桥面变体：走道带+薄箱梁+排架柱没入海面）----
    # 近海（桥面之下）：水体 + 浪沫
    front = s.vgrad("sea7f", [(0, "#2e8a84", 1), (1, "#175a58", 1)])
    s.rect(0, GROUND + 4, W, H - GROUND - 4, front)
    for _ in range(14):
        fx0, fy0 = rng.uniform(0, W - 80), rng.uniform(GROUND + 24, H - 12)
        s.line(fx0, fy0, fx0 + rng.uniform(26, 80), fy0 - rng.uniform(0, 4),
               "#d6f2e8", rng.uniform(1.2, 2), rng.uniform(0.2, 0.45))
    ground_v2.draw_ground_deck(s, "p7_sea", k=1.0, fade=474.0)
    # 前景浮标（排架之间的水面上）
    s.poly([(924, 470), (938, 470), (935, 454), (927, 454)], "#ff5a3c", 0.95)
    glow_dot(s, 931, 452, "#ff4640", r=2.4, halos=((6, 0.4), (11, 0.15)))
    s.ellipse(931, 472, 24, 4.5, "#d6f2e8", 0.5)
    return s


# ============================================================
# 画廊：把 PROPOSALS 扩成 7 案后重建 gallery.html（原 4 案种子不变，重跑恒等）
# ============================================================
NEW_PROPOSALS = [
    ("proposal_5_dawn_cloud.svg", dawn_cloud, "方案五 · 破晓云廊",
     "高空航线 vibe：曙光金霞 + 云海 + 细碎天环，浮空平台链与天梯缆线。",
     ["#33265a", "#8e5578", "#f4b071", "#fbeef0", "#4a4662"],
     "天环/浮岛链 0.9 / 中景平台+龙门架 0.55 / 桥面与云下深带 0；暖高调背景衬暗色机体，黄弹靠亮天承托（亮背景章规矩适用）"),
    ("proposal_6_red_desert.svg", red_desert, "方案六 · 赤沙矿区",
     "矿区荒漠 vibe：白热沙暴天光 + 赤红沙海，斗轮巨机与输送栈桥。",
     ["#b8d0dc", "#ded0b4", "#b0512f", "#62281a", "#ffb347"],
     "峡壁/巨机/电塔 0.9 / 栈桥矿仓 0.55 / 红沙地表 0；中性沙色对黄弹友好，沙暴带浓度是唯一风险"),
    ("proposal_7_drowned_city.svg", drowned_city, "方案七 · 溺海都会",
     "沿岸战场 vibe：高调青绿海光 + 沉没天际线，倾覆巨舰与海堤公路。",
     ["#9ecdd2", "#cfe9e2", "#5fc0b0", "#5a7268", "#ff5a3c"],
     "沉没楼群/巨舰 0.9 / 屋顶残舰 0.55 / 海堤+近海 0；高亮水面对深色机体与红眼最友好，反光带避开中央走弹区"),
]


def build_all_and_gallery():
    for fname, fn, *_ in list(gp.PROPOSALS) + list(NEW_PROPOSALS):
        fn().save(fname)
    gp.PROPOSALS.extend(NEW_PROPOSALS)
    gp.build_gallery()


if __name__ == "__main__":
    build_all_and_gallery()
