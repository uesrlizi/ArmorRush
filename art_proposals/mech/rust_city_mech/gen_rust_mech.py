# -*- coding: utf-8 -*-
"""场景一「锈雨废都」的角色（机甲）美术试案生成器。

原则（吸取 mech 线教训）：
- 纯几何形状拼装，不描参考图、不做事后压扁——短粗比例直接写进骨架坐标。
- 侧视、朝右；近侧肢体亮、远侧肢体暗（2D 侧视可读性）。
- 简单抽象：每个候选 ~20 个形状，靠剪影和一处橙色发光点读识别度（与场景钠灯同源）。
- 产出 = 合成图：场景提案原画打底 + 画内游戏真实比例（玩家位 x=400）+ 右侧大号细节视图。

三个候选按腿型区分（AC6 惯例）：A 逆关节=速度 / B 重双足=火力 / C 四脚=炮台。
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
from generate_proposals import Svg  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SCENE = os.path.normpath(os.path.join(HERE, "..", "..", "proposal_1_rust_city.svg"))

# 军规低饱和底色 + 单一强调色（钠灯橙，与场景灯火同源）
BODY = "#2e3238"    # 近侧主装甲
BODY_L = "#3c4148"  # 近侧受光面板
BODY_D = "#26292e"  # 远侧肢体（暗一档）
DARK = "#1d2024"    # 关节/武器/内骨架
ACCENT = "#ffa04a"  # 强调橙（眼/条带/喷口）


def _scene_parts():
    src = open(SCENE, encoding="utf-8").read()
    defs = src.split("<defs>", 1)[1].split("</defs>", 1)[0]
    body = src.split("</defs>", 1)[1].rsplit("</svg>", 1)[0]
    return defs, body


def _shadow(s, cx, cy, rx):
    s.ellipse(cx, cy, rx, rx * 0.14, "#141414", 0.3)


# ---------------------------------------------------------------- 候选 A：逆关节（速度）
def mech_a(s):
    # 远侧腿（直承重，暗）
    s.rect(-10, -26, 10, 12, BODY_D)
    s.poly([(-8, -14), (-2, -12), (-4, -2), (-10, -2)], BODY_D)
    s.poly([(-14, 0), (6, 0), (6, -4), (-10, -5)], BODY_D)
    # 远侧肩甲
    s.rect(-14, -60, 12, 9, BODY_D)
    # 背部推进器
    s.rect(-22, -52, 12, 16, DARK)
    s.poly([(-20, -36), (-12, -36), (-14, -30), (-18, -30)], DARK)
    s.circle(-16, -28, 5, ACCENT, 0.25)
    s.circle(-16, -28, 2.2, ACCENT, 0.9)
    # 骨盆 + 躯干（前倾楔形）
    s.rect(-10, -32, 18, 8, DARK)
    s.poly([(-8, -58), (16, -55), (20, -40), (10, -28), (-10, -28)], BODY)
    s.rect(6, -48, 8, 2, DARK, 0.8)      # 胸部散热缝
    s.rect(16, -54, 3, 10, ACCENT, 0.9)  # 前缘强调条
    # 头（小、下沉于肩甲间）+ 单条发光传感器眼
    s.rect(12, -69, 10, 6, ACCENT, 0.18)
    s.rect(8, -70, 14, 10, BODY_L)
    s.rect(14, -67.5, 6, 2.5, ACCENT)
    # 近侧肩甲
    s.poly([(4, -62), (22, -60), (20, -50), (4, -52)], BODY_L)
    # 近侧腿（逆关节：膝朝前、踝后收、掌前伸）
    s.poly([(2, -26), (14, -24), (10, -12), (0, -14)], BODY)          # 股
    s.poly([(10, -12), (13, -9), (3, -2), (-1, -6)], BODY)            # 胫
    s.poly([(-4, 0), (20, 0), (21, -4), (8, -7), (-4, -5)], BODY_L)   # 大脚掌
    # 低持步枪（枪口前下）
    s.rect(18, -19, 4, 5, DARK)
    s.rect(14, -24, 26, 5, DARK)
    s.rect(40, -25, 4, 7, DARK)


# ---------------------------------------------------------------- 候选 B：重双足（火力）
def mech_b(s):
    # 远侧腿（暗，柱状）
    s.rect(-14, -30, 16, 14, BODY_D)
    s.rect(-12, -16, 14, 12, BODY_D)
    s.poly([(-20, 0), (10, 0), (10, -5), (-16, -7)], BODY_D)
    # 远侧肩甲（巨大）
    s.rect(-26, -64, 18, 12, BODY_D)
    # 背部武器架
    s.rect(-30, -52, 14, 18, DARK)
    s.circle(-23, -44, 2.5, "#101216")
    s.circle(-23, -38, 2.5, "#101216")
    # 骨盆 + 躯干（宽厚）
    s.rect(-12, -30, 22, 10, DARK)
    s.poly([(-16, -56), (20, -56), (24, -40), (18, -30), (-14, -30)], BODY)
    s.rect(6, -52, 14, 16, BODY_L)       # 胸前板
    # 头（几乎埋进肩甲）
    s.rect(17, -59, 6, 2.5, ACCENT)
    s.rect(12, -62, 12, 9, BODY)
    # 近侧肩甲（最大识别件）+ 强调条
    s.poly([(8, -66), (32, -62), (30, -48), (8, -50)], BODY_L)
    s.rect(22, -61, 4, 10, ACCENT, 0.9)
    # 近侧腿（粗柱 + 大平掌）
    s.poly([(-6, -30), (12, -30), (14, -16), (-2, -16)], BODY)
    s.rect(-2, -16, 14, 12, BODY)
    s.circle(10, -16, 3, BODY_L)         # 膝甲
    s.poly([(-10, 0), (26, 0), (26, -6), (-6, -8)], BODY_L)
    # 低持重炮
    s.rect(8, -34, 10, 10, BODY_D)
    s.rect(14, -34, 38, 8, DARK)
    s.rect(50, -36, 6, 12, DARK)


# ---------------------------------------------------------------- 候选 C：四脚（炮台）
def mech_c(s):
    # 远侧腿（暗）
    s.rect(12, -34, 10, 16, BODY_D)
    s.poly([(8, 0), (30, 0), (30, -5), (10, -7)], BODY_D)
    s.rect(-24, -34, 10, 16, BODY_D)
    s.poly([(-28, 0), (-6, 0), (-6, -5), (-26, -7)], BODY_D)
    # 尾部喷口
    s.rect(-38, -48, 8, 7, DARK)
    s.rect(-38, -38, 8, 7, DARK)
    s.circle(-40, -44.5, 4.5, ACCENT, 0.22)
    s.circle(-40, -44.5, 2, ACCENT, 0.9)
    s.circle(-40, -34.5, 4.5, ACCENT, 0.22)
    s.circle(-40, -34.5, 2, ACCENT, 0.9)
    # 低矮宽大的六边形车体
    s.poly([(-30, -52), (28, -52), (34, -38), (28, -24), (-26, -24), (-34, -38)], BODY)
    s.rect(-22, -52, 42, 4, BODY_L)
    # 炮塔 + 长管
    s.poly([(-4, -62), (16, -62), (12, -52), (0, -52)], BODY_L)
    s.rect(14, -59, 34, 5, DARK)
    s.rect(46, -60.5, 5, 8, DARK)
    s.line(4, -62, 1, -72, DARK, 1.5)    # 天线
    # 前缘传感器眼条
    s.rect(22, -48, 12, 7.5, ACCENT, 0.18)
    s.rect(24, -46, 8, 3.5, ACCENT)
    # 近侧腿（亮，前后各一）
    s.rect(-20, -30, 11, 18, BODY)
    s.poly([(-30, 0), (-8, 0), (-9, -6), (-28, -8)], BODY)
    s.rect(16, -30, 11, 18, BODY)
    s.poly([(12, 0), (34, 0), (33, -6), (14, -8)], BODY)
    s.circle(21, -13, 2.5, BODY_L)
    s.circle(-14.5, -13, 2.5, BODY_L)


# (文件名, 绘制函数, 标题, 说明, 高度, xmin, xmax)  xmin/xmax 为局部坐标包络，用于自适应缩放
CANDIDATES = [
    ("rust_mech_a_speed.svg", mech_a, "候选 A · 逆关节（速度型）",
     "最瘦高的剪影：前倾楔形躯干 + 逆关节长掌，背部单喷口橙色尾焰；眼部条灯与场景钠灯同源。",
     70, -24, 44),
    ("rust_mech_b_heavy.svg", mech_b, "候选 B · 重双足（火力型）",
     "宽厚剪影：超大肩甲盖住半身、头部下沉几乎不可见、柱状腿大平掌；肩甲一道橙条做识别。",
     62, -30, 56),
    ("rust_mech_c_tetrapod.svg", mech_c, "候选 C · 四脚（炮台型）",
     "最低最宽：六边形低车体 + 四脚 + 塔状长管，尾部双喷口；前缘整条发光眼带。",
     60, -40, 51),
]

SCENE_H = 52.0   # 画内显示高度（=游戏内 ~100px 的一半画布）
DETAIL_H = 300.0 # 细节视图显示高度
DETAIL_W = 420.0 # 细节视图允许的最大宽度（面板宽 448，留边）


def composite(fname, mech_fn, height, xmin, xmax):
    mid = (xmin + xmax) * 0.5
    s_small = SCENE_H / height
    s_big = min(DETAIL_H / height, DETAIL_W / (xmax - xmin))
    s = Svg(1200, 540)
    defs, body = _scene_parts()
    s.defs.append(defs)
    s.body.append(body)
    # 画内：游戏真实比例站玩家位（左 1/3、地面线 y=330）
    _shadow(s, 400, 331, SCENE_H * 0.42)
    s.body.append(f'<g transform="translate({400 - mid * s_small:.1f},{330}) scale({s_small:.3f})">')
    mech_fn(s)
    s.body.append("</g>")
    # 右侧细节视图
    s.rect(716, 28, 448, 486, "#15171b", 0.6, rx=14)
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
      <p class="meta">调色 {chips} <code>{BODY}</code> 底 / <code>{ACCENT}</code> 强调</p>
    </section>""")
    html = f"""<!DOCTYPE html>
<html lang="zh"><head><meta charset="utf-8">
<title>锈雨废都 · 角色试案（场景一）</title>
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
<h1>锈雨废都 · 角色试案</h1>
<p class="note">合成图 = 场景提案原画 + 画内游戏比例（玩家位 x=400、地面线 y=330）+ 右侧大号细节视图。侧视朝右、纯几何拼装、短粗比例写在骨架里；近侧肢体亮、远侧暗一档；强调橙与场景钠灯同源。候选按腿型区分：A 逆关节=速度 / B 重双足=火力 / C 四脚=炮台。</p>
{"".join(rows)}
</body></html>"""
    with open(os.path.join(HERE, "rust_mech_gallery.html"), "w", encoding="utf-8") as fp:
        fp.write(html)
    print("gallery OK")


if __name__ == "__main__":
    os.makedirs(HERE, exist_ok=True)
    for fname, fn, _t, _d, height, xmin, xmax in CANDIDATES:
        composite(fname, fn, height, xmin, xmax)
        print("baked", fname)
    build_gallery()
