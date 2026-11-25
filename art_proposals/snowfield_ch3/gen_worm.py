# -*- coding: utf-8 -*-
"""第三章 BOSS·机械冰蠕「冰钻」（BossWorm）全部贴图的唯一生成器。

产物直接写 assets/world_3/：
  boss_snow_worm_head.svg   钻头头部 200x160，原点=头心 (100,80)，原生朝 +X（节点按航向转）
  boss_snow_worm_seg_a.svg  体节 A（背刃+散热缝）100x170，原点 (50,85)
  boss_snow_worm_seg_b.svg  体节 B（背刃+舷窗灯）100x170
  boss_snow_worm_tail.svg   尾节 100x170（宽端在 +X 接前节，向 −X 收成尾锥）
  fx_ice_shard.svg          冰锥直射弹 48x16（+X 弹头；长条才读得出高速弹）
  fx_worm_puff.png          雪粉软团 128x96（多团高斯叠成的蓬松团，普通混合）
  fx_worm_chunk.svg         冰块碎片 28x24
  fx_worm_mound.svg         破土隆起 240x110（锚=底边中点 (120,108)，贴地表）
  fx_worm_ridge.svg         潜行雪脊 200x60（锚=底边中点 (100,60)）
  fx_worm_shadow.png        冰下黑影 220x130（软椭圆，节点压扁用）
  fx_worm_mark.svg          航迹雪痕 80x18

构型账（真实参照=隧道掘进机刀盘 + 泰拉瑞亚毁灭者/AC6 冰虫的分节机械蠕虫）：
  真实构型选「掘进机」——头= armored 机壳 + 截锥刀盘（三道滚刀 V 形刀箍 + 先导钻尖），
  不抄任何现役 BOSS 的船体多边形（worlds.md §3「BOSS 剪影不许撞车」）。
  比例：头长 200：头高 160 = 1.25（掘进机刀盘近正方，钝而重）；体节长 100：裸筒高 120（画布 170
  含背刃）——节短才弯得顺：弯道半径 250px 上相邻节转角 23°、三成套叠（30px）盖住外侧张口
  （首版 150px 长节在急弯上散成一排扇形板，拼装自验打回）；10 节逐节收细 1−0.0044k² + 尾节 ×0.5，
  全长≈920（屏幕宽 2400 的 38%）。
  玩家机甲高≈60：蠕虫裸筒 128=2.1 倍，头部 160=2.7 倍——BOSS 体量档（现役 300x180）。

色板=第三章敌营冷蓝灰族（bake_snow_units.py 同源）+ 章信号色：
  LIGHT #5d6c76 / BODY #39444d / BELLY #2a333a / GAP #161c21 / STEEL #aab8c2
  FROST #e8eff3（甲面挂霜=雪原身份+受光读法）/ RED #e23d3d（独眼红=敌）/ CYAN #7fd0ff（散热/舷灯）
  YELLOW #c9b23c（标识条）
ThorVG 硬约束：无 filter/pattern/use/text/transform；无 rect+rotate。
软边贴图（雪粉/黑影）走 PNG 不走 SVG：SVG 径向渐变的光栅在圆外是 (0,0,0,0)，双线性采样
在软边上混出暗边=「半透明泡泡」读法（实机截图打回）；PNG 由本脚本用 numpy 直接写，
RGB 全幅恒定、只动 alpha（预乘一致），任何缩放档都没有边缘色偏。
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.normpath(os.path.join(ROOT, "art_proposals")))
from generate_proposals import Svg, f  # noqa: E402

OUT = os.path.join(ROOT, "assets", "world_3")

LIGHT, BODY, BELLY, GAP = "#5d6c76", "#39444d", "#2a333a", "#161c21"
STEEL, FROST, RED, CYAN = "#aab8c2", "#e8eff3", "#e23d3d", "#7fd0ff"
YELLOW = "#c9b23c"
SNOW_HI, SNOW_MID, SNOW_LO = "#f2f8fb", "#cfdfe8", "#b9cdd9"
SHADOW = "#2a333a"


def save(s, name, comment):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(s.w)} {f(s.h)}" '
           f'width="{f(s.w)}" height="{f(s.h)}">\n<!-- {comment.strip()} -->\n<defs>\n'
           + "\n".join(s.defs) + "\n</defs>\n" + "\n".join(s.body) + "\n</svg>\n")
    with open(os.path.join(OUT, name), "w", encoding="utf-8", newline="\n") as fp:
        fp.write(svg)
    print(name)


# ============================================================
# 头部：机壳 + 截锥刀盘（200x160，原点 (100,80)，朝 +X）
# ============================================================
def head():
    s = Svg(200, 160)
    # ---- 颈环（接首节）：深色套环 + 上下两根液压杆 ----
    s.rect(0, 16, 26, 128, GAP, rx=6)
    s.circle(13, 34, 3, STEEL, 0.85)
    s.circle(13, 126, 3, STEEL, 0.85)
    s.rect(8, 46, 24, 7, STEEL)
    s.rect(8, 107, 24, 7, STEEL)
    s.rect(8, 49, 24, 1.5, GAP, 0.5)
    s.rect(8, 110, 24, 1.5, GAP, 0.5)
    # ---- 机壳 ----
    s.poly([(24, 10), (112, 18), (124, 34), (124, 126), (112, 142), (24, 150)], BODY)
    s.poly([(24, 10), (112, 18), (120, 30), (24, 24)], LIGHT, 0.9)
    s.poly([(24, 132), (124, 126), (112, 142), (24, 150)], BELLY)
    # 挂霜（甲面挂雪：受光读法）
    s.poly([(30, 8), (58, 10), (54, 17), (84, 14), (104, 20), (112, 26), (24, 22)], FROST, 0.95)
    # 面板缝
    s.line(62, 24, 62, 134, GAP, 1.5, 0.45)
    s.line(96, 20, 96, 132, GAP, 1.5, 0.45)
    # 独眼（EyeGlow 节点画布 (72,43)=局部 (-28,-37)）
    s.rect(52, 34, 40, 18, GAP)
    s.rect(54, 36, 36, 2, STEEL, 0.4)
    s.rect(58, 40, 28, 6, RED)
    # 散热栅（三道，青色内芯）
    for y in (66, 80, 94):
        s.rect(34, y, 22, 6, GAP)
        s.rect(37, y + 2, 16, 2, CYAN, 0.85)
    # 口部发射器（Muzzle 画布 (140,80)=局部 (40,0)；上下各两枚钢齿框住）
    s.poly([(118, 48), (142, 56), (142, 104), (118, 112)], GAP)
    s.ellipse(132, 80, 5, 20, CYAN, 0.5)
    for tx in (120, 130):
        s.poly([(tx, 50 + (tx - 120) * 0.3), (tx + 8, 50 + (tx - 120) * 0.3),
                (tx + 4, 58 + (tx - 120) * 0.3)], STEEL)
        s.poly([(tx, 110 - (tx - 120) * 0.3), (tx + 8, 110 - (tx - 120) * 0.3),
                (tx + 4, 102 - (tx - 120) * 0.3)], STEEL)
    # ---- 截锥刀盘 ----
    s.poly([(126, 28), (166, 52), (188, 68), (198, 80), (188, 92), (166, 108), (126, 132)], BELLY)
    s.poly([(126, 28), (166, 52), (162, 60), (126, 40)], LIGHT, 0.7)
    for x, yt, yb in ((142, 38, 122), (158, 46, 114), (174, 56, 104)):
        s.path(f"M {x - 6},{yt} L {x + 9},80 L {x - 6},{yb}", "none", STEEL, 5.5, cap="round")
        s.path(f"M {x - 1},{yt + 3} L {x + 14},80 L {x - 1},{yb - 3}", "none", GAP, 2, 0.6)
    # 先导钻尖 + 尾灯红点
    s.poly([(186, 70), (200, 80), (186, 90)], STEEL)
    s.line(190, 80, 199, 80, GAP, 1.2)
    s.circle(196, 80, 2.2, RED)
    save(s, "boss_snow_worm_head.svg", """机械冰蠕「冰钻」钻头头部 200x160，原点=头心 (100,80)，原生朝 +X（节点按航向转）。
