# -*- coding: utf-8 -*-
"""拆地块 v2 公共绘制模块：场景提案预览图与实机烘焙共用的分层语言。

分层（自上而下，包角已按用户意见移除）：
  1 顶缘亮线  2 走道带（每块独立取花）  3 带底转折  4 立面 AO 渐隐
  5 立面层理（渐疏渐淡）+ 章材质剖面细节  6 深层渐变  7 块间缝（上密下疏）
  8 掉档=墙面全露+墙脚件；升档=接触阴影 36px 渐隐（无亮线包角）

画布约定：canvas = 世界÷2（提案预览 1200×540）；k=放大倍数（解剖图 k=2，
实机烘焙世界比例=k=2 的几何）。坐标原点左上，y 向下。

实机档位（balance.gd）：块宽 320、档差 64、三档顶面 536/600/664、同高 2~4 块。
提案预览档位序列 SEQ 两侧固定最低档——老场景两侧道具不用搬家，高低差留在
中段（正是 gameplay 视野）。
"""
import math
import random

CHUNK = 160.0                          # 画布半比例块宽（世界 320）
TIER_Y = {0: 332.0, 1: 300.0, 2: 268.0}  # 档位顶面（世界 664/600/536）
BAND = 28.0                            # 表面带高（世界 56）
# 两侧 t0 平地（老道具原位不动）+ 中段 t2 高台 + t1 过渡；段长 2/3/2/3 合规(2~4)
SEQ = [0, 0, 2, 2, 2, 1, 1, 0, 0, 0]
X_OFF = -100.0


def f(v):
    s = f"{v:.1f}"
    s = s.rstrip("0").rstrip(".")
    return s if s else "0"


def pts(seq):
    return " ".join(f"{f(x)},{f(y)}" for x, y in seq)


# ---- 渐变适配：兼容 generate_proposals.Svg（vgrad(gid, stops)/_lgrad）
# 与本目录最小 Svg（vgrad(stops)/hgrad）两套签名 ----
_GC = [0]


def _gid(s):
    _GC[0] += 1
    return f"gv{_GC[0]}"


def _vgrad(s, stops):
    try:
        return s.vgrad(stops)
    except TypeError:
        return s.vgrad(_gid(s), stops)


def _hgrad(s, stops, x2=1.0, y2=0.0):
    try:
        return s.hgrad(stops, x2, y2)
    except (TypeError, AttributeError):
        return s._lgrad(_gid(s), stops, x2, y2)


