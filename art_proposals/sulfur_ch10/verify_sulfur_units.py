# -*- coding: utf-8 -*-
"""第十章单位像素级自验 + 排布预览。
1) Godot(ThorVG) 光栅每张 SVG（scale 4）；
2) 断言：非全透明、非品红占位、alpha>0 像素灰阶跨度 ≥32、源码无 transform/filter/text/use；
3) 锚点对齐：与 assets/world_9 同位件比对——画布尺寸一致、独眼红核心质心一致（±0.25px）；
   骨架挂点/危险件锚点像素不透明；危险件 bbox 底=接地点、顶=顶点；
4) 敌营主色 BODY #4a2a3a 存在于单位件、硫焰蓝 #48b4ff 存在；
5) 拼排布预览 units_preview_ch10.png（本章天色+走道带）。"""
import os
import re
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
GODOT = "C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
UNITS = os.path.join(HERE, "units")
RENDER = os.path.join(UNITS, "render")
SC = 4


def raster(abs_svg, out_png, scale=SC):
    rel = os.path.relpath(abs_svg, ROOT).replace("\\", "/")
    relo = os.path.relpath(out_png, ROOT).replace("\\", "/")
    if os.path.exists(out_png):
        os.remove(out_png)
    r = subprocess.run([GODOT, "--headless", "--path", ROOT, "--script",
                        "res://art_proposals/raster_svg.gd", "--", "res://" + rel,
                        "res://" + relo, str(scale)], capture_output=True, text=True)
    if not os.path.exists(out_png):
        raise SystemExit(f"raster fail {rel}: {r.stderr[-400:]}")
    return Image.open(out_png).convert("RGBA")


def red_core(img, win=None):
    xs = ys = n = 0
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if win and not (abs((x + .5) / SC - win[0]) <= 6 and abs((y + .5) / SC - win[1]) <= 6):
                continue
            if a > 200 and r > 230 and 50 < g < 90 and 50 < b < 90:
                xs += x; ys += y; n += 1
    if n == 0:
        return None
    return ((xs / n + 0.5) / SC, (ys / n + 0.5) / SC)


PAIRS = {
    "enemy_sulfur_walker_body": "enemy_storm_walker_body",
    "enemy_sulfur_walker_arm": "enemy_storm_walker_arm",
    "enemy_sulfur_drone": "enemy_storm_drone",
    "enemy_sulfur_drone_arm": "enemy_storm_drone_arm",
    "enemy_sulfur_shield_body": "enemy_storm_shield_body",
    "enemy_sulfur_elite_body": "enemy_storm_elite_body",
    "enemy_sulfur_elite_arm": "enemy_storm_elite_arm",
    "boss_sulfur_body": "boss_storm_body",
    "boss_sulfur_arm": "boss_storm_arm",
}
JOINTS = {
    "enemy_sulfur_walker_body": [(16, 24), (15.5, 18.3)],
    "enemy_sulfur_walker_arm": [(36, 8), (6, 15)],
    "enemy_sulfur_drone": [(12, 14.4), (15.2, 21)],
    "enemy_sulfur_drone_arm": [(28, 8), (13, 9.5)],
    "enemy_sulfur_shield_body": [(24, 24), (23.5, 18.3)],
    "enemy_sulfur_elite_body": [(44, 12), (19, 26.5)],
    "enemy_sulfur_elite_arm": [(17, 40), (17, 6)],
    # 枢座 / 独眼 / NozzlePort / DrillPort / VentPort
    "boss_sulfur_body": [(150, 26), (55, 63), (4, 144), (150, 168), (246, 46)],
    "boss_sulfur_arm": [(78, 22), (10, 22)],
    "fx_sulfur_vent": [(40, 25.5), (10, 14), (70, 14)],
    "fx_sulfur_vent_glow": [(32, 13)],
    "fx_sulfur_vent_flame": [(36, 221), (36, 4), (6, 200), (66, 200)],
    "fx_sulfur_drill": [(16, 8), (30, 8)],
    "fx_sulfur_flare_puff": [(24, 24)],
    "fx_sulfur_gas_shell": [(12, 12)],
    "fx_sulfur_cloud": [(100, 42), (2, 42), (198, 42)],
    "fx_sulfur_cloud_front": [(20, 42), (30, 10), (30, 74)],
}
EYE_KEYS = {"enemy_sulfur_walker_body", "enemy_sulfur_shield_body", "enemy_sulfur_elite_body"}
# 危险件：不透明包围盒 (底 y, 顶 y, 左 x, 右 x)（画布坐标，±1.5）
ANCHOR_BBOX = {
    "fx_sulfur_vent": (26, None, 0, 80),
    "fx_sulfur_vent_flame": (223, 2, 2, 70),
}
BODY_RGB = (0x4a, 0x2a, 0x3a)
BLUE_RGB = (0x48, 0xb4, 0xff)


