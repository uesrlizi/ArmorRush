# -*- coding: utf-8 -*-
"""world_10 场景美术提案 ·「硫焰地热田」。

复用 generate_proposals.py 的 Svg 框架（画布 1200x540，档位区账
SEQ=[0,0,2,2,2,1,1,0,0,0]：t0=[-100,220]∪[1020,1500] 顶 332 / t2=[220,700] 顶 268 /
t1=[700,1020] 顶 300）。地块=ground_v2 draw_ground，本章主题键 p10_sulfur 在本脚本
内运行时注册（借 "salt" 画法分支：龟裂纹=硫壳裂纹、渍斑=硫黄结壳、结晶点）。
图元约束：只用 rect/polygon/path/circle/ellipse/line + 渐变；禁 filter/pattern/
use/text/transform；一切线段两端落地/接实物/出画；条带里不画唯一地标。

主题：火山破火山口里的废弃地热电站——玄武岩黑地上结满硫黄壳，喷气孔冒着
硫烟，井口漏出的硫黄在燃烧，火焰是蓝色的。
色相（只定色相不定明度，§6 细则）：天=硫烟赭橄榄（黄绿偏，战斗带压中调）；
地=玄武冷灰黑+硫黄壳；章信号色=硫焰蓝 #48b4ff；敌营=墨酒红 #4a2a3a 族。

产出（全部 sulfur_ch10/ 内）：
  proposal_10_sulfur_field.svg/.png  主视景提案（与前九套同规格）
  env_sulfur_far.svg/.png            远景条 1024x1300（画布 y=世界 y+570）
  env_sulfur_mid.svg/.png            中景条 2048x520 透明底（画布 y=世界 y−180）
  enemy_squad_ch10.svg/.png          敌营小队剪影配色示意
  comp_main_ch10.png                 ① 主视景合成帧：far+mid+地形+664 线（世界 2400x1080）
  comp_ch8_ch9_ch10.png              ② 与前章同规格并排（接地账）
用法：python -I art_proposals/sulfur_ch10/gen_sulfur10.py
（内部调 Godot headless + raster_svg.gd 光栅，再用 PIL 合成）
"""
import math
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, ".."))
ROOT = os.path.normpath(os.path.join(ART, ".."))
sys.path.insert(0, ART)
sys.path.insert(0, os.path.join(ART, "terrain_blocks"))
from generate_proposals import Svg, W, H, GROUND, f, glow_dot  # noqa: E402
import ground_v2 as gv  # noqa: E402

GODOT = r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"

# ---- 色板 ----
SKY = [(0, "#5a5632", 1), (0.5, "#8a8348", 1), (1, "#b2a866", 1)]   # 硫烟赭橄榄
HAZE = "#d6cc8a"            # 地平硫雾辉
SIG = "#48b4ff"             # 硫焰蓝（章信号色）
SIG_CORE = "#c8ecff"
SULF = "#c8b048"            # 硫黄壳（地面/堆）
RIDGE_B = "#6e6846"         # 远破火山口壁（后排）
RIDGE_F = "#4c4836"         # 前排（比天暗两档以上）
PLUME = "#d8d4b4"           # 硫烟柱
BASALT, BASALT_D = "#4a4a46", "#34332f"       # 中景玄武/混凝土
PIPE, PIPE_D, PIPE_HI = "#5c5a52", "#3c3b36", "#9a9682"

gv.THEMES["p10_sulfur"] = {
    "style": "salt",
    "top_line": "#c8bc78", "band": "#4c4a44", "band_edge": "#3a3934",
    "band_dark": "#3a3934", "band_light": "#6e6c62", "ao": "#2a2926",
    "face_hi": "#403e39", "face_lo": "#222120", "strata": "#34322e",
    "seam": "#1e1d1b", "detail": "#a89c60", "foot": "#3a3832",
    "accent": "#c8b048",
}
TH = gv.THEMES["p10_sulfur"]

# 墨酒红敌营（近黑=敌，中调背景不反转）
E_LIGHT, E_BODY, E_BELLY, E_GAP = "#6a4456", "#4a2a3a", "#321c28", "#20121a"
EYE = "#ff4640"


