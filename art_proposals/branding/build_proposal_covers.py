# -*- coding: utf-8 -*-
"""提案场景平地版封面三件套：平地场景图 + 标题文字图 + 合成封面。

场景底 = 美术提案生成器（art_proposals/generate_proposals.py）的方案三「雪原警戒点」
与方案四「珊瑚辐合夜」，**平地重排**（提案原图带 t2/t1 台地档位；本版 SEQ 全 0 =
单一地面线，道具基底随之落平地），原生 1200x540 生成后按比例矢量包边
（天空上延=天顶色平涂、滩地下延=立面底色平涂，渐变端点处无缝）。

交付（本目录）：
  scene_p3_flat_16x9.png / _4x3 / _20x9   方案三平地场景（雪原警戒点）
  scene_p4_flat_16x9.png / _4x3 / _20x9   方案四平地场景（珊瑚辐合夜）
  title_on_bright.png                     标题·亮底用（深色字，透明底）
  title_on_dark.png                       标题·暗底用（白字+暗影，透明底）
  cover_p3_16x9.png / _4x3 / _20x9        合成封面（雪原+标题）
  cover_p4_16x9.png / _4x3 / _20x9        合成封面（珊瑚夜+标题）
  showcase_proposal_covers.png            总览拼图

用法: build / raster / stamp / validate
"""
import os, sys, math, random

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "art_proposals"))
sys.path.insert(0, HERE)

import generate_proposals as gp                      # noqa: E402  Svg/glow_dot/haze_band/arc_path
from terrain_blocks import ground_v2                 # noqa: E402

OUT = HERE
RENDER = os.path.join(OUT, "covers", "render")
GODOT = r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"

# ---- 平地化：档位表全拉平（提案原图 t2/t1 台地 → 单一地面线；块顶 332=提案地面线+2） ----
ground_v2.SEQ = [0] * 10
ground_v2.TIER_Y = {0: 332.0, 1: 332.0, 2: 332.0}
FLAT_TOP = 332.0

