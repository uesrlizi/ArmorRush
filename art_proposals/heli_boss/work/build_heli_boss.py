# -*- coding: utf-8 -*-
# BOSS·大型武装直升机 提案 build：Godot 同源光栅 → 4× 组装 → showcase + PIL 自验
# 用法: python build_heli_boss.py   （在 art_proposals/heli_boss/work/ 下）
import os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = r'C:\Users\31715\Documents\GodotProject\2d-ac'
DIR  = os.path.join(ROOT, 'art_proposals', 'heli_boss')
WORK = os.path.join(DIR, 'work')
GODOT = r'C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
S = 4  # 光栅倍数（=游戏内 1:1 档 ×4 展示）

PIECE = {  # name: (svg, canvas w, h)
    'body':      ('heli_boss_body.svg', 340, 120),
    'rotor':     ('heli_boss_rotor.svg', 380, 56),
    'tailrotor': ('heli_boss_tailrotor.svg', 72, 72),
    'gun':       ('heli_boss_gun.svg', 104, 104),
}
ELITE = os.path.join(ROOT, 'assets', 'enemy_rust_elite_body.svg')  # 60×80 现役同框

# 组装账（body 画布坐标 → 各件画布 TL = 挂点 − pivot）
MOUNT = {  # piece: (挂点x, 挂点y, pivotx, pivoty)
    'rotor':     (156, 5, 190, 28),
    'tailrotor': (326, 66, 36, 36),
    'gun':       (36, 96, 52, 52),
}

def font(sz):
    for p in (r'C:\Windows\Fonts\msyh.ttc', r'C:\Windows\Fonts\simhei.ttf'):
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()