def blue_flame(s, x, y, h, op=1.0):
    """井口硫焰：蓝外焰+浅芯（径向软光晕，无硬边光）。y=焰根。"""
    s.glow_ellipse(x, y - h * 0.45, h * 0.32, h * 0.6, SIG, 0.45 * op)
    s.glow_ellipse(x, y - h * 0.3, h * 0.14, h * 0.32, SIG_CORE, 0.7 * op)


def plume(s, gid, x, y_base, w, h, op):
    """硫烟柱：根部起一串径向软光晕烟团（自下而上变大变淡、向右飘），
    根部必须接喷气孔/井口/罐顶。硬边梯形版读成探照灯光柱，已弃。"""
    n = 7
    for i in range(n):
        t = i / (n - 1)
        cy = y_base - h * t
        cx = x + h * 0.18 * t * t
        r = w * (0.35 + 1.1 * t)
        s.glow_ellipse(cx, cy, r, r * 0.8, PLUME, op * (1.0 - 0.75 * t))


def ridges(s, width, base_amp, n, y_off, step):
    """k 整数正弦破火山口壁两排（接缝两侧同值=无缝），平顶折线棱面。"""
    for k, amp, base, col, op in ((1, base_amp[0], y_off[0], RIDGE_B, 0.7),
                                  (2, base_amp[1], y_off[1], RIDGE_F, 0.92)):
        pts = []
        for i in range(n + 1):
            x = i * step
            v = 0.5 + 0.5 * math.sin(k * math.pi * 2 * i / n + (0.9 if k == 2 else 0))
            pts.append((x, round(base - amp * v)))
        s.poly([(0, 2000)] + pts + [(width, 2000)], col, op)


# ============================================================
# 远景条 1024x1300（画布 y=世界 y+570；底=世界 730）
# 主体块账：后排壁顶画布 ~880..950（世界 310..380）、前排 ~960..1010（世界 390..440）
# ——成片主体块顶到世界 250..430 ✓；底雾 ≤100px op≤0.4
# ============================================================
def far10():
    rng = random.Random(10101)
    s = Svg(1024, 1300)
    sky = s.vgrad("sky10f", [(0, "#5a5632", 1), (0.5, "#76703e", 1),
                             (0.82, "#8a8348", 1), (1, "#b2a866", 1)])
    s.rect(0, 0, 1024, 1300, sky)
    for cy, rx, op in ((160, 260, 0.12), (280, 300, 0.10), (420, 220, 0.08)):
        s.ellipse(rng.uniform(220, 800), cy, rx, 14, "#4a462a", op)   # 高空烟幕横条
    s.glow_ellipse(512, 1225, 440, 70, HAZE, 0.24)
    # 硫烟柱（画在壁后面，根部被前排壁盖住=从口子里冒出来）
    for i, (px, h) in enumerate(((180, 380), (560, 460), (850, 330))):
        plume(s, f"pl10f{i}", px, 1000, 60, h, 0.30)
    # 后排：k=1（1 周期/1024），前排：k=2，step 64 粗折线=棱面
    pts_b, pts_f = [], []
    for i in range(17):
        x = i * 64
        pts_b.append((x, round(950 - 70 * (0.5 + 0.5 * math.sin(math.pi * 2 * i / 16)))))
        pts_f.append((x, round(1010 - 50 * (0.5 + 0.5 * math.sin(math.pi * 4 * i / 16 + 0.9)))))
    s.poly([(0, 1300)] + pts_b + [(1024, 1300)], RIDGE_B, 0.72)
    s.poly([(0, 1300)] + pts_f + [(1024, 1300)], RIDGE_F, 0.94)
    # 前排壁顶受光缘（硫黄淡缘）
    for (x1, y1), (x2, y2) in zip(pts_f, pts_f[1:]):
        if y2 < y1:
            s.line(x1, y1, x2, y2, "#8c8456", 1.6, 0.6)
    # 壁面硫黄结壳斑（落在前排壁内 y>壁顶+20）
    for _ in range(9):
        x = rng.uniform(40, 984)
        s.ellipse(x, rng.uniform(1060, 1180), rng.uniform(14, 30), 3, SULF, 0.32)
    # 喷气孔小蓝焰（嵌壁脚，软光晕）
    for x in (300, 720):
        blue_flame(s, x, 1170, 26, 0.8)
    fog = s.vgrad("fog10f", [(0, "#b2a866", 0.0), (1, "#b2a866", 0.36)])
    s.rect(0, 1200, 1024, 100, fog)
    return s


