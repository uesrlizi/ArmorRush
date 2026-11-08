# -*- coding: utf-8 -*-
"""玩家机甲腿部 IK 姿态拼装预览（与 leg_ik.gd 同一套两骨 IK 数学）。

把 6 个腿部骨件 + 躯干按场景坐标账在 PIL 里摆姿态（世界系、未镜像）：
- 站立（crouch=0）必须与拆件前的整图逐像素一致（回归判据，AA 接缝除外）；
- 滑行下蹲（crouch=3 默认档）与深蹲（crouch=8）看关节 overlap 是否破皮。
输出 art_proposals/mech/work/leg_ik_preview/pose_preview.png（并排+轴点标记+地面线）。

坐标账：世界画布位 = 54 + 局部位/S（S=0.5833333）；crouch 时 Visuals 整层下移
crouch（局部单位）= 身体/髋/膝同步 +shift=crouch/S（画布单位），唯独脚掌目标钉死不动。
"""
import math
import os
import subprocess
import sys

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PREVIEW = os.path.join(ROOT, "art_proposals", "mech", "work", "leg_ik_preview")
GODOT = "C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"

R = 8          # 光栅倍率（108 画布 -> 864px）
CANVAS = 108.0
S = 0.5833333  # 精灵缩放（局部 = (画布-54)*S）

# ---- 轴点账（与 tools/split_player_legs.py 同源，局部单位）----
HIP = {"far": (-9.625, 2.0417), "near": (-4.34, 2.0417)}
KNEE_OFF = (2.0417, 11.6667)
ANKLE_OFF = (-3.9667, 12.25)
SOLE_ALIGN = {"far": (-11.55, 30.275), "near": (-6.265, 30.275)}
ANKLE_UP = (0.0, -4.3167)

# 静止姿态角（=手绘姿态，骨链的零点）：增量制——骨节点转的是「相对静止」的偏移量，
# 美术件本身已带静止倾角，绝对角只在中间量里出现。
THIGH_REST_DEG = -9.9262
KNEE_REL_REST_DEG = 27.8687
SHIN_ABS_REST_DEG = THIGH_REST_DEG + KNEE_REL_REST_DEG  # = 17.9425（小腿美术自带的倾角）


def to_canvas(local_pt):
    return (54.0 + local_pt[0] / S, 54.0 + local_pt[1] / S)


def solve_leg(side, crouch):
    """与 leg_ik.gd 相同的两骨 IK（局部系）：hip 恒定，脚掌目标随 Visuals 下沉上抬。
    返回 (thigh_rot_deg, knee_rel_deg, knee_pos_local)。"""
    hip = HIP[side]
    sole_local = (SOLE_ALIGN[side][0], SOLE_ALIGN[side][1] - crouch)
    ankle_t = (sole_local[0] + ANKLE_UP[0], sole_local[1] + ANKLE_UP[1])
    l1 = math.hypot(*KNEE_OFF)
    l2 = math.hypot(*ANKLE_OFF)
    dx, dy = ankle_t[0] - hip[0], ankle_t[1] - hip[1]
    raw = math.hypot(dx, dy)
    dist = min(max(raw, abs(l1 - l2) + 0.01), l1 + l2 - 0.01)
    ux, uy = dx / raw, dy / raw
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    px, py = uy, -ux  # bend_sign=+1：膝盖朝画布前方(+x)
    kx = hip[0] + ux * a + px * h
    ky = hip[1] + uy * a + py * h
    thigh_rot = math.degrees(math.atan2(ky - hip[1], kx - hip[0])) - 90.0
    shin_abs = math.degrees(math.atan2(ankle_t[1] - ky, ankle_t[0] - kx)) - 90.0
    return thigh_rot, shin_abs - thigh_rot, (kx, ky)


def paste_part(img, part_png, rot_deg, pivot_c, target_c):
    """把骨件贴上画布：绕 pivot 旋转 rot_deg 后落到 target（均为画布单位）。
    正向 xo = T + Rθ(x - P)；AFFINE 填逆映射 (xs,ys) = P + R^-1(xo - T)。"""
    P = (pivot_c[0] * R, pivot_c[1] * R)
    T = (target_c[0] * R, target_c[1] * R)
    th = math.radians(rot_deg)
    ct, st = math.cos(th), math.sin(th)
    coeffs = (ct, st, P[0] - (ct * T[0] + st * T[1]),
              -st, ct, P[1] - (-st * T[0] + ct * T[1]))
    img.alpha_composite(part_png.transform(part_png.size, Image.AFFINE, coeffs,
                                           resample=Image.BICUBIC))


