# -*- coding: utf-8 -*-
"""第八章「镜盐之原」单位/特效烘焙：采盐与地热能力套件。

产物（assets/world_8/）：
  enemy_salt_walker_body.svg  56x52   步行者换皮「盐壳巡守」
  enemy_salt_walker_arm.svg   48x28   步行者枪臂
  enemy_salt_drone.svg        38x42   无人机换皮「盐田巡飞」
  enemy_salt_drone_arm.svg    32x16   无人机枪臂
  enemy_salt_shield_body.svg  56x52   盾卫换皮「盐垒盾卫」
  enemy_salt_elite_body.svg   60x80   精英「喷井」钻机车（预教间歇泉）
  enemy_salt_elite_arm.svg    34x44   精英钻塔（固定射角，臂不俯仰=锚桩家族位）
  boss_salt_body.svg          300x180 BOSS「盐磨」悬浮采盐联合机（泉幕+灼烤）
  boss_salt_wing.svg          96x44   BOSS 镜阵翼（俯仰真瞄=炮，翼尖聚焦口=Muzzle）
  fx_salt_dart.svg            16x8    裂地镖（小件快弹，读法归地面标记）
  fx_salt_mark.svg            140x40  地裂环纹 mark（预警主读出件+预漏白汽）
  fx_salt_column.svg          90x360  汽柱（顶在纹理 y=0，「柱是墙不是弹」）
  fx_salt_burn.svg            180x180 盐面灼白斑（r90 满幅，SlagPool 换皮视觉）
  fx_salt_glint.svg           48x48   光斑晕（ADD：灼烤光束线落点光斑）
  fx_salt_bolt.svg            36x16   融盐重弹（盐磨普攻点放，salt_bolt.tscn=bullet.gd 纯换皮）

锚点账（详账=提案_v1_镜盐之原.md §3；杂兵照 §3 基线逐像素对齐）：
  步行者：眼 (15.5,18.3)=halo r5.3/core r2.4；肩 joint (16,24)；地面 y=50；
          前缘 x<6 留空给枪臂。
  无人机：眼 (12,14.4)=halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。
  盾卫：  眼 (23.5,18.3)=halo r5.3/core r2.4；肩 joint (24,24)（复用本章枪臂）。
  精英：  眼 (19,26.5)=halo r5.3/core r2.4；ArmPivot=钻塔座画布 (44,12)→局部
          (14,-28)（锚桩家族位：固定射角不俯仰）；臂画布 34x44 枢端 (17,40)
          →offset(-17,-40)，钻头朝 -Y，钻尖画布 (17,6)=Muzzle 臂局部 (0,-34)。
          裂地镖从钻尖口出膛落地成 mark。
  BOSS：  独眼条带 y60..66 含 (55,63)（EyeGlow 节点 (-95,-27) 沿用；艏段甲板
          顶缘抬 y52..54 包住条带，ch6/ch7 同手法）；ArmPivot=镜阵翼枢画布
          (150,26)→局部 (0,-64)（俯仰真瞄=炮；翼画布 96x44 枢端 (78,22)
          →offset(-78,-22)，翼尖聚焦口画布 (10,22)=Muzzle 臂局部 (-68,0)；
          翼转=炮读法：蓄光时翼面泛粉）；BayPort=腹裂地锚口画布 (150,168)
          →局部 (0,78)（裂地镖出膛位，泉幕 mark 由镖落地生成）；举升喷口画布
          (110,156)/(210,156)=局部 (-40,66)/(60,66)（通用 fx_flame+加色杏金）。
          碰撞 280x150。
色板（提案 v1 §0：敌营墨青绿 #2e4a42 族，与走道带暖白灰/镜洼青绿三分色相）：
      LIGHT #4e6a5e / BODY #2e4a42 / BELLY #1e332e / GAP #142320
      + 信号黄 #d8a021 + 盐田粉 #f2789f（章信号色：盐渍/航旗/预警灯）
      + 独眼红 #ff4640 不变 + 白热 #f2f0ff + 白汽 #eef6f2
      + 镜洼青绿 #3fc9b0（泉语汇）+ 盐霜 #e8dcc0。
ThorVG 硬约束：无 filter/pattern/use/text/transform；无 rect+rotate。
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
from generate_proposals import Svg, f, glow_dot  # noqa: E402

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "world_8"))

LIGHT = "#4e6a5e"
BODY = "#2e4a42"
BELLY = "#1e332e"
GAP = "#142320"
RED = "#ff4640"
YELLOW = "#d8a021"
PINK = "#f2789f"        # 盐田粉（章信号色）
WHITE = "#f2f0ff"       # 白热
STEAM = "#eef6f2"       # 白汽
TEAL = "#3fc9b0"        # 镜洼青绿（泉语汇）
SALT = "#e8dcc0"        # 盐霜
MIRROR_GLASS = "#c8dcd4"  # 镜面
MIRROR_GLASS_DK = "#9fc4b8"


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


def _salt_fleck(s, rng, x0, y0, w, h, n=3):
    """盐霜斑（舱面小面积白渍，识别性涂装）。"""
    for _ in range(n):
        s.ellipse(x0 + rng.uniform(4, w - 4), y0 + rng.uniform(2, h - 2),
                  rng.uniform(3, 6), rng.uniform(1.2, 2.2), SALT,
                  rng.uniform(0.35, 0.6))


# ============================================================
# 杂兵三件套（骨架锚点=§3 基线，造型按盐田守备队重涂微调）
# ============================================================
def walker_body():
    """步行者换皮「盐壳巡守」56x52，地面 y=50。
    比例账沿七章骨架：舱体胶囊 5..46 x 12..33 + 背部双罐 + 逆关节双足踏地 y50；
    背顶信号灯=盐田粉（章信号色）。肩面盐霜斑（盐田守备识别涂装）。
    骨架：眼 (15.5,18.3)=halo r5.3/core r2.4；肩 joint (16,24)。前缘 x<6 留空。"""
    import random as _r
    rng = _r.Random(9101)
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
    _salt_fleck(s, rng, 20, 14, 22, 16, 3)              # 肩面盐霜
    # 背顶信号杆（盐田粉）
    s.poly([(26, 12), (29, 5), (31, 5), (29, 13)], BELLY)
    s.circle(30, 4.4, 1.4, PINK, 0.9)
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
    s.circle(33, 13.5, 1.3, PINK, 0.9)
    return s


def drone_body():
    """无人机换皮「盐田巡飞」38x42（悬浮）。
    侧视语义：扁旋盘体+下吊舱+腹挂盐料斗（采盐读法）+顶灯（盐田粉）。
    骨架：眼 (12,14.4)=halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。"""
    s = Svg(38, 42)
    # 顶部灯穗（盐田粉）
    s.line(20, 5.5, 20, 3.2, GAP, 1.2)
    s.circle(20, 2.8, 1.2, PINK, 0.9)
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
    # 腹挂盐料斗（采盐读法：斗里盐尖）
    s.rect(18, 31, 2.5, 3, GAP)
    s.poly([(15, 34), (24, 34), (22, 40), (17, 40)], BELLY)
    s.poly([(17, 34), (22, 34), (21, 37), (18, 37)], SALT, 0.9)
    s.circle(19.5, 36, 1.2, PINK, 0.85)
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
    s.circle(25, 10.5, 1.0, PINK, 0.9)
    return s


def shield_body():
    """盾卫换皮「盐垒盾卫」56x52，地面 y=50。
    比例账沿七章：通高塔盾 4..25 x 10..47 + 后置舱体 25..49 x 10..42 + 双足。
    盾面=盐垒语汇（盐壳横缝层理+龟裂亮纹+盐田粉警示斜带）。
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
    # 塔盾（盐垒面：横缝层理 + 龟裂亮纹 + 盐田粉警示斜带）
    s.poly([(5, 10), (22, 10), (25, 14), (25, 44), (21, 47), (7, 47), (4, 42), (4, 14)], BODY)
    s.poly([(4, 14), (7, 11.5), (7, 45), (4, 40)], LIGHT, 0.6)
    for sy in (16, 22, 28, 34, 40):      # 横缝层理
        s.line(6, sy, 23, sy + 1, BELLY, 1.6, 0.7)
    for cx2, cy2, ex, ey in ((12, 18, 17, 24), (9, 30, 15, 36)):  # 龟裂亮纹（盐壳）
        s.line(cx2, cy2, ex, ey, SALT, 1.2, 0.6)
    for rx_ in (19, 27, 35):             # 结晶点对
        s.circle(11, rx_ + 2, 1.6, SALT, 0.7)
        s.circle(18, rx_ - 2, 1.6, SALT, 0.7)
    s.line(8, 44, 20, 30, PINK, 2.2, 0.75)
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
    s.rect(32, 34, 9, 2.5, PINK, 0.8)
    return s