# ============================================================
# 七章主题（canvas 半比例色账；实机烘焙同色，几何 ×2）
# ============================================================
THEMES = {
    # 一 锈雨废都：沥青走道带 + 土层断面 + 露头钢筋 + 墙脚瓦砾
    "ch1_rust": {
        "style": "rust",
        "top_line": "#7a7462", "band": "#4a473e", "band_edge": "#332f28",
        "band_dark": "#2e2c26", "band_light": "#5d594e", "ao": "#26241c",
        "face_hi": "#46433a", "face_lo": "#2b2921", "strata": "#242218",
        "seam": "#1f1d16", "detail": "#6a5a48", "foot": "#33302a",
        "accent": "#ffa04a",
    },
    # 二 精炼所工业带：钢板混凝土走道带（板缝/铆钉/警示黄）+ 深绿灰断面
    "ch2_ref": {
        "style": "ref",
        "top_line": "#59645a", "band": "#39453f", "band_edge": "#26302a",
        "band_dark": "#222b26", "band_light": "#46554c", "ao": "#1d2622",
        "face_hi": "#333e38", "face_lo": "#1d2420", "strata": "#1a221d",
        "seam": "#161d18", "detail": "#4d5a50", "foot": "#2a332d",
        "accent": "#d8a021",
    },
    # 三 雪原警戒点：深色路板搁在亮雪断面上（雪檐受光/车辙/黄虚线/雪斑）
    "ch3_snow": {
        "style": "snow",
        "top_line": "#f7fafb", "band": "#56626c", "band_edge": "#333d45",
        "band_dark": "#39434c", "band_light": "#e8eff3", "ao": "#5f6f7a",
        "face_hi": "#dfe7ec", "face_lo": "#b3c5d1", "strata": "#9fb3bf",
        "seam": "#93a7b4", "detail": "#8fa5b3", "foot": "#f7fafb",
        "accent": "#c9b23c",
    },
    # 四 珊瑚辐合夜：暗玄武岩走道带 + 珊瑚辉光裂纹（暗场章，断面近黑）
    "ch4_coral": {
        "style": "coral",
        "top_line": "#4a5890", "band": "#171d33", "band_edge": "#0d1226",
        "band_dark": "#0b0f20", "band_light": "#232c4a", "ao": "#0a0e1e",
        "face_hi": "#12172a", "face_lo": "#0a0d1c", "strata": "#1a2138",
        "seam": "#070a16", "detail": "#ff6a3d", "foot": "#10152a",
        "accent": "#ff7a45",
    },
    # 五 破晓云廊：云上高架桥（走道带+薄箱梁+排架柱没入云海）
    "p5_cloud": {
        "style": "cloud",
        "top_line": "#c9a88e", "band": "#45415e", "band_edge": "#332f48",
        "band_dark": "#3a3550", "band_light": "#5c5674", "ao": "#2c2840",
        "face_hi": "#7a6284", "face_lo": "#453759", "strata": "#6a5478",
        "seam": "#3c3452", "detail": "#d8b89a", "foot": "#b489a4",
        "accent": "#ffc46a", "pier": "#3a3550",
    },
    # 六 赤沙矿区：赤红沙走道带（风纹/车辙/矿石）+ 沙层断面
    "p6_desert": {
        "style": "desert",
        "top_line": "#c97a52", "band": "#b0512f", "band_edge": "#8a3a24",
        "band_dark": "#8a3a24", "band_light": "#c97a52", "ao": "#7a3220",
        "face_hi": "#9a4527", "face_lo": "#62281a", "strata": "#7a321e",
        "seam": "#5a2416", "detail": "#d98c5e", "foot": "#8a4a30",
        "accent": "#ffb347",
    },
    # 七 溺海都会：跨海栈桥（走道带+薄箱梁+排架柱没入海面）
    "p7_sea": {
        "style": "sea",
        "top_line": "#a9c4b8", "band": "#5a7268", "band_edge": "#46584f",
        "band_dark": "#3c4c44", "band_light": "#8fa39a", "ao": "#37453e",
        "face_hi": "#3f4f47", "face_lo": "#22312b", "strata": "#2e3c35",
        "seam": "#1d2823", "detail": "#7a5a3c", "foot": "#d6f2e8",
        "accent": "#ff5a3c", "pier": "#37453e",
    },
    # 八 闭园夜场：沥青广场走道带（裂缝/褪色漆条/嵌灯）+ 混凝土断面（夜蓝族，暗场章）
    "p8_park": {
        "style": "park",
        "top_line": "#5a6a8c", "band": "#2e3a4e", "band_edge": "#232c3a",
        "band_dark": "#1e2632", "band_light": "#46556e", "ao": "#161d28",
        "face_hi": "#26303f", "face_lo": "#141a24", "strata": "#1d2634",
        "seam": "#10151d", "detail": "#4a5a74", "foot": "#202a38",
        "accent": "#5fe0b0",
    },
    # 九 镜盐之原：盐壳台地走道带（龟裂/盐田粉渍/结晶点）+ 盐层断面（黄昏暖调）
    "p9_salt": {
        "style": "salt",
        "top_line": "#e8d8bc", "band": "#b8a684", "band_edge": "#98876c",
        "band_dark": "#988670", "band_light": "#dccfae", "ao": "#7a6a52",
        "face_hi": "#a8967a", "face_lo": "#6e5f4a", "strata": "#8a7a62",
        "seam": "#5c4f3c", "detail": "#e8dcc0", "foot": "#d8c8a8",
        "accent": "#f2789f",
    },
    # 十 绿渊林场：湿泥苔走道带（苔斑/木屑/车辙）+ 土层根断面（阴天灰绿）
    "p10_forest": {
        "style": "forest",
        "top_line": "#7a9a6a", "band": "#46543e", "band_edge": "#35422e",
        "band_dark": "#2e3a28", "band_light": "#5e704e", "ao": "#242e1e",
        "face_hi": "#38442e", "face_lo": "#1f281a", "strata": "#2b3622",
        "seam": "#161e12", "detail": "#8a6a48", "foot": "#2e3826",
        "accent": "#b8e04a",
    },
}


