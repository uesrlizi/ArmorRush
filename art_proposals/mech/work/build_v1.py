# -*- coding: utf-8 -*-
# 玩家机甲提案 v3：全部几何以"用户原始描形坐标"为源，经 map() 统一映射
# 比例：上身(锚点y=479以上) ×0.88，腿部 ×0.70（v2的0.62压坏了Z形小腿，回调）
# 原则：形状语言=用户描形；装甲=描形多边形内缩拷贝；头/背包/天线=参考图有而描形未含，补齐
import math

U = 0.88   # 上身压缩
L = 0.70   # 腿部压缩
YA = 479.0 # 锚点（髋顶）

def mapy(y):
    if y < YA: return YA - (YA - y) * U
    return YA + (y - YA) * L

def M(pts):
    return [(x, mapy(y)) for x, y in pts]

def inset(pts, k):
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    return [(cx + (x - cx) * k, cy + (y - cy) * k) for x, y in pts]

def P(pts, fill, sw=4, stroke='#181B20', extra=''):
    s = ' '.join(f'{x:.0f},{y:.0f}' for x, y in pts)
    st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ''
    return f'<polygon points="{s}" fill="{fill}"{st}{extra}/>'

def R(x, y, w, h, fill, sw=4, stroke='#181B20', rx=0, extra=''):
    st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ''
    r = f' rx="{rx}"' if rx else ''
    return f'<rect x="{x:.0f}" y="{y:.0f}" width="{w:.0f}" height="{h:.0f}" fill="{fill}"{st}{r}{extra}/>'

def C(cx, cy, r, fill, sw=0, stroke=''):
    st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ''
    return f'<circle cx="{cx:.0f}" cy="{cy:.0f}" r="{r}" fill="{fill}"{st}/>'

def LN(x1, y1, x2, y2, stroke, w):
    return f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" stroke="{stroke}" stroke-width="{w}"/>'

# ── 用户描形原始多边形（手动描机甲大形.svg，未压缩） ──
SHIN  = [(889,577),(877,614),(958,666),(966,728),(922,796),(975,813),(1104,767),(1096,731),(1034,711),(1040,666),(1065,649),(1072,607),(1033,579),(956,589)]
THIGH = [(1042,511),(1025,592),(987,612),(960,598),(984,508),(1021,502)]
FOOT  = [(980,791),(947,818),(896,832),(928,865),(1096,850),(1098,836),(1059,767)]
HIP   = [(960,479),(1053,479),(1053,533),(960,533)]
WAIST = (987,444,48,48)
TORSO = [(1033,337),(895,379),(912,424),(977,468),(1061,468),(1088,406),(1116,401),(1127,392),(1156,395),(1164,355),(1094,313)]
CHEST = [(980,369),(983,327),(1081,301),(1088,343)]
PAULD = [(928,327),(994,388),(1030,328),(1058,324),(1085,369),(1109,303),(1082,266),(999,288)]
UARM  = [(1055,440),(1081,432),(1058,324),(1030,328)]
FARM  = [(1151,382),(906,541),(927,576),(1174,414)]
GUN   = [(963,499),(948,471),(723,626),(746,658),(806,613),(823,632),(898,581),(877,557)]

S = []
S.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 980 970" font-family="\'Segoe UI\',\'Microsoft YaHei\',sans-serif">')
S.append('  <!-- 玩家机甲提案 · 用户正侧描形提炼 v3：源坐标=用户描形，map()统一映射(上身0.88/腿0.70) -->')
S.append('  <defs><radialGradient id="eyeV" cx="0.35" cy="0.5" r="0.9"><stop offset="0" stop-color="#D8FFF4"/><stop offset="0.5" stop-color="#52E0C4"/><stop offset="1" stop-color="#189E82"/></radialGradient></defs>')
S.append('  <rect width="980" height="970" fill="#14171C"/>')
S.append('  <text x="24" y="42" font-size="26" font-weight="700" fill="#C6C0AC">玩家机甲提案 · 描形提炼 v3</text>')
S.append('  <text x="24" y="70" font-size="14" fill="#7A8290">大形=用户正侧手描 · 映射：上身0.88/腿0.70 · 装甲=描形多边形内缩 · 补头部/背包/天线</text>')
# 阴影/脚底：FOOT 最低点 865 → mapy=757 → +130=887
S.append('  <ellipse cx="474" cy="891" rx="150" ry="15" fill="#000000" opacity="0.4"/>')
S.append('  <g transform="translate(1471,130) scale(-1,1)">')
S.append('  <g stroke-linejoin="round" stroke-linecap="round">')