# ============================================================
# 中景条 2048x520 透明底（画布 y=世界 y−180；地形顶 664=画布 484；脚 488..500；
# 接缝两侧留 40px）
# 段1 汽水分离塔（最高件，顶 214=世界 394） / 段2 井口阀树+Ω 伸缩弯管 /
# 段3 硫黄堆+输送斜槽 / 段4 喷气孔围栏+警示牌
# ============================================================
def mid10():
    rng = random.Random(10102)
    s = Svg(2048, 520)
    # 段1 汽水分离塔（x120..360）
    s.rect(150, 214, 70, 270, BASALT, 0.96)                    # 罐身
    s.ellipse(185, 214, 35, 10, BASALT, 0.96)                  # 罐顶
    s.rect(150, 214, 8, 270, PIPE_HI, 0.35)                    # 受光竖缘
    for y in (270, 340, 410):
        s.rect(146, y, 78, 6, BASALT_D, 0.96)                  # 箍带
    s.rect(136, 484, 98, 12, BASALT_D, 0.96)                   # 基座（脚 496）
    s.rect(240, 300, 12, 196, PIPE_D, 0.96)                    # 旁立梯架（脚 496）
    for y in range(310, 490, 18):
        s.line(240, y, 252, y, PIPE, 2, 0.9)
    s.line(220, 250, 340, 250, PIPE, 7, 0.96)                  # 出汽管 → 段1 支架
    s.rect(330, 250, 12, 246, PIPE_D, 0.96)                    # 支架（脚 496）
    plume(s, "pl10m0", 185, 206, 26, 120, 0.35)                # 罐顶放空汽（根接罐顶）

    # 段2 井口阀树 + Ω 伸缩弯管（x480..1000）
    s.rect(520, 440, 50, 56, BASALT_D, 0.96)                   # 井口台（脚 496）
    s.rect(536, 380, 18, 60, PIPE, 0.96)                       # 阀树立管
    for y in (392, 416):
        s.rect(526, y, 38, 8, PIPE_D, 0.96)                    # 法兰
        s.circle(520, y + 4, 7, PIPE, 0.96)                    # 手轮
    blue_flame(s, 545, 380, 44, 1.0)                           # 漏气硫焰（井口顶）
    # 横管 554..980 高 400，中段 Ω 弯上拱
    s.line(554, 400, 700, 400, PIPE, 8, 0.96)
    s.path("M 700,400 L 700,300 L 800,300 L 800,400", stroke=PIPE, w=8, opacity=0.96)
    s.line(800, 400, 980, 400, PIPE, 8, 0.96)
    s.line(554, 396, 980, 396, PIPE_HI, 1.4, 0.5)
    for px in (620, 750, 880, 970):                            # 管托（脚 496）
        s.rect(px - 5, 404, 10, 92, PIPE_D, 0.96)
        s.rect(px - 12, 490, 24, 6, PIPE_D, 0.96)
    glow_dot(s, 750, 300, SIG, r=1.8, halos=((4, 0.35), (8, 0.12)))  # Ω 顶航标蓝灯

    # 段3 硫黄堆 + 输送斜槽（x1080..1420）
    s.poly([(1090, 496), (1200, 392), (1250, 400), (1350, 496)], "#a8943c", 0.96)
    s.poly([(1200, 392), (1250, 400), (1230, 430), (1180, 420)], "#d8c45c", 0.9)  # 堆顶受光
    for _ in range(6):
        x = rng.uniform(1130, 1310)
        s.line(x, rng.uniform(440, 480), x + 14, rng.uniform(440, 480), "#7c6c2c", 1.6, 0.7)
    s.line(1236, 398, 1400, 268, PIPE, 6, 0.96)                # 斜槽（下端搭堆顶）
    s.rect(1394, 262, 14, 234, PIPE_D, 0.96)                   # 槽端支柱（脚 496）
    s.rect(1384, 254, 34, 14, PIPE, 0.96)                      # 槽头

    # 段4 喷气孔围栏 + 警示牌（x1500..2000）
    s.ellipse(1640, 494, 50, 5, "#2a2824", 0.9)                # 孔口
    plume(s, "pl10m1", 1640, 492, 40, 200, 0.38)
    blue_flame(s, 1640, 494, 30, 0.9)
    for fx in range(1570, 1720, 36):                           # 围栏桩
        s.line(fx, 496, fx, 452, PIPE_D, 4, 0.9)
    s.line(1570, 462, 1714, 462, PIPE_D, 2.4, 0.85)
    s.line(1800, 496, 1800, 404, PIPE, 5, 0.96)                # 牌杆
    s.rect(1764, 364, 72, 44, "#3e3c36", 0.96)
    s.rect(1761, 361, 78, 4, "#d6cc8a", 0.9)                   # 亮缘描边
    s.rect(1761, 405, 78, 4, "#d6cc8a", 0.9)
    s.rect(1774, 380, 52, 8, SIG, 0.85)                        # 硫焰蓝警示杠
    s.ellipse(1920, 494, 40, 4, SULF, 0.6)                     # 地面结壳
    return s


