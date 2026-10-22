# -*- coding: utf-8 -*-
"""第六章「赤沙矿区」单位/特效烘焙：矿区电网与输送能力套件。

产物（assets/world_6/）：
  enemy_red_walker_body.svg  56x52   步行者换皮「矿巡步机」
  enemy_red_walker_arm.svg   48x28   步行者枪臂
  enemy_red_drone.svg        38x42   无人机换皮「吊斗浮游机」
  enemy_red_drone_arm.svg    32x16   无人机枪臂
  enemy_red_shield_body.svg  56x52   盾卫换皮「挡墙盾卫」
  enemy_red_elite_body.svg   60x80   精英「锚桩」打桩车（预教电网闸）
  enemy_red_elite_arm.svg    34x44   精英双桩炮架（固定射角不俯仰）
  boss_red_body.svg          300x180 BOSS「赤轮」斗轮采集舰（电网闸+溜矿车）
  boss_red_wheel.svg         120x120 BOSS 斗轮（独立旋转件）
  boss_red_rack.svg          60x54   BOSS 双桩炮架（独立件）
  fx_red_chip.svg            22x12   斗轮弹石（bullet.gd 纯换皮）
  fx_red_stake.svg           46x14   锚桩（抛体落桩，+X=飞行方向）
  fx_red_fence.svg           8x200   电幕竖直光带（拉伸到幕高，代码脉冲）
  fx_red_cart.svg            76x84   溜矿车（贴地滚向玩家，顶灯读法）

锚点账（详见 提案_v1_赤沙矿区.md §3；杂兵照 §3 基线逐像素对齐）：
  步行者：眼 (15.5,18.3)=halo r5.3/core r2.4；肩 joint (16,24)；地面 y=50；
          前缘 x<6 留空给枪臂。
  无人机：眼 (12,14.4)=halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。
  盾卫：  眼 (23.5,18.3)=halo r5.3/core r2.4；肩 joint (24,24)（复用本章枪臂）。
  精英：  眼 (19,26.5)=halo r5.3/core r2.4；ArmPivot 画布 (44,12)→局部 (14,-28)
          （炮架基座环）；臂画布 34x44 枢端 (17,40)、双管朝天、管口 (17,6)
          =Muzzle 臂局部 (0,-34)。固定射角（垂发账，臂不俯仰）。
  BOSS：  独眼条带 y60..66 含 (55,63)（EyeGlow 节点 (-95,-27) 沿用）；
          Wheel=斗轮独立件，轮毂画布 (44,120)→局部 (-106,30)（轮缘 r54，
          最低点 +84=世界 454：bob 后对 t536 台阶净空 76）；Rack=背甲炮架
          画布 (210,38)→局部 (60,-52)（架画布 60x54 枢端 (30,50)，管口
          (30,4)=Muzzle 架局部 (0,-46)）；BayPort 画布 (150,170)→局部 (0,80)
          （腹舱口）；举升风扇画布 (120,154)/(230,154)=局部 (-30,64)/(80,64)
          （通用 fx_flame+加色）。碰撞 280x150。
色板：LIGHT #a85a3a / BODY #6e3424 / BELLY #4e2418 / GAP #33180e
      + 信号黄 #d8a021 + 矿灯金 #ffb347 + 独眼红 #ff4640 不变
      + 电幕蓝紫 #a08cff/#5a4a9c（暖沙底上的对比读法）。
ThorVG 硬约束：无 filter/pattern/use/text/transform；无 rect+rotate。
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
from generate_proposals import Svg, f  # noqa: E402

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "world_6"))

LIGHT = "#a85a3a"
BODY = "#6e3424"
BELLY = "#4e2418"
GAP = "#33180e"
RED = "#ff4640"
YELLOW = "#d8a021"
GOLD = "#ffb347"        # 矿灯金
RUST_RIM = "#d98c5e"    # 受光锈橙（环境同款顶缘）
ARC_HI = "#a08cff"      # 电幕中带（蓝紫）
ARC_DEEP = "#5a4a9c"    # 电幕外晕
WHITE_HOT = "#f2f0ff"   # 电白热芯


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
# 杂兵三件套（骨架锚点=§3 基线，造型按矿区守备队重涂微调）
# ============================================================
def walker_body():
    """步行者换皮「矿巡步机」56x52，地面 y=50。
    比例账沿五章骨架：舱体胶囊 5..46 x 12..33 + 背部双罐 + 逆关节双足踏地 y50；
    背顶矿灯=矿区语汇。骨架：眼 (15.5,18.3)=halo r5.3/core r2.4；
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
    # 背顶矿灯杆（矿区守备识别件）
    s.poly([(26, 12), (29, 5), (31, 5), (29, 13)], BELLY)
    s.circle(30, 4.4, 1.4, GOLD, 0.9)
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
    """无人机换皮「吊斗浮游机」38x42（悬浮）。
    侧视语义：扁旋盘体+下吊矿斗+顶灯，盘缘下三根天线。
    骨架：眼 (12,14.4)=halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。"""
    s = Svg(38, 42)
    # 顶部灯穗
    s.line(20, 5.5, 20, 3.2, GAP, 1.2)
    s.circle(20, 2.8, 1.2, GOLD, 0.9)
    # 扁旋盘体
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
    # 腹挂矿斗（吊运读法）
    s.rect(18, 31, 2.5, 3, GAP)
    s.poly([(15, 34), (24, 34), (22, 40), (17, 40)], BELLY)
    s.poly([(15, 34), (24, 34), (23.4, 35.6), (15.6, 35.6)], BODY, 0.9)
    s.circle(19.5, 37, 1.4, GOLD, 0.85)
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
    """盾卫换皮「挡墙盾卫」56x52，地面 y=50。
    比例账沿五章：通高塔盾 4..25 x 10..47 + 后置舱体 25..49 x 10..42 + 双足。
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
# 精英「锚桩」：打桩架缆车（预教电网闸）
# ============================================================
def elite_body():
    """精英「锚桩」打桩车 60x80，地面 y=80。
    比例账（按能力反推）：电网桩 Ø14 级出膛 → 双桩炮架（朝天固定射角，管口
    画布 (44,6) 邻域）→ 炮架基座 (38..52, 8..40) + 绞盘鼓；轮式底盘（三轮
    踏地 y78）+ 车体 (4..58, 40..64) + 驾驶眼塔。
    锚点：眼 (19,26.5)=halo r5.3/core r2.4；ArmPivot 画布 (44,12)→局部
    (14,-28)（炮架臂独立件，固定射角不俯仰，Muzzle=臂局部 (0,-34)）。"""
    s = Svg(60, 80)
    # ---- 轮式底盘（三轮，踏地 y78）----
    s.rect(4, 58, 54, 8, BELLY)                       # 底梁
    for wx, wy, r in ((14, 70, 8), (32, 72, 7), (48, 70, 8)):
        s.circle(wx, wy, r, GAP)
        s.circle(wx, wy, r - 3.2, BODY)
        s.circle(wx, wy, 1.6, BELLY, 0.9)
    # ---- 车体（工程平板）----
    s.poly([(4, 42), (58, 42), (58, 58), (4, 58)], BODY)
    s.poly([(4, 42), (58, 42), (57, 44.5), (5, 44.5)], LIGHT, 0.7)
    for i, hx in enumerate(range(22, 56, 6)):         # 危险黄警示带
        s.rect(hx, 52, 2.5, 3.5, YELLOW if i % 2 == 0 else GAP, 0.8)
    # 尾部缆桩料箱 + 位标灯
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
    # ---- 炮架基座（能力签名件；双桩管=臂独立件；基座从车体顶收到塔环）----
    s.poly([(38, 44), (52, 44), (50, 14), (40, 14)], BODY)   # 基座（落地）
    s.rect(40, 12, 12, 2.5, LIGHT)
    s.circle(44, 12, 4.5, GAP)                               # 塔环（=ArmPivot）
    s.circle(44, 12, 2.2, BELLY)
    s.circle(50, 7, 1.3, WHITE_HOT, 0.9)                     # 就绪白热灯
    # ---- 绞盘鼓（架缆读法：缆线绕鼓下到料箱）----
    s.circle(34, 50, 4.2, BELLY)
    s.circle(34, 50, 2.2, BODY)
    s.line(34, 54, 52, 60, GAP, 1.2, 0.8)
    return s


def elite_arm():
    """精英双桩炮架 34x44（固定射角，不俯仰）。枢端画布 (17,40)=炮架塔环；
    双管朝天（-Y），管口画布 (17,6)=Muzzle（臂局部 (0,-34)）。
    出膛焰/预警闪光都落管口（真实枪口律）。"""
    s = Svg(34, 44)
    s.rect(10, 36, 14, 8, BELLY)                 # 枢座
    s.circle(17, 40, 3.0, BELLY)                 # 枢环（=枢端画布 (17,40)）
    s.rect(9, 16, 16, 22, BODY)                  # 架体
    s.rect(9, 16, 16, 2.5, LIGHT)
    s.rect(11, 4, 4.6, 18, GAP)                  # 左管（朝天）
    s.rect(18.4, 4, 4.6, 18, GAP)                # 右管
    s.rect(10, 2, 6.6, 3.4, BODY)                # 左管口座
    s.rect(17.4, 2, 6.6, 3.4, BODY)              # 右管口座
    s.rect(11.8, 0.6, 3.0, 2.0, WHITE_HOT, 0.95) # 左管口白热
    s.rect(19.2, 0.6, 3.0, 2.0, WHITE_HOT, 0.95) # 右管口白热
    s.circle(27, 24, 1.2, YELLOW, 0.85)          # 架侧警示灯
    return s


# ============================================================
# BOSS「赤轮」：斗轮采集舰（电网闸 ⇄ 溜矿车 + 斗轮弹石）
# ============================================================
def boss_body():
    """BOSS 斗轮采集舰「赤轮」300x180=碰撞体 body_size，原点(150,90)，原生朝左。
    造型按能力布挂件：低矮宽驳船体（矿区采集驳）+ 独眼条带（沿用锚点）+
    艏部斗轮座（斗轮=独立旋转件 boss_red_wheel，画布 (44,120)）+ 背甲双桩
    炮座（炮架=独立件 boss_red_rack，画布 (210,38)）+ 腹舱口（BayPort 画布
    (150,170)，溜矿车出舱）+ 船底双举升风扇位（风扇=通用 fx_flame，画布
    (120,154)/(230,154)）。"""
    s = Svg(300, 180)
    # ---- 船体（低矮宽驳；艏部下切给斗轮座让位）----
    s.poly([(10, 88), (42, 62), (140, 56), (238, 58), (286, 68), (294, 90),
            (288, 122), (244, 146), (186, 162), (118, 164), (64, 154),
            (22, 126)], BODY)
    s.poly([(42, 62), (140, 56), (238, 58), (282, 67), (278, 74), (236, 64),
            (140, 62), (48, 68)], LIGHT, 0.7)
    # 舷侧压暗 + 板缝
    s.poly([(22, 126), (64, 154), (118, 164), (186, 162), (240, 146),
            (230, 138), (120, 152), (66, 140), (30, 118)], BELLY)
    s.rect(130, 60, 2.5, 96, GAP, 0.3)
    s.rect(206, 62, 2.5, 88, GAP, 0.35)
    s.rect(60, 96, 180, 2, GAP, 0.3)
    # 舷窗带（矿灯金）
    for wx in range(158, 232, 16):
        s.rect(wx, 74, 7, 6, GOLD, 0.8)
    # ---- 艏部斗轮座（斗轮=独立件 boss_red_wheel，轮毂画布 (44,120)）----
    s.poly([(24, 96), (72, 96), (78, 140), (40, 146)], BELLY)      # 座架
    s.circle(44, 120, 7, GAP)                                      # 轮毂环
    s.circle(44, 120, 3.4, BELLY)
    s.rect(70, 100, 10, 3, LIGHT, 0.7)
    # ---- 背甲双桩炮座（炮架=独立件 boss_red_rack，画布 (210,38)）----
    s.rect(188, 46, 44, 14, BELLY)             # 座环裙
    s.rect(190, 44, 40, 3, LIGHT, 0.7)
    s.circle(210, 52, 2, WHITE_HOT, 0.9)       # 就绪白热灯（座侧）
    # ---- 腹舱口（BayPort 画布 (150,170)：溜矿车出舱）----
    s.rect(126, 148, 48, 16, GAP)              # 舱门槽
    s.rect(126, 148, 48, 3, LIGHT, 0.5)
    s.rect(132, 156, 36, 8, "#241008")         # 舱口（深腔）
    s.circle(150, 144, 1.8, YELLOW, 0.9)       # 舱口位标灯
    # ---- 船底双举升风扇位（风扇独件画布 (120,154)/(230,154)）----
    s.rect(108, 148, 24, 10, BELLY)
    s.rect(218, 142, 24, 10, BELLY)
    # ---- 艏锥 + 独眼条带（沿用锚点 y60..66 含 (55,63)）----
    s.poly([(0, 86), (14, 76), (20, 76), (20, 100), (6, 94)], BELLY)
    s.line(0, 86, 6, 94, LIGHT, 2, 0.7)
    s.rect(38, 57, 34, 12, RED, 0.18)
    s.rect(42, 60, 26, 6, RED, 0.95)
    # 驾驶舱框
    s.poly([(78, 58), (114, 56), (112, 70), (82, 72)], GAP, 0.9)
    s.poly([(80, 60), (110, 58), (109, 62), (82, 64)], LIGHT, 0.5)
    # ---- 中部输送拱棚（装料读法）----
    s.poly([(120, 44), (176, 44), (170, 34), (126, 34)], BELLY)
    s.line(126, 34, 170, 34, LIGHT, 1.6, 0.7)
    # ---- 侧舷识别条 ----
    s.rect(130, 80, 26, 3, RED, 0.8)
    # 危险黄警示带（舷侧）
    for i, hx in enumerate(range(88, 116, 7)):
        s.rect(hx, 128, 3, 4, YELLOW if i % 2 == 0 else GAP, 0.8)
    return s


def boss_wheel():
    """BOSS 斗轮 120x120（独立旋转件，中心 (60,60)=轮毂）。轮缘 r54（最低
    点=局部 +84：世界 370+84=454，bob 后对最高台阶 536 净空 76 ✓）；8 辐条
    +轮缘铲斗，铲斗沿口两处矿灯金热斑（采掘高温读法）。旋转由代码驱动
    （_tick_visual，恒转+直射加速）。"""
    s = Svg(120, 120)
    cx, cy, r = 60.0, 60.0, 54.0
    s.circle(cx, cy, r + 4, GAP)                       # 轮缘外圈
    s.circle(cx, cy, r - 10, BELLY, 0.55)              # 轮内暗盘（微透）
    for i in range(8):                                 # 辐条 + 铲斗
        aa = i * math.pi / 4.0
        s.line(cx, cy, cx + (r - 8) * math.cos(aa), cy + (r - 8) * math.sin(aa),
               BODY, 5.0)
        bx = cx + (r + 1) * math.cos(aa)
        by = cy + (r + 1) * math.sin(aa)
        s.rect(bx - 9, by - 9, 18, 18, BODY)           # 铲斗（方斗）
        s.rect(bx - 9, by - 9, 18, 3.5, LIGHT, 0.8)    # 斗沿受光
    s.circle(cx, cy, 12, BELLY)                        # 轮毂
    s.circle(cx, cy, 5, GAP)
    # 矿灯金热斑（两处斗沿：采掘摩擦高温）
    hx = cx + (r + 1) * math.cos(2.2)
    hy = cy + (r + 1) * math.sin(2.2)
    s.circle(hx, hy, 3.2, GOLD, 0.9)
    hx2 = cx + (r + 1) * math.cos(2.2 + math.pi)
    hy2 = cy + (r + 1) * math.sin(2.2 + math.pi)
    s.circle(hx2, hy2, 2.4, GOLD, 0.75)
    return s


def boss_rack():
    """BOSS 双桩炮架 60x54（独立件，固定射角）。枢端画布 (30,50)=背甲炮座环；
    双管朝天（-Y）外张微角（视觉外张，弹道由解算负责），管口画布 (30,4)
    =Muzzle（架局部 (0,-46)）。出膛焰/预警闪光都落管口（真实枪口律）。"""
    s = Svg(60, 54)
    s.rect(18, 42, 24, 12, BELLY)                # 枢座
    s.circle(30, 50, 4.0, BELLY)                 # 枢环（=枢端画布 (30,50)）
    s.rect(16, 18, 28, 26, BODY)                 # 架体
    s.rect(16, 18, 28, 2.5, LIGHT)
    s.poly([(14, 20), (26, 2), (31, 4), (22, 22)], GAP)    # 左管（微外张）
    s.poly([(46, 20), (34, 2), (29, 4), (38, 22)], GAP)    # 右管
    s.rect(20, 0, 8.4, 4, BODY)                  # 左管口座
    s.rect(31.6, 0, 8.4, 4, BODY)                # 右管口座
    s.rect(22.4, 0, 3.6, 2.2, WHITE_HOT, 0.95)   # 左管口白热
    s.rect(33.6, 0, 3.6, 2.2, WHITE_HOT, 0.95)   # 右管口白热
    s.circle(48, 30, 1.4, YELLOW, 0.85)          # 架侧警示灯
    return s


# ============================================================
# 特效件
# ============================================================
def fx_chip():
    """斗轮弹石 22x12（+X=飞行方向）：红砂岩屑读法——暗壳岩体+受光棱面
    +微小热斑（暖沙底上靠暗壳剪影读，白热带不行=亮底吞白）。弹石小而钝，
    直瞄短梭的轻量读法（威胁=弹石密度不是单发）。red_chip.tscn=bullet.gd 纯换皮。"""
    s = Svg(22, 12)
    s.poly([(1, 6), (5, 2), (14, 1), (21, 5), (19, 10), (6, 11)], BELLY)
    s.poly([(5, 2), (14, 1), (19, 5), (12, 5)], BODY)      # 受光棱面
    s.circle(16, 7, 1.6, GOLD, 0.8)                        # 热斑
    return s


def fx_stake():
    """锚桩 46x14（+X=飞行方向）：打桩钢钉读法——桩尖朝前（+X 前缘）+尾部
    稳定翼+桩身白热充能环（蓄能时代码脉冲增亮=二段预警的弹上读法）。"""
    s = Svg(46, 14)
    s.rect(8, 4, 30, 6, BODY)                  # 桩身
    s.rect(8, 4, 30, 2, LIGHT, 0.8)
    s.poly([(36, 3), (45, 7), (36, 11)], GAP)  # 桩尖（+X）
    s.poly([(2, 1), (10, 4), (10, 10), (2, 13)], BELLY)   # 尾翼
    s.rect(0, 5, 4, 4, BODY)
    s.circle(30, 7, 2.6, WHITE_HOT, 0.95)      # 充能环（代码脉冲）
    s.circle(30, 7, 4.6, ARC_HI, 0.35)         # 充能晕
    return s


def fx_fence():
    """电幕竖直光带 8x200（纵向拉伸到幕高）：锯齿电弧读法——白热芯+
    蓝紫中带+深晕三层，锯齿由代码同一段折线生成三层宽度。暖沙底上蓝紫
    对比最大（章专属读法：白热会吞进亮底）。亮度脉冲由代码驱动
    （FlakShell 引信同款思路）。"""
    s = Svg(8, 200)
    amp, seg = 2.2, 16.0
    pts = []
    y = 2.0
    flip = 1.0
    while y < 198.0:
        pts.append((4.0 + flip * amp, y))
        flip = -flip
        y += seg

    def ribbon(width, color, opacity):
        pp = [(x - width * 0.5, y_) for x, y_ in pts]
        pp += [(x + width * 0.5, y_) for x, y_ in reversed(pts)]
        s.poly(pp, color, opacity)

    ribbon(7.0, ARC_DEEP, 0.45)
    ribbon(4.0, ARC_HI, 0.9)
    ribbon(1.6, WHITE_HOT, 1.0)
    return s


def fx_cart():
    """溜矿车 76x84（+X=滚向玩家=世界向左，行进反向时整层镜像）：
    矿斗车读法——梯形斗体+矿石堆+双轮+顶灯（白热顶灯=第一眼读法的
    主动读出件，滚进场就先看见灯）。碰撞 64x84。"""
    s = Svg(76, 84)
    # 矿石堆（斗口上）
    s.poly([(14, 34), (30, 22), (48, 20), (62, 32), (62, 38), (14, 38)], BELLY)
    for ox, oy in ((30, 26), (44, 24), (54, 30)):
        s.circle(ox, oy, 2.2, GOLD, 0.75)
    # 斗体（梯形，口宽底窄）
    s.poly([(8, 36), (68, 36), (60, 62), (16, 62)], BODY)
    s.poly([(8, 36), (68, 36), (66, 40), (10, 40)], LIGHT)
    for i, hx in enumerate(range(16, 60, 9)):     # 斗身警示带
        s.rect(hx, 46, 4, 5, YELLOW if i % 2 == 0 else GAP, 0.8)
    s.rect(14, 58, 48, 4, BELLY)                  # 斗底
    # 轮对
    for wx in (22, 54):
        s.circle(wx, 68, 8, GAP)
        s.circle(wx, 68, 4.4, BODY)
        s.circle(wx, 68, 1.6, BELLY)
    # 顶灯（白热读出件）
    s.rect(36, 12, 4, 10, GAP)
    s.circle(38, 9, 3.2, WHITE_HOT, 0.95)
    s.circle(38, 9, 5.6, GOLD, 0.35)
    return s


if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)
    save(walker_body(), "enemy_red_walker_body.svg", """第六章步行者换皮「矿巡步机」56x52，地面 y=50。
