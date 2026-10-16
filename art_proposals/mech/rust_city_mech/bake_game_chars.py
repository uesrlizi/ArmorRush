# -*- coding: utf-8 -*-
"""锈雨角色实装烘焙：把选中的玩家 A / 敌人 A 拆成 body + arm 两件游戏素材。

拆件原则（用户定）：
- 臂/武器单拆，挂 ArmPivot 做可动瞄准；腿不拆、不走路（AC 式滑动）。
- body 画布坐标 = 游戏世界像素，脚底对齐碰撞盒底（玩家脚线 = 原点下 30px，敌人 = 24px）。
- arm 画布把"肩轴"放在已知像素，Godot 侧用 centered=false + offset 让节点原点=肩轴。

产物（写入 2d-ac/assets/）：
  player_mech_body.svg  72x104  肩轴在画外由 tscn 定位；含头部/躯干/双腿/推进器（静焰）
  player_mech_arm.svg   64x36   肩轴像素 (8,10)；肩甲+臂+步枪
  enemy_walker_body.svg 56x52    含单眼/舱体/双腿/天线/枪座
  enemy_walker_arm.svg  56x24    肩轴像素 (44,8)；枪臂（原生朝左）
"""
import os

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "..", "..", "..", "assets"))

# 玩家（冷炭灰蓝 + 钠灯橙）
PB, PB_L, PB_D, PD, P_ACC = "#2e3238", "#3c4148", "#26292e", "#1d2024", "#ffa04a"
# 敌人（暖铁锈深灰 + 信号红）
EB, EB_L, EB_D, ED, E_ACC = "#332e2c", "#453d39", "#282322", "#171514", "#ff5140"


def write(name, w, h, defs, body):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
           f'width="{w}" height="{h}">\n<defs>\n' + "\n".join(defs) + "\n</defs>\n"
           + "\n".join(body) + "\n</svg>\n")
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as fp:
        fp.write(svg)
    print(f"{name}: {len(svg) // 1024} KB")


def rect(body, x, y, w, h, fill, opacity=None):
    op = f' opacity="{opacity}"' if opacity is not None else ""
    body.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}"{op}/>')


def poly(body, pts, fill, opacity=None):
    p = " ".join(f"{x},{y}" for x, y in pts)
    op = f' opacity="{opacity}"' if opacity is not None else ""
    body.append(f'<polygon points="{p}" fill="{fill}"{op}/>')


def circle(body, x, y, r, fill, opacity=None):
    op = f' opacity="{opacity}"' if opacity is not None else ""
    body.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"{op}/>')


def line(body, x1, y1, x2, y2, stroke, w):
    body.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}" stroke-width="{w}"/>')


# ---------------------------------------------------------------- 玩家 A：机体
def player_body():
    K = 1.43                      # 提案局部单位 -> 世界像素
    px = lambda x: round(36 + K * x, 1)
    py = lambda y: round(102 + K * y, 1)   # 脚底=y0 -> 画布 102（碰撞盒底=原点+30）
    S = K
    d, b = [], []
    # 远侧腿（暗）
    rect(b, px(-10), py(-26), 10 * S, 12 * S, PB_D)
    poly(b, [(px(-8), py(-14)), (px(-2), py(-12)), (px(-4), py(-2)), (px(-10), py(-2))], PB_D)
    poly(b, [(px(-14), py(0)), (px(6), py(0)), (px(6), py(-4)), (px(-10), py(-5))], PB_D)
    # 远侧肩甲
    rect(b, px(-14), py(-60), 12 * S, 9 * S, PB_D)
    # 背部推进器 + 静态尾焰
    rect(b, px(-22), py(-52), 12 * S, 16 * S, PD)
    poly(b, [(px(-20), py(-36)), (px(-12), py(-36)), (px(-14), py(-30)), (px(-18), py(-30))], PD)
    circle(b, px(-16), py(-28), 5 * S, P_ACC, 0.25)
    circle(b, px(-16), py(-28), 2.2 * S, P_ACC, 0.9)
    # 骨盆 + 躯干
    rect(b, px(-10), py(-32), 18 * S, 8 * S, PD)
    poly(b, [(px(-8), py(-58)), (px(16), py(-55)), (px(20), py(-40)), (px(10), py(-28)), (px(-10), py(-28))], PB)
    rect(b, px(6), py(-48), 8 * S, 2 * S, PD, 0.8)
    rect(b, px(16), py(-54), 3 * S, 10 * S, P_ACC, 0.9)
    # 头 + 发光眼
    rect(b, px(12), py(-69), 10 * S, 6 * S, P_ACC, 0.18)
    rect(b, px(8), py(-70), 14 * S, 10 * S, PB_L)
    rect(b, px(14), py(-67.5), 6 * S, 2.5 * S, P_ACC)
    # 近侧肩甲
    poly(b, [(px(4), py(-62)), (px(22), py(-60)), (px(20), py(-50)), (px(4), py(-52))], PB_L)
    # 近侧腿（逆关节）
    poly(b, [(px(2), py(-26)), (px(14), py(-24)), (px(10), py(-12)), (px(0), py(-14))], PB)
    poly(b, [(px(10), py(-12)), (px(13), py(-9)), (px(3), py(-2)), (px(-1), py(-6))], PB)
    poly(b, [(px(-4), py(0)), (px(20), py(0)), (px(21), py(-4)), (px(8), py(-7)), (px(-4), py(-5))], PB_L)
    # 肩轴关节（臂的旋转中心，被臂根盖住）
    circle(b, px(12), py(-54), 6, PD)
    write("player_mech_body.svg", 72, 104, d, b)


