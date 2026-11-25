# -*- coding: utf-8 -*-
"""BOSS 形态预览：旧机体 vs 新机体，按 tscn 节点位拼装（机体+挂件+举升焰+独眼），
无头 Chrome 截图出 PNG。用法：python preview.py <旧机体目录> <输出png>
  旧机体目录=放着旧 boss_*_body.svg 的目录（git show 导出），新机体读 units/。
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
S = 2  # 预览放大倍数


def url(p):
    return "file:///" + os.path.abspath(p).replace(os.sep, "/")


# 每章：body 名、挂件 [(svg, 左上画布坐标)]、举升焰画布中心、独眼画布中心（旧/新）、底色
CH = {
    6: dict(body="boss_red_body.svg", bg="#d9b48a",
            parts=[("assets/world_6/boss_red_wheel.svg", (-16, 60)),
                   ("assets/world_6/boss_red_rack.svg", (180, -12))],
            flames_old=[(120, 154), (230, 154)], flames_new=[(120, 154), (230, 154)],
            eye_old=(55, 63), eye_new=(95, 60), tint="rgba(255,190,115,.6)"),
    8: dict(body="boss_salt_body.svg", bg="#d8b48c",
            parts=[("assets/world_8/boss_salt_wing.svg", (72, 4))],
            flames_old=[(110, 156), (210, 156)], flames_new=[(114, 160), (206, 160)],
            eye_old=(55, 63), eye_new=(69, 90), tint="rgba(250,200,133,.6)"),
    9: dict(body="boss_storm_body.svg", bg="#8a8296",
            parts=[("assets/world_9/boss_storm_arm.svg", (72, 4))],
            flames_old=[(110, 156), (210, 156)], flames_new=[(110, 160), (190, 160)],
            eye_old=(55, 63), eye_new=(55, 63), tint="rgba(110,82,160,.6)"),
    10: dict(body="boss_sulfur_body.svg", bg="#a89a80",
             parts=[("assets/world_10/boss_sulfur_arm.svg", (72, 4))],
             flames_old=[(110, 156), (210, 156)], flames_new=[(110, 148), (210, 148)],
             eye_old=(55, 63), eye_new=(55, 63), tint="rgba(72,181,255,.6)"),
}


def unit(body_path, c, flames, eye):
    h = [f'<div class="u" style="background:{c["bg"]}">']
    h.append(f'<img style="left:{0}px;top:{0}px;width:{300*S}px" src="{url(body_path)}">')
    for p, (x, y) in c["parts"]:
        h.append(f'<img class="part" style="left:{x*S}px;top:{y*S}px" data-s="{S}" src="{url(os.path.join(ROOT, p))}">')
    for fx, fy in flames:
        w = 32 * 1.1 * S
        h.append(f'<img style="left:{fx*S-w/2}px;top:{fy*S-w/2}px;width:{w}px;'
                 f'filter:drop-shadow(0 0 0 {c["tint"]});opacity:.8;mix-blend-mode:screen" '
                 f'src="{url(os.path.join(ROOT, "assets/common/fx_flame.svg"))}">')
    ex, ey = eye
    h.append(f'<div class="eye" style="left:{(ex-26)*S}px;top:{(ey-2)*S}px;width:{52*S}px;height:{4*S}px"></div>')
    h.append(f'<div class="box" style="left:{10*S}px;top:{15*S}px;width:{280*S}px;height:{150*S}px"></div>')
    h.append("</div>")
    return "".join(h)


def main(old_dir, out_png):
    rows = []
    for ch, c in CH.items():
        old = unit(os.path.join(old_dir, c["body"]), c, c["flames_old"], c["eye_old"])
        new = unit(os.path.join(HERE, "units", c["body"]), c, c["flames_new"], c["eye_new"])
        rows.append(f'<div class="r"><b>{ch}</b>{old}{new}</div>')
    html = f"""<html><head><style>
body{{margin:0;background:#222;font:20px sans-serif;color:#eee}}
.r{{display:flex;align-items:center;gap:16px;padding:8px}}
.r b{{width:36px;text-align:center}}
.u{{position:relative;width:{340*S}px;height:{200*S}px;overflow:visible}}
.u>*{{position:absolute;transform:translate({20*S}px,{10*S}px)}}
.eye{{background:radial-gradient(ellipse,rgba(255,220,180,1) 0,rgba(255,82,64,.9) 30%,rgba(255,82,64,0) 70%);mix-blend-mode:screen}}
.box{{border:1px dashed rgba(0,0,0,.35)}}
</style><script>
window.onload=()=>{{for(const i of document.querySelectorAll('img.part')){{i.style.width=(i.naturalWidth*{S})+'px'}}}}
</script></head><body>{''.join(rows)}</body></html>"""
    hp = os.path.join(HERE, "_preview.html")
    with open(hp, "w", encoding="utf-8") as fp:
        fp.write(html)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--allow-file-access-from-files",
                    "--virtual-time-budget=2000", f"--window-size={36+16*3+340*S*2+40},{(200*S+16)*4+20}",
                    f"--screenshot={os.path.abspath(out_png)}", url(hp)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("OK", out_png)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
