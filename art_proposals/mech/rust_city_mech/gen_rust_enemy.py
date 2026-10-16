# -*- coding: utf-8 -*-
"""场景一「锈雨废都」的敌人美术提案生成器（画风与玩家线统一：低饱和几何拼装 + 单一强调色）。

与玩家侧的区分：
- 朝向：敌人全部朝左（面向来向的玩家）；玩家朝右。
- 强调色：玩家=钠灯橙 #ffa04a；敌人=信号红 #ff5140（承接占位红三角的敌色直觉）。
- 车体色：玩家=冷炭灰蓝；敌人=暖铁锈深灰（同世界、敌方阵营）。

三个候选按机动方式区分：A 双足步行者（后续敌人要走，腿型预留）/ B 自走炮塔（履带，站桩合理）/ C 悬浮无人机（推进器悬空）。
产出合成图：场景提案原画 + 画内游戏比例（敌人实际 44x48，画布半刻度 ~26px）+ 右侧大号细节视图。
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
from generate_proposals import Svg  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SCENE = os.path.normpath(os.path.join(HERE, "..", "..", "proposal_1_rust_city.svg"))

# 敌方阵营色：暖铁锈深灰 + 信号红
BODY = "#332e2c"
BODY_L = "#453d39"
BODY_D = "#282322"
DARK = "#171514"
ACCENT = "#ff5140"


def _scene_parts():
    src = open(SCENE, encoding="utf-8").read()
    defs = src.split("<defs>", 1)[1].split("</defs>", 1)[0]
    body = src.split("</defs>", 1)[1].rsplit("</svg>", 1)[0]
    return defs, body


def _shadow(s, cx, cy, rx):
    s.ellipse(cx, cy, rx, rx * 0.14, "#141414", 0.3)


# ---------------------------------------------------------------- 候选 A：双足步行者（朝左）
def enemy_a(s):
    # 远侧腿（暗）
    s.rect(-2, -22, 10, 10, BODY_D)
    s.poly([(-14, 0), (8, 0), (8, -4), (-10, -5)], BODY_D)
    # 骨盆 + 圆背舱体（前缘前倾）
    s.rect(-8, -24, 16, 7, DARK)
    s.poly([(-18, -42), (14, -42), (18, -30), (12, -18), (-14, -18)], BODY)
    s.rect(2, -38, 8, 2, DARK, 0.8)          # 背部散热缝
    s.rect(10, -36, 3, 9, ACCENT, 0.85)      # 尚存一点阵营色的背条
    # 单眼（红，前缘）
    s.circle(-13, -33, 5.5, ACCENT, 0.22)
    s.circle(-13, -33, 2.5, ACCENT, 0.95)
    # 天线
    s.line(10, -42, 14, -50, DARK, 1.5)
    # 枪臂（前下）
    s.rect(-14, -28, 8, 8, BODY_D)
    s.rect(-40, -25, 26, 5, DARK)
    s.rect(-44, -26.5, 5, 8, DARK)
    # 近侧腿（逆关节，与玩家 A 同构但更矮壮）
    s.poly([(0, -20), (-12, -18), (-8, -8), (2, -10)], BODY)
    s.poly([(-8, -8), (-11, -5), (-1, 0), (3, -3)], BODY)
    s.poly([(-16, 0), (10, 0), (11, -4), (-2, -6)], BODY_L)


# ---------------------------------------------------------------- 候选 B：自走炮塔（履带，朝左）
def enemy_b(s):
    # 履带底盘
    s.rect(-32, -14, 62, 14, DARK)
    for wx in (-22, -8, 6, 20):
        s.circle(wx, -7, 4, BODY_D)
        s.circle(wx, -7, 1.5, DARK)
    # 炮塔座 + 塔体
    s.rect(-26, -22, 52, 8, BODY)
    s.poly([(-16, -38), (12, -38), (16, -30), (12, -22), (-14, -22)], BODY_L)
    # 传感器眼条（红，前缘）
    s.rect(-20, -33, 14, 7, ACCENT, 0.18)
    s.rect(-18, -31, 10, 3, ACCENT)
    # 主炮（前伸）
    s.rect(-52, -33, 36, 6, DARK)
    s.rect(-57, -35, 6, 10, DARK)
    # 尾部 radiator + 红点
    s.rect(18, -30, 8, 8, DARK)
    s.circle(22, -26, 4, ACCENT, 0.22)
    s.circle(22, -26, 1.8, ACCENT, 0.9)


# ---------------------------------------------------------------- 候选 C：悬浮无人机（朝左，悬空高度画进本体）
def enemy_c(s):
    # 侧鳍
    s.poly([(-6, -46), (6, -52), (10, -44)], BODY_L)
    s.poly([(-16, -44), (-24, -48), (-22, -40)], BODY_D)
    # 舱体（水滴形，前尖）
    s.poly([(-22, -44), (8, -46), (18, -36), (10, -26), (-16, -28)], BODY)
    s.rect(-12, -41, 12, 3, BODY_L)          # 顶部座盖
    # 眼（红，前缘）
    s.circle(-14, -34, 5.5, ACCENT, 0.22)
    s.circle(-14, -34, 2.5, ACCENT, 0.95)
    # 前下挂炮
    s.rect(-24, -27, 14, 6, DARK)
    s.rect(-29, -26, 5, 8, DARK)
    # 下置推进器 + 悬空吹焰（悬空高度的视觉解释）
    s.poly([(-8, -26), (2, -26), (0, -20), (-6, -20)], DARK)
    s.poly([(-11, -19), (5, -19), (-3, -4)], ACCENT, 0.12)
    s.circle(-3, -21, 3, ACCENT, 0.9)
    s.circle(-3, -21, 6.5, ACCENT, 0.22)


# (文件名, 绘制函数, 标题, 说明, 高度, xmin, xmax)
CANDIDATES = [
    ("rust_enemy_a_walker.svg", enemy_a, "候选 A · 双足步行者",
     "和玩家 A 同构的逆关节腿但更矮壮——后续敌人要走路，腿型直接可用；单红眼 + 枪臂前下。",
     50, -44, 18),
    ("rust_enemy_b_turret.svg", enemy_b, "候选 B · 自走炮塔",
     "最低最宽：履带 + 旋转炮塔 + 前伸主炮；站桩射击的形态解释最自然，眼条换成了横条。",
     38, -57, 30),
    ("rust_enemy_c_drone.svg", enemy_c, "候选 C · 悬浮无人机",
     "离开地面的维度：下置推进器红焰解释悬空；体积小、眼位高，弹道从高处来。",
     52, -29, 18),
]

SCENE_H = 26.0   # 画内显示高度（敌人实际 48px 世界，半刻度 24，略放大到 26 好认）
DETAIL_H = 300.0
DETAIL_W = 420.0
STAND_X = 580.0  # 画内站位（玩家位右侧，敌人来向）


def composite(fname, mech_fn, height, xmin, xmax):
    mid = (xmin + xmax) * 0.5
    s_small = SCENE_H / height
    s_big = min(DETAIL_H / height, DETAIL_W / (xmax - xmin))
    s = Svg(1200, 540)
    defs, body = _scene_parts()
    s.defs.append(defs)
    s.body.append(body)
    # 画内：游戏比例站地面线（敌人从画面右侧来）
    _shadow(s, STAND_X, 331, SCENE_H * 0.42)
    s.body.append(f'<g transform="translate({STAND_X - mid * s_small:.1f},{330}) scale({s_small:.3f})">')
    mech_fn(s)
    s.body.append("</g>")
    # 右侧细节视图（底色略偏暖，呼应敌方铁锈色）
    s.rect(716, 28, 448, 486, "#1a1512", 0.6, rx=14)
    s.body.append(f'<g transform="translate({940 - mid * s_big:.1f},{500}) scale({s_big:.3f})">')
    _shadow(s, 0, 0, (xmax - xmin) * 0.32)
    mech_fn(s)
    s.body.append("</g>")
    s.save(os.path.join(HERE, fname))


def build_gallery():
    rows = []
    for fname, _, title, desc, _h, _a, _b in CANDIDATES:
        chips = "".join(f'<span class="chip" style="background:{c}"></span>' for c in
                        (BODY, BODY_L, BODY_D, DARK, ACCENT))
        rows.append(f"""
    <section>
      <h2>{title}</h2>
      <img src="{fname}" alt="{title}">
      <p class="desc">{desc}</p>
      <p class="meta">调色 {chips} <code>{BODY}</code> 底 / <code>{ACCENT}</code> 敌方红</p>
    </section>""")
    html = f"""<!DOCTYPE html>
