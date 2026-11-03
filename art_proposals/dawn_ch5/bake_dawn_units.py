# -*- coding: utf-8 -*-
"""第五章「破晓云廊」单位/特效烘焙：防空截击能力套件。

产物（assets/world_5/）：
  enemy_dawn_walker_body.svg  56x52   步行者换皮「巡航步机」
  enemy_dawn_walker_arm.svg   48x28   步行者枪臂
  enemy_dawn_drone.svg        38x42   无人机换皮「信标浮游机」
  enemy_dawn_drone_arm.svg    32x16   无人机枪臂
  enemy_dawn_shield_body.svg  56x52   盾卫换皮「板垒盾卫」
  enemy_dawn_elite_body.svg   60x80   精英「响哨」防空炮车（预教啸雷）
  enemy_dawn_elite_arm.svg    40x22   精英双管高炮臂（俯仰跟踪）
  boss_dawn_body.svg          300x180 BOSS「断云」高空截击机（啸雷+俯冲）
  boss_dawn_gun.svg           44x18   BOSS 机鼻直射炮臂
  boss_dawn_cannon.svg        36x30   BOSS 背部啸雷炮塔（俯仰跟随）
  fx_dawn_flak.svg            112x14  啸雷弹（曳光矢：白热金主带+暗壳双色，弹体恒亮）
  fx_dawn_flakcore.svg        32x32   引信芯光斑（白热金径向软晕，「何时爆」信息层）
  fx_dawn_flakshard.svg       18x18   弹壳碎片（dawn_burst 崩射身份件，任意角自旋）
  fx_dawn_bolt.svg            30x12   机鼻曳光矢弹（bullet.gd 纯换皮）

锚点账（详见 提案_v1_破晓云廊.md §3；杂兵照 §3 基线逐像素对齐）：
  精英：眼 (19,26.5)=halo r5.3/core r2.4；ArmPivot 画布 (44,12)→局部 (14,-28)，
        臂枢随玩家俯仰；臂画布 40x22 枢端 (28,13)、双管、管口 (6,10)
        =Muzzle 臂局部 (-22,-3)。
  BOSS：独眼条带 y60..66 含 (55,63)（EyeGlow 节点 (-95,-27) 沿用）；
        ArmPivot=机鼻炮座画布 (60,74)→局部 (-90,-16)（直射，Muzzle=臂局部
        (-24,0)=管口 (10,9)）；Cannon=背炮塔画布 (150,34)→局部 (0,-56)
        （啸雷炮位，塔身独立件俯仰跟随，Muzzle=局部 (0,-16)=管口白热尖）；
        Nose=机鼻画布 (14,84)→局部 (-136,-6)（俯冲预警）；Thruster1/2=局部
        (136,-4)/(136,16)（尾焰=通用 fx_flame.svg+加色）；无旋翼。
色板：LIGHT #7a6090 / BODY #4e3c64 / BELLY #3a2c50 / GAP #2a1f3e
      + 信号黄 #d8a021 + 白热金 #ffd9a0/#fff3d8 + 独眼红 #ff4640 不变。
ThorVG 硬约束：无 filter/pattern/use/text/transform；无 rect+rotate。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
from generate_proposals import Svg, f  # noqa: E402

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "world_5"))

LIGHT = "#7a6090"
BODY = "#4e3c64"
BELLY = "#3a2c50"
GAP = "#2a1f3e"
RED = "#ff4640"
YELLOW = "#d8a021"
GOLD = "#ffc46a"        # 晨光金窗/位标
WHITE_HOT = "#ffd9a0"   # 白热金（啸雷语言）
CORE_HOT = "#fff3d8"
VIOLET = "#8e7cc0"      # 曳光紫
VIOLET_HI = "#cfc0f0"


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
# 杂兵三件套（骨架锚点=§3 基线，造型按云廊守备队重涂微调）
# ============================================================
def walker_body():
    """步行者换皮「巡航步机」56x52，地面 y=50。
    比例账沿四章骨架：舱体胶囊 5..46 x 12..33 + 背部单罐 + 逆关节双足踏地 y50；
    背鳍天线=云廊通讯语汇。骨架：眼 (15.5,18.3)=halo r5.3/core r2.4；
    肩 joint (16,24)。前缘 x<6 留空给枪臂。"""
    s = Svg(56, 52)
    # 远侧足对（暗）
    s.poly([(24, 32), (29, 32), (27, 41), (31, 46), (26, 50), (21, 41)], BELLY)
    s.poly([(38, 32), (43, 32), (41, 41), (45, 46), (40, 50), (35, 41)], BELLY)
    # 背罐 + 排气阀
    s.rect(31, 7, 5.5, 10, BELLY)
    s.rect(38.5, 9, 5.5, 8, BELLY)
    s.rect(30.5, 5.5, 6.5, 2.5, GAP)
    s.line(41.5, 9, 44, 5, GAP, 1.5)
    s.circle(44.3, 4.5, 1.2, RED, 0.9)
    # 主舱体
    s.poly([(8, 14), (30, 12), (42, 16), (46, 24), (42, 33), (10, 33), (5, 26), (5, 19)], BODY)
    s.poly([(8, 14), (30, 12), (42, 16), (43.5, 19), (9.5, 17)], LIGHT)
    # 背鳍天线（云廊守备识别件）
    s.poly([(26, 12), (32, 4), (34, 5), (30, 13)], BELLY)
    s.circle(33, 4, 1.2, GOLD, 0.9)
    # 头部圆舷窗 + 独眼（节点位）
    s.circle(15.5, 18.3, 6.6, GAP)
    s.rect(9.5, 14.5, 12, 7.5, GAP)
    s.circle(15.5, 18.3, 5.3, RED, 0.22)
    s.circle(15.5, 18.3, 2.4, RED, 0.95)
    # 腹部龙骨
    s.rect(10, 31.5, 34, 1.5, GAP, 0.8)
    s.poly([(10, 33), (42, 33), (38, 37), (14, 37)], BELLY)
    # 侧舷警示带
    for i, hx in enumerate(range(24, 42, 6)):
        s.rect(hx, 26, 2.5, 3, YELLOW if i % 2 == 0 else GAP, 0.85)
    # 近侧足对（逆关节，踏地）
    s.poly([(11, 33), (16, 33), (15, 41), (19, 46), (14, 50), (8, 42)], BODY)
    s.poly([(30, 33), (35, 33), (35, 42), (39, 46), (34, 50), (29, 42)], BODY)
    s.rect(12, 48.5, 9, 1.8, BELLY)
    s.rect(30, 48.5, 9, 1.8, BELLY)
    # 肩 joint（枪臂挂点）
    s.circle(16, 24, 3.5, GAP)
    return s


def walker_arm():
    """步行者枪臂换皮 48x28：速射炮（方匣机匣+消焰管）。
    肩 joint (36,8)、枪口尖端 ~(2,15)（Muzzle=臂画布 (6,15)）。"""
    s = Svg(48, 28)
    s.circle(36, 8, 3.5, BELLY)
    s.rect(33, 8, 6, 10, BELLY)
    s.rect(17, 10, 19, 9, BODY)          # 机匣
    s.rect(17, 10, 19, 2.5, LIGHT)
    s.rect(5, 12.2, 13, 4, GAP)          # 长管
    s.rect(10, 11.4, 2.2, 5.6, BODY)     # 收口环
    s.rect(1, 11, 6, 7, BODY)            # 膛口座
    s.rect(1, 13.6, 2.2, 2.8, GAP)       # 膛口
    s.rect(21, 19, 10, 4, BELLY)         # 下挂弹匣
    s.circle(31.5, 21, 2, BELLY)
    s.circle(33, 13.5, 1.3, GOLD, 0.9)
    return s


def drone_body():
    """无人机换皮「信标浮游机」38x42（悬浮）。
    侧视语义：扁圆盘体+下吊舱+顶灯穗，盘缘下三根天线。
    骨架：眼 (12,14.4)=halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。"""
    s = Svg(38, 42)
    # 顶部灯穗
    s.line(20, 5.5, 20, 3.2, GAP, 1.2)
    s.circle(20, 2.8, 1.2, GOLD, 0.9)
    # 扁圆盘体
    s.ellipse(20, 12, 15, 7, BODY)
    s.ellipse(20, 10.5, 13, 4.5, LIGHT, 0.85)
    s.ellipse(20, 14, 15, 3, BELLY)
    # 盘缘天线 ×3
    for ax in (8, 20, 32):
        s.line(ax, 15, ax, 20, GAP, 1.2, 0.9)
        s.circle(ax, 21, 1.1, GAP)
    # 中央吊舱（实体质量）
    s.poly([(9, 19), (29, 19), (32, 24), (28, 31), (10, 31), (6, 24)], BODY)
    s.poly([(9, 19), (29, 19), (30, 21), (10, 21)], LIGHT, 0.8)
    s.poly([(11, 28), (27, 28), (25, 31), (13, 31)], BELLY)
    # 眼窝 + 独眼（节点位，盘前）
    s.rect(7.5, 11.5, 9, 6, GAP)
    s.circle(12, 14.4, 4.4, RED, 0.22)
    s.circle(12, 14.4, 2.0, RED, 0.95)
    # 检修警示带
    s.rect(16, 22.5, 6, 2.5, YELLOW, 0.85)
    # 腹挂传感器球
    s.rect(18, 31, 2.5, 3, GAP)
    s.circle(19.2, 36, 3, BELLY)
    s.circle(19.2, 36, 1.2, GOLD, 0.9)
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
    s.circle(25, 10.5, 1.0, GOLD, 0.9)
    return s


def shield_body():
    """盾卫换皮「板垒盾卫」56x52，地面 y=50。
    比例账沿四章：通高塔盾 4..25 x 10..47 + 后置舱体 25..49 x 10..42 + 双足。
    骨架：眼 (23.5,18.3)=halo r5.3/core r2.4；肩 joint (24,24)（复用本章枪臂）。"""
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
    # 塔盾（通高，前缘受光 + 铆钉阵 + 警示斜带）
    s.poly([(5, 10), (22, 10), (25, 14), (25, 44), (21, 47), (7, 47), (4, 42), (4, 14)], BODY)
    s.poly([(4, 14), (7, 11.5), (7, 45), (4, 40)], LIGHT, 0.6)
    for ry_ in (18, 26, 34):
        s.circle(11, ry_, 1.6, GAP)
        s.circle(18, ry_ + 4, 1.6, GAP)
    s.line(8, 44, 20, 30, YELLOW, 2.2, 0.75)   # 盾面警示斜带
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


# ============================================================
# 精英「响哨」：防空炮车（预教啸雷弹）
# ============================================================
def elite_body():
    """精英「响哨」防空炮车 60x80，地面 y=80。
    比例账（按能力反推）：啸雷弹 Ø30 级出膛 → 双管高炮（管口画布 (24,10)
    邻域）→ 炮塔基座 (36..52, 8..24) + 后置雷达碟；轮式底盘（三轮踏地 y78）
    + 车体 (4..58, 40..64) + 驾驶眼塔。
    锚点：眼 (19,26.5)=halo r5.3/core r2.4；ArmPivot 画布 (44,12)→局部
    (14,-28)（炮塔臂独立件随玩家俯仰，Muzzle=臂局部 (-22,-3)）。"""
    s = Svg(60, 80)
    # ---- 轮式底盘（三轮，踏地 y78）----
    s.rect(4, 58, 54, 8, BELLY)                       # 底梁
    for wx, wy, r in ((14, 70, 8), (32, 72, 7), (48, 70, 8)):
        s.circle(wx, wy, r, GAP)
        s.circle(wx, wy, r - 3.2, BODY)
        s.circle(wx, wy, 1.6, BELLY, 0.9)
    # ---- 车体（防空炮车平板）----
    s.poly([(4, 42), (58, 42), (58, 58), (4, 58)], BODY)
    s.poly([(4, 42), (58, 42), (57, 44.5), (5, 44.5)], LIGHT, 0.7)
    for i, hx in enumerate(range(22, 56, 6)):         # 危险黄警示带
        s.rect(hx, 52, 2.5, 3.5, YELLOW if i % 2 == 0 else GAP, 0.8)
    # 尾部储能罐 + 位标灯
    s.rect(52, 34, 6, 10, BELLY)
    s.circle(55, 32, 1.4, GOLD, 0.9)
    # ---- 驾驶眼塔 + 独眼（锚点）----
    s.poly([(8, 22), (30, 22), (32, 28), (32, 42), (8, 42)], BODY)
    s.rect(8, 22, 22, 3, LIGHT)
    s.rect(12, 23, 14, 7, GAP)
    s.circle(19, 26.5, 5.3, RED, 0.22)
    s.circle(19, 26.5, 2.4, RED, 0.95)
    s.rect(10, 33, 20, 4, GAP)
    # 前部破障锥
    s.poly([(2, 50), (8, 46), (10, 46), (10, 60), (4, 60), (0, 56)], BELLY)
    s.line(0, 56, 4, 60, LIGHT, 2, 0.7)
    # ---- 炮塔基座（能力签名件；炮管=臂独立件；梯形从车体顶一路收到塔环）----
    s.poly([(37, 46), (51, 46), (50, 10), (38, 10)], BODY)   # 塔座（落地）
    s.rect(38, 10, 12, 2.5, LIGHT)
    s.circle(44, 12, 4.5, GAP)                               # 塔环（=ArmPivot）
    s.circle(44, 12, 2.2, BELLY)
    s.circle(50, 7, 1.3, WHITE_HOT, 0.9)                     # 就绪白热灯
    # ---- 后置雷达碟（防空识别件）----
    s.line(55, 42, 57, 26, BELLY, 2)
    s.ellipse(58, 24, 5, 3.5, BODY)
    s.ellipse(58, 23.4, 4, 2.2, LIGHT, 0.8)
    return s


def elite_arm():
    """精英双管高炮臂 40x22（俯仰跟踪）。枢端画布 (28,13)=炮塔环心；
    双管左伸，管口画布 (6,10)=Muzzle（臂局部 (-22,-3)）。
    出膛焰/预警闪光都落管口（真实枪口律）。"""
    s = Svg(40, 22)
    s.rect(22, 6, 12, 14, BODY)                 # 炮匣
    s.rect(22, 6, 12, 2.5, LIGHT)
    s.rect(10, 8, 14, 3.2, GAP)                 # 上管
    s.rect(10, 13.5, 14, 3.2, GAP)              # 下管
    s.rect(4, 7.6, 7, 4, BODY)                  # 上管口座
    s.rect(4, 13.1, 7, 4, BODY)                 # 下管口座
    s.rect(2, 8.4, 2.6, 2.4, WHITE_HOT, 0.9)    # 上管口白热
    s.rect(2, 13.9, 2.6, 2.4, WHITE_HOT, 0.9)   # 下管口白热
    s.circle(28, 13, 2.2, BELLY)                # 枢环（=枢端画布 (28,13)）
    s.circle(20, 20, 1.2, GOLD, 0.85)           # 匣侧信号灯
    return s


# ============================================================
# BOSS「断云」：高空截击机（啸雷⇄俯冲+机鼻曳光）
# ============================================================
def boss_body():
    """BOSS 高空截击机「断云」300x180=碰撞体 body_size，原点(150,90)，原生朝左。
    造型按能力布挂件：细长镖形机身 + 独眼条带（沿用锚点）+ 背部啸雷炮塔座
    （塔身=独立件俯仰跟随，炮口画布 (150,6) 邻域）+ 机鼻炮座（直射臂=独立件）
    + 后掠翼/双垂尾 + 尾部双发短舱（尾焰=通用 fx_flame 独件，画布 (286,86)/
    (286,106)）。v1 无旋翼（推进焰脉动同哨兵账）。"""
    s = Svg(300, 180)
    # ---- 双垂尾（先画，被机身压住；根部埋进机体轮廓下——首版根部悬在
    #      机身上缘外读成"断件"，2026-10-22 用户抓，返工）----
    s.poly([(238, 72), (282, 10), (296, 16), (288, 82)], BODY)
    s.poly([(282, 10), (296, 16), (292, 22), (280, 18)], LIGHT, 0.85)
    s.poly([(238, 96), (270, 146), (290, 138), (284, 98)], BELLY)
    # ---- 后掠主翼（侧视薄刃，上挑）----
    s.poly([(120, 76), (232, 40), (266, 52), (168, 88)], BODY)
    s.poly([(120, 76), (232, 40), (240, 43), (132, 80)], LIGHT, 0.7)
    # 腹鳍
    s.poly([(150, 104), (196, 130), (208, 122), (172, 100)], BELLY)
    # ---- 机身（细长镖形；前段顶缘抬到 y52 包住独眼条带 y57..69）----
    s.poly([(8, 84), (36, 52), (150, 58), (240, 62), (292, 74), (296, 92),
            (250, 108), (60, 104), (16, 96)], BODY)
    s.poly([(36, 52), (150, 58), (240, 62), (288, 73), (284, 78), (238, 66),
            (150, 62), (42, 56)], LIGHT, 0.7)
    # 腹部压暗 + 悬浮引擎辉光
    s.poly([(16, 96), (60, 104), (250, 108), (240, 100), (60, 96)], BELLY)
    # 板缝
    s.rect(120, 62, 2.5, 42, GAP, 0.35)
    s.rect(196, 60, 2.5, 44, GAP, 0.35)
    s.rect(80, 92, 170, 2, GAP, 0.3)
    # 舷窗带（暖金）
    for wx in range(160, 232, 16):
        s.rect(wx, 72, 7, 6, GOLD, 0.8)
    # ---- 机鼻锥 + 独眼条带（沿用锚点 y60..66 含 (55,63)）----
    s.poly([(0, 82), (14, 74), (18, 74), (18, 98), (6, 92)], BELLY)
    s.line(0, 82, 6, 92, LIGHT, 2, 0.7)
    s.rect(38, 57, 34, 12, RED, 0.18)
    s.rect(42, 60, 26, 6, RED, 0.95)
    # 座舱框
    s.poly([(76, 58), (112, 56), (110, 70), (80, 72)], GAP, 0.9)
    s.poly([(78, 60), (108, 58), (107, 62), (80, 64)], LIGHT, 0.5)
    # ---- 背部啸雷炮塔座（塔身=独立件 boss_dawn_cannon，画布 (150,22)）----
    s.rect(136, 48, 28, 12, BELLY)               # 座环裙
    s.rect(138, 46, 24, 3, LIGHT, 0.7)
    s.circle(150, 54, 2, WHITE_HOT, 0.9)         # 就绪白热灯（座侧）
    # ---- 机鼻炮座（直射臂=独立件 boss_dawn_gun，画布 (60,74)）----
    s.circle(60, 74, 4, GAP)                     # 臂根 joint（=ArmPivot）
    s.poly([(52, 70), (70, 70), (68, 80), (54, 80)], BELLY, 0.9)  # 炮座壳
    # ---- 尾部双发短舱（尾焰独件画布 (286,86)/(286,106)）----
    s.rect(268, 76, 26, 18, BODY)
    s.rect(268, 76, 26, 3, LIGHT, 0.6)
    s.rect(288, 79, 6, 12, GAP)                  # 上喷口
    s.rect(266, 98, 24, 16, BELLY)
    s.rect(266, 98, 24, 3, LIGHT, 0.5)
    s.rect(284, 101, 6, 10, GAP)                 # 下喷口
    # ---- 侧舷识别条 ----
    s.rect(132, 78, 26, 3, RED, 0.8)
    return s


def boss_gun():
    """BOSS 机鼻直射炮臂 44x18（俯仰跟踪）。枢端画布 (34,9)=机鼻炮座环；
    炮管左伸，管口画布 (10,9)=Muzzle（臂局部 (-24,0)）。
    电光矢弹出膛点（直射无预警，真瞄即预警）。"""
    s = Svg(44, 18)
    s.rect(24, 3, 14, 12, BODY)                  # 炮匣
    s.rect(24, 3, 14, 2.5, LIGHT)
    s.rect(8, 6.6, 18, 4.6, GAP)                 # 长管
    s.rect(16, 6, 2.4, 5.8, BODY)                # 收口环
    s.rect(4, 6, 6, 6, BODY)                     # 管口座
    s.rect(2, 7.6, 2.6, 2.8, VIOLET_HI, 0.9)     # 管口紫芯
    s.circle(30, 9, 2.4, BELLY)                  # 枢环
    s.circle(34, 15, 1.1, GOLD, 0.85)
    return s


def boss_cannon():
    """BOSS 背部啸雷炮塔 36x30（俯仰跟随：整塔绕枢点旋向玩家）。
    枢点=画布 (18,16)≈Cannon 原点（塔鼓同心）；双管朝天（-Y），管口白热尖
    画布 y0.6..2.6=Cannon/Muzzle 局部 (0,-16) 邻域。出膛焰/预警闪光都落
    管口（真实枪口律）。"""
    s = Svg(36, 30)
    s.rect(12, 18, 12, 10, BELLY)                # 塔座
    s.circle(18, 16, 8, BODY)                    # 塔鼓（同心枢点）
    s.circle(18, 16, 8, BODY, 0.0)
    s.circle(18, 14, 5.5, LIGHT, 0.7)            # 塔顶受光
    s.rect(14, 4, 3.4, 16, GAP)                  # 左管（朝天）
    s.rect(19, 4, 3.4, 16, GAP)                  # 右管
    s.rect(13, 2, 5.4, 3.4, BODY)                # 左管口座
    s.rect(18, 2, 5.4, 3.4, BODY)                # 右管口座
    s.rect(14.4, 0.6, 2.6, 2, WHITE_HOT, 0.95)   # 左管口白热
    s.rect(19.4, 0.6, 2.6, 2, WHITE_HOT, 0.95)   # 右管口白热
    s.circle(27, 24, 1.2, YELLOW, 0.85)          # 塔侧警示灯
    return s


# ============================================================
# 特效件
# ============================================================
def fx_flak():
    """啸雷弹 112x14（+X=飞行方向）：**曳光矢读法**——弹速 2400 下短弹
    几乎不可见（2026-10-22 用户二轮抓："尺寸拉大，可以多长几倍"），拉到
    全长 112=每秒掠过自身长度 21 次，高速下拖成一条白热金轨迹。双色账
    不变：白热带/弹头管暗紫天区、暗壳管金霞地平带（章专属弹只保本章
    可读性）。v2（2026-10-23）：**弹体恒亮**（轨迹读法，整弹 alpha 闪烁
    =轨迹断线判废），引信读法移交 fx_dawn_flakcore 光斑独立脉冲。"""
    s = Svg(112, 14)
    s.rect(0, 3.5, 98, 7, "#3a2c50", 0.92)       # 暗壳全长（金霞带上的剪影读法）
    s.rect(3, 5.2, 92, 3.6, "#5a4470", 0.9)      # 壳受光条
    s.rect(10, 2.2, 82, 9.6, WHITE_HOT, 0.95)    # 白热金主带（暗紫天区上的读法）
    s.rect(16, 4.4, 70, 5.2, CORE_HOT, 1.0)      # 内芯提亮（轨迹亮线）
    s.circle(102, 7, 6.0, WHITE_HOT, 0.95)       # 弹头白热（+X 前缘）
    s.circle(102, 7, 2.8, "#fff8e8", 1.0)        # 弹头亮芯
    s.circle(84, 7, 3.2, "#fff8e8", 1.0)         # 引信芯（位置锚=光斑挂点局部 (28,0)）
    s.circle(84, 7, 5.6, WHITE_HOT, 0.3)         # 芯晕
    return s


def fx_flakcore():
    """引信芯光斑 32x32（径向软晕，ADD 叠亮）：白热金晕+亮芯双层——啸雷弹
    引信期的「何时爆」信息层（alpha+scale 随引信进度渐急脉冲，代码驱动；
    v1 整弹 alpha 闪烁=轨迹断线已废）。挂在弹上引信芯位（局部 (28,0)），
    随弹体旋转。"""
    s = Svg(32, 32)
    s.glow_ellipse(16, 16, 15, 15, WHITE_HOT, 0.45)
    s.glow_ellipse(16, 16, 7, 7, "#fff8e8", 0.95)
    return s


def fx_flakshard():
    """啸雷弹壳碎片 18x18（dawn_burst 崩射身份件，任意角自旋）：高炮弹幕
    的弹壳崩碎读法——暗紫壳（金霞地平带上剪影可读）+暗紫受光棱+白热金
    反光小面（受光面被 color_ramp 染暖=「热壳冷却」）。fx_red_rock 的
    dawn 对应件，禁万能圆盘/方点。"""
    s = Svg(18, 18)
    s.poly([(2, 6), (7, 1), (15, 3), (17, 10), (10, 17), (3, 13)], BELLY)
    s.poly([(7, 1), (15, 3), (17, 10), (9, 7)], LIGHT, 0.85)   # 受光棱
    s.poly([(9, 7), (17, 10), (10, 17)], CORE_HOT, 0.5)        # 白热金反光小面
    return s


def fx_bolt():
    """机鼻曳光矢弹 30x12（+X=飞行方向）：平滑三层带（外晕/中层/白热芯）
    ——紫白曳光语汇（云廊守备曳光机炮）。dawn_bolt.tscn=bullet.gd 纯换皮。"""
    s = Svg(30, 12)
    import math
    amp, lam, x0, x1, yc = 1.6, 15.0, 2.0, 28.0, 6.0
    n = 24
    xs = [x0 + (x1 - x0) * i / (n - 1) for i in range(n)]
    ys = [yc + amp * math.sin((x - x0) / lam * 2.0 * math.pi) for x in xs]

    def ribbon(width, color, opacity):
        pts = [(x, y - width * 0.5) for x, y in zip(xs, ys)]
        pts += [(x, y + width * 0.5) for x, y in zip(reversed(xs), reversed(ys))]
        s.poly(pts, color, opacity)

    ribbon(6.0, VIOLET, 0.30)
    ribbon(3.0, VIOLET_HI, 0.9)
    ribbon(1.3, "#ffffff", 1.0)
    s.circle(x1, ys[-1], 1.5, "#ffffff", 1.0)
    return s


if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)
    save(walker_body(), "enemy_dawn_walker_body.svg", """第五章步行者换皮「巡航步机」56x52，地面 y=50。
