# -*- coding: utf-8 -*-
"""2d-ac 场景美术提案生成器：4 套 AC6 风格场景，纯几何计算，手写矢量。

构图对齐游戏实际画面：画布 1200x540（= 视口 2400x1080 的一半，20:9），
地面线 y=330（约 61% 高度，对应游戏内地表 600~664 的落位），玩家位 x=400（左 1/3）。

Godot/ThorVG 兼容约束：只用 rect/polygon/path/circle/ellipse/line + linearGradient，
不用 <filter>/<pattern>/<use>/<text>/<image>（Godot 的 SVG 导入对 filter 支持不可靠，
氛围全靠分层透明度与渐变）。种子固定，重跑结果一致。
"""
import math
import os
import random

from terrain_blocks import ground_v2

W, H = 1200, 540
GROUND = 330.0
OUT = os.path.dirname(os.path.abspath(__file__))


def f(v):
    s = f"{v:.1f}"
    s = s.rstrip("0").rstrip(".")
    return s if s else "0"


def pts(seq):
    return " ".join(f"{f(x)},{f(y)}" for x, y in seq)


class Svg:
    def __init__(self, w: float = W, h: float = H):
        self.w = w
        self.h = h
        self.defs = []
        self.body = []
        self._gid = 0

    # ---- 渐变 ----
    def vgrad(self, gid, stops, y1=0.0, y2=1.0):
        """竖向线性渐变；stops = [(offset, color, opacity), ...]"""
        ss = "".join(
            f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops
        )
        self.defs.append(
            f'<linearGradient id="{gid}" x1="0" y1="{y1}" x2="0" y2="{y2}">{ss}</linearGradient>'
        )
        return f"url(#{gid})"

    def rgrad(self, color, op0, op1=0.0):
        """径向渐变（中心 op0 → 边缘 op1），用于无 filter 的软光晕"""
        self._gid += 1
        gid = f"rg{self._gid}"
        self.defs.append(
            f'<radialGradient id="{gid}">'
            f'<stop offset="0" stop-color="{color}" stop-opacity="{op0}"/>'
            f'<stop offset="1" stop-color="{color}" stop-opacity="{op1}"/></radialGradient>'
        )
        return f"url(#{gid})"

    def glow_ellipse(self, cx, cy, rx, ry, color, op):
        """中心亮边缘透明的椭圆光晕"""
        self.ellipse(cx, cy, rx, ry, self.rgrad(color, op, 0.0))

    def _lgrad(self, gid, stops, x2, y2):
        ss = "".join(
            f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops
        )
        self.defs.append(
            f'<linearGradient id="{gid}" x1="0" y1="0" x2="{x2}" y2="{y2}">{ss}</linearGradient>'
        )
        return f"url(#{gid})"

    # ---- 图元 ----
    def _op(self, opacity):
        return f' opacity="{opacity}"' if opacity is not None else ""

    def rect(self, x, y, w, h, fill, opacity=None, rx=None):
        r = f' rx="{rx}"' if rx else ""
        self.body.append(
            f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}"{r} fill="{fill}"{self._op(opacity)}/>'
        )

    def poly(self, seq, fill, opacity=None):
        self.body.append(f'<polygon points="{pts(seq)}" fill="{fill}"{self._op(opacity)}/>')

    def line(self, x1, y1, x2, y2, stroke, w=1.0, opacity=None, cap=None):
        c = f' stroke-linecap="{cap}"' if cap else ""
        self.body.append(
            f'<line x1="{f(x1)}" y1="{f(y1)}" x2="{f(x2)}" y2="{f(y2)}" '
            f'stroke="{stroke}" stroke-width="{f(w)}"{c}{self._op(opacity)}/>'
        )

    def path(self, d, fill="none", stroke=None, w=1.0, opacity=None, cap=None):
        s = f' stroke="{stroke}" stroke-width="{f(w)}"' if stroke else ""
        c = f' stroke-linecap="{cap}"' if cap else ""
        self.body.append(f'<path d="{d}" fill="{fill}"{s}{c}{self._op(opacity)}/>')

    def circle(self, cx, cy, r, fill, opacity=None):
        self.body.append(
            f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{fill}"{self._op(opacity)}/>'
        )

    def ellipse(self, cx, cy, rx, ry, fill, opacity=None):
        self.body.append(
            f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}" fill="{fill}"{self._op(opacity)}/>'
        )

    def group(self, transform=None):
        t = f' transform="{transform}"' if transform else ""
        self.body.append(f"<g{t}>")

    def endgroup(self):
        self.body.append("</g>")

    def save(self, name):
        svg = (
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(self.w)} {f(self.h)}" '
            f'width="{f(self.w)}" height="{f(self.h)}">\n<defs>\n' + "\n".join(self.defs) + "\n</defs>\n"
            + "\n".join(self.body) + "\n</svg>\n"
        )
        p = os.path.join(OUT, name)
        with open(p, "w", encoding="utf-8") as fp:
            fp.write(svg)
        print(f"{name}: {len(svg) // 1024} KB")