构型=隧道掘进机刀盘：颈环(0..26)+机壳(24..124)+口部发射器(118..142)+截锥刀盘(126..198)+先导钻尖。
锚点：EyeGlow 画布 (72,43)=局部 (-28,-37)；Muzzle 画布 (140,80)=局部 (40,0)（ArmPivot 同轴随头转）。
碰撞=头心矩形 176x124（Node2D CollisionShape，露出地面才启用）。色板=第三章冷蓝灰族。
生成器=art_proposals/snowfield_ch3/gen_worm.py（改图改脚本别手改）。""")


def _drum(s):
    """体节公用筒身（100x170，原点 (50,85)，+X=朝头一侧）。"""
    s.poly([(6, 32), (94, 32), (98, 44), (98, 140), (94, 152), (6, 152), (2, 140), (2, 44)], BODY)
    s.poly([(6, 32), (94, 32), (94, 44), (6, 44)], LIGHT, 0.85)
    s.poly([(6, 140), (98, 140), (94, 152), (6, 152)], BELLY)
    s.poly([(9, 31), (46, 30), (42, 38), (90, 35), (93, 41), (9, 43)], FROST, 0.9)
    s.line(50, 44, 50, 140, GAP, 1.5, 0.4)
    # 后裙（朝尾）与前套环（朝头）+ 两根液压杆（弯道外侧张开时露出来=关节读法）
    s.rect(0, 42, 6, 100, BELLY)
    s.rect(0, 42, 2, 100, GAP, 0.5)
    s.rect(92, 38, 8, 108, GAP)
    s.rect(88, 66, 10, 6, STEEL)
    s.rect(88, 112, 10, 6, STEEL)
    # 低背刃：逐节连成一条背脊线（剪影）
    s.rect(8, 26, 84, 6, GAP)
    s.poly([(16, 32), (34, 6), (62, 8), (82, 32)], BELLY)
    s.line(34, 6, 62, 8, LIGHT, 3, cap="round")
    s.poly([(33, 8), (46, 7), (49, 13), (35, 16)], FROST, 0.8)
    s.rect(1, 52, 3, 18, YELLOW, 0.8)


def seg_a():
    s = Svg(100, 170)
    _drum(s)
    s.rect(36, 80, 26, 10, GAP)
    s.rect(40, 83, 18, 4, CYAN, 0.9)
    save(s, "boss_snow_worm_seg_a.svg", """机械冰蠕「冰钻」体节 A（背刃+散热缝）100x170，原点 (50,85)，+X=朝头一侧（套环端）。
