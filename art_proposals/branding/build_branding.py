# -*- coding: utf-8 -*-
"""Armor Rush 品牌图拼装：游戏图标(512) + 引擎启动画面(2400x1080)。
全部由现有素材拼装（拿现有素材拼，不改件）：
  玩家机甲 = assets/player_mech_user_{nozzle,body,arm}.svg 按 player.tscn 挂载账组装
  BOSS     = assets/boss_rust_{body,rotor,tailrotor}.svg
  环境     = assets/env_rust_far.svg(远景连天空) / env_rust_mid.svg(中景) /
             env_rust_ground_top.svg(地表带) / env_rust_deck.svg(图标地面)
  点缀     = assets/bullet_player.svg(图标黄弹) / assets/fx_smoke.svg(待机汽)
用法: python build_branding.py build   # 产出 icon.svg / boot_splash.svg / cover.svg
      python build_branding.py stamp   # cover_2x.png 盖标题 -> cover.png（630x500，itch 封面）
      python build_branding.py validate [render_dir]  # PIL 像素断言 + showcase
"""
import os, re, sys, random

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS = os.path.join(ROOT, "assets")
OUT = os.path.dirname(os.path.abspath(__file__))

# ---------- 源件内文提取（剥 xml 声明与 <svg> 外壳，只留内容） ----------
def inner(path):
    with open(os.path.join(ASSETS, path), encoding="utf-8") as f:
        s = f.read()
    m = re.search(r"<svg[^>]*>", s)
    assert m, path
    body = s[m.end(): s.rfind("</svg>")]
    return body.strip()

def rename_ids(svg, prefix):
    """同文件贴多份时渐变 id 防撞：id="sky" -> id="prefix_sky"，url(#sky) 同步。"""
    svg = re.sub(r'id="([A-Za-z0-9_]+)"', lambda m: 'id="%s_%s"' % (prefix, m.group(1)), svg)
    svg = re.sub(r'url\(#([A-Za-z0-9_]+)\)', lambda m: 'url(#%s_%s)' % (prefix, m.group(1)), svg)
    return svg

# ---------- 玩家机甲：player.tscn 挂载账（Visuals 局部系，画布中心=精灵原点） ----------
# body 108² 画布，精灵位 (6.18,0) 缩放 0.5833 -> translate(6.18,0) scale(0.5833) translate(-54,-54)
# arm 160² 画布（轴=画布中心），ArmPivot (-5.75,-24.38) 精灵居中 -> 同构
# nozzle 32² 画布（轴=画布中心），精灵位 = NozzlePivot(-17.82,-13)+(2.126,0.549)
MECH_PARTS = [
    ("nozzle", "player_mech_user_nozzle.svg", "translate(-15.69,-12.45) scale(0.5833) translate(-16,-16)"),
    ("body",   "player_mech_user_body.svg",   "translate(6.18,0) scale(0.5833) translate(-54,-54)"),
    ("arm",    "player_mech_user_arm.svg",    "translate(-5.75,-24.38) scale(0.5833) translate(-80,-80)"),
]
# 机甲 Visuals 局部包围盒（由画布账反推）：x -25.3..34.35(枪口向右)，y -30.1(肩顶)..29.2(足底)。
MECH_TOP, MECH_FOOT, MECH_LEFT, MECH_RIGHT = -30.1, 29.2, -25.3, 34.35
MUZZLE = (36.31, -12.69)      # = ArmPivot(-5.75,-24.38)+(42.06,11.69)

def mech_group(ax, ay, s, comment=""):
    parts = "\n".join(
        '  <g transform="%s">\n%s\n  </g>' % (tf, inner(src))
        for _, src, tf in MECH_PARTS)
    return ('<!-- 玩家机甲：三拆件按 player.tscn 挂载账组装（喷口在体后、臂在最前），%s\n'
            '     组变换 translate(%.1f,%.1f) scale(%.2f)；足底=AY+29.2*S，枪口=AX+(%.2f*S,%.2f*S) -->\n'
            '<g transform="translate(%.2f,%.2f) scale(%.4f)">\n%s\n</g>'
            % (comment, ax, ay, s, MUZZLE[0], MUZZLE[1], ax, ay, s, parts))