# ============================================================
# 主视景提案（1200x540）。道具对档位区账逐件核算：
#   t0=[-100,220]∪[1020,1500] 顶 332 / t2=[220,700] 顶 268 / t1=[700,1020] 顶 300
# ============================================================
def sulfur_field():
    rng = random.Random(1010)
    s = Svg()
    s.rect(0, 0, W, GROUND, s.vgrad("sky10", SKY))
    s.glow_ellipse(600, 318, 420, 42, HAZE, 0.3)
    for cy, rx, op in ((80, 240, 0.10), (130, 300, 0.08)):
        s.ellipse(rng.uniform(260, 940), cy, rx, 8, "#4a462a", op)

    # 远景：硫烟柱（先画，壁盖根）+ 破火山口壁两排（GROUND 以下由地块盖）
    for i, (px, h) in enumerate(((150, 170), (540, 200), (1100, 150))):
        plume(s, f"pl10p{i}", px, 300, 30, h, 0.32)
    for k, amp, base, col, op in ((1, 46, 300, RIDGE_B, 0.72), (2, 30, 326, RIDGE_F, 0.92)):
        pts = []
        for i in range(13):
            v = 0.5 + 0.5 * math.sin(k * math.pi * 2 * i / 12 + (0.9 if k == 2 else 0))
            pts.append((i * 100, round(base - amp * v)))
        s.poly([(0, GROUND + 4)] + pts + [(W, GROUND + 4)], col, op)

    # 中景：分离塔（左 t0，脚 332）+ 井口阀树 Ω 管（t2 台面，脚 268）
    s.rect(60, 196, 36, 136, BASALT, 0.96)
    s.ellipse(78, 196, 18, 5, BASALT, 0.96)
    s.rect(60, 196, 4, 136, PIPE_HI, 0.35)
    for y in (226, 262, 298):
        s.rect(58, y, 40, 3, BASALT_D, 0.96)
    s.rect(52, 326, 52, 6, BASALT_D, 0.96)
    s.line(96, 214, 180, 214, PIPE, 4, 0.96)
    s.rect(176, 214, 6, 118, PIPE_D, 0.96)                     # 支架落 t0（x176<220 ✓）
    plume(s, "pl10p_t", 78, 191, 12, 60, 0.35)
    # t2：井口台 x300..326 脚 268
    s.rect(300, 240, 26, 28, BASALT_D, 0.96)
    s.rect(308, 212, 10, 28, PIPE, 0.96)
    s.rect(302, 220, 22, 4, PIPE_D, 0.96)
    blue_flame(s, 313, 212, 24, 1.0)
    s.line(318, 228, 400, 228, PIPE, 4, 0.96)
    s.path("M 400,228 L 400,180 L 450,180 L 450,228", stroke=PIPE, w=4, opacity=0.96)
    s.line(450, 228, 560, 228, PIPE, 4, 0.96)
    for px in (360, 425, 500, 556):                            # 管托脚 268（全在 t2 内）
        s.rect(px - 2.5, 230, 5, 38, PIPE_D, 0.96)
    glow_dot(s, 425, 180, SIG, r=1.3, halos=((3, 0.35), (6, 0.12)))
    # t2 硫黄堆（x590..690 脚 268）
    s.poly([(592, 268), (640, 226), (660, 230), (690, 268)], "#a8943c", 0.96)
    s.poly([(640, 226), (660, 230), (650, 244), (632, 240)], "#d8c45c", 0.9)

    # ---- 独层大件：倾斜巨型地热井架（坐 t1 台面 x720..900 脚 300，架顶斜挑到
    #      x1010,y40；井口硫焰在架根；架顶天车放空汽柱）----
    s.ellipse(812, 299, 110, 4, "#1e1c18", 0.55)               # 接地阴影
    s.rect(720, 284, 190, 16, BASALT_D, 0.96)                  # 钻台底座（脚 300）
    s.rect(720, 284, 190, 2.4, PIPE_HI, 0.6)
    L0, R0, top = (744, 284), (884, 284), (1010, 40)           # 左右腿根 → 顶点
    lt = (top[0] - 18, top[1] + 6)
    rt = (top[0] + 14, top[1] + 10)
    s.line(L0[0], L0[1], lt[0], lt[1], PIPE, 6, 0.96)
    s.line(R0[0], R0[1], rt[0], rt[1], PIPE, 6, 0.96)
    for i in range(1, 8):                                      # 桁格横材+斜撑
        t1_, t2_ = i / 8, (i - 1) / 8
        a = (L0[0] + (lt[0] - L0[0]) * t1_, L0[1] + (lt[1] - L0[1]) * t1_)
        b = (R0[0] + (rt[0] - R0[0]) * t1_, R0[1] + (rt[1] - R0[1]) * t1_)
        a0 = (L0[0] + (lt[0] - L0[0]) * t2_, L0[1] + (lt[1] - L0[1]) * t2_)
        b0 = (R0[0] + (rt[0] - R0[0]) * t2_, R0[1] + (rt[1] - R0[1]) * t2_)
        s.line(a[0], a[1], b[0], b[1], PIPE, 2.4, 0.9)
        s.line(a0[0], a0[1], b[0], b[1], PIPE, 1.4, 0.8)
        s.line(b0[0], b0[1], a[0], a[1], PIPE, 1.4, 0.8)
    s.rect(top[0] - 24, top[1] - 4, 44, 16, PIPE_D, 0.96)      # 天车
    s.line(lt[0], lt[1], top[0] - 24, top[1] + 10, PIPE, 2, 0.9)
    plume(s, "pl10big", top[0], top[1] - 4, 26, 40, 0.35)      # 顶部放空（根接天车）
    s.rect(790, 254, 50, 30, BASALT, 0.96)                     # 司钻房（坐底座）
    s.rect(800, 262, 14, 8, "#d6cc8a", 0.6)
    blue_flame(s, 868, 284, 40, 1.0)                           # 井口硫焰（坐底座顶）
    glow_dot(s, 930, 170, SIG, r=1.6, halos=((4, 0.35), (8, 0.12)))  # 架身航标灯（在右腿上）

    gv.draw_ground(s, "p10_sulfur", bottom=H, k=1.0)

    # 前景（ground 之后画）：右平地喷气孔+蓝焰+围栏，左平地结壳
    s.ellipse(1160, 331, 26, 3, "#1e1d1b", 0.95)
    blue_flame(s, 1160, 331, 22, 0.9)
    for fx in (1120, 1138, 1182, 1200):
        s.line(fx, 332, fx, 312, PIPE, 2.4, 0.95)
        s.circle(fx, 311, 1.6, PIPE_HI, 0.9)
    s.line(1120, 318, 1200, 318, PIPE, 1.4, 0.85)
    s.line(1260, 332, 1260, 300, PIPE, 3, 0.95)                # 警示桩
    s.rect(1252, 294, 16, 10, "#3e3c36", 0.95)
    s.rect(1252, 294, 16, 2.4, "#d6cc8a", 0.9)
    s.rect(1255, 298, 10, 3, SIG, 0.85)
    for _ in range(10):                                        # 硫尘
        s.circle(rng.uniform(0, W), rng.uniform(150, 320), rng.uniform(0.8, 1.8),
                 "#e8e0b0", rng.uniform(0.12, 0.3))
    return s


