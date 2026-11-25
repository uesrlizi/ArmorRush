# -*- coding: utf-8 -*-
"""Armor Rush 视频封面/海报多比例出图（拼装现役件；v2 构图=第八章「镜盐之原」黄昏疾行）。

成套交付（根目录 PNG 成品）：
  cover_16x9.png   2560x1440  视频封面（B站/YouTube）
  cover_20x9.png   2400x1080  宽幅 banner（=窗口比例）
  cover_9x16.png   1080x1920  竖屏短视频封面
  poster_4x3.png   2048x1536  横版海报
  poster_3x4.png   1440x1920  竖版海报
  square_1x1.png   1440×1440  方图

v2 构图（2026-11-13 用户否决 v1 开火打直升机后重设计）：
  场景换到第八章镜盐之原——远层=env_salt_far（黄昏杏金天+盐原山脉+晶塔），
  地标=env_salt_harvester（搁浅采盐联合机独层，左景沉盐），中景=env_salt_mid
  （泵站/盐山/晾盐架小件），地表=盐壳带 env_salt_ground_top + 盐滩延续到画布底，
  机甲前倾 6° 沿盐滩疾行（拼装静止账不变，倾角=组装级变换），脚下压扁镜面倒影
  +镜洼光斑。**无任何战斗特效**（枪口焰/曳光/推进焰/BOSS/雨全删——自绘特效与
  引擎渲染不一致，用户否决）。动势只靠姿态与环境。
标题=stamp 盖印（白 ARMOR RUSH+暗影 / 琥珀横线 / 装甲疾驰，Bahnschrift+SimHei）。
用法:
  python build_covers.py build             # covers/<名>.svg
  python build_covers.py raster            # Godot headless 光栅 -> covers/render/<名>_1x.png
  python build_covers.py stamp             # PIL 盖标题 -> 根目录 6 张成品
  python build_covers.py validate [render_dir]  # PIL 断言 + showcase_covers.png
"""
import os, sys, math, random

OUT = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, OUT)
from build_branding import inner, rename_ids  # noqa: E402

RENDER = os.path.join(OUT, "covers", "render")
GODOT = r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"

# ---------- 玩家机甲拼装账（Visuals 局部系，画布中心=机体锚点；正本=player.tscn/split_player_legs.py） ----------
MECH_SCALE = 0.5833333
MECH_PARTS = [
    ("common/player_mech_user_nozzle.svg",          16, (-15.6944, -12.4508)),
    ("common/player_mech_user_leg_far_foot.svg",    54, (6.5, 0)),
    ("common/player_mech_user_leg_far_thigh.svg",   54, (6.5, 0)),
    ("common/player_mech_user_leg_far_shin.svg",    54, (6.5, 0)),
    ("common/player_mech_user_leg_near_foot.svg",   54, (6.5, 0)),
    ("common/player_mech_user_leg_near_thigh.svg",  54, (6.5, 0)),
    ("common/player_mech_user_leg_near_shin.svg",   54, (6.5, 0)),
    ("common/player_mech_user_body.svg",            54, (6.1795, 0)),
    ("common/player_mech_user_arm.svg",             80, (-5.7505, -24.38)),
]
SOLE_Y = 30.27
MECH_TOP = -30.1
MECH_L, MECH_R = -25.3, 34.35
CONTENT_CX = 4.5

