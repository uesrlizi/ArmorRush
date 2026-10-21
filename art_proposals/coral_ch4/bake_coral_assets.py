# -*- coding: utf-8 -*-
"""方案四「珊瑚辐合夜」游戏素材烘焙（第四章换皮）：把提案拆成游戏用的 SVG。

产物直接写入 2d-ac/assets/（命名 *_coral_*）：
  env_coral_far.svg           1024x1300 远景条（靛蓝夜空+塔群剪影）
  env_coral_ring.svg          3200x640  碎环巨构独层（tile 3200 一现，防平铺重复）
  env_coral_mid.svg           2048x520  中景条（半埋管廊/采掘井架/天线阵地）
  env_coral_ground.svg        256x480   兜底地面条
  env_coral_ground_top.svg    256x56    地块表面带（玄武岩+珊瑚地裂）
  env_coral_ground_fill.svg   16x256    地块填充竖向渐变
  env_coral_deck.svg          720x26    栈桥桥面（夜航钢板+位标灯）
  enemy_coral_walker_body.svg 56x52     步行者换皮：潜航重步机（耐压壳+逆关节足）
  enemy_coral_walker_arm.svg  48x28     步行者枪臂换皮（鱼雷管长炮）
  enemy_coral_drone.svg       38x42     无人机换皮：伞灯浮游机（钟形伞体+垂缆）
  enemy_coral_drone_arm.svg   32x16     无人机枪臂换皮
  enemy_coral_shield_body.svg 56x52     盾卫换皮：蜂巢堡盾（盾面珊瑚发光缝）
  enemy_coral_elite_body.svg  60x80     精英换皮：磁悬浮雷舱车（斜甲双肩井）
  boss_coral_body.svg         300x180   BOSS 换皮：深海猎杀舰「鮟鱇」（整体重设计）
  boss_coral_gun.svg          110x32    BOSS 机枪臂换皮（转膛炮）
  boss_coral_rotor.svg        84x16     BOSS 尾推桨 blade bar（涵道内）
  boss_coral_tailrotor.svg    56x56     BOSS 侧置姿态风扇（五叶）

骨架对齐账（换皮铁律：美术重画、锚点不动）：
  步行者：眼 (15.5,18.3)；肩 joint (16,24)；地面 y=50
  无人机：眼 (12,14.4)；枪口=臂画布 (13,11)
  盾卫：  眼 (23.5,18.3)；肩 joint (24,24)
  精英：  眼 (19,26.5)；两仓口画布 (38.5,1.5)/(49.5,1.5)（=pivot±5.5）
  BOSS：  眼条带 y60..66 含 (55,63)；导弹仓口画布 x 83/105/167/189 @ y26；
          枪口=臂画布 (2,~4)（flip_v 后贴艇艏下颌）；
          尾推桨 bar 心=节点 (122,-26)→画布 (272,64)（尾部涵道内）；
          侧风扇心=节点 (122,22)→画布 (272,112)（尾部下浮筒）

色板（提案四「靛蓝夜+珊瑚辉光」）：天空 #090d22→#131a38→#273052、
碎环 #1c2547、塔群剪影 #0d1330、雾带 #3a4674、岩丘 #0a0e22、
珊瑚光 #ff5a33/#ff7a45/#ffb36b、余烬 #ff9c5a、冷天光边 #4a5890。
机甲（敌营随章转亮钢蓝——**暗场章对"近黑=敌"的 Chapter 例外**：近黑会埋进
#090d22 夜底，敌营反转成比天亮一档的冷钢蓝，阵营语言=亮钢蓝壳体+珊瑚灯位+
独眼红不变）：LIGHT #9fb0d8 / BODY #5d6d94 / BELLY #3f4c6e / GAP #262f4a
+ 危险黄 #d8a021 + 珊瑚灯 #ff7a45。
ThorVG 硬约束：无 filter/pattern/use/text/transform；平铺接缝两侧留空。单位件坐标全手排。
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
from generate_proposals import Svg, f, arc_path  # noqa: E402

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "world_4"))

# ---- 环境色板（提案四「珊瑚辐合夜」） ----
SKY_STOPS = [(0, "#090d22", 1), (0.55, "#131a38", 1), (1, "#273052", 1)]
STAR = "#dfe6ff"      # 星点
RING = "#1c2547"      # 碎环巨构主体
RING_ALT = "#232d55"  # 错位碎环段
CORAL = "#ff5a33"     # 珊瑚主光
CORAL_HI = "#ff7a45"  # 珊瑚亮边
CORAL_CORE = "#ffb36b"  # 珊瑚白热芯
EMBER = "#ff9c5a"     # 上升余烬
TOWER = "#0d1330"     # 远景塔群剪影
WINDOW = "#ff6a3d"    # 塔窗珊瑚点
HAZE = "#3a4674"      # 雾带
MOUND = "#0a0e22"     # 中景剪影/岩丘
RIM_COLD = "#4a5890"  # 剪影冷天光边
ROAD = "#12172b"      # 玄武岩路面
ROAD_DEEP = "#0a0d1c"
STRATA = "#1a2140"    # 路面层理
MARK = "#6a7aa8"      # 磨损标线
FILL_STOPS = [(0, "#161c34", 1), (0.45, "#0f1326", 1), (1, "#080b18", 1)]

# ---- 机甲色板（敌营随章转亮钢蓝，暗场章例外见文件头） ----
LIGHT = "#9fb0d8"
BODY = "#5d6d94"
BELLY = "#3f4c6e"
GAP = "#262f4a"
RED = "#ff4640"
YELLOW = "#d8a021"
CORAL_LAMP = "#ff7a45"  # 单位珊瑚信号灯


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
    """远景条 1024x1300：靛蓝夜空 + 星点 + 塔群剪影 + 地平线珊瑚辉光。
    比例账：塔群高 150..380；两侧 24px 留空=接缝纯天空。画布底 1300=世界 730。
    碎环巨构已迁出（tile 1024 里画唯一地标=同屏 2~3 份穿帮），见 ring_strip()。
    种子 4041。"""
    rng = random.Random(4041)
    s = Svg(1024, 1300)
    s.rect(0, 0, 1024, 1300, s.vgrad("sky", SKY_STOPS))
    # 星点（上半天）
    for _ in range(26):
        s.circle(rng.uniform(30, 994), rng.uniform(20, 620), rng.uniform(0.8, 1.6),
                 STAR, rng.uniform(0.3, 0.85))
    # ---- 远景塔群剪影（稀疏珊瑚窗）----
    for tx, tw, th in ((70, 80, 210), (190, 56, 260), (320, 110, 170), (520, 70, 240),
                       (650, 90, 150), (860, 100, 250)):
        top = 1300 - th
        s.rect(tx, top, tw, th, TOWER)
        if rng.random() < 0.6:  # 斜切顶
            cut = rng.uniform(14, 40)
            s.poly([(tx, top), (tx + tw, top), (tx + tw, top + cut)], TOWER)
        if rng.random() < 0.5:
            s.line(tx + tw * 0.5, top, tx + tw * 0.5, top - rng.uniform(22, 54), TOWER, 3)
        for _ in range(rng.randint(2, 5)):
            s.rect(tx + rng.uniform(6, tw - 12), top + rng.uniform(14, th - 20), 4, 7,
                   WINDOW, rng.uniform(0.5, 0.9))
    # 地平线远端珊瑚辉光 + 上升余烬
    s.glow_ellipse(500, 1296, 120, 26, CORAL, 0.10)
    s.glow_ellipse(500, 1296, 56, 14, CORAL_HI, 0.18)
    for _ in range(12):
        ex, ey = rng.uniform(380, 860), rng.uniform(780, 980)
        s.circle(ex, ey, rng.uniform(1, 2), EMBER, rng.uniform(0.3, 0.8))
        s.line(ex, ey + 3, ex, ey + 10, EMBER, 1, 0.12)
    # 雾带（贴地）
    g = s.vgrad("hz", [(0, HAZE, 0), (1, HAZE, 0.35)])
    s.rect(0, 1010, 1024, 290, g)
    return s


def ring_strip():
    """碎环巨构独层 3200x640 透明底（RingStrip，tile 3200 > 视口 2400 →
    同屏最多一份，数学上消灭平铺重复；视差同 far=0.9，画在 HillsStrip 之后
    被 MidStack 前景遮挡）。
    主环心画布 (1600,320) r240。**tex 落位规则（二轮翻车点：2400 会回绕弹切）**：
    环渲染位 rel = phase−3200+tex_x，phase 回绕（3200→0）瞬间所有拷贝 +3200，
    落在 region 左边界外的那份直接消失——环必须在该时刻全出屏：
    tex_x−3200+半宽 ≤ −1200 且 tex_x−半宽 ≥ 1200 → tex_x ∈ [1200+半宽, 3200−1200−半宽]，
    半宽≈270 → 取 1600（两侧各 130px 余量）。开机 phase=3140 时环刚在右屏外，
    起跑约 1s 后从右缘滑入；屏上约 39s / 空档约 14s。
    地上大弧环已按用户要求删除（中景坠环残片，重复感强）。
    **region 账（首版翻车点）**：WorldStrip 节点每帧钉在 镜头x+phase（phase∈
    [0,tile)），region 宽必须 ≥ 视口+tile 才能全程盖屏——tscn 里 region 用
    6400x640（同其他条带），别用 tile 原宽。种子 4044。"""
    rng = random.Random(4044)
    s = Svg(3200, 640)
    cx, cy, rr = 1600.0, 320.0, 240.0
    for a0, a1 in ((-30, 80), (95, 150), (166, 205), (216, 258), (268, 320)):
        s.path(arc_path(cx, cy, rr, a0, a1), stroke=RING, w=34)
    # 错位碎环段
    s.path(arc_path(cx + 9, cy + 11, rr, 20, 62), stroke=RING_ALT, w=30)
    # 下缘珊瑚光边（宽软晕 + 细亮线 + 白热节点）
    s.path(arc_path(cx, cy, rr - 17, 120, 205), stroke=CORAL, w=9, opacity=0.2)
    s.path(arc_path(cx, cy, rr - 17, 120, 205), stroke=CORAL, w=2.5, opacity=0.85)
    for aa in (128, 160, 188):
        ax = cx + (rr - 17) * math.cos(math.radians(aa))
        ay = cy + (rr - 17) * math.sin(math.radians(aa))
        s.circle(ax, ay, 4, CORAL_HI, 0.35)
        s.circle(ax, ay, 1.6, CORAL_CORE, 0.95)
    # 环周散星（巨构尺度感）
    for _ in range(14):
        s.circle(rng.uniform(60, 3140), rng.uniform(60, 580), rng.uniform(0.8, 1.4),
                 STAR, rng.uniform(0.3, 0.7))
    return s


def mid_strip():
    """中景条 2048x520（透明底，tile 2048）：三段各异——
    A 半埋输送管廊（双管+法兰+泄压阀塔，断口珊瑚渗光）；B 采掘井架+管排；
    C 半埋堡坎+天线阵。剪影 #0a0e22 + 冷天光边 #4a5890 + 珊瑚点。
    （原 A 段"坠落的环残片"大弧已删——用户：地上环重复感强。）
    世界 y：画布 520=世界 700（地形顶之下）。两侧 40px 留空。种子 4042。"""
    rng = random.Random(4042)
    s = Svg(2048, 520)
    BASE = 520.0

    # ---- A 段：半埋输送管廊（横向双管，与 B 段井架竖构图对比）----
    s.rect(300, 478, 400, 14, MOUND)             # 上管
    s.rect(300, 478, 400, 2.5, RIM_COLD, 0.4)    # 顶缘冷光
    s.rect(300, 496, 400, 24, MOUND)             # 下管（半没入地平）
    for fx in (360, 470, 600):                   # 法兰（竖短矩形）
        s.rect(fx - 4, 474, 8, 40, MOUND)
        s.rect(fx - 4, 474, 8, 3, RIM_COLD, 0.5)
    # 泄压阀塔 + 警灯
    s.rect(548, 436, 16, 44, MOUND)
    s.rect(544, 432, 24, 6, MOUND)
    s.line(556, 432, 556, 410, MOUND, 3)
    s.circle(556, 406, 2.2, RED, 0.85)
    # 管尾断口（撕裂 + 珊瑚渗光）
    s.poly([(700, 478), (724, 472), (718, 508), (694, 512)], "#070a1c")
    s.circle(716, 492, 2.4, CORAL_HI, 0.8)
    s.circle(716, 492, 5, CORAL, 0.2)
    # 半埋碎屑堆
    s.ellipse(430, BASE, 120, 13, "#10152e")
    s.ellipse(680, BASE, 80, 10, "#10152e", 0.9)

    # ---- B 段：采掘井架 + 管排 ----
    # 井架（收分桁架，双腿 + 横撑之字）
    lx0, lx1, ltop = 1010.0, 1130.0, 300.0
    s.line(lx0, BASE, lx0 + 36, ltop, MOUND, 7)
    s.line(lx1, BASE, lx1 - 36, ltop, MOUND, 7)
    yy = BASE - 26
    while yy > ltop + 14:
        t = (BASE - yy) / (BASE - ltop)
        xl = lx0 + 36 * t
        xr = lx1 - 36 * t
        s.line(xl, yy, xr, yy - 24, MOUND, 3, 0.95)
        s.line(xr, yy, xl, yy - 24, MOUND, 3, 0.95)
        yy -= 24
    s.rect(lx0 + 22, ltop - 14, 86, 12, MOUND)          # 顶平台
    s.circle(lx0 + 65, ltop - 26, 13, MOUND)            # 天车轮
    s.circle(lx0 + 65, ltop - 26, 5, "#070a1c", 0.9)
    s.line(lx0 + 65, ltop - 14, lx0 + 65, ltop - 39, MOUND, 3)
    s.circle(lx0 + 65, ltop - 44, 2.2, RED, 0.85)       # 警灯
    # 冷天光边（腿外缘）
    s.line(lx0, BASE - 6, lx0 + 36, ltop + 4, RIM_COLD, 1.4, 0.4)
    # 出渣管排（地面横管 + 支墩）
    s.rect(880, 486, 300, 12, MOUND)
    s.rect(880, 486, 300, 2.5, RIM_COLD, 0.4)
    for px in (910, 990, 1070, 1150):
        s.rect(px, 498, 10, 22, MOUND)

    # ---- C 段：半埋堡坎 + 天线阵 ----
    s.rect(1560, 462, 210, 58, MOUND)                   # 堡坎主体（半埋）
    s.rect(1560, 462, 210, 4, RIM_COLD, 0.45)           # 顶缘冷光
    s.poly([(1560, 462), (1596, 448), (1740, 448), (1770, 462)], MOUND)  # 顶罩
    s.poly([(1596, 448), (1740, 448), (1736, 452), (1600, 452)], RIM_COLD, 0.35)
    for wx in (1610, 1680, 1720):                       # 射击窗（珊瑚微光）
        s.rect(wx, 484, 14, 10, "#070a1c")
        s.rect(wx + 3, 487, 8, 4, WINDOW, 0.75)
    # 天线阵（三杆，杆顶灯）
    for ax, ah, tilt in ((1520, 92, 2), (1810, 118, -3), (1900, 74, 2)):
        s.line(ax, 462, ax + tilt, 462 - ah, MOUND, 4)
        s.line(ax - 12 + tilt, 462 - ah * 0.45, ax + 12 + tilt, 462 - ah * 0.45, MOUND, 2.5)
        s.circle(ax + tilt, 462 - ah - 3, 2.0, RED, 0.85)
    s.ellipse(1810, 384, 14, 6, MOUND)                  # 碟形天线
    s.line(1810, 388, 1810, 344, MOUND, 3)
    # 底部雾
    g = s.vgrad("fog", [(0, HAZE, 0), (1, HAZE, 0.42)])
    s.rect(0, 438, 2048, 82, g)
    return s


def ground_top():
    """地块表面带 256x56（横向平铺）：玄武岩 + 珊瑚地裂。
    比例账：顶缘冷天光 3px、层理横带、磨损标线 y26、底缘暗 5px；
    地裂/余烬距边 >=6px，接缝=纯路面。种子 4043。"""
    rng = random.Random(4043)
    s = Svg(256, 56)
    s.rect(0, 0, 256, 56, ROAD)
    s.rect(0, 0, 256, 3, RIM_COLD)             # 顶缘冷天光（受夜天光）
    s.rect(0, 3, 256, 1.5, "#5a6aa0", 0.5)     # 冷光柔边
    s.rect(0, 51, 256, 5, ROAD_DEEP)           # 底缘压暗
    # 层理横带（玄武岩沉积纹）
    s.line(0, 14, 256, 14, STRATA, 3, 0.5)
    s.line(0, 40, 256, 40, STRATA, 3, 0.5)
    # 磨损标线（两段，接缝处留空）
    s.rect(30, 26, 22, 3, MARK, 0.4)
    s.rect(150, 26, 22, 3, MARK, 0.4)
    # 暗斑
    for sx, sw in ((60, 40), (130, 30), (210, 34)):
        s.ellipse(sx, rng.uniform(8, 46), sw / 2, rng.uniform(2, 3.5), "#0d1226", 0.7)
    # 珊瑚地裂（暗缝芯 + 珊瑚光边 + 白热端点；两段，接缝留空）
    for cx, cy in ((46, 12), (176, 34)):
        pts_ = [(cx, cy)]
        px, py = cx, cy
        for _ in range(3):
            px += rng.uniform(9, 17)
            py += rng.uniform(4, 9)
            pts_.append((px, py))
        d = "M " + " L ".join(f"{f(a)},{f(b)}" for a, b in pts_)
        s.path(d, stroke="#060812", w=2.4, opacity=0.9)
        s.path(d, stroke=CORAL, w=1, opacity=0.75)
        s.circle(px, py, 1.3, CORAL_CORE, 0.9)
    # 余烬点
    for _ in range(8):
        s.circle(rng.uniform(6, 250), rng.uniform(6, 48), rng.uniform(0.8, 1.4),
                 EMBER, rng.uniform(0.4, 0.7))
    return s


def ground_fill():
    """地块填充 16x256 竖向渐变（岩床向深处压暗，保HUD底衬可读）。"""
    s = Svg(16, 256)
    s.rect(0, 0, 16, 256, s.vgrad("fillg", FILL_STOPS))
    return s


def ground_strip():
    """兜底地面条 256x480（GroundStrip，位于世界 664..1144）：表面带 + 深处渐变。"""
    s = Svg(256, 480)
    src = ground_top()
    s.body.extend(src.body)
    s.defs.extend(src.defs)
    g = s.vgrad("deepg", [(0, "#0f1326", 1), (1, "#080b18", 1)])
    s.rect(0, 56, 256, 424, g)
    return s


def deck():
    """栈桥桥面 720x26：夜航钢板 + 格栅纹 + 桁架腹杆 + 珊瑚位标灯。
    行走面=顶缘（冷光 3px + 钢板 7px），桁架收在下 16px。"""
    s = Svg(720, 26)
    s.rect(0, 0, 720, 3, "#8fa0cf")            # 顶缘冷天光
    s.rect(0, 3, 720, 7, "#1e2540")            # 钢桥面板
    for gx in range(9, 720, 18):               # 格栅纹
        s.line(gx, 4.5, gx, 9.5, "#141a30", 1.6, 0.6)
    s.rect(0, 10, 720, 2.5, "#0e1226")         # 前缘口
    for lx in range(60, 720, 120):             # 珊瑚位标灯（航行灯语言，克制间距）
        s.circle(lx, 11.2, 1.2, CORAL_LAMP, 0.8)
    for i in range(18):                        # 桁架腹杆
        x0 = i * 40.0
        if i % 2 == 0:
            s.line(x0, 12.5, x0 + 40, 24.5, "#141a30", 2.0)
        else:
            s.line(x0, 24.5, x0 + 40, 12.5, "#141a30", 2.0)
    s.line(0, 24.5, 720, 24.5, "#141a30", 2.0)  # 下弦
    return s


# ============================================================
# 敌人单位（骨架锚点与一/二/三章逐点对齐；造型第四章全重画）
# ============================================================
def walker_body():
    """步行者换皮「潜航重步机」56x52，地面 y=50。
    比例账：耐压壳舱体（圆钝胶囊，5..46 x 12..33）+ 背部双氧罐 + 逆关节双足
    （远侧对 BELLY、近侧对 BODY）踏地 y50；头部圆舷窗托独眼。
    骨架：眼 (15.5,18.3)=halo r5.3/core r2.4；肩 joint (16,24)。前缘 x<6 留空给枪臂。"""
    s = Svg(56, 52)
    # 远侧足对（先画，暗一档）
    s.poly([(24, 32), (29, 32), (27, 41), (31, 46), (26, 50), (21, 41)], BELLY)
    s.poly([(38, 32), (43, 32), (41, 41), (45, 46), (40, 50), (35, 41)], BELLY)
    # 背部双氧罐 + 排气阀
    s.rect(31, 7, 5.5, 10, BELLY)
    s.rect(38.5, 9, 5.5, 8, BELLY)
    s.rect(30.5, 5.5, 6.5, 2.5, GAP)
    s.line(41.5, 9, 44, 5, GAP, 1.5)
    s.circle(44.3, 4.5, 1.2, RED, 0.9)
    # 主舱体（圆钝耐压壳）
    s.poly([(8, 14), (30, 12), (42, 16), (46, 24), (42, 33), (10, 33), (5, 26), (5, 19)], BODY)
    s.poly([(8, 14), (30, 12), (42, 16), (43.5, 19), (9.5, 17)], LIGHT)
    # 头部圆舷窗 + 独眼（节点位）
    s.circle(15.5, 18.3, 6.6, GAP)
    s.rect(9.5, 14.5, 12, 7.5, GAP)
    s.circle(15.5, 18.3, 5.3, RED, 0.22)
    s.circle(15.5, 18.3, 2.4, RED, 0.95)
    # 腹部龙骨
    s.rect(10, 31.5, 34, 1.5, GAP, 0.8)
    s.poly([(10, 33), (42, 33), (38, 37), (14, 37)], BELLY)
    # 侧舷珊瑚灯位
    for i, hx in enumerate(range(24, 42, 6)):
        s.rect(hx, 26, 2.5, 3, CORAL_LAMP if i % 2 == 0 else GAP, 0.85)
    # 近侧足对（逆关节，踏地）
    s.poly([(11, 33), (16, 33), (15, 41), (19, 46), (14, 50), (8, 42)], BODY)
    s.poly([(30, 33), (35, 33), (35, 42), (39, 46), (34, 50), (29, 42)], BODY)
    # 足垫
    s.rect(12, 48.5, 9, 1.8, BELLY)
    s.rect(30, 48.5, 9, 1.8, BELLY)
    # 肩 joint（枪臂挂点）
    s.circle(16, 24, 3.5, GAP)
    return s


def walker_arm():
    """步行者枪臂换皮 48x28：鱼雷管长炮（收口环管 + 下挂瓶，与三章细长管拉开）。
    肩 joint (36,8)、枪口尖端 ~(2,15)（Muzzle=臂画布 (6,15) 落在膛口座内）。"""
    s = Svg(48, 28)
    s.circle(36, 8, 3.5, BELLY)
    s.rect(33, 8, 6, 10, BELLY)
    s.rect(17, 10, 19, 9, BODY)          # 机匣
    s.rect(17, 10, 19, 2.5, LIGHT)
    s.rect(5, 12.2, 13, 4, GAP)          # 长管
    s.rect(10, 11.4, 2.2, 5.6, BODY)     # 收口环
    s.rect(1, 11, 6, 7, BODY)            # 膛口座
    s.rect(1, 13.6, 2.2, 2.8, GAP)       # 膛口
    s.rect(21, 19, 10, 4, BELLY)         # 下挂瓶
    s.circle(31.5, 21, 2, BELLY)
    s.circle(33, 13.5, 1.3, CORAL_LAMP, 0.9)
    return s


def drone_body():
    """无人机换皮「伞灯浮游机」38x42（悬浮）。
    侧视语义：钟形伞体朝上，伞缘垂两根缆（端珠），中央吊舱=实体质量；
    顶部小灯穗。骨架：眼 (12,14.4)=halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。"""
    s = Svg(38, 42)
    # 顶部灯穗
    s.line(20, 5.5, 20, 3.2, GAP, 1.2)
    s.circle(20, 2.8, 1.2, CORAL_LAMP, 0.9)
    # 钟形伞体
    s.poly([(6, 16), (10, 8), (20, 5), (30, 8), (34, 16), (30, 19), (8, 19)], BODY)
    s.poly([(10, 8), (20, 5), (30, 8), (28, 10.5), (12, 10.5)], LIGHT, 0.8)
    s.poly([(6, 16), (34, 16), (33, 19), (7, 19)], BELLY)
    # 伞缘垂缆 ×2（端珠）
    s.line(11, 19, 9, 35, GAP, 1.5, 0.9)
    s.line(26, 19, 28, 36, GAP, 1.5, 0.9)
    s.circle(9, 36, 1.6, GAP)
    s.circle(28, 37, 1.6, GAP)
    # 中央吊舱（实体质量）
    s.poly([(9, 19), (29, 19), (32, 24), (28, 31), (10, 31), (6, 24)], BODY)
    s.poly([(9, 19), (29, 19), (30, 21), (10, 21)], LIGHT, 0.8)
    s.poly([(11, 28), (27, 28), (25, 31), (13, 31)], BELLY)
    # 眼窝 + 独眼（节点位，钟前）
    s.rect(7.5, 11.5, 9, 6, GAP)
    s.circle(12, 14.4, 4.4, RED, 0.22)
    s.circle(12, 14.4, 2.0, RED, 0.95)
    # 检修珊瑚带
    s.rect(16, 22.5, 6, 2.5, CORAL_LAMP, 0.85)
    # 腹挂传感器球
    s.rect(18, 31, 2.5, 3, GAP)
    s.circle(19.2, 36, 3, BELLY)
    s.circle(19.2, 36, 1.2, CORAL_LAMP, 0.9)
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
    s.circle(25, 10.5, 1.0, CORAL_LAMP, 0.9)
    return s


def shield_body():
    """盾卫换皮「蜂巢堡盾」56x52，地面 y=50。
    比例账：通高塔盾 4..25 x 10..47（占前 40% 全高，盾面蜂窝穴+一道珊瑚发光缝）；
    后置舱体 25..49 x 10..42；双足踏地。
    骨架：眼 (23.5,18.3)=halo r5.3/core r2.4（盾/舱交界窝）；
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
    # 塔盾（通高，前缘受光 + 蜂窝穴 + 珊瑚发光缝）
    s.poly([(5, 10), (22, 10), (25, 14), (25, 44), (21, 47), (7, 47), (4, 42), (4, 14)], BODY)
    s.poly([(4, 14), (7, 11.5), (7, 45), (4, 40)], LIGHT, 0.6)
    s.poly([(9, 17), (14, 17), (15.5, 20), (14, 23), (9, 23), (7.5, 20)], GAP)
    s.poly([(9, 27), (14, 27), (15.5, 30), (14, 33), (9, 33), (7.5, 30)], GAP)
    s.poly([(17, 22), (21, 22), (22, 25), (21, 28), (17, 28), (15.5, 25)], GAP)
    s.line(11, 35, 13, 46, CORAL, 1.4, 0.75)   # 盾面珊瑚发光缝
    s.circle(13, 46, 1.2, CORAL_CORE, 0.9)
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
    """精英换皮「磁悬浮雷舱车」60x80，地面 y=80。
    比例账（功能反推）：弹径 5.6 → 仓口宽 9 → 斜甲双肩井盖 x 34..43/45..54
    （=pivot±5.5）；前置眼塔 8..32；悬浮裙替代履带（裙底辉光缝，无接地垫）。
    骨架：眼 (19,26.5)=halo r5.3/core r2.4；两仓口 (38.5,1.5)/(49.5,1.5)。"""
    s = Svg(60, 80)
    # 天线 + 警灯
    s.line(28, 22, 31, 12, GAP, 1.5)
    s.circle(31.3, 11.5, 1.3, RED, 0.9)
    # 垂发井基座 + 斜甲
    s.rect(32, 4, 26, 10, BODY)
    s.rect(32, 4, 26, 2, LIGHT)
    s.rect(34, 0, 9, 6, GAP)             # 井盖 A（Muzzle 38.5,1.5）
    s.rect(45, 0, 9, 6, GAP)             # 井盖 B（Muzzle 49.5,1.5）
    s.rect(33, 5.5, 11, 1.5, LIGHT, 0.6)
    s.rect(44.5, 5.5, 11, 1.5, LIGHT, 0.6)
    s.poly([(30, 14), (60, 14), (58, 20), (32, 20)], BELLY)   # 斜肩整流
    # 回旋座
    s.rect(30, 20, 28, 5, BELLY)
    # 连接甲板（眼塔与尾舱之间）
    s.rect(30, 25, 28, 19, BODY)
    s.rect(30, 25, 28, 2.5, LIGHT, 0.7)
    for vy in (32, 38):                  # 甲板肋
        s.rect(34, vy, 20, 1.5, GAP, 0.6)
    # 车体（低滑翔舰体）
    s.poly([(4, 44), (58, 44), (60, 52), (58, 62), (48, 68), (14, 68), (4, 60)], BODY)
    s.poly([(4, 44), (58, 44), (57.5, 46.5), (4.5, 46.5)], LIGHT, 0.7)
    # 驾驶眼塔 + 眼
    s.poly([(8, 22), (30, 22), (32, 28), (32, 44), (8, 44)], BODY)
    s.rect(8, 22, 22, 3, LIGHT)
    s.rect(12, 23, 14, 7, GAP)
    s.circle(19, 26.5, 5.3, RED, 0.22)
    s.circle(19, 26.5, 2.4, RED, 0.95)
    s.rect(10, 33, 20, 4, GAP)
    # 前部声呐锥
    s.poly([(2, 56), (8, 50), (10, 50), (10, 66), (4, 66), (0, 60)], BELLY)
    s.line(0, 60, 4, 66, LIGHT, 2, 0.7)
    # 危险黄警示带
    for i, hx in enumerate(range(18, 52, 5)):
        s.rect(hx, 56, 2.5, 3.5, YELLOW if i % 2 == 0 else GAP, 0.8)
    # 悬浮裙（无履带；底部珊瑚辉光缝=磁浮语义）
    s.poly([(6, 64), (54, 64), (56, 72), (48, 76), (12, 76), (4, 72)], BELLY)
    for tx in range(12, 48, 7):          # 裙面通风口
        s.rect(tx, 66, 2, 7, GAP, 0.85)
    s.glow_ellipse(30, 77, 26, 4, CORAL_LAMP, 0.25)
    s.rect(10, 75.5, 40, 2, CORAL_LAMP, 0.85)
    return s