# ============================================================
# 敌营小队剪影配色示意（同 ch9 版式：硫烟天+玄武走道带，五单位朝左 ×2 + 色板条）
# ============================================================
def enemy10():
    s = Svg()
    s.rect(0, 0, W, H, s.vgrad("sky10e", SKY))
    s.glow_ellipse(600, 400, 420, 46, HAZE, 0.26)
    GY = 400
    s.rect(0, GY, W, H - GY, s.vgrad("band10e", [(0, TH["band"], 1), (1, TH["face_lo"], 1)]))
    s.rect(0, GY, W, 2, TH["top_line"])
    for x in (260, 700, 1080):
        s.ellipse(x, GY + 14, 30, 2.5, SULF, 0.4)

    def walker(cx, shield=False):
        x0, y0 = cx - 56, GY - 104
        s.ellipse(cx, GY + 2, 56, 5, "#14120e", 0.5)
        s.rect(x0 + 34, y0 + 26, 60, 46, E_BODY, 1)
        s.rect(x0 + 34, y0 + 26, 60, 8, E_LIGHT, 1)
        s.rect(x0 + 52, y0 + 12, 24, 18, E_BODY, 1)
        s.circle(x0 + 56, y0 + 21, 2.6, EYE, 1)
        s.rect(x0 + 8, y0 + 40, 30, 10, E_LIGHT, 1)
        s.rect(x0 + 2, y0 + 42, 10, 6, E_GAP, 1)
        for lx in (x0 + 44, x0 + 72):
            s.rect(lx, y0 + 72, 12, 20, E_BELLY, 1)
            s.rect(lx - 2, y0 + 90, 16, 6, E_BELLY, 1)
            s.rect(lx + 8, y0 + 80, 8, 14, E_GAP, 1)
        if shield:
            s.rect(x0 - 6, y0 + 18, 12, 78, E_LIGHT, 1)
            s.rect(x0 - 6, y0 + 18, 4, 78, "#8a6274", 1)
            s.rect(x0 - 3, y0 + 44, 6, 6, EYE, 0.9)

    walker(120)
    dx, dy = 250, GY - 190
    s.rect(dx - 38, dy, 76, 40, E_BODY, 1)
    s.rect(dx - 38, dy, 76, 7, E_LIGHT, 1)
    s.circle(dx - 24, dy + 16, 2.6, EYE, 1)
    s.rect(dx - 62, dy + 22, 26, 9, E_LIGHT, 1)
    s.rect(dx - 68, dy + 24, 8, 5, E_GAP, 1)
    s.rect(dx - 26, dy + 40, 52, 8, E_BELLY, 1)
    s.glow_ellipse(dx, dy + 56, 16, 7, SIG, 0.4)               # 推进焰=硫焰蓝
    s.glow_ellipse(dx, dy + 60, 9, 10, SIG_CORE, 0.55)
    walker(390, shield=True)
    ex, ey = 550, GY - 160                                     # 精英车
    s.ellipse(ex, GY + 2, 62, 5, "#14120e", 0.5)
    s.rect(ex - 60, ey + 100, 120, 40, E_BODY, 1)
    s.rect(ex - 60, ey + 100, 120, 8, E_LIGHT, 1)
    s.rect(ex - 60, ey + 140, 116, 12, E_BELLY, 1)
    for tx in range(ex - 52, ex + 56, 16):
        s.circle(tx, ey + 146, 5, E_GAP, 1)
    s.rect(ex - 58, ey + 72, 30, 30, E_BODY, 1)
    s.circle(ex - 52, ey + 84, 2.8, EYE, 1)
    s.rect(ex + 6, ey + 44, 44, 60, E_BELLY, 1)               # 背驮储罐
    s.rect(ex + 6, ey + 44, 44, 5, E_LIGHT, 1)
    s.rect(ex + 22, ey + 30, 12, 16, E_GAP, 1)                 # 罐口
    bx, by = 590, 40                                           # BOSS 悬浮
    s.ellipse(bx + 300, GY + 6, 320, 10, "#14120e", 0.5)
    s.poly([(bx, by + 150), (bx + 60, by + 100), (bx + 200, by + 80),
            (bx + 460, by + 80), (bx + 580, by + 130), (bx + 580, by + 240),
            (bx + 60, by + 240)], E_BODY, 1)
    s.poly([(bx + 60, by + 100), (bx + 200, by + 80), (bx + 460, by + 80),
            (bx + 300, by + 110)], E_LIGHT, 1)
    s.rect(bx + 90, by + 44, 70, 52, E_BELLY, 1)
    s.circle(bx + 108, by + 62, 5, EYE, 1)
    s.rect(bx + 260, by + 30, 40, 54, E_BELLY, 1)              # 背部井口喷嘴塔
    s.rect(bx + 252, by + 24, 56, 10, E_GAP, 1)
    s.rect(bx + 330, by + 50, 90, 34, E_BELLY, 1)              # 储罐段
    s.rect(bx - 20, by + 176, 70, 16, E_LIGHT, 1)              # 艏部喷嘴
    s.rect(bx - 44, by + 180, 28, 8, E_GAP, 1)
    for jx in (bx + 160, bx + 380):
        s.glow_ellipse(jx, by + 252, 26, 12, SIG, 0.35)
        s.glow_ellipse(jx, by + 258, 14, 14, SIG_CORE, 0.5)
    for col, i in ((E_LIGHT, 0), (E_BODY, 1), (E_BELLY, 2), (E_GAP, 3), (EYE, 4), (SIG, 5)):
        cx = 90 + i * 108
        s.rect(cx, 452, 88, 56, col, 1)
        s.rect(cx, 452, 88, 4, "#e0dcc8", 0.5)
        s.rect(cx, 504, 88, 4, "#0c0b09", 0.5)
    return s


