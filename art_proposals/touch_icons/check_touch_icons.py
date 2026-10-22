# -*- coding: utf-8 -*-
"""触控图标 PIL 代用光栅自检（编辑器在线铁律阻塞引擎光栅期间的代用，同 check_sentinel 先例）：
解析 work/ 下四张 SVG（circle/rect/line/path 的 M-L-Q-Z 平涂原语，round cap 线）按文档序渲染，
跑像素断言（包盒/缝隙/单色性/关键点），最后拼 showcase.png（旧版行 vs 新版行+按钮底板模拟）。
覆盖不了 ThorVG 抗锯齿差异——定稿仍要编辑器离线后补跑 Godot 光栅（raster_svg.gd）。"""
import os
import re

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "work")
OLD = os.path.join(HERE, "render")
SCALE = 4
PLATE = (26, 33, 43)  # 按钮底板模拟色（touch_button.gd base_color 提亮档， showcase 垫底用）


def flatten_quad(p0, p1, p2, n=16):
    pts = []
    for i in range(1, n + 1):
        t = i / n
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        pts.append((x, y))
    return pts


def parse_path(d):
    """M/L/Q/Z 路径 → 多段折线（Q 展平）。返回 [(points, closed), ...]"""
    tokens = re.findall(r"([MLQZ])([^MLQZ]*)", d)
    subs, cur, start, closed = [], [], None, False
    for cmd, body in tokens:
        nums = [float(v) for v in re.findall(r"-?\d+\.?\d*", body)]
        if cmd == "M":
            if cur:
                subs.append((cur, False))
            cur = [tuple(nums[0:2])]
            start = cur[0]
            pts = [tuple(nums[i:i + 2]) for i in range(2, len(nums), 2)]
            cur += pts
        elif cmd == "L":
            cur += [tuple(nums[i:i + 2]) for i in range(0, len(nums), 2)]
        elif cmd == "Q":
            for i in range(0, len(nums), 4):
                cur += flatten_quad(cur[-1], tuple(nums[i:i + 2]),
                                    tuple(nums[i + 2:i + 4]))[1:]
        elif cmd == "Z":
            closed = True
            if cur and start is not None:
                cur.append(start)
    if cur:
        subs.append((cur, closed))
    return subs


def render_svg(path):
    src = open(path, encoding="utf-8").read()
    img = Image.new("RGBA", (240 * SCALE, 240 * SCALE), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img, "RGBA")
    for tag, body in re.findall(r"<(circle|rect|line|path|g)\b([^>]*?)/?>", src):
        if tag == "g":
            continue
        a = dict(re.findall(r'([\w-]+)="([^"]*)"', body))
        op = float(a["opacity"]) if "opacity" in a else 1.0
        white = (255, 255, 255, int(255 * op))
        s = SCALE
        if tag == "circle":
            cx, cy, r = float(a["cx"]) * s, float(a["cy"]) * s, float(a["r"]) * s
            dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=white)
        elif tag == "rect":
            x, y = float(a["x"]) * s, float(a["y"]) * s
            w, h = float(a["width"]) * s, float(a["height"]) * s
            dr.rectangle([x, y, x + w, y + h], fill=white)  # rx≈7 忽略（4x 下视觉差可忽略）
        elif tag == "line":
            p1 = (float(a["x1"]) * s, float(a["y1"]) * s)
            p2 = (float(a["x2"]) * s, float(a["y2"]) * s)
            w = int(float(a.get("stroke-width", 1)) * s)
            dr.line([p1, p2], fill=white, width=w)
            if a.get("stroke-linecap") == "round":
                r = w / 2
                for p in (p1, p2):
                    dr.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=white)
        elif tag == "path":
            d_attr = a.get("d", "")
            if "fill=\"none\"" in body or a.get("fill") == "none":
                w = int(float(a.get("stroke-width", 1)) * s)
                for pts, _closed in parse_path(d_attr):
                    pp = [(x * s, y * s) for x, y in pts]
                    dr.line(pp, fill=white, width=w,
                            joint="curve")
                    if a.get("stroke-linecap") == "round":
                        r = w / 2
                        for p in (pp[0], pp[-1]):
                            dr.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=white)
            else:
                for pts, closed in parse_path(d_attr):
                    pp = [(x * s, y * s) for x, y in pts]
                    if closed:
                        dr.polygon(pp, fill=white)
                    else:
                        dr.line(pp, fill=white, width=max(1, 2 * s))
    return img


def bbox_alpha(img):
    return img.getbbox()  # 非零 alpha 的包盒


def px(img, cx, cy):
    return img.getpixel((int(cx * SCALE), int(cy * SCALE)))


