# -*- coding: utf-8 -*-
"""玩家机甲腿部拆件生成器（骨架部件流）。

规约（头注释即本条线的契约）：
- 源件：assets/common/player_mech_user_body.svg（用户手绘 v2，不改色不改形，
  只做「按关节把既有路径分发到独立文件」的组装级拆分）。
- 画布：全部部件保持 108x108 画布与同一外层变换
  translate(2,2) scale(0.3377) translate(-329,-474)，
  即任何部件内原坐标 p 的画布位 = (2,2)+0.3377*(p-(329,474))。
  画布中心 (54,54) = 机体锚点（场景内 Visuals 原点，精灵缩放 0.5833333）。
- 部件：每腿三骨——thigh(大腿)/shin(小腿)/foot(脚)，远/近两腿共 6 文件；
  躯干（腰/跨/胸/胸传感器/胸-肩）留在 player_mech_user_body.svg。
- 关节：hip(胯)/knee(膝)/ankle(踝) 轴点坐标由本脚本按路径几何算出并写进
  各部件头注释；场景 tscn 与 leg_ik.gd 只引用这里的数，不另立副本。
- 用法：
    python tools/split_player_legs.py            # 解析+生成部件+打印轴点账
    python tools/split_player_legs.py --analyze  # 只打印几何分析，不写文件
"""
import re
import sys
import os

SRC = os.path.join(os.path.dirname(__file__), "..", "assets", "common",
                   "player_mech_user_body.svg")
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "common")

# 画布三账（与源件外层变换、场景精灵缩放一致）
TX, TY, SC = 2.0, 2.0, 0.3377      # 画布 = (TX,TY) + SC*(orig - (OX,OY))
OX, OY = 329.0, 474.0
CANVAS = 108.0
SPRITE_SCALE = 0.5833333           # 场景内精灵缩放（画布 px -> 局部 px）

CUBE_STEPS = 24  # 三次贝塞尔摊平细分


def to_canvas(p):
    return (TX + SC * (p[0] - OX), TY + SC * (p[1] - OY))


def to_local(c):
    return ((c[0] - CANVAS / 2) * SPRITE_SCALE, (c[1] - CANVAS / 2) * SPRITE_SCALE)


def cubic(p0, p1, p2, p3, t):
    mt = 1.0 - t
    x = mt**3 * p0[0] + 3 * mt**2 * t * p1[0] + 3 * mt * t**2 * p2[0] + t**3 * p3[0]
    y = mt**3 * p0[1] + 3 * mt**2 * t * p1[1] + 3 * mt * t**2 * p2[1] + t**3 * p3[1]
    return (x, y)


def flatten_path(d):
    """把路径 d 摊平成折点列（子路径用 None 分隔）。支持 M/m C/c H/h V/v L/l Z/z。"""
    tokens = re.findall(r"([MmLlHhVvCcZz])|(-?\d*\.?\d+(?:[eE][-+]?\d+)?)", d)
    seq = []  # (cmd, [nums])
    cur_cmd, nums = None, []
    for cmd, num in tokens:
        if cmd:
            if cur_cmd:
                seq.append((cur_cmd, nums))
            cur_cmd, nums = cmd, []
        else:
            nums.append(float(num))
    if cur_cmd:
        seq.append((cur_cmd, nums))

    pts = []
    sub = []
    pen = (0.0, 0.0)
    start = (0.0, 0.0)
    last_c2 = None

    def emit(p):
        sub.append(p)

    i = 0
    for cmd, nums in seq:
        n = 0
        while n < len(nums) or (cmd in "Zz" and n == 0):
            if cmd in "Mm":
                p = nums[n:n + 2]
                if cmd == "M":
                    pen = (p[0], p[1])
                else:
                    pen = (pen[0] + p[0], pen[1] + p[1])
                if sub:
                    pts.append(sub)
                    sub = []
                start = pen
                last_c2 = None
                n += 2
            elif cmd in "Ll":
                p = nums[n:n + 2]
                pen = (p[0], p[1]) if cmd == "L" else (pen[0] + p[0], pen[1] + p[1])
                emit(pen)
                last_c2 = None
                n += 2
            elif cmd in "Hh":
                x = nums[n]
                pen = (x, pen[1]) if cmd == "H" else (pen[0] + x, pen[1])
                emit(pen)
                last_c2 = None
                n += 1
            elif cmd in "Vv":
                y = nums[n]
                pen = (pen[0], y) if cmd == "V" else (pen[0], pen[1] + y)
                emit(pen)
                last_c2 = None
                n += 1
            elif cmd in "Cc":
                p1 = nums[n:n + 2]
                p2 = nums[n + 2:n + 4]
                p3 = nums[n + 4:n + 6]
                if cmd == "c":
                    p1 = (pen[0] + p1[0], pen[1] + p1[1])
                    p2 = (pen[0] + p2[0], pen[1] + p2[1])
                    p3 = (pen[0] + p3[0], pen[1] + p3[1])
                for k in range(1, CUBE_STEPS + 1):
                    emit(cubic(pen, p1, p2, p3, k / CUBE_STEPS))
                pen = p3
                last_c2 = p2
                n += 6
            elif cmd in "Zz":
                if sub and start != sub[-1]:
                    emit(start)
                pen = start
                n += 1
            else:
                raise ValueError("unsupported cmd %r" % cmd)
    if sub:
        pts.append(sub)
    return pts