# ============================================================
# 方案三平地版：雪原警戒点（逐字保留原构图；电杆/雪堆基底落平地 332）
# ============================================================
def snowfield_flat():
    rng = random.Random(303)
    s = gp.Svg()

    sky = s.vgrad("sky3", [(0, "#d4e2ea", 1), (0.6, "#e9f1f5", 1), (1, "#f7fafb", 1)])
    s.rect(0, 0, gp.W, gp.GROUND, sky)
    s.circle(870, 110, 120, "#ffffff", 0.08)
    s.circle(870, 110, 80, "#ffffff", 0.18)
    s.circle(870, 110, 46, "#ffffff", 0.55)

    # ---- 远岭 ----
    ridge = [(0, gp.GROUND)]
    rx = 0.0
    while rx < gp.W:
        rx += rng.uniform(80, 150)
        ridge.append((rx, gp.GROUND - rng.uniform(24, 70)))
    ridge.append((gp.W, gp.GROUND))
    s.poly(ridge, "#c2d2db")

    # ---- 远景军事设施 ----
    far = "#8ba0ab"
    s.rect(130, gp.GROUND - 34, 92, 34, far, 0.9)
    s.rect(126, gp.GROUND - 40, 100, 8, "#eef4f7", 0.95)
    s.rect(165, gp.GROUND - 26, 22, 10, "#4a5a64", 0.9)
    # 雷达塔（桁架计算）
    tx = 690.0
    s.line(tx - 20, gp.GROUND, tx - 4, 128, far, 3)
    s.line(tx + 20, gp.GROUND, tx + 4, 128, far, 3)
    yy = gp.GROUND - 24
    while yy > 140:
        t = (gp.GROUND - yy) / (gp.GROUND - 128)
        xl = tx - 20 + 16 * t
        xr = tx + 20 - 16 * t
        s.line(xl, yy, xr, yy - 22, far, 1.5, 0.9)
        s.line(xr, yy, xl, yy - 22, far, 1.5, 0.9)
        yy -= 22
    s.rect(tx - 24, 150, 48, 5, far)
    s.circle(tx, 112, 11, far)
    s.line(tx, 112, tx + 9, 103, far, 1.5)
    s.line(tx, 128, tx, 84, far, 2.5)
    gp.glow_dot(s, tx, 82, "#e23d3d", r=3, halos=((7, 0.35), (13, 0.15)))
    s.rect(1040, gp.GROUND - 26, 70, 26, far, 0.85)
    s.rect(1036, gp.GROUND - 31, 78, 7, "#eef4f7", 0.9)
    gp.haze_band(s, 200, gp.GROUND, "#dfe9ee", 0.4)

    # ---- 中景：半埋运输机残骸 ----
    s.group(f"translate(885,{gp.f(gp.GROUND + 40)}) rotate(-6)")
    s.rect(0, -86, 300, 46, "#5a6a74", rx=22)
    s.rect(0, -56, 300, 8, "#46545e")
    s.rect(10, -66, 300, 5, "#c24438", 0.8)
    wx = 26
    while wx < 270:
        s.rect(wx, -78, 7, 8, "#2e3840", 0.9)
        wx += 19
    s.poly([(240, -86), (296, -138), (306, -132), (286, -84)], "#54646e")
    s.poly([(120, -64), (200, -50), (188, -36), (96, -54)], "#4c5a64")
    s.rect(150, -52, 34, 16, "#46545e", rx=6)
    s.poly([(286, -60), (306, -50), (300, -38), (280, -48)], "#3e4a53")
    s.endgroup()
    s.poly([(860, gp.GROUND + 2), (940, gp.GROUND - 28), (1030, gp.GROUND - 14), (1120, gp.GROUND + 2), (1120, gp.GROUND + 4), (860, gp.GROUND + 4)], "#e9f1f5")
    s.ellipse(1010, gp.GROUND - 2, 140, 12, "#eef4f7")

    # ---- 路侧电线杆（平地版：基底全 332） ----
    pole = "#6e8694"
    poles = [(150, 3, FLAT_TOP), (430, -2, FLAT_TOP), (730, 2, FLAT_TOP), (980, -3, FLAT_TOP)]
    for i, (pxx, tilt, pbase) in enumerate(poles):
        ph = 52
        s.line(pxx, pbase, pxx + tilt * 0.4, pbase - ph, pole, 2.5, 0.9)
        s.line(pxx - 8 + tilt, pbase - ph + 6, pxx + 8 + tilt, pbase - ph + 6, pole, 2, 0.9)
        s.line(pxx + tilt, pbase - ph, pxx + tilt, pbase - ph - 6, pole, 1.5, 0.9)
        if i:
            qx, qt, qbase = poles[i - 1]
            x0w, x1w = qx + qt, pxx + tilt
            y0w = qbase - ph - 6
            y1w = pbase - ph - 6
            s.path(f"M {gp.f(x0w)},{gp.f(y0w)} Q {gp.f((x0w + x1w) / 2)},{gp.f((y0w + y1w) / 2 + 9)} {gp.f(x1w)},{gp.f(y1w)}",
                   stroke=pole, w=1.1, opacity=0.7)

    # ---- 地表：拆地块 v2 平地 ----
    ground_v2.draw_ground(s, "ch3_snow", bottom=gp.H, k=1.0)
    # 中景雪堆（平地版：基底全 332）
    for mx, mw, mh in ((240, 160, 22), (520, 120, 14), (760, 200, 26)):
        s.ellipse(mx, FLAT_TOP, mw / 2, mh, "#dbe6ec")

    # ---- 风雪 ----
    for _ in range(16):
        lx, ly = rng.uniform(80, gp.W), rng.uniform(40, 260)
        ln = rng.uniform(40, 95)
        s.line(lx, ly, lx - ln, ly + ln * 0.12, "#ffffff", 2, rng.uniform(0.3, 0.55), cap="round")
    for _ in range(18):
        s.circle(rng.uniform(0, gp.W), rng.uniform(10, gp.H), rng.uniform(1, 2.2), "#ffffff", rng.uniform(0.5, 0.9))
    return s