def raster(svg, out_png):
    r = subprocess.run([GODOT, '--headless', '--path', ROOT,
        '--script', 'res://art_proposals/raster_svg.gd', '--', svg, out_png, str(S)],
        capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(out_png):
        print(r.stdout, r.stderr); sys.exit('raster 失败: ' + svg)
    return Image.open(out_png).convert('RGBA')

os.makedirs(WORK, exist_ok=True)
imgs = {}
for name, (svg, w, h) in PIECE.items():
    out = os.path.join(WORK, name + '.png')
    imgs[name] = raster(os.path.join(DIR, svg), out)
    assert imgs[name].size == (w*S, h*S), (name, imgs[name].size, (w*S, h*S))
elite = raster(ELITE, os.path.join(WORK, 'elite.png'))

# ── 组装（4×，body TL 置于 pad 后原点） ──
bw, bh = PIECE['body'][1]*S, PIECE['body'][2]*S
offs = {n: ((mx-px)*S, (my-py)*S) for n,(mx,my,px,py) in MOUNT.items()}
minx = min([0]+[offs[n][0] for n in offs]); maxx = max([bw]+[offs[n][0]+imgs[n].width for n in offs])
miny = min([0]+[offs[n][1] for n in offs]); maxy = max([bh]+[offs[n][1]+imgs[n].height for n in offs])
PAD = 48
aw, ah = maxx-minx+2*PAD, maxy-miny+2*PAD
asm = Image.new('RGBA', (aw, ah), (0,0,0,0))
bx, by = -minx+PAD, -miny+PAD   # body TL
# 层级账：主旋翼/机炮在 body 后（桅柱帽盖毂底、围领咬枪塔），尾桨挂近侧
# ——画在 body 之上，整盘可见才读得出整周旋转（垂尾只被桨叶扫过）
for n in ('rotor', 'gun'):
    asm.alpha_composite(imgs[n], (bx+offs[n][0], by+offs[n][1]))
asm.alpha_composite(imgs['body'], (bx, by))
asm.alpha_composite(imgs['tailrotor'], (bx+offs['tailrotor'][0], by+offs['tailrotor'][1]))
asm.save(os.path.join(WORK, 'assembled.png'))
print('assembled', asm.size, 'bodyTL', (bx, by))

# ── 色板对账 ──
PAL = [(51,46,44),(40,35,34),(69,61,57),(23,21,20),(255,81,64)]  # 332e2c 282322 453d39 171514 ff5140
OPS = [i/20 for i in range(4, 19)]  # 文件中出现的 opacity 档
closure = set(PAL)
for c1 in PAL:
    for c2 in PAL:
        for o in OPS:
            closure.add(tuple(round(c1[k]*o + c2[k]*(1-o)) for k in range(3)))
def palette_report(img, tag):
    px = img.load(); bad = {}
    total = 0
    for y in range(0, img.height, 2):
        for x in range(0, img.width, 2):
            r,g,b,a = px[x,y]
            if a < 254: continue
            total += 1
            c = (r,g,b)
            if not any(all(abs(c[k]-p[k])<=10 for k in range(3)) for p in closure):
                bad[c] = bad.get(c, 0)+1
    print('palette[%s] opaque=%d 越色=%d %s' % (tag, total, sum(bad.values()),
          sorted(bad.items(), key=lambda kv:-kv[1])[:4]))
    return sum(bad.values())
bad_total = sum(palette_report(im, n) for n, im in imgs.items())
palette_report(asm, 'assembled')

# ── 关键像素断言（bodyTL 已知，采样画布坐标×S+TL；负坐标=body 画布外的枪/旋翼区） ──
ap = asm.load()
def at(cx, cy): return ap[bx+int(cx*S), by+int(cy*S)][:3]
def near(c, p, tol=14): return all(abs(c[k]-p[k])<=tol for k in range(3))
checks = [
    ('旋翼毂心帽点@156,5',   at(156,5),   (23,21,20)),
    ('尾桨毂心帽点@326,66',  at(326,66),  (23,21,20)),
    ('枪口环@-7,73',         at(-7,73),   (23,21,20)),
    ('枪塔体@40,80',         at(40,80),   (51,46,44)),
    ('仓口A@121,101',        at(121,101), (23,21,20)),
    ('仓口B@121,113',        at(121,113), (23,21,20)),
    ('红眼@13,68',           at(13,68),   (255,81,64)),
    ('尾梁红条@258,56',      at(258,56),  (224,76,61)),
    ('机鼻主色@70,60',       at(70,60),   (51,46,44)),
    ('座舱玻璃@110,26',      at(110,26),  (23,21,20)),
]
ok = True
for tag, c, want in checks:
    hit = near(c, want)
    ok &= hit
    print('%s %s got=%s want=%s' % ('✓' if hit else '✗', tag, c, want))

# 红像素总量（眼+识别条+桨尖）
red = sum(1 for y in range(asm.height) for x in range(asm.width)
          if ap[x,y][3]>200 and ap[x,y][0]>150 and ap[x,y][1]<130 and ap[x,y][2]<130)
print('red px =', red); ok &= red > 400
if not ok: sys.exit('像素断言未全过')

# ── showcase ──
F = font(30); Fs = font(22)
W, H = 2040, 1820
sh = Image.new('RGBA', (W, H), (24,21,19,255))
d = ImageDraw.Draw(sh)
d.text((30, 20), 'BOSS · 大型武装直升机 提案 v1 — 平涂/无描边/敌方暖棕灰4阶+锈红', font=F, fill=(232,226,218,255))

# Panel A：组装体（左移让出右侧标注带）+ 标注
AX, AY = 30, 100
sh.alpha_composite(asm, (AX, AY))
ax, ay = AX+bx, AY+by  # body TL 在 showcase 上的位置
def lead(x1, y1, x2, y2, text, tx, ty, col=(205,197,187,255)):
    d.line((x1,y1,x2,y2), fill=col, width=2)
    d.ellipse((x1-4,y1-4,x1+4,y1+4), fill=(255,81,64,255))
    d.text((tx,ty), text, font=Fs, fill=col)
# 标注账：文字全部落在机身剪影之外的空带（上带/右带/下带）
lead(ax+156*S, ay+2*S,   ax+156*S+50, AY+8,   '主旋翼件 · pivot=(156,5)，呼吸±2°', ax+156*S+56, AY+2)
lead(ax+330*S, ay+40*S,  ax+330*S+70, AY+8,   '尾桨件 · pivot=(326,66)，整周旋转(近侧盘)', ax+330*S+76, AY+2)
lead(ax-6*S,   ay+80*S,  ax-40,       AY+ah-140, '下巴机炮塔件 · 双枪口(8,28.5)/(8,42.5)', AX+8, AY+ah-150)
lead(ax+115*S, ay+114*S, ax+115*S-40, AY+ah-60, 'MissilePorts 仓口A/B=(115,102)/(115,114)', AX+8, AY+ah-70)
lead(ax+13*S,  ay+68*S,  ax-40,       AY+ah-240, '红眼 · EyeGlow(13,68)', AX+8, AY+ah-250)
lead(ax+326*S, ay+95*S,  ax+340*S+30, AY+ah-240, '垂尾/平尾/收起轮舱', ax+340*S+36, AY+ah-250)
# 碰撞盒（290×170 居中画布中心）右上角注
ccx, ccy = ax+170*S, ay+60*S
d.rectangle((ccx-145*S, ccy-85*S, ccx+145*S, ccy+85*S), outline=(140,200,235,150), width=3)
d.text((ccx-145*S+10, ccy-85*S+8), '碰撞盒 290×170（盖旋翼扫掠全高）', font=Fs, fill=(140,200,235,210))
# 比例尺（100 游戏px = 400 展示px），Panel A 右下角
sb_x0, sb_y = AX+aw-460, AY+ah-20
d.line((sb_x0, sb_y, sb_x0+400, sb_y), fill=(232,226,218,255), width=3)
for xx in (sb_x0, sb_x0+200, sb_x0+400): d.line((xx, sb_y-8, xx, sb_y+8), fill=(232,226,218,255), width=3)
d.text((sb_x0, sb_y-36), '100px / 200px（游戏 1:1 档 ×4）', font=Fs, fill=(232,226,218,255))

# Panel B：拆件（2× = 游戏 1:1 档）
py0 = AY+ah+50
d.text((30, py0), '拆件（独立旋转/瞄准件，2×=游戏 1:1 档）', font=F, fill=(232,226,218,255))
px_ = 30
for n in ('body', 'rotor', 'tailrotor', 'gun'):
    im = imgs[n]; w2, h2 = im.width//2, im.height//2
    sh.alpha_composite(im.resize((w2, h2), Image.NEAREST), (px_, py0+56))
    d.text((px_, py0+56+h2+8), n + '  %d×%d' % PIECE[n][1:], font=Fs, fill=(170,163,153,255))
    px_ += w2+60

# Panel C：同框比例（精英 + 玩家高线，同为游戏 1:1 档 ×4 后同缩）
pc0 = py0+380
d.text((30, pc0), '同框比例（左：本提案 · 右：现役精英导弹车 60×80 · 竖线：玩家机甲高 104）', font=F, fill=(232,226,218,255))
half = asm.resize((asm.width//2, asm.height//2), Image.LANCZOS)
sh.alpha_composite(half, (30, pc0+56))
eh = elite.resize((elite.width//2, elite.height//2), Image.LANCZOS)
sh.alpha_composite(eh, (30+half.width+140, pc0+56+half.height-eh.height))
# 玩家高线（104 游戏px → 2× = 208）
p_x = 30+half.width+140+eh.width+110
p_y1, p_y2 = pc0+56+half.height-208, pc0+56+half.height
d.line((p_x, p_y1, p_x, p_y2), fill=(255,160,74,255), width=4)
for yy in (p_y1, p_y2): d.line((p_x-10, yy, p_x+10, yy), fill=(255,160,74,255), width=4)
d.text((p_x+16, (p_y1+p_y2)//2-14), '玩家 104', font=Fs, fill=(255,160,74,255))

out = os.path.join(DIR, 'heli_boss_showcase.png')
sh.convert('RGB').save(out)
print('showcase →', out, sh.size)