# ============================================================
# 走道带花纹（每块独立取花；k=倍数）
# ============================================================
def band_detail(s, th, x0, top, bw, band, k, rng):
    st = th["style"]
    if st == "rust":
        for _ in range(rng.randint(1, 2)):  # 裂缝
            cx, cy = rng.uniform(0.1, 0.7) * bw + x0, top + rng.uniform(6, 14) * k
            seg = [(cx, cy)]
            for _s2 in range(3):
                cx += rng.uniform(4, 12) * k
                cy += rng.uniform(3, 7) * k
                seg.append((cx, min(cy, top + band - 3 * k)))
            s.path("M " + " L ".join(f"{f(a)},{f(b)}" for a, b in seg),
                   stroke=th["band_dark"], w=1.1 * k, opacity=0.85)
        if rng.random() < 0.6:  # 沥青补丁
            px = rng.uniform(0.12, 0.62) * bw + x0
            pw = rng.uniform(20, 34) * k
            s.rect(px, top + 7 * k, pw, band - 13 * k, th["band_light"], 0.4)
            s.rect(px, top + 7 * k, pw, 1.0 * k, th["band_dark"], 0.5)
        for _ in range(6):  # 碎石点
            s.rect(x0 + rng.uniform(3, bw - 6) * k, top + rng.uniform(5, band - 6),
                   2.2 * k, 1.6 * k, th["band_dark"], rng.uniform(0.35, 0.7))
    elif st == "ref":
        s.line(x0 + 2 * k, top + band * 0.55, x0 + bw - 2 * k, top + band * 0.55,
               th["band_dark"], 0.8 * k, 0.4)  # 水平板缝
        jx = rng.uniform(0.25, 0.5) * bw + x0  # 混凝土板伸缩缝
        s.line(jx, top + 3 * k, jx, top + band - 2 * k, th["band_dark"], 1.0 * k, 0.7)
        for _ in range(4):  # 铆钉点
            s.circle(x0 + rng.uniform(4, bw - 4) * k, top + rng.uniform(6, band - 6),
                     0.9 * k, th["band_light"], 0.5)
        if rng.random() < 0.4:  # 警示黄短杠
            s.rect(x0 + rng.uniform(0.2, 0.6) * bw, top + band - 8 * k,
                   10 * k, 2 * k, th["accent"], 0.5)
    elif st == "snow":
        for _ in range(2):  # 车辙
            s.line(x0, top + 12 * k, x0 + bw, top + 12 * k, th["band_dark"], 1.6 * k, 0.4)
            s.line(x0, top + 19 * k, x0 + bw, top + 19 * k, th["band_dark"], 1.6 * k, 0.4)
        dx = rng.uniform(6, 30) * k + x0  # 中线黄虚线
        while dx < x0 + bw - 26 * k:
            s.rect(dx, top + 13 * k, 13 * k, 2 * k, th["accent"], 0.5)
            dx += 26 * k
        for _ in range(rng.randint(2, 3)):  # 雪斑
            s.ellipse(x0 + rng.uniform(0.15, 0.85) * bw, top + rng.uniform(8, band - 5),
                      rng.uniform(7, 14) * k, rng.uniform(1.5, 2.6) * k,
                      th["band_light"], rng.uniform(0.55, 0.85))
    elif st == "coral":
        if rng.random() < 0.55:  # 珊瑚辉光裂纹（短划贴带，别读成垂线）
            gx = rng.uniform(0.15, 0.55) * bw + x0
            gy = top + rng.uniform(7, 12) * k
            for _s2 in range(rng.randint(2, 3)):
                ln = rng.uniform(5, 11) * k
                s.line(gx, gy, gx + ln, gy + rng.uniform(-1.5, 1.5) * k,
                       th["accent"], 2.2 * k, 0.14)
                s.line(gx, gy, gx + ln, gy + rng.uniform(-1.5, 1.5) * k,
                       th["detail"], 0.8 * k, 0.7)
                gx += ln + rng.uniform(4, 9) * k
            s.circle(gx - 3 * k, gy, 1.2 * k, th["accent"], 0.6)
        for _ in range(rng.randint(1, 2)):  # 暗岩块
            rx = rng.uniform(0.1, 0.7) * bw + x0
            s.poly([(rx, top + band - 4 * k), (rx + 8 * k, top + band - 9 * k),
                    (rx + 15 * k, top + band - 4 * k)], th["band_light"], 0.6)
    elif st == "cloud":
        dx = rng.uniform(4, 24) * k + x0  # 车道虚线（低对比）
        while dx < x0 + bw - 26 * k:
            s.rect(dx, top + band * 0.5, 13 * k, 1.5 * k, "#d8c8b8", 0.3)
            dx += 28 * k
        for _ in range(3):  # 铆接点
            s.circle(x0 + rng.uniform(4, bw - 4) * k, top + rng.uniform(5, 9) * k,
                     0.9 * k, th["band_light"], 0.55)
        if rng.random() < 0.3:  # 嵌灯
            s.circle(x0 + rng.uniform(0.2, 0.8) * bw, top + 8 * k, 1.2 * k, th["accent"], 0.75)
    elif st == "desert":
        for _ in range(4):  # 风纹
            ly = top + rng.uniform(5, band - 5)
            lx = rng.uniform(0, 0.5) * bw + x0
            s.line(lx, ly, lx + rng.uniform(20, 44) * k, ly - rng.uniform(1, 2.5) * k,
                   th["band_light"], 0.9 * k, 0.4)
        for _ in range(2):  # 车辙印
            tx = rng.uniform(0.1, 0.6) * bw + x0
            s.line(tx, top + 8 * k, tx + rng.uniform(16, 30) * k, top + 11 * k,
                   th["band_dark"], 1.4 * k, 0.4)
        if rng.random() < 0.4:  # 矿石
            rx = rng.uniform(0.2, 0.75) * bw + x0
            s.poly([(rx, top + band - 3 * k), (rx + 5 * k, top + band - 7.5 * k),
                    (rx + 10 * k, top + band - 3 * k)], th["band_dark"], 0.85)
    elif st == "sea":
        for jy in (0.32, 0.58, 0.8):  # 潮痕
            j0 = rng.uniform(0, 0.3) * bw + x0
            s.line(j0, top + band * jy, j0 + rng.uniform(30, 70) * k,
                   top + band * jy, th["band_light"], 1.1 * k, 0.45)
        jx = rng.uniform(0.3, 0.7) * bw + x0  # 伸缩缝
        s.line(jx, top + 2.5 * k, jx, top + band - 1.5 * k, th["band_dark"], 1.0 * k, 0.55)
        if rng.random() < 0.45:  # 排水格栅
            gx = rng.uniform(0.15, 0.7) * bw + x0
            for i in range(4):
                s.rect(gx + i * 4 * k, top + band - 8 * k, 2.4 * k, 5 * k,
                       th["band_dark"], 0.9)
    elif st == "park":
        for _ in range(rng.randint(1, 2)):  # 裂缝（同 rust 语法）
            cx, cy = rng.uniform(0.1, 0.7) * bw + x0, top + rng.uniform(6, 14) * k
            seg = [(cx, cy)]
            for _s2 in range(3):
                cx += rng.uniform(4, 12) * k
                cy += rng.uniform(3, 7) * k
                seg.append((cx, min(cy, top + band - 3 * k)))
            s.path("M " + " L ".join(f"{f(a)},{f(b)}" for a, b in seg),
                   stroke=th["band_dark"], w=1.1 * k, opacity=0.85)
        for i in range(2):  # 褪色漆条（薄荷=信号色 / 褪红，斑驳低透明）
            pc = th["accent"] if i == 0 or rng.random() < 0.6 else "#d86a5a"
            px = rng.uniform(0.12, 0.72) * bw + x0
            s.rect(px, top + band * 0.52 + i * 7 * k, rng.uniform(12, 20) * k, 2.2 * k,
                   pc, rng.uniform(0.3, 0.5))
        if rng.random() < 0.4:  # 地面嵌灯
            s.circle(x0 + rng.uniform(0.2, 0.8) * bw, top + 8 * k, 1.2 * k,
                     th["accent"], 0.7)
        for _ in range(4):  # 碎屑点
            s.rect(x0 + rng.uniform(3, bw - 6) * k, top + rng.uniform(5, band - 6),
                   2.0 * k, 1.5 * k, th["band_dark"], rng.uniform(0.35, 0.7))
    elif st == "salt":
        for _ in range(2):  # 盐壳龟裂（细亮纹折线）
            cx, cy = rng.uniform(0.1, 0.6) * bw + x0, top + rng.uniform(5, 10) * k
            for _s2 in range(3):
                nx = cx + rng.uniform(6, 14) * k
                ny = cy + rng.uniform(-2, 4) * k
                s.line(cx, cy, nx, min(ny, top + band - 3 * k), th["band_light"], 1.0 * k, 0.6)
                cx, cy = nx, min(ny, top + band - 3 * k)
        px = rng.uniform(0.2, 0.6) * bw + x0  # 盐田粉渍
        s.ellipse(px, top + rng.uniform(6, band - 5), rng.uniform(8, 15) * k,
                  rng.uniform(1.6, 2.6) * k, th["accent"], rng.uniform(0.28, 0.5))
        for _ in range(5):  # 结晶点
            s.rect(x0 + rng.uniform(3, bw - 6) * k, top + rng.uniform(5, band - 6),
                   1.8 * k, 1.4 * k, th["detail"], rng.uniform(0.4, 0.8))
    elif st == "forest":
        for _ in range(2):  # 苔斑
            s.ellipse(x0 + rng.uniform(0.15, 0.85) * bw, top + rng.uniform(6, band - 5),
                      rng.uniform(8, 15) * k, rng.uniform(1.6, 2.8) * k,
                      th["band_light"], rng.uniform(0.4, 0.7))
        dx = rng.uniform(0.1, 0.5) * bw + x0  # 木屑横屑（萤黄绿低透明）
        for i in range(4):
            s.line(dx + i * 6 * k, top + band * 0.72,
                   dx + i * 6 * k + rng.uniform(3, 8) * k, top + band * 0.72,
                   th["accent"], 1.2 * k, 0.3)
        tx = rng.uniform(0.15, 0.6) * bw + x0  # 运材车辙
        s.line(tx, top + 9 * k, tx + rng.uniform(18, 34) * k, top + 11 * k,
               th["band_dark"], 1.5 * k, 0.45)


