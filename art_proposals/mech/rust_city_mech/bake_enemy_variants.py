# -*- coding: utf-8 -*-
"""敌人两型实装烘焙（2026-10-13）：悬浮无人机 C + 盾卫（A 改）拆成游戏素材。

拆件原则与 bake_game_chars.py 一致：
- 无人机：本体 + 枪臂两件，臂挂 ArmPivot 做可动瞄准；下置推进器红焰画进本体
  （提案 C 的"悬空视觉解释"原样保留，静态焰）。
- 盾卫：复用提案 A 步行者的全部几何（px0 28→36 右移 7.68px 给盾让位），
  正面加防暴盾板（盖住枪座/骨盆前段，红眼在上不留遮挡）；枪臂直接复用
  enemy_rust_walker_arm.svg（枪口伸出盾缘 ~12px，读作"盾上炮位"）。

比例账（提案局部单位，y 向上、脚底 y=0，K 为到世界像素的换算）：
- 无人机 K=0.8：舱体宽 40u→32px、高 20u→16px；连鳍全高 52u→41.6px、含焰全宽 47u→37.6px。
  对比步行者 56x52——更小一号，配合 10 HP 的"脆"。
- 盾卫 K=0.96（与步行者同档）：盾板 17u 宽→16.3px、22u 高→21.1px，占本体前缘 2/3 高。

产物（写入 2d-ac/assets/）：
  enemy_rust_drone.svg       38x42  舱体/侧鳍/顶盖/单眼/推进器+静态红焰（原生朝左）
  enemy_rust_drone_arm.svg   32x16  前下挂炮，肩轴 (28,8)（原生朝左）
  enemy_rust_shield_body.svg 56x52  步行者本体右移 + 正面盾板（原生朝左）
"""
import os

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "..", "..", "..", "assets"))

# 敌方阵营色：暖铁锈深灰 + 信号红（与 bake_game_chars.py 同板）
EB, EB_L, EB_D, ED, E_ACC = "#332e2c", "#453d39", "#282322", "#171514", "#ff5140"


def write(name, w, h, defs, body, ledger):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
           f'width="{w}" height="{h}">\n<!-- {ledger} -->\n<defs>\n' + "\n".join(defs)
           + "\n</defs>\n" + "\n".join(body) + "\n</svg>\n")
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as fp:
        fp.write(svg)
    print(f"{name}: {len(svg)} B")


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


# ---------------------------------------------------------- 无人机 C：本体
# 几何 = gen_rust_enemy.py enemy_c 原坐标 × K=0.8；px0=29K=23.2（x∈[-29,18]），
# py0=52K=41.6（y∈[-52,0]，含鳍顶与焰尖正好满幅）。
def drone_body():
    K = 0.8
    px = lambda x: round(29 * K + K * x, 1)
    py = lambda y: round(52 * K + K * y, 1)
    d, b = [], []
    # 侧鳍：近侧亮 / 远侧暗
    poly(b, [(px(-6), py(-46)), (px(6), py(-52)), (px(10), py(-44))], EB_L)
    poly(b, [(px(-16), py(-44)), (px(-24), py(-48)), (px(-22), py(-40))], EB_D)
    # 舱体（水滴形，前尖朝左）
    poly(b, [(px(-22), py(-44)), (px(8), py(-46)), (px(18), py(-36)),
             (px(10), py(-26)), (px(-16), py(-28))], EB)
    # 顶部座盖 + 舱体散热缝
    rect(b, px(-12), py(-41), 12 * K, 3 * K, EB_L)
    rect(b, px(2), py(-38), 8 * K, 2 * K, ED, 0.8)
    # 单眼（红，前缘——与步行者同语言）
    circle(b, px(-14), py(-34), 4.4, E_ACC, 0.22)
    circle(b, px(-14), py(-34), 2.0, E_ACC, 0.95)
    # 枪臂挂点 stub（臂盖在上面）
    rect(b, px(-14), py(-27), 6 * K, 4 * K, EB_D)
    # 下置推进器 + 静态悬空吹焰（悬空高度的视觉解释，提案 C 原样）
    poly(b, [(px(-8), py(-26)), (px(2), py(-26)), (px(0), py(-20)), (px(-6), py(-20))], ED)
    poly(b, [(px(-11), py(-19)), (px(5), py(-19)), (px(-3), py(-4))], E_ACC, 0.12)
    circle(b, px(-3), py(-21), 2.4, E_ACC, 0.9)
    circle(b, px(-3), py(-21), 5.2, E_ACC, 0.22)
    write("enemy_rust_drone.svg", 38, 42, d, b,
          "无人机 K=0.8 px0=29K py0=52K；舱体 y[-46,-26]u、焰尖 y-4u、鳍顶 y-52u；"
          "碰撞盒 34x18 @sprite(2,-8) 盖舱体；feet_offset=2；ArmPivot=(-3.8,0)")