筒身 y32..152（高 120）；背刃尖 (34,6)。节点按所在链位的切线转、按链位缩放
（BalanceWorld3.WORM_SEG_SCALES）。A/B 沿链交替。生成器=gen_worm.py。""")


def seg_b():
    s = Svg(100, 170)
    _drum(s)
    s.circle(50, 86, 13, STEEL, 0.5)
    s.circle(50, 86, 11, GAP)
    s.circle(50, 86, 5, CYAN, 0.9)
    save(s, "boss_snow_worm_seg_b.svg", """机械冰蠕「冰钻」体节 B（背刃+舷窗灯）100x170，原点 (50,85)，+X=朝头一侧（套环端）。
舷窗灯心 (50,86)。生成器=gen_worm.py。""")


def tail():
    s = Svg(100, 170)
    # 宽端在 +X（接末节），向 −X 收成尾锥
    s.poly([(2, 85), (32, 52), (94, 44), (98, 58), (98, 112), (94, 126), (32, 118)], BODY)
    s.poly([(32, 52), (94, 44), (94, 58), (38, 64)], LIGHT, 0.8)
    s.poly([(32, 118), (94, 126), (98, 112), (38, 106)], BELLY, 0.9)
    s.poly([(38, 50), (84, 46), (83, 53), (42, 58)], FROST, 0.8)
    s.line(62, 48, 62, 122, GAP, 1.5, 0.4)
    s.rect(92, 50, 8, 70, GAP)
    s.poly([(24, 60), (12, 36), (28, 46), (38, 54)], BELLY)
    s.poly([(24, 110), (12, 134), (28, 124), (38, 116)], BELLY)
    for y in (72, 94):
        s.rect(44, y, 10, 4, GAP)
        s.rect(46, y + 1, 6, 2, CYAN, 0.8)
    s.poly([(2, 85), (22, 76), (22, 94)], STEEL)
    s.line(5, 85, 21, 85, GAP, 1.2)
    s.circle(28, 85, 3.5, RED)
    save(s, "boss_snow_worm_tail.svg", """机械冰蠕「冰钻」尾节 100x170，原点 (50,85)。宽端（套环）在 +X 接末节，
