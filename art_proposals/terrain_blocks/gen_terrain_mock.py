# -*- coding: utf-8 -*-
"""拆地块（terrain chunk）美术提案 · 效果图生成器（mock + 解剖图）。

几何/分层语言全部来自 ground_v2 公共模块（与场景提案预览、实机烘焙同源）。
本文件只负责：画布、天空与远景简笔、玩家比例锚、解剖图拼装。
实机几何账（balance.gd / terrain.gd）：块宽 320、档差 64、三档 536/600/664、
同高连续 2~4 块；画布=世界÷2。
"""
import os
import random

import ground_v2 as gv
from ground_v2 import f

OUT = os.path.dirname(os.path.abspath(__file__))
W, H = 1200, 540


class Svg:
    """首批同款最小 SVG 写出器。"""

    def __init__(self, w=W, h=H):
        self.w, self.h = w, h
        self.defs, self.body = [], []
        self._gid = 0

    def uid(self, p):
        self._gid += 1
        return f"{p}{self._gid}"

    def vgrad(self, stops):
        gid = self.uid("vg")
        ss = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
        self.defs.append(f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">{ss}</linearGradient>')
        return f"url(#{gid})"

    def hgrad(self, stops, x2=1.0, y2=0.0):
        gid = self.uid("hg")
        ss = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
        self.defs.append(f'<linearGradient id="{gid}" x1="0" y1="0" x2="{x2}" y2="{y2}">{ss}</linearGradient>')
        return f"url(#{gid})"

    def rect(self, x, y, w, h, fill, opacity=None):
        op = f' opacity="{opacity}"' if opacity is not None else ""
        self.body.append(f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" fill="{fill}"{op}/>')

    def poly(self, seq, fill, opacity=None):
        op = f' opacity="{opacity}"' if opacity is not None else ""
        self.body.append(f'<polygon points="{gv.pts(seq)}" fill="{fill}"{op}/>')

    def line(self, x1, y1, x2, y2, stroke, w=1.0, opacity=None, cap=None):
        c = f' stroke-linecap="{cap}"' if cap else ""
        op = f' opacity="{opacity}"' if opacity is not None else ""
        self.body.append(
            f'<line x1="{f(x1)}" y1="{f(y1)}" x2="{f(x2)}" y2="{f(y2)}" '
            f'stroke="{stroke}" stroke-width="{f(w)}"{c}{op}/>')

    def path(self, d, fill="none", stroke=None, w=1.0, opacity=None, cap=None):
        s_ = f' stroke="{stroke}" stroke-width="{f(w)}"' if stroke else ""
        c = f' stroke-linecap="{cap}"' if cap else ""
        op = f' opacity="{opacity}"' if opacity is not None else ""
        self.body.append(f'<path d="{d}" fill="{fill}"{s_}{c}{op}/>')

    def circle(self, cx, cy, r, fill, opacity=None):
        op = f' opacity="{opacity}"' if opacity is not None else ""
        self.body.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{fill}"{op}/>')

    def ellipse(self, cx, cy, rx, ry, fill, opacity=None):
        op = f' opacity="{opacity}"' if opacity is not None else ""
        self.body.append(
            f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}" fill="{fill}"{op}/>')

    def glow_ellipse(self, cx, cy, rx, ry, color, op):
        self.ellipse(cx, cy, rx, ry, self.hgrad([(0, color, op), (1, color, 0.0)]))

    def to_text(self):
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(self.w)} {f(self.h)}" '
            f'width="{f(self.w)}" height="{f(self.h)}">\n<defs>\n' + "\n".join(self.defs) +
            "\n</defs>\n" + "\n".join(self.body) + "\n</svg>\n")

    def save(self, name):
        svg = self.to_text()
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as fp:
            fp.write(svg)
        print(f"{name}: {len(svg) // 1024} KB")


def draw_mech(s, x, gy):
    """玩家剪影（画布半比例 36x52≈世界 72x104），给效果图一个比例锚。"""
    ink = "#1d2024"
    s.poly([(x - 8, gy - 32), (x + 10, gy - 36), (x + 12, gy - 18), (x - 7, gy - 14)], "#2e3238")
    s.poly([(x - 10, gy - 42), (x + 8, gy - 46), (x + 9, gy - 33), (x - 9, gy - 29)], ink)
    s.poly([(x + 3, gy - 48), (x + 10, gy - 47), (x + 10, gy - 42), (x + 3, gy - 43)], ink)
    s.circle(x + 8, gy - 45, 1.1, "#ffa04a", 0.95)
    s.line(x + 4, gy - 26, x + 15, gy - 22, ink, 3.0)
    s.line(x + 15, gy - 22, x + 15, gy - 18, ink, 2.4)
    s.line(x - 3, gy - 14, x - 8, gy - 5, "#26292e", 3.8)
    s.line(x - 8, gy - 5, x - 1, gy - 1, "#26292e", 3.4)
    s.line(x + 4, gy - 14, x + 2, gy - 5, "#26292e", 3.8)
    s.line(x + 2, gy - 5, x + 9, gy - 1, "#26292e", 3.4)