def compose(crouch, show_pivots=False):
    img = Image.new("RGBA", (int(CANVAS * R), int(CANVAS * R)), (0, 0, 0, 0))
    body = Image.open(os.path.join(PREVIEW, "player_mech_user_body.png")).convert("RGBA")
    shift = crouch / S  # Visuals 下沉量（画布单位）
    for side in ("far", "near"):
        thigh_rot, knee_rel, knee_pos = solve_leg(side, crouch)
        hip_l = HIP[side]
        knee_rest_l = (hip_l[0] + KNEE_OFF[0], hip_l[1] + KNEE_OFF[1])
        hip_c = to_canvas(hip_l)
        knee_rest_c = to_canvas(knee_rest_l)
        sole_c = to_canvas(SOLE_ALIGN[side])  # 世界钉死
        for part in ("foot", "thigh", "shin"):
            png = Image.open(os.path.join(
                PREVIEW, f"player_mech_user_leg_{side}_{part}.png")).convert("RGBA")
            if part == "foot":
                paste_part(img, png, 0.0, sole_c, sole_c)  # 不转不移
            elif part == "thigh":
                paste_part(img, png, thigh_rot - THIGH_REST_DEG, hip_c,
                           (hip_c[0], hip_c[1] + shift))
            else:
                # 增量制：美术自带静止倾角，贴图旋转量 = 绝对角 - 静止角。
                # （场景里同账：Knee 节点 rotation = 现相对角 - 静止相对角。）
                knee_c = to_canvas(knee_pos)
                paste_part(img, png, thigh_rot + knee_rel - SHIN_ABS_REST_DEG,
                           knee_rest_c, (knee_c[0], knee_c[1] + shift))
    img.alpha_composite(body, (0, int(round(shift * R))))  # 躯干最后画=盖大腿根

    if show_pivots:
        draw = ImageDraw.Draw(img)
        for side in ("far", "near"):
            thigh_rot, knee_rel, knee_pos = solve_leg(side, crouch)
            marks = [
                (to_canvas(HIP[side])[0], to_canvas(HIP[side])[1] + shift, (255, 80, 80)),
                (to_canvas(knee_pos)[0], to_canvas(knee_pos)[1] + shift, (80, 255, 120)),
                (to_canvas(SOLE_ALIGN[side])[0], to_canvas(SOLE_ALIGN[side])[1], (80, 160, 255)),
            ]
            for x, y, color in marks:
                x, y = x * R, y * R
                draw.ellipse([x - 5, y - 5, x + 5, y + 5], outline=color, width=3)
    return img


def main():
    # 回归基准：拆件前的原始整图（git HEAD 版本）放进预览目录光栅一次
    orig_svg = os.path.join(PREVIEW, "orig_body.svg").replace("\\", "/")
    rel = orig_svg[len(ROOT) + 1:]
    with open(orig_svg, "wb") as f:
        f.write(subprocess.run(
            ["git", "show", "HEAD:assets/common/player_mech_user_body.svg"],
            cwd=ROOT, capture_output=True, check=True).stdout)
    if not os.path.exists(os.path.join(PREVIEW, "orig_body.png")):
        r = subprocess.run([GODOT, "--headless", "--path", ROOT,
                            "--script", "res://art_proposals/raster_svg.gd", "--",
                            "res://" + rel, "res://" + rel.replace(".svg", ".png")],
                           capture_output=True, text=True, timeout=90)
        print(r.stdout.strip() or r.stderr.strip())
    orig = Image.open(os.path.join(PREVIEW, "orig_body.png")).convert("RGBA")

    rest = compose(0.0)
    a, b = rest.tobytes(), orig.tobytes()
    diff = sum(1 for i in range(0, len(a), 4) if a[i:i + 4] != b[i:i + 4])
    print(f"rest pose vs original: {diff} differing px / {len(a)//4}")

    tiles = [("crouch=0 standing (max height)", rest),
             ("crouch=3 slide (default)", compose(3.0, show_pivots=True)),
             ("crouch=8 deep", compose(8.0, show_pivots=True)),
             ("original", orig)]
    pad, label_h = 20, 40
    out = Image.new("RGBA", (pad + len(tiles) * (864 + pad), pad * 2 + label_h + 864),
                    (24, 26, 30, 255))
    d = ImageDraw.Draw(out)
    for i, (label, tile) in enumerate(tiles):
        x = pad + i * (864 + pad)
        out.alpha_composite(tile, (x, pad + label_h))
        d.text((x + 4, pad + 10), label, fill=(230, 230, 230))
        d.line([x, pad + label_h + 106 * R, x + 864, pad + label_h + 106 * R],
               fill=(255, 90, 60, 160), width=2)
    out.save(os.path.join(PREVIEW, "pose_preview.png"))
    print("saved", os.path.join(PREVIEW, "pose_preview.png"))


if __name__ == "__main__":
    sys.exit(main())
