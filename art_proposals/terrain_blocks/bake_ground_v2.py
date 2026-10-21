# -*- coding: utf-8 -*-
"""拆地块 v2 实机纹理烘焙：四章 640×66 双变体表面带 + 16×256 立面渐变。

覆盖 assets/ 下原文件名（env_<ch>_ground_top.svg / env_<ch>_ground_fill.svg），
main*/Terrain 的 @export 引用不变。几何=世界比例（k=2 的 ground_v2 语言）：

表面带 640×66（左右各一个 320 变体，terrain.gd 按块序号奇偶取半幅）：
  y 0..2.5   顶缘亮线
  y 2.5..56  走道带（每变体一套花：裂缝/补丁/板缝铆钉/车辙雪斑/辉光短划…）
  y 56..66   立面 AO 渐隐（带正下投影，terrain.gd 的立面从 66 起）
  接缝烘在 x=0/320/640 竖缝
立面 16×256：face_hi→face_lo 渐变（0.42 处到位）+ 4 条层理横线
  （纹理被 sprite 拉伸到 320×634，横线自然成为通长层理）。
"""
import os
import random

from gen_terrain_mock import Svg
import ground_v2 as gv

ASSETS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets"))

CHAPTERS = {
    # ch -> (主题 key, 资产子目录)。2026-10-21 资产分层：assets/world_1..4
    # （同日早些时候曾是 ch1..ch4，用户又改名 world_N——跟目录现状走）
    "rust": ("ch1_rust", "world_1"),
    "ref": ("ch2_ref", "world_2"),
    "snow": ("ch3_snow", "world_3"),
    "coral": ("ch4_coral", "world_4"),
}


def bake_band(ch_key, th):
    s = Svg(640, 66)
    # 走道带底色（全幅）
    s.rect(0, 2.5, 640, 53.5, th["band"])
    # 两个变体各取一套花（种子固定，重跑恒等）
    for half, seed in ((0, 3111), (1, 3222)):
        gv.band_detail(s, th, half * 320.0, 0.0, 320.0, 56.0, 2.0, random.Random(seed))
    # 带底转折
    s.rect(0, 53.6, 640, 2.4, th["band_edge"])
    # 顶缘亮线
    s.rect(0, 0, 640, 2.8, th["top_line"])
    # 块间缝（x=0/320/640 竖缝，纹理边缘各留对称半缝）
    for xc in (0.0, 320.0, 640.0):
        s.rect(xc - 1.2, 2.5, 2.4, 63.5, th["seam"], 0.55)
    # 立面 AO 渐隐——必须垫不透明的立面亮色底：这段在纹理里是半透明渐变，
    # 而 fill 精灵从 y=66 才开始，背后没有东西会直接透出天空（高档位地块
    # 背后是亮天空=漏光，2026-10-21 用户抓）。垫 face_hi 后与立面顶端无缝。
    s.rect(0, 56, 640, 10, th["face_hi"])
    ao = s.vgrad([(0, th["ao"], 0.8), (1, th["ao"], 0.0)])
    s.rect(0, 56, 640, 10, ao)
    return s.to_text()


def bake_fill(th):
    s = Svg(16, 256)
    body = s.vgrad([(0, th["face_hi"], 1), (0.42, th["face_lo"], 1), (1, th["face_lo"], 1)])
    s.rect(0, 0, 16, 256, body)
    # 层理横线：纹理拉伸后落在世界 y≈88/136/200/280（块顶起算），透明度衰减
    for ty, op in ((9, 0.42), (28, 0.31), (54, 0.2), (86, 0.12)):
        s.rect(0, ty, 16, 1, th["strata"], op)
    return s.to_text()


def main():
    for ch, (key, sub) in CHAPTERS.items():
        th = gv.THEMES[key]
        band_p = os.path.join(ASSETS, sub, f"env_{ch}_ground_top.svg")
        fill_p = os.path.join(ASSETS, sub, f"env_{ch}_ground_fill.svg")
        for p, text in ((band_p, bake_band(key, th)), (fill_p, bake_fill(th))):
            with open(p, "w", encoding="utf-8") as fp:
                fp.write(text)
            print("OK", os.path.relpath(p, ASSETS), f"{len(text) // 1024} KB")


if __name__ == "__main__":
    main()