# ============================================================
# 精英「喷井」：钻机车（预教间歇泉）
# ============================================================
def elite_body():
    """精英「喷井」钻机车 60x80，地面 y=80。
    比例账（按能力反推）：钻塔基座（塔状，钻臂=独立件竖在塔环上）→ 塔座基
    (38..52, 8..40) + 绞盘鼓；轮式底盘（三轮踏地 y78）+ 车体 (4..58, 40..64)
    + 驾驶眼塔。
    锚点：眼 (19,26.5)=halo r5.3/core r2.4；ArmPivot 画布 (44,12)→局部
    (14,-28)（钻塔座塔环；钻塔独立件固定射角不俯仰=锚桩家族账，
    Muzzle=臂局部 (0,-34)）。"""
    s = Svg(60, 80)
    # ---- 轮式底盘（三轮，踏地 y78）----
    s.rect(4, 58, 54, 8, BELLY)                       # 底梁
    for wx, wy, r in ((14, 70, 8), (32, 72, 7), (48, 70, 8)):
        s.circle(wx, wy, r, GAP)
        s.circle(wx, wy, r - 3.2, BODY)
        s.circle(wx, wy, 1.6, BELLY, 0.9)
    # ---- 车体（采盐平板车）----
    s.poly([(4, 42), (58, 42), (58, 58), (4, 58)], BODY)
    s.poly([(4, 42), (58, 42), (57, 44.5), (5, 44.5)], LIGHT, 0.7)
    for i, hx in enumerate(range(22, 56, 6)):         # 危险黄警示带
        s.rect(hx, 52, 2.5, 3.5, YELLOW if i % 2 == 0 else GAP, 0.8)
    # 尾部盐料箱 + 位标灯（盐田粉）
    s.rect(52, 34, 6, 10, BELLY)
    s.circle(55, 32, 1.4, PINK, 0.9)
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
    # ---- 钻塔基座（能力签名件；钻塔=臂独立件竖在塔环上；塔架三角面）----
    s.poly([(38, 44), (52, 44), (50, 14), (40, 14)], BODY)   # 基座（落地）
    s.rect(40, 12, 12, 2.5, LIGHT)
    s.circle(44, 12, 4.5, GAP)                               # 塔环（=ArmPivot）
    s.circle(44, 12, 2.2, BELLY)
    s.circle(50, 7, 1.3, WHITE, 0.9)                         # 就绪白热灯
    # ---- 绞盘鼓（缆线读法）----
    s.circle(34, 50, 4.2, BELLY)
    s.circle(34, 50, 2.2, BODY)
    s.line(34, 54, 52, 60, GAP, 1.2, 0.8)
    return s


