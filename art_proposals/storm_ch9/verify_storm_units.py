# -*- coding: utf-8 -*-
"""第九章单位像素级自验 + 排布预览。
1) Godot(ThorVG) 光栅每张 SVG（scale 4）；
2) 断言：非全透明、非品红占位、alpha>0 像素灰阶跨度 ≥32、调色板主色存在；
3) 锚点对齐：与 assets/world_8 同名件比对——画布尺寸一致、独眼红核心像素位置一致；
   危险件锚点（接地点/顶点）像素不透明；
4) 拼排布预览 units_preview_ch9.png。"""
import os
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
    r = subprocess.run([GODOT, "--headless", "--path", ROOT, "--script",
                        "res://art_proposals/raster_svg.gd", "--", "res://" + rel,
                        "res://" + relo, str(scale)], capture_output=True, text=True)
    if not os.path.exists(out_png):
        raise SystemExit(f"raster fail {rel}: {r.stderr[-400:]}")
    return Image.open(out_png).convert("RGBA")


def red_core(img, win=None):
    """独眼核心红像素（#ff4640 近似、alpha 高）的质心，画布坐标。"""
    xs = ys = n = 0
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if win and not (abs((x+.5)/SC-win[0])<=6 and abs((y+.5)/SC-win[1])<=6):
                continue
            if a > 200 and r > 230 and 50 < g < 90 and 50 < b < 90:
                xs += x; ys += y; n += 1
    if n == 0:
        return None
    return ((xs / n + 0.5) / SC, (ys / n + 0.5) / SC)


PAIRS = {  # 九章件 : 八章同位件（锚点比对）
    "enemy_storm_walker_body": "enemy_salt_walker_body",
    "enemy_storm_walker_arm": "enemy_salt_walker_arm",
    "enemy_storm_drone": "enemy_salt_drone",
    "enemy_storm_drone_arm": "enemy_salt_drone_arm",
    "enemy_storm_shield_body": "enemy_salt_shield_body",
    "enemy_storm_elite_body": "enemy_salt_elite_body",
    "enemy_storm_elite_arm": "enemy_salt_elite_arm",
    "boss_storm_body": "boss_salt_body",
    "boss_storm_arm": "boss_salt_wing",
}
# 骨架挂点（画布坐标）必须落在不透明像素上
JOINTS = {
    "enemy_storm_walker_body": [(16, 24), (15.5, 18.3)],
    "enemy_storm_walker_arm": [(36, 8), (6, 15)],
    "enemy_storm_drone": [(12, 14.4)],
    "enemy_storm_drone_arm": [(28, 8), (13, 9.5)],
    "enemy_storm_shield_body": [(24, 24), (23.5, 18.3)],
    "enemy_storm_elite_body": [(44, 12), (19, 26.5)],
    "enemy_storm_elite_arm": [(17, 40), (17, 6)],
    "boss_storm_body": [(150, 26), (55, 63), (150, 160), (206, 52), (230, 56), (254, 60)],
    "boss_storm_arm": [(78, 22), (10, 22)],
    "fx_storm_stake_high": [(14, 115), (14, 6)],
    "fx_storm_stake_low": [(16, 45), (16, 6)],
    "fx_storm_rod": [(18, 137), (18, 19), (14.5, 80), (21.5, 80)],
    "fx_storm_arc_lash": [(64, 12)],
}
EYE_KEYS = {'enemy_storm_walker_body','enemy_storm_shield_body','enemy_storm_elite_body'}
ANCHOR_BBOX = {  # 危险件：不透明包围盒底边=接地点 y、顶边=顶点 y（±1）
    "fx_storm_stake_high": (116, 4), "fx_storm_stake_low": (46, 4), "fx_storm_rod": (138, 18),
}