# ============================================================
# BOSS 深海猎杀舰「鮟鱇」（300x180，整体重设计：楔形舰体 + 艏部诱饵灯桅
# + 背脊垂发 + 尾部涵道推桨 + 侧置五叶姿态风扇）
# ============================================================
def boss_body():
    s = Svg(300, 180)
    # ---- 尾鳍（先画，被舰体压住）----
    s.poly([(246, 28), (272, 2), (292, 4), (284, 36)], BODY)        # 上垂尾
    s.poly([(272, 2), (292, 4), (290, 10), (275, 9)], LIGHT)
    s.poly([(248, 116), (270, 142), (290, 140), (282, 112)], BELLY)  # 下垂尾
    # ---- 龙骨 + 悬浮辉光（先画，被主舰体压住上缘）----
    s.poly([(40, 112), (240, 108), (232, 134), (60, 134)], BELLY)
    s.glow_ellipse(140, 138, 110, 9, CORAL_LAMP, 0.28)
    s.rect(70, 131, 150, 2.5, CORAL_LAMP, 0.7)
    # ---- 主舰体（楔形猎杀舰，艏左）----
    s.poly([(6, 64), (40, 44), (240, 40), (288, 56), (292, 84), (260, 108), (60, 112), (20, 96)], BODY)
    s.poly([(40, 44), (240, 40), (286, 55), (284, 59), (239, 44), (42, 48)], LIGHT, 0.7)
    # 板缝
    s.rect(110, 44, 2.5, 64, GAP, 0.35)
    s.rect(190, 42, 2.5, 66, GAP, 0.35)
    s.rect(70, 88, 180, 2.5, GAP, 0.3)
    # 舷窗带（暗窗为主，两粒珊瑚亮窗）
    for wi, wx in enumerate(range(90, 230, 18)):
        if wi in (3, 7):
            s.rect(wx, 70, 8, 7, CORAL_LAMP, 0.85)
        else:
            s.rect(wx, 70, 8, 7, GAP, 0.9)
    # 艇鼻帽
    s.poly([(2, 66), (20, 58), (20, 90), (2, 80)], BELLY)
    # ---- 背脊垂发甲板（4 仓口=BOSS_RAIN_COUNT 1:1，仓口画布 x 83/105/167/189 @ y26）----
    s.poly([(66, 32), (214, 32), (210, 46), (70, 46)], BODY)        # 甲板基座
    s.poly([(60, 34), (74, 18), (198, 18), (212, 34)], BODY)
    s.poly([(74, 18), (198, 18), (196, 22), (76, 22)], LIGHT)
    for mx in (83, 105, 167, 189):                 # 仓口深缝
        s.rect(mx - 5, 23.5, 10, 5, GAP)
        s.rect(mx - 7, 29, 14, 2, LIGHT, 0.6)
    for i, hx in enumerate(range(64, 200, 12)):    # 甲板前缘警示
        s.rect(hx, 34, 6, 4, YELLOW if i % 2 == 0 else GAP, 0.6)
    s.rect(120, 38, 28, 3, RED, 0.75)
    # ---- 艏部诱饵灯桅（鮟鱇钓灯，本章签名光）----
    s.poly([(32, 46), (36, 46), (31, 22), (28, 22)], BODY)          # 桅杆
    s.line(28, 22, 20, 18, BODY, 2.5)                               # 灯臂
    s.glow_ellipse(18, 16, 12, 12, CORAL, 0.5)
    s.circle(18, 16, 5, CORAL, 0.95)
    s.circle(18, 16, 2.2, "#ffd9a0", 0.95)
    # ---- 独眼条带（眼条 y60..66 含 (55,63)，骑在艇鼻）----
    s.rect(38, 57, 34, 12, RED, 0.18)
    s.rect(42, 60, 26, 6, RED, 0.95)
    # ---- 尾部涵道推桨座（桨 bar 独件在画布 (272,64)）----
    s.poly([(252, 44), (296, 44), (298, 84), (254, 84)], BODY)
    s.rect(252, 44, 46, 4, LIGHT)
    s.circle(272, 64, 17, "#141a30", 0.9)          # 涵道口
    # 侧风扇座（风扇独件画布 (272,112)）
    s.rect(262, 96, 20, 12, BELLY)
    return s


