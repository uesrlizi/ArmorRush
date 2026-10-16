# -*- coding: utf-8 -*-
# 玩家机甲资产 · 用户绘制版组装 v3
# 根因修复：上版丢了 <defs><style> 色表，未显式赋色的部件全渲染成黑。
# 本版：cls 全部显式化为用户原值 → 枪身上/下/枪管统一 #4a525e 一个色块（用户要求）
#       仅两处保留调整：小臂+手 #3c4148（与枪分离）、腿-远 #1d2024（纵深）
# 点缀：胸口传感器竖条 + 喷口辉光（橙，现役手法）；无头无眼
# 组装：scale 0.3377，viewBox 108×108

import re

src = open(r'C:\Users\31715\Documents\GodotProject\2d-ac\art_proposals\mech\手动绘制机甲.svg', encoding='utf-8').read()
body = src[src.index('<g id="_腿-远"'):src.index('</svg>')]

# 1. cls 全部显式化（用户原值）
body = body.replace('class="cls-1"', 'fill="#2e3238"')
body = body.replace('class="cls-2"', 'fill="#3c4148"')
body = body.replace('class="cls-3"', 'fill="#26292e"')
body = body.replace('class="cls-4"', 'fill="#3c4148"')

# 2. 腿-远 加深一档（纵深）
m = re.search(r'<g id="_腿-远".*?</g>', body, re.S)
pass  # 远腿保持 #26292e（用户原值；#1d2024 在深背景读不到）

# 3. 枪身上/下/枪管 统一一色（用户要求一个色块）
body = body.replace('<rect id="_枪-下" data-name="枪-下" fill="#4a525e"', '<rect id="_枪-下" data-name="枪-下" fill="#4a525e"')
# （枪-下/枪管在步骤1已是 #4a525e，与枪-上同色，无需再改）

# 4. 小臂+手 降一档与枪分离
body = body.replace('<rect id="_小臂_手" data-name="小臂+手" fill="#4a525e"', '<rect id="_小臂_手" data-name="小臂+手" fill="#26292e"')

# 5. 喷口辉光：紧跟喷口元素之后
i = body.index('id="_喷口"')
j = body.index('/>', i) + 2
glow = '\n  <circle cx="367" cy="570" r="7" fill="#ffa04a" opacity="0.18"/>\n  <circle cx="367" cy="570" r="3.5" fill="#ffa04a"/>'
body = body[:j] + glow + body[j:]

# 6. 胸口前坡传感器竖条：最上层
body += ('\n  <g id="_点缀-胸传感器">\n'
         '    <rect x="537" y="545" width="10.5" height="20" fill="#ffa04a" opacity="0.18"/>\n'
         '    <rect x="540" y="548" width="4.5" height="14" fill="#ffa04a"/>\n'
         '  </g>')

S = []
S.append('<?xml version="1.0" encoding="UTF-8"?>')
S.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="108" height="112">')
S.append('<!-- 玩家机甲：用户绘制，全部色值归位现役4阶 #1d2024/#26292e/#2e3238/#3c4148（枪身一整块 #3c4148，小臂 #26292e）。')
S.append('     橙 #ffa04a 点缀：胸口传感器竖条 + 喷口辉光。无头无眼（设计如此）。 -->')
S.append('<g transform="translate(2,2) scale(0.3377) translate(-329,-474)">')
S.append(body)
S.append('</g>')
S.append('</svg>')

out = r'C:\Users\31715\Documents\GodotProject\2d-ac\art_proposals\mech\player_mech_user_v1.svg'
open(out, 'w', encoding='utf-8').write('\n'.join(S))
print('written', sum(len(x) for x in S))
