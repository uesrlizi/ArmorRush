# -*- coding: utf-8 -*-
# 玩家机甲资产 · 从用户绘制 v2 重新拆件（2026-10-16 重做，替代已删除的 build_user_split.py）
# 源：player_mech_user_v2.svg（108×108，唯一美术定稿；本脚本不改色、不改形，只做机械拆分）
#   body   = v2 去掉「手臂整体」组和喷口的全部（腿-远/腿-近/躯干(腰跨胸+传感器)/胸-肩）
#   arm    = 「手臂整体」组：肩甲→大臂→小臂→枪 一整件（用户要求：从肩膀到枪整体拆出）
#   nozzle = 喷口锥+根部辉光（2026-10-16 二次拆件：可动旋转件，推进焰挂其下随动）
# 拆件规约（svg-game-art skill）：
#   - 臂件画布 160×160，旋转轴(肩关节)=画布中心(80,80)，画布须容纳最大回转半径（轴→枪口 74.8 < 80）
#   - 喷口件画布 32×32，旋转轴(辉光中心=根部挂载点)=画布中心(16,16)，±20° 摆动最大半径 < 16
#   - 身体件保持 108×108 原坐标空间，画布中心(54,54)=机体锚点原点
#   - pivot / 枪口 / 焰口出口坐标写进各份 SVG 注释
# ThorVG 规避：v2 里两个 rect+rotate(5.5°) 烘焙为等价多边形（角点由本脚本按变换矩阵精确计算）
# 引擎换算（scale S=63/108=0.5833333，与旧 72×104 身体贴图在局内同为 63px 高）：
#   ArmPivot.position = (肩关节-画布中心)*S；Muzzle = (枪口-肩关节)*S
#   NozzlePivot.position = (辉光中心-画布中心)*S；焰挂焰口中点、基础旋转=锥轴角-90°(焰原生朝+Y)

import math
import re
import shutil
import xml.etree.ElementTree as ET

ROOT = r'C:\Users\31715\Documents\GodotProject\2d-ac'
SRC = ROOT + r'\art_proposals\mech\player_mech_user_v2.svg'
OUTDIR = ROOT + r'\art_proposals\mech'
ASSETS = ROOT + r'\assets'

S = 63.0 / 108.0          # 精灵缩放：v2 画布单位 → 世界像素
ARM_CANVAS = 160.0        # 臂件画布边长（偶数，中心=整数）
ARM_PIVOT = ARM_CANVAS / 2.0
NOZ_CANVAS = 32.0         # 喷口件画布边长
NOZ_PIVOT = NOZ_CANVAS / 2.0

src = open(SRC, encoding='utf-8').read()
ET.fromstring(src)  # 先验源文件本身是良构 XML

# ── 外层变换逐字保留 ──
m_outer = re.search(r'<g transform="(translate\(2,2\) scale\(0\.3377\) translate\(-329,-474\))">', src)
assert m_outer, '外层变换未找到'
outer_open = m_outer.group(0)


def parse_translate_rotate(tstr):
    """解析 'translate(tx ty) rotate(deg)'（v2 中两处 rect 的写法）"""
    mt = re.search(r'translate\(\s*([-\d.]+)[ ,]+([-\d.]+)\s*\)', tstr)
    mr = re.search(r'rotate\(\s*([-\d.]+)\s*\)', tstr)
    assert mt and mr, '变换解析失败: %s' % tstr
    return float(mt.group(1)), float(mt.group(2)), float(mr.group(1))


def apply_tr(x, y, tx, ty, deg):
    """SVG transform='translate(tx ty) rotate(deg)'：先转后移"""
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return x * c - y * s + tx, x * s + y * c + ty


def apply_outer(x, y):
    """v2 外层：translate(2,2) scale(0.3377) translate(-329,-474)"""
    return 2 + (x - 329) * 0.3377, 2 + (y - 474) * 0.3377


# ── 抽取「手臂整体」组（深度配平，不靠行号猜） ──
i0 = src.index('<g id="_手臂整体"')
depth = 0
i = i0
while True:
    mo = re.compile(r'<g\b|</g>').search(src, i)
    assert mo, '手臂整体组未配平'
    depth += 1 if mo.group(0).startswith('<g') else -1
    i = mo.end()
    if depth == 0:
        break