def boss_gun():
    """BOSS 机枪臂换皮 110x32（flip_v 后挂艇鼻下颌，枪带画布 y85..117）。
    枪口轴线画布顶 y0..8，枪口尖端画布 (2,~4)=Muzzle。
    造型：转膛炮（单管+散热环+尾部转膛鼓，与三章单管重炮拉开）。"""
    s = Svg(110, 32)
    s.rect(8, 1, 48, 6, BODY)            # 单管
    s.rect(16, 0, 4, 8, GAP)             # 散热环
    s.rect(26, 0, 4, 8, GAP)
    s.rect(36, 0, 4, 8, GAP)
    s.rect(0, 0, 9, 8, BODY)             # 膛口座
    s.rect(0, 2.5, 3, 3, GAP)            # 膛口
    s.circle(64, 12, 11, BODY)           # 转膛鼓
    s.circle(64, 12, 6.5, GAP)
    s.circle(64, 12, 2, RED, 0.8)
    s.rect(74, 2, 26, 20, BODY)          # 尾机匣
    s.rect(74, 2, 26, 4, LIGHT)
    s.rect(66, 24, 18, 6, BELLY)         # 弹链盒
    s.rect(96, 6, 12, 12, GAP)           # 后座筒
    s.rect(92, 9, 5, 3, GAP, 0.9)
    s.rect(92, 15, 5, 3, GAP, 0.9)
    return s