def main():
    icons = {name: render_svg(os.path.join(WORK, name + ".svg"))
             for name in ("ui_btn_melee_sword", "ui_btn_fire_cartridge",
                          "ui_btn_fire_pistol", "ui_btn_thrust_white")}

    # ---- 单色性断言：任何非透明像素必须纯白（r=g=b=255，透明度自由） ----
    for name, img in icons.items():
        for v in img.getdata():
            r, g, b, a = v
            if a > 0:
                assert r == 255 and g == 255 and b == 255, f"{name} 出现非白像素 {v}"
    print("mono OK: 四张全白无色相")

    # ---- 包盒账（画布单位，±4 容差） ----
    expect = {
        "ui_btn_melee_sword": (49, 52, 188, 191),
        "ui_btn_fire_cartridge": (53, 65, 176, 187),
        "ui_btn_fire_pistol": (42, 70, 196, 178),
        "ui_btn_thrust_white": (64, 30, 166, 206),
    }
    for name, img in icons.items():
        bb = tuple(v / SCALE for v in bbox_alpha(img))
        e = expect[name]
        ok = all(abs(bb[i] - e[i]) <= 4 for i in range(4))
        assert ok, f"{name} 包盒偏移: {bb} 期望 {e}"
        print(f"bbox OK {name}: ({bb[0]:.0f},{bb[1]:.0f})-({bb[2]:.0f},{bb[3]:.0f})")

    # ---- 剑：缝隙透底 + 关键件在位 ----
    sw = icons["ui_btn_melee_sword"]
    for label, cx, cy, want_on in (
            ("柄首", 59.2, 180.8, True), ("柄中", 78.2, 161.8, True),
            ("护手中", 91.0, 149.0, True), ("刃中", 131.7, 108.3, True),
            ("柄首|柄缝", 67.0, 173.0, False), ("护手|刃缝", 96.5, 143.5, False)):
        a = px(sw, cx, cy)[3]
        assert (a > 0) == want_on, f"剑 {label}@({cx},{cy}) alpha={a} 期望{'实' if want_on else '空'}"
    print("sword gaps OK: 首柄缝/护刃缝透底，四件在位")

    # ---- 弹壳：底缘/壳/弹头在位，壳口|弹底缝透底 ----
    ca = icons["ui_btn_fire_cartridge"]
    for label, cx, cy, want_on in (
            ("底缘", 70.2, 169.8, True), ("壳体", 92.4, 164.6, True),
            ("瓶肩", 113.0, 127.0, True), ("弹头", 134.9, 105.1, True),
            ("壳口|弹底缝", 127.1, 112.9, False)):
        a = px(ca, cx, cy)[3]
        assert (a > 0) == want_on, f"弹 {label}@({cx},{cy}) alpha={a}"
    print("cartridge gaps OK: 底缘/壳/弹头在位，口缝透底")

    # ---- 手枪：套筒/握把在位，护环内透底 ----
    pi = icons["ui_btn_fire_pistol"]
    for label, cx, cy, want_on in (
            ("套筒", 120, 91, True), ("握把", 70, 140, True),
            ("准星", 183, 74, True), ("护环内", 134, 146, False)):
        a = px(pi, cx, cy)[3]
        assert (a > 0) == want_on, f"枪 {label}@({cx},{cy}) alpha={a}"
    print("pistol OK: 套筒/握把/准星在位，护环内透底")

    # ---- 推进：双箭头 + 三档白透明度焰 ----
    th = icons["ui_btn_thrust_white"]
    assert px(th, 120, 40)[3] > 200, "箭头顶点缺失"
    assert px(th, 120, 66)[3] == 0, "双箭头带间应净空"
    a_in, a_mid, a_out = (px(th, 120, 166)[3], px(th, 120, 180)[3],
                          px(th, 120, 196)[3])
    assert a_in > 220 and 130 < a_mid < 200 and 80 < a_out < 140, \
        f"焰三档透明度账崩: in={a_in} mid={a_mid} out={a_out}"
    print(f"thrust OK: 箭头/净空/焰三档 in={a_in} mid={a_mid} out={a_out}")

    # ---- showcase：旧行（引擎光栅存档） vs 新行（PIL 渲染+按钮底板模拟） ----
    font = ImageFont.truetype(
        os.path.join(HERE, "..", "..", "tools", "ref_fonts", "NotoSansSC-Regular.otf"), 22)
    cell, pad, label_h = 240, 36, 44
    W = pad + cell * 4 + pad
    H = pad + 34 + cell + label_h + 26 + cell + label_h + pad
    sheet = Image.new("RGBA", (W, H), (16, 19, 28, 255))
    d = ImageDraw.Draw(sheet)
    d.text((pad, pad - 6), "触控图标 v2 · 纯白无色彩族（上=旧版存档 / 下=新版，底板=实机圆钮模拟）",
           font=font, fill=(230, 232, 240, 255))
    olds = [("旧·斩击 蓝弧", "ui_btn_melee.png"), ("旧·开火 黄弹", "ui_btn_fire.png"),
            ("旧·推进 橙焰", "ui_btn_thrust.png")]
    y_old = pad + 34
    for i, (label, fn) in enumerate(olds):
        x = pad + i * cell
        ic = Image.open(os.path.join(OLD, fn)).convert("RGBA").resize((cell, cell))
        sheet.paste(ic, (x, y_old), ic)
        d.text((x + cell // 2 - 60, y_old + cell + 8), label, font=font, fill=(150, 156, 170, 255))
    news = [("剑 · 斩击（接线）", "ui_btn_melee_sword"), ("弹壳 · 开火（推荐）", "ui_btn_fire_cartridge"),
            ("手枪 · 开火（备选）", "ui_btn_fire_pistol"), ("推进 · 白化（接线）", "ui_btn_thrust_white")]
    y_new = y_old + cell + label_h + 26
    for i, (label, key) in enumerate(news):
        x = pad + i * cell
        # 按钮底板模拟：r100 圆 + 亮缘（touch_button.gd 账）
        cx, cy, r = x + cell // 2, y_new + cell // 2, 100
        plate = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        pd = ImageDraw.Draw(plate)
        pd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=PLATE + (120,))
        pd.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, 40), width=2)
        sheet.paste(plate, (x, y_new), plate)
        ic = icons[key].resize((cell, cell), Image.NEAREST)
        sheet.paste(ic, (x, y_new), ic)
        d.text((x + cell // 2 - 70, y_new + cell + 8), label, font=font, fill=(230, 232, 240, 255))
    out = os.path.join(HERE, "showcase.png")
    sheet.save(out)
    print("saved", out, sheet.size)


if __name__ == "__main__":
    main()