def elite_arm():
    """精英钻塔 34x44（固定射角，臂不俯仰=锚桩家族）。枢端画布 (17,40)=钻塔座
    塔环；A 字塔架向上收拢，钻杆中轴（ guides 夹持），钻尖画布 (17,6)
    =Muzzle（臂局部 (0,-34)）。裂地镖从钻尖口垂直上抛落地成 mark（弹小快，
    读法归地面标记）。出膛焰/预警闪光都落钻尖（真实枪口律）。"""
    s = Svg(34, 44)
    s.rect(11, 34, 12, 9, BELLY)                 # 枢座
    s.circle(17, 40, 3.4, BELLY)                 # 枢环（=枢端画布 (17,40)）
    s.poly([(6, 40), (17, 8), (28, 40)], BODY)   # A 字塔架（两腿+顶）
    s.line(8.5, 38, 17, 10, LIGHT, 2, 0.9)
    s.line(25.5, 38, 17, 10, LIGHT, 2, 0.9)
    for gy in (16, 22, 28):                      # 横撑
        s.line(17 - (40 - gy) * 0.28, gy, 17 + (40 - gy) * 0.28, gy, BODY, 2, 0.9)
    s.rect(15, 8, 4, 30, GAP)                    # 钻杆中轴
    s.rect(16.2, 10, 1.6, 26, LIGHT, 0.7)        # 杆面受光
    s.poly([(17, 0), (20.4, 6), (13.6, 6)], WHITE, 0.95)   # 钻尖（白热）
    s.circle(24, 30, 1.2, PINK, 0.85)            # 塔腿位标灯
    return s