骨架：眼 (15.5,18.3)=halo r5.3/core r2.4；肩 joint (16,24)；前缘 x<6 留空。
造型：舱体胶囊+背鳍天线+警示带（云廊守备涂装）。
色板：LIGHT #7a6090/BODY #4e3c64/BELLY #3a2c50/GAP #2a1f3e。""")
    save(walker_arm(), "enemy_dawn_walker_arm.svg", """第五章步行者枪臂 48x28。肩 joint (36,8)、枪口尖端 ~(2,15)
（Muzzle=臂画布 (6,15)）。速射炮（方匣机匣+消焰管）。""")
    save(drone_body(), "enemy_dawn_drone.svg", """第五章无人机换皮「信标浮游机」38x42（悬浮）。
骨架：眼 (12,14.4)=halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。
造型：扁圆盘体+盘缘天线×3+下吊舱+顶灯穗。""")
    save(drone_arm(), "enemy_dawn_drone_arm.svg", """第五章无人机枪臂 32x16。肩 joint (28,8)、枪口尖端 ~(12,9.5)
（Muzzle=臂画布 (13,11)）。""")
    save(shield_body(), "enemy_dawn_shield_body.svg", """第五章盾卫换皮「板垒盾卫」56x52，地面 y=50。
骨架：眼 (23.5,18.3)=halo r5.3/core r2.4；肩 joint (24,24)（复用本章枪臂）。
造型：通高塔盾（铆钉阵+警示斜带）+后置舱体+双足。""")
    save(elite_body(), "enemy_dawn_elite_body.svg", """第五章精英「响哨」防空炮车 60x80，地面 y=80。
骨架：眼 (19,26.5)=halo r5.3/core r2.4；ArmPivot 画布 (44,12)→局部 (14,-28)
（炮塔臂独立件随玩家俯仰）。造型：轮式底盘+驾驶眼塔+炮塔基座（塔环）+
后置雷达碟——防空炮车读法。提案=同目录 提案_v1_破晓云廊.md §3。""")
    save(elite_arm(), "enemy_dawn_elite_arm.svg", """第五章精英双管高炮臂 40x22（俯仰跟踪）。
枢端画布 (28,13)=炮塔环心；双管左伸，管口画布 (6,10)=Muzzle
（臂局部 (-22,-3)）。出膛焰/预警闪光落管口（真实枪口律）。""")
    save(boss_body(), "boss_dawn_body.svg", """第五章 BOSS 高空截击机「断云」300x180=碰撞体，原点(150,90)，原生朝左。
能力布挂件：背部啸雷炮塔座（塔身独立件画布 (150,34)=Cannon 局部 (0,-56)）
+ 机鼻炮座（直射臂独立件，ArmPivot 画布 (60,74)）+ 尾部双发短舱（尾焰独件
画布 (286,86)/(286,106)=通用 fx_flame）。沿用锚点：独眼条带 y60..66 含
(55,63)，机身前段顶缘抬到 y52 包住条带。无旋翼（推进焰脉动）。
提案=同目录 提案_v1_破晓云廊.md §3。""")
    save(boss_gun(), "boss_dawn_gun.svg", """第五章 BOSS 机鼻直射炮臂 44x18（俯仰跟踪）。
枢端画布 (34,9)=机鼻炮座环；管口画布 (10,9)=Muzzle（臂局部 (-24,0)）。
电光矢弹出膛点（直射无预警，真瞄即预警）。""")
    save(boss_cannon(), "boss_dawn_cannon.svg", """第五章 BOSS 背部啸雷炮塔 36x30（俯仰跟随）。
枢点=画布 (18,16)≈Cannon 原点（塔鼓同心）；双管朝天，管口白热尖
画布 y0.6..2.6=Cannon/Muzzle 局部 (0,-16) 邻域。出膛焰/预警闪光落管口
（真实枪口律）。""")
    save(fx_flak(), "fx_dawn_flak.svg", """啸雷弹贴图 112x14（+X=飞行方向）：曳光矢读法——弹速 2400 下
拉全长=高速拖成白热金轨迹（二轮返工：36 版太短几乎不可见）。双色账：
白热带/弹头管暗紫天区、暗壳管金霞地平带（章专属弹只保本章可读性）。
v2：弹体恒亮（轨迹读法），引信读法移交 fx_dawn_flakcore 光斑脉冲。""")
    save(fx_flakcore(), "fx_dawn_flakcore.svg", """引信芯光斑 32x32（径向软晕，ADD 叠亮）：白热金晕+亮芯
——啸雷弹引信「何时爆」信息层，alpha+scale 渐急脉冲由代码驱动。""")
    save(fx_flakshard(), "fx_dawn_flakshard.svg", """啸雷弹壳碎片 18x18（dawn_burst 崩射身份件，任意角自旋）：
暗紫壳+暗紫受光棱+白热金反光小面——高炮弹幕的弹壳崩碎读法。""")
    save(fx_bolt(), "fx_dawn_bolt.svg", """机鼻曳光矢弹 30x12（+X=飞行方向）：平滑三层带（外晕/中层/白热芯）
——紫白曳光语汇。dawn_bolt.tscn=bullet.gd 纯换皮。""")
    print("dawn chapter units baked.")