# ---- 疾行姿（腿骨件绕关节轴点的组装级旋转，不改件；轴点=split_player_legs.py 关节画布账）----
M = MECH_SCALE
HIP_DY = -3.0   # 轴点整体上移 3：旋转时骨件顶端钉在骨盆覆盖带内不露缝，下端摆出步幅
PIV_HIP_FAR    = ((37.5 - 54) * M, (57.5 - 54) * M + HIP_DY)
PIV_KNEE_FAR   = ((41.0 - 54) * M, (77.5 - 54) * M + HIP_DY)
PIV_ANKLE_FAR  = ((34.2 - 54) * M, (98.5 - 54) * M + HIP_DY)
PIV_HIP_NEAR   = ((46.56 - 54) * M, (57.5 - 54) * M + HIP_DY)
PIV_KNEE_NEAR  = ((50.06 - 54) * M, (77.5 - 54) * M + HIP_DY)
PIV_ANKLE_NEAR = ((43.26 - 54) * M, (98.5 - 54) * M + HIP_DY)
# 疾行姿：正向运动学嵌套（小腿组嵌进大腿旋转组、脚组嵌进小腿组），
# 角度一律写相对角（deg，+ = 顺时针 = 向后摆），绝对角由嵌套自动级联。
# 写绝对角绕静止位轴点=骨链脱臼（膝已被大腿搬走，脚踝戳出实心楔穿地）。
LEG_POSE = {
    "far":  dict(thigh=13, shin=12, foot=-2),    # 远腿后蹬抬跟
    "near": dict(thigh=-16, shin=11, foot=-3),   # 近腿前跨落跟
}
POSE_SOLE_Y = 30.4    # 疾行姿触地足(近足)足底的局部 y（prepare 用它落锚=踩线）

def mech_world(cfg, lx, ly):
    """局部点 -> 封面像素（含整机前倾 tilt）。"""
    a = math.radians(cfg["tilt"])
    x, y = lx * cfg["S"], ly * cfg["S"]
    return (cfg["ax"] + x * math.cos(a) - y * math.sin(a),
            cfg["ay"] + x * math.sin(a) + y * math.cos(a))

def _part_g(src, c, px, py):
    return ('<g transform="translate(%.4f,%.4f) scale(%.7f) translate(-%d,-%d)">%s</g>'
            % (px, py, MECH_SCALE, c, c, rename_ids(inner(src), src.split("/")[-1][:-4])))

def _rot(piv, deg, inner):
    return ('<g transform="translate(%.4f,%.4f) rotate(%.3f) translate(%.4f,%.4f)">%s</g>'
            % (piv[0], piv[1], deg, -piv[0], -piv[1], inner))

def _leg_chain(side):
    """一条腿的 FK 链：大腿(髋)→小腿(膝相对角)→脚(踝相对角)，嵌套级联=关节自动衔接。"""
    pose = LEG_POSE[side]
    pt = "common/player_mech_user_leg_%s_%%s.svg" % side
    pivs = {"far": (PIV_HIP_FAR, PIV_KNEE_FAR, PIV_ANKLE_FAR),
            "near": (PIV_HIP_NEAR, PIV_KNEE_NEAR, PIV_ANKLE_NEAR)}[side]
    foot = _part_g(pt % "foot", 54, 6.5, 0)
    shin = _rot(pivs[1], pose["shin"], _part_g(pt % "shin", 54, 6.5, 0) + foot)
    return _rot(pivs[0], pose["thigh"], _part_g(pt % "thigh", 54, 6.5, 0) + shin)

def mech_parts_inner():
    """9 件拼装内文（z 序=player.tscn：喷口最底、腿、躯干、臂最顶）。
    腿=两条 FK 链（骨件旋转=组装级变换，不改件），摆出疾行跨步。"""
    parts = [_part_g("common/player_mech_user_nozzle.svg", 16, -15.6944, -12.4508),
             _leg_chain("far"), _leg_chain("near"),
             _part_g("common/player_mech_user_body.svg", 54, 6.1795, 0),
             _part_g("common/player_mech_user_arm.svg", 80, -5.7505, -24.38)]
    return "\n".join(parts)

def mech_group(cfg, extra_tf=""):
    """整机 <g>：translate(ax,ay) rotate(tilt) scale(S)。extra_tf=外层附加（倒影用）。"""
    s = cfg["S"]
    return ('<g %stransform="translate(%.2f,%.2f) rotate(%.2f) scale(%.4f)">\n%s\n</g>'
            % (extra_tf, cfg["ax"], cfg["ay"], cfg["tilt"], s, mech_parts_inner()))