# ============================================================
# BOSS「盐磨」：悬浮采盐联合机（间歇泉幕 ⇄ 定镜灼烤 + 盐晶弹）
# ============================================================
def boss_body():
    """BOSS 悬浮采盐联合机「盐磨」300x180=碰撞体 body_size，原点(150,90)，
    原生朝左。造型按能力布挂件：低宽采盐联合机体（艏部斗轮鼓罩=采盐语汇
    +驾驶楼+舷侧盐料斗）+ 独眼条带（沿用锚点；**艏段甲板顶缘抬 y52..54
    包住条带 y57..69**，ch6/ch7 同手法）+ 镜阵翼枢座（翼=独立件
    boss_salt_wing，画布 (150,26)）+ 腹裂地锚口（BayPort 画布 (150,168)，
    裂地镖由此出膛落地成 mark）+ 船底双举升喷口位（喷口=通用 fx_flame，
    画布 (110,156)/(210,156)）。
    连接账（ch6 顶挂件教训全沿用）：翼枢座裙底埋进甲板顶缘 ≥2px、顶托翼枢座
    （翼画布 y4..48 与裙 28..54 重叠段被翼盖住=接缝归零）。"""
    s = Svg(300, 180)
    # ---- 船体（低宽联合机；艏段顶缘抬高包条带）----
    s.poly([(8, 84), (36, 54), (140, 52), (238, 56), (286, 66), (294, 90),
            (288, 122), (244, 146), (186, 162), (118, 164), (64, 154),
            (22, 126)], BODY)
    s.poly([(36, 54), (140, 52), (238, 56), (282, 65), (278, 71), (236, 62),
            (140, 58), (42, 60)], LIGHT, 0.7)
    # 舷侧压暗 + 板缝
    s.poly([(22, 126), (64, 154), (118, 164), (186, 162), (240, 146),
            (230, 138), (120, 152), (66, 140), (30, 118)], BELLY)
    s.rect(130, 60, 2.5, 96, GAP, 0.3)
    s.rect(206, 62, 2.5, 88, GAP, 0.35)
    s.rect(60, 92, 170, 2, GAP, 0.3)
    # 舷窗带（暖光=还在开机）
    for wx in range(158, 232, 16):
        s.rect(wx, 74, 7, 6, "#f0d0a8", 0.75)
    # ---- 艏部斗轮鼓罩（采盐语汇签名件：半圆鼓包在艏甲板上）----
    s.path("M 30 66 A 30 30 0 0 1 90 66 L 90 84 L 30 84 Z", fill=BODY, opacity=0.95)
    s.path("M 36 66 A 24 24 0 0 1 84 66", stroke=LIGHT, w=2.4, opacity=0.7)
    s.line(42, 62, 42, 84, GAP, 2.2, 0.5)
    s.line(60, 56, 60, 84, GAP, 2.2, 0.5)
    s.line(78, 62, 78, 84, GAP, 2.2, 0.5)
    s.circle(60, 66, 6, BELLY)                   # 鼓毂
    s.circle(60, 66, 2.6, LIGHT, 0.9)
    # ---- 镜阵翼枢座（翼=独立件 boss_salt_wing，画布 (150,26)）：座裙
    #      x136..164 y28..54——底边 54 埋进甲板顶缘（该处 52..54，埋 ≥2px）、
    #      顶 28 托住翼枢座（翼画布 y4..48 重叠段被翼盖住=接缝归零）----
    s.rect(136, 28, 28, 26, BELLY)              # 座环裙
    s.rect(138, 26, 24, 3, LIGHT, 0.7)
    s.circle(172, 36, 1.8, WHITE, 0.9)          # 就绪白热灯（座侧）
    # ---- 腹裂地锚口（BayPort 画布 (150,168)：裂地镖出膛位）----
    s.rect(128, 150, 44, 14, GAP)               # 舱门槽
    s.rect(128, 150, 44, 3, LIGHT, 0.5)
    s.rect(134, 158, 32, 7, "#0d1a15")          # 舱口（深腔）
    for gx in range(140, 164, 8):               # 锚口格栅
        s.line(gx, 158, gx, 165, BELLY, 1.6, 0.9)
    s.circle(150, 146, 1.8, PINK, 0.9)          # 舱口位标灯（盐田粉）
    # ---- 驾驶楼（坐在抬高的艏甲板上，亮窗=还在开机）----
    s.poly([(78, 48), (114, 46), (112, 64), (82, 66)], GAP, 0.9)
    s.poly([(84, 50), (108, 48), (107, 54), (86, 55)], "#f0d0a8", 0.6)
    glow_dot(s, 96, 42, PINK, r=2.0, halos=((5, 0.35), (9, 0.13)))  # 楼顶信号灯
    # ---- 舷侧盐料斗（采盐读法：斗口盐尖）----
    s.poly([(190, 96), (232, 96), (226, 122), (196, 122)], BELLY)
    s.poly([(196, 96), (226, 96), (222, 104), (200, 104)], SALT, 0.85)
    s.circle(211, 110, 1.4, PINK, 0.8)
    # ---- 船底双举升喷口位（喷口独件画布 (110,156)/(210,156)）----
    s.rect(98, 148, 24, 10, BELLY)
    s.rect(198, 142, 24, 10, BELLY)
    # ---- 艏锥 + 独眼条带（沿用锚点 y60..66 含 (55,63)；甲板已抬 y52..54
    #      包住条带，不戳出轮廓）----
    s.poly([(0, 82), (14, 74), (20, 74), (20, 98), (6, 92)], BELLY)
    s.line(0, 82, 6, 92, LIGHT, 2, 0.7)
    s.rect(38, 57, 34, 12, RED, 0.18)
    s.rect(42, 60, 26, 6, RED, 0.95)
    # ---- 侧舷绞盘（缆线到腹口）----
    s.circle(170, 100, 6, BELLY)
    s.circle(170, 100, 3, BODY)
    s.line(170, 106, 152, 150, GAP, 1.2, 0.75)
    # ---- 侧舷识别条 + 盐霜 ----
    s.rect(130, 80, 26, 3, PINK, 0.8)
    for i, hx in enumerate(range(88, 116, 7)):
        s.rect(hx, 128, 3, 4, YELLOW if i % 2 == 0 else GAP, 0.8)
    import random as _r
    rng = _r.Random(9110)
    for fx2 in (100, 150, 250):
        s.ellipse(fx2, rng.uniform(140, 156), rng.uniform(10, 16), 3, SALT, 0.4)
    return s


