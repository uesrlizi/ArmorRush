# -*- coding: utf-8 -*-
"""第十章「硫焰地热田」单位/危险件烘焙：井口封堵与井场管线能力套件。

产物（art_proposals/sulfur_ch10/units/）：
  enemy_sulfur_walker_body.svg  56x52   步行者换皮「井场巡检」
  enemy_sulfur_walker_arm.svg   48x28   步行者枪臂
  enemy_sulfur_drone.svg        38x42   无人机换皮「烟道飞眼」
  enemy_sulfur_drone_arm.svg    32x16   无人机枪臂
  enemy_sulfur_shield_body.svg  56x52   盾卫换皮「防喷闸盾卫」
  enemy_sulfur_elite_body.svg   60x80   精英「窜井」井口封堵车
  enemy_sulfur_elite_arm.svg    34x44   精英钻机架（固定射角不俯仰，钻杆朝 -Y）
  boss_sulfur_body.svg          300x180 BOSS「井口」井场管线母舰
  boss_sulfur_arm.svg           96x44   BOSS 井架吊杆（俯仰件，无发光口，不出弹）
  fx_sulfur_vent.svg            80x28   硫焰井口底座，锚点=底部接地点 (40,26)
  fx_sulfur_vent_glow.svg       64x20   亮井层（口内蓝焰渐急，代码驱动 alpha），锚点 (32,18)
  fx_sulfur_vent_flame.svg      72x224  井口焰柱 H=220，锚点=底部接地点 (36,222)
  fx_sulfur_drill.svg           32x16   钻头弹（+X=飞行方向），锚点中心 (16,8)
  fx_sulfur_flare_puff.svg      48x48   普攻蓝白焰团，锚点中心 (24,24)
  fx_sulfur_gas_shell.svg       24x24   硫气弹（青灰白汽团+蓝火星，无伤弹药读法），锚点中心 (12,12)
  fx_sulfur_cloud.svg           200x84  硫云爆燃带段（硫黄烟墙），画布 y0..84 ↔ 世界 y428..512，锚点左上 (0,0)
  fx_sulfur_cloud_front.svg     40x84   硫云锋线（蓝焰，唯一蓝色件），锚点 (20,42)

参照系=威胁设计_ch10.md §0（唯一口径，世界 y 朝下）。危险件：节点 origin=接地点，
节点局部=(canvas-anchor)*scale：
  井口底座 接地 (40,26)；口宽 64（画布 x8..72）。
  焰柱 接地 (36,222)，焰顶 (36,2)=局部 (0,-220)；焰体宽 64（画布 x4..68）。
  亮井层 接地 (32,18)，口内光带 y8..18。

单位锚点（与第九章既有单位逐像素同位，worlds.md §3 锚点钉死）：
  步行者：眼 (15.5,18.3) halo r5.3/core r2.4；肩 joint (16,24)；地面 y=50。
  枪臂：肩 joint (36,8)、Muzzle 臂画布 (6,15)。
  无人机：眼 (12,14.4) halo r4.4/core r2.0；ArmPivot (15.2,21)；臂 joint (28,8)、Muzzle (13,11)。
  盾卫：眼 (23.5,18.3)；肩 joint (24,24)。
  精英：眼 (19,26.5)；ArmPivot 画布 (44,12)→局部 (14,-28)；臂 34x44 枢端 (17,40)，
        钻杆口画布 (17,6)=DrillPort=Muzzle 臂局部 (0,-34)（ThreatFlash 挂此）。地面 y=80。
  BOSS（原点画布 (150,90)，局部=画布-(150,90)；hover 370 船底 460）：
        独眼条带 y60..66 含 (55,63)（EyeGlow (-95,-27) 沿用）；
        NozzlePort 艏部井口喷嘴 画布 (4,144)→局部 (-146,54)→世界 y=424；
        DrillPort 腹舱钻杆井口 画布 (150,168)→局部 (0,78)；
        VentPort 艉部排烟囱口 画布 (246,46)→局部 (96,-44)；
        ArmPivot 画布 (150,26)→局部 (0,-64)；臂=井架吊杆 96x44 枢端 (78,22)，吊钩座 (10,22)=Muzzle 臂局部 (-68,0)（无发光口，不出弹）；
        举升喷口 (110,156)/(210,156)=非出手件（无光晕扁椭圆）；全机蓝色发光只在 Nozzle/Drill/Vent。
色板（提案_ch10 §4 墨酒红族）：LIGHT #6a4456 / BODY #4a2a3a / BELLY #321c28 /
  GAP #20121a / 独眼 #ff4640 / 点缀硫焰蓝 #48b4ff（浅芯 #c8ecff，暗焰边 #1e4a66）；
  硫黄壳 #c8b048 只做低不透明小斑。
ThorVG 硬约束：无 filter/pattern/use/text/transform；无 rect+rotate。
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))
from generate_proposals import Svg, f, glow_dot  # noqa: E402

OUT = os.path.join(HERE, "units")

LIGHT = "#6a4456"
BODY = "#4a2a3a"
BELLY = "#321c28"
GAP = "#20121a"
VOID = "#120a10"
RED = "#ff4640"
BLUE = "#48b4ff"
BLUE_CORE = "#c8ecff"
BLUE_DK = "#1e4a66"
SULFUR = "#c8b048"
STEEL = "#7a6a72"       # 阀门/法兰金属（敌营族内中明度）
SMOKE = "#d8d4b4"
CLOUD = "#5a4a18"       # 硫云烟墙主色（硫褐，R14 压暗）
CLOUD_EDGE = "#d8c040"  # 带界亮边
CLOUD_LT = "#6e5c22"
CLOUD_DK = "#463a12"
GAS = "#b8c4c0"


def save(s, name, comment=""):
    head = f"<!-- {comment.strip()} -->\n" if comment else ""
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(s.w)} {f(s.h)}" '
           f'width="{f(s.w)}" height="{f(s.h)}">\n{head}<defs>\n' + "\n".join(s.defs)
           + "\n</defs>\n" + "\n".join(s.body) + "\n</svg>\n")
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as fp:
        fp.write(svg)
    print(name)


def valve(s, cx, cy, r=2.6):
    """手轮阀（井场语汇）：轮缘+轮毂。"""
    s.circle(cx, cy, r, STEEL)
    s.circle(cx, cy, r - 1.1, BELLY)
    s.circle(cx, cy, 0.9, STEEL)


def pilot(s, x, y, r=1.4):
    """硫焰蓝引火灯（实心块+同形 0.18 光晕）。"""
    s.circle(x, y, r * 2.6, BLUE, 0.18)
    s.circle(x, y, r, BLUE, 0.95)


def sulfur_fleck(s, pts):
    for (x, y, rx, ry) in pts:
        s.ellipse(x, y, rx, ry, SULFUR, 0.4)


# ---------------- 杂兵 ----------------
def walker_body():
    s = Svg(56, 52)
    s.poly([(24, 32), (29, 32), (27, 41), (31, 46), (26, 50), (21, 41)], BELLY)
    s.poly([(38, 32), (43, 32), (41, 41), (45, 46), (40, 50), (35, 41)], BELLY)
    # 背负气瓶 + 取样管（井场巡检读法）
    s.rect(32, 5, 6, 12, BELLY)
    s.rect(39.5, 7, 5, 10, BELLY)
    s.rect(31.5, 3.5, 7, 2.5, STEEL)
    valve(s, 42, 6, 2.2)
    s.poly([(8, 14), (30, 12), (42, 16), (46, 24), (42, 33), (10, 33), (5, 26), (5, 19)], BODY)
    s.poly([(8, 14), (30, 12), (42, 16), (43.5, 19), (9.5, 17)], LIGHT)
    # 背顶引火灯杆
    s.line(27, 13, 27, 4.5, GAP, 1.6)
    pilot(s, 27, 3.6, 1.3)
    s.circle(15.5, 18.3, 6.6, GAP)
    s.rect(9.5, 14.5, 12, 7.5, GAP)
    s.circle(15.5, 18.3, 5.3, RED, 0.22)
    s.circle(15.5, 18.3, 2.4, RED, 0.95)
    s.rect(10, 31.5, 34, 1.5, GAP, 0.8)
    s.poly([(10, 33), (42, 33), (38, 37), (14, 37)], BELLY)
    # 侧舷蓝警示杠
    for i, hx in enumerate(range(24, 42, 6)):
        s.rect(hx, 26, 2.5, 3, BLUE if i % 2 == 0 else GAP, 0.8)
    sulfur_fleck(s, [(34, 22, 3, 1.2), (24, 20, 2.4, 1.0)])
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
    for rx_ in (8.5, 13):                   # 管身法兰（管线读法）
        s.rect(rx_, 11, 2.2, 6.4, STEEL)
    s.rect(1, 11, 6, 7, BODY)
    s.rect(1, 13.6, 2.2, 2.8, GAP)
    s.rect(21, 19, 10, 4, BELLY)
    s.circle(33, 13.5, 1.3, BLUE, 0.9)
    return s


def drone_body():
    s = Svg(38, 42)
    s.line(20, 5.5, 20, 2.5, GAP, 1.2)
    pilot(s, 20, 2.4, 1.2)
    s.ellipse(20, 12, 15, 7, BODY)
    s.ellipse(20, 10.5, 13, 4.5, LIGHT, 0.85)
    s.ellipse(20, 14, 15, 3, BELLY)
    for ax in (8, 32):                      # 盘缘短排烟管
        s.rect(ax - 1.5, 15, 3, 5, GAP)
        s.ellipse(ax, 20.5, 2.6, 1.2, BLUE, 0.55)
    s.poly([(9, 19), (29, 19), (32, 24), (28, 31), (10, 31), (6, 24)], BODY)
    s.poly([(9, 19), (29, 19), (30, 21), (10, 21)], LIGHT, 0.8)
    s.poly([(11, 28), (27, 28), (25, 31), (13, 31)], BELLY)
    s.rect(7.5, 11.5, 9, 6, GAP)
    s.circle(12, 14.4, 4.4, RED, 0.22)
    s.circle(12, 14.4, 2.0, RED, 0.95)
    # 腹挂气体取样罐
    s.rect(18.5, 31, 2.5, 3, GAP)
    s.rect(15, 33.5, 9.5, 6.5, BELLY, rx=2.5)
    s.rect(16, 34.5, 2, 4.5, STEEL, 0.8)
    s.rect(15, 22.5, 8, 2.2, BLUE, 0.75)
    return s


def drone_arm():
    s = Svg(32, 16)
    s.circle(28, 8, 2.5, BELLY)
    s.rect(18, 6.5, 10, 5.5, BODY)
    s.rect(18, 6.5, 10, 2, LIGHT)
    s.rect(13.5, 8, 5, 3, GAP)
    s.rect(11, 7.5, 3, 4.5, BODY)
    s.circle(11.8, 9.5, 1.0, GAP)
    s.circle(25, 10.5, 1.0, BLUE, 0.9)
    return s


def shield_body():
    s = Svg(56, 52)
    s.poly([(12, 42), (18, 42), (16, 50), (9, 50)], BELLY)
    s.rect(46, 18, 6, 15, BELLY)
    s.line(44, 11, 47, 3, GAP, 1.5)
    pilot(s, 47.3, 2.5, 1.2)
    s.poly([(25, 10), (45, 10), (49, 18), (49, 36), (42, 42), (28, 42), (25, 38)], BODY)
    s.poly([(25, 10), (45, 10), (46.5, 13.5), (26.5, 13.5)], LIGHT)
    s.rect(31, 17, 11, 3.5, GAP)
    # 塔盾=防喷闸板：厚闸板 + 横向闸杆 + 两枚手轮
    s.poly([(5, 10), (22, 10), (25, 14), (25, 44), (21, 47), (7, 47), (4, 42), (4, 14)], BODY)
    s.poly([(4, 14), (7, 11.5), (7, 45), (4, 40)], LIGHT, 0.6)
    s.rect(7, 26, 16, 5, BELLY)
    s.rect(7, 26, 16, 1.4, LIGHT, 0.6)
    for sy in (16, 37):
        s.rect(7, sy, 15, 2, GAP, 0.8)
    valve(s, 11.5, 21, 2.8)
    valve(s, 11.5, 41, 2.8)
    s.rect(16, 32, 6, 2.2, BLUE, 0.8)
    sulfur_fleck(s, [(18, 20, 2.6, 1.1), (15, 44, 3, 1.0)])
    s.rect(6, 47, 13, 3, BELLY)
    s.rect(18, 14, 10, 8, GAP)
    s.circle(23.5, 18.3, 5.3, RED, 0.22)
    s.circle(23.5, 18.3, 2.4, RED, 0.95)
    s.circle(24, 24, 3.5, GAP)
    s.poly([(30, 42), (36, 42), (38, 49), (31, 49)], BODY)
    s.rect(29, 47.5, 11, 2.2, BELLY)
    s.rect(32, 34, 9, 2.5, BLUE, 0.75)
    return s


# ---------------- 精英「窜井」井口封堵车 ----------------
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
        s.rect(hx, 52, 2.5, 3.5, BLUE if i % 2 == 0 else GAP, 0.8)
    # 驾驶眼塔
    s.poly([(8, 22), (30, 22), (32, 28), (32, 42), (8, 42)], BODY)
    s.rect(8, 22, 22, 3, LIGHT)
    s.rect(12, 23, 14, 7, GAP)
    s.circle(19, 26.5, 5.3, RED, 0.22)
    s.circle(19, 26.5, 2.4, RED, 0.95)
    s.rect(10, 33, 20, 4, GAP)
    s.poly([(2, 50), (8, 46), (10, 46), (10, 60), (4, 60), (0, 56)], BELLY)
    # 钻机架基座（臂=独立件，塔环 (44,12)）：A 字支腿
    s.poly([(36, 44), (52, 44), (48, 16), (40, 16)], BODY)
    s.poly([(36, 44), (39, 44), (41.5, 16), (40, 16)], LIGHT, 0.6)
    s.rect(39, 14, 10, 2.5, LIGHT)
    s.circle(44, 12, 4.5, GAP)
    s.circle(44, 12, 2.2, BELLY)
    # 车载备用井口（能力签名件：采油树 + 两枚手轮 + 蓝引火）
    s.rect(24, 36, 6, 6, BELLY)
    s.rect(22.5, 34, 9, 2.5, STEEL)
    s.rect(25, 28, 4, 6, BELLY)
    valve(s, 21.5, 31, 2.4)
    valve(s, 32.5, 31, 2.4)
    s.rect(23.5, 26, 7, 2.2, STEEL)
    pilot(s, 27, 24.6, 1.2)
    # 尾部钻头弹药架（三枚钻头尖朝上）
    s.rect(52, 30, 5, 14, BELLY)
    for i, by in enumerate((32, 36, 40)):
        s.poly([(53, by + 2), (56, by + 2), (54.5, by - 0.5)], STEEL)
    sulfur_fleck(s, [(14, 48, 3.2, 1.2), (46, 56, 3.6, 1.1)])
    return s


def elite_arm():
    """钻机架 34x44（固定射角，钻杆朝 -Y）。枢端 (17,40)，钻杆口 (17,6)=DrillPort=Muzzle 臂局部 (0,-34)。"""
    s = Svg(34, 44)
    s.rect(10, 32, 14, 10, BELLY)
    s.circle(17, 40, 3.4, BELLY)
    # A 字井架两腿 + 横撑
    s.poly([(9, 34), (12.5, 34), (15, 8), (13.5, 8)], BODY)
    s.poly([(21.5, 34), (25, 34), (20.5, 8), (19, 8)], BODY)
    for gy in (16, 24):
        s.rect(12, gy, 10, 2, GAP)
    # 钻杆（中轴）+ 顶驱
    s.rect(15.6, 9, 2.8, 25, STEEL)
    s.rect(15.6, 9, 1, 25, LIGHT, 0.8)
    s.rect(11.5, 2.5, 11, 6, GAP)            # 架口夹持（口=6）
    s.rect(13.5, 4, 7, 3.5, VOID)
    s.poly([(15.4, 7.5), (18.6, 7.5), (17, 3.5)], STEEL)   # 露出的钻头尖
    s.circle(25.5, 28, 1.3, BLUE, 0.9)
    return s


# ---------------- BOSS「井口」井场管线母舰 ----------------
def boss_body():
    s = Svg(300, 180)
    # 船体：低宽井场平台
    s.poly([(8, 84), (36, 54), (140, 52), (238, 56), (286, 66), (294, 90),
            (288, 122), (244, 146), (186, 162), (118, 164), (64, 154), (22, 126)], BODY)
    s.poly([(36, 54), (140, 52), (238, 56), (282, 65), (278, 71), (236, 62),
            (140, 58), (42, 60)], LIGHT, 0.7)
    s.poly([(22, 126), (64, 154), (118, 164), (186, 162), (240, 146),
            (230, 138), (120, 152), (66, 140), (30, 118)], BELLY)
    s.rect(60, 92, 170, 2, GAP, 0.3)
    # 舷侧集输管线（三根横管 + 法兰，签名件：管线母舰）
    for py, col in ((104, BELLY), (114, GAP)):
        s.rect(40, py, 228, 6, col)
        s.rect(40, py, 228, 1.4, LIGHT, 0.45)
    for fx_ in range(56, 268, 34):
        s.rect(fx_, 102, 4, 19, STEEL, 0.85)
    valve(s, 128, 98, 4)
    valve(s, 196, 98, 4)
    # 中央井架（ArmPivot 枢座 (150,26) 坐在井架顶台；座裙底 54 埋进甲板）
    s.poly([(118, 54), (128, 54), (144, 20), (140, 20)], BELLY)
    s.poly([(182, 54), (172, 54), (156, 20), (160, 20)], BELLY)
    for gy, x0, x1 in ((44, 126, 174), (34, 132, 168)):
        s.rect(x0, gy, x1 - x0, 2.4, GAP)
    s.line(128, 52, 166, 22, GAP, 1.4, 0.7)
    s.line(172, 52, 134, 22, GAP, 1.4, 0.7)
    s.rect(136, 14, 28, 10, BODY)
    s.rect(138, 14, 24, 3, LIGHT, 0.7)
    s.circle(150, 26, 5, GAP)
    # 艉部排烟囱 VentPort (246,46)：烟囱 x236..256 自甲板 58 起到口 40
    s.rect(236, 40, 20, 20, BELLY)
    s.rect(236, 40, 20, 2.5, LIGHT, 0.7)
    s.rect(233, 38, 26, 4, GAP)
    s.rect(239, 42, 14, 6, VOID)
    s.ellipse(246, 45, 6, 2.4, BLUE, 0.6)
    s.ellipse(246, 45, 3, 1.2, BLUE_CORE, 0.9)
    s.rect(258, 50, 6, 10, BELLY)          # 副烟囱
    # 腹舱钻杆井口 DrillPort (150,168)
    s.rect(130, 150, 40, 14, GAP)
    s.rect(130, 150, 40, 3, LIGHT, 0.5)
    s.rect(140, 158, 20, 12, BELLY)
    s.rect(144, 162, 12, 7, VOID)
    s.poly([(147, 164), (153, 164), (150, 170)], STEEL)      # 钻头尖露头
    valve(s, 135, 158, 2.6)
    valve(s, 165, 158, 2.6)
    pilot(s, 150, 146, 1.4)
    # 舷窗带 + 驾驶楼
    for wx in range(206, 262, 14):
        s.rect(wx, 78, 7, 6, "#e0c8d4", 0.65)
    s.poly([(80, 60), (106, 58), (104, 78), (82, 80)], GAP, 0.9)
    s.poly([(84, 62), (102, 60), (101, 66), (85, 67)], "#e0c8d4", 0.6)
    # 举升喷口位
    s.rect(98, 148, 24, 10, BELLY)
    s.rect(198, 142, 24, 10, BELLY)
    s.ellipse(110, 160, 10, 3, BLUE, 0.35)   # 举升喷口（非出手件，无光晕）
    s.ellipse(210, 154, 10, 3, BLUE, 0.35)
    # 艏部井口喷嘴 NozzlePort (4,144)：自艏下颌伸出的粗喷管 + 喇叭口
    s.poly([(22, 118), (40, 128), (20, 150), (12, 140)], BELLY)       # 管座
    s.line(30, 128, 14, 144, BODY, 9)
    s.line(30, 126, 15, 141, LIGHT, 2, 0.6)
    s.poly([(0, 134), (12, 136), (14, 152), (0, 154)], GAP)          # 喇叭口
    s.rect(11, 135, 3, 18, STEEL)
    s.circle(4, 144, 5.5, BLUE, 0.22)
    s.circle(4, 144, 3.2, BLUE, 0.9)
    s.circle(4, 144, 1.4, BLUE_CORE)
    # 艏锥 + 独眼条带（锚点 y60..66 含 (55,63)）
    s.poly([(0, 82), (14, 74), (20, 74), (20, 98), (6, 92)], BELLY)
    s.rect(38, 57, 34, 12, RED, 0.18)
    s.rect(42, 60, 26, 6, RED, 0.95)
    # 警示杠 + 硫黄结壳
    for i, hx in enumerate(range(88, 116, 7)):
        s.rect(hx, 128, 3, 4, STEEL if i % 2 == 0 else GAP, 0.8)
    sulfur_fleck(s, [(70, 140, 6, 1.8), (180, 150, 7, 1.8), (226, 66, 5, 1.4), (60, 74, 5, 1.4)])
    return s


def boss_arm():
    """井架吊杆 96x44（俯仰件，无发光口）。枢端 (78,22)，杆端吊钩座 (10,22)=Muzzle 臂局部 (-68,0)（仅占位，本章不从此出弹）。"""
    s = Svg(96, 44)
    s.rect(74, 12, 10, 20, BELLY)
    s.circle(78, 22, 4.4, BELLY)
    s.circle(78, 22, 2.0, LIGHT)
    # 桁架吊杆（上下弦 + 斜腹杆），杆端收窄
    s.poly([(14, 19), (76, 15), (76, 18), (14, 21)], BODY)
    s.poly([(14, 23), (76, 26), (76, 29), (14, 25)], BODY)
    s.poly([(14, 19), (76, 15), (76, 16), (14, 20)], LIGHT, 0.8)
    for i in range(6):
        x = 18 + i * 9.5
        s.line(x, 20, x + 9.5, 26.5, GAP, 1.6)
    # 杆端滑轮座 + 吊索 + 吊钩（暗金属，无光）
    s.circle(10, 22, 6, BELLY)
    s.circle(10, 22, 3.2, STEEL)
    s.circle(10, 22, 1.2, GAP)
    s.line(10, 28, 10, 36, GAP, 1.2)
    s.path("M 10 36 Q 13 41 8 41", stroke=STEEL, w=1.6)
    return s


# ---------------- 危险件 ----------------
def vent():
    """井口底座 80x28，接地 (40,26)；口宽 64（x8..72），口沿顶 y10。"""
    s = Svg(80, 28)
    s.poly([(0, 26), (80, 26), (74, 16), (6, 16)], BELLY)      # 破地拱起的地壳
    sulfur_fleck(s, [(14, 21, 5, 1.5), (64, 22, 6, 1.5)])
    s.rect(8, 10, 64, 8, GAP)                                   # 套管头
    s.rect(8, 10, 64, 2, LIGHT, 0.8)
    s.rect(14, 12, 52, 5, VOID)                                 # 井口黑膛
    for fx_ in (6, 70):                                         # 法兰耳
        s.rect(fx_, 8, 4, 12, STEEL)
    s.rect(36, 20, 8, 6, BODY)                                  # 接地立管
    pilot(s, 8, 5.5, 1.2)                                       # 法兰耳引火标
    return s


def vent_glow():
    """亮井层 64x20，锚点 (32,18)：口内蓝焰微光（alpha/scale 由代码渐急）。"""
    s = Svg(64, 20)
    s.glow_ellipse(32, 12, 30, 9, BLUE, 0.55)
    s.ellipse(32, 13, 22, 3.2, BLUE, 0.85)
    s.ellipse(32, 13, 12, 1.6, BLUE_CORE, 0.95)
    for x, h in ((20, 5), (32, 8), (44, 5)):                   # 口沿火舌苗
        s.poly([(x - 3, 14), (x + 3, 14), (x, 14 - h)], BLUE, 0.8)
    return s


def vent_flame():
    """焰柱 72x224，接地 (36,222)，焰顶 (36,2)=局部 (0,-220)；焰体宽 64。
    竖直静止墙：暗焰边→硫焰蓝→白热芯三层，普通混合。"""
    s = Svg(72, 224)
    outer = s.vgrad("vf_o", [(0, BLUE_DK, 0.0), (0.12, BLUE_DK, 0.75), (1, BLUE_DK, 0.92)])
    mid = s.vgrad("vf_m", [(0, BLUE, 0.0), (0.15, BLUE, 0.85), (1, BLUE, 0.95)])
    core = s.vgrad("vf_c", [(0, BLUE_CORE, 0.0), (0.25, BLUE_CORE, 0.85), (1, BLUE_CORE, 1.0)])
    s.path("M 4 222 L 6 120 Q 10 40 36 2 Q 62 40 66 120 L 68 222 Z", fill=outer)
    s.path("M 14 222 L 15 130 Q 20 60 36 16 Q 52 60 57 130 L 58 222 Z", fill=mid)
    s.path("M 26 222 L 27 150 Q 30 90 36 50 Q 42 90 45 150 L 46 222 Z", fill=core)
    # 底部喷口压强裙
    s.ellipse(36, 216, 34, 7, BLUE, 0.6)
    s.ellipse(36, 218, 18, 4, BLUE_CORE, 0.9)
    return s


def drill():
    """钻头弹 32x16，锚点中心 (16,8)，+X=飞行方向。暗壳钻身+螺纹+亮钻尖+蓝尾焰。"""
    s = Svg(32, 16)
    s.ellipse(5, 8, 5, 3, BLUE, 0.4)
    s.ellipse(4, 8, 3, 1.8, BLUE, 0.95)
    s.rect(4, 4.5, 14, 7, BODY)
    s.rect(4, 4.5, 14, 2, LIGHT)
    for x in (8, 12, 16):
        s.line(x, 4.5, x + 2.5, 11.5, GAP, 1.2)
    s.poly([(18, 3.5), (24, 4.5), (31, 8), (24, 11.5), (18, 12.5)], STEEL)
    s.poly([(24, 6.5), (31, 8), (24, 9.5)], "#e8dce0")
    return s


def flare_puff():
    """普攻蓝白焰团 48x48，锚点中心 (24,24)：暗焰边 #1e4a66 → 主焰 #48b4ff → 白热芯 #c8ecff。"""
    s = Svg(48, 48)
    s.circle(24, 24, 22, BLUE_DK, 0.85)
    s.poly([(4, 26), (10, 12), (20, 4), (30, 6), (40, 12), (45, 24), (40, 38),
            (28, 45), (14, 42), (6, 36)], BLUE_DK, 0.6)
    s.circle(24, 24, 16, BLUE, 0.95)
    s.circle(27, 22, 8.5, BLUE_CORE)
    return s