向 −X 收成尾锥，钢尖 (2,85)；双稳定鳍；红尾灯 (28,85)。生成器=gen_worm.py。""")


# ============================================================
# 弹与特效贴图
# ============================================================
def shard():
    s = Svg(48, 16)
    s.poly([(1, 8), (14, 1.5), (36, 1.5), (47, 8), (36, 14.5), (14, 14.5)], "#1f2c36")
    s.poly([(4, 8), (15, 2.8), (35, 2.8), (44, 8), (35, 13.2), (15, 13.2)], "#86b4d4")
    s.poly([(8, 8), (16, 4.2), (34, 4.8), (41, 8), (34, 11.2), (16, 11.8)], "#f2fbff")
    s.line(16, 4.2, 20, 11.8, "#ffffff", 1, 0.5)
    s.poly([(2, 5), (8, 6.6), (8, 9.4), (2, 11)], "#dfeaf2", 0.85)
    save(s, "fx_ice_shard.svg", """冰锥直射弹贴图 48x16（ice_shard.tscn=bullet.gd 纯换皮，+X 弹头）。
普通混合（不 ADD）：暗描边 #1f2c36 + 钢蓝 #86b4d4 + 白冰芯——亮背景章靠描边剪影读；
长条形（首版 32x12 在 1600 窗里读成小圆点，高速弹的读法=拉长度）。碰撞=胶囊 r4×长 40。
生成器=art_proposals/snowfield_ch3/gen_worm.py。""")


def _soft_png(name, rgb, width, height, blobs, peak, window):
    """多团高斯叠成软边贴图：RGB 全幅恒定、只有 alpha 变（见文件头「软边贴图」说明）。
    window=(cx, cy, rx, ry)=椭圆窗：窗内 1、到窗边线性收到 0——高斯尾在画布四边还有残 alpha，
    不开窗贴图边界会露出一圈硬直边（黑影实机读成「走道下面一个深色方框」，打回）。"""
    import numpy as np
    from PIL import Image
    ys, xs = np.mgrid[0:height, 0:width]
    acc = np.zeros((height, width), dtype=float)
    for cx, cy, sig, amp in blobs:
        acc += amp * np.exp(-((xs + 0.5 - cx) ** 2 + (ys + 0.5 - cy) ** 2) / (2.0 * sig * sig))
    wx, wy, wrx, wry = window
    r2 = ((xs + 0.5 - wx) / wrx) ** 2 + ((ys + 0.5 - wy) / wry) ** 2
    alpha = (np.clip(acc / peak, 0.0, 1.0) * np.clip(1.0 - r2, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    img = np.zeros((height, width, 4), dtype=np.uint8)
    img[..., 0] = rgb[0]
    img[..., 1] = rgb[1]
    img[..., 2] = rgb[2]
    img[..., 3] = alpha
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name))
    print(name, "edge_alpha_max=%d" % int(max(alpha[0].max(), alpha[-1].max(), alpha[:, 0].max(), alpha[:, -1].max())))


def puff():
    # 中心大团 + 七个偏心小团：边缘凹凸=蓬松雪团，不是圆片
    _soft_png("fx_worm_puff.png", (255, 255, 255), 128, 96, [
        (64, 50, 26, 1.0), (40, 60, 17, 0.9), (90, 58, 18, 0.9), (50, 34, 15, 0.85),
        (80, 32, 14, 0.85), (64, 72, 13, 0.8), (26, 42, 11, 0.7), (104, 42, 11, 0.7),
    ], 1.0, (64, 50, 62, 46))


def shadow():
    # 软椭圆黑影：窄核 + 宽晕两层
    _soft_png("fx_worm_shadow.png", (42, 51, 58), 220, 130, [
        (110, 65, 44, 1.0), (110, 65, 82, 0.45),
    ], 1.25, (110, 65, 108, 63))


def chunk():
    s = Svg(28, 24)
    pts = [(2, 16), (9, 3), (22, 2), (26, 13), (17, 22), (6, 21)]
    s.poly(pts, SNOW_HI)
    s.poly([(9, 3), (22, 2), (17, 12), (8, 12)], "#c3d9e6")
    d = "M " + " L ".join(f"{x},{y}" for x, y in pts) + " Z"
    s.path(d, "none", "#9fb8c8", 1.2)
    save(s, "fx_worm_chunk.svg", """冰块碎片 28x24（破土/入地喷块粒子）。白冰面+青灰棱面+细描边。