def boss_wing():
    """BOSS 镜阵翼 96x44（独立件，俯仰真瞄=炮）。枢端画布 (78,22)=镜阵翼枢；
    两片镜面成 V 张开朝 -X（蓄能闪光读法：镜面浅青白+受光棱线），翼尖聚焦口
    画布 (10,22)=Muzzle（臂局部 (-68,0)）：聚焦透镜圈+白热芯+盐田粉镜晕
    （灼烤蓄光时整翼泛粉由代码驱动 modulate）。出膛焰/预警/光束源都在聚焦口
    （真实枪口律）。"""
    s = Svg(96, 44)
    # V 形镜面两片（上片长、下片短=不对称读法）
    s.poly([(10, 20), (52, 6), (74, 14), (74, 30), (52, 22)], MIRROR_GLASS, 0.95)
    s.poly([(12, 26), (50, 26), (72, 34), (70, 40), (48, 34), (14, 32)],
           MIRROR_GLASS_DK, 0.95)
    # 镜面棱线（受光）
    s.line(12, 20, 52, 8, WHITE, 1.6, 0.8)
    s.line(16, 28, 50, 30, WHITE, 1.2, 0.6)
    # 镜面分割框
    s.line(34, 12, 36, 22, MIRROR_GLASS_DK, 1.8, 0.9)
    s.line(52, 10, 54, 20, MIRROR_GLASS_DK, 1.8, 0.9)
    s.line(40, 28, 42, 34, MIRROR_GLASS_DK, 1.6, 0.9)
    # 背架（连接枢端的暗骨架）
    s.line(50, 20, 78, 20, BODY, 5, 0.95)
    s.line(56, 30, 78, 26, BODY, 3.4, 0.95)
    # 枢座（=枢端画布 (78,22)）
    s.rect(74, 12, 10, 18, BELLY)
    s.circle(78, 22, 4.4, BELLY)
    s.circle(78, 22, 2.0, LIGHT)
    # 翼尖聚焦口（=Muzzle 画布 (10,22)）：透镜圈+白热芯
    s.circle(14, 22, 7, BELLY)
    s.circle(12, 22, 5, BODY)
    s.circle(10, 22, 3.2, WHITE, 0.95)
    s.circle(10, 22, 1.6, PINK, 0.9)             # 镜晕（盐田粉=蓄光预告色）
    s.circle(30, 14, 1.2, PINK, 0.8)             # 翼面位标灯
    return s


# ============================================================
# 特效件
# ============================================================
def fx_dart():
    """裂地镖 16x8（+X=飞行方向）：小件快弹（弹体小 12×6 快速一闪即落，
    读法归地面标记本身=提案 §1）。暗壳镖身+白热镖尖+盐田粉尾带。"""
    s = Svg(16, 8)
    s.poly([(1, 2.5), (11, 2), (15, 4), (11, 6), (1, 5.5)], BELLY)  # 镖身
    s.poly([(11, 2), (15, 4), (11, 6)], GAP)                        # 镖头棱面
    s.rect(1, 3.2, 3, 1.6, PINK, 0.9)                               # 尾带
    s.circle(14.4, 4, 1.1, WHITE, 0.95)                             # 镖尖白热
    return s