# ============================================================
# 方案四平地版：珊瑚辐合夜（原构图无踩档位道具，逐字保留）
# ============================================================
def coral_flat():
    rng = random.Random(404)
    s = gp.Svg()

    sky = s.vgrad("sky4", [(0, "#090d22", 1), (0.55, "#131a38", 1), (1, "#273052", 1)])
    s.rect(0, 0, gp.W, gp.GROUND, sky)
    for _ in range(24):
        s.circle(rng.uniform(0, gp.W), rng.uniform(10, 220), rng.uniform(0.8, 1.6), "#dfe6ff", rng.uniform(0.3, 0.85))

    # ---- 天空碎环巨构 ----
    rcx, rcy, rr = 795.0, 168.0, 148.0
    for a0, a1 in ((-30, 80), (95, 150), (166, 205), (216, 258), (268, 320)):
        s.path(gp.arc_path(rcx, rcy, rr, a0, a1), stroke="#1c2547", w=24)
    s.path(gp.arc_path(rcx + 7, rcy + 9, rr, 20, 62), stroke="#232d55", w=22)
    s.path(gp.arc_path(rcx, rcy, rr - 12, 120, 205), stroke="#ff5a33", w=2.5, opacity=0.85)
    s.path(gp.arc_path(rcx, rcy, rr - 12, 120, 205), stroke="#ff5a33", w=9, opacity=0.2)
    for aa in (128, 160, 188):
        ax = rcx + (rr - 12) * math.cos(math.radians(aa))
        ay = rcy + (rr - 12) * math.sin(math.radians(aa))
        s.circle(ax, ay, 4, "#ff7a45", 0.35)
        s.circle(ax, ay, 1.6, "#ffb36b", 0.95)

    # ---- 远景巨构塔群 ----
    for tx, tw, th in ((60, 80, 210), (185, 56, 260), (300, 110, 170), (520, 70, 240),
                       (640, 90, 140), (980, 100, 250), (1120, 60, 190)):
        top = gp.GROUND - th
        s.rect(tx, top, tw, th, "#0d1330")
        if rng.random() < 0.6:
            cut = rng.uniform(10, 30)
            s.poly([(tx, top), (tx + tw, top), (tx + tw, top + cut)], "#0d1330")
        if rng.random() < 0.5:
            s.line(tx + tw * 0.5, top, tx + tw * 0.5, top - rng.uniform(16, 40), "#0d1330", 2)
        for _ in range(rng.randint(2, 5)):
            s.rect(tx + rng.uniform(4, tw - 8), top + rng.uniform(10, th - 14), 2.5, 4, "#ff6a3d", rng.uniform(0.5, 0.9))
    s.ellipse(450, 262, 60, 13, "#ff5a33", 0.10)
    s.ellipse(450, 262, 28, 7, "#ff7a45", 0.16)

    # ---- 雾带 + 两侧岩丘 ----
    gp.haze_band(s, gp.GROUND - 74, gp.GROUND - 18, "#3a4674", 0.30)
    for side in ("L", "R"):
        if side == "L":
            mound = [(0, gp.GROUND), (30, gp.GROUND - 34), (90, gp.GROUND - 52), (160, gp.GROUND - 30), (230, gp.GROUND - 46), (265, gp.GROUND)]
        else:
            mound = [(930, gp.GROUND), (980, gp.GROUND - 40), (1060, gp.GROUND - 58), (1130, gp.GROUND - 28), (1200, gp.GROUND - 44), (1200, gp.GROUND)]
        s.poly(mound, "#0a0e22")
        for i in range(len(mound) - 1):
            x0, y0 = mound[i]
            x1, y1 = mound[i + 1]
            if y0 < gp.GROUND and y1 < gp.GROUND:
                s.line(x0, y0, x1, y1, "#4a5890", 1.2, 0.35)

    # ---- 地表：拆地块 v2 平地 ----
    ground_v2.draw_ground(s, "ch4_coral", bottom=gp.H, k=1.0)
    # 上升余烬
    for _ in range(15):
        ex, ey = rng.uniform(480, 820), rng.uniform(190, 330)
        s.circle(ex, ey, rng.uniform(1, 2), "#ff9c5a", rng.uniform(0.3, 0.9))
        s.line(ex, ey + 3, ex, ey + 9, "#ff9c5a", 1, 0.12)
    return s

