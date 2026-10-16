# -*- coding: utf-8 -*-
# 玩家机甲资产 · 用户绘制版组装 v5：明度重排（对齐现役节奏）
# 明度账（上亮中暗，相邻≥1档）：
#   肩甲/枪(上中下管) #3c4148 受光 → 躯干/小腿 #2e3238 中值
#   → 胯/大腿/脚/大臂/胸-肩/喷口 #26292e 暗板 → 腰/小臂+手/腿-远 #1d2024 最深
# 其余不变：枪一整块、无头无眼、橙点缀（胸口上坡竖条挪出枪区）、层级保留、scale 0.3377

import re

src = open(r'C:\Users\31715\Documents\GodotProject\2d-ac\art_proposals\mech\手动绘制机甲.svg', encoding='utf-8').read()
body = src[src.index('<g id="_腿-远"'):src.index('</svg>')]

# 基础映射：cls → 现役色阶
body = body.replace('class="cls-1"', 'fill="#2e3238"')  # 躯干/胸-肩 → 中值（胸-肩后面覆写）
body = body.replace('class="cls-2"', 'fill="#26292e"')  # 喷口/近足 → 暗板
body = body.replace('class="cls-3"', 'fill="#1d2024"')  # 腿-远/腰 → 最深
body = body.replace('class="cls-4"', 'fill="#3c4148"')  # 肩甲/大小臂/胯/大腿/小腿/枪 → 受光（下面逐个覆写）

# 逐部位覆写（按明度账）
overrides = [
    ('id="_腰"',        '#1d2024'),
    ('id="_跨"',        '#26292e'),
    ('id="_胸-肩"',     '#26292e'),
    ('id="_喷口"',      '#26292e'),
    ('id="_小腿"',      '#2e3238'),
    ('id="_枪管"',      '#26292e'),
    ('id="_大臂"',      '#1d2024'),
    ('id="_小臂_手"',   '#3c4148'),
]
for pid, color in overrides:
    body = re.sub(r'(id="%s"[^>]*?)class="[^"]*"' % pid, r'\1fill="%s"' % color, body)
    # class 已在基础映射换成 fill 的，再做值替换
    body = re.sub(r'(id="%s"[^>]*?)fill="[^"]*"' % pid, r'\1fill="%s"' % color, body)

# 近侧大腿（腿-近组内第一个 #3c4148 path）→ #26292e
m2 = re.search(r'<g id="_腿-近".*?</g>', body, re.S)
leg_near = m2.group(0)
lines = leg_near.split('\n')
for i, l in enumerate(lines):
    if '#3c4148' in l:
        lines[i] = l.replace('fill="#3c4148"', 'fill="#26292e"')
        break
body = body.replace(m2.group(0), '\n'.join(lines))

# 喷口辉光
i = body.index('id="_喷口"')
j = body.index('/>', i) + 2
glow = '\n  <circle cx="367" cy="570" r="7" fill="#ffa04a" opacity="0.18"/>\n  <circle cx="367" cy="570" r="3.5" fill="#ffa04a"/>'
body = body[:j] + glow + body[j:]

# 胸部上坡传感器竖条（枪口上方，明确的胸部件点缀）
body += ('\n  <g id="_点缀-胸传感器">\n'
         '    <rect x="521" y="503" width="10.5" height="20" fill="#ffa04a" opacity="0.18"/>\n'
         '    <rect x="524" y="506" width="4.5" height="14" fill="#ffa04a"/>\n'
         '  </g>')

S = []
S.append('<?xml version="1.0" encoding="UTF-8"?>')
S.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="108" height="108">')
S.append('<!-- 玩家机甲：用户绘制。明度账：肩甲/枪身/小臂 #3c4148 受光 → 躯干/小腿 #2e3238 → 胯/大腿/脚/大臂/胸-肩/喷口/枪管 #26292e → 腰/腿-远 #1d2024。')
S.append('     橙 #ffa04a 点缀：胸上坡传感器竖条 + 喷口辉光。无头无眼（设计如此）。 -->')
S.append('<g transform="translate(2,2) scale(0.3377) translate(-329,-474)">')
S.append(body)
S.append('</g>')
S.append('</svg>')

out = r'C:\Users\31715\Documents\GodotProject\2d-ac\art_proposals\mech\player_mech_user_v1.svg'
open(out, 'w', encoding='utf-8').write('\n'.join(S))
print('written', sum(len(x) for x in S))