def fx_mark():
    """地裂环纹 mark 140x40（中心=落点）：间歇泉预警主读出件——地裂环纹
    （暗环+放射裂缝）+ 盐田粉蓄能环（渐急由代码驱动 alpha/scale）+ 预漏
    白汽（中缝小汽苗，预告「这里要喷」）。落在地表上（椭圆扁环贴地读法）。"""
    s = Svg(140, 40)
    cx, cy = 70.0, 26.0
    # 地裂外环（暗）
    s.ellipse(cx, cy, 56, 10, GAP, 0.55)
    s.ellipse(cx, cy, 40, 7, "#0d1a15", 0.75)
    # 环内盐面翻开（浅）
    s.ellipse(cx, cy, 30, 5, BELLY, 0.9)
    # 放射裂缝 ×8
    import math as _m
    for i in range(8):
        ang = i * math.pi / 4.0 + 0.35
        dx = _m.cos(ang)
        dy = _m.sin(ang) * 0.32
        s.line(cx + dx * 30, cy + dy * 30, cx + dx * 54, cy + dy * 54, GAP, 2.4, 0.8)
        s.line(cx + dx * 34, cy + dy * 34, cx + dx * 44, cy + dy * 34 + 3, LIGHT, 1.2, 0.5)
    # 蓄能粉环（代码驱动渐急）
    s.ellipse(cx, cy, 44, 8, PINK, 0.4)
    # 预漏白汽（中缝汽苗 ×3）
    s.ellipse(cx - 8, 8, 4, 7, STEAM, 0.7)
    s.ellipse(cx, 5, 5, 8, STEAM, 0.8)
    s.ellipse(cx + 8, 9, 3.4, 6, STEAM, 0.6)
    return s


def fx_column():
    """汽柱 90x360（**柱顶在纹理 y=0**——节点把顶钉在地表−360，柱体向下
    延满 360）：「柱是墙不是弹」的主读出件——宽幅白汽墙（分层汽柱体，
    alpha 烘在色里 0.78+）+ 撕裂缘 + 底部喷发外扩裙。普通混合不 ADD：
    墙要读出实体遮挡感。纯跳 67 << 柱高 360=第一眼「别跳，跑」。"""
    import random as _r
    rng = _r.Random(9105)
    s = Svg(90, 360)
    # 柱体分层（三列汽流，中列最实）
    body = s.vgrad("col", [(0, STEAM, 0.6), (0.35, STEAM, 0.86),
                           (0.85, STEAM, 0.92), (1, STEAM, 0.7)])
    s.rect(18, 0, 54, 360, body)
    s.rect(8, 30, 16, 330, STEAM, 0.6)           # 左列（撕裂缘）
    s.rect(66, 24, 16, 336, STEAM, 0.6)          # 右列
    # 撕裂缘（汽团凸起）
    for _ in range(14):
        cx2 = rng.choice([10.0, 24.0, 66.0, 80.0])
        cy2 = rng.uniform(20, 350)
        s.ellipse(cx2, cy2, rng.uniform(5, 10), rng.uniform(12, 26), STEAM,
                  rng.uniform(0.5, 0.75))
    # 汽流竖纹（白亮芯，越上越密）
    for _ in range(16):
        sx = rng.uniform(24, 66)
        sy = rng.uniform(0, 300)
        ln = rng.uniform(40, 120)
        s.line(sx, sy, sx + rng.uniform(-3, 3), sy + ln, WHITE,
               rng.uniform(1.6, 3.0), rng.uniform(0.25, 0.5))
    # 底部喷发外扩裙（喷口压强读法）
    s.ellipse(45, 348, 42, 14, STEAM, 0.8)
    s.ellipse(45, 344, 28, 9, WHITE, 0.75)
    # 底部泉眼青绿光（镜洼热泉语汇）
    s.ellipse(45, 352, 20, 6, TEAL, 0.5)
    return s