def player_arm():
    # 画布 64x44，肩轴 (10,8)；Godot: centered=false, offset=(-10,-8)
    # 低持步枪：细臂条从肩垂下，枪挂髋侧（对齐提案，别加粗枪口）
    d, b = [], []
    circle(b, 10, 8, 4.5, PB_L)        # 肩甲盖
    rect(b, 8, 8, 7, 18, PB)           # 上臂细条（肩->手）
    rect(b, 11, 22, 6, 8, PD)          # 护手
    rect(b, 10, 28, 38, 7, PD)         # 步枪（低持，x10..48）
    rect(b, 48, 27, 5, 9, PD)          # 枪口小块
    rect(b, 16, 35, 5, 5, PD)          # 握把
    rect(b, 42, 29.5, 3, 4, P_ACC, 0.9)
    write("player_mech_arm.svg", 64, 44, d, b)


# ---------------------------------------------------------------- 敌人 A：机体（原生朝左）
def enemy_body():
    K = 0.96
    px = lambda x: round(28 + K * x, 1)
    py = lambda y: round(50 + K * y, 1)    # 脚底 -> 画布 50（feet_offset 24）
    S = K
    d, b = [], []
    # 远侧腿（暗）
    rect(b, px(-2), py(-22), 10 * S, 10 * S, EB_D)
    poly(b, [(px(-14), py(0)), (px(8), py(0)), (px(8), py(-4)), (px(-10), py(-5))], EB_D)
    # 骨盆 + 圆背舱体
    rect(b, px(-8), py(-24), 16 * S, 7 * S, ED)
    poly(b, [(px(-18), py(-42)), (px(14), py(-42)), (px(18), py(-30)), (px(12), py(-18)), (px(-14), py(-18))], EB)
    rect(b, px(2), py(-38), 8 * S, 2 * S, ED, 0.8)
    rect(b, px(10), py(-36), 3 * S, 9 * S, E_ACC, 0.85)
    # 单眼（红，前缘）
    circle(b, px(-13), py(-33), 5.3, E_ACC, 0.22)
    circle(b, px(-13), py(-33), 2.4, E_ACC, 0.95)
    # 天线
    line(b, px(10), py(-42), px(14), py(-50), ED, 1.5)
    # 枪座（臂的挂点）
    rect(b, px(-14), py(-28), 8 * S, 8 * S, EB_D)
    # 近侧腿（逆关节）
    poly(b, [(px(0), py(-20)), (px(-12), py(-18)), (px(-8), py(-8)), (px(2), py(-10))], EB)
    poly(b, [(px(-8), py(-8)), (px(-11), py(-5)), (px(-1), py(0)), (px(3), py(-3))], EB)
    poly(b, [(px(-16), py(0)), (px(10), py(0)), (px(11), py(-4)), (px(-2), py(-6))], EB_L)
    # 肩轴关节
    circle(b, px(-12), py(-27), 3.5, ED)
    write("enemy_walker_body.svg", 56, 52, d, b)


def enemy_arm():
    # 画布 48x28，肩轴 (36,8)；原生朝左（枪指向 -x）
    # 细臂条垂下 + 短枪身（对齐提案：枪长 ~26，枪口 5x9，别画成长炮）
    d, b = [], []
    circle(b, 36, 8, 3.5, EB_D)        # 肩甲盖
    rect(b, 33, 8, 6, 10, EB_D)        # 臂细条
    rect(b, 8, 12, 26, 6, ED)          # 枪身（x8..34）
    rect(b, 3, 10.5, 5, 9, ED)         # 枪口
    circle(b, 12, 15, 1.5, E_ACC, 0.9) # 枪身红点
    write("enemy_walker_arm.svg", 48, 28, d, b)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    player_body()
    player_arm()
    enemy_body()
    enemy_arm()