# ---------- 比例配置 ----------
# G=盐滩行走线（机甲足底/地平线）；far_k 锚定 env_salt_far 画布1234线（=游戏地形顶）到 G；
# hv_* =采盐联合机（3200x900 画布，机身 x1235..1965、轮底 862）；flat=盐滩延续区。
RATIOS = {
    "cover_16x9": dict(W=2560, H=1440, G=1120, far_k=1.10, mid_k=0.95, gtop_k=1.0,
                       S=12.0, tilt=3, cx=1830,
                       hv=dict(k=0.75, cx=690), pools=7,
                       title=dict(mode="left", x=154, y=170, latin=200), seed=16),
    "cover_20x9": dict(W=2400, H=1080, G=840, far_k=0.80, mid_k=0.85, gtop_k=0.75,
                       S=9.6, tilt=3, cx=1700,
                       hv=dict(k=0.56, cx=560), pools=5,
                       title=dict(mode="left", x=156, y=130, latin=185), seed=20),
    "cover_9x16": dict(W=1080, H=1920, G=1580, far_k=1.60, mid_k=0.62, gtop_k=1.35,
                       S=12.0, tilt=3, cx=600,
                       hv=dict(k=0.85, cx=340), pools=5,
                       title=dict(mode="center", y=163, latin=145), seed=91),
    "poster_4x3": dict(W=2048, H=1536, G=1200, far_k=1.10, mid_k=0.90, gtop_k=1.05,
                       S=12.0, tilt=3, cx=1500,
                       hv=dict(k=0.70, cx=640), pools=6,
                       title=dict(mode="left", x=154, y=150, latin=168), seed=43),
    "poster_3x4": dict(W=1440, H=1920, G=1560, far_k=1.45, mid_k=0.75, gtop_k=1.35,
                       S=14.5, tilt=3, cx=720,
                       hv=dict(k=0.70, cx=380), pools=5,
                       title=dict(mode="center", y=163, latin=190), seed=34),
    "square_1x1": dict(W=1440, H=1440, G=1150, far_k=1.42, mid_k=0.75, gtop_k=1.0,
                       S=10.5, tilt=3, cx=770,
                       hv=dict(k=0.60, cx=330), pools=5,
                       title=dict(mode="left", x=130, y=110, latin=160), seed=11),
}

def prepare(cfg):
    """机甲锚点：ax 由内容中心 cx 反推；ay 由疾行姿触地足底=G 反推。"""
    cfg["ax"] = cfg["cx"] - CONTENT_CX * cfg["S"]
    cfg["ay"] = cfg["G"] - POSE_SOLE_Y * cfg["S"]
    return cfg

def pools_svg(cfg, rng):
    """镜洼光斑：压扁光纹条语言（ry≤6），霞粉/青绿两族，撒在盐滩区。"""
    W, H, G = cfg["W"], cfg["H"], cfg["G"]
    gk = cfg["gtop_k"]
    top = G + 56 * gk + 10
    out = ["<!-- 镜洼光斑（压扁光纹条语言，霞粉/青绿） -->"]
    for _ in range(cfg["pools"]):
        w = rng.uniform(0.07, 0.14) * W
        h = rng.uniform(4, 9)
        x = rng.uniform(0.03 * W, W - w - 0.03 * W)
        y = rng.uniform(top, H - h - 14)
        pink = rng.random() < 0.5
        base = "#f0b096" if pink else "#a8d0c0"
        out.append('<rect x="%.0f" y="%.1f" width="%.0f" height="%.1f" rx="%.1f" fill="%s" opacity="%.2f"/>'
                   % (x, y, w, h, h / 2, base, rng.uniform(0.34, 0.5)))
        out.append('<rect x="%.0f" y="%.1f" width="%.0f" height="%.1f" rx="%.1f" fill="#ffffff" opacity="%.2f"/>'
                   % (x + w * 0.12, y + h * 0.25, w * 0.55, h * 0.3, h * 0.15, rng.uniform(0.2, 0.32)))
    return "\n".join(out)