def fx_burn():
    """盐面灼白斑 180x180（r90 满幅，中心=灼点；SlagPool 换皮视觉按判定半径
    缩放）：白热灼斑+盐壳龟裂缘+盐田粉热晕芯——「干燥光束烧过的地方」。
    蒸汽由 MirrorBurn 代码补间汽苗件。"""
    import math as _m
    s = Svg(180, 180)
    cx, cy = 90.0, 90.0
    s.glow_ellipse(cx, cy, 86, 86, WHITE, 0.32)          # 热晕外圈
    s.circle(cx, cy, 62, SALT, 0.9)                      # 灼斑体（盐白）
    s.circle(cx, cy, 46, WHITE, 0.9)                     # 白热芯
    s.circle(cx, cy, 22, "#ffe8ec", 0.9)                 # 粉热芯（盐田粉热）
    # 龟裂缘（放射裂块）
    for i in range(12):
        ang = i * math.pi / 6.0 + 0.26
        dx = _m.cos(ang)
        dy = _m.sin(ang)
        s.line(cx + dx * 50, cy + dy * 50, cx + dx * 68, cy + dy * 68, "#b8a888", 2.6, 0.8)
        s.line(cx + dx * 58, cy + dy * 58, cx + dx * 74, cy + dy * 74, "#8a7a62", 1.6, 0.6)
    # 斑缘结晶点
    for i in range(8):
        ang = i * math.pi / 4.0 + 0.6
        dx = _m.cos(ang)
        dy = _m.sin(ang)
        s.circle(cx + dx * 60, cy + dy * 60, 3, SALT, 0.9)
    return s


def fx_glint():
	"""光斑晕 48x48（径向软晕，ADD 叠亮）：白粉双层——干燥光束线的落点光斑
	+ mark 蓄能点缀共用。脉冲由代码驱动。"""
	s = Svg(48, 48)
	s.glow_ellipse(24, 24, 22, 22, PINK, 0.4)
	s.glow_ellipse(24, 24, 9, 9, WHITE, 0.95)
	return s


def fx_molten_bolt():
	"""融盐重弹 36x16（+X=飞行方向；盐磨普攻点放，salt_bolt.tscn=bullet.gd 纯
	换皮，照 slag_slug 账）：镜阵聚热熔出的盐弹——暗盐壳压底（黄昏暖调天上靠
	暗壳剪影读，同 ch2 熔渣重弹「焦壳压暗才读成有壳的熔渣」）+ 熔芯裂缝透光
	（杏金熔）+ 白热熔芯弹头 + 盐田粉热晕尾带（章信号色）。普通混合不 ADD。"""
	s = Svg(36, 16)
	s.poly([(3, 3.5), (24, 2.5), (33, 6), (33, 10), (24, 13.5), (3, 12.5)], "#3a2c22")  # 暗盐壳
	s.poly([(24, 2.5), (33, 6), (33, 10), (24, 13.5), (28, 8)], "#574434", 0.9)          # 壳前棱面
	s.line(8, 4.5, 12, 11.5, "#ffb050", 2.2, 0.9)                                        # 熔芯裂缝×3
	s.line(15, 3.5, 18, 12.5, "#ffc870", 1.8, 0.85)
	s.line(21, 4, 23.5, 12, "#ffb050", 1.6, 0.8)
	s.ellipse(29.5, 8, 4.5, 5, "#fff2d8", 0.95)                                          # 白热熔芯头
	s.circle(31.5, 8, 2, WHITE, 0.95)
	s.rect(2, 5.5, 5, 5, PINK, 0.75)                                                     # 盐田粉热晕尾带
	s.rect(0.5, 6.5, 2.5, 3, PINK, 0.5)                                                  # 尾焰残迹
	return s