# 背包（补；锚在躯干后方 orig 1160-1272, 330-430）
S.append('  <g id="pack">')
S.append('    ' + P(M([(1160,424),(1192,382),(1252,370),(1272,402),(1264,456),(1192,470)], 4)) )
S.append('    ' + P(M([(1168,426),(1196,390),(1246,380),(1260,404),(1254,448),(1196,460)], 0), '#5E646B'))
S.append('    ' + f'<ellipse cx="1246" cy="{mapy(464):.0f}" rx="14" ry="6" fill="#FFB35C" opacity="0.85"/>')
S.append('    ' + R(1210, mapy(396), 24, 6, '#52E0C4', 0, '', 3, ' opacity="0.7"'))
S.append('  </g>')

# 腰
S.append('  <g id="waist">')
S.append('    ' + R(WAIST[0], mapy(WAIST[1]), WAIST[2], mapy(WAIST[1]+WAIST[3])-mapy(WAIST[1]), '#23262C'))
S.append('    ' + P(M([(995,448),(1007,448),(999,486),(987,486)], 0), '#C43C2C'))
S.append('  </g>')

# 胯
S.append('  <g id="hip">')
S.append('    ' + P(M(HIP), '#59626E'))
S.append('    ' + P(M(inset(HIP, 0.7)), '#6B7480', 0))
S.append('    ' + C(1006, mapy(510), 13, '#23262C'))
S.append('  </g>')

# 躯干
S.append('  <g id="torso">')
S.append('    ' + P(M(TORSO), '#C6C0AC'))
S.append('    ' + P(M([(1022,362),(908,394),(922,426),(974,462),(1042,462)]), '#D6D1BF', 0))
S.append('    ' + P(M([(1078,418),(1112,412),(1148,407),(1158,378),(1120,372)]), '#A69E88', 0))
S.append('    ' + C(948, mapy(428), 6, '#C43C2C', 2.5, '#181B20'))
S.append('    ' + R(1088, mapy(452), 26, 5, '#8F8975', 0, '', 2.5))
S.append('    ' + R(1088, mapy(461), 26, 5, '#8F8975', 0, '', 2.5))
S.append('  </g>')

# 躯干-肩（胸前上板）
S.append('  <g id="chest-top">')
S.append('    ' + P(M(CHEST), '#D6D1BF'))
S.append('    ' + P(M([(980,369),(983,327),(996,324),(994,380)]), '#C43C2C', 0))
S.append('  </g>')

# 大腿
S.append('  <g id="thigh">')
S.append('    ' + P(M(THIGH), '#23262C'))
S.append('    ' + P(M(inset(THIGH, 0.76)), '#C6C0AC', 0))
S.append('    ' + LN(1010, 520, 995, 580, '#A69E88', 2.5))
S.append('  </g>')

# 脚
S.append('  <g id="foot">')
S.append('    ' + P(M(FOOT), '#23262C'))
S.append('    ' + P(M(inset(FOOT, 0.80)), '#C6C0AC', 0))
S.append('    ' + P(M([(1040,784),(1059,767),(1098,836),(1096,850),(1052,846)]), '#9A927C', 0))
S.append('    ' + P(M([(905,810),(940,800),(952,864),(922,865)]), '#9A927C', 0))
S.append('    ' + R(926, mapy(852), 164, 9, '#23262C', 0, '', 4))
S.append('  </g>')

# 小腿
S.append('  <g id="shin">')
S.append('    ' + P(M(SHIN), '#23262C'))
S.append('    ' + P(M(inset(SHIN, 0.85)), '#C6C0AC', 0))
S.append('    ' + P(M([(893,583),(883,601),(952,630),(948,614)]), '#9A927C', 0))
S.append('    ' + P(M([(1030,582),(1072,601),(1062,634),(1036,646)]), '#D6D1BF', 0))
S.append('    ' + C(1004, mapy(610), 11, '#23262C'))
S.append('    ' + LN(978, 592, 1028, 618, '#C7CDD6', 3))
S.append('    ' + C(978, 592, 3.5, '#23262C'))
S.append('    ' + C(1028, 618, 3.5, '#23262C'))
S.append('  </g>')