def build_scene(name):
    cfg = prepare(RATIOS[name])
    W, H, G = cfg["W"], cfg["H"], cfg["G"]
    rng = random.Random(cfg["seed"])

    # 远层：env_salt_far 1024x1300，画布 1234=游戏地形顶 -> 锚到 G。
    # 联步进取整并回算缩放（1024k 非整数会留 0.6px 透明缝=黑竖线 artifact）
    far_step = max(1, round(1024 * cfg["far_k"]))
    fk = far_step / 1024
    far_ty = G - 1234 * fk
    far = "\n".join('<!-- env_salt_far 第%d联（黄昏天+盐原山脉+晶塔） -->\n<g transform="translate(%d,%d) scale(%.5f)">%s</g>'
                    % (i + 1, i * far_step, round(far_ty), fk,
                       rename_ids(inner("world_8/env_salt_far.svg"), "f%d" % (i + 1)))
                    for i in range(math.ceil(W / far_step)))

    # 地标：搁浅采盐联合机 3200x900（机身 1235..1965，轮底 862），底沉盐 18px
    hv = cfg["hv"]
    hv_ty = G + 18 - 862 * hv["k"]
    harvester = ('<!-- 搁浅采盐联合机（第八章独层地标，沉盐读法） -->\n'
                 '<g transform="translate(%d,%d) scale(%.4f)">%s</g>'
                 % (round(hv["cx"] - 1600 * hv["k"]), round(hv_ty), hv["k"],
                    rename_ids(inner("world_8/env_salt_harvester.svg"), "hv")))

    # 中景：env_salt_mid 2048x520 透明底，落地脚线画布 496 -> G+18（联步进取整同上）
    mid_step = max(1, round(2048 * cfg["mid_k"]))
    mk = mid_step / 2048
    mid_ty = G + 18 - 496 * mk
    mid = "\n".join('<g transform="translate(%d,%d) scale(%.5f)">%s</g>'
                    % (i * mid_step, round(mid_ty), mk,
                       rename_ids(inner("world_8/env_salt_mid.svg"), "m%d" % (i + 1)))
                    for i in range(math.ceil(W / mid_step)))

    # 地表带 + 盐滩延续区（盐壳带贴图 + 暖渐变平滩到画布底）
    gstep = max(1, round(640 * cfg["gtop_k"]))
    gk = gstep / 640
    band_h = 66 * gk
    gtop = "\n".join('<g transform="translate(%d,%d) scale(%.5f)">%s</g>'
                     % (i * gstep, round(G), gk, inner("world_8/env_salt_ground_top.svg"))
                     for i in range(math.ceil(W / gstep)))
    flat_top = G + band_h

    # 黄昏霞气（游戏 AerialFog 语言+地平线绯粉霞带）：雾底边由地表带剪出，不几何对齐
    fog = ('<radialGradient id="haze_g" cx="0.5" cy="1" r="0.9">'
           '<stop offset="0" stop-color="#eda488" stop-opacity="0.42"/>'
           '<stop offset="0.7" stop-color="#eda488" stop-opacity="0.20"/>'
           '<stop offset="1" stop-color="#eda488" stop-opacity="0"/></radialGradient>'
           '<rect x="0" y="%.1f" width="%d" height="%.1f" fill="url(#haze_g)"/>'
           '<linearGradient id="glow_g" x1="0" y1="0" x2="0" y2="1">'
           '<stop offset="0" stop-color="#f29080" stop-opacity="0"/>'
           '<stop offset="0.65" stop-color="#f29080" stop-opacity="0.30"/>'
           '<stop offset="1" stop-color="#f29080" stop-opacity="0.42"/></linearGradient>'
           '<rect x="0" y="%.1f" width="%d" height="%.1f" fill="url(#glow_g)"/>'
           % (G - 300, W, 330, G - 170, W, 176))

    # 机甲 + 压扁镜面倒影（倒影=整机全变换对 G 镜像后纵向压 0.35，叠在盐滩上）
    K = 0.35
    mech = mech_group(cfg)
    reflection = ('<!-- 镜面倒影：整机全变换对 G 镜像纵向压 %.2f，叠盐滩 -->\n'
                  '<g transform="translate(0,%.2f) scale(1,-%.3f)" opacity="0.22">\n%s\n</g>'
                  % (K, G * (1 + K), K, mech_group(cfg)))

    svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