# ---------------------------------------------------------- 无人机 C：枪臂
# 提案"前下挂炮"拆出：肩轴取挂点 (-10,-26)u；枪身 x[-24,-10]u、枪口 x[-29,-24]u。
def drone_arm():
    K = 0.8
    d, b = [], []
    rect(b, 16.8, 7.2, 11.2, 4.8, ED)   # 枪身（轴左侧 14u→11.2px）
    rect(b, 12.8, 8.0, 4.0, 6.4, ED)    # 枪口（比枪身薄、往下坠 0.8px）
    circle(b, 26.0, 9.6, 1.2, E_ACC, 0.9)  # 枪身红点
    circle(b, 28.0, 8.0, 2.5, EB_D)     # 轴盖
    write("enemy_rust_drone_arm.svg", 32, 16, d, b,
          "枪臂 K=0.8 肩轴(28,8)=挂点(-10,-26)u；枪口尖端 canvas x12.8=轴左 15.2px；"
          "tscn: centered=false offset=(-28,-8)，Muzzle=(-15,3)")


# ---------------------------------------------------------- 盾卫：本体
# = bake_game_chars.py enemy_body 几何原样（px0 28→36 右移），外加正面盾板。
def shield_body():
    K = 0.96
    px = lambda x: round(36 + K * x, 1)
    py = lambda y: round(50 + K * y, 1)    # 脚底 -> 画布 50（feet_offset 24，与步行者同）
    S = K
    d, b = [], []
    # 远侧腿（暗）
    rect(b, px(-2), py(-22), 10 * S, 10 * S, EB_D)
    poly(b, [(px(-14), py(0)), (px(8), py(0)), (px(8), py(-4)), (px(-10), py(-5))], EB_D)
    # 骨盆 + 圆背舱体
    rect(b, px(-8), py(-24), 16 * S, 7 * S, ED)
    poly(b, [(px(-18), py(-42)), (px(14), py(-42)), (px(18), py(-30)),
             (px(12), py(-18)), (px(-14), py(-18))], EB)
    rect(b, px(2), py(-38), 8 * S, 2 * S, ED, 0.8)
    rect(b, px(10), py(-36), 3 * S, 9 * S, E_ACC, 0.85)
    # 单眼（红，前缘）——盾顶留白不遮挡（盾顶 y=-28u，眼底 y≈-27.5u）
    circle(b, px(-13), py(-33), 5.3, E_ACC, 0.22)
    circle(b, px(-13), py(-33), 2.4, E_ACC, 0.95)
    # 天线
    line(b, px(10), py(-42), px(14), py(-50), ED, 1.5)
    # 近侧腿（逆关节）
    poly(b, [(px(0), py(-20)), (px(-12), py(-18)), (px(-8), py(-8)), (px(2), py(-10))], EB)
    poly(b, [(px(-8), py(-8)), (px(-11), py(-5)), (px(-1), py(0)), (px(3), py(-3))], EB)
    poly(b, [(px(-16), py(0)), (px(10), py(0)), (px(11), py(-4)), (px(-2), py(-6))], EB_L)
    # ---- 正面防暴盾（盖枪座/骨盆前段；炮臂后画、压在盾上读作"盾上炮位"） ----
    # 盾板本体：前缘竖直 x=-31u，顶缘 y=-28u（红眼下方 0.5u 收进），右缘微斜
    poly(b, [(px(-31), py(-6)), (px(-31), py(-28)), (px(-16), py(-28)), (px(-14), py(-6))], EB_D)
    # 内嵌板（暗一档，与本体拉开层次）
    poly(b, [(px(-28), py(-9)), (px(-28), py(-25)), (px(-17.5), py(-25)), (px(-16), py(-9))], ED)
    # 阵营红条（与背部背条同语言）
    rect(b, px(-25), py(-24), 3 * S, 12 * S, E_ACC, 0.85)
    # 前缘亮棱 + 铆钉
    line(b, px(-31), py(-6), px(-31), py(-28), EB_L, 2.0)
    circle(b, px(-28.5), py(-10.5), 1.2, EB_L)
    circle(b, px(-28.5), py(-23.5), 1.2, EB_L)
    # 肩轴关节（臂的旋转中心，被臂根盖住）
    circle(b, px(-12), py(-27), 3.5, ED)
    write("enemy_rust_shield_body.svg", 56, 52, d, b,
          "盾卫 K=0.96 px0=36 py0=50（步行者几何右移 7.68px）；盾板 x[-31,-14]u y[-28,-6]u；"
          "碰撞盒 52x48 居中、feet_offset=24；ArmPivot=(-4,-2) 肩轴(-12,-27)u，复用 walker_arm")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    drone_body()
    drone_arm()
    shield_body()