arm_body = src[i0:i]
rest = src[:i0] + src[i:]
rest = rest[:rest.rindex('</g>')].rstrip()  # 剥掉源文件的外层收口 </g></svg>，输出时自己补

# ── 抽取喷口：path _喷口 + 紧随其后的两颗辉光圆 ──
nz_start = src.index('<path id="_喷口"')
i35 = src.index('<circle cx="367" cy="570" r="3.5"')
nz_end = src.index('/>', i35) + 2
nozzle_elems = src[nz_start:nz_end]
assert rest.count(nozzle_elems) == 1, '喷口段在 body 中定位失败'
rest = rest.replace(nozzle_elems, '', 1)

# ── rect+rotate 烘焙为等价 polygon（ThorVG 崩溃规避） ──
baked = {}


def bake(mo):
    tag = mo.group(0)
    attrs = dict(re.findall(r'([\w-]+)="([^"]*)"', tag))
    x, y = float(attrs['x']), float(attrs['y'])
    w, h = float(attrs['width']), float(attrs['height'])
    tx, ty, deg = parse_translate_rotate(attrs['transform'])
    pts = [apply_tr(px, py, tx, ty, deg)
           for px, py in [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]]
    poly = '<polygon id="%s" data-name="%s" fill="%s" points="%s"/>' % (
        attrs['id'], attrs['data-name'], attrs['fill'],
        ' '.join('%.2f,%.2f' % p for p in pts))
    baked[attrs['id']] = (x + w / 2, y, tx, ty, deg)  # 顶边中点=关节锚（转前坐标）
    return poly


rest, n1 = re.subn(r'<rect id="_胸-肩"[^>]*/>', bake, rest)
arm_body, n2 = re.subn(r'<rect id="_大臂"[^>]*/>', bake, arm_body)
assert n1 == 1 and n2 == 1, '烘焙未命中 (n1=%d n2=%d)' % (n1, n2)

# ── 关键锚点（v2 108 画布坐标） ──
bx, by, btx, bty, bdeg = baked['_大臂']
sx, sy = apply_tr(bx, by, btx, bty, bdeg)   # 肩关节，pre-outer
pix, piy = apply_outer(sx, sy)               # → (33.54, 12.20)

mbar = re.search(r'<rect id="_枪管"[^>]*/>', src).group(0)
ma = dict(re.findall(r'([\w-]+)="([^"]*)"', mbar))
mx_pre = float(ma['x']) + float(ma['width'])          # 枪管右缘=枪口
my_pre = float(ma['y']) + float(ma['height']) / 2.0   # 管轴中心
mux, muy = apply_outer(mx_pre, my_pre)                 # → (105.64, 32.23)

assert '<circle cx="367" cy="570" r="3.5"' in nozzle_elems, '辉光圆不在喷口段'
nox, noy = apply_outer(367, 570)             # 喷口辉光中心=枢轴 → (14.83, 34.42)

# 喷口几何（path 数据读点，账：M351.24,553.05 顶点；c-11.62,26.77→(339.62,579.82) 焰口沿A；
# 再 c 10.7,7.56→(350.32,587.38) 焰口沿B；右端 (371.29,566.81)=锥顶/挂载侧）
nz_top = apply_outer(351.24, 553.05)
nz_ma = apply_outer(339.62, 579.82)
nz_mb = apply_outer(350.32, 587.38)
nz_mount = apply_outer(371.29, 566.81)
nz_mouth = ((nz_ma[0] + nz_mb[0]) / 2.0, (nz_ma[1] + nz_mb[1]) / 2.0)  # 焰口中点
nz_axis = math.degrees(math.atan2(nz_mouth[1] - nz_mount[1], nz_mouth[0] - nz_mount[0]))
nz_flame_rot = math.radians(nz_axis - 90.0)  # 焰原生朝 +Y(90°)
noz_radius = max(
    math.hypot(p[0] - nox, p[1] - noy) for p in [nz_top, nz_ma, nz_mb, nz_mount])
noz_radius = max(noz_radius, 7 * 0.3377)     # 辉光外缘 r=7(pre-outer)
assert noz_radius < NOZ_PIVOT, '喷口画布装不下摆动半径 %.2f' % noz_radius

radius = math.hypot(mux - pix, muy - piy)    # 臂件最大回转半径（枪口最远）
assert radius < ARM_PIVOT, '臂件画布装不下回转半径 %.2f' % radius