def far_rust(s, rng):
    for bx, bw, bh in ((-20, 130, 120), (150, 90, 170), (260, 150, 90), (620, 110, 150),
                       (760, 80, 100), (900, 150, 130), (1080, 120, 90)):
        s.poly([(bx, 334), (bx, 334 - bh), (bx + bw, 334 - bh + rng.uniform(-14, 6)),
                (bx + bw, 334)], "#857a5e", 0.42)
    s.glow_ellipse(830, 150, 95, 78, "#eadfb0", 0.22)
    haze = s.vgrad([(0, "#cabb8e", 0.0), (0.5, "#cabb8e", 0.32), (1, "#cabb8e", 0.0)])
    s.rect(0, 210, W, 126, haze)


def far_snow(s, rng):
    ridge = [(0, 336)]
    rx = 0.0
    while rx < W:
        rx += rng.uniform(90, 160)
        ridge.append((rx, 336 - rng.uniform(18, 52)))
    ridge.append((W, 336))
    s.poly(ridge, "#c2d2db")
    tx = 690.0
    far = "#8ba0ab"
    s.line(tx - 18, 336, tx - 4, 120, far, 2.6, 0.75)
    s.line(tx + 18, 336, tx + 4, 120, far, 2.6, 0.75)
    s.rect(tx - 22, 140, 44, 4, far, 0.8)
    s.circle(tx, 104, 10, far, 0.85)
    s.circle(tx, 104, 3, far, 1.0)
    haze = s.vgrad([(0, "#dfe9ee", 0.0), (0.5, "#dfe9ee", 0.4), (1, "#dfe9ee", 0.0)])
    s.rect(0, 220, W, 120, haze)


MOCK_KEY = {"rust": "ch1_rust", "snow": "ch3_snow"}
FAR = {"rust": far_rust, "snow": far_snow}


def build_mock(key):
    s = Svg()
    rng = random.Random(42)
    sky_stops = ([(0, "#b3a37c", 1), (0.55, "#c9b88e", 1), (1, "#a2936f", 1)]
                 if key == "rust" else
                 [(0, "#d4e2ea", 1), (0.6, "#e9f1f5", 1), (1, "#f7fafb", 1)])
    sky = s.vgrad(sky_stops)
    s.rect(0, 0, W, H, sky)
    FAR[key](s, rng)
    gv.draw_ground(s, MOCK_KEY[key], bottom=H, k=1.0)
    draw_mech(s, 400, gv.TIER_Y[gv.SEQ[3]])  # 站在中段 t2 高台上
    s.save(f"terrain_{key}_mock.svg")


def build_anatomy(key):
    """解剖图 k=2：左=整块分层；右=掉档剖面（接触阴影/墙脚/雪檐）。"""
    gkey = MOCK_KEY[key]
    th = gv.THEMES[gkey]
    s = Svg(1200, 420)
    bg = {"rust": "#a89a74", "snow": "#b9cdd8"}[key]
    s.rect(0, 0, 1200, 420, bg)

    # 左：整块（世界 320 宽，k=2 → 640 画布宽；top=52）
    gv.draw_block(s, th, 40, 52, 320, 420, 2.0, 3)

    # 右：掉档剖面（高块 t2 顶 52 → 低块 t0 顶 52+128；k=2，与左面板留 40px 间隔）
    gv.draw_block(s, th, 720, 52, 120, 420, 2.0, 5, drop=2)
    gv.draw_block(s, th, 960, 180, 120, 420, 2.0, 6)
    sh = s.hgrad([(0, th["ao"], 0.55), (1, th["ao"], 0.0)])
    s.rect(960, 180 + 1.4 * 2, 72, 28 * 2 - 1.4 * 2, sh)   # 接触阴影
    gv.wall_foot(s, th, 960, 180, 2.0, random.Random(7), hi_top=52)
    s.save(f"terrain_{key}_anatomy.svg")


if __name__ == "__main__":
    build_mock("rust")
    build_mock("snow")
    build_anatomy("rust")
    build_anatomy("snow")
