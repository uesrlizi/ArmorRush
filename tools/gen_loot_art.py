"""轻肉鸽装备美术生成器（design/run_loop.md §4）：掉落芯片 / 槽位图标 ×6 / 护盾环 / 肩部武器件×3 / 弹体×2。

生成器出坐标，SVG 头注自带坐标账；改形改这里重跑，别手改 SVG。
用法（项目根目录）：python tools/gen_loot_art.py
  → 写 assets/common/{loot_chip,loot_glyph_<槽位>×6,shield_ring,
     shoulder_mount,missile_pod,rail_gun,player_missile,rail_bolt}.svg

画风同玩家机甲拆件（player_mech_user_*.svg 头注）：纯平涂多边形、无描边、无文字；
ThorVG 规避——不用 rect+rotate、不用 <g transform=rotate>（坐标全部烘焙进 points）。
全部按 2× 画布绘制（与机甲件 0.5833 同为超采样档）；槽位图标与芯片在 HUD/世界里
缩到 0.3~0.5 显示，导入开 mipmap、节点用 LINEAR_WITH_MIPMAPS（UI 默认档的例外）。
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


def rot(points, deg, cx, cy):
    """绕 (cx,cy) 旋转（屏幕坐标 y 向下：正角=顺时针），烘焙进坐标（ThorVG 禁 rotate）。"""
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in points]


def chamfer_square(cx, cy, half, cut):
    """切角方块：左上/右下两角切 cut（AC 切角块语言；对角双切读作技术铭牌，四角全切读成停车牌）。"""
    x0, y0, x1, y1 = cx - half, cy - half, cx + half, cy + half
    return [(x0, y0 + cut), (x0 + cut, y0), (x1, y0), (x1, y1 - cut), (x1 - cut, y1), (x0, y1)]


def bar(p0, p1, half):
    """两点间定宽直杆（四边形），half=半宽。"""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    n = math.hypot(dx, dy)
    px, py = -dy / n * half, dx / n * half
    return [(p0[0] + px, p0[1] + py), (p1[0] + px, p1[1] + py),
            (p1[0] - px, p1[1] - py), (p0[0] - px, p0[1] - py)]


# ---- 掉落芯片：世界里的装备件（所有成员同框，槽位图标另叠一层） ----
# 画布 128×128（2×），中心 (64,64)=节点原点；LootPickup 以 chip+glyph 双贴图自建。
# 造型=对角双切的方形铭牌：外光晕 0.22 + 白边（受 tint=成员色）+ 最深色底板
# （叠乘后仍深：亮天里深板立得住、暗夜里成员色边与图标立得住——任何天色都有明度对比）。
# 图标=loot_glyph_<槽位>.svg 叠在底板中央（成员色），形状=哪类零件、颜色=哪个成员。
CHIP = 128.0
CHIP_HALO, CHIP_RIM, CHIP_PLATE = 62.0, 54.0, 47.0  # 半边长（光晕/边/底板）


def loot_chip():
    c = CHIP * 0.5
    halo = chamfer_square(c, c, CHIP_HALO, 24.0)
    rim = chamfer_square(c, c, CHIP_RIM, 20.0)
    plate = chamfer_square(c, c, CHIP_PLATE, 16.0)
    note = ("轻肉鸽·掉落芯片（design/run_loop.md §4）：所有成员同框，LootPickup 以 self_modulate=成员色上屏"
            "（颜色即预告），槽位图标 loot_glyph_<槽位>.svg 另叠一层。\n"
            f"     画布 {CHIP:.0f}×{CHIP:.0f}（2×），中心 ({c:.0f},{c:.0f})=节点原点；对角双切方牌（左上/右下切角）。\n"
            f"     半边长：光晕 {CHIP_HALO:.0f}（opacity 0.22）/ 白边 {CHIP_RIM:.0f} / 底板 {CHIP_PLATE:.0f}"
            f"（边带 {CHIP_RIM - CHIP_PLATE:.0f}）。白=受 tint，#1d2024 底板叠乘后仍深=任何天色的明度对比。\n"
            "     生成器：tools/gen_loot_art.py（改形改脚本重跑，别手改）。")
    write("loot_chip.svg", int(CHIP), int(CHIP), note, [
        poly(halo, TINT_BASE, 0.22),
        poly(rim, TINT_BASE),
        poly(plate, DEEPEST),
    ])
    print(f"  loot_chip plate={CHIP_PLATE * 2:.0f} rim={CHIP_RIM * 2:.0f} halo={CHIP_HALO * 2:.0f} (canvas units)")


# ---- 槽位图标：6 槽各一枚（白=受 tint：芯片上=成员色，HUD 装备栏=本章墨色） ----
# 画布 96×96（2×），主体居中占 ~70-80%；双档平色=主体满白 + 次级 0.55~0.6（焰/柄/壳）。
# 小尺寸律：HUD 显示 28（1600 窗口约 19px）——最细部件 ≥10 单位（≈2px），结构剪影优先。
# 选形（误读清单在前）：枪=斜 45° 子弹+拖尾（同触屏射击键，用户认过的语言）；刀=竖直宽刃剑
# （同斩击键）；推进=燃烧室+钟形喷口+三舌倒火（单倒三角焰与喷口上下对称读成沙漏；背推/腿推
# 合并成推进槽后共用一枚）；装甲=平肩双片胸甲+分节腹甲（平底防读成心形、无袖防读成 T 恤）；
# 护盾=尖顶六边环+顶点节点（=机体上的护盾环缩影）；肩部=短炮匣+长身管+挂臂底座
# （=越肩武器缩影；长身管防读成监控摄像头，带座=挂载武器）。
G = 96.0


def glyph_layers_gun():
    # 直轴形（中轴 x=48，尖朝上）→ 绕中心顺时针 45°=尖朝右上（同 ui_btn_fire 的经典子弹侧影）
    head = [(40, 45), (40, 36), (41, 28), (43.5, 22), (46, 17.5), (48, 15),
            (50, 17.5), (52.5, 22), (55, 28), (56, 36), (56, 45)]
    casing = [(38, 44), (58, 44), (58, 74), (38, 74)]   # 次级档，上下各被满白件压 1 单位防 AA 缝
    rim = [(36, 73), (60, 73), (60, 80), (36, 80)]
    trail_a = [(41, 85), (46, 85), (46, 97), (41, 97)]
    trail_b = [(51, 85), (56, 85), (56, 91), (51, 91)]
    layers = [(casing, 0.6), (trail_a, 0.5), (trail_b, 0.5), (head, 1.0), (rim, 1.0)]
    return [(rot(p, 45.0, 48.0, 48.0), op) for p, op in layers]


def glyph_layers_blade():
    blade = [(48, 9), (55.5, 22), (55.5, 61), (40.5, 61), (40.5, 22)]
    guard = [(32, 60), (64, 60), (68, 64.5), (64, 69), (32, 69), (28, 64.5)]
    grip = [(44, 68), (52, 68), (52, 82), (44, 82)]
    pommel = [(40, 81), (56, 81), (56, 87), (40, 87)]
    return [(grip, 0.6), (blade, 1.0), (guard, 1.0), (pommel, 1.0)]


def glyph_layers_boost():
    # 燃烧室窄于喷口（钟形喷口是最宽件=读作发动机；燃烧室比喉部宽太多会读成锤头/T 字）；
    # 焰=三舌倒火（中舌最长）——单个倒三角焰与正三角喷口上下对称，HUD 尺寸读成沙漏/棋子。
    chamber = [(42, 8), (54, 8), (58, 12), (58, 21), (38, 21), (38, 12)]
    bell = [(40, 20), (56, 20), (70, 45), (26, 45)]
    plume = [(29, 50), (67, 50), (64, 73), (57, 63), (48, 92), (39, 63), (32, 73)]
    core = [(40, 50), (56, 50), (52, 64), (48, 79), (44, 64)]
    return [(plume, 0.55), (chamber, 1.0), (bell, 1.0), (core, 1.0)]


def glyph_layers_armor():
    # 胸甲两片（平肩+颈口，中缝 5 单位）+ 两道腹甲环片（次级档，平底）——分节甲片读作装甲；
    # 首版斜肩+尖底在 HUD 尺寸读成心形（两瓣+尖），平肩平底分节即破。
    chest_l = [(16, 18), (38, 18), (42, 25), (45.5, 25), (45.5, 46), (19, 46)]
    chest_r = [(50.5, 25), (54, 25), (58, 18), (80, 18), (77, 46), (50.5, 46)]
    band_1 = [(22, 51), (74, 51), (71, 63), (25, 63)]
    band_2 = [(27, 68), (69, 68), (66, 80), (30, 80)]
    return [(band_1, 0.6), (band_2, 0.6), (chest_l, 1.0), (chest_r, 1.0)]


def glyph_layers_shield():
    # 内场先画（0.22，压在环下 0.5 单位防缝）→ 环带 6 段梯形 → 顶点节点盖住段间接缝
    r_out, r_in, r_node = 40.0, 31.0, 6.5
    layers = [(hexagon(48, 48, r_in + 0.5), 0.22)]
    outer, inner = hexagon(48, 48, r_out), hexagon(48, 48, r_in)
    for k in range(6):
        n = (k + 1) % 6
        layers.append(([outer[k], outer[n], inner[n], inner[k]], 1.0))
    for x, y in hexagon(48, 48, (r_out + r_in) * 0.5):
        layers.append((hexagon(x, y, r_node), 1.0))
    return layers


def glyph_layers_shoulder():
    # 炮匣短、身管长（管长:匣长≈0.6——短镜头+支座会读成监控摄像头，长身管才是炮）
    housing = [(14, 38), (50, 33), (57, 40), (57, 56), (16, 60), (8, 51)]
    barrel = [(56, 42), (84, 43), (84, 51), (56, 52)]
    brake = [(81, 38), (90, 38), (90, 56), (81, 56)]
    arm = [(26, 58), (40, 57), (44, 75), (30, 75)]
    base = [(20, 74), (52, 74), (56, 82), (16, 82)]
    return [(arm, 0.6), (housing, 1.0), (barrel, 1.0), (brake, 1.0), (base, 1.0)]


GLYPHS = {
    "gun": ("枪（机炮）", "斜 45° 子弹+两道拖尾", glyph_layers_gun),
    "blade": ("刀", "竖直宽刃剑", glyph_layers_blade),
    "boost": ("推进", "燃烧室+钟形喷口+三舌倒火（合并槽：主焰+姿控焰）", glyph_layers_boost),
    "armor": ("装甲", "平肩双片胸甲+两道腹甲环片", glyph_layers_armor),
    "shield": ("护盾", "尖顶六边环+顶点节点（护盾环缩影）", glyph_layers_shield),
    "shoulder": ("肩部武器", "炮匣+身管+挂臂底座（越肩武器缩影）", glyph_layers_shoulder),
}


def loot_glyphs():
    for slot, (name, desc, build) in GLYPHS.items():
        layers = build()
        xs = [x for p, _ in layers for x, _ in p]
        ys = [y for p, _ in layers for _, y in p]
        # 包围盒居中（主体光学中心≈包围盒中心；子弹拖尾也算进剪影）
        dx = G * 0.5 - (min(xs) + max(xs)) * 0.5
        dy = G * 0.5 - (min(ys) + max(ys)) * 0.5
        layers = [([(x + dx, y + dy) for x, y in p], op) for p, op in layers]
        x0, x1, y0, y1 = min(xs) + dx, max(xs) + dx, min(ys) + dy, max(ys) + dy
        assert 2.0 <= x0 and x1 <= G - 2.0 and 2.0 <= y0 and y1 <= G - 2.0, (slot, x0, x1, y0, y1)
        note = (f"轻肉鸽·槽位图标「{name}」（design/run_loop.md §4）：{desc}。\n"
                f"     画布 {G:.0f}×{G:.0f}（2×），白=受 tint：掉落芯片上=成员色，HUD 装备栏=本章墨色（空槽淡显）。\n"
                f"     主体包围盒 x{x0:.1f}..{x1:.1f} y{y0:.1f}..{y1:.1f}（{x1 - x0:.0f}×{y1 - y0:.0f}，居中）；"
                "满白=主体，0.5~0.6=次级（焰/柄/壳/挂臂），0.22=护盾内场。\n"
                "     生成器：tools/gen_loot_art.py（改形改脚本重跑，别手改）。")
        body = []
        for p, op in layers:
            body.append(poly(p, TINT_BASE, None if op >= 1.0 else op))
        write(f"loot_glyph_{slot}.svg", int(G), int(G), note, body)
        print(f"  glyph {slot}: bbox {x1 - x0:.0f}x{y1 - y0:.0f}")


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


# ---- 肩部武器（§4 肩部武器槽通道）：AC 式越肩大件，三件套 ----
# 固定支架（焊死在机背）+ 两套炮身（导弹舱/磁轨炮）挂同一个轴点（PodPivot）；
# +X=炮口朝前，朝向镜像与轴旋转都由 Visuals/PodPivot 承担。
# 用色=机甲四阶灰+橙传感器（与本体同套，不受 tint——成员身份由弹道与发数承担）。
def shoulder_mount():
    # 支架：底座宽（焊在机背上）上收成铰接块；画布 56×40（2×），中心 (28,20)=挂载点
    # =ShoulderPod 节点原点；场景缩放 0.5 → 局内 28×20。铰接顶面 y=10 → PodPivot 局部 (0,-5)。
    base = [(10, 36), (46, 36), (42, 18), (14, 18)]
    base_top = [(14, 18), (42, 18), (40, 15), (16, 15)]
    hinge = [(20, 10), (36, 10), (36, 15), (20, 15)]
    hinge_face = [(20, 10), (36, 10), (35, 12.5), (21, 12.5)]
    cell = [(26, 25), (30, 25), (30, 28), (26, 28)]
    note = ("轻肉鸽·肩部武器支架（design/run_loop.md §4 肩部武器槽通道）：固定底座+铰接块，"
            "焊死在机背不动，炮身绕顶部轴点瞄准（轴点在支架与炮身之间）。\n"
            "     色阶同机甲拆件：受光#3c4148/中值#2e3238/暗板#26292e/最深#1d2024 + 橙#ffa04a；不受 tint。\n"
            "     画布 56×40（2×），中心 (28,20)=挂载点=ShoulderPod 原点；场景缩放 0.5 → 局内 28×20。\n"
            "     出口坐标：铰接顶面画布 (28,10) → ShoulderPod 局部 (0,-5)（PodPivot 节点放此处）。\n"
            "     生成器：tools/gen_loot_art.py（改形改脚本重跑，别手改）。")
    write("shoulder_mount.svg", 56, 40, note, [
        poly(base, DEEPEST),
        poly(base_top, DARK),
        poly(hinge, MID),
        poly(hinge_face, LIGHT),
        poly(cell, ORANGE),
    ])
    print("  shoulder_mount pivot local=(0,-5) (pod node space, sprite scale 0.5)")


def missile_pod():
    # 蜂巢导弹架：三联装方形发射匣，前脸三筒口、顶部提梁、尾部排气格栅、下挂耳扣进铰接块；
    # 画布 88×44（2×），中心 (44,22)=轴点=PodPivot 原点；场景缩放 0.5 → 局内 ~32×16。
    # 比例账：匣长 66 / 匣高 32（长:高≈2:1 的发射匣读法），筒口 ~7×8 ×3 竖排。
    box = [(16, 6), (68, 6), (76, 12), (76, 32), (68, 38), (16, 38), (12, 34), (12, 10)]
    top = [(16, 6), (68, 6), (68, 10), (16, 10)]
    face = [(68, 6), (76, 12), (76, 32), (68, 38)]
    tube_a = [(69, 13), (75.5, 13), (75.5, 19), (69, 19)]
    tube_b = [(69, 18), (75.5, 18), (75.5, 24), (69, 24)]
    tube_c = [(69, 23), (75.5, 23), (75.5, 29), (69, 29)]
    grille_a = [(13, 14), (16, 14), (16, 22), (13, 22)]
    grille_b = [(13, 24), (16, 24), (16, 32), (13, 32)]
    lug = [(38, 38), (46, 38), (44, 42), (40, 42)]
    beam = [(24, 2), (56, 2), (56, 5), (24, 5)]
    beam_leg_a = [(26, 5), (29, 5), (29, 8), (26, 8)]
    beam_leg_b = [(51, 5), (54, 5), (54, 8), (51, 8)]
    sensor = [(20, 12), (24, 12), (24, 15), (20, 15)]
    note = ("轻肉鸽·蜂巢导弹架（design/run_loop.md §4 肩部武器槽）：三联装发射匣=越肩大件，"
            "+X=筒口朝前（朝向镜像与轴瞄准由 Visuals/PodPivot 承担）。\n"
            "     色阶同机甲拆件：受光#3c4148/中值#2e3238/暗板#26292e/最深#1d2024 + 橙#ffa04a；不受 tint。\n"
            "     画布 88×44（2×），中心 (44,22)=轴点=PodPivot 原点；场景缩放 0.5 → 局内 32×16。\n"
            "     出口坐标：筒口画布 (75.5,21) → PodPivot 局部 (17,0)（MuzzleMissile 放此处）。\n"
            "     生成器：tools/gen_loot_art.py（改形改脚本重跑，别手改）。")
    write("missile_pod.svg", 88, 44, note, [
        poly(lug, DEEPEST),
        poly(beam, DARK),
        poly(beam_leg_a, DARK),
        poly(beam_leg_b, DARK),
        poly(box, MID),
        poly(top, LIGHT),
        poly(face, DARK),
        poly(tube_a, DEEPEST),
        poly(tube_b, DEEPEST),
        poly(tube_c, DEEPEST),
        poly(grille_a, DEEPEST),
        poly(grille_b, DEEPEST),
        poly(sensor, ORANGE),
    ])
    print("  missile_pod muzzle local=(17,0) (pivot node space, sprite scale 0.5)")


def rail_gun():
    # 磁轨炮：细长双导轨身管+后部线圈舱（长得细长=磁轨读法）；
    # 画布 120×24（2×），轴点画布 (28,12)（挂接端）；精灵中心 (60,12)，
    # 场景缩放 0.5 → 局内全长 50×10，PodPivot 局部精灵位 (16,0)、炮口 (43,0)。
    coil = [(18, 4), (44, 4), (48, 8), (48, 16), (44, 20), (18, 20), (14, 16), (14, 8)]
    coil_top = [(18, 4), (44, 4), (44, 7), (18, 7)]
    rail_top = [(48, 7), (110, 7), (110, 9), (48, 9)]
    rail_bot = [(48, 15), (110, 15), (110, 17), (48, 17)]
    core = [(44, 9), (110, 9), (110, 15), (44, 15)]
    brake = [(106, 6), (114, 6), (114, 18), (106, 18)]
    lug = [(20, 20), (28, 20), (26, 24), (22, 24)]
    sensor = [(34, 10), (38, 10), (38, 13), (34, 13)]
    note = ("轻肉鸽·磁轨炮（design/run_loop.md §4 肩部武器槽）：双导轨细长身管=磁轨炮读法，"
            "+X=炮口朝前（朝向镜像与轴瞄准由 Visuals/PodPivot 承担）。\n"
            "     色阶同机甲拆件：受光#3c4148/中值#2e3238/暗板#26292e/最深#1d2024 + 橙#ffa04a；不受 tint。\n"
            "     画布 120×24（2×），轴点画布 (28,12)=PodPivot 原点；精灵中心 (60,12) → 精灵位 (16,0)；"
            "场景缩放 0.5 → 局内 50×10。\n"
            "     出口坐标：炮口画布 (114,12) → PodPivot 局部 (43,0)（MuzzleRail 放此处）。\n"
            "     生成器：tools/gen_loot_art.py（改形改脚本重跑，别手改）。")
    write("rail_gun.svg", 120, 24, note, [
        poly(lug, DEEPEST),
        poly(coil, MID),
        poly(coil_top, LIGHT),
        poly(core, DARK),
        poly(rail_top, LIGHT),
        poly(rail_bot, LIGHT),
        poly(brake, DEEPEST),
        poly(sensor, ORANGE),
    ])
    print("  rail_gun sprite local=(16,0) muzzle local=(43,0) (pivot node space, sprite scale 0.5)")


# ---- 肩部武器弹体（+X=弹头；发射方赋 tint/伤，弹体本身不存数值） ----
def player_missile():
    # 蜂巢小导弹：弹体+破空鼻锥+十字尾翼+橙色识别带；画布 36×16（2×）满幅，
    # 中心 (18,8)=节点原点；场景缩放 0.5 → 局内 18×8。
    fin_top = [(2, 4), (6, 0), (8, 4), (8, 6), (2, 6)]
    fin_bot = [(2, 10), (6, 16), (8, 12), (8, 10), (2, 10)]
    nozzle = [(0, 6), (4, 6), (4, 10), (0, 10)]
    body = [(4, 4), (28, 4), (34, 8), (28, 12), (4, 12)]
    nose = [(28, 4), (34, 8), (28, 12)]
    band = [(22, 4), (25, 4), (25, 12), (22, 12)]
    note = ("轻肉鸽·蜂巢小导弹弹体（design/run_loop.md §4 肩部武器槽）：+X=弹头，"
            "PlayerMissile 出筒后弹体轴跟实时速度（归航转弯可见）。\n"
            "     色阶同机甲拆件：受光#3c4148/中值#2e3238/暗板#26292e/最深#1d2024 + 橙#ffa04a；不受 tint"
            "（成员身份由发数与出筒读法承担）。\n"
            "     画布 36×16（2×）满幅，中心 (18,8)=节点原点；场景缩放 0.5 → 局内 18×8。\n"
            "     生成器：tools/gen_loot_art.py（改形改脚本重跑，别手改）。")
    write("player_missile.svg", 36, 16, note, [
        poly(fin_top, DEEPEST),
        poly(fin_bot, DEEPEST),
        poly(nozzle, DEEPEST),
        poly(body, MID),
        poly(nose, DARK),
        poly(band, ORANGE),
    ])
    print("  player_missile 18x8 in-game")


def rail_bolt():
    # 磁轨弹：细长杆+小翼+弹尖（ADD 加色混合材质上屏：白=杆芯，淡黄=翼与尾光）；
    # 画布 96×12（2×）满幅，中心 (48,6)=节点原点；场景缩放 0.5 → 局内 48×6。
    # ADD 源色纪律：贴图全亮色（深色在加色下=不可见），成员 tint 走 Sprite modulate 替换。
    fin_top = [(10, 1), (20, 1), (23, 4.5), (13, 4.5)]
    fin_bot = [(10, 11), (20, 11), (23, 7.5), (13, 7.5)]
    tail = [(0, 3), (7, 3), (7, 9), (0, 9)]
    shaft = [(0, 4.5), (88, 4.5), (88, 7.5), (0, 7.5)]
    tip = [(88, 4.5), (96, 6), (88, 7.5)]
    note = ("轻肉鸽·磁轨弹（design/run_loop.md §4 肩部武器槽）：+X=弹头，ADD 加色混合"
            "（同玩家曳光弹语言）；弹体全长=速度读法（速 3600 直线弹道）。\n"
            "     色板：#ffffff 杆芯/弹尖（ADD 下顶格亮）、#ffe9a8 翼与尾光；成员 tint=Sprite modulate 替换"
            "（黄色族红线：磁轨炮成员色 (0.95,0.95,0.72) 在黄族内）。\n"
            "     画布 96×12（2×）满幅，中心 (48,6)=节点原点；场景缩放 0.5 → 局内 48×6。\n"
            "     生成器：tools/gen_loot_art.py（改形改脚本重跑，别手改）。")
    write("rail_bolt.svg", 96, 12, note, [
        poly(tail, "#ffe9a8"),
        poly(fin_top, "#ffe9a8"),
        poly(fin_bot, "#ffe9a8"),
        poly(shaft, "#ffffff"),
        poly(tip, "#ffffff"),
    ])
    print("  rail_bolt 48x6 in-game (ADD)")


if __name__ == "__main__":
    loot_chip()
    loot_glyphs()
    shield_ring()
    shoulder_mount()
    missile_pod()
    rail_gun()
    player_missile()
    rail_bolt()