def boss_rotor():
    """BOSS 尾推螺旋桨 blade bar 84x16（侧视刃边，画布心=节点心）。
    节点位：boss_ch4.tscn Rotor=(122,-26) → 艇体画布 (272,64)（尾部涵道内），
    bar 覆盖 x230..314（桨尖越出涵道/画布右缘=推桨在尾鳍之后，正常出画）。"""
    s = Svg(84, 16)
    s.rect(2, 6, 80, 4, GAP)             # 桨叶刃条
    s.rect(4, 6, 12, 4, LIGHT, 0.8)      # 桨尖反光
    s.rect(68, 6, 12, 4, LIGHT, 0.6)
    s.rect(20, 6.8, 2, 2.4, BELLY, 0.7)  # 叶间分隔刻
    s.rect(50, 6.8, 2, 2.4, BELLY, 0.7)
    s.rect(38, 3, 8, 10, BODY)           # 桨毂
    s.rect(40.5, 6, 3, 4, GAP)
    return s


def boss_tailrotor():
    """BOSS 侧置姿态风扇 56x56（整周旋转，画布心=节点 (272,112)，挂尾部下浮筒）。
    侧视语义：风扇盘平行屏幕→正圆成立；五叶 0/72/144/216/288（绕 28,28 手工预算，
    内缘 r6 外缘 r19 叶宽半 3.0），毂 BELLY + 红心。"""
    s = Svg(56, 56)

    def blade(deg):
        a = math.radians(deg)
        dx, dy = math.cos(a), math.sin(a)
        px, py = -dy, dx
        inner = (28 + 6 * dx, 28 + 6 * dy)
        outer = (28 + 19 * dx, 28 + 19 * dy)
        return [(inner[0] + 3.0 * px, inner[1] + 3.0 * py),
                (inner[0] - 3.0 * px, inner[1] - 3.0 * py),
                (outer[0] - 3.0 * px, outer[1] - 3.0 * py),
                (outer[0] + 3.0 * px, outer[1] + 3.0 * py)]

    for deg in (0, 72, 144, 216, 288):
        s.poly(blade(deg), LIGHT)
    s.circle(28, 28, 6, BELLY)
    s.circle(28, 28, 2.5, RED, 0.9)
    return s