# ============================================================
# 公共小部件
# ============================================================
def glow_dot(s, x, y, color, r=3.0, halos=((8, 0.30), (16, 0.13))):
    """信号灯：实心点 + 两圈透明度递减光晕（无 filter 的假发光）"""
    for hr, hop in halos:
        s.circle(x, y, hr, color, hop)
    s.circle(x, y, r, color)


def haze_band(s, y0, y1, color, peak=0.3):
    """横向雾带：竖向渐变 0→peak→0，压在层与层之间拉开深度"""
    g = s.vgrad(f"haze_{color.strip('#')}_{int(peak * 100)}_{int(y0)}",
                [(0, color, 0), (0.5, color, peak), (1, color, 0)])
    s.rect(0, y0, W, y1 - y0, g)


def fissure(s, rng, x0, y0, length, w0, max_y):
    """地裂：暗色裂隙体 + 内部熔光 + 分叉。返回主线末端 (x, y)。"""
    cline = [(x0, y0)]
    cx, cy = x0, y0
    n = max(4, int(length // 26))
    for _ in range(n):
        cx += rng.uniform(-20, 20)
        cy += length / n
        cline.append((cx, min(cy, max_y)))
    half = [max(1.2, w0 * (1 - i / len(cline))) for i in range(len(cline))]  # 口宽尾细
    body = [(px - hw, py) for (px, py), hw in zip(cline, half)]
    body += [(px + hw, py) for (px, py), hw in zip(reversed(cline), reversed(half))]
    d = "M " + " L ".join(f"{f(px)},{f(py)}" for px, py in body) + " Z"
    s.path(d, fill="#ff4d2e", opacity=0.10)  # 外晕
    s.path(d, fill="#04060d")                # 裂隙空洞
    dd = "M " + " L ".join(f"{f(px)},{f(py)}" for px, py in cline)
    s.path(dd, stroke="#ff5a33", w=2.4, opacity=0.5, cap="round")
    s.path(dd, stroke="#ff8a4d", w=1.4, opacity=0.95, cap="round")
    for nx, ny in (cline[0], cline[len(cline) // 2], cline[-1]):
        s.glow_ellipse(nx, ny, 26, 10, "#ff5a33", 0.30)
    # 分叉
    bx, by = cline[len(cline) // 3]
    branch = [(bx, by)]
    for _ in range(3):
        bx += rng.uniform(-24, 24)
        by += rng.uniform(14, 22)
        branch.append((bx, min(by, max_y)))
    dd2 = "M " + " L ".join(f"{f(px)},{f(py)}" for px, py in branch)
    s.path(dd2, stroke="#ff5a33", w=4, opacity=0.14, cap="round")
    s.path(dd2, stroke="#ff8a4d", w=1.2, opacity=0.85, cap="round")
    return cline[-1]


# ============================================================
# 方案一：锈雨废都（AC6 第一章废弃都市 vibe）
# ============================================================
def rust_city():
    rng = random.Random(101)
    s = Svg()

    # 天空：脏赭色雾霾
    sky = s.vgrad("sky1", [(0, "#b3a37c", 1), (0.55, "#c9b88e", 1), (1, "#a2936f", 1)])
    s.rect(0, 0, W, GROUND, sky)
    # 隐日
    s.glow_ellipse(830, 140, 130, 110, "#eadfb0", 0.30)
    s.glow_ellipse(830, 140, 55, 48, "#f2e8bd", 0.45)

    # ---- 远景两层（WorldStrip scroll_scale≈0.9）----
    for color, op, hmin, hmax, step in (("#9a9078", 0.5, 100, 190, (50, 95)),
                                        ("#857a5e", 0.68, 130, 250, (60, 110))):
        x = -30.0
        while x < W + 40:
            w = rng.uniform(38, 86)
            h = rng.uniform(hmin, hmax)
            top = GROUND - h
            # 破损天际线：顶缘 3~5 段跌落
            n = rng.randint(3, 5)
            tops = [(x, top + rng.uniform(0, h * 0.25))]
            for i in range(1, n):
                tops.append((x + w * i / (n - 1), top + rng.uniform(0, h * 0.25)))
            tops.append((x + w, top + rng.uniform(0, h * 0.25)))
            s.poly([(x, GROUND)] + tops + [(x + w, GROUND)], color, op)
            if rng.random() < 0.35:  # 天线
                ax = x + w * rng.uniform(0.2, 0.8)
                s.line(ax, top, ax, top - rng.uniform(18, 46), color, 1.6, op)
            x += w + rng.uniform(*step)
    # 远景巨构（AC6 地标感）：左侧巨型板塔 + 右侧工程起重机剪影
    s.poly([(66, GROUND), (66, GROUND - 132), (84, GROUND - 150), (178, GROUND - 150),
            (186, GROUND - 120), (186, GROUND)], "#6f6650", 0.85)
    for i in range(6):
        yy = GROUND - 18 - i * 22
        s.line(70, yy, 182, yy, "#5d5644", 1.4, 0.8)
    s.line(132, GROUND - 150, 132, GROUND - 184, "#6f6650", 3, 0.85)
    s.line(946, GROUND, 952, GROUND - 168, "#6f6650", 3, 0.85)      # 起重机塔身
    s.line(884, GROUND - 160, 1064, GROUND - 172, "#6f6650", 2.4, 0.85)  # 臂架
    s.line(952, GROUND - 168, 902, GROUND - 96, "#6f6650", 1.6, 0.8)     # 拉索
    s.line(950, GROUND - 148, 1042, GROUND - 158, "#6f6650", 1.2, 0.7)
    s.line(1042, GROUND - 158, 1042, GROUND - 128, "#6f6650", 1.2, 0.7)  # 吊索+钩
    s.rect(1038, GROUND - 128, 8, 6, "#6f6650", 0.85)
    haze_band(s, 190, GROUND, "#cabb8e", 0.32)

    # ---- 中景楼群（scroll_scale≈0.55）----
    x = -40.0
    while x < W + 60:
        w = rng.uniform(90, 150)
        h = rng.uniform(170, 290)
        top = GROUND - h
        lean = rng.uniform(-18, 18) if rng.random() < 0.3 else 0.0  # 少量倾斜楼
        col_w = rng.choice((15, 17, 19))  # 每楼窗距不同

        def sx(yy, _h=h, _lean=lean):
            return _lean * (GROUND - yy) / _h

        # 楼体：顶缘缺口
        n = rng.randint(3, 5)
        edge = []
        for i in range(n + 1):
            ex = x + w * i / n
            ey = top + (rng.uniform(4, 26) if 0 < i < n and i % 2 == 0 else rng.uniform(2, 10))
            edge.append((ex + sx(ey), ey))
        s.poly([(x, GROUND)] + edge + [(x + w, GROUND)], "#57544a")
        # 楼层板（受光面，略亮于楼体）
        yy = top + 16
        while yy < GROUND - 6:
            off = sx(yy)
            s.line(x + 3 + off, yy, x + w - 3 + off, yy, "#63604f", 1.0, 0.55)
            yy += 15
        # 窗格：稀疏点灯
        wx = x + 10
        while wx < x + w - 12:
            wy = top + 18
            while wy < GROUND - 16:
                off = sx(wy)
                r = rng.random()
                if r < 0.05:
                    s.rect(wx - 3 + off, wy - 3, 12, 13, "#ff9b45", 0.12)  # 光晕
                    s.rect(wx + off, wy, 6, 7, "#ffa04a", 0.95)
                elif r < 0.13:
                    s.rect(wx + off, wy, 6, 7, "#6e5836", 0.9)
                else:
                    s.rect(wx + off, wy, 6, 7, "#3b3931", 0.9)
                wy += 15
            wx += col_w
        # 底层门洞透光
        if rng.random() < 0.4:
            dx = x + w * 0.5
            s.rect(dx - 14, GROUND - 34, 28, 34, "#ff8c3a", 0.18)
            s.rect(dx - 7, GROUND - 20, 14, 20, "#ff8c3a", 0.8)
        x += w + rng.uniform(8, 60)

    # ---- 高架断桥 ----
    deck_y, deck_h = 214.0, 13.0
    for x0, x1 in ((0, 585), (705, W)):
        s.rect(x0, deck_y, x1 - x0, deck_h, "#46433a")
        s.line(x0, deck_y, x1, deck_y, "#5a574b", 1.5)
        s.line(x0, deck_y + deck_h, x1, deck_y + deck_h, "#37352d", 1.5)
    # 断口斜坠的一截
    s.poly([(585, deck_y), (655, deck_y + 26), (645, deck_y + 40), (575, deck_y + 14)], "#44413a")
    for px in (90, 270, 450, 800, 980, 1140):  # 桥墩
        s.rect(px - 5.5, deck_y + deck_h, 11, GROUND - deck_y - deck_h, "#3d3a32")
    # 垂缆（只留挂在断桥上的两段；悬空无锚点的天空线会读作杂质）
    s.path("M 120 227 Q 360 300 585 227", stroke="#2c2a24", w=1.5, opacity=0.8)
    s.path("M 705 227 Q 950 296 1190 227", stroke="#2c2a24", w=1.5, opacity=0.8)

    # ---- 地表（拆地块 v2：两侧平地+中段高低差，画法与实机一致）----
    ground_v2.draw_ground(s, "ch1_rust", bottom=H, k=1.0)

    # 地表剪影道具（两侧平地段，落在最低档走道带上）
    s.poly([(118, 330), (126, 312), (148, 306), (176, 320), (196, 326), (196, 332), (118, 332)], "#33312a")
    s.poly([(136, 312), (148, 302), (166, 306), (174, 318)], "#2c2a24")  # 车壳残骸
    for bx, bh in ((1054, 16), (1068, 20), (1082, 14)):  # 油桶群
        s.rect(bx, 332 - bh, 11, bh, "#3a382f")
        s.line(bx, 332 - bh * 0.35, bx + 11, 332 - bh * 0.35, "#2c2a24", 1.2, 0.8)

    # 远处火光（贴中段高台天际线，避免落在近处走道带上读成污渍）
    s.ellipse(450, 262, 50, 12, "#ff9b45", 0.10)
    s.ellipse(450, 262, 26, 7, "#ffab5c", 0.16)
    for _ in range(14):  # 灰烬飘浮
        s.circle(rng.uniform(0, W), rng.uniform(20, 300), rng.uniform(1, 2), "#ddd3ac", rng.uniform(0.15, 0.4))
    return s


# ============================================================
# 方案二：精炼所工业带（AC6 工厂/ WALL vibe）
# ============================================================
def refinery():
    rng = random.Random(202)
    s = Svg()

    sky = s.vgrad("sky2", [(0, "#a9bcb2", 1), (0.6, "#7f988e", 1), (1, "#6b857c", 1)])
    s.rect(0, 0, W, GROUND, sky)
    for cy, rx, ry, op in ((70, 470, 11, 0.10), (108, 520, 13, 0.08), (146, 430, 10, 0.10)):
        s.ellipse(rng.uniform(300, 900), cy, rx, ry, "#5c7870", op)

    # ---- 远景烟囱群（0.9）----
    x = -20.0
    while x < W + 40:
        w = rng.uniform(14, 34)
        h = rng.uniform(130, 230)
        s.rect(x, GROUND - h, w, h, "#5a736c", 0.5)
        if rng.random() < 0.4:
            s.rect(x - 4, GROUND - h - 5, w + 8, 5, "#5a736c", 0.5)
        if rng.random() < 0.3:
            s.line(x + w / 2, GROUND - h, x + w / 2, GROUND - h - rng.uniform(20, 44), "#5a736c", 1.4, 0.5)
        x += w + rng.uniform(30, 66)
    haze_band(s, 170, GROUND, "#8ba39a", 0.32)

    # ---- 远景中央冷却塔（双曲面收腰剪影，画在栈桥之后、塔群之前）----
    right, left = [], []
    for i in range(11):
        t = i / 10.0
        yy = GROUND - 208 * t
        hw = 52 + (38 - 52) * t - 18 * math.sin(math.pi * t)
        right.append((612 + hw, yy))
        left.append((612 - hw, yy))
    s.poly(right + left[::-1], "#5a736c", 0.65)
    s.glow_ellipse(612, GROUND - 214, 64, 18, "#c5d2ca", 0.10)  # 塔顶蒸汽

    # ---- 左侧蒸馏塔群（0.55）----
    for cx, cw, ch in ((40, 64, 275), (128, 52, 240), (205, 70, 290)):
        top = GROUND - ch
        s.rect(cx, top, cw, ch, "#38504a")
        s.ellipse(cx + cw / 2, top, cw / 2, 6, "#2f443f")  # 顶盖
        yy = top + 34
        while yy < GROUND - 14:  # 平台环 + 栏杆
            s.rect(cx - 5, yy, cw + 10, 5, "#2f443f")
            s.line(cx - 5, yy - 8, cx + cw + 5, yy - 8, "#2a3c37", 1.2, 0.9)
            px = cx - 5
            while px <= cx + cw + 5:
                s.line(px, yy - 8, px, yy, "#2a3c37", 1.0, 0.8)
                px += 16
            yy += 38
        # 竖梯
        s.line(cx + cw * 0.3, top + 12, cx + cw * 0.3, GROUND - 8, "#2a3c37", 1.2, 0.8)
        ry = top + 20
        while ry < GROUND - 12:
            s.line(cx + cw * 0.3 - 4, ry, cx + cw * 0.3 + 4, ry, "#2a3c37", 1.0, 0.7)
            ry += 12
    # 塔间连管
    for yy in (180, 212):
        s.line(104, yy, 128, yy, "#2f443f", 5)
        s.line(180, yy, 205, yy, "#2f443f", 5)
    glow_dot(s, 75, GROUND - 290, "#ff4640", r=3)

    # ---- 右侧火炬塔 + 储罐 ----
    s.rect(1010, GROUND - 270, 16, 274, "#334741")
    for yy in range(int(GROUND - 240), int(GROUND), 44):
        s.line(1004, yy, 1032, yy + 20, "#2c3f39", 1.5, 0.9)
        s.line(1032, yy, 1004, yy + 20, "#2c3f39", 1.5, 0.9)
    fx, fy = 1018, GROUND - 278
    s.poly([(fx, fy - 6), (fx - 9, fy + 10), (fx, fy + 16), (fx + 9, fy + 10)], "#ff8c3a", 0.85)
    s.poly([(fx, fy - 1), (fx - 5, fy + 10), (fx, fy + 14), (fx + 5, fy + 10)], "#ffc46a", 0.9)
    s.circle(fx, fy + 7, 4, "#fff3c4", 0.95)
    sx_, sy_ = fx + 14, fy - 6
    for i in range(6):  # 烟羽
        s.ellipse(sx_ + i * 22, sy_ - i * 16, 12 + i * 4, 8 + i * 2, "#7b8b84", 0.20 - i * 0.03)
    # 地面火炬反光
    s.glow_ellipse(1018, GROUND + 34, 42, 62, "#ff9b3d", 0.16)
    # 储罐
    s.rect(900, GROUND - 66, 92, 32, "#3c524c", rx=15)
    s.line(946, GROUND - 66, 946, GROUND - 34, "#2c3f39", 1.5, 0.8)
    for bx in (912, 966):
        s.rect(bx, GROUND - 34, 8, 38, "#2f443f")
    # 危险警示条纹（黄黑）
    hzx = 912.0
    for i in range(5):
        s.poly([(hzx + i * 8, GROUND - 10), (hzx + i * 8 + 4, GROUND - 10),
                (hzx + i * 8 + 8, GROUND + 4), (hzx + i * 8 + 4, GROUND + 4)],
               "#d8a021" if i % 2 == 0 else "#2a2a24")

    # ---- 桁架栈桥（计算网格；抬高避让中段 t2 高台顶 268）----
    bx0, bx1, by0, by1 = 240.0, 940.0, 212.0, 240.0
    s.line(bx0, by0, bx1, by0, "#2c403a", 5)
    s.line(bx0, by1, bx1, by1, "#2c403a", 5)
    n = int((bx1 - bx0) // 35)
    for i in range(n + 1):
        vx = bx0 + i * 35
        s.line(vx, by0, vx, by1, "#2c403a", 2)
        if i < n:
            if i % 2 == 0:
                s.line(vx, by0, vx + 35, by1, "#2c403a", 2)
            else:
                s.line(vx, by1, vx + 35, by0, "#2c403a", 2)
    s.rect(bx0, by1, bx1 - bx0, 5, "#31463f")
    for px in (350, 850):
        s.rect(px - 7, by1 + 5, 14, GROUND - by1 - 5, "#2c403a")
    glow_dot(s, 350, by1 + 8, "#ff4640", r=2.2, halos=((6, 0.3), (11, 0.12)))
    glow_dot(s, 850, by1 + 8, "#ff4640", r=2.2, halos=((6, 0.3), (11, 0.12)))

    # 前景管排（两侧平地段，留出中段高低差视野）
    for x0, x1 in ((0, 215), (950, 1200)):
        for yy in (300, 312):
            s.line(x0, yy, x1, yy, "#354944", 8)
            s.line(x0, yy - 2.5, x1, yy - 2.5, "#4d635d", 2, 0.9)
        px = x0 + 10
        while px < x1:
            s.rect(px - 3, 314, 6, 24, "#2b3b36")
            if (px - x0) % 110 < 55:  # 法兰
                s.rect(px - 2, 295, 4, 22, "#2b3b36")
            px += 55

    # 工作灯锥光
    s.circle(75, GROUND - 160, 2.5, "#ffd9a0")
    s.poly([(75, GROUND - 158), (28, GROUND + 4), (152, GROUND + 4)], "#ffcf8e", 0.08)

    # ---- 地表（拆地块 v2）----
    ground_v2.draw_ground(s, "ch2_ref", bottom=H, k=1.0)
    for gx, gy in ((200, 342), (560, 278), (1080, 342)):  # 排水格栅（贴所在档走道带）
        for i in range(5):
            s.line(gx, gy + i * 4, gx + 46, gy + i * 4, "#1c2420", 1.5)
    # 溢散蒸汽（贴档顶）
    for vx, vy in ((430, 258), (760, 292)):
        for i in range(3):
            s.circle(vx + i * 12, vy - i * 14, 10 + i * 6, "#c5d2ca", 0.07 - i * 0.015)
    return s


# ============================================================
# 方案三：雪原警戒点（AC6 第三章雪原 vibe，高调冰白）
# ============================================================
def snowfield():
    rng = random.Random(303)
    s = Svg()

    sky = s.vgrad("sky3", [(0, "#d4e2ea", 1), (0.6, "#e9f1f5", 1), (1, "#f7fafb", 1)])
    s.rect(0, 0, W, GROUND, sky)
    s.circle(870, 110, 120, "#ffffff", 0.08)
    s.circle(870, 110, 80, "#ffffff", 0.18)
    s.circle(870, 110, 46, "#ffffff", 0.55)

    # ---- 远岭 ----
    ridge = [(0, GROUND)]
    rx = 0.0
    while rx < W:
        rx += rng.uniform(80, 150)
        ridge.append((rx, GROUND - rng.uniform(24, 70)))
    ridge.append((W, GROUND))
    s.poly(ridge, "#c2d2db")

    # ---- 远景军事设施 ----
    far = "#8ba0ab"
    # 左侧掩体
    s.rect(130, GROUND - 34, 92, 34, far, 0.9)
    s.rect(126, GROUND - 40, 100, 8, "#eef4f7", 0.95)
    s.rect(165, GROUND - 26, 22, 10, "#4a5a64", 0.9)
    # 雷达塔（桁架计算）
    tx = 690.0
    s.line(tx - 20, GROUND, tx - 4, 128, far, 3)
    s.line(tx + 20, GROUND, tx + 4, 128, far, 3)
    yy = GROUND - 24
    while yy > 140:
        t = (GROUND - yy) / (GROUND - 128)
        xl = tx - 20 + 16 * t
        xr = tx + 20 - 16 * t
        s.line(xl, yy, xr, yy - 22, far, 1.5, 0.9)
        s.line(xr, yy, xl, yy - 22, far, 1.5, 0.9)
        yy -= 22
    s.rect(tx - 24, 150, 48, 5, far)
    s.circle(tx, 112, 11, far)
    s.line(tx, 112, tx + 9, 103, far, 1.5)
    s.line(tx, 128, tx, 84, far, 2.5)
    glow_dot(s, tx, 82, "#e23d3d", r=3, halos=((7, 0.35), (13, 0.15)))
    # 右侧远掩体
    s.rect(1040, GROUND - 26, 70, 26, far, 0.85)
    s.rect(1036, GROUND - 31, 78, 7, "#eef4f7", 0.9)
    haze_band(s, 200, GROUND, "#dfe9ee", 0.4)

    # ---- 中景：半埋运输机残骸（机头朝画面中央、尾部出画，腹埋雪中）----
    s.group(f"translate(885,{f(GROUND + 40)}) rotate(-6)")
    s.rect(0, -86, 300, 46, "#5a6a74", rx=22)          # 机身
    s.rect(0, -56, 300, 8, "#46545e")                   # 腹部阴影
    s.rect(10, -66, 300, 5, "#c24438", 0.8)             # 红色识别带
    wx = 26
    while wx < 270:                                     # 舷窗
        s.rect(wx, -78, 7, 8, "#2e3840", 0.9)
        wx += 19
    s.poly([(240, -86), (296, -138), (306, -132), (286, -84)], "#54646e")  # 垂尾
    s.poly([(120, -64), (200, -50), (188, -36), (96, -54)], "#4c5a64")     # 断翼残段
    s.rect(150, -52, 34, 16, "#46545e", rx=6)                              # 发动机短舱
    s.poly([(286, -60), (306, -50), (300, -38), (280, -48)], "#3e4a53")    # 尾部撕裂口
    s.endgroup()
    # 盖上积雪
    s.poly([(860, GROUND + 2), (940, GROUND - 28), (1030, GROUND - 14), (1120, GROUND + 2), (1120, GROUND + 4), (860, GROUND + 4)], "#e9f1f5")
    s.ellipse(1010, GROUND - 2, 140, 12, "#eef4f7")

    # 路侧电线杆（贴所在档顶；700 挪 730 避开掉档墙）
    pole = "#6e8694"
    poles = [(150, 3, 332.0), (430, -2, 268.0), (730, 2, 300.0), (980, -3, 300.0)]
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
            s.path(f"M {f(x0w)},{f(y0w)} Q {f((x0w + x1w) / 2)},{f((y0w + y1w) / 2 + 9)} {f(x1w)},{f(y1w)}",
                   stroke=pole, w=1.1, opacity=0.7)

    # ---- 地表：拆地块 v2（路板走道带+亮雪断面，画法与实机一致）----
    ground_v2.draw_ground(s, "ch3_snow", bottom=H, k=1.0)
    # 中景雪堆（画在块顶之后，落在所在档走道带上）
    for mx, mw, mh in ((240, 160, 22), (520, 120, 14), (760, 200, 26)):
        base = 268.0 if mx < 700 else 300.0
        s.ellipse(mx, base, mw / 2, mh, "#dbe6ec")

    # ---- 风雪（向左后掠，强化向右跑的速度感）----
    for _ in range(16):
        lx, ly = rng.uniform(80, W), rng.uniform(40, 260)
        ln = rng.uniform(40, 95)
        s.line(lx, ly, lx - ln, ly + ln * 0.12, "#ffffff", 2, rng.uniform(0.3, 0.55), cap="round")
    for _ in range(18):
        s.circle(rng.uniform(0, W), rng.uniform(10, H), rng.uniform(1, 2.2), "#ffffff", rng.uniform(0.5, 0.9))
    return s


# ============================================================
# 方案四：珊瑚辐合夜（AC6 后期 Coral vibe，最有辨识度）
# ============================================================
def arc_path(cx, cy, r, a0, a1):
    """角度制圆弧 path（度，0=正右，顺时针为正）"""
    x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
    x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M {f(x0)},{f(y0)} A {f(r)} {f(r)} 0 {large} 1 {f(x1)},{f(y1)}"


def coral_night():
    rng = random.Random(404)
    s = Svg()

    sky = s.vgrad("sky4", [(0, "#090d22", 1), (0.55, "#131a38", 1), (1, "#273052", 1)])
    s.rect(0, 0, W, GROUND, sky)
    for _ in range(24):
        s.circle(rng.uniform(0, W), rng.uniform(10, 220), rng.uniform(0.8, 1.6), "#dfe6ff", rng.uniform(0.3, 0.85))

    # ---- 天空碎环巨构 ----
    rcx, rcy, rr = 795.0, 168.0, 148.0
    for a0, a1 in ((-30, 80), (95, 150), (166, 205), (216, 258), (268, 320)):
        s.path(arc_path(rcx, rcy, rr, a0, a1), stroke="#1c2547", w=24)
    # 一段错位的碎环
    s.path(arc_path(rcx + 7, rcy + 9, rr, 20, 62), stroke="#232d55", w=22)
    # 下缘珊瑚光边
    s.path(arc_path(rcx, rcy, rr - 12, 120, 205), stroke="#ff5a33", w=2.5, opacity=0.85)
    s.path(arc_path(rcx, rcy, rr - 12, 120, 205), stroke="#ff5a33", w=9, opacity=0.2)
    for aa in (128, 160, 188):
        ax = rcx + (rr - 12) * math.cos(math.radians(aa))
        ay = rcy + (rr - 12) * math.sin(math.radians(aa))
        s.circle(ax, ay, 4, "#ff7a45", 0.35)
        s.circle(ax, ay, 1.6, "#ffb36b", 0.95)

    # ---- 远景巨构塔群（剪影 + 稀疏珊瑚窗）----
    for tx, tw, th in ((60, 80, 210), (185, 56, 260), (300, 110, 170), (520, 70, 240),
                       (640, 90, 140), (980, 100, 250), (1120, 60, 190)):
        top = GROUND - th
        s.rect(tx, top, tw, th, "#0d1330")
        if rng.random() < 0.6:  # 斜切顶
            cut = rng.uniform(10, 30)
            s.poly([(tx, top), (tx + tw, top), (tx + tw, top + cut)], "#0d1330")
        if rng.random() < 0.5:
            s.line(tx + tw * 0.5, top, tx + tw * 0.5, top - rng.uniform(16, 40), "#0d1330", 2)
        for _ in range(rng.randint(2, 5)):
            s.rect(tx + rng.uniform(4, tw - 8), top + rng.uniform(10, th - 14), 2.5, 4, "#ff6a3d", rng.uniform(0.5, 0.9))
    # 地平线远端珊瑚辉光（贴中段高台天际线，别落在近处走道带上）
    s.ellipse(450, 262, 60, 13, "#ff5a33", 0.10)
    s.ellipse(450, 262, 28, 7, "#ff7a45", 0.16)

    # ---- 雾带 + 两侧岩丘 ----
    haze_band(s, GROUND - 74, GROUND - 18, "#3a4674", 0.30)
    for side in ("L", "R"):
        if side == "L":
            mound = [(0, GROUND), (30, GROUND - 34), (90, GROUND - 52), (160, GROUND - 30), (230, GROUND - 46), (265, GROUND)]
        else:
            mound = [(930, GROUND), (980, GROUND - 40), (1060, GROUND - 58), (1130, GROUND - 28), (1200, GROUND - 44), (1200, GROUND)]
        s.poly(mound, "#0a0e22")
        # 岩顶天光冷边
        for i in range(len(mound) - 1):
            x0, y0 = mound[i]
            x1, y1 = mound[i + 1]
            if y0 < GROUND and y1 < GROUND:
                s.line(x0, y0, x1, y1, "#4a5890", 1.2, 0.35)

    # ---- 地表：拆地块 v2（暗玄武岩块 + 走道带珊瑚辉光裂纹 + 断面辉光脉）----
    ground_v2.draw_ground(s, "ch4_coral", bottom=H, k=1.0)
    # 上升余烬
    for _ in range(15):
        ex, ey = rng.uniform(480, 820), rng.uniform(190, 330)
        s.circle(ex, ey, rng.uniform(1, 2), "#ff9c5a", rng.uniform(0.3, 0.9))
        s.line(ex, ey + 3, ex, ey + 9, "#ff9c5a", 1, 0.12)
    return s


PROPOSALS = [
    ("proposal_1_rust_city.svg", rust_city, "方案一 · 锈雨废都",
     "第一章废弃都市 vibe：酸雾锈色 + 钠灯橙点，断桥垂缆、层叠废墟天际线。",
     ["#c9b88e", "#57544a", "#3a382f", "#ffa04a", "#4d4a40"],
     "远景天际线 0.9 / 中景楼群 0.55 / 地表 0；钠灯橙是唯一的暖色，敌我弹道 readable"),
    ("proposal_2_refinery.svg", refinery, "方案二 · 精炼所工业带",
     "工厂/墙 vibe：钢青绿天光 + 红警灯 + 危险黄，桁架栈桥横穿画面。",
     ["#7f988e", "#38504a", "#2c403a", "#ff4640", "#d8a021"],
     "远景烟囱群 0.9 / 中景塔群栈桥 0.55 / 前景管排与地表 0；结构感最强，最'工业 AC'"),
    ("proposal_3_snowfield.svg", snowfield, "方案三 · 雪原警戒点",
     "第三章雪原 vibe：高调冰白 + 暗色剪影 + 一点信号红，半埋运输机残骸。",
     ["#f7fafb", "#c2d2db", "#4d5963", "#5a6a74", "#e23d3d"],
     "远岭雷达塔 0.9 / 中景残骸雪堆 0.55 / 雪盖公路 0；暗色机体在雪上辨识度最高"),
    ("proposal_4_coral_night.svg", coral_night, "方案四 · 珊瑚辐合夜",
     "后期 Coral vibe：靛蓝夜空 + 碎环巨构 + 地裂珊瑚辉光，最具 AC6 辨识度。",
     ["#090d22", "#182042", "#0d1330", "#ff5a33", "#ffb36b"],
     "碎环+塔群 0.9 / 雾带岩丘 0.55 / 发光地裂地表 0；暗场对弹道可读性是主要风险"),
]


def build_gallery():
    rows = []
    for fname, _, title, desc, palette, layer_note in PROPOSALS:
        chips = "".join(
            f'<span class="chip" style="background:{c}"></span><code>{c}</code>' for c in palette
        )
        rows.append(f"""
    <section>
      <h2>{title}</h2>
      <p class="desc">{desc}</p>
      <img src="{fname}" alt="{title}">
      <p class="meta"><b>调色板：</b>{chips}</p>
      <p class="meta"><b>分层/视差：</b>{layer_note}</p>
    </section>""")
    html = f"""<!DOCTYPE html>
<html lang="zh"><head><meta charset="utf-8">
<title>2d-ac 场景美术提案 · AC6 方向</title>
<style>
  body {{ background:#101216; color:#d8dce2; font-family:"Microsoft YaHei",system-ui,sans-serif; margin:32px auto; max-width:1280px; padding:0 20px; }}
  h1 {{ font-size:22px; }} h2 {{ font-size:18px; margin:0 0 4px; color:#f0f2f5; }}
  .note {{ color:#9aa2ad; font-size:13px; }}
  section {{ margin:34px 0; }}
  img {{ width:100%; border-radius:8px; display:block; box-shadow:0 4px 24px rgba(0,0,0,.5); }}
  .desc {{ margin:2px 0 10px; color:#b8bfc8; }}
  .meta {{ font-size:13px; color:#9aa2ad; margin:4px 0; }}
  .chip {{ display:inline-block; width:14px; height:14px; border-radius:3px; vertical-align:-2px; margin:0 4px 0 10px; border:1px solid rgba(255,255,255,.2);}}
  code {{ color:#8fa0b8; font-size:12px; }}
</style></head><body>
<h1>2d-ac 场景美术提案 · AC6 方向（手写矢量）</h1>
<p class="note">画布 1200×540 = 游戏视口 2400×1080 的一半（20:9）；地面线 y=330 ≈ 画面 61%，对齐游戏内落位。全部几何计算生成，无滤镜/文本，Godot ThorVG 兼容。纯场景，不含机甲。</p>
{"".join(rows)}
</body></html>"""
    p = os.path.join(OUT, "gallery.html")
    with open(p, "w", encoding="utf-8") as fp:
        fp.write(html)
    print("gallery.html OK")


if __name__ == "__main__":
    for fname, fn, *_ in PROPOSALS:
        fn().save(fname)
    build_gallery()