def gas_shell():
    """硫气弹 24x24，锚点中心 (12,12)：青灰白汽团 + 蓝火星（弹体无伤，弹药读法）。"""
    s = Svg(24, 24)
    s.circle(12, 12, 10.5, GAS, 0.55)
    s.circle(10, 11, 7, GAS, 0.85)
    s.circle(15, 14, 5.5, SMOKE, 0.85)
    s.circle(12, 12, 3.6, BELLY)
    for x, y in ((6, 8), (17, 7), (16, 18)):
        s.circle(x, y, 1.4, BLUE, 0.95)
    s.circle(12, 12, 1.6, BLUE_CORE)
    return s


def cloud():
    """硫云爆燃带段 200x84（画布 y0..84 ↔ 世界 y428..512 绝对带），锚点左上 (0,0)；
    横向可平铺：硫黄色烟墙（#d8c040 系，圆钝云团轮廓，无尖齿）；蓝色只在锋线件 fx_sulfur_cloud_front。"""
    s = Svg(200, 84)
    band = s.vgrad("sc_b", [(0, CLOUD_LT, 0.95), (0.5, CLOUD, 0.95), (1, CLOUD_DK, 0.95)])
    s.rect(0, 2, 200, 80, band)
    for x, y, r in ((0, 20, 14), (40, 18, 15), (80, 22, 14), (120, 17, 15), (160, 21, 14), (200, 20, 14)):
        s.circle(x, y, r, CLOUD_LT, 0.8)
    for x, y, r in ((20, 64, 14), (60, 66, 14), (100, 64, 14), (140, 66, 14), (180, 64, 14)):
        s.circle(x, y, r, CLOUD_DK, 0.8)
    for x, y in ((30, 40), (90, 46), (150, 38)):
        s.ellipse(x, y, 18, 7, CLOUD_LT, 0.5)
    s.rect(0, 0, 200, 2, CLOUD_EDGE)
    s.rect(0, 82, 200, 2, CLOUD_EDGE)
    return s