# ── 组装输出 ──
XML_HEAD = '<?xml version="1.0" encoding="UTF-8"?>\n'
NOTE_COMMON = ('用户绘制 v2 拆件（唯一美术定稿 player_mech_user_v2.svg，本件不改色不改形）。\n'
               '     色阶：受光#3c4148/中值#2e3238/暗板#26292e/最深#1d2024 + 橙#ffa04a；无头无眼（设计如此）。\n'
               '     矩形+rotate 已烘焙为等价多边形（ThorVG 不支持 rect+rotate，2026-10-16 崩溃规避）。')

body_svg = XML_HEAD + (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="108" height="108">\n'
    '<!-- 玩家机甲·身体件：腿-远/腿-近/躯干(腰跨胸+胸传感器)/胸-肩；喷口已拆至 player_mech_user_nozzle.svg。\n'
    '     ' + NOTE_COMMON + '\n'
    '     画布 108×108 原坐标空间，画布中心(54,54)=机体锚点原点（精灵缩放 %.7f，局内 63px 高）。\n'
    '     肩关节(臂件旋转轴)在本画布 (%.2f,%.2f)；喷口枢轴(辉光中心)在本画布 (%.2f,%.2f)。\n'
    '     臂件/喷口件见 player_mech_user_arm.svg / player_mech_user_nozzle.svg。 -->\n'
    % (S, pix, piy, nox, noy)
    + outer_open + '\n' + rest[rest.index('<g id="_腿-远"'):] + '\n</g>\n</svg>\n')

arm_shift_x, arm_shift_y = ARM_PIVOT - pix, ARM_PIVOT - piy
arm_svg = XML_HEAD + (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">\n'
    % (int(ARM_CANVAS), int(ARM_CANVAS), int(ARM_CANVAS), int(ARM_CANVAS))
    + '<!-- 玩家机甲·臂件：肩甲→大臂→小臂→枪 一整件，肩关节=唯一旋转轴（俯仰±60°/朝向镜像由引擎做）。\n'
    '     ' + NOTE_COMMON + '\n'
    '     画布 %d×%d，旋转轴=画布中心 (%.0f,%.0f)；最大回转半径(轴→枪口) %.1f < %.0f，任意俯仰不出画布。\n'
    '     出口坐标（精灵缩放 %.7f）：Muzzle = 轴+(%.2f,%.2f)，即 ArmPivot 局部同一对数。\n'
    '     回原 v2 空间偏移 translate(%.4f,%.4f)；\n'
    '     挂法：ArmPivot.position=((%.2f,%.2f)-(54,54))*%.4f，Arm 精灵居中置于 ArmPivot 原点。 -->\n'
    % (int(ARM_CANVAS), int(ARM_CANVAS), ARM_PIVOT, ARM_PIVOT, radius, ARM_PIVOT,
       S, (mux - pix) * S, (muy - piy) * S, arm_shift_x, arm_shift_y,
       pix, piy, S)
    + '<g transform="translate(%.4f,%.4f)">\n' % (arm_shift_x, arm_shift_y)
    + outer_open + '\n' + arm_body + '\n</g>\n</g>\n</svg>\n')