# ============================================================
# 比例包装：原生 1200x540 平地场景 → 目标画布（天空上延/滩地下延）
# ============================================================
FRAC = 0.72              # 地面线构图分数（提案正本 61.1%，用户要求地面压低 → 72%）
SCENES = {
    "p3": dict(builder=snowfield_flat, sky_top="#d4e2ea", face_lo="#b3c5d1", decor=None,
               title=dict(text="#1d2024", shadow=None)),        # 亮雪天 → 深色字
    "p4": dict(builder=coral_flat, sky_top="#090d22", face_lo="#0a0d1c", decor="stars",
               title=dict(text="#ffffff", shadow="#29261e")),   # 靛蓝夜 → 白字+暗影
}
RATIOS = {
    "16x9": dict(W=2560, H=1440),
    "4x3": dict(W=2560, H=1920),
    "20x9": dict(W=2560, H=1152),
}   # 2K 家族：统一 2560 宽
AMBER = "#ffa04a"

def build_scene_svg(key, ratio):
    sc = SCENES[key]
    W, H = RATIOS[ratio]["W"], RATIOS[ratio]["H"]
    sc_s = W / 1200.0
    g_line = FRAC * H
    dy = g_line / sc_s - 330.0                    # 场景组原生下移量
    ext_top = dy * sc_s                           # 场景顶之上的天空延展
    scene_bot = (540.0 + dy) * sc_s               # 场景底（其下=滩地延展）
    body = sc["builder"]()

    parts = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">' % (W, H, W, H)]
    parts.append("<!-- %s 平地版 %s（提案原生 1200x540 平地重排 ×%.4f，天空上延 %.0fpx / 滩地下延 %.0fpx；地面线 y=%.0f=%.1f%%H） -->"
                 % (key, ratio, sc_s, ext_top, H - scene_bot, g_line, g_line / H * 100))
    parts.append("<defs>\n" + "\n".join(body.defs) + "\n</defs>")
    if ext_top > 0.5:
        parts.append('<rect x="0" y="0" width="%d" height="%.1f" fill="%s"/>' % (W, ext_top + 1, sc["sky_top"]))
        if sc["decor"] == "stars" and ext_top > 40:
            rng = random.Random(4040)
            n = int(ext_top * W / 9000) + 6
            parts.append("<!-- 延展天区星点（延续原星场风格） -->")
            for _ in range(n):
                parts.append('<circle cx="%.1f" cy="%.1f" r="%.2f" fill="#dfe6ff" opacity="%.2f"/>'
                             % (rng.uniform(0, W), rng.uniform(6, ext_top - 14),
                                rng.uniform(0.8, 1.6), rng.uniform(0.3, 0.85)))
    parts.append('<g transform="translate(0,%.2f) scale(%.5f)">\n' % (dy * sc_s, sc_s) + "\n".join(body.body) + "\n</g>")
    if H - scene_bot > 0.5:
        parts.append('<rect x="0" y="%.1f" width="%d" height="%.1f" fill="%s"/>' % (scene_bot - 1, W, H - scene_bot + 1, sc["face_lo"]))
    parts.append("</svg>")
    return "\n".join(parts)

