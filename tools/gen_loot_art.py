"""轻肉鸽装备美术三件生成器（design/run_loop.md §4）：掉落小件 / 护盾环 / 背挂副炮。

生成器出坐标，SVG 头注自带坐标账；改形改这里重跑，别手改 SVG。
用法（项目根目录）：python tools/gen_loot_art.py
  → 写 assets/common/{loot_part,shield_ring,shoulder_pod}.svg

画风同玩家机甲拆件（player_mech_user_*.svg 头注）：纯平涂多边形、无描边、无文字；
ThorVG 规避——不用 rect+rotate、不用 <g transform=rotate>（坐标全部烘焙进 points）。
三件都按 2× 画布绘制、场景里 Sprite2D 缩 0.5/0.65 用（与机甲件 0.5833 同为超采样档）。
"""
import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "common"

# 机甲色阶（与 player_mech_user_*.svg 同一套）
LIGHT, MID, DARK, DEEPEST, ORANGE = "#3c4148", "#2e3238", "#26292e", "#1d2024", "#ffa04a"
TINT_BASE = "#ffffff"  # 受 tint 件的底色：白 = 成员色原样上屏（self_modulate 叠乘）


def pts(points):
    return " ".join(f"{x:.2f},{y:.2f}" for x, y in points)


def poly(points, fill, opacity=None):
    op = f' opacity="{opacity}"' if opacity is not None else ""
    return f'  <polygon points="{pts(points)}" fill="{fill}"{op}/>'


def hexagon(cx, cy, r, pointy=True):
    off = -90.0 if pointy else 0.0
    return [(cx + r * math.cos(math.radians(off + 60.0 * k)),
             cy + r * math.sin(math.radians(off + 60.0 * k))) for k in range(6)]


def write(name, w, h, note, body):
    svg = (f'<?xml version="1.0" encoding="UTF-8"?>\n'
           f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">\n'
           f'<!-- {note} -->\n' + "\n".join(body) + "\n</svg>\n")
    (OUT / name).write_text(svg, encoding="utf-8")
    print(f"wrote {name} ({w}x{h})")


# ---- 掉落小件：通用补给件（所有成员同形，tint=成员色即预告） ----
# 画布 64×64（2×），中心 (32,32)=节点原点；场景缩放 0.65 → 局内约 35×16 本体。
# 造型=横置六棱补给匣（侧视六棱柱轮廓）：白底外框（受 tint=成员色）+ 最深色内框
# （叠乘后仍深=明度对比在任何天色下都成立）+ 白芯槽（受 tint=发光芯）+ 0.22 光晕
# （机甲传感器同款「0.18 晕+实芯」语汇，提一档保读）。
def loot_part():
    cx, cy = 32.0, 32.0
    halo = [(8, 14), (56, 14), (63, 32), (56, 50), (8, 50), (1, 32)]
    body = [(12, 20), (52, 20), (59, 32), (52, 44), (12, 44), (5, 32)]
    inner = [(17, 25), (47, 25), (51, 32), (47, 39), (17, 39), (13, 32)]
    core = [(24, 29), (40, 29), (40, 35), (24, 35)]
    notch_l = [(19, 20), (22, 20), (22, 25), (19, 25)]
    notch_r = [(42, 20), (45, 20), (45, 25), (42, 25)]
    note = ("轻肉鸽·掉落小件（design/run_loop.md §4）：通用补给匣，所有成员同形，"
            "LootPickup 以 self_modulate=成员色上屏（颜色即预告）。\n"
            "     画布 64×64（2×），中心 (32,32)=节点原点；场景缩放 0.65。"
            "本体六棱 x5..59 y20..44（局内 35×16），光晕 x1..63 y14..50 opacity 0.22。\n"
            "     白=受 tint 部分（外框/芯槽/光晕），#1d2024 内框与刻槽=叠乘后仍深的明度对比。\n"
            "     生成器：tools/gen_loot_art.py（改形改脚本重跑，别手改）。")
    write("loot_part.svg", 64, 64, note, [
        poly(halo, TINT_BASE, 0.22),
        poly(body, TINT_BASE),
        poly(inner, DEEPEST),
        poly(notch_l, DEEPEST),
        poly(notch_r, DEEPEST),
        poly(core, TINT_BASE),
    ])
    assert all(0 <= x <= 64 and 0 <= y <= 64 for p in (halo, body) for x, y in p)
    print(f"  loot_part body w={59 - 5} h={44 - 20} (x0.65 -> {54 * 0.65:.1f}x{24 * 0.65:.1f}px), center=({cx},{cy})")