<!-- Armor Rush {name} {W}x{H}（v2 构图：第八章「镜盐之原」黄昏疾行）。
     层账：far x{fk}（画布1234线锚 G={G}，ty={far_ty:.0f}）→ 采盐联合机（k={hv["k"]}，底沉盐18）
     → mid x{mk}（脚线 G+18）→ 蜃气带 → 盐壳带 y={G}..{flat_top:.0f} + 盐滩渐变到画布底
     → 机甲倒影（压0.35/op0.15）→ 镜洼光斑 → 机甲（前倾{cfg["tilt"]}°，S={cfg["S"]}）。
     无战斗特效（v1 否决项）；标题区留白给 stamp 盖印（{cfg["title"]["mode"]}）。 -->
{far}
{harvester}
{mid}
{fog}
<rect x="0" y="{flat_top:.1f}" width="{W}" height="{H - flat_top:.1f}" fill="url(#flat_g)"/>
<linearGradient id="flat_g" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#b3a282"/>
  <stop offset="1" stop-color="#7c6e58"/>
</linearGradient>
{gtop}
{reflection}
{pools_svg(cfg, rng)}
{mech}
</svg>
'''
    return svg

# ---------- Godot 光栅 ----------
def cmd_raster():
    import subprocess
    os.makedirs(RENDER, exist_ok=True)
    for name in RATIOS:
        svg = os.path.join(OUT, "covers", name + ".svg")
        png = os.path.join(RENDER, name + "_1x.png")
        print(">>", name)
        r = subprocess.run([GODOT, "--headless", "--path", ROOT,
                            "--script", "res://art_proposals/raster_svg.gd",
                            "--", svg, png, "1.0"],
                           capture_output=True, text=True, timeout=120)
        tail = (r.stdout or "").strip().splitlines()[-2:] + (r.stderr or "").strip().splitlines()[-3:]
        assert r.returncode == 0 and os.path.exists(png), "raster fail %s:\n%s" % (name, "\n".join(tail))
        print("   ", tail[0] if tail else "ok")

# ---------- 标题盖印（PIL 系统字体；ThorVG 渲不了文字） ----------
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

def stamp_all():
    from PIL import Image, ImageDraw
    AMBER, WHITE, SHADOW = "#ffa04a", "#ffffff", "#29261e"
    for name, cfg in RATIOS.items():
        img = Image.open(os.path.join(RENDER, name + "_1x.png")).convert("RGB")
        d = ImageDraw.Draw(img)
        W = cfg["W"]
        t = cfg["title"]
        latin, cjk, size_cjk = _load_fonts(t["latin"])
        trk = int(t["latin"] * 0.05)
        sh = max(4, int(t["latin"] * 0.045))

        def draw_tracked(xy, text, font, trk_, fill, shadow):
            x, y = xy
            for ch in text:
                if shadow:
                    d.text((x + sh, y + sh), ch, font=font, fill=SHADOW)
                d.text((x, y), ch, font=font, fill=fill)
                x += d.textlength(ch, font=font) + trk_
            return x - trk_

        def text_w(text, font, trk_):
            return sum(d.textlength(ch, font=font) for ch in text) + trk_ * (len(text) - 1)

        latin_text, cjk_text = "ARMOR RUSH", "装甲疾驰"
        lw = text_w(latin_text, latin, trk)
        x0 = t["x"] if t["mode"] == "left" else (W - lw) / 2
        y0 = t["y"]
        draw_tracked((x0, y0), latin_text, latin, trk, WHITE, True)
        line_h = max(10, int(t["latin"] * 0.055))
        ly = y0 + int(t["latin"] * 1.16)
        pad = int(t["latin"] * 0.04)   # 横线只略出字尾
        d.rectangle([x0 + sh, ly + sh, x0 + lw + pad + sh, ly + line_h + sh], fill=SHADOW)
        d.rectangle([x0, ly, x0 + lw + pad, ly + line_h], fill=AMBER)
        cy = ly + line_h + int(t["latin"] * 0.30)
        ctrk = int(size_cjk * 0.13)
        cw = text_w(cjk_text, cjk, ctrk)
        cx0 = x0 if t["mode"] == "left" else (W - cw) / 2
        draw_tracked((cx0, cy), cjk_text, cjk, ctrk, WHITE, True)
        out = os.path.join(OUT, name + ".png")
        img.save(out)
        print("stamped ->", out)

# ---------- PIL 断言 + showcase ----------
def validate(render_dir=None):
    from PIL import Image
    ok = True
    def chk(cond, msg):
        nonlocal ok
        print(("PASS " if cond else "FAIL ") + msg)
        ok = ok and cond
    def near(c, hexs, tol=16):
        t = tuple(int(hexs[i:i + 2], 16) for i in (1, 3, 5))
        return all(abs(a - b) <= tol for a, b in zip(c[:3], t))

    for name, cfg0 in RATIOS.items():
        cfg = prepare(dict(cfg0))
        p = os.path.join(OUT, name + ".png")
        if not os.path.exists(p):
            chk(False, name + " 成品缺失")
            continue
        im = Image.open(p).convert("RGB")
        W, H, G = cfg["W"], cfg["H"], cfg["G"]
        chk(im.size == (W, H), "%s 尺寸 %s" % (name, im.size))
        # 标题白字
        t = cfg["title"]
        _, _, size_cjk = _load_fonts(t["latin"])
        blk_bot = t["y"] + int(t["latin"] * 2.1)
        white = sum(1 for x in range(0, W, 3) for y in range(t["y"], min(blk_bot, H), 3)
                    if near(im.getpixel((x, y)), "#ffffff", 26))
        chk(white > 260, "%s 标题白字(%d 采样)" % (name, white))
        amber = sum(1 for x in range(0, W, 2) for y in range(t["y"] + int(t["latin"] * 1.0),
                                                             t["y"] + int(t["latin"] * 1.35))
                    if near(im.getpixel((x, y)), "#ffa04a", 36))
        chk(amber > 60, "%s 琥珀横线(%dpx)" % (name, amber))
        # 机甲暗部剪影（ThorVG 静默透明的兜底报警）
        mx0, my0 = mech_world(cfg, MECH_L, MECH_TOP)
        mx1, my1 = mech_world(cfg, MECH_R, SOLE_Y)
        mx0, mx1 = int(max(0, mx0)), int(min(W, mx1))
        my0, my1 = int(max(0, my0)), int(min(H, my1))
        dark = sum(1 for x in range(mx0, mx1, 3) for y in range(my0, my1, 3)
                   if sum(im.getpixel((x, y))) < 210)
        chk(dark > (mx1 - mx0) * (my1 - my0) / 9 * 0.10, "%s 机甲剪影(%d/%d)" % (name, dark, (mx1 - mx0) * (my1 - my0) / 9))
        # 地标暗部（采盐联合机应可读）
        hv = cfg["hv"]
        hx = hv["cx"]
        hdark = sum(1 for x in range(max(0, int(hx - 360 * hv["k"])), min(W, int(hx + 360 * hv["k"])), 3)
                    for y in range(max(0, int(G - 500 * hv["k"])), min(H, int(G + 20)), 3)
                    if sum(im.getpixel((x, y))) < 400)
        chk(hdark > 300, "%s 采盐机地标(%d 采样)" % (name, hdark))
        # 盐滩渐变底色 + 地表带
        chk(near(im.getpixel((W // 2, H - 4)), "#7c6e58", 22), "%s 盐滩底色" % name)
        band_c = im.getpixel((W // 2, min(H - 1, int(G + 66 * cfg["gtop_k"] / 2))))
        chk(300 < sum(band_c) < 660, "%s 盐壳带中值(%s)" % (name, band_c))
        # 远景联排接缝（同贴图相邻列均差；步进=build_scene 的整数字）
        far_step = max(1, round(1024 * cfg["far_k"]))
        for sx in (far_step, far_step * 2):
            if sx >= W - 2:
                continue
            d_ = [sum(abs(im.getpixel((sx, y))[i] - im.getpixel((sx + 1, y))[i]) for i in range(3))
                  for y in range(40, min(G - 20, H - 1), 7)]
            chk(sum(d_) / max(1, len(d_)) < 9, "%s 远景接缝 x=%d (均差 %.1f)" % (name, sx, sum(d_) / max(1, len(d_))))
        # 倒影存在：机甲正下方带区应比同行右侧空白带区暗
        rbox = (max(0, int(cfg["ax"] - 8 * cfg["S"])), G + 90, int(cfg["ax"] + 20 * cfg["S"]), min(H, G + 210))
        ref_mean = n_ref = 0
        for x in range(rbox[0], rbox[2], 3):
            for y in range(rbox[1], rbox[3], 3):
                ref_mean += sum(im.getpixel((x, y)))
                n_ref += 1
        ref_mean /= max(1, n_ref)
        sx0 = min(W - 60, rbox[2] + 120)
        adj_mean = n_adj = 0
        for x in range(sx0, min(W, sx0 + 240), 3):
            for y in range(rbox[1], rbox[3], 3):
                adj_mean += sum(im.getpixel((x, y)))
                n_adj += 1
        adj_mean /= max(1, n_adj)
        chk(ref_mean < adj_mean - 12, "%s 镜面倒影(机甲下 %.0f vs 右侧 %.0f)" % (name, ref_mean, adj_mean))

    # showcase：2 列 3 行拼图（深底）
    th_w = 760
    cells = []
    for name in ("cover_16x9", "cover_20x9", "poster_4x3", "poster_3x4", "square_1x1", "cover_9x16"):
        im = Image.open(os.path.join(OUT, name + ".png")).convert("RGB")
        th = im.resize((th_w, round(im.height * th_w / im.width)), Image.LANCZOS)
        cells.append((name, th))
    col_h1 = cells[0][1].height + cells[2][1].height + cells[4][1].height + 40
    col_h2 = cells[1][1].height + cells[3][1].height + cells[5][1].height + 40
    Hc = max(col_h1, col_h2) + 20
    canvas = Image.new("RGB", (th_w * 2 + 60, Hc), (24, 24, 24))
    y1 = y2 = 20
    for i, (name, th) in enumerate(cells):
        x = 20 if i % 2 == 0 else th_w + 40
        y = (y1, y2)[i % 2]
        canvas.paste(th, (x, y))
        if i % 2 == 0:
            y1 += th.height + 20
        else:
            y2 += th.height + 20
    canvas.save(os.path.join(OUT, "showcase_covers.png"))
    print("showcase ->", os.path.join(OUT, "showcase_covers.png"))
    print("RESULT:", "ALL PASS" if ok else "HAS FAILURES")

if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "build"
    if arg == "build":
        os.makedirs(os.path.join(OUT, "covers"), exist_ok=True)
        for name in RATIOS:
            p = os.path.join(OUT, "covers", name + ".svg")
            with open(p, "w", encoding="utf-8", newline="\n") as f:
                f.write(build_scene(name))
            print("wrote", p)
    elif arg == "raster":
        cmd_raster()
    elif arg == "stamp":
        stamp_all()
    elif arg == "validate":
        validate()