生成器=art_proposals/snowfield_ch3/gen_worm.py。""")


def mound():
    s = Svg(240, 110)
    s.path("M 8,108 Q 120,-8 232,108 Z", SNOW_HI)
    s.path("M 120,108 Q 190,40 232,108 Z", SNOW_MID)
    s.path("M 120,14 L 112,48 L 122,74 L 116,106", "none", "#5f6f7a", 3)
    s.path("M 96,30 L 88,60 L 76,104", "none", "#5f6f7a", 2.2)
    s.path("M 146,32 L 156,66 L 168,104", "none", "#5f6f7a", 2.2)
    save(s, "fx_worm_mound.svg", """破土隆起 240x110：雪丘（右翼背光）+ 三道裂隙。锚=底边中点 (120,108)，贴地表线摆放；
峰值在 (120,10)（ThreatFlash 挂点）。生成器=art_proposals/snowfield_ch3/gen_worm.py。""")


def ridge():
    s = Svg(200, 60)
    s.path("M 2,60 Q 50,6 110,12 Q 160,20 198,60 Z", SNOW_HI)
    s.path("M 110,12 Q 160,20 198,60 L 110,60 Z", SNOW_MID)
    s.path("M 60,22 L 78,58", "none", SNOW_LO, 2)
    save(s, "fx_worm_ridge.svg", """潜行雪脊 200x60（地表航迹的隆脊）。锚=底边中点 (100,60)。生成器=gen_worm.py。""")


def mark():
    s = Svg(80, 18)
    s.path("M 4,13 L 22,8 L 44,14 L 76,9", "none", SNOW_LO, 2, 0.6, cap="round")
    s.path("M 4,11 L 22,6 L 44,12 L 76,7", "none", "#f7fafb", 3.5, cap="round")
    save(s, "fx_worm_mark.svg", """航迹雪痕 80x18：潜行沿途留下的亮色扰动痕（深色走道带上靠亮痕读），自淡。
生成器=art_proposals/snowfield_ch3/gen_worm.py。""")


if __name__ == "__main__":
    head()
    seg_a()
    seg_b()
    tail()
    shard()
    puff()
    chunk()
    mound()
    ridge()
    shadow()
    mark()
