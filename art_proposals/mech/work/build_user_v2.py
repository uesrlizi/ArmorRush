# -*- coding: utf-8 -*-
# 玩家机甲资产 · 用户绘制版组装 v2
# 源：手动绘制机甲.svg（部件层级/形状全部保留）
# 调配色：腿-远→#1d2024（最深纵深）；胯/近大腿/小臂+手/枪-下/枪管→#3c4148（中亮分离）
#         受光集中：肩甲/近小腿/枪-上 保持 #4a525e
# 加细节：胸口前坡橙色传感器竖条(+0.18光晕，现役同款)、喷口橙辉光；不加头不加眼睛
# 组装：bbox(329,474)-(637,782) 308×308 → scale 0.3377 → 高104，viewBox 108×108 含2px边距

import re

src = open(r'C:\Users\31715\Documents\GodotProject\2d-ac\art_proposals\mech\手动绘制机甲.svg', encoding='utf-8').read()
body = src[src.index('<g id="_腿-远"'):src.index('</svg>')]

# 腿-远 加深
m = re.search(r'<g id="_腿-远".*?</g>', body, re.S)
body = body.replace(m.group(0), m.group(0).replace('class="cls-3"', 'fill="#1d2024"'))

# 胯 降一档
body = body.replace('<path id="_跨" data-name="跨" class="cls-4"', '<path id="_跨" data-name="跨" fill="#3c4148"')

# 近侧大腿（腿-近组内第一个 cls-4 path）降一档
m2 = re.search(r'<g id="_腿-近".*?</g>', body, re.S)
leg_near = m2.group(0)
lines = leg_near.split('\n')
for i, l in enumerate(lines):
    if 'cls-4' in l:
        lines[i] = l.replace('class="cls-4"', 'fill="#3c4148"')
        break
body = body.replace(m2.group(0), '\n'.join(lines))

# 小臂+手 / 枪-下 / 枪管 降一档
body = body.replace('<rect id="_小臂_手" data-name="小臂+手" class="cls-4"', '<rect id="_小臂_手" data-name="小臂+手" fill="#3c4148"')
body = body.replace('<rect id="_枪-下" data-name="枪-下" class="cls-4"', '<rect id="_枪-下" data-name="枪-下" fill="#3c4148"')
body = body.replace('<rect id="_枪管" data-name="枪管" class="cls-4"', '<rect id="_枪管" data-name="枪管" fill="#3c4148"')

# 喷口辉光：紧跟喷口元素之后插入
i = body.index('id="_喷口"')
j = body.index('/>', i) + 2
glow = '\n  <circle cx="367" cy="570" r="7" fill="#ffa04a" opacity="0.18"/>\n  <circle cx="367" cy="570" r="3.5" fill="#ffa04a"/>'
body = body[:j] + glow + body[j:]

# 胸口前坡传感器竖条：最上层
body += ('\n  <g id="_点缀-胸传感器">\n'
         '    <rect x="537" y="545" width="10.5" height="20" fill="#ffa04a" opacity="0.18"/>\n'
         '    <rect x="540" y="548" width="4.5" height="14" fill="#ffa04a"/>\n'
         '  </g>')

S = []
S.append('<?xml version="1.0" encoding="UTF-8"?>')
S.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="108" height="112">')
S.append('<!-- 玩家机甲：用户绘制（形状/部件层级/主色板），AI 仅调配色+橙色点缀+缩放组装。')
S.append('     色阶：#1d2024 远腿 / #26292e 腰 / #2e3238 躯干 / #3c4148 胯·近大腿·小臂·枪下轨·近脚 / #4a525e 受光面（肩甲·近小腿·枪上轨）')
S.append('     橙 #ffa04a：胸口传感器竖条 + 喷口辉光（现役同款实心+0.18光晕）。无头无眼（设计如此）。 -->')
S.append('<g transform="translate(2,2) scale(0.3377) translate(-329,-474)">')
S.append(body)
S.append('</g>')
S.append('</svg>')

out = r'C:\Users\31715\Documents\GodotProject\2d-ac\art_proposals\mech\player_mech_user_v1.svg'
open(out, 'w', encoding='utf-8').write('\n'.join(S))
print('written', sum(len(x) for x in S))