# ---------- Godot 光栅 ----------
def cmd_raster():
    import subprocess
    os.makedirs(RENDER, exist_ok=True)
    jobs = [("covers/%s_flat_%s.svg" % (k, r), "covers/render/%s_flat_%s.png" % (k, r))
            for k in SCENES for r in RATIOS]
    for svg_name, png_name in jobs:
        svg = os.path.join(OUT, svg_name)
        png = os.path.join(OUT, png_name)
        print(">>", os.path.basename(svg))
        r = subprocess.run([GODOT, "--headless", "--path", ROOT,
                            "--script", "res://art_proposals/raster_svg.gd",
                            "--", svg, png, "1.0"], capture_output=True, text=True, timeout=120)
        tail = (r.stdout or "").strip().splitlines()[-2:] + (r.stderr or "").strip().splitlines()[-3:]
        assert r.returncode == 0 and os.path.exists(png), "raster fail %s:\n%s" % (svg_name, "\n".join(tail))

# ---------- 标题盖印 / 独立标题图 ----------
def _load_fonts(size_latin):
    from PIL import ImageFont
    FONTS = "C:/Windows/Fonts/"
    latin = None
    for fname, var in (("bahnschrift.ttf", "Bold"), ("arialbd.ttf", None)):
        if os.path.exists(FONTS + fname):
            try:
                latin = ImageFont.truetype(FONTS + fname, size_latin)
                if var:
                    latin.set_variation_by_name(var)
                break
            except Exception:
                latin = None
    size_cjk = int(size_latin * 0.62)
    cjk = None
    for fname in ("simhei.ttf", "msyhbd.ttc", "msyh.ttc"):
        if os.path.exists(FONTS + fname):
            cjk = ImageFont.truetype(FONTS + fname, size_cjk)
            break
    assert latin and cjk, "标题字体加载失败"
    return latin, cjk, size_cjk

def draw_title(d, x0, y0, size, text_color, shadow_color):
    """标题三件套：ARMOR RUSH + 琥珀横线 + 装甲疾驰。shadow_color=None 则不画影。"""
    latin, cjk, size_cjk = _load_fonts(size)
    trk = int(size * 0.05)
    sh = max(3, int(size * 0.045)) if shadow_color else 0

    def tracked(x, y, text, font, trk_):
        for ch in text:
            if shadow_color:
                d.text((x + sh, y + sh), ch, font=font, fill=shadow_color)
            d.text((x, y), ch, font=font, fill=text_color)
            x += d.textlength(ch, font=font) + trk_
        return x - trk_

    def tw(text, font, trk_):
        return sum(d.textlength(ch, font=font) for ch in text) + trk_ * (len(text) - 1)

    lw = tw("ARMOR RUSH", latin, trk)
    draw_x = tracked(x0, y0, "ARMOR RUSH", latin, trk)
    line_h = max(8, int(size * 0.055))
    ly = y0 + int(size * 1.16)
    pad = int(size * 0.04)
    if shadow_color:
        d.rectangle([x0 + sh, ly + sh, draw_x + pad + sh, ly + line_h + sh], fill=shadow_color)
    d.rectangle([x0, ly, draw_x + pad, ly + line_h], fill=AMBER)
    cy = ly + line_h + int(size * 0.30)
    ctrk = int(size_cjk * 0.13)
    tracked(x0, cy, "装甲疾驰", cjk, ctrk)
    return lw, cy + size_cjk - y0   # (主标题宽, 块总高)