# 枪（描形多边形 + 加粗外圈）
S.append('  <g id="gun">')
S.append('    ' + P(M(GUN), '#3A3E46', 9, '#23262C'))
S.append('    ' + P(M(inset(GUN, 0.82)), '#4A4F58', 0))
S.append('    ' + P(M([(918,462),(948,470),(940,486),(912,478)]), '#2A2D34', 0))
S.append('    ' + C(928, 474, 5, '#52E0C4'))
S.append('    ' + P(M([(748,610),(726,606),(716,624),(742,632)]), '#23262C'))
S.append('    ' + P(M([(860,576),(878,584),(868,602),(850,594)]), '#2A2D34', 0))
S.append('  </g>')

# 小臂+手
S.append('  <g id="forearm">')
S.append('    ' + P(M(FARM), '#23262C'))
S.append('    ' + P(M(inset(FARM, 0.70)), '#B9B29C', 0))
S.append('    ' + C(1156, mapy(404), 10, '#23262C'))
S.append('    ' + P(M([(906,541),(927,576),(908,592),(890,558)]), '#23262C'))
S.append('  </g>')

# 大臂
S.append('  <g id="upperarm">')
S.append('    ' + P(M(UARM), '#23262C'))
S.append('    ' + P(M(inset(UARM, 0.72)), '#B9B29C', 0))
S.append('  </g>')

# 肩膀
S.append('  <g id="pauldron">')
S.append('    ' + P(M(PAULD), '#9A927C'))
S.append('    ' + P(M(inset(PAULD, 0.84)), '#ABA48E', 0))
S.append('    ' + P(M([(928,327),(940,332),(950,344),(936,338)]), '#C43C2C', 0))
S.append('    ' + C(1074, mapy(348), 4.5, '#23262C'))
S.append('  </g>')

# 头部（补）
S.append('  <g id="head">')
S.append('    ' + P([(1144,302),(1158,282),(1204,277),(1234,287),(1242,309),(1230,326),(1188,332),(1156,322)], '#C6C0AC', 3.5))
S.append('    ' + P([(1152,304),(1162,288),(1202,284),(1226,292),(1232,308),(1222,322),(1190,326),(1164,318)], '#A69E88', 0))
S.append('    ' + P([(1146,302),(1158,286),(1170,286),(1164,320),(1150,312)], '#23262C', 0))
S.append(f'    <rect x="1152" y="296" width="18" height="7" rx="2" fill="url(#eyeV)"/>')
S.append('    ' + P([(1194,330),(1220,328),(1214,340),(1198,340)], '#57544A', 0))
S.append('  </g>')
# 天线（补，从肩甲后上方探出）
S.append('  <g id="antenna">')
S.append(f'    {LN(990, mapy(312), 934, mapy(252), "#23262C", 5)}')
S.append(f'    {C(932, mapy(250), 4, "#C43C2C")}')
S.append('  </g>')

S.append('  </g>')
S.append('  </g>')
S.append('  <g font-size="13" fill="#7A8290">')
S.append('    <rect x="24" y="906" width="34" height="22" rx="4" fill="#C6C0AC" stroke="#181B20" stroke-width="2"/>')
S.append('    <rect x="66" y="906" width="34" height="22" rx="4" fill="#9A927C" stroke="#181B20" stroke-width="2"/>')
S.append('    <rect x="108" y="906" width="34" height="22" rx="4" fill="#3A3E46" stroke="#181B20" stroke-width="2"/>')
S.append('    <rect x="150" y="906" width="34" height="22" rx="4" fill="#C43C2C" stroke="#181B20" stroke-width="2"/>')
S.append('    <rect x="192" y="906" width="34" height="22" rx="4" fill="#52E0C4" stroke="#181B20" stroke-width="2"/>')
S.append('    <text x="236" y="922">#C6C0AC 装甲 / #9A927C 肩甲 / #3A3E46 枪铁 / #C43C2C 强调红 / 传感器青</text>')
S.append('  </g>')
S.append('</svg>')

open('mech_trace_refined_v1.svg', 'w', encoding='utf-8').write('\n'.join(S))
print('written', sum(len(x) for x in S))