def main():
    os.makedirs(RENDER, exist_ok=True)
    fails, log, imgs = [], [], {}
    for fn in sorted(os.listdir(UNITS)):
        if not fn.endswith(".svg"):
            continue
        key = fn[:-4]
        img = raster(os.path.join(UNITS, fn), os.path.join(RENDER, key + ".png"))
        imgs[key] = img
        px = list(img.get_flattened_data())
        op = [p for p in px if p[3] > 0]
        magenta = sum(1 for p in op if p[3] > 128 and p[0] > 240 and p[1] < 20 and p[2] > 240)
        lum = [int(0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]) for p in op]
        span = (max(lum) - min(lum)) if lum else 0
        ok = len(op) > 0 and magenta == 0 and span >= 32
        msg = f"{key}: {img.width}x{img.height} opaque={len(op)} magenta={magenta} lumspan={span}"
        for (jx, jy) in JOINTS.get(key, []):
            a = img.getpixel((min(img.width - 1, int(jx * SC)), min(img.height - 1, int(jy * SC))))[3]
            if a == 0:
                ok = False
                msg += f" JOINT({jx},{jy})透明"
        if key in ANCHOR_BBOX:
            bb = img.getbbox()
            bot, top = bb[3] / SC, bb[1] / SC
            eb, et = ANCHOR_BBOX[key]
            msg += f" bbox_y={top:.2f}..{bot:.2f}"
            if abs(bot - eb) > 1 or abs(top - et) > 1.5:
                ok = False
                msg += " ANCHOR_BBOX偏"
        if key in PAIRS:
            ref_svg = os.path.join(ROOT, "assets", "world_8", PAIRS[key] + ".svg")
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
    # R10 读色分族：旧雷光紫 #a678e8 零残留；装饰紫 #6e52a0 不许出现在危险件
    def near(p, c, tol=14):
        return p[3] > 128 and all(abs(p[i] - c[i]) <= tol for i in range(3))
    for key, img in imgs.items():
        px_ = list(img.get_flattened_data())
        old = sum(near(p, (0xa6, 0x78, 0xe8)) for p in px_)
        live = sum(near(p, (0xf0, 0xe6, 0xff), 8) for p in px_)
        dec = sum(near(p, (0x6e, 0x52, 0xa0), 6) for p in px_)
        bad = old > 0 or (dec > 0 and key.startswith("fx_"))
        log.append(f"  color {key}: old={old} live_core={live} decor={dec}" + (" FAIL" if bad else ""))
        if bad:
            fails.append(key + ":color")
    print("\n".join(log))

    # ---- 排布预览：本章天色+走道带，2x 单位 ----
    W, H = 2400, 900
    sheet = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(sheet)
    for y in range(H):
        t = y / H
        c0, c1 = (0x3a, 0x44, 0x48), (0x8e, 0x8e, 0x92)
        d.line([(0, y), (W, y)], fill=tuple(int(c0[i] + (c1[i] - c0[i]) * t) for i in range(3)))
    GY = 760
    d.rectangle([0, GY, W, H], fill=(0x4e, 0x44, 0x52))
    d.line([(0, GY), (W, GY)], fill=(0xb0, 0xa4, 0xbc), width=4)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 24)
    except OSError:
        font = ImageFont.load_default()

    def put(key, x, ground_canvas_y, scale=2, label=None, arm=None, pivot=None, arm_pivot=None):
        im = imgs[key]
        k = scale / SC
        im2 = im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS)
        y = GY - int(ground_canvas_y * scale)
        sheet.alpha_composite(im2, (x, y))
        if arm:
            a = imgs[arm]
            a2 = a.resize((int(a.width * k), int(a.height * k)), Image.LANCZOS)
            sheet.alpha_composite(a2, (int(x + (pivot[0] - arm_pivot[0]) * scale),
                                       int(y + (pivot[1] - arm_pivot[1]) * scale)))
        if label:
            d.text((x, GY + 20), label, font=font, fill=(236, 232, 244))

    put("enemy_storm_walker_body", 40, 50, label="步行者", arm="enemy_storm_walker_arm", pivot=(16, 24), arm_pivot=(36, 8))
    put("enemy_storm_shield_body", 220, 50, label="盾卫", arm="enemy_storm_walker_arm", pivot=(24, 24), arm_pivot=(36, 8))
    put("enemy_storm_drone", 400, 200, label="无人机", arm="enemy_storm_drone_arm", pivot=(15.2, 21), arm_pivot=(28, 8))
    put("enemy_storm_elite_body", 560, 80, label="精英·架线", arm="enemy_storm_elite_arm", pivot=(44, 12), arm_pivot=(17, 40))
    # 跨缆示意：高缆 / 低缆（世界 1:1 刻度，桩高即缆高）
    def span(x0, key, H_, ax, ay, txt):
        im = imgs[key]
        im1 = im.resize((im.width // SC, im.height // SC), Image.LANCZOS)
        for xx in (x0, x0 + 320):
            sheet.alpha_composite(im1, (xx - ax, GY - ay))
        d.line([(x0, GY - H_), (x0 + 320, GY - H_)], fill=(0x26, 0x20, 0x32), width=3)  # 紧绷灰缆（未带电态）
        d.text((x0 + 60, GY + 20), txt, font=font, fill=(236, 232, 244))
    # R16 排布：低缆右桩 x=1460，针1 x=1640（水平间隔 180 ≥150），互不叠压
    span(760, "fx_storm_stake_high", 110, 14, 116, "高缆 H110（钻）")
    span(1140, "fx_storm_stake_low", 40, 16, 46, "低缆 H40（飞）")
    ROD_XS = (1640, 1740, 1840)
    rim = imgs["fx_storm_rod"].resize((36, 140), Image.LANCZOS)
    for rx_ in ROD_XS:
        sheet.alpha_composite(rim, (rx_ - 18, GY - 138))
    d.text((1660, GY + 20), "引雷针 120", font=font, fill=(236, 232, 244))
    # R15：弧弹用新色（芯 #f0e6ff + 外辉 #c9a6ff），2x 放大后置于暗天区读色
    al = imgs["fx_storm_arc_lash"].resize((256, 48), Image.LANCZOS)
    AL_XY = (1100, 300)
    sheet.alpha_composite(al, AL_XY)
    d.text((1140, 360), "普攻断缆弧", font=font, fill=(236, 232, 244))
    # BOSS 1:1.5，船底贴 hover 示意
    bb = imgs["boss_storm_body"]
    s15 = 1.5 / SC
    b2 = bb.resize((int(bb.width * s15), int(bb.height * s15)), Image.LANCZOS)
    bx, by = 1820, 140
    sheet.alpha_composite(b2, (bx, by))
    ar = imgs["boss_storm_arm"]
    a2 = ar.resize((int(ar.width * s15), int(ar.height * s15)), Image.LANCZOS)
    sheet.alpha_composite(a2, (int(bx + (150 - 78) * 1.5), int(by + (26 - 22) * 1.5)))
    d.text((bx, by + 290), "BOSS·引雷 浮空巡线舰", font=font, fill=(236, 232, 244))
    out = os.path.join(HERE, "units_preview_ch9.png")
    rgb = sheet.convert("RGB")
    rgb.save(out)
    print("preview", out)
    stake_right = 1140 + 320
    gap = ROD_XS[0] - stake_right
    print(f"R16 gap low-stake-right {stake_right} -> rod1 {ROD_XS[0]} = {gap}px", "OK" if gap >= 150 else "FAIL")
    if gap < 150:
        fails.append("R16:gap")

    # R15 明度实测：取预览图上弧弹区/BOSS 区的像素，按 HSV V 分族
    import colorsys
    def v_of(c):
        return colorsys.rgb_to_hsv(*(ch / 255.0 for ch in c))[2]
    def near_rgb(c, ref, tol):
        return all(abs(c[i] - ref[i]) <= tol for i in range(3))
    def region_stat(box, ref, tol):
        px_ = rgb.crop(box).getdata()
        hits = [c for c in px_ if near_rgb(c, ref, tol)]
        if not hits:
            return 0, None
        mean = tuple(sum(c[i] for c in hits) / len(hits) for i in range(3))
        return len(hits), mean
    al_box = (AL_XY[0], AL_XY[1], AL_XY[0] + 256, AL_XY[1] + 48)
    n_core, m_core = region_stat(al_box, (0xf0, 0xe6, 0xff), 28)
    n_glow, m_glow = region_stat(al_box, (0xc9, 0xa6, 0xff), 34)
    boss_box = (bx, by, bx + 450, by + 270)
    n_dec, m_dec = region_stat(boss_box, (0x6e, 0x52, 0xa0), 22)
    # 弧弹像素主色（alpha 合成后非背景像素的均值：背景=天色渐变，取与天色差 >40 的像素）
    sky_c = rgb.getpixel((AL_XY[0] - 6, AL_XY[1] + 24))
    body = [c for c in rgb.crop(al_box).getdata() if sum(abs(c[i] - sky_c[i]) for i in range(3)) > 40]
    m_body = tuple(round(sum(c[i] for c in body) / max(len(body), 1)) for i in range(3))
    print(f"R15 arc-lash core n={n_core} mean={m_core and tuple(round(v) for v in m_core)} V={m_core and round(v_of(m_core), 3)}")
    print(f"R15 arc-lash glow n={n_glow} mean={m_glow and tuple(round(v) for v in m_glow)} V={m_glow and round(v_of(m_glow), 3)}")
    print(f"R15 boss decor-violet n={n_dec} mean={m_dec and tuple(round(v) for v in m_dec)} V={m_dec and round(v_of(m_dec), 3)}")
    print(f"R15 arc-lash body-pixel mean (vs sky {sky_c}) = {m_body} V={round(v_of(m_body), 3)}")
    dv = (v_of(m_glow) if m_glow else 0) - (v_of(m_dec) if m_dec else 1)
    ok15 = n_core > 0 and n_glow > 0 and n_dec > 0 and dv >= 0.25
    print(f"R15 V(glow)-V(decor)={dv:.3f}", "OK" if ok15 else "FAIL")
    if not ok15:
        fails.append("R15:value")

    # R16 特写：低缆矮桩与引雷针 1:1 实机比例并排（同一缩放 ×4，地面同线）
    CW, CH_ = 520, 720
    cu = Image.new("RGBA", (CW, CH_), (0x56, 0x62, 0x60, 255))
    dc = ImageDraw.Draw(cu)
    cgy = 640
    dc.rectangle([0, cgy, CW, CH_], fill=(0x4e, 0x44, 0x52))
    dc.line([(0, cgy), (CW, cgy)], fill=(0xb0, 0xa4, 0xbc), width=4)
    low = imgs["fx_storm_stake_low"]   # SC=4 光栅 = 实机 ×4
    rod = imgs["fx_storm_rod"]
    cu.alpha_composite(low, (130 - 16 * SC, cgy - 46 * SC))
    cu.alpha_composite(rod, (380 - 18 * SC, cgy - 138 * SC))
    dc.text((60, cgy + 20), "低缆矮桩 H40", font=font, fill=(236, 232, 244))
    dc.text((300, cgy + 20), "引雷针 H120", font=font, fill=(236, 232, 244))
    dc.text((20, 16), "1:1 实机比例并排（同倍率 ×4）", font=font, fill=(236, 232, 244))
    cpath = os.path.join(HERE, "units_closeup_stake_rod_ch9.png")
    cu.convert("RGB").save(cpath)
    print("closeup", cpath)
    if fails:
        print("FAILED:", fails)
        sys.exit(1)
    print("ALL PASS")


if __name__ == "__main__":
    main()