if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)
    save(far_strip(), "env_coral_far.svg", """第四章「珊瑚辐合夜」远景条 1024x1300（HillsStrip，tile 1024 视差 0.9）。
靛蓝夜空 #090d22→#273052 + 星点 + 塔群剪影 #0d1330 稀疏珊瑚窗 +
地平线辉光 + 余烬 + 雾带。碎环巨构在独立层 env_coral_ring（tile 1024 里画
唯一地标=同屏 2~3 份穿帮，已迁出）。
两侧 24px 留空=平铺接缝纯天空；画布底 1300=世界 730。种子 4041。""")
    save(ring_strip(), "env_coral_ring.svg", """第四章碎环巨构独层 3200x640 透明底（RingStrip，tile 3200 视差 0.9，
tile 3200 > 视口 2400 → 同屏最多一份，消除平铺重复）。
主环心画布 (1600,320) r240 + 环周散星。**tex 落位=回绕不弹切带
[1200+半宽, 3200−1200−半宽] 取 1600**（二轮教训：tex 2400 在回绕瞬间
环还剩右侧 1/3 在屏，直接弹切消失）。
tscn 摆位：position(8,270)、region 6400x640（=视口+tile 覆盖账）、
层级在 HillsStrip 之后（远条不透明）、MidStrip 之前。
开机环在右屏外，起跑约 1s 从右缘滑入；屏上约 39s / 空档约 14s。种子 4044。""")
    save(mid_strip(), "env_coral_mid.svg", """第四章中景条 2048x520 透明底（MidStrip，tile 2048）。
三段各异：A 半埋输送管廊（双管+法兰+泄压阀塔，断口珊瑚渗光）/
B 采掘井架（天车轮+警灯）+出渣管排 / C 半埋堡坎（射击窗珊瑚微光）+天线阵。
剪影 #0a0e22 族 + 冷天光边 #4a5890 + 信号红。两侧 40px 留空。
画布底=世界 700。种子 4042。""")
    save(ground_top(), "env_coral_ground_top.svg", """第四章地块表面带 256x56（terrain.gd 平铺，256 相位对齐）。
玄武岩：顶缘冷天光 3px + 层理横带 + 磨损标线 + 暗斑 + 珊瑚地裂
（暗缝芯+珊瑚光边+白热端点）+ 余烬点；底缘压暗 5px；花纹距边 >=6px。种子 4043。""")
    save(ground_fill(), "env_coral_ground_fill.svg", """第四章地块填充 16x256 竖向渐变（岩床向深处压暗，保HUD底衬可读）。""")
    save(ground_strip(), "env_coral_ground.svg", """第四章兜底地面条 256x480（GroundStrip，位于世界 664..1144）：
表面带内容同 ground_top + 深处渐变。""")
    save(deck(), "env_coral_deck.svg", """第四章栈桥桥面 720x26（scaffold_ch4 换装）：
顶缘冷天光 + 夜航钢板（格栅纹）+ 珊瑚位标灯 + 桁架腹杆。
桥墩用色走 obstacle.pier_color（章配 #384266）。""")
    save(walker_body(), "enemy_coral_walker_body.svg", """第四章步行者「潜航重步机」56x52，地面 y=50。
骨架对齐：眼 (15.5,18.3) halo r5.3/core r2.4；肩 joint (16,24) r3.5。
造型：圆钝耐压壳舱体 + 头部圆舷窗 + 背部双氧罐 + 逆关节双足（远对 BELLY/近对 BODY）。
前缘 x<6 留空给枪臂。色板：LIGHT #9fb0d8 / BODY #5d6d94 / BELLY #3f4c6e /
GAP #262f4a（暗场章敌营转亮钢蓝）+ 红/黄/珊瑚灯。""")
    save(walker_arm(), "enemy_coral_walker_arm.svg", """第四章步行者枪臂 48x28：鱼雷管长炮（收口环管+下挂瓶）。
肩 joint (36,8)、枪口尖端 ~(2,15)（Muzzle=臂画布 (6,15)）。""")
    save(drone_body(), "enemy_coral_drone.svg", """第四章无人机「伞灯浮游机」38x42（悬浮）。
骨架对齐：眼 (12,14.4) halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。
造型：钟形伞体+顶部灯穗+伞缘垂缆×2（端珠）+中央吊舱+腹挂传感器球。""")
    save(drone_arm(), "enemy_coral_drone_arm.svg", """第四章无人机枪臂 32x16。肩 joint (28,8)、枪口尖端 ~(12,9.5)（Muzzle=臂画布 (13,11)）。""")
    save(shield_body(), "enemy_coral_shield_body.svg", """第四章盾卫「蜂巢堡盾」56x52，地面 y=50。
骨架对齐：眼 (23.5,18.3) halo r5.3/core r2.4（盾/舱交界窝）；肩 joint (24,24)（复用本章枪臂）。
造型：通高塔盾（前缘受光+蜂窝穴+盾面珊瑚发光缝）+ 后置舱体 + 双足 + 滑鞋。""")
    save(elite_body(), "enemy_coral_elite_body.svg", """第四章精英「磁悬浮雷舱车」60x80，地面 y=80。
骨架对齐：眼 (19,26.5)；两仓口 (38.5,1.5)/(49.5,1.5)=ArmPivot(44,1.5)±5.5；
造型：垂发斜甲双肩井 + 驾驶眼塔 + 悬浮裙（底部珊瑚辉光缝，无履带）+ 前部声呐锥。""")
    save(boss_body(), "boss_coral_body.svg", """第四章 BOSS 深海猎杀舰「鮟鱇」300x180=碰撞体 body_size，原点(150,90)，原生朝左。
整体重设计：楔形舰体（板缝+舷窗带+艇鼻帽）/ 背脊垂发甲板（4 仓口画布
x 83/105/167/189 @ y26 = boss.gd MissilePorts 1:1）/ 艏部诱饵灯桅（珊瑚钓灯，
本章签名光）/ 龙骨悬浮辉光 / 尾鳍×2 + 尾部涵道推桨座（bar 独件画布 (272,64)）+
侧风扇座（五叶圆扇独件画布 (272,112)）。
独眼条带 y60..66 含 (55,63)，EyeGlow 节点 (-95,-27) scale1.2 照摆；
机枪臂独件 pivot(-51,15) 枪带画布 y85..117（flip_v 贴艇鼻下颌）。""")
    save(boss_gun(), "boss_coral_gun.svg", """第四章 BOSS 机枪臂 110x32（tscn flip_v=true、offset(-95,-20)）。
枪口轴线画布顶 y0..8，枪口尖端 (2,~4)=Muzzle(-93,8)。转膛炮：单管+散热环+转膛鼓+后座筒。""")
    save(boss_rotor(), "boss_coral_rotor.svg", """第四章 BOSS 尾推螺旋桨 blade bar 84x16。
节点位（boss_ch4.tscn）Rotor=(122,-26) → 艇体画布 (272,64)（尾部涵道内）；
桨尖越出涵道=推桨在尾鳍之后（正常出画，同章1旋翼 overshoot 语言）。""")
    save(boss_tailrotor(), "boss_coral_tailrotor.svg", """第四章 BOSS 侧置姿态风扇 56x56（整周旋转，画布心=节点 (272,112)）。
风扇盘平行屏幕→正圆成立；五叶 0/72/144/216/288（绕 28,28 预算）+ 毂 + 红心。""")
    print("coral chapter assets baked.")