# ---- 护盾环：尖顶六边形能量环（机体外缘，盾量=亮度） ----
# 画布 208×208（2×），中心 (104,104)=环心；场景缩放 0.5 → 局内外接圆 R47（高 94 宽 81.4）。
# 机体参照：本体精灵 63px 高（108 画布×0.5833）、宽含臂 ~55px → 环四周留 ~13-15px 余量。
# 尖顶朝上：机体是竖长剪影，尖顶六边形高>宽，贴身。
# 环带=6 段梯形（外/内顶点逐段相连，不依赖 fill-rule）opacity 0.7；场=内六边形 0.10；
# 顶点节点=6 个小六边形满不透明（同一 tint 下靠不透明度分出层级）。
def shield_ring():
    cx, cy = 104.0, 104.0
    r_out, r_in = 94.0, 87.0
    outer = hexagon(cx, cy, r_out)
    inner = hexagon(cx, cy, r_in)
    body = [poly(inner, TINT_BASE, 0.10)]
    for k in range(6):
        n = (k + 1) % 6
        body.append(poly([outer[k], outer[n], inner[n], inner[k]], TINT_BASE, 0.7))
    r_mid = (r_out + r_in) * 0.5
    for x, y in hexagon(cx, cy, r_mid):
        body.append(poly(hexagon(x, y, 5.5), TINT_BASE))
    note = ("轻肉鸽·护盾环（design/run_loop.md §4 护盾槽通道）：尖顶六边形能量环，"
            "Player/Visuals/ShieldRing 以 self_modulate=成员环色、modulate.a=盾量上屏。\n"
            f"     画布 208×208（2×），中心 (104,104)=环心；场景缩放 0.5 → 局内外接 R{r_out / 2:.0f}"
            f"（高 {r_out:.0f} 宽 {r_out * math.sqrt(3) / 2:.1f}）。\n"
            f"     环带 R{r_in / 2:.1f}..{r_out / 2:.0f}（局内）6 段梯形 opacity 0.7；内场 0.10；"
            "顶点节点小六边形 r2.75 满不透明。\n"
            "     生成器：tools/gen_loot_art.py（改形改脚本重跑，别手改）。")
    write("shield_ring.svg", 208, 208, note, body)
    print(f"  shield_ring in-game R_out={r_out / 2} height={r_out} width={r_out * math.sqrt(3) / 2:.1f}")


# ---- 背挂副炮：肩部武器槽的背挂单元（+X=炮口朝前，镜像交给 Visuals） ----
# 画布 72×32（2×），中心 (36,16)=挂载点（节点原点）；场景缩放 0.5 → 局内 36×16。
# 造型=楔形炮匣+细长身管+炮口制退器，底部挂座；AC6 背挂单元越肩前指的读法。
# 用色=机甲四阶灰+橙传感器（与本体同套，不受 tint——成员身份由曳光色与发数承担）。
def shoulder_pod():
    mount = [(14, 18), (30, 18), (33, 30), (16, 30)]
    housing = [(6, 8), (46, 5), (52, 10), (52, 22), (8, 24), (2, 17)]
    top = [(7, 8), (46, 5), (49.5, 8.5), (9, 11.5)]
    barrel = [(52, 12), (69, 12.6), (69, 17.4), (52, 18)]
    brake = [(64, 11), (70, 11), (70, 19), (64, 19)]
    halo = [(38, 13), (46, 13), (46, 19), (38, 19)]
    sensor = [(40, 14.5), (44, 14.5), (44, 17.5), (40, 17.5)]
    muzzle = (70.0, 15.0)
    mx, my = (muzzle[0] - 36.0) * 0.5, (muzzle[1] - 16.0) * 0.5
    note = ("轻肉鸽·背挂副炮（design/run_loop.md §4 肩部武器槽通道）：楔形炮匣+身管+制退器+挂座，"
            "+X=炮口朝前（朝向镜像由 Visuals 承担）。\n"
            "     色阶同机甲拆件：受光#3c4148/中值#2e3238/暗板#26292e/最深#1d2024 + 橙#ffa04a；不受 tint。\n"
            "     画布 72×32（2×），中心 (36,16)=挂载点=ShoulderPod 节点原点；场景缩放 0.5 → 局内 36×16。\n"
            f"     出口坐标：炮口画布 ({muzzle[0]:.0f},{muzzle[1]:.0f}) → ShoulderPod 局部 ({mx:.1f},{my:.1f})"
            "（Muzzle Marker2D 放此处）。\n"
            "     生成器：tools/gen_loot_art.py（改形改脚本重跑，别手改）。")
    write("shoulder_pod.svg", 72, 32, note, [
        poly(mount, DEEPEST),
        poly(housing, MID),
        poly(top, LIGHT),
        poly(barrel, DARK),
        poly(brake, DEEPEST),
        poly(halo, ORANGE, 0.18),
        poly(sensor, ORANGE),
    ])
    print(f"  shoulder_pod muzzle local=({mx},{my}) (pod node space, sprite scale 0.5)")


if __name__ == "__main__":
    loot_part()
    shield_ring()
    shoulder_pod()