if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)
    save(walker_body(), "enemy_salt_walker_body.svg", """第八章步行者换皮「盐壳巡守」56x52，地面 y=50。
骨架：眼 (15.5,18.3)=halo r5.3/core r2.4；肩 joint (16,24)；前缘 x<6 留空。
造型：舱体胶囊+背顶信号灯（盐田粉）+肩面盐霜斑（盐田守备涂装）。
色板：LIGHT #4e6a5e/BODY #2e4a42/BELLY #1e332e/GAP #142320。""")
    save(walker_arm(), "enemy_salt_walker_arm.svg", """第八章步行者枪臂 48x28。肩 joint (36,8)、枪口尖端 ~(2,15)
（Muzzle=臂画布 (6,15)）。速射炮（方匣机匣+消焰管）。""")
    save(drone_body(), "enemy_salt_drone.svg", """第八章无人机换皮「盐田巡飞」38x42（悬浮）。
骨架：眼 (12,14.4)=halo r4.4/core r2.0；ArmPivot 画布 (15.2,21)。
造型：扁旋盘体+盘缘天线×3+下吊舱+腹挂盐料斗（采盐读法）+顶灯。""")
    save(drone_arm(), "enemy_salt_drone_arm.svg", """第八章无人机枪臂 32x16。肩 joint (28,8)、枪口尖端 ~(12,9.5)
（Muzzle=臂画布 (13,11)）。""")
    save(shield_body(), "enemy_salt_shield_body.svg", """第八章盾卫换皮「盐垒盾卫」56x52，地面 y=50。
骨架：眼 (23.5,18.3)=halo r5.3/core r2.4；肩 joint (24,24)（复用本章枪臂）。
造型：盐垒塔盾（横缝层理+龟裂亮纹+盐田粉警示斜带）+后置舱体+双足。""")
    save(elite_body(), "enemy_salt_elite_body.svg", """第八章精英「喷井」钻机车 60x80，地面 y=80。
骨架：眼 (19,26.5)=halo r5.3/core r2.4；ArmPivot 画布 (44,12)→局部 (14,-28)
（钻塔座塔环；钻塔独立件固定射角不俯仰=锚桩家族账）。
造型：轮式底盘+驾驶眼塔+钻塔基座+绞盘鼓+尾部盐料箱——钻机车读法。
提案=同目录 提案_v1_镜盐之原.md §3。""")
    save(elite_arm(), "enemy_salt_elite_arm.svg", """第八章精英钻塔 34x44（固定射角，臂不俯仰）。
枢端画布 (17,40)=钻塔座塔环；A 字塔架+钻杆中轴，钻尖画布 (17,6)=Muzzle
（臂局部 (0,-34)）。裂地镖从钻尖口出膛（出膛焰/预警闪光落钻尖）。""")
    save(boss_body(), "boss_salt_body.svg", """第八章 BOSS 悬浮采盐联合机「盐磨」300x180=碰撞体，原点(150,90)，原生朝左。
能力布挂件：镜阵翼枢座（翼独立件画布 (150,26)=局部 (0,-64)）+ 腹裂地锚口
（BayPort 画布 (150,168)=局部 (0,78)，裂地镖出膛位）+ 艏部斗轮鼓罩 +
舷侧盐料斗 + 船底喷口位（画布 (110,156)/(210,156)=通用 fx_flame）。
沿用锚点：独眼条带 y60..66 含 (55,63)（艏段甲板顶缘 y52..54 包住条带）。
提案=同目录 提案_v1_镜盐之原.md §3。""")
    save(boss_wing(), "boss_salt_wing.svg", """第八章 BOSS 镜阵翼 96x44（独立件，俯仰真瞄=炮）。
枢端画布 (78,22)=镜阵翼枢；两片镜面 V 张开朝 -X，翼尖聚焦口画布 (10,22)
=Muzzle（臂局部 (-68,0)）。蓄光时整翼泛粉（代码 modulate）。""")
    save(fx_dart(), "fx_salt_dart.svg", """裂地镖 16x8（+X=飞行方向）：小件快弹，快速一闪即落——读法归地面
标记本身（fx_salt_mark）。落地生成 mark（间歇泉预警）。""")
    save(fx_mark(), "fx_salt_mark.svg", """地裂环纹 mark 140x40（中心=落点）：间歇泉预警主读出件——地裂环纹
（暗环+放射裂缝）+盐田粉蓄能环（代码驱动渐急）+预漏白汽。""")
    save(fx_column(), "fx_salt_column.svg", """汽柱 90x360（柱顶在纹理 y=0——节点把顶钉在地表−360）：「柱是墙不是弹」
主读出件——宽幅白汽墙+撕裂缘+底部喷发外扩裙+泉眼青绿光。普通混合不 ADD。
柱高 360 >> 纯跳 67=第一眼「别跳，跑」。种子 9105。""")
    save(fx_burn(), "fx_salt_burn.svg", """盐面灼白斑 180x180（r90 满幅，中心=灼点；SlagPool 换皮视觉按判定
半径缩放）：白热灼斑+盐壳龟裂缘+粉热芯。蒸汽由 MirrorBurn 代码补间。""")
    save(fx_glint(), "fx_salt_glint.svg", """光斑晕 48x48（径向软晕，ADD）：白粉双层——干燥光束线落点光斑+mark
蓄能点缀共用。脉冲由代码驱动。""")
    save(fx_molten_bolt(), "fx_salt_bolt.svg", """融盐重弹 36x16（+X=飞行方向）：暗盐壳+熔芯裂缝透光（杏金熔）
+白热熔芯头+盐田粉热晕尾带。盐磨普攻点放弹，salt_bolt.tscn=bullet.gd 纯换皮
（照 slag_slug 账：普通混合不 ADD，暗壳压底=暖调天上靠剪影读）。""")
    print("salt mirror chapter units baked.")