# ============================================================
# 立面剖面细节（锈=钢筋 / 雪=冰脉 / 珊瑚=辉光脉 / 其余按章变化）
# ============================================================
def face_detail(s, th, x0, top, bw, band, k, rng):
    st = th["style"]
    fy = top + band
    if st in ("rust", "ref", "sea", "park", "forest"):
        ry = fy + rng.uniform(9, 16) * k  # 露头钢筋/管线（park=拆散电缆 forest=断根，同语法）
        for rx in (rng.uniform(0.2, 0.42), rng.uniform(0.58, 0.8)):
            px = x0 + rx * bw
            s.line(px, ry, px + 9 * k, ry, th["detail"], 1.4 * k, 0.85)
            if st == "rust":
                s.circle(px + 11 * k, ry, 1.1 * k, "#8a5a3a", 0.9)
            elif st == "forest":
                s.line(px + 4 * k, ry, px + 8 * k, ry + rng.uniform(4, 8) * k,
                       th["detail"], 1.0 * k, 0.7)
    elif st == "snow":
        for _ in range(2):  # 冰脉
            px = x0 + rng.uniform(0.25, 0.75) * bw
            s.line(px, fy + 5 * k, px + rng.uniform(-4, 4) * k, fy + 26 * k,
                   th["detail"], 1.1 * k, 0.8)
    elif st == "coral":
        if rng.random() < 0.5:  # 珊瑚辉光脉（断面短竖纹，收敛）
            px = x0 + rng.uniform(0.3, 0.7) * bw
            s.line(px, fy + 5 * k, px + rng.uniform(-2, 2) * k, fy + 16 * k,
                   th["detail"], 1.6 * k, 0.16)
            s.line(px, fy + 5 * k, px + rng.uniform(-2, 2) * k, fy + 16 * k,
                   th["detail"], 0.7 * k, 0.65)
            s.circle(px, fy + 18 * k, 1.1 * k, th["accent"], 0.55)
    elif st == "cloud":
        ry = fy + rng.uniform(8, 14) * k  # 桁架端头
        px = x0 + rng.uniform(0.2, 0.7) * bw
        s.line(px, ry, px + 10 * k, ry, th["detail"], 1.3 * k, 0.7)
    elif st == "desert":
        px = x0 + rng.uniform(0.2, 0.7) * bw  # 砂层夹石
        s.poly([(px, fy + rng.uniform(8, 14) * k), (px + 7 * k, fy + rng.uniform(5, 9) * k),
                (px + 13 * k, fy + rng.uniform(10, 16) * k)], th["detail"], 0.7)
    elif st == "salt":
        for _ in range(2):  # 盐晶竖纹（断面短竖线，受光面亮）
            px = x0 + rng.uniform(0.25, 0.75) * bw
            s.line(px, fy + 6 * k, px + rng.uniform(-2, 2) * k, fy + 18 * k,
                   th["detail"], 1.1 * k, 0.7)
        if rng.random() < 0.5:  # 粉盐渍带（断面渗色）
            s.rect(x0 + rng.uniform(0.2, 0.6) * bw, fy + rng.uniform(10, 22) * k,
                   rng.uniform(14, 26) * k, 3 * k, th["accent"], 0.22)