noz_shift_x, noz_shift_y = NOZ_PIVOT - nox, NOZ_PIVOT - noy
nozzle_svg = XML_HEAD + (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">\n'
    % (int(NOZ_CANVAS), int(NOZ_CANVAS), int(NOZ_CANVAS), int(NOZ_CANVAS))
    + '<!-- 玩家机甲·喷口件：喷口锥+根部辉光，可动旋转件（摆幅±20°由 Balance.NOZZLE_SWING_DEG 定）。\n'
    + NOTE_COMMON.split('\n')[0] + '\n'
    + NOTE_COMMON.split('\n')[1] + '\n'
    '     画布 %d×%d，旋转轴=画布中心 (%.0f,%.0f)=辉光中心 v2(%.2f,%.2f)（挂载点，转动零漂移）；\n'
    '     最大回转半径 %.1f < %.0f，±20° 摆动不出画布。\n'
    '     焰口轴线（锥顶(%.2f,%.2f)→焰口中点(%.2f,%.2f)）= %.1f°；焰原生朝+Y，基础旋转=%.4f rad。\n'
    '     焰口中点（枢轴局部）=(%.2f,%.2f) 画布 = (%.2f,%.2f)px（缩放 %.7f），推进焰 Thruster 挂此处。\n'
    '     回原 v2 空间偏移 translate(%.4f,%.4f)；挂法：NozzlePivot.position=((%.2f,%.2f)-(54,54))*%.4f，\n'
    '     随朝向镜像 position.x 与 scale.x，摆动写 NozzlePivot.rotation（镜像由 scale 提供，摆角与朝向无关）。 -->\n'
    % (int(NOZ_CANVAS), int(NOZ_CANVAS), NOZ_PIVOT, NOZ_PIVOT, nox, noy,
       noz_radius, NOZ_PIVOT,
       nz_mount[0], nz_mount[1], nz_mouth[0], nz_mouth[1], nz_axis, nz_flame_rot,
       nz_mouth[0] - nox, nz_mouth[1] - noy, (nz_mouth[0] - nox) * S, (nz_mouth[1] - noy) * S, S,
       noz_shift_x, noz_shift_y, nox, noy, S)
    + '<g transform="translate(%.4f,%.4f)">\n' % (noz_shift_x, noz_shift_y)
    + outer_open + '\n' + nozzle_elems + '\n</g>\n</g>\n</svg>\n')

for path, text in [(OUTDIR + r'\player_mech_user_body.svg', body_svg),
                   (OUTDIR + r'\player_mech_user_arm.svg', arm_svg),
                   (OUTDIR + r'\player_mech_user_nozzle.svg', nozzle_svg)]:
    open(path, 'w', encoding='utf-8', newline='\n').write(text)
    ET.fromstring(text)  # 输出必须是良构 XML

shutil.copy(OUTDIR + r'\player_mech_user_body.svg', ASSETS + r'\player_mech_user_body.svg')
shutil.copy(OUTDIR + r'\player_mech_user_arm.svg', ASSETS + r'\player_mech_user_arm.svg')
shutil.copy(OUTDIR + r'\player_mech_user_nozzle.svg', ASSETS + r'\player_mech_user_nozzle.svg')

# ── 自检：组归属 ──
for gone in ['_手臂整体', '_枪', '_肩"', '_喷口', 'cx="367"']:
    assert gone not in body_svg, 'body 不应含 ' + gone
for need in ['_腿-远', '_腿-近', '_躯干', '_胸-肩', '_点缀-胸传感器']:
    assert need in body_svg, 'body 缺 ' + need
for need in ['_手臂整体', '_大臂关节', '_肩"', '_小臂关节', '_小臂_手', '_枪"', '_枪-下', '_枪管', '_枪-上']:
    assert need in arm_svg, 'arm 缺 ' + need
for need in ['_喷口', 'cx="367"', 'r="7"', 'r="3.5"']:
    assert need in nozzle_svg, 'nozzle 缺 ' + need

print('OK body %dB arm %dB nozzle %dB' % (len(body_svg), len(arm_svg), len(nozzle_svg)))
print('pivot_v2   = (%.4f, %.4f)' % (pix, piy))
print('muzzle_v2  = (%.4f, %.4f)' % (mux, muy))
print('nozzle_v2  = (%.4f, %.4f)  radius=%.2f' % (nox, noy, noz_radius))
print('mouth_v2   = (%.4f, %.4f)  axis=%.2f deg' % (nz_mouth[0], nz_mouth[1], nz_axis))
print('arm_shift  = (%.4f, %.4f)' % (arm_shift_x, arm_shift_y))
print('noz_shift  = (%.4f, %.4f)' % (noz_shift_x, noz_shift_y))
print('--- tscn (S=%.7f) ---' % S)
print('ArmPivot.position    = (%.2f, %.2f)' % ((pix - 54) * S, (piy - 54) * S))
print('Muzzle   (pivot局部) = (%.2f, %.2f)' % ((mux - pix) * S, (muy - piy) * S))
print('NozzlePivot.position = (%.2f, %.2f)' % ((nox - 54) * S, (noy - 54) * S))
print('Thruster(pivot局部)  = (%.2f, %.2f) rotation = %.4f' % (
    (nz_mouth[0] - nox) * S, (nz_mouth[1] - noy) * S, nz_flame_rot))
print('Sprite/Arm/Nozzle scale = %.7f' % S)