# ============================================================
# 光栅 + PIL 合成
# ============================================================
def raster(svg, png, scale):
    r = subprocess.run([GODOT, "--headless", "--path", ROOT, "--script",
                        "res://art_proposals/raster_svg.gd", "--", svg, png, str(scale)],
                       capture_output=True, text=True, timeout=180)
    if not os.path.isfile(png):
        raise SystemExit(f"raster failed: {svg}\n{r.stdout}\n{r.stderr}")


def composite():
    from PIL import Image, ImageDraw
    FW, FH, GT = 2400, 1080, 664
    S9 = os.path.join(ART, "storm_ch9")
    chs = [
        ("ch8 mirror-salt", os.path.join(S9, "_salt_far.png"), os.path.join(S9, "_salt_mid.png"),
         "#b8a684", "#a8967a", "#e8d8bc"),
        ("ch9 storm-line", os.path.join(S9, "env_storm_far.png"), os.path.join(S9, "env_storm_mid.png"),
         "#4e4452", "#453b4a", "#b0a4bc"),
        ("ch10 sulfur-field (new)", os.path.join(HERE, "env_sulfur_far.png"),
         os.path.join(HERE, "env_sulfur_mid.png"), TH["band"], TH["face_hi"], TH["top_line"]),
    ]

    def frame(far_p, mid_p, band, face, topc, line=True):
        img = Image.new("RGB", (FW, FH))
        far = Image.open(far_p).convert("RGBA")
        for x in (0, 1024, 2048):
            img.paste(far, (x, 730 - 1300), far)
        mid = Image.open(mid_p).convert("RGBA")
        for x in (0, 2048):
            img.paste(mid, (x, 700 - 520), mid)
        d = ImageDraw.Draw(img)
        d.rectangle((0, GT, FW, 720), fill=band)
        d.rectangle((0, 720, FW, FH), fill=face)
        d.rectangle((0, GT, FW, GT + 3), fill=topc)
        if line:
            d.line((0, GT, FW, GT), fill=(255, 60, 60), width=2)
        return img

    main = frame(*chs[2][1:])
    d = ImageDraw.Draw(main)
    d.text((16, 12), "ch10 far+mid composite / red line = terrain top y664 (world 2400x1080)",
           fill=(255, 255, 255))
    p1 = os.path.join(HERE, "comp_main_ch10.png")
    main.save(p1)
    sc = 0.5
    sw, sh = int(FW * sc), int(FH * sc)
    out = Image.new("RGB", (sw, sh * 3 + 16), (20, 20, 20))
    for i, (lab, *rest) in enumerate(chs):
        fr = frame(*rest).resize((sw, sh), Image.LANCZOS)
        out.paste(fr, (0, i * (sh + 8)))
        ImageDraw.Draw(out).text((10, i * (sh + 8) + 4), lab + "   red line = y664",
                                 fill=(255, 255, 255))
    p2 = os.path.join(HERE, "comp_ch8_ch9_ch10.png")
    out.save(p2)
    return p1, p2


def build():
    jobs = [(sulfur_field, "proposal_10_sulfur_field", 2), (far10, "env_sulfur_far", 1),
            (mid10, "env_sulfur_mid", 1), (enemy10, "enemy_squad_ch10", 2)]
    for fn, name, sc in jobs:
        svg = os.path.join(HERE, name + ".svg")
        fn().save(svg)
        raster(svg, os.path.join(HERE, name + ".png"), sc)
        print("png", name)
    for p in composite():
        print("png", p)


if __name__ == "__main__":
    build()