# ============================================================
# 掉档/升档墙脚件（画在低块带面上，wx=墙的世界 x）
# ============================================================
def wall_foot(s, th, wx, low_top, k, rng, rise=False, hi_top=None):
    st = th["style"]
    if st == "snow" and not rise and hi_top is not None:
        # 雪檐沿高块墙角悬挑（雪层下包，非包角）
        s.poly([(wx - 6 * k, hi_top), (wx + 3.5 * k, hi_top + 1.5 * k),
                (wx + 1.5 * k, hi_top + 6.5 * k), (wx - 5 * k, hi_top + 3.5 * k)],
               "#f2f7f9", 0.95)
    if st in ("rust", "park"):
        for _ in range(3):
            rx = wx + rng.uniform(2, 30) * k
            rw = rng.uniform(7, 15) * k
            rh = rng.uniform(2, 4.5) * k
            s.poly([(rx, low_top + 1.4 * k), (rx + rw * 0.5, low_top + 1.4 * k - rh),
                    (rx + rw, low_top + 1.4 * k)], th["foot"], rng.uniform(0.8, 1.0))
    elif st == "ref":
        for _ in range(2):
            rx = wx + rng.uniform(3, 26) * k
            rw = rng.uniform(6, 12) * k
            rh = rng.uniform(2.5, 5) * k
            s.poly([(rx, low_top + 1.4 * k), (rx + rw * 0.5, low_top + 1.4 * k - rh),
                    (rx + rw, low_top + 1.4 * k)], th["foot"], 0.95)
    elif st == "snow":
        s.ellipse(wx + 16 * k, low_top + 2 * k, 15 * k, 2.8 * k, th["foot"], 0.95)
        s.ellipse(wx + 7 * k, low_top + 1.5 * k, 8 * k, 1.8 * k, th["foot"], 0.85)
    elif st == "coral":
        s.glow_ellipse(wx + 14 * k, low_top + 3 * k, 18 * k, 5 * k, th["accent"], 0.16)
        for _ in range(2):
            rx = wx + rng.uniform(3, 22) * k
            s.poly([(rx, low_top + 1.4 * k), (rx + 6 * k, low_top - 3 * k),
                    (rx + 11 * k, low_top + 1.4 * k)], th["foot"], 0.95)
        s.circle(wx + 12 * k, low_top + 0.5 * k, 1.4 * k, th["accent"], 0.85)
    elif st == "cloud":
        s.ellipse(wx + 16 * k, low_top + 3 * k, 17 * k, 3.2 * k, th["foot"], 0.7)
    elif st == "desert":
        rx = wx + rng.uniform(3, 14) * k
        s.poly([(rx, low_top + 1.4 * k), (rx + 8 * k, low_top - 5 * k),
                (rx + 17 * k, low_top + 1.4 * k)], th["foot"], 0.9)
        s.ellipse(wx + 18 * k, low_top + 2 * k, 12 * k, 2.2 * k, "#d98c5e", 0.6)
    elif st == "sea":
        s.ellipse(wx + 13 * k, low_top + 1.8 * k, 13 * k, 2.2 * k, th["foot"], 0.6)
        rx = wx + rng.uniform(4, 18) * k
        s.poly([(rx, low_top + 1.4 * k), (rx + 5 * k, low_top - 3.5 * k),
                (rx + 10 * k, low_top + 1.4 * k)], "#54665c", 0.95)
    elif st == "salt":
        s.ellipse(wx + 14 * k, low_top + 2 * k, 13 * k, 2.4 * k, th["foot"], 0.6)
        rx = wx + rng.uniform(4, 18) * k
        s.poly([(rx, low_top + 1.4 * k), (rx + 5 * k, low_top - 4 * k),
                (rx + 11 * k, low_top + 1.4 * k)], th["band_light"], 0.9)
    elif st == "forest":
        s.ellipse(wx + 15 * k, low_top + 2.2 * k, 14 * k, 2.6 * k, th["foot"], 0.7)
        for _ in range(2):
            rx = wx + rng.uniform(3, 20) * k
            s.line(rx, low_top + 1.4 * k, rx + rng.uniform(-2, 2) * k,
                   low_top - rng.uniform(4, 8) * k, th["detail"], 1.6 * k, 0.9)  # 露头断根