<html lang="zh"><head><meta charset="utf-8">
<title>锈雨废都 · 敌人提案（场景一）</title>
<style>
  body {{ background:#101216; color:#d8dce2; font-family:"Microsoft YaHei",system-ui,sans-serif; margin:32px auto; max-width:1280px; padding:0 20px; }}
  h1 {{ font-size:22px; }} h2 {{ font-size:18px; margin:0 0 6px; color:#f0f2f5; }}
  section {{ margin:34px 0; }}
  img {{ width:100%; border-radius:8px; display:block; box-shadow:0 4px 24px rgba(0,0,0,.5); }}
  .desc {{ color:#b8bfc8; margin:8px 0 4px; }}
  .meta {{ font-size:13px; color:#9aa2ad; }}
  .note {{ color:#9aa2ad; font-size:13px; }}
  .chip {{ display:inline-block; width:14px; height:14px; border-radius:3px; vertical-align:-2px; margin-right:4px; border:1px solid rgba(255,255,255,.2);}}
  code {{ color:#8fa0b8; font-size:12px; }}
</style></head><body>
<h1>锈雨废都 · 敌人提案</h1>
<p class="note">画风与玩家线同一套（几何拼装、短粗骨架、近亮远暗）。敌我识别：玩家朝右+钠灯橙 / 敌人朝左+信号红（承接占位红三角）。画内为游戏比例（敌人 44×48 世界像素，站位在玩家右侧的来向）。</p>
{"".join(rows)}
</body></html>"""
    with open(os.path.join(HERE, "rust_enemy_gallery.html"), "w", encoding="utf-8") as fp:
        fp.write(html)
    print("gallery OK")


if __name__ == "__main__":
    for fname, fn, _t, _d, height, xmin, xmax in CANDIDATES:
        composite(fname, fn, height, xmin, xmax)
        print("baked", fname)
    build_gallery()