# ---------- 图标 512 ----------
def build_icon():
    S = 6.2
    GROUND = 430
    AY = round(GROUND - MECH_FOOT * S, 1)          # 足底踩地面
    AX = round(256 - 4.5 * S, 1)                   # 机甲内容中心(局部x≈4.5)对齐画布正中 x=256
    rain = []
    rng = random.Random(7)
    for i in range(9):
        x, y = rng.uniform(10, 500), rng.uniform(8, 300)
        L = rng.uniform(46, 108)
        rain.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#e8e0c0" stroke-width="%.1f" opacity="%.2f"/>'
                    % (x, y, x - 0.14 * L, y + L, rng.choice([1.5, 2.0, 2.5]), rng.uniform(0.14, 0.26)))
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
<!-- Armor Rush 游戏图标 512x512（游戏内 icon.svg 同源）。
     构图（2026-10-17 用户定稿）：机甲全身立姿居中(内容中心 x=256，足踩 y={GROUND} 平台缘)，
     远景塔楼剪影+斜雨，暖沙尘天四段平涂(#b3a97f/#c9b88e/#a89a76/#9c8f6e=env_rust_far 天色账)。
     黄弹已按用户要求移除。色全部出自现役素材：机甲4阶灰+琥珀#ffa04a，平台#46433a，地面底#3a382f。
     比例账：机甲高 {59.3*S:.0f}px=画布 72%（小尺寸可读底线 60%）；
     机甲挂载账同 player.tscn（喷口/体/臂三件，精灵缩放 0.5833 内置）。
     小尺寸自验：icon_48.png 中央暗部须仍成剪影。 -->
<!-- 天空四段平涂（env_rust_far 渐变色的分档取样） -->
<rect x="0" y="0" width="512" height="165" fill="#b3a97f"/>
<rect x="0" y="165" width="512" height="97" fill="#c9b88e"/>
<rect x="0" y="262" width="512" height="118" fill="#a89a76"/>
<rect x="0" y="380" width="512" height="50" fill="#9c8f6e"/>
<!-- 远景塔楼剪影（env_rust_far 塔 x0.4 透明度档） -->
<polygon points="300,430 300,300 312,270 322,282 332,262 342,276 342,430" fill="#857a5e" opacity="0.4"/>
<polygon points="350,430 350,240 366,228 380,242 394,232 408,248 408,430" fill="#9a9078" opacity="0.5"/>
<polygon points="422,430 422,210 440,198 458,214 474,206 490,222 490,430" fill="#857a5e" opacity="0.5"/>
<line x1="436" y1="198" x2="436" y2="176" stroke="#857a5e" stroke-width="3" opacity="0.5"/>
<!-- 地面：env_rust_deck 平台条 x2 + 底色(env_rust_ground_top 底缘色) -->
<rect x="0" y="456" width="512" height="56" fill="#3a382f"/>
<g transform="translate(0,{GROUND})">{inner("env_rust_deck.svg")}</g>
<g transform="translate(720,{GROUND})">{inner("env_rust_deck.svg")}</g>
{mech_group(AX, AY, S, "居中 x=256，足踩平台缘 y=%d" % GROUND)}
<!-- 雨（前景斜雨，风向 -x） -->
{chr(10).join(rain)}
</svg>
'''

# ---------- 启动画面 2400x1080（20:9 = 窗口比例，fullsize 满铺无缝） ----------
def build_splash():
    GROUND = 880
    rng = random.Random(11)
    rain = []
    for i in range(40):
        x, y = rng.uniform(-30, 2430), rng.uniform(-30, 1000)
        L = rng.uniform(55, 135)
        bright = rng.random() < 0.16
        rain.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%.1f" opacity="%.2f"/>'
                    % (x, y, x - 0.16 * L, y + L,
                       "#e8e0c0" if bright else rng.choice(["#ddd3ac", "#e8e0c0"]),
                       rng.choice([3.0, 2.4]) if bright else rng.uniform(1.4, 2.2),
                       rng.uniform(0.24, 0.3) if bright else rng.uniform(0.09, 0.2)))
    far = "\n".join('<!-- env_rust_far 第%d联（含原生天空/雾带/浮尘，原尺寸，底对齐 y=1080 -->\n<g transform="translate(%d,-220)">%s</g>'
                    % (i + 1, i * 1024, rename_ids(inner("env_rust_far.svg"), "f%d" % (i + 1))) for i in range(3))
    mid = "\n".join('<g transform="translate(%d,400)">%s</g>' % (i * 1024, rename_ids(inner("env_rust_mid.svg"), "m%d" % (i + 1))) for i in range(3))
    gtop = "\n".join('<g transform="translate(%d,%d)">%s</g>' % (i * 256, GROUND, inner("env_rust_ground_top.svg")) for i in range(10))
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2400 1080" width="2400" height="1080">
<!-- Armor Rush 引擎启动画面 2400x1080（20:9=窗口比例，boot_splash 满铺）。
     构图（2026-10-17 用户定稿：只要背景，不要主体）——纯锈雨废都空景：
     env_rust_far x3 联=远景+原生天空（原尺寸，底对齐 y=1080，塔顶落 y 610..790），
     env_rust_mid x3 联=中景（基底 y=920 压进地表带），env_rust_ground_top x10 联=地表(y={GROUND}..936)+
     底色延到画布底，前景斜雨。机甲/BOSS/待机汽已按用户要求移除——主体交给游戏内启动页。 -->
{far}
{mid}
<!-- 地表：env_rust_ground_top 联排 + 底色延到画布底 -->
<rect x="0" y="936" width="2400" height="144" fill="#3a382f"/>
{gtop}
{chr(10).join(rain)}
</svg>
'''

# ---------- itch 封面 630x500（场景 + 玩家机甲；标题由 PIL 盖印，见 stamp_cover） ----------
def build_cover():
    GROUND = 400
    S = 3.9
    AY = round(GROUND - MECH_FOOT * S, 1)          # 286.1 -> 足底 400 踩地表
    AX = round(470 - 4.5 * S, 1)                   # 机甲内容中心 x=470（右下，朝右蓄势）
    rng = random.Random(5)
    rain = []
    for i in range(14):
        x, y = rng.uniform(-10, 640), rng.uniform(-10, 470)
        L = rng.uniform(40, 95)
        bright = rng.random() < 0.16
        rain.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%.1f" opacity="%.2f"/>'
                    % (x, y, x - 0.16 * L, y + L,
                       "#e8e0c0" if bright else rng.choice(["#ddd3ac", "#e8e0c0"]),
                       2.6 if bright else rng.uniform(1.2, 2.0),
                       rng.uniform(0.22, 0.28) if bright else rng.uniform(0.09, 0.18)))
    far = ('<!-- env_rust_far x0.62（自带天空/雾带，塔顶落 y≈270，底越界由地表裁） -->\n'
           '<g transform="translate(0,-244.6) scale(0.62)">%s</g>'
           % rename_ids(inner("env_rust_far.svg"), "cf"))
    mid = ('<g transform="translate(0,117.6) scale(0.62)">%s</g>'   # 基底 y=440 压进地表带
           % rename_ids(inner("env_rust_mid.svg"), "cm"))
    gtop = "\n".join('<g transform="translate(%d,%d) scale(0.75)">%s</g>' % (i * 192, GROUND, inner("env_rust_ground_top.svg")) for i in range(4))
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 630 500" width="630" height="500">
<!-- Armor Rush itch 封面 630x500。构图：场景空景打底（同启动画面语言），
     玩家机甲 x3.9 立姿右下(x 内容中心 470，足踩 y={GROUND})朝右蓄势；
     左上标题区留给 stamp_cover 盖印（PIL 系统字体，白字+琥珀横线=播报字幕语言）。
     安全区账：itch feed 卡对封面做竖向居中裁(≈630x354，即 y 73..427)——
     标题 y 88..216、机甲 y 151..400 全部落在内；地面带下缘允许被裁。
     层账：远景 far x0.62 (0,-244.6) / 中景 mid x0.62 (0,117.6，基底 y=440) /
     地表 ground_top x0.75 联排 y={GROUND}..442 / 底色 #3a382f 到画布底 / 机甲 / 前景雨。 -->
{far}
{mid}
<rect x="0" y="442" width="630" height="58" fill="#3a382f"/>
{gtop}
{mech_group(AX, AY, S, "内容中心 x=470，足踩 y=%d" % GROUND)}
{chr(10).join(rain)}
</svg>
'''

def main_build():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("icon.svg", build_icon), ("boot_splash.svg", build_splash), ("cover.svg", build_cover)):
        p = os.path.join(OUT, name)
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write(fn())
        print("wrote", p)

# ---------- 封面标题盖印（ThorVG 渲不了文字，系统字体 PIL 盖印后降采样） ----------
def stamp_cover(render_dir):
    from PIL import Image, ImageDraw, ImageFont
    FONTS = "C:/Windows/Fonts/"
    def load(cands, size, variation=None):
        for name, var in cands:
            if os.path.exists(FONTS + name):
                try:
                    f = ImageFont.truetype(FONTS + name, size)
                    if var:
                        f.set_variation_by_name(var)
                    return f
                except Exception:
                    continue
        return ImageFont.load_default()
    img = Image.open(os.path.join(render_dir, "cover_2x.png")).convert("RGB")
    d = ImageDraw.Draw(img)
    latin = load([("bahnschrift.ttf", "Bold"), ("arialbd.ttf", None)], 116)
    cjk = load([("simhei.ttf", None), ("msyhbd.ttc", None), ("msyh.ttc", None)], 76)
    x0, y0, trk = 96, 176, 14                     # 2x 空间：1x 标题区 (48,88) 起
    x = x0
    for ch in "ARMOR RUSH":
        d.text((x, y0), ch, font=latin, fill="#ffffff")
        x += d.textlength(ch, font=latin) + trk
    tw = x - trk - x0
    d.rectangle([x0, 316, x0 + tw + 24, 328], fill="#ffa04a")   # 琥珀分隔横线（播报式）
    x = x0
    for ch in "装甲疾驰":
        d.text((x, 356), ch, font=cjk, fill="#ffffff")
        x += d.textlength(ch, font=cjk) + 10
    out = os.path.join(OUT, "cover.png")
    img.resize((630, 500), Image.LANCZOS).save(out)
    print("cover ->", out)

# ---------- PIL 断言 + showcase ----------
def main_validate(render_dir):
    from PIL import Image
    render_dir = render_dir or os.path.join(OUT, "render")
    ok = True
    def chk(cond, msg):
        nonlocal ok
        print(("PASS " if cond else "FAIL ") + msg)
        ok = ok and cond
    def near(c, hexs, tol=14):
        t = tuple(int(hexs[i:i + 2], 16) for i in (1, 3, 5))
        return all(abs(a - b) <= tol for a, b in zip(c[:3], t))

    icon = Image.open(os.path.join(render_dir, "icon_512.png")).convert("RGB")
    chk(near(icon.getpixel((508, 4)), "#b3a97f"), "icon 天空色")
    chk(near(icon.getpixel((256, 500)), "#3a382f"), "icon 地面底色")
    dark = sum(1 for x in range(40, 470) for y in range(60, 430)
               if sum(icon.getpixel((x, y))) < 210)   # 机甲4阶灰都 < 0x48*3≈216
    chk(dark > 20000, "icon 机甲剪影像素量(%d)" % dark)
    # 居中后琥珀世界位账（AX=228.1,S=6.2）：喷口辉光 AX-15.69*S≈(131,172)，胸传感器 AX+17.4*S≈(336,150)
    amber = sum(1 for x in range(106, 156) for y in range(148, 196)
                if near(icon.getpixel((x, y)), "#ffa04a", 40))
    amber += sum(1 for x in range(310, 364) for y in range(118, 192)
                 if near(icon.getpixel((x, y)), "#ffa04a", 40))
    chk(amber > 30, "icon 琥珀点缀(辉光+传感器 %dpx)" % amber)
    yellow = sum(1 for x in range(400, 512) for y in range(140, 200)
                 if near(icon.getpixel((x, y)), "#ffee58", 40))
    chk(yellow == 0, "icon 无黄弹(残留 %dpx)" % yellow)
    # 居中账：机甲暗部像素的 x 质心应落在 256±30
    xs, n = 0, 0
    for x in range(40, 470, 2):
        for y in range(60, 430, 2):
            if sum(icon.getpixel((x, y))) < 210:
                xs += x
                n += 1
    cx = xs / n if n else -1
    chk(abs(cx - 256) < 30, "icon 机甲居中(x质心 %.0f)" % cx)

    icon48 = Image.open(os.path.join(render_dir, "icon_48.png")).convert("RGB")
    w, h = icon48.size
    dark48 = sum(1 for x in range(w) for y in range(h) if sum(icon48.getpixel((x, y))) < 210)
    chk(dark48 > w * h * 0.10, "icon@48 剪影仍可读(%d/%d)" % (dark48, w * h))

    cover_path = os.path.join(OUT, "cover.png")
    if os.path.exists(cover_path):
        cv = Image.open(cover_path).convert("RGB")
        chk(cv.size == (630, 500), "cover 尺寸 %s" % (cv.size,))
        white = sum(1 for x in range(50, 500, 2) for y in range(80, 230, 2)
                    if near(cv.getpixel((x, y)), "#ffffff", 14))
        chk(white > 500, "cover 标题白字(%d 采样)" % white)
        amber = sum(1 for x in range(50, 450) for y in range(155, 170)
                    if near(cv.getpixel((x, y)), "#ffa04a", 30))
        chk(amber > 100, "cover 琥珀横线(%dpx)" % amber)
        dark_cv = sum(1 for x in range(350, 600, 2) for y in range(160, 400, 2)
                      if sum(cv.getpixel((x, y))) < 210)
        chk(dark_cv > 2000, "cover 机甲主体(%d 采样)" % dark_cv)
        chk(near(cv.getpixel((315, 480)), "#3a382f"), "cover 地面底色")

    sp = Image.open(os.path.join(render_dir, "boot_splash.png")).convert("RGB")
    chk(sp.size == (2400, 1080), "splash 尺寸 %s" % (sp.size,))
    chk(near(sp.getpixel((1200, 60)), "#b3a97f", 20), "splash 天空(顶)" )
    chk(near(sp.getpixel((1240, 928)), "#4d4a40"), "splash 地表带")
    # 无主体（用户定稿）：y 60..600 天空区不应有任何机甲/BOSS 级暗块（塔楼顶 610 起）
    dark_sky = sum(1 for x in range(0, 2400, 3) for y in range(60, 600, 3)
                   if sum(sp.getpixel((x, y))) < 210)
    chk(dark_sky < 60, "splash 纯背景无主体(天空区暗像素采样 %d)" % dark_sky)
    # 远景联排接缝：天区相邻列均差
    for sx in (1023, 2047):
        d = [sum(abs(sp.getpixel((sx, y))[i] - sp.getpixel((sx + 1, y))[i]) for i in range(3)) for y in range(80, 400)]
        chk(sum(d) / len(d) < 6, "splash 远景接缝 x=%d (均差 %.1f)" % (sx, sum(d) / len(d)))

    # showcase：深底，splash 缩略 + 图标三档（深/浅双底）
    th = sp.resize((1600, 720), Image.LANCZOS)
    H = 720 + 40 + 300 + 20
    canvas = Image.new("RGB", (1960, H), (24, 24, 24))
    canvas.paste(th, (0, 0))
    for i, (name, sz) in enumerate((("512", 256), ("128", 128), ("48", 48))):
        ic = Image.open(os.path.join(render_dir, "icon_512.png")).convert("RGBA").resize((sz, sz), Image.LANCZOS)
        x = 40 + i * (sz + 60) + (256 - sz)
        canvas.paste(ic, (x, 760), ic)
    light = Image.new("RGBA", (200, 128), (235, 232, 224, 255))
    canvas.paste(light, (1180, 764))
    ic128 = Image.open(os.path.join(render_dir, "icon_512.png")).convert("RGBA").resize((128, 128), Image.LANCZOS)
    ic48 = ic128.resize((48, 48), Image.LANCZOS)
    canvas.paste(ic128, (1200, 772), ic128)
    canvas.paste(ic48, (1330, 812), ic48)
    cover_path = os.path.join(OUT, "cover.png")
    if os.path.exists(cover_path):
        cv = Image.open(cover_path).convert("RGBA").resize((300, 238), Image.LANCZOS)
        canvas.paste(cv, (1620, 770), cv)
    canvas.save(os.path.join(OUT, "showcase.png"))
    print("showcase ->", os.path.join(OUT, "showcase.png"))
    print("RESULT:", "ALL PASS" if ok else "HAS FAILURES")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "validate":
        main_validate(sys.argv[2] if len(sys.argv) > 2 else None)
    elif len(sys.argv) > 1 and sys.argv[1] == "stamp":
        stamp_cover(sys.argv[2] if len(sys.argv) > 2 else os.path.join(OUT, "render"))
    else:
        main_build()
