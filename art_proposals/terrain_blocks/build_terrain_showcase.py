# -*- coding: utf-8 -*-
"""拼装拆地块重做提案效果图：整视图 + 解剖标注图 → 每章一张 showcase PNG。"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "render")
OUT = os.path.dirname(os.path.abspath(__file__))
FONT = "C:/Windows/Fonts/msyh.ttc"
BG = (16, 18, 22)
FG = (232, 236, 242)
GREY = (154, 162, 173)


def F(size):
    return ImageFont.truetype(FONT, size)


SCENES = {
    "rust": {
        "title": "拆地块重做提案 · 一 锈雨废都",
        "notes": "材质语言：沥青走道带（裂缝/补丁/碎石，每块独立取花）+ 土层断面（层理/竖裂缝/露头钢筋）+ 墙脚瓦砾；"
                 "深色立面保 HUD 底衬。",
        "palette": [("#7a7462", "顶缘亮"), ("#4a473e", "走道带"), ("#46433a", "立面亮端"),
                    ("#2b2921", "立面深处"), ("#6a5a48", "钢筋锈")],
        "labels": [  # (文字, 文本位, 指点位)
            ("顶缘亮线", (410, 20), (360, 54)),
            ("走道带：每块独立取花，无平铺重复感", (60, 118), (240, 84)),
            ("带底转折线", (585, 88), (520, 107)),
            ("立面 AO：带正下投影渐隐（立体感主来源）", (585, 130), (620, 112)),
            ("层理：间距渐疏、透明度渐衰减", (620, 200), (560, 155)),
            ("剖面细节：露头钢筋", (60, 158), (300, 136)),
            ("块间缝：上密下疏，读作人工分板", (585, 260), (680, 215)),
            ("深层渐变压暗（HUD 底衬）", (60, 360), (220, 350)),
            ("掉档：墙面全露=剖面主秀场", (700, 330), (800, 140)),
            ("接触阴影 36px 渐隐", (1030, 230), (1000, 192)),
            ("墙脚瓦砾", (1075, 150), (990, 174)),
        ],
    },
    "snow": {
        "title": "拆地块重做提案 · 三 雪原警戒点",
        "notes": "材质语言：深色路板搁在亮雪断面上（对齐现役雪章亮地面）——雪檐受光顶缘/车辙+黄虚线+雪斑走道带/"
                 "雪层理+冰脉断面/墙脚雪堆+掉档处雪檐悬挑。",
        "palette": [("#f7fafb", "雪檐亮缘"), ("#56626c", "路板"), ("#dfe7ec", "雪断面亮端"),
                    ("#b3c5d1", "雪断面深处"), ("#5f6f7a", "投影")],
        "labels": [
            ("雪檐受光顶缘", (410, 20), (360, 54)),
            ("路板走道带：车辙+中线黄虚线+雪斑", (60, 118), (240, 84)),
            ("路板底转折", (585, 88), (520, 107)),
            ("路板投在雪断面上的 AO", (585, 130), (620, 112)),
            ("雪层理（淡，随深度衰减）", (620, 200), (560, 155)),
            ("断面冰脉", (60, 158), (300, 136)),
            ("块间缝（雪面读作冰缝）", (585, 260), (680, 215)),
            ("雪断面深处渐变", (60, 360), (220, 350)),
            ("掉档：雪断面全露", (700, 330), (800, 140)),
            ("雪檐沿墙角悬挑", (1075, 40), (958, 56)),
            ("接触阴影", (1030, 230), (1000, 192)),
            ("墙脚雪堆", (1075, 150), (1000, 176)),
        ],
    },
}

M = 20
IMG_W, H1, H2 = 1200, 540, 420
TITLE_H, GAP, NOTES_H = 46, 12, 64
CW, CH = IMG_W + M * 2, TITLE_H + H1 + GAP + H2 + NOTES_H

for key, sc in SCENES.items():
    img = Image.new("RGB", (CW, CH), BG)
    d = ImageDraw.Draw(img)
    d.text((M, 12), sc["title"], font=F(24), fill=FG)
    d.text((CW - 620, 18), "实机几何：块宽 320 · 档差 64 · 三档 536/600/664 · 同高连续 2~4 块",
           font=F(15), fill=GREY)
    mock = Image.open(os.path.join(HERE, f"terrain_{key}_mock.png"))
    img.paste(mock, (M, TITLE_H))
    anat = Image.open(os.path.join(HERE, f"terrain_{key}_anatomy.png"))
    y2 = TITLE_H + H1 + GAP
    img.paste(anat, (M, y2))

    # 解剖标注（白字带深描边，亮暗底都可读）
    f_lab = F(15)
    for text, (tx, ty), (px, py) in sc["labels"]:
        ax, ay = M + tx, y2 + ty
        bx, by = M + px, y2 + py
        d.line((ax + 4, ay + 8, bx, by), fill=(240, 240, 240), width=1)
        d.ellipse((bx - 2.5, by - 2.5, bx + 2.5, by + 2.5), fill=(255, 210, 120),
                  outline=(40, 40, 40))
        d.text((ax, ay), text, font=f_lab, fill=(255, 255, 255),
               stroke_width=2, stroke_fill=(30, 32, 36))

    # 底注 + 调色板
    ny = y2 + H2 + 8
    d.text((M, ny), sc["notes"], font=F(15), fill=GREY)
    cx = M
    for c, name in sc["palette"]:
        d.rounded_rectangle((cx, ny + 26, cx + 16, ny + 42), 3, fill=c, outline=(70, 76, 86))
        d.text((cx + 22, ny + 28), f"{name} {c}", font=F(13), fill=GREY)
        cx += 22 + 13 * (len(name) + len(c)) + 18

    out = os.path.join(OUT, f"terrain_{key}_showcase.png")
    img.save(out)
    print("OK", out, img.size)