骨架：眼 (15.5,18.3)=halo r5.3/core r2.4；肩 joint (16,24)；前缘 x<6 留空。
造型：舱体胶囊+背顶矿灯+警示带（矿区守备涂装）。
色板：LIGHT #a85a3a/BODY #6e3424/BELLY #4e2418/GAP #33180e。""")
    save(walker_arm(), "enemy_red_walker_arm.svg", """第六章步行者枪臂 48x28。肩 joint (36,8)、枪口尖端 ~(2,15)
（Muzzle=臂画布 (6,15)）。速射炮（方匣机匣+消焰管）。""")
    save(drone_body(), "enemy_red_drone.svg", """第六章无人机换皮「吊斗浮游机」38x42（悬浮）。
骨架：眼 (12,14.4)=halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。
造型：扁旋盘体+盘缘天线×3+下吊舱+腹挂矿斗+顶灯。""")
    save(drone_arm(), "enemy_red_drone_arm.svg", """第六章无人机枪臂 32x16。肩 joint (28,8)、枪口尖端 ~(12,9.5)
（Muzzle=臂画布 (13,11)）。""")
    save(shield_body(), "enemy_red_shield_body.svg", """第六章盾卫换皮「挡墙盾卫」56x52，地面 y=50。
骨架：眼 (23.5,18.3)=halo r5.3/core r2.4；肩 joint (24,24)（复用本章枪臂）。
造型：通高塔盾（铆钉阵+警示斜带）+后置舱体+双足。""")
    save(elite_body(), "enemy_red_elite_body.svg", """第六章精英「锚桩」打桩车 60x80，地面 y=80。
骨架：眼 (19,26.5)=halo r5.3/core r2.4；ArmPivot 画布 (44,12)→局部 (14,-28)
（炮架臂独立件，固定射角不俯仰）。造型：轮式底盘+驾驶眼塔+炮架基座（塔环）
+绞盘鼓——打桩架缆车读法。提案=同目录 提案_v1_赤沙矿区.md §3。""")
    save(elite_arm(), "enemy_red_elite_arm.svg", """第六章精英双桩炮架 34x44（固定射角）。
枢端画布 (17,40)=炮架塔环；双管朝天，管口画布 (17,6)=Muzzle
（臂局部 (0,-34)）。出膛焰/预警闪光落管口（真实枪口律）。""")
    save(boss_body(), "boss_red_body.svg", """第六章 BOSS 斗轮采集舰「赤轮」300x180=碰撞体，原点(150,90)，原生朝左。
能力布挂件：艏部斗轮座（斗轮独立件画布 (44,120)=局部 (-106,30)）+
背甲双桩炮座（炮架独立件画布 (210,38)=局部 (60,-52)）+ 腹舱口（BayPort
画布 (150,170)=局部 (0,80)，溜矿车出舱）+ 船底风扇位（画布 (120,154)/
(230,154)=通用 fx_flame）。沿用锚点：独眼条带 y60..66 含 (55,63)。
提案=同目录 提案_v1_赤沙矿区.md §3。""")
    save(boss_wheel(), "boss_red_wheel.svg", """第六章 BOSS 斗轮 120x120（独立旋转件，中心 (60,60)=轮毂）。
轮缘 r54：局部最低点 +84=世界 454（bob 后对 t536 台阶净空 76）。
旋转由代码驱动（恒转+直射加速）；斗沿矿灯金热斑=采掘高温读法。""")
    save(boss_rack(), "boss_red_rack.svg", """第六章 BOSS 双桩炮架 60x54（独立件，固定射角）。
枢端画布 (30,50)=背甲炮座环；双管朝天微外张，管口画布 (30,4)
=Muzzle（架局部 (0,-46)）。出膛焰/预警闪光落管口（真实枪口律）。""")
    save(fx_chip(), "fx_red_chip.svg", """斗轮弹石 22x12（+X=飞行方向）：暗壳岩体+受光棱面+热斑
（亮沙底靠暗壳剪影读）。red_chip.tscn=bullet.gd 纯换皮。""")
    save(fx_stake(), "fx_red_stake.svg", """锚桩 46x14（+X=飞行方向）：桩尖朝前+尾翼+桩身白热充能环
（蓄能时代码脉冲增亮=二段预警的弹上读法）。""")
    save(fx_fence(), "fx_red_fence.svg", """电幕竖直光带 8x200（纵向拉伸到幕高）：锯齿电弧三层
（白热芯/蓝紫中带/深晕）——暖沙底上蓝紫对比最大。亮度脉冲由代码驱动。""")
    save(fx_cart(), "fx_red_cart.svg", """溜矿车 76x84（+X=滚向玩家，行进反向时整层镜像）：
梯形斗体+矿石堆+双轮+白热顶灯（第一眼读法的主动读出件）。碰撞 64x84。""")
    print("red desert chapter units baked.")
