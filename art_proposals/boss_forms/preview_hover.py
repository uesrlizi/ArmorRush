# -*- coding: utf-8 -*-
"""悬浮推进预览：八台 BOSS 全表火箭焰（2026-11-11 八轮定案）。
拼装=机体+挂件+举升焰（含截击机冲撞期点火示意），按 tscn 节点局部坐标+画布
原点换算；灰度焰做 modulate 染色近似（RGB 乘法，与引擎一致）。
无头 Chrome 出 PNG。用法：python preview_hover.py [输出png]
最终以引擎实机为准（闪燃/速度拉长/增推 boost 是动态的，图为静态中位）。"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
TINT = os.path.join(HERE, "_tint")
S = 1.6  # 预览放大倍数


def url(p):
    return "file:///" + os.path.abspath(p).replace(os.sep, "/")


def mul(hexcol, rgb):
    r = int(hexcol[1:3], 16) * rgb[0]
    g = int(hexcol[3:5], 16) * rgb[1]
    b = int(hexcol[5:7], 16) * rgb[2]
    return "#%02x%02x%02x" % (min(255, int(r)), min(255, int(g)), min(255, int(b)))


def tinted(src, rgb, tag):
    os.makedirs(TINT, exist_ok=True)
    text = open(os.path.join(ROOT, src), encoding="utf-8").read()
    text = re.sub(r'fill="(#[0-9a-fA-F]{6})"',
                  lambda m: 'fill="' + mul(m.group(1), rgb) + '"', text)
    out = os.path.join(TINT, f"{tag}.svg")
    with open(out, "w", encoding="utf-8") as fp:
        fp.write(text)
    return url(out)


# 每台：章名、机体（bw=画布宽，原点=画布中心）、挂件[(路径,画布左上)]、独眼、
# 焰[局部](x,y,旋转deg)（thruster_flame 贴图 scale1.1，焰根=节点上方 26×1.1）、
# 焰色、行底色、备注
ORIGIN = {2: (150, 90), 3: (130, 90), 5: (150, 90), 6: (150, 90),
          7: (150, 90), 8: (150, 90), 9: (150, 90), 10: (150, 90)}
BOSSES = [
    dict(ch=2, name="浮堡·冶炼驳船", body="assets/world_2/boss_ref_body.svg", bw=300,
         parts=[], eye=(55, 63),
         flames=[(-55, 56, 0), (55, 56, 0)], flame_rgb=(0.55, 0.72, 0.85),
         bg="#3a4550", note="船底双钢青焰（新换装；风扇装饰件已废）"),
    dict(ch=3, name="哨兵·悬空机甲", body="assets/world_3/boss_snow_body.svg", bw=260,
         parts=[], eye=(70, 58),
         flames=[(-22, 104, 0), (22, 104, 0)], flame_rgb=(0.28, 0.71, 1),
         bg="#56606e", note="底舱双喷口朝下（新；倒飞为主，尾部平射不合理）"),
    dict(ch=5, name="断云·高空截击机", body="assets/world_5/boss_dawn_body.svg", bw=300,
         parts=[], eye=(55, 63),
         flames=[(165, -4, -90), (165, 16, -90)], flame_rgb=(1, 0.72, 0.4),
         bg="#8a94a8", note="尾焰仅冲撞期点火（示意；平时熄火飘行，前摇即开）"),
    dict(ch=6, name="赤轮·斗轮挖掘机", body="assets/world_6/boss_red_body.svg", bw=300,
         parts=[("assets/world_6/boss_red_wheel.svg", (-16, 60)),
                ("assets/world_6/boss_red_rack.svg", (180, -12))], eye=(95, 60),
         flames=[(-30, 59, 0), (80, 59, 0)], flame_rgb=(1, 0.75, 0.45),
         bg="#c98d5e", note="底盘双矿灯金焰（新换装）"),
    dict(ch=7, name="沉锚·打捞巡防舰", body="assets/world_7/boss_sea_body.svg", bw=300,
         parts=[], eye=(55, 63),
         flames=[(-40, 95, 0), (60, 95, 0)], flame_rgb=(0.62, 0.95, 0.92),
         bg="#8fb8b2", note="海喷白青举升焰（焰形重做=平根锥）"),
    dict(ch=8, name="盐磨·聚光镜碟", body="assets/world_8/boss_salt_body.svg", bw=300,
         parts=[("assets/world_8/boss_salt_wing.svg", (72, 4))], eye=(69, 90),
         flames=[(-36, 96, 0), (56, 96, 0)], flame_rgb=(0.98, 0.78, 0.52),
         bg="#dca878", note="杏金蒸汽举升焰（焰形重做=平根锥）"),
    dict(ch=9, name="引雷·浮空电塔", body="assets/world_9/boss_storm_body.svg", bw=300,
         parts=[], eye=(55, 63),
         flames=[(-40, 62, 0), (40, 62, 0)], flame_rgb=(0.58, 0.42, 0.85),
         bg="#3a3346", note="座裙双电紫焰（新换装；三叶桨装饰件已废）"),
    dict(ch=10, name="井口·钻井平台", body="assets/world_10/boss_sulfur_body.svg", bw=300,
         parts=[("assets/world_10/boss_sulfur_arm.svg", (72, 4))], eye=(55, 63),
         flames=[(-40, 82, 0), (60, 82, 0)], flame_rgb=(0.28, 0.71, 1),
         bg="#a89a80", note="硫焰蓝举升焰（焰形重做=平根锥）"),
]

UW, UH = 352, 244  # 单元画布（宽留 ch5 尾焰伸出量；机体仍按 bw 居中）


def unit(c):
    ox, oy = ORIGIN[c["ch"]]
    bx = (300 - c["bw"]) / 2.0  # 机体画布在 300 单元里的左偏（ch3=20，其余 0）

    def px(cx_canvas):
        return (bx + cx_canvas) * S
    h = [f'<div class="u" style="background:{c["bg"]}">']
    h.append(f'<img class="p" style="left:{bx*S}px;top:0;width:{c["bw"]*S}px" '
             f'src="{url(os.path.join(ROOT, c["body"]))}">')
    for p, (x, y) in c["parts"]:
        h.append(f'<img class="part" style="left:{x*S}px;top:{y*S}px" '
                 f'src="{url(os.path.join(ROOT, p))}">')
    ex, ey = c["eye"]
    h.append(f'<div class="eye" style="left:{px(ex)-26*S}px;top:{ey*S-2*S}px;'
             f'width:{52*S}px;height:{4*S}px"></div>')
    t = tinted("assets/common/thruster_flame.svg", c["flame_rgb"], f"f{c['ch']}")
    for fx, fy, r in c["flames"]:
        cx, cy = px(ox + fx), (oy + fy) * S
        # 节点=喷口（原点=焰根）：贴图 40x64×1.1=44x70，喷口 (20,6)→img (22,6.6)
        h.append(f'<img style="left:{cx-22*S}px;top:{cy-6.6*S}px;width:{44*S}px;height:{70*S}px;'
                 f'transform-origin:{22*S}px {6.6*S}px;'
                 f'transform:rotate({r}deg);opacity:.72;mix-blend-mode:screen" src="{t}">')
    h.append("</div>")
    return "".join(h)


def main(out_png):
    cells = []
    for c in BOSSES:
        cells.append(f'<div class="cell">'
                     f'<div class="cap">ch{c["ch"]} {c["name"]} — {c["note"]}</div>'
                     f'{unit(c)}</div>')
    cols = 2
    rows = (len(cells) + cols - 1) // cols
    cw = UW * S + 8
    ch_ = UH * S + 44
    js = ("window.onload=()=>{for(const i of document.querySelectorAll('img.part')){"
          "i.style.width=(i.naturalWidth*" + str(S) + ")+'px'}}")
    css = (
        "body{margin:0;background:#1c2026;font:14px sans-serif;color:#d8dde4}"
        f".grid{{display:grid;grid-template-columns:repeat({cols},max-content);gap:10px 14px;padding:10px}}"
        f".cell{{width:{int(cw)}px}}"
        ".cap{padding:2px 4px;color:#9fb2c0}"
        f".u{{position:relative;width:{int(UW*S)}px;height:{int(UH*S)}px;overflow:hidden;border-radius:3px}}"
        ".u>img{position:absolute}"
        ".eye{background:radial-gradient(ellipse,rgba(255,220,180,1) 0,rgba(255,82,64,.9) 30%,rgba(255,82,64,0) 70%);mix-blend-mode:screen}"
    )
    html = ("<html><head><meta charset='utf-8'><style>" + css + "</style><script>" + js
            + "</script></head><body><div class='grid'>" + "".join(cells)
            + "</div></body></html>")
    hp = os.path.join(HERE, "_preview_hover.html")
    with open(hp, "w", encoding="utf-8") as fp:
        fp.write(html)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--allow-file-access-from-files",
                    "--virtual-time-budget=2000",
                    f"--window-size={int(cw*cols+38)},{int(ch_*rows+24)}",
                    f"--screenshot={os.path.abspath(out_png)}", url(hp)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("OK", out_png)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "boss_hover_preview.png")
    main(out)