def near(p, c, tol):
    return p[3] > 200 and all(abs(p[i] - c[i]) <= tol for i in range(3))


def main():
    os.makedirs(RENDER, exist_ok=True)
    fails, log, imgs = [], [], {}
    for fn in sorted(os.listdir(UNITS)):
        if not fn.endswith(".svg"):
            continue
        key = fn[:-4]
        src = open(os.path.join(UNITS, fn), encoding="utf-8").read()
        banned = re.findall(r"transform|<filter|<text|<use|<pattern|<image", src)
        img = raster(os.path.join(UNITS, fn), os.path.join(RENDER, key + ".png"))
        imgs[key] = img
        px = list(img.get_flattened_data())
        op = [p for p in px if p[3] > 0]
        magenta = sum(1 for p in op if p[3] > 128 and p[0] > 240 and p[1] < 20 and p[2] > 240)
        lum = [int(0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]) for p in op]
        span = (max(lum) - min(lum)) if lum else 0
        nb = sum(near(p, BODY_RGB, 10) for p in px)
        nblue = sum(near(p, BLUE_RGB, 24) for p in px)
        ok = len(op) > 0 and magenta == 0 and span >= 32 and not banned
        msg = (f"{key}: {img.width}x{img.height} opaque={len(op)} magenta={magenta} "
               f"lumspan={span} body={nb} blue={nblue} banned={len(banned)}")
        if key.startswith(("enemy_", "boss_")) and nb == 0:
            ok = False; msg += " NO_BODY_COLOR"
        if key in ("boss_sulfur_arm", "fx_sulfur_cloud"):
            if nblue > 0:
                ok = False; msg += " BLUE_FORBIDDEN"
        elif nblue == 0:
            ok = False; msg += " NO_BLUE"
        for (jx, jy) in JOINTS.get(key, []):
            a = img.getpixel((min(img.width - 1, int(jx * SC)), min(img.height - 1, int(jy * SC))))[3]
            if a == 0:
                ok = False
                msg += f" JOINT({jx},{jy})透明"
        if key in ANCHOR_BBOX:
            bb = img.getbbox()
            l, t, r, b = (v / SC for v in bb)
            eb, et, el, er = ANCHOR_BBOX[key]
            msg += f" bbox=({l:.1f},{t:.1f})..({r:.1f},{b:.1f})"
            if abs(b - eb) > 1.5 or (et is not None and abs(t - et) > 1.5) or abs(l - el) > 1.5 or abs(r - er) > 1.5:
                ok = False
                msg += " ANCHOR_BBOX偏"
        if key in PAIRS:
            ref_svg = os.path.join(ROOT, "assets", "world_9", PAIRS[key] + ".svg")
            ref = raster(ref_svg, os.path.join(RENDER, "_ref_" + PAIRS[key] + ".png"))
            if ref.size != img.size:
                ok = False
                msg += f" SIZE≠ref{ref.size}"
            w = JOINTS[key][1] if key in EYE_KEYS else None
            c1, c2 = red_core(img, w), red_core(ref, w)
            if c2 is not None:
                if c1 is None or abs(c1[0] - c2[0]) > 0.25 or abs(c1[1] - c2[1]) > 0.25:
                    ok = False
                msg += f" eye={c1 and tuple(round(v, 2) for v in c1)} ref={tuple(round(v, 2) for v in c2)}"
        msg += " OK" if ok else " FAIL"
        log.append(msg)
        if not ok:
            fails.append(key)
    print("\n".join(log))

    # ---- R15：BOSS 贴图蓝色发光像素只许在 Nozzle/Drill/Vent 与登记举升喷口 ----
    bimg = imgs["boss_sulfur_body"]
    allowed = [(4, 144, 10), (150, 160, 24), (246, 46, 16), (110, 160, 13), (210, 154, 13)]
    stray = 0
    for yy in range(bimg.height):
        for xx in range(bimg.width):
            p = bimg.getpixel((xx, yy))
            if p[3] > 60 and p[2] > 180 and p[2] - p[0] > 80:
                cx, cy = xx / SC, yy / SC
                if not any((cx - ax) ** 2 + (cy - ay) ** 2 <= r * r for ax, ay, r in allowed):
                    stray += 1
    print(f"R15 boss stray blue glow px = {stray}", "OK" if stray == 0 else "FAIL")
    if stray:
        fails.append("R15_boss_stray_blue")

    # ---- R14：烟墙在第十章真实天空色上 1:1 合成，带中段主体 vs 背景亮度差/对比度 ----
    def rl(c):
        def ch(v):
            v /= 255.0
            return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
        return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2])
    # world_10 真实天空色：world_10.tscn 天空渐变 = env_sulfur_far 底色 #5a5632→#8a8348→#b2a866
    # （far 条画布 1300 高，画布 y=世界 y+570）。取带中段世界 y=470 → t=1040/1300=0.80。
    stops = [(0.0, (0x5a, 0x56, 0x32)), (0.5, (0x8a, 0x83, 0x48)), (1.0, (0xb2, 0xa8, 0x66))]
    tt = (470 + 570) / 1300.0
    (t0, a), (t1, b) = stops[1], stops[2]
    kk = (tt - t0) / (t1 - t0)
    sky = tuple(int(a[i] + (b[i] - a[i]) * kk) for i in range(3))
    # 参考（不作闸）：far 条实渲同高度像素（前排火山口壁会落在带后）
    far_png = os.path.join(HERE, "env_sulfur_far.png")
    fim = Image.open(far_png).convert("RGBA")
    fk = fim.height / 1300.0
    wall_px = [fim.getpixel((x, int((470 + 570) * fk))) for x in range(0, fim.width, max(1, fim.width // 64))]
    wall = tuple(sum(p[i] for p in wall_px) // len(wall_px) for i in range(3))
    cl1 = imgs["fx_sulfur_cloud"].resize((200, 84), Image.LANCZOS)
    frame = Image.new("RGBA", (200, 84), sky + (255,))
    frame.alpha_composite(cl1)
    mid = [frame.getpixel((x, y)) for x in range(20, 180) for y in range(30, 54)]
    body = tuple(sum(p[i] for p in mid) // len(mid) for i in range(3))
    lb, ls = rl(body), rl(sky)
    dl = abs(ls - lb)
    cr = (max(lb, ls) + 0.05) / (min(lb, ls) + 0.05)
    ok14 = dl >= 0.20 and cr >= 2.5
    print(f"R14 cloud body={body} L={lb:.3f} sky={sky} L={ls:.3f} dL={dl:.3f} contrast={cr:.2f}", "OK" if ok14 else "FAIL")
    print(f"R14 info: far 条同高度均色 {wall} L={rl(wall):.3f}（火山口壁，非闸）")
    if not ok14:
        fails.append("R14_cloud_contrast")

    # ---- 排布预览：本章赭橄榄天 + 玄武走道带，单位 2x ----
    W, H = 2400, 1000
    sheet = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(sheet)
    GY = 820
    stops = [(0.0, (0x5a, 0x56, 0x32)), (0.55, (0x8a, 0x83, 0x48)), (1.0, (0xb2, 0xa8, 0x66))]
    for y in range(GY):
        t = y / GY
        for (t0, a), (t1, b) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                k = (t - t0) / (t1 - t0)
                d.line([(0, y), (W, y)], fill=tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)))
                break
    d.rectangle([0, GY, W, H], fill=(0x4c, 0x4a, 0x44))
    d.line([(0, GY), (W, GY)], fill=(0xc8, 0xbc, 0x78), width=4)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 24)
    except OSError:
        font = ImageFont.load_default()

    def scaled(key, scale):
        im = imgs[key]
        k = scale / SC
        return im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)

    def put(key, x, ground_canvas_y, scale=2, label=None, arm=None, pivot=None, arm_pivot=None, gy=GY):
        im2 = scaled(key, scale)
        y = gy - int(ground_canvas_y * scale)
        if arm:
            a2 = scaled(arm, scale)
            arm_xy = (int(x + (pivot[0] - arm_pivot[0]) * scale), int(y + (pivot[1] - arm_pivot[1]) * scale))
        sheet.alpha_composite(im2, (x, y))
        if arm:
            sheet.alpha_composite(a2, arm_xy)
        if label:
            d.text((x, GY + 24), label, font=font, fill=(236, 232, 220))

    put("enemy_sulfur_walker_body", 40, 50, label="步行者", arm="enemy_sulfur_walker_arm", pivot=(16, 24), arm_pivot=(36, 8))
    put("enemy_sulfur_shield_body", 220, 50, label="盾卫", arm="enemy_sulfur_walker_arm", pivot=(24, 24), arm_pivot=(36, 8))
    put("enemy_sulfur_drone", 400, 260, label="无人机", arm="enemy_sulfur_drone_arm", pivot=(15.2, 21), arm_pivot=(28, 8))
    put("enemy_sulfur_elite_body", 560, 80, label="精英·窜井", arm="enemy_sulfur_elite_arm", pivot=(44, 12), arm_pivot=(17, 40))
    # 井口三态（实机 1:1：底座+亮井 / 底座+亮井+焰柱 H220 / 底座）
    VX = (900, 1060, 1220)
    vent1 = scaled("fx_sulfur_vent", 1)
    glow1 = scaled("fx_sulfur_vent_glow", 1)
    flame1 = scaled("fx_sulfur_vent_flame", 1)
    for i, vx in enumerate(VX):
        if i == 1:
            sheet.alpha_composite(flame1, (vx - 36, GY - 222))
        if i <= 1:
            sheet.alpha_composite(glow1, (vx - 32, GY - 18))
        sheet.alpha_composite(vent1, (vx - 40, GY - 26))
    d.text((860, GY + 24), "亮井 / 喷发 H220 / 息", font=font, fill=(236, 232, 220))
    # 普攻火鞭示意：焰团 ×1 串（48px 步进 64）+ 钻头 + 硫气弹（2x）
    for i in range(5):
        sheet.alpha_composite(scaled("fx_sulfur_flare_puff", 1), (1340 + i * 64 - 24, 300 + i * 6 - 24))
    d.text((1340, 340), "普攻·硫焰扫掠", font=font, fill=(236, 232, 220))
    sheet.alpha_composite(scaled("fx_sulfur_drill", 2), (1340, 420))
    d.text((1420, 420), "钻头弹", font=font, fill=(236, 232, 220))
    sheet.alpha_composite(scaled("fx_sulfur_gas_shell", 2), (1340, 480))
    d.text((1420, 488), "硫气弹", font=font, fill=(236, 232, 220))
    # 硫云带（预览摆放示意，世界 y428..512 绝对带，不随地表）
    cl = scaled("fx_sulfur_cloud", 1)
    for cx in range(1300, 1700, 200):
        sheet.alpha_composite(cl, (cx, GY - 172))
    sheet.alpha_composite(scaled("fx_sulfur_cloud_front", 1), (1280, GY - 172))
    d.text((1300, GY - 210), "硫云爆燃带 世界 y 428..512（绝对带）· 左缘=蓝焰锋线", font=font, fill=(236, 232, 220))
    # BOSS 1:1.5 + 臂
    bx, by = 1800, 160
    sheet.alpha_composite(scaled("boss_sulfur_body", 1.5), (bx, by))
    sheet.alpha_composite(scaled("boss_sulfur_arm", 1.5), (int(bx + (150 - 78) * 1.5), int(by + (26 - 22) * 1.5)))
    d.text((bx, by + 290), "BOSS·井口 井场管线母舰", font=font, fill=(236, 232, 220))
    for (cx, cy, nm) in ((4, 144, "Nozzle"), (150, 168, "Drill"), (246, 46, "Vent")):
        X, Y = bx + cx * 1.5, by + cy * 1.5
        d.ellipse([X - 5, Y - 5, X + 5, Y + 5], outline=(255, 255, 255), width=2)
        d.text((X + 6, Y - 30 if nm == "Vent" else Y + 6), nm, font=font, fill=(255, 255, 255))
    out = os.path.join(HERE, "units_preview_ch10.png")
    sheet.convert("RGB").save(out)
    print("preview", out)
    if fails:
        print("FAILED:", fails)
        sys.exit(1)
    print("ALL PASS")


if __name__ == "__main__":
    main()