# ============================================================
# 单块分层绘制
# ============================================================
def draw_block(s, th, x0, top, w, bottom, k, pat, drop=0, rise=0):
    """一块地块完整分层。drop/rise=与右邻档差（正=掉档档数，负=升档）。"""
    rng = random.Random(9000 + pat * 131)
    band = BAND * k
    bw = w * k

    # 5+6 立面主体 + 深层渐变
    face = _vgrad(s, [(0, th["face_hi"], 1), (0.72, th["face_lo"], 1), (1, th["face_lo"], 1)])
    s.rect(x0, top + band, bw, bottom - top - band, face)

    # 4 立面 AO 带
    ao = _vgrad(s, [(0, th["ao"], 0.8), (1, th["ao"], 0.0)])
    s.rect(x0, top + band, bw, 5.0 * k, ao)

    # 5b 立面层理
    yy = band + 16 * k
    i = 0
    while top + yy < min(bottom, top + 240 * k):
        op = max(0.12, 0.42 - i * 0.11)
        s.line(x0 + 3 * k, top + yy, x0 + bw - 3 * k, top + yy, th["strata"], 1.2 * k, op)
        yy += (16 + i * 8) * k
        i += 1

    # 5c 剖面细节 + 竖裂缝/冰裂补充
    face_detail(s, th, x0, top, bw, band, k, rng)
    if th["style"] == "rust":
        for _ in range(rng.randint(1, 2)):
            cx = rng.uniform(0.2, 0.8) * bw + x0
            cy = top + band + 8 * k
            seg = [(cx, cy)]
            for _s2 in range(3):
                cx += rng.uniform(-6, 6) * k
                cy += rng.uniform(10, 18) * k
                seg.append((cx, min(cy, top + band + 80 * k)))
            s.path("M " + " L ".join(f"{f(a)},{f(b)}" for a, b in seg),
                   stroke=th["band_dark"], w=1.2 * k, opacity=0.8)
    elif th["style"] in ("snow", "coral"):
        for _ in range(rng.randint(1, 2)):
            cx = rng.uniform(0.25, 0.75) * bw + x0
            s.line(cx, top + band + 6 * k, cx + rng.uniform(-5, 5) * k,
                   top + band + 34 * k, th["face_lo"] if th["style"] == "snow" else th["band_dark"],
                   1.1 * k, 0.7)

    # 7 块间缝（上密下疏两段渐隐）
    for ex in (x0, x0 + bw):
        s.line(ex + 0.5 * k, top + band + 2 * k, ex + 0.5 * k, top + band + 46 * k,
               th["seam"], 1.2 * k, 0.55)
        s.line(ex + 0.5 * k, top + band + 46 * k, ex + 0.5 * k, top + band + 78 * k,
               th["seam"], 1.2 * k, 0.25)

    # 2 走道带 + 花纹
    s.rect(x0, top, bw, band, th["band"])
    band_detail(s, th, x0, top, bw, band, k, rng)

    # 3 带底转折暗线
    s.rect(x0, top + band - 1.2 * k, bw, 1.2 * k, th["band_edge"])

    # 1 顶缘亮线（包角已删——用户意见 2026-10-21）
    s.rect(x0, top, bw, 1.4 * k, th["top_line"])

    # 8b 升档：右墙接触阴影（本块带上向左渐隐）
    if rise > 0:
        sh = _hgrad(s, [(0, th["ao"], 0.55), (1, th["ao"], 0.0)])
        sw = 36.0 * k
        s.rect(x0 + bw - sw, top + 1.4 * k, sw, band - 1.4 * k, sh)


