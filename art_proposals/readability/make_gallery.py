# -*- coding: utf-8 -*-
"""可读性提案图后处理：以游戏真渲染的 P0/P2 为底，用与 Godot 相同的 alpha 混合公式
确定性合成 P1（雾）与 P3（雾+橙让位），拼 2x2 对比图与明度带图，生成 gallery.html。

混合公式与 readability_preview.gd 一致：out = src*(1-a) + fog*a，fog=#b3a97f，
梯度 (0,0.28)→(0.55,0.45)→(1.0,0.58)，作用域 far+mid（画面顶部到地表带顶边），
前景（地块/箱子/角色下半）不入雾。"""
import pathlib
from PIL import Image, ImageChops, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
SHOTS = ROOT / "autotest_shots"
OUT = ROOT / "art_proposals" / "readability"

FOG = (0xB3, 0xA9, 0x7F)          # 天色雾
STOPS = [(0.0, 0.28), (0.55, 0.45), (1.0, 0.58)]
ORANGE_MAP = {                     # 中景钠灯降饱和（与 bake_mid_soft.py 同值）
    (0xFF, 0xA0, 0x4A): (0xC4, 0x81, 0x45),
    (0xFF, 0x8C, 0x3A): (0xB0, 0x6B, 0x3B),
}
# 渐变世界坐标（y -40..1300、相机 y=540、视口 1080 高）按实际图高换算：
# 画面 y = 世界 y - CAMERA_Y + H/2，渐变原点（世界 -540）→ 画面 y = -H*0.5+40*(H/1080)
GRAD_TOP_PX = -500.0               # 世界 -540 → 画面 -500（H=1080 基准）
GRAD_H = 1840.0                    # 世界高度
RIM = (255, 227, 179)              # outline_rim.gdshader 默认暖白，玩家定位锚


def _scale(img_h: int) -> float:
    return img_h / 1080.0


def fog_alpha(y: float, img_h: int) -> float:
    s = _scale(img_h)
    p = (y - (GRAD_TOP_PX * s)) / (GRAD_H * s)
    p = max(0.0, min(1.0, p))
    for (p0, a0), (p1, a1) in zip(STOPS, STOPS[1:]):
        if p <= p1:
            return a0 + (a1 - a0) * (p - p0) / (p1 - p0)
    return STOPS[-1][1]


def detect_ground_line(img: Image.Image) -> int:
    """扫描行均值找地表带顶边（前景暗色大块的上沿）。"""
    g = img.convert("L")
    w, h = g.size
    px = g.load()
    prev = None
    best, best_y = 0.0, int(h * 0.55)
    for y in range(int(h * 0.5), int(h * 0.75)):
        s = 0
        for x in range(200, w - 200, 16):
            s += px[x, y]
        mean = s / len(range(200, w - 200, 16))
        if prev is not None:
            drop = prev - mean
            if drop > best:
                best, best_y = drop, y
        prev = mean
    return best_y


def apply_fog(base: Image.Image, ground_y: int) -> Image.Image:
    w, h = base.size
    mask = Image.new("L", (1, h))
    for y in range(h):
        a = fog_alpha(y, h) if y <= ground_y else 0.0
        mask.putpixel((0, y), round(a * 255))
    mask = mask.resize((w, h))
    fog_layer = Image.new("RGB", (w, h), FOG)
    return Image.composite(fog_layer, base, mask)


def find_player_box(img: Image.Image, ground_y: int) -> tuple:
    """用 P2 独有的 rim 亮色在画面左半、地表带附近定位玩家，返回扩边排除框。"""
    w, h = img.size
    region = img.crop((0, max(0, ground_y - 160), w // 2, ground_y + 8))
    px = region.load()
    xs, ys = [], []
    for yy in range(region.size[1]):
        for xx in range(region.size[0]):
            r, g, b = px[xx, yy][:3]
            if r > 238 and 200 < g < 245 and 150 < b < 205:
                xs.append(xx)
                ys.append(yy)
    if not xs:
        return (0, 0, 0, 0)
    x0, x1 = min(xs), max(xs)
    y0, y1 = min(ys) + max(0, ground_y - 160), max(ys) + max(0, ground_y - 160)
    pad = 30
    return (max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad), min(h, y1 + pad))


def apply_orange_soft(base: Image.Image, keep_box: tuple) -> Image.Image:
    """把中景钠灯橙替换为降饱和色；keep_box（玩家）内不动。"""
    w, h = base.size
    out = base
    for src, dst in ORANGE_MAP.items():
        r, gg, b = out.convert("RGB").split()
        # 收紧容差：天空/远楼受光面 r≤200、b≥127，都会误触发宽松阈值。
        m_r = r.point(lambda v: 255 if v > 235 else 0)
        m_g = gg.point(lambda v: 255 if 110 < v < 205 else 0)
        m_b = b.point(lambda v: 255 if v < 120 else 0)
        mask = ImageChops.multiply(ImageChops.multiply(m_r, m_g), m_b)
        exclude = Image.new("L", (w, h), 255)
        ImageDraw.Draw(exclude).rectangle(keep_box, fill=0)
        mask = ImageChops.multiply(mask, exclude)
        solid = Image.new("RGB", (w, h), dst)
        out = Image.composite(solid, out, mask)
    return out


def label(img: Image.Image, text: str) -> Image.Image:
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 460, 56], fill=(20, 20, 18))
    d.text((18, 14), text, fill=(240, 235, 220))
    return img


def main() -> None:
    p0 = Image.open(SHOTS / "readability_p0.png").convert("RGB")
    p2 = Image.open(SHOTS / "readability_p2.png").convert("RGB")
    ground_y = detect_ground_line(p0)
    keep = find_player_box(p2, ground_y)
    print("ground line at y =", ground_y, "| player keep box =", keep)

    p1 = apply_fog(p0.copy(), ground_y)
    p3 = apply_fog(apply_orange_soft(p2.copy(), keep), ground_y)

    p0.save(SHOTS / "readability_p0.png")
    p1.save(SHOTS / "readability_p1.png")
    p3.save(SHOTS / "readability_p3.png")
    print("p1/p3 composited, p0/p2 kept from engine render")

    # ---- 2x2 对比图 ----
    tw = p0.resize((1200, 540))
    grid = Image.new("RGB", (2400, 1080 + 2 * 34), (12, 12, 12))
    cells = [
        (tw, "P0  baseline (current)"),
        (p1.resize((1200, 540)), "P1  aerial fog on far+mid"),
        (p2.resize((1200, 540)), "P2  rim light + contact shadow"),
        (p3.resize((1200, 540)), "P3  = P1 + P2 + scene orange yields"),
    ]
    d = ImageDraw.Draw(grid)
    for i, (im, cap) in enumerate(cells):
        x, y = (i % 2) * 1200, (i // 2) * (540 + 34)
        grid.paste(im, (x, y))
        d.rectangle([x, y + 540, x + 1200, y + 574], fill=(24, 24, 22))
        d.text((x + 14, y + 548), cap, fill=(235, 230, 214))
    grid.save(OUT / "compare_grid.png")
    print("saved compare_grid.png")


if __name__ == "__main__":
    main()