def parse_svg(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    paths = []
    for m in re.finditer(r'<path\b[^>]*/>', text):
        element = m.group(0)
        fill_m = re.search(r'fill="([^"]*)"', element)
        d_m = re.search(r'\bd="([^"]*)"', element)
        paths.append({"fill": fill_m.group(1), "d": d_m.group(1), "element": element})
    return text, paths


# ---- 关节轴点账（画布空间，108x108；由 --analyze 的路径几何选定，选点依据见各部件头注释）----
HIP = {"far": (37.5, 57.5), "near": (46.56, 57.5)}    # 胯：大腿轴线上端，盆骨(跨)覆盖带内
KNEE = {"far": (41.0, 77.5), "near": (50.06, 77.5)}   # 膝：大腿底边与小腿顶边交叠带中点
ANKLE = {"far": (34.2, 98.5), "near": (43.26, 98.5)}  # 踝：小腿轴线与脚面顶边的交叠点
SOLE = {"far": (34.2, 105.9), "near": (43.26, 105.9)}  # 脚掌接地点（脚底边、踝正下方）

PARTS = {  # (侧, 部件) -> 源件 path 索引
    ("far", "thigh"): 0, ("far", "foot"): 1, ("far", "shin"): 2,
    ("near", "thigh"): 3, ("near", "foot"): 4, ("near", "shin"): 5,
}

PART_COMMENT = {
    "thigh": "大腿件：髋段护板（源件 _腿-{side} 第1条路径，原样搬运）",
    "shin": "小腿件：膝-踝段护板带踝底板（源件 _腿-{side} 第3条路径，原样搬运）",
    "foot": "脚掌件：脚掌+脚尖斜坡（源件 _腿-{side} 第2条路径，原样搬运）",
}


def num(v):
    """坐标账输出：统一 0.5 对齐容差的 4 位小数。"""
    return f"{v:.4f}".rstrip("0").rstrip(".")


def local_of(canvas_pt):
    x, y = to_local(canvas_pt)
    return Vector(x, y)


class Vector:
    def __init__(self, x, y):
        self.x, self.y = x, y

    def __repr__(self):
        return f"Vector2({num(self.x)}, {num(self.y)})"

    def __sub__(self, o):
        return Vector(self.x - o.x, self.y - o.y)

    def __mul__(self, k):
        return Vector(self.x * k, self.y * k)

    def angle_deg(self):
        import math
        return math.degrees(math.atan2(self.y, self.x))

    def length(self):
        return (self.x * self.x + self.y * self.y) ** 0.5


def bbox(polylines):
    xs = [p[0] for sub in polylines for p in sub]
    ys = [p[1] for sub in polylines for p in sub]
    return min(xs), min(ys), max(xs), max(ys)


def report(name, d):
    subs = flatten_path(d)
    cb = [list(map(to_canvas, p)) for p in subs]
    x0, y0, x1, y1 = bbox(cb)
    print(f"--- {name}")
    print(f"    orig bbox: {bbox(subs)}")
    print(f"    canvas bbox: ({x0:.1f},{y0:.1f})..({x1:.1f},{y1:.1f})  "
          f"size {x1-x0:.1f}x{y1-y0:.1f}")
    for i, sub in enumerate(cb):
        s = "  ".join(f"({p[0]:.1f},{p[1]:.1f})" for p in sub[::4])
        print(f"    sub{i} [{len(sub)}pt] {s}")


def main():
    analyze_only = "--analyze" in sys.argv
    text, paths = parse_svg(os.path.abspath(SRC))
    print(f"parsed {len(paths)} paths")

    # ---- 场景/求解器坐标账（局部空间 = (画布-(54,54))*0.5833333）----
    print("\n==== 场景装配账（局部单位，直接可进 tscn / leg_ik.gd）====")
    for side in ("far", "near"):
        hip, knee = local_of(HIP[side]), local_of(KNEE[side])
        ankle, sole = local_of(ANKLE[side]), local_of(SOLE[side])
        l1 = (knee - hip).length()
        l2 = (ankle - knee).length()
        t1 = (knee - hip).angle_deg() - 90.0   # 骨静止朝向 = 画布 +y(向下)
        t2 = (ankle - knee).angle_deg() - 90.0
        print(f"[{side}] Hip{side.capitalize()}pos={hip}  "
              f"KneeOff={knee - hip} (L1={l1:.3f})  "
              f"AnkleOff={ankle - knee} (L2={l2:.3f})  "
              f"rest thigh_rot={t1:.4f}deg knee_rel={t2 - t1:.4f}deg "
              f"({t1/180*3.14159265358979:.6f} / {(t2 - t1)/180*3.14159265358979:.6f} rad)")
        print(f"      sole_anchor={sole}  sole_align(常量)={sole}  "
              f"ankle_up(常量)={ankle - sole}")
    bend = local_of(KNEE["far"]) - local_of(HIP["far"])
    print(f"bend_sign 账：膝在 hip->ankle 连线的 +perp 侧 = 前方(+x) -> bend_sign=+1")

    if analyze_only:
        return 0

    # ---- 生成 6 个腿部部件 ----
    outer = '<g transform="translate(2,2) scale(0.3377) translate(-329,-474)">'
    for (side, part), idx in PARTS.items():
        el = paths[idx]["element"]
        hip_c, knee_c, ankle_c = HIP[side], KNEE[side], ANKLE[side]
        sole_c = SOLE[side]
        svg_local = local_of
        knee_off = svg_local(knee_c) - svg_local(hip_c)
        ankle_off = svg_local(ankle_c) - svg_local(knee_c)
        header = f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="108" height="108">
<!-- 玩家机甲·{"远" if side == "far" else "近"}腿·{ {"thigh": "大腿", "shin": "小腿", "foot": "脚掌"}[part] }件：{PART_COMMENT[part].format(side="远" if side == "far" else "近")}。
     骨架部件流拆件（生成器 tools/split_player_legs.py 产出，路径原样搬运不改色不改形，勿手改 d）。
     画布 108x108 与身体件同空间：画布位 = (2,2)+0.3377*(orig-(329,474))，画布中心(54,54)=机体锚点（精灵缩放 0.5833333）。
     本腿轴点账（画布位 -> 精灵局部）：胯 hip={hip_c} -> {svg_local(hip_c)}；
     膝 knee={knee_c}（骨局部偏移 {knee_off}）；
     踝 ankle={ankle_c}（骨局部偏移 {ankle_off}）；脚掌接地 sole={sole_c}。
     场景装配：Visuals/LegRig/ 下 Hip{side.capitalize()}(骨原点=胯轴)/Sprite 为本件，Knee 子节点挂小腿件；
     IK 按 Knee/Ankle 节点实际位置取骨长（scripts/player/leg_ik.gd），轴点在编辑器里可拖调。 -->
{outer}
  {el}
</g>
</svg>
"""
        out = os.path.join(os.path.abspath(OUT_DIR),
                           f"player_mech_user_leg_{side}_{part}.svg")
        with open(out, "w", encoding="utf-8", newline="\n") as f:
            f.write(header)
        print(f"wrote {os.path.relpath(out, os.path.join(os.path.dirname(__file__), '..'))}")

    # ---- 重写 body：只保留躯干（去掉 6 条腿路径，其余逐字保留）----
    new_text = text
    for (side, part), idx in PARTS.items():
        el = paths[idx]["element"]
        assert el in new_text, f"path{idx} 不在源件文本里"
        new_text = new_text.replace(el + "\n", "", 1) if el + "\n" in new_text \
            else new_text.replace(el, "", 1)
    old_head = text[text.index("<!--"):text.index("-->") + 3]
    new_head = """<!-- 玩家机甲·身体件（躯干）：腰/跨/胸+胸传感器/胸-肩。腿已拆为独立骨件
     （远/近各 大腿/小腿/脚掌 = player_mech_user_leg_{far,near}_{thigh,shin,foot}.svg），
     场景装配与关节轴点账见 tools/split_player_legs.py 与 scripts/player/leg_ik.gd。
     用户绘制 v2 拆件（唯一美术定稿 player_mech_user_v2.svg，本件不改色不改形）。
     色阶：受光#3c4148/中值#2e3238/暗板#26292e/最深#1d2024 + 橙#ffa04a；无头无眼（设计如此）。
     矩形+rotate 已烘焙为等价多边形（ThorVG 不支持 rect+rotate，2026-10-16 崩溃规避）。
     画布 108×108 原坐标空间，画布中心(54,54)=机体锚点原点（精灵缩放 0.5833333，局内 63px 高）。
     肩关节(臂件旋转轴)在本画布 (33.54,12.20)；喷口枢轴(辉光中心)在本画布 (14.83,34.42)。
     臂件/喷口件见 player_mech_user_arm.svg / player_mech_user_nozzle.svg。 -->"""
    new_text = new_text.replace(old_head, new_head, 1)
    with open(os.path.abspath(SRC), "w", encoding="utf-8", newline="\n") as f:
        f.write(new_text)
    print("rewrote body (torso only)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