def cloud_front():
    """硫云爆燃锋线 40x84（画布 y0..84 ↔ 世界 y428..512），锚点=锋线中线 (20,42)；
    +X 侧为已燃区、-X 为推进方向（锋头朝左）。蓝焰锋：暗焰边→硫焰蓝→白热芯竖条。"""
    s = Svg(40, 84)
    s.path("M 22 2 Q 8 20 12 42 Q 8 64 22 82 L 40 82 L 40 2 Z", fill=BLUE_DK, opacity=0.8)
    s.path("M 24 6 Q 13 22 16 42 Q 13 62 24 78 L 34 78 L 34 6 Z", fill=BLUE, opacity=0.95)
    s.path("M 26 14 Q 20 28 22 42 Q 20 56 26 70 L 29 70 L 29 14 Z", fill=BLUE_CORE)
    return s


ITEMS = [
    (walker_body, "enemy_sulfur_walker_body.svg", "第十章步行者换皮「井场巡检」56x52 地面 y=50。眼 (15.5,18.3)；肩 joint (16,24)。"),
    (walker_arm, "enemy_sulfur_walker_arm.svg", "第十章步行者枪臂 48x28。肩 joint (36,8)；Muzzle 臂画布 (6,15)。"),
    (drone_body, "enemy_sulfur_drone.svg", "第十章无人机换皮「烟道飞眼」38x42。眼 (12,14.4)；ArmPivot (15.2,21)。"),
    (drone_arm, "enemy_sulfur_drone_arm.svg", "第十章无人机枪臂 32x16。joint (28,8)；Muzzle (13,11)。"),
    (shield_body, "enemy_sulfur_shield_body.svg", "第十章盾卫换皮「防喷闸盾卫」56x52 地面 y=50。眼 (23.5,18.3)；肩 joint (24,24)。"),
    (elite_body, "enemy_sulfur_elite_body.svg", "第十章精英「窜井」井口封堵车 60x80 地面 y=80。眼 (19,26.5)；ArmPivot 画布 (44,12)=局部 (14,-28)，固定射角不俯仰。"),
    (elite_arm, "enemy_sulfur_elite_arm.svg", "第十章精英钻机架 34x44。枢端 (17,40)；钻杆口 (17,6)=DrillPort=Muzzle 臂局部 (0,-34)，ThreatFlash 挂此。"),
    (boss_body, "boss_sulfur_body.svg", "第十章 BOSS「井口」井场管线母舰 300x180=碰撞体，原点 (150,90)，原生朝左，hover 370 船底 460。独眼条带 y60..66 含 (55,63)；NozzlePort (4,144)=局部 (-146,54)=世界 y424；DrillPort (150,168)=局部 (0,78)；VentPort (246,46)=局部 (96,-44)；ArmPivot (150,26)=局部 (0,-64)。"),
    (boss_arm, "boss_sulfur_arm.svg", "第十章 BOSS 井架吊杆 96x44（俯仰件，无发光口）。枢端 (78,22)；杆端吊钩座 (10,22)=Muzzle 臂局部 (-68,0)，本章不从此出弹。"),
    (vent, "fx_sulfur_vent.svg", "硫焰井口底座 80x28。锚点画布 (ax,ay)=(40,26) 底部接地点；口宽 64（x8..72）。"),
    (vent_glow, "fx_sulfur_vent_glow.svg", "亮井层 64x20。锚点画布 (ax,ay)=(32,18)；口内蓝焰渐急由代码驱动，无伤读出层。"),
    (vent_flame, "fx_sulfur_vent_flame.svg", "井口焰柱 72x224。锚点画布 (ax,ay)=(36,222) 底部接地点；焰顶 (36,2)=局部 (0,-220)；焰体宽 64。"),
    (drill, "fx_sulfur_drill.svg", "钻头弹 32x16，锚点中心 (16,8)，+X=飞行方向。"),
    (flare_puff, "fx_sulfur_flare_puff.svg", "普攻蓝白焰团 48x48，锚点中心 (24,24)；芯 #c8ecff/主焰 #48b4ff/暗焰边 #1e4a66，普通混合不 ADD。"),
    (gas_shell, "fx_sulfur_gas_shell.svg", "硫气弹 24x24，锚点中心 (12,12)；青灰白汽团+蓝火星，弹体无伤。"),
    (cloud, "fx_sulfur_cloud.svg", "硫云爆燃带段 200x84，锚点左上 (0,0)；画布 y0..84 ↔ 世界 y428..512 绝对带，横向平铺；硫褐烟墙 #5a4a18 主体+上下 2px #d8c040 带界亮边。"),
    (cloud_front, "fx_sulfur_cloud_front.svg", "硫云爆燃锋线 40x84，锚点 (20,42)；画布 y0..84 ↔ 世界 y428..512；锋头朝左推进，蓝焰只用于此件。"),
]

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn, name, c in ITEMS:
        save(fn(), name, c)
