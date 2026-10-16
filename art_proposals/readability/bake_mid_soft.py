# -*- coding: utf-8 -*-
"""烘焙 env_rust_mid_soft.svg：中景钠灯橙降饱和（可读性提案 P3 的「强调色让位」变体）。

理由：玩家机甲的强调橙 #ffa04a 与中景钠灯 #ffa04a 同值，全场唯一识别色被场景吃掉。
本变体把中景橙降到低饱和旧灯色，纯橙让位给玩家；原 env_rust_mid.svg 不动。
"""
import colorsys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "env_rust_mid.svg"
DST = ROOT / "assets" / "env_rust_mid_soft.svg"


def hsl_to_hex(h: float, s: float, l: float) -> str:
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def hsl_of(hexcolor: str) -> tuple:
    r, g, b = (int(hexcolor[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h, s, l


# 亮橙 #ffa04a → 同色相降饱和降明度；深一点的高温橙同理。
h, s, l = hsl_of("#ffa04a")
SOFT_MAIN = hsl_to_hex(h, 0.52, min(l, 0.52))
h2, s2, l2 = hsl_of("#ff8c3a")
SOFT_DEEP = hsl_to_hex(h2, 0.50, min(l2, 0.46))

text = SRC.read_text(encoding="utf-8")
n1 = text.count("#ffa04a")
n2 = text.count("#ff8c3a")
text = text.replace("#ffa04a", SOFT_MAIN).replace("#ff8c3a", SOFT_DEEP)

note = ("<!-- 变体：env_rust_mid_soft（readability P3 提案）。由 bake_mid_soft.py 生成，\n"
        "     钠灯橙 #%s→%s ×%d、#%s→%s ×%d。纯橙让位给玩家机甲。原文件不动。-->\n"
        % ("ffa04a", SOFT_MAIN[1:], n1, "ff8c3a", SOFT_DEEP[1:], n2))
text = text.replace(">\n", ">\n" + note, 1)

DST.write_text(text, encoding="utf-8")
print("baked %s  (%d x #ffa04a -> %s, %d x #ff8c3a -> %s)"
      % (DST.name, n1, SOFT_MAIN, n2, SOFT_DEEP))
