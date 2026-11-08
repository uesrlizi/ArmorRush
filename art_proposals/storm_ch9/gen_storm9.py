# -*- coding: utf-8 -*-
"""world_9 场景美术提案 ·「雷暴线场」（接 world_8 镜盐之原之后，第九章）。

复用 generate_proposals.py 的 Svg 框架（画布 1200x540，档位区账
SEQ=[0,0,2,2,2,1,1,0,0,0]：t0=[-100,220]∪[1020,1500] 顶 332 / t2=[220,700] 顶 268 /
t1=[700,1020] 顶 300；地块=terrain_blocks/ground_v2.py THEMES.p9_storm）。
图元约束：只用 rect/polygon/path/circle/ellipse/line + 渐变；禁 filter/pattern/
use/text/transform；rect+rotate 会崩；一切线段两端必须落地、接实物或出画；
条带里不画太阳/闪电盘等唯一地标（雷暴光交给地平辉光+天顶渐变承担）。

主题：超高压输电线走廊横穿雷暴荒原——成排门型铁塔、断头高架、垂弧断缆，
雷暴压境，线路早已断电，塔上只剩雷暴在走线。
色相（提案只定色相不定明度，§6 细则）：天=雷暴青灰绿中调（战斗带压中调）；
章信号色=雷光紫 #a678e8（电蚀焦痕/警示/航标）；地=焦紫灰硬质荒原；
敌营=焦铁墨紫 #3a3346 族（近黑=敌，不反转；与走道带紫灰、远山青灰三分色相）。
与前八套撞族自查：锈橙暖褐(1)/冷绿(2)/冷蓝灰雪(3)/暗红夜+亮钢蓝(4)/
金霞紫罗兰(5)/白热赤红(6)/青绿海光(7)/杏金绯粉(8)——雷暴青灰绿天+雷光紫+
焦紫灰地全错开 ✓；敌营焦铁墨紫非奶油白非低对比浅色 ✓。

本脚本产出（全部 storm_ch9/ 内）：
  proposal_9_storm_line.svg  主视景提案（评审对象，与八套同规格同框架）
  env_storm_far.svg          远景条 1024x1300（画布 y=世界 y+570，含天色）
  env_storm_mid.svg          中景条 2048x520 透明底（画布 y=世界 y−180；
                             落地件脚 488..500，地形顶 664=画布 484）
  enemy_squad_ch9.svg        敌营小队剪影配色示意（五单位+色板条）
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "terrain_blocks")))
from generate_proposals import Svg, W, H, GROUND, f, glow_dot  # noqa: E402
import ground_v2 as gv  # noqa: E402

SKY_STOPS = [(0, "#3a4448", 1), (0.5, "#5e6a66", 1), (1, "#8e8e92", 1)]
STORM_GLOW = "#b09ae0"          # 地平雷光紫辉
SIG = "#a678e8"                 # 雷光紫（章信号色）
STEEL = "#8e9ab0"               # 钢青铁件亮缘
PYLON = "#46524f"               # 远层铁塔剪影（比天暗两档、比中景件亮=景深不反）
RIDGE_B = "#525e58"             # 远山（后排）
RIDGE_F = "#3a4642"             # 远山（前排）
TH = gv.THEMES["p9_storm"]

# 焦铁墨紫敌营（近黑=敌，中亮背景章不反转）
E_LIGHT, E_BODY, E_BELLY, E_GAP = "#5a5068", "#3a3346", "#262032", "#191524"
EYE = "#ff4640"                 # 独眼红（阵营铁律）


def catenary(s, x1, y1, x2, y2, sag, color, w, op):
    """垂弧缆：二次贝塞尔近似（两端必须接实物）。"""
    cx, cy = (x1 + x2) / 2, max(y1, y2) + sag
    s.path(f"M {f(x1)},{f(y1)} Q {f(cx)},{f(cy)} {f(x2)},{f(y2)}",
           stroke=color, w=w, opacity=op, cap="round")


def pylon(s, x, top, base, w, color, op, hi=None):
    """门型输电塔剪影：双柱+三横担+绝缘子点串；x=中线。"""
    hw = w / 2
    for sgn in (-1, 1):
        lx = x + sgn * hw * 0.8
        s.line(lx, base, x + sgn * hw * 0.25, top, color, w * 0.16, op)
    for i in range(3):  # 横担（上窄下宽）
        t = i / 2.0
        ay = top + (base - top) * (0.18 + 0.3 * i)
        aw = w * (0.7 + 0.3 * i)
        s.line(x - aw / 2, ay, x + aw / 2, ay, color, w * 0.13, op)
        for sgn in (-1, 1):  # 悬垂绝缘子串（短竖串点）
            ix = x + sgn * aw / 2
            for d in range(3):
                s.circle(ix, ay + 4 + d * 3.2, 1.1, color, op)
            if hi:
                s.circle(ix, ay + 4, 1.0, hi, op * 0.7)
    s.line(x - hw * 0.25, top, x + hw * 0.25, top, color, w * 0.16, op)  # 塔顶
    if hi:  # 受光棱线（塔顶一竖）
        s.line(x, top, x, top + (base - top) * 0.22, hi, 1.4, op * 0.6)


# ============================================================
# 远景条 1024x1300（画布 y = 世界 y + 570；底=世界 730）
# 主体块账：远山脊顶画布 ~950..1010（世界 380..440）、塔顶 880..930
# （世界 310..360）——成片主体块顶到世界 250..430 ✓；底雾只压脚（100px/op≤0.4）
# ============================================================
def far9():
    rng = random.Random(9091)
    s = Svg(1024, 1300)
    sky = s.vgrad("sky9f", [(0, "#3a4448", 1), (0.45, "#566260", 1),
                            (0.8, "#787e78", 1), (1, "#8e8e92", 1)])
    s.rect(0, 0, 1024, 1300, sky)
    # 高空雷暴云横条（低对比，不画闪电盘——唯一地标规矩）
    for cy, rx, op in ((140, 240, 0.14), (230, 320, 0.12), (340, 220, 0.10),
                       (460, 280, 0.08)):
        s.ellipse(rng.uniform(200, 820), cy, rx, 16, "#2a3438", op)
    # 地平雷光辉（径向渐变软光晕，非硬边椭圆光）
    s.glow_ellipse(512, 1235, 430, 60, STORM_GLOW, 0.20)
    s.glow_ellipse(300, 1210, 240, 36, STORM_GLOW, 0.12)
    s.glow_ellipse(760, 1220, 200, 32, STORM_GLOW, 0.10)

    # 远山：k 整数正弦（2 周期/1024 → 接缝两侧同值无缝），折线棱面
    for ridge, amp, base, col, op in ((1.0, 46, 1050, RIDGE_B, 0.55),
                                      (2.0, 64, 1075, RIDGE_F, 0.78)):
        pts_ = []
        for i in range(0, 17):
            x = i * 64
            y = base - amp * (0.5 + 0.5 * math.sin(ridge * math.pi * 2 * i / 16))
            pts_.append((x, round(y)))
        s.poly([(0, 1300)] + pts_ + [(1024, 1300)], col, op)

    # 门型铁塔群成排（4 座，避开接缝 24px）：顶 880..930=世界 310..360
    tw_xs = (200, 420, 640, 860)
    for i, tx in enumerate(tw_xs):
        pylon(s, tx, 884 + (i % 2) * 22, 1245, 88, PYLON, 0.9, hi=STEEL)
    # 塔间垂弧导线（两端接横担绝缘子串端——线段两端接实物 ✓）
    for i in range(3):
        x1, x2 = tw_xs[i] + 31, tw_xs[i + 1] - 31
        y1 = 940 + (i % 2) * 22
        for dy, w, op in ((0, 2.2, 0.55), (14, 1.6, 0.4)):
            catenary(s, x1, y1 + dy, x2, y1 + dy, 52, PYLON, w, op)

    # 底雾只压脚（≤100px、op≤0.4）
    fog = s.vgrad("fog9f", [(0, "#8e8e92", 0.0), (1, "#8e8e92", 0.34)])
    s.rect(0, 1200, 1024, 100, fog)
    # 雨丝（氛围线，画在本条内最上层前——避免读成游离断线，短划密排）
    for _ in range(26):
        rx, ry = rng.uniform(0, 1024), rng.uniform(300, 1180)
        ln = rng.uniform(10, 22)
        s.line(rx, ry, rx - ln * 0.22, ry + ln, "#a8b2ae", 1.2,
               rng.uniform(0.10, 0.22), cap="round")
    return s


# ============================================================
# 中景条 2048x520 透明底（画布 y = 世界 y − 180；地形顶 664=画布 484；
# 落地件脚 488..500；接缝两侧留空 40px；多段各异构图防重复）
# 段1 断头高架墩 / 段2 变压器台+杆 / 段3 塔基座+残塔段 / 段4 警示牌+栅栏桩
# ============================================================
def mid9():
    rng = random.Random(9092)
    s = Svg(2048, 520)
    CONC, CONC_D = "#6a6470", "#4e4856"     # 混凝土（紫灰族）
    METAL, METAL_D = "#5a5566", "#3a3542"

    # 段1 断头高架墩（x120..400）：桥板顶 210（世界 390∈380..420 ✓）
    s.rect(120, 210, 280, 26, CONC, 0.95)
    s.rect(120, 210, 280, 4, "#8a8492", 0.9)                    # 板顶亮缘
    for px, pw in ((150, 24), (330, 24)):                        # 墩柱
        s.rect(px, 236, pw, 256, CONC_D, 0.95)
        s.rect(px - 8, 482, pw + 16, 12, CONC_D, 0.95)          # 扩基（脚 494）
    for bx in range(388, 401, 6):                                # 断口锯齿（露筋一竖）
        s.rect(bx, 210 + (bx - 388) * 2, 4, 26 - (bx - 388) * 2, METAL_D, 0.9)
    s.line(392, 218, 392, 232, STEEL, 2, 0.8)

    # 段2 变压器台小屋+杆（x560..900）
    s.rect(560, 428, 130, 68, CONC, 0.95)                        # 小屋（脚 496）
    s.poly([(556, 428), (694, 428), (625, 408)], CONC_D, 0.95)   # 檐顶
    s.rect(600, 466, 22, 30, METAL_D, 0.95)                      # 门
    s.rect(580, 442, 16, 12, "#c9d4da", 0.55)                    # 亮窗
    s.rect(700, 300, 10, 196, METAL, 0.95)                       # 杆（脚 496）
    for cy in (316, 340):                                        # 杆横担
        s.line(680, cy, 734, cy, METAL, 3.5, 0.95)
    s.rect(712, 356, 34, 40, METAL_D, 0.95)                      # 变压器罐
    s.line(712, 376, 746, 376, METAL, 2, 0.6)
    glow_dot(s, 705, 350, SIG, r=1.6, halos=((4, 0.35), (7, 0.12)))  # 航标紫灯
    # 断缆垂弧：高架断口 → 杆横担（两端接实物 ✓）
    catenary(s, 396, 226, 680, 316, 120, METAL_D, 2.2, 0.7)
    catenary(s, 734, 340, 1030, 300, 70, METAL_D, 1.8, 0.55)

    # 段3 塔基座+残塔段（x1000..1320）：断头在 300（世界 480 近上限）
    s.rect(1040, 460, 120, 38, CONC_D, 0.95)                     # 基座（脚 498）
    s.rect(1040, 460, 120, 4, "#8a8492", 0.85)
    for i, (lx, ly) in enumerate(((1076, 300), (1124, 300))):    # 双主材
        s.line(lx, 460, lx, ly, METAL, 6, 0.95)
    for i in range(4):                                           # 斜撑 X 块
        y1 = 300 + i * 40
        s.line(1076, y1, 1124, y1 + 40, METAL, 2.5, 0.85)
        s.line(1124, y1, 1076, y1 + 40, METAL, 2.5, 0.85)
    s.line(1076, 300, 1124, 300, METAL, 5, 0.95)                 # 断头横材
    s.line(1100, 300, 1100, 284, STEEL, 2, 0.7)                  # 断口毛刺亮缘

    # 段4 警示牌+栅栏桩（x1450..2000，牌面给描边亮缘=小件读法）
    s.line(1560, 496, 1560, 408, METAL, 5, 0.95)                 # 牌杆（脚 496）
    s.rect(1524, 368, 72, 44, "#565062", 0.95)
    s.rect(1521, 365, 78, 4, "#c9d4da", 0.9)                     # 亮缘描边
    s.rect(1521, 409, 78, 4, "#c9d4da", 0.9)
    s.rect(1534, 384, 52, 8, SIG, 0.8)                           # 雷光紫警示杠
    for fx in range(1690, 1920, 56):                             # 栅栏桩
        s.line(fx, 494, fx, 452, METAL_D, 4, 0.9)
        s.circle(fx, 450, 2.2, METAL, 0.9)
    s.line(1690, 462, 1906, 462, METAL_D, 2.4, 0.8)
    s.line(1690, 478, 1906, 478, METAL_D, 2.4, 0.8)

    # 落地碎缆（两端入地/接墩——不悬空起头）
    catenary(s, 430, 470, 560, 486, 8, METAL_D, 2.0, 0.75)
    catenary(s, 1330, 482, 1450, 492, 10, METAL_D, 1.8, 0.65)
    return s


# ============================================================
# 主视景提案（1200x540，档位区账同八套；道具落位逐件对表：
#   t0=[-100,220]∪[1020,1500] 顶 332 / t2=[220,700] 顶 268 / t1=[700,1020] 顶 300）
# ============================================================
def storm_line():
    rng = random.Random(909)
    s = Svg()

    # 天空：雷暴青灰绿（色带账 (0,#3a4448)(0.5,#5e6a66)(1,#8e8e92)，压中调）
    sky = s.vgrad("sky9", [(0, "#3a4448", 1), (0.5, "#5e6a66", 1), (1, "#8e8e92", 1)])
    s.rect(0, 0, W, GROUND, sky)
    # 地平雷光辉（不画闪电盘——唯一地标规矩）
    s.glow_ellipse(600, 318, 380, 40, STORM_GLOW, 0.26)
    s.glow_ellipse(330, 308, 220, 24, STORM_GLOW, 0.14)
    for cy, rx, op in ((70, 220, 0.10), (120, 280, 0.08), (170, 190, 0.06)):
        s.ellipse(rng.uniform(260, 940), cy, rx, 9, "#2a3438", op)

    # ---- 远景：远山两排（k 整数正弦折线）+ 铁塔群 ----
    for ridge, amp, base, col, op in ((1.0, 24, 336, RIDGE_B, 0.55),
                                      (2.0, 32, 344, RIDGE_F, 0.8)):
        pts_ = []
        for i in range(0, 13):
            x = i * 100
            y = base - amp * (0.5 + 0.5 * math.sin(ridge * math.pi * 2 * i / 12))
            pts_.append((x, round(y)))
        s.poly([(0, GROUND)] + pts_ + [(W, GROUND)], col, op)
    # 塔群：t0 两座全高 + 台缘后三座只露台顶以上段（底画到 GROUND，台体立面盖）
    # 账：x120 顶 212 / x500 顶 180 / x620 顶 200 / x800 顶 222 / x1240 顶 214
    tw = ((120, 212), (500, 180), (620, 200), (800, 222), (1240, 214))
    for tx, ty in tw:
        pylon(s, tx, ty, GROUND + 2, 46, PYLON, 0.88, hi=STEEL)
    for i in range(4):  # 塔间垂弧导线（接横担端）
        x1, x2 = tw[i][0] + 16, tw[i + 1][0] - 16
        y1 = max(tw[i][1], tw[i + 1][1]) + 28
        catenary(s, x1, y1, x2, y1, 24, PYLON, 1.2, 0.5)

    # ---- 雨丝（氛围线在中景道具之前画——v1 教训⑤）----
    for _ in range(14):
        lx, ly = rng.uniform(40, W), rng.uniform(140, 300)
        ln = rng.uniform(10, 20)
        s.line(lx, ly, lx - ln * 0.22, ly + ln, "#a8b2ae", 1.1,
               rng.uniform(0.10, 0.2), cap="round")

    # ---- 中景：断头高架墩（左 t0）+ 变压器小屋/杆（t2）+ 塔基残段（t1）----
    CONC, CONC_D, METAL, METAL_D = "#6a6470", "#4e4856", "#5a5566", "#3a3542"
    # 断头高架墩：板顶 138（世界 276? 半比例=世界×0.5：板顶=世界 416∈380..420✓）
    s.rect(40, 138, 170, 14, CONC, 0.95)
    s.rect(40, 138, 170, 2.4, "#8a8492", 0.9)
    for px in (66, 176):                     # 墩柱，脚落 t0 顶 331
        s.rect(px, 152, 12, 179, CONC_D, 0.95)
        s.rect(px - 4, 326, 20, 6, CONC_D, 0.95)
    for bx in range(198, 211, 4):            # 断口锯齿+露筋亮缘
        s.rect(bx, 138 + (bx - 198) * 1.4, 3, 14 - (bx - 198) * 1.4, METAL_D, 0.9)
    s.line(201, 142, 201, 150, STEEL, 1.6, 0.8)
    # 变压器小屋（t2 台面，脚 268）+ 杆
    s.rect(560, 216, 66, 52, CONC, 0.95)
    s.poly([(557, 216), (690 - 66, 216), (593, 205)], CONC_D, 0.95)
    s.rect(581, 238, 12, 30, METAL_D, 0.95)
    s.rect(590, 226, 9, 7, "#c9d4da", 0.55)
    s.line(672, 160, 672, 268, METAL, 4, 0.95)                   # 杆（脚 268）
    s.line(660, 172, 684, 172, METAL, 2.5, 0.95)
    s.rect(676, 180, 18, 22, METAL_D, 0.95)
    glow_dot(s, 672, 166, SIG, r=1.2, halos=((3, 0.35), (5, 0.12)))
    # 断缆垂弧：高架断口 → 杆横担（两端接实物 ✓）
    catenary(s, 202, 148, 660, 172, 58, METAL_D, 1.4, 0.65)
    catenary(s, 684, 186, 826, 160, 36, METAL_D, 1.1, 0.5)
    # 塔基座+残塔段（t1 台面，脚 300）：断头 148（世界 296∈台顶以上段）
    s.rect(744, 288, 60, 12, CONC_D, 0.95)
    s.rect(744, 288, 60, 2, "#8a8492", 0.85)
    s.line(760, 300, 760, 148, METAL, 3.4, 0.95)
    s.line(788, 300, 788, 148, METAL, 3.4, 0.95)
    for i in range(3):
        y1 = 152 + i * 50
        s.line(760, y1, 788, y1 + 50, METAL, 1.4, 0.8)
        s.line(788, y1, 760, y1 + 50, METAL, 1.4, 0.8)
    s.line(760, 148, 788, 148, METAL, 2.6, 0.95)
    s.line(774, 148, 774, 138, STEEL, 1.4, 0.7)

    # ---- 独层大件：倒伏门型铁塔（跨 t1 台面，塔头挑出台缘悬 t0 上空，
    #      悬垂绝缘子串末端坠缆落地=一切线段落地/接实物）----
    s.ellipse(880, 299, 118, 4, "#221c28", 0.55)                 # 接地阴影（先画）
    # 主桁梁：下弦坐 t1 台面（脚 299/300），上弦挑向右上
    lo = [(758, 296), (830, 268), (902, 236), (974, 200), (1046, 168)]
    up = [(758, 270), (830, 240), (902, 206), (974, 168), (1046, 132)]
    s.line(lo[0][0], lo[0][1], lo[-1][0], lo[-1][1], METAL, 5, 0.95)
    s.line(up[0][0], up[0][1], up[-1][0], up[-1][1], METAL, 4, 0.95)
    s.line(758, 300, 758, 270, METAL, 5, 0.95)                   # 塔根坐台
    for i in range(4):                                           # 桁格斜撑
        s.line(lo[i][0], lo[i][1], up[i + 1][0], up[i + 1][1], METAL, 1.8, 0.85)
        s.line(up[i][0], up[i][1], lo[i + 1][0], lo[i + 1][1], METAL, 1.8, 0.85)
    s.line(1046, 168, 1046, 132, METAL, 4, 0.95)                 # 塔头断口
    s.line(1046, 132, 1046, 122, STEEL, 1.6, 0.8)                # 断口亮缘
    # 悬垂绝缘子串 ×2（塔头横担）+ 末端坠缆落地 t0（y331）
    for ix, iy in ((1060, 138), (1078, 146)):
        for d in range(4):
            s.circle(ix, iy + d * 4, 1.3, METAL, 0.9)
        s.circle(ix, iy, 1.1, STEEL, 0.7)
    catenary(s, 1078, 160, 1150, 331, 30, METAL_D, 1.6, 0.75)    # 坠缆触地
    glow_dot(s, 812, 258, SIG, r=1.6, halos=((4, 0.35), (7, 0.12)))  # 塔身航标紫灯

    # ---- 地表（拆地块 v2 @ p9_storm：焦紫灰硬质荒原）----
    gv.draw_ground(s, "p9_storm", bottom=H, k=1.0)

    # ---- 前景剪影道具（ground 之后画；小件给描边/亮缘）----
    # 坠缆段贴 t0 地面（右平地，两端微翘入地）
    catenary(s, 1060, 331, 1180, 330, 6, METAL_D, 2.0, 0.85)
    # 散落绝缘子串（亮缘+描边才读得出）
    for dx in (1108, 1122):
        s.rect(dx, 324, 5, 10, "#565062", 0.95)
        s.rect(dx - 1, 322, 7, 2.4, "#c9d4da", 0.9)
        s.rect(dx - 1, 333, 7, 2.4, "#c9d4da", 0.85)
    # 警示桩（t0 右平地）
    s.line(1210, 331, 1210, 302, METAL, 3, 0.95)
    s.rect(1202, 296, 16, 10, "#565062", 0.95)
    s.rect(1202, 296, 16, 2.4, "#c9d4da", 0.9)
    s.rect(1205, 299, 10, 3, SIG, 0.8)
    # 台面小件：焦痕块（t2 带面，电蚀紫微光）
    s.ellipse(360, 276, 18, 3, TH["accent"], 0.18)
    s.ellipse(640, 302, 14, 2.6, TH["accent"], 0.15)

    # 氛围：雨点 + 低飞尘
    for _ in range(10):
        s.circle(rng.uniform(0, W), rng.uniform(160, 320), rng.uniform(0.8, 1.8),
                 "#c2c8c4", rng.uniform(0.12, 0.3))
    return s


# ============================================================
# 敌营小队剪影配色示意（1200x540：雷暴天+走道带底，五单位朝左 ×2 + 色板条）
# 锚点比例对 §3 基线：步行者 56x52 / 无人机 38x42 / 盾卫 56x52 / 精英 60x80 /
# BOSS 300x180（悬浮），×2 直绘
# ============================================================
def enemy9():
    s = Svg()
    sky = s.vgrad("sky9e", [(0, "#3a4448", 1), (0.5, "#5e6a66", 1), (1, "#8e8e92", 1)])
    s.rect(0, 0, W, H, sky)
    s.glow_ellipse(600, 400, 420, 46, STORM_GLOW, 0.22)
    GY = 400                                  # 地面线（走道带顶）
    band = s.vgrad("band9e", [(0, TH["face_hi"], 1), (1, TH["face_lo"], 1)])
    s.rect(0, GY, W, H - GY, band)
    s.rect(0, GY, W, 2, TH["top_line"])
    def unit_walk(cx, shield=False):
        """步行者 56x52 ×2=112x104，脚 GY，朝左；盾卫加正面盾板。"""
        x0, y0 = cx - 56, GY - 104
        s.ellipse(cx, GY + 2, 56, 5, "#221c28", 0.5)              # 接地阴影
        s.rect(x0 + 34, y0 + 26, 60, 46, E_BODY, 1)               # 躯干
        s.rect(x0 + 34, y0 + 26, 60, 8, E_LIGHT, 1)               # 肩受光
        s.rect(x0 + 52, y0 + 12, 24, 18, E_BODY, 1)               # 头（下沉）
        s.circle(x0 + 56, y0 + 21, 2.6, EYE, 1)                   # 独眼红
        s.rect(x0 + 8, y0 + 40, 30, 10, E_LIGHT, 1)               # 枪臂前伸（朝左）
        s.rect(x0 + 2, y0 + 42, 10, 6, E_GAP, 1)                  # 枪口
        for lx in (x0 + 44, x0 + 72):                             # 逆关节双腿
            s.rect(lx, y0 + 72, 12, 20, E_BELLY, 1)
            s.rect(lx - 2, y0 + 90, 16, 6, E_BELLY, 1)
            s.rect(lx + 8, y0 + 80, 8, 14, E_GAP, 1)              # 后膝块
        if shield:
            s.rect(x0 - 6, y0 + 18, 12, 78, E_LIGHT, 1)           # 正面盾板
            s.rect(x0 - 6, y0 + 18, 4, 78, "#7a7090", 1)
            s.rect(x0 - 3, y0 + 44, 6, 6, EYE, 0.9)               # 盾眼缝

    unit_walk(120)
    # 无人机 38x42 ×2=76x84 悬浮（下置推进器红焰解释悬空）
    dx_, dy_ = 250, GY - 190
    s.rect(dx_ - 38, dy_, 76, 40, E_BODY, 1)
    s.rect(dx_ - 38, dy_, 76, 7, E_LIGHT, 1)
    s.circle(dx_ - 24, dy_ + 16, 2.6, EYE, 1)
    s.rect(dx_ - 62, dy_ + 22, 26, 9, E_LIGHT, 1)                 # 枪臂朝左
    s.rect(dx_ - 68, dy_ + 24, 8, 5, E_GAP, 1)
    s.rect(dx_ - 26, dy_ + 40, 52, 8, E_BELLY, 1)
    s.glow_ellipse(dx_, dy_ + 56, 16, 7, "#ff7a45", 0.35)         # 推进焰
    s.glow_ellipse(dx_, dy_ + 60, 9, 10, "#ffb08a", 0.5)
    unit_walk(390, shield=True)
    # 精英 60x80 ×2=120x160 车体（头前置+垂发舱后置高过头）
    ex, ey = 550, GY - 160
    s.ellipse(ex, GY + 2, 62, 5, "#221c28", 0.5)
    s.rect(ex - 60, ey + 100, 120, 40, E_BODY, 1)                 # 车体
    s.rect(ex - 60, ey + 100, 120, 8, E_LIGHT, 1)
    s.rect(ex - 60, ey + 140, 116, 12, E_BELLY, 1)                # 履带座
    for tx in range(ex - 52, ex + 56, 16):
        s.circle(tx, ey + 146, 5, E_GAP, 1)                       # 轮
    s.rect(ex - 58, ey + 72, 30, 30, E_BODY, 1)                   # 头前置（底缘压车体顶）
    s.circle(ex - 52, ey + 84, 2.8, EYE, 1)
    s.rect(ex + 6, ey + 44, 44, 60, E_BELLY, 1)                   # 垂发舱（高过头，底压车体顶）
    s.rect(ex + 12, ey + 50, 8, 40, E_GAP, 1)                     # 仓口 ×2
    s.rect(ex + 30, ey + 50, 8, 40, E_GAP, 1)
    s.rect(ex + 6, ey + 44, 44, 5, E_LIGHT, 1)
    # BOSS 300x180 ×2=600x360 悬浮低宽舰体（船底 340=GY−60）
    bx, by = 590, 40                             # bx=左缘, by=顶
    s.ellipse(bx + 300, GY + 6, 320, 10, "#221c28", 0.5)
    s.poly([(bx, by + 150), (bx + 60, by + 100), (bx + 200, by + 80),
            (bx + 460, by + 80), (bx + 580, by + 130), (bx + 580, by + 240),
            (bx + 60, by + 240)], E_BODY, 1)                      # 楔形舰体
    s.poly([(bx + 60, by + 100), (bx + 200, by + 80), (bx + 460, by + 80),
            (bx + 300, by + 110)], E_LIGHT, 1)                    # 甲板受光
    s.rect(bx + 90, by + 44, 70, 52, E_BELLY, 1)                  # 驾驶楼（底压甲板）
    s.circle(bx + 108, by + 62, 5, EYE, 1)                        # 独眼
    s.rect(bx + 250, by + 40, 150, 44, E_BELLY, 1)                # 背部武器段
    s.rect(bx + 264, by + 52, 26, 20, E_GAP, 1)
    s.rect(bx + 306, by + 52, 26, 20, E_GAP, 1)
    s.rect(bx - 20, by + 176, 70, 16, E_LIGHT, 1)                 # 艏炮朝左
    s.rect(bx - 44, by + 180, 28, 8, E_GAP, 1)
    s.rect(bx + 480, by + 200, 90, 14, E_BELLY, 1)                # 艉部
    for jx in (bx + 160, bx + 380):                               # 举升喷口
        s.glow_ellipse(jx, by + 252, 26, 12, "#b09ae0", 0.35)
        s.glow_ellipse(jx, by + 258, 14, 14, "#d8c8f4", 0.5)
    for ix in (bx + 120, bx + 420):                               # 舷侧航标紫灯
        glow_dot(s, ix, by + 230, SIG, r=2, halos=((5, 0.4), (9, 0.15)))

    # 色板条（无文字——ThorVG 禁 text；hex 见提案 md §敌营配色）
    chips = ((E_LIGHT, 0), (E_BODY, 1), (E_BELLY, 2), (E_GAP, 3),
             (EYE, 4), (SIG, 5))
    for col, i in chips:
        cx = 90 + i * 108
        s.rect(cx, 452, 88, 56, col, 1)
        s.rect(cx, 452, 88, 4, "#d8dce4", 0.5)
        s.rect(cx, 504, 88, 4, "#12100c", 0.5)
    return s


# ============================================================
OUT = HERE


def build():
    storm_line().save(os.path.join(OUT, "proposal_9_storm_line.svg"))
    far9().save(os.path.join(OUT, "env_storm_far.svg"))
    mid9().save(os.path.join(OUT, "env_storm_mid.svg"))
    enemy9().save(os.path.join(OUT, "enemy_squad_ch9.svg"))
    print("OK: 4 svgs written to", OUT)


if __name__ == "__main__":
    build()