def cmd_stamp():
    from PIL import Image, ImageDraw
    # 独立标题图（透明底，latin 280，两种亮暗底各一张）
    latin, cjk, size_cjk = _load_fonts(280)
    tmp = Image.new("RGBA", (3600, 1400), (0, 0, 0, 0))
    dt = ImageDraw.Draw(tmp)
    trk = int(280 * 0.05)
    lw = sum(dt.textlength(ch, font=latin) for ch in "ARMOR RUSH") + trk * 9
    ctrk = int(size_cjk * 0.13)
    cw = sum(dt.textlength(ch, font=cjk) for ch in "装甲疾驰") + ctrk * 3
    block_w = max(lw, cw)
    PADX, PADY = 60, 60
    Wt = int(block_w + PADX * 2 + 30)
    Ht = int(280 * 1.16 + max(8, int(280 * 0.055)) + int(280 * 0.30) + size_cjk + PADY * 2)
    for name, text_color, shadow in (("title_on_bright.png", "#1d2024", None),
                                     ("title_on_dark.png", "#ffffff", "#29261e")):
        img = Image.new("RGBA", (Wt, Ht), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        draw_title(d, PADX, PADY, 280, text_color, shadow)
        out = os.path.join(OUT, name)
        img.save(out)
        print("title ->", out, img.size)
    # 合成封面：场景 + 标题（左上，比例字号沿用封面线惯例）
    layout = {"16x9": (200, 0.14), "4x3": (200, 0.13), "20x9": (200, 0.14)}   # 统一 2560 宽 → 字号一致
    for key in SCENES:
        tcol = SCENES[key]["title"]
        for ratio, (size, yf) in layout.items():
            img = Image.open(os.path.join(RENDER, "%s_flat_%s.png" % (key, ratio))).convert("RGBA")
            d = ImageDraw.Draw(img)
            draw_title(d, int(img.width * 0.06), int(img.height * yf), size, tcol["text"], tcol["shadow"])
            out = os.path.join(OUT, "cover_%s_%s.png" % (key, ratio))
            img.convert("RGB").save(out)
            print("cover ->", out)
    # 平地场景图成品（无标题，交付可自拼的底图）
    for key in SCENES:
        for ratio in RATIOS:
            src = Image.open(os.path.join(RENDER, "%s_flat_%s.png" % (key, ratio))).convert("RGB")
            src.save(os.path.join(OUT, "scene_%s_flat_%s.png" % (key, ratio)))
            print("scene ->", os.path.join(OUT, "scene_%s_flat_%s.png" % (key, ratio)))

# ---------- 断言 + showcase ----------
def validate():
    from PIL import Image
    ok = True
    def chk(cond, msg):
        nonlocal ok
        print(("PASS " if cond else "FAIL ") + msg)
        ok = ok and cond
    def near(c, hexs, tol=16):
        t = tuple(int(hexs[i:i + 2], 16) for i in (1, 3, 5))
        return all(abs(a - b) <= tol for a, b in zip(c[:3], t))

    for key in SCENES:
        for ratio, cfg in RATIOS.items():
            p = os.path.join(OUT, "scene_%s_flat_%s.png" % (key, ratio))
            if not os.path.exists(p):
                chk(False, p + " 缺失")
                continue
            im = Image.open(p).convert("RGB")
            W, H = cfg["W"], cfg["H"]
            G = FRAC * H
            chk(im.size == (W, H), "%s %s 尺寸 %s" % (key, ratio, im.size))
            # 地表已画：走道带取样 ≠ 天区取样
            band = im.getpixel((W // 2, int(G + 28 * (W / 1200.0) * 0.5)))
            sky = im.getpixel((W // 2, int(G - 60)))
            chk(sum(abs(a - b) for a, b in zip(band, sky)) > 40, "%s %s 地表/天区分离" % (key, ratio))
            # 平地：地面线上方应无立面墙（原档位墙会在 G 上方出现断面色）
            s_ = W / 1200.0
            walls = 0
            for fx in (0.25, 0.5, 0.75):
                x = int(W * fx)
                col = [im.getpixel((x, int(G - yy))) for yy in (4, 10, 18, 28)]
                walls += sum(1 for c in col if abs(c[0] - c[2]) < 8 and sum(c) > 570)
            chk(walls <= 2, "%s %s 平地无台地墙(亮断面采样 %d)" % (key, ratio, walls))

    # 标题图：透明底 + 有字形
    for name in ("title_on_bright.png", "title_on_dark.png"):
        im = Image.open(os.path.join(OUT, name)).convert("RGBA")
        corners = [im.getpixel((2, 2)), im.getpixel((im.width - 3, 2)), im.getpixel((2, im.height - 3))]
        chk(all(c[3] == 0 for c in corners), name + " 四角透明")
        glyphs = sum(1 for x in range(0, im.width, 4) for y in range(0, im.height, 4) if im.getpixel((x, y))[3] > 200)
        chk(glyphs > 800, name + " 字形存在(%d 采样)" % glyphs)

    # 合成封面：标题字与琥珀线
    for key in SCENES:
        tc = SCENES[key]["title"]["text"]
        for ratio, cfg in RATIOS.items():
            p = os.path.join(OUT, "cover_%s_%s.png" % (key, ratio))
            im = Image.open(p).convert("RGB")
            W, H = cfg["W"], cfg["H"]
            size = 200
            y0 = int(H * {"16x9": 0.14, "4x3": 0.13, "20x9": 0.14}[ratio])
            if tc == "#ffffff":
                glyph = sum(1 for x in range(0, W, 3) for y in range(y0, y0 + int(size * 1.1), 3)
                            if near(im.getpixel((x, y)), "#ffffff", 26))
            else:
                glyph = sum(1 for x in range(0, W, 3) for y in range(y0, y0 + int(size * 1.1), 3)
                            if sum(im.getpixel((x, y))) < 210)
            chk(glyph > 200, "cover_%s_%s 标题字形(%d)" % (key, ratio, glyph))
            amber = sum(1 for x in range(0, W, 2) for y in range(y0 + int(size * 1.0), y0 + int(size * 1.35))
                        if near(im.getpixel((x, y)), "#ffa04a", 36))
            chk(amber > 60, "cover_%s_%s 琥珀横线(%d)" % (key, ratio, amber))

    # showcase：2 列（场景行 + 封面行）
    from PIL import Image
    th_w = 700
    rows = []
    for key in ("p3", "p4"):
        for name in ("scene_%s_flat_16x9" % key, "cover_%s_16x9" % key,
                     "scene_%s_flat_4x3" % key, "cover_%s_4x3" % key,
                     "scene_%s_flat_20x9" % key, "cover_%s_20x9" % key):
            im = Image.open(os.path.join(OUT, name + ".png")).convert("RGB")
            rows.append(im.resize((th_w, round(im.height * th_w / im.width)), Image.LANCZOS))
    cols = 2
    rows_n = (len(rows) + cols - 1) // cols
    cell_h = max(t.height for t in rows) + 16
    canvas = Image.new("RGB", (th_w * cols + 30, rows_n * cell_h + 16), (24, 24, 24))
    for i, t in enumerate(rows):
        canvas.paste(t, (10 + (i % cols) * (th_w + 10), 8 + (i // cols) * cell_h))
    canvas.save(os.path.join(OUT, "showcase_proposal_covers.png"))
    print("showcase ->", os.path.join(OUT, "showcase_proposal_covers.png"))
    print("RESULT:", "ALL PASS" if ok else "HAS FAILURES")

if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "build"
    if arg == "build":
        os.makedirs(os.path.join(OUT, "covers"), exist_ok=True)
        for key in SCENES:
            for ratio in RATIOS:
                p = os.path.join(OUT, "covers", "%s_flat_%s.svg" % (key, ratio))
                with open(p, "w", encoding="utf-8", newline="\n") as f:
                    f.write(build_scene_svg(key, ratio))
                print("wrote", p)
    elif arg == "raster":
        cmd_raster()
    elif arg == "stamp":
        cmd_stamp()
    elif arg == "validate":
        validate()