def draw_ground(s, key, bottom=540.0, k=1.0):
    """按 SEQ 画整幅地块 + 墙脚件。x 单位=画布半比例（k=1）。"""
    th = THEMES[key]
    tops = [X_OFF + i * CHUNK for i in range(len(SEQ))]
    for i, t in enumerate(SEQ):
        drop = max(0, t - SEQ[i + 1]) if i + 1 < len(SEQ) else 0
        rise = max(0, -(t - SEQ[i + 1])) if i + 1 < len(SEQ) else 0
        draw_block(s, th, tops[i], TIER_Y[t], CHUNK, bottom, k, i, drop, rise)
    # 墙脚件：掉档→低块带面；升档→本块带面（墙基碎屑）
    for i in range(len(SEQ) - 1):
        d = SEQ[i] - SEQ[i + 1]
        wx = tops[i + 1]
        rng = random.Random(5100 + i * 17)
        if d > 0:
            wall_foot(s, th, wx, TIER_Y[SEQ[i + 1]], k, rng, hi_top=TIER_Y[SEQ[i]])
        elif d < 0:
            wall_foot(s, th, wx - 30 * k, TIER_Y[SEQ[i]], k, rng, rise=True)


# ============================================================
# 桥面地块变体（云上高架/跨海栈桥）：走道带 + 薄箱梁 + 排架柱。
# 背景云海/海面由场景先画；柱身向下渐隐没入其中，柱脚按章给 云团/浪花。
# ============================================================
def draw_deck_block(s, th, x0, top, w, k, pat, drop=0, rise=0, fade=474.0):
    rng = random.Random(9000 + pat * 131)
    band = BAND * k
    bw = w * k
    yb = top + band

    # 薄箱梁桥体（走道带之下 12k），底缘暗线
    s.rect(x0, yb, bw, 12 * k, th["band_edge"])
    s.rect(x0, yb + 10.8 * k, bw, 1.2 * k, th["face_lo"])

    # 排架柱 ×2：柱身向下渐隐；柱间剪刀撑
    pier = th.get("pier", th["band_edge"])
    y0 = yb + 12 * k
    body = _vgrad(s, [(0, pier, 0.95), (0.72, pier, 0.8), (1, pier, 0.0)])
    for px in (x0 + 24 * k, x0 + 122 * k):
        s.rect(px, y0, 14 * k, fade - y0, body)
    x1, x2 = x0 + 38 * k, x0 + 122 * k
    yb2 = min(fade - 26 * k, y0 + (fade - y0) * 0.45)
    s.line(x1, y0 + 6 * k, x2, yb2, pier, 1.6 * k, 0.55)
    s.line(x2, y0 + 6 * k, x1, yb2, pier, 1.6 * k, 0.55)
    # 柱脚：云团/浪花（按章 foot 色）
    for px in (x0 + 31 * k, x0 + 129 * k):
        s.ellipse(px, fade, 17 * k, 4 * k, th["foot"], 0.5)

    # 7 块间接缝（只在走道带+梁体上）
    for ex in (x0, x0 + bw):
        s.line(ex + 0.5 * k, top + 3 * k, ex + 0.5 * k, yb + 10 * k, th["seam"], 1.2 * k, 0.5)

    # 2 走道带 + 花纹
    s.rect(x0, top, bw, band, th["band"])
    band_detail(s, th, x0, top, bw, band, k, rng)

    # 3 带底转折暗线（梁体色即转折）
    # 1 顶缘亮线
    s.rect(x0, top, bw, 1.4 * k, th["top_line"])

    # 8b 升档：右墙接触阴影（本块带上向左渐隐）
    if rise > 0:
        sh = _hgrad(s, [(0, th["ao"], 0.55), (1, th["ao"], 0.0)])
        sw = 36.0 * k
        s.rect(x0 + bw - sw, top + 1.4 * k, sw, band - 1.4 * k, sh)


def draw_ground_deck(s, key, k=1.0, fade=474.0):
    """桥面地块整幅（背景云海/海面由场景先画好）。"""
    th = THEMES[key]
    tops = [X_OFF + i * CHUNK for i in range(len(SEQ))]
    for i, t in enumerate(SEQ):
        drop = max(0, t - SEQ[i + 1]) if i + 1 < len(SEQ) else 0
        rise = max(0, -(t - SEQ[i + 1])) if i + 1 < len(SEQ) else 0
        draw_deck_block(s, th, tops[i], TIER_Y[t], CHUNK, k, i, drop, rise, fade)
