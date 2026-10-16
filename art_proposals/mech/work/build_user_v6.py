# -*- coding: utf-8 -*-
# 玩家机甲资产 · 用户绘制版组装 v6（修正覆写静默失败 bug）
# pid 不带 id=" 前缀；每个覆写用 re.subn 断言命中，失败即抛错
# 明度账：受光 #3c4148=肩甲+枪身(上/下一整块)+小臂；中值 #2e3238=躯干+近小腿
#         暗板 #26292e=胯/近大腿/近足/大臂/胸-肩/喷口/枪管；最深 #1d2024=腰/腿-远
# 点缀：胸口前坡传感器竖条（挂躯干组内胸路径后，正确层级）+ 喷口辉光；无头无眼

import re

SRC = r'C:\Users\31715\Documents\GodotProject\2d-ac\art_proposals\mech\手动绘制机甲.svg'
OUT = r'C:\Users\31715\Documents\GodotProject\2d-ac\art_proposals\mech\player_mech_user_v2.svg'

src = open(SRC, encoding='utf-8').read()
body = src[src.index('<g id="_腿-远"'):src.index('</svg>')]

# 基础色阶
body = body.replace('class="cls-1"', 'fill="#2e3238"')  # 躯干
body = body.replace('class="cls-2"', 'fill="#3c4148"')  # 近足（喷口后覆写）
body = body.replace('class="cls-3"', 'fill="#26292e"')  # 腰/腿-远
body = body.replace('class="cls-4"', 'fill="#3c4148"')  # 肩甲/大小臂/胯/大腿/小腿/枪（下面覆写）

# 逐部位覆写：pid 不带前缀；subn 断言命中
overrides = [
    ('_腰',      '#1d2024'),
    ('_跨',      '#26292e'),
    ('_胸-肩',   '#26292e'),
    ('_喷口',    '#26292e'),
    ('_枪管',    '#26292e'),
    ('_大臂',    '#1d2024'),
    ('_小臂_手', '#26292e'),
]
for pid, color in overrides:
    body, n = re.subn(r'(id="%s" data-name="[^"]*") fill="[^"]*"' % re.escape(pid),
                      r'\1 fill="%s"' % color, body)
    assert n == 1, '覆写未命中: %s (n=%d)' % (pid, n)

# 腿-远整组 → 最深档（阴影层；游戏场景浅地面下可读）
i0 = body.index('id="_腿-远"')
seg_start = body.rindex('<g', 0, i0)
seg_end = body.index('</g>', i0) + 4
seg = body[seg_start:seg_end]
seg_new, n0 = re.subn(r'fill="#26292e"', 'fill="#1d2024"', seg)
assert n0 == 3, '腿-远 path 数量异常: %d' % n0
body = body[:seg_start] + seg_new + body[seg_end:]

# 腿-近：组内三条 path 无 id，按序号赋色（大腿/足=暗板，小腿刃=中值受光）
m2 = re.search(r'<g id="_腿-近".*?</g>', body, re.S)
leg_near = m2.group(0)
near_fills = ['#26292e', '#26292e', '#2e3238']
parts = re.split(r'(<path [^>]*/>)', leg_near)
pi = 0
for k in range(len(parts)):
    if parts[k].startswith('<path '):
        parts[k] = parts[k].replace('fill="#3c4148"', 'fill="%s"' % near_fills[pi], 1) \
            if 'fill="#3c4148"' in parts[k] else parts[k]
        if 'fill="#3c4148"' in parts[k]:
            parts[k] = re.sub(r'fill="[^"]*"', 'fill="%s"' % near_fills[pi], parts[k], count=1)
        pi += 1
assert pi == 3, '腿-近 path 数量异常: %d' % pi
body = body.replace(m2.group(0), ''.join(parts))

# 喷口辉光：紧跟喷口元素之后
i = body.index('id="_喷口"')
j = body.index('/>', i) + 2
glow = '\n  <circle cx="367" cy="570" r="7" fill="#ffa04a" opacity="0.18"/>\n  <circle cx="367" cy="570" r="3.5" fill="#ffa04a"/>'
body = body[:j] + glow + body[j:]

# 胸传感器竖条：插入躯干组内、胸路径之后（正确层级，前景手臂/枪自然遮挡）
i2 = body.index('id="_胸"')
j2 = body.index('/>', i2) + 2
sensor = ('\n  <g id="_点缀-胸传感器">\n'
          '    <rect x="538" y="538" width="10.5" height="20" fill="#ffa04a" opacity="0.18"/>\n'
          '    <rect x="540" y="540" width="4.5" height="14" fill="#ffa04a"/>\n'
          '  </g>')
body = body[:j2] + sensor + body[j2:]

# 输出自检
def fill_of(pid):
    m = re.search(r'id="%s" data-name="[^"]*" fill="([^"]*)"' % re.escape(pid), body)
    assert m, '缺少部件: ' + pid
    return m.group(1)

checks = {
    '_胸': '#2e3238', '_胸-肩': '#26292e', '_腰': '#1d2024', '_跨': '#26292e',
    '_肩': '#3c4148', '_大臂': '#1d2024', '_小臂_手': '#26292e',
    '_枪-上': '#3c4148', '_枪-下': '#3c4148', '_枪管': '#26292e',
    '_喷口': '#26292e',
}
m_far = re.search(r'<g id="_腿-远".*?</g>', body, re.S)
assert m_far and m_far.group(0).count('fill="#1d2024"') == 3, '腿-远 未压到最深档'
for pid, want in checks.items():
    got = fill_of(pid)
    assert got == want, '%s 色值错误: got %s want %s' % (pid, got, want)

S = []
S.append('<?xml version="1.0" encoding="UTF-8"?>')
S.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="108" height="108">')
S.append('<!-- 玩家机甲：用户绘制，色值全部归位现役4阶。')
S.append('     明度账：受光#3c4148=肩甲+枪身一整块 → 中值#2e3238=躯干/近小腿 → 暗板#26292e=胯/近大腿/近足/大臂/胸-肩/喷口/枪管 → 最深#1d2024=腰/小臂/腿-远。')
S.append('     橙#ffa04a：胸口前坡传感器竖条(躯干组内层级) + 喷口辉光。无头无眼（设计如此）。 -->')
S.append('<g transform="translate(2,2) scale(0.3377) translate(-329,-474)">')
S.append(body)
S.append('</g>')
S.append('</svg>')

open(OUT, 'w', encoding='utf-8').write('\n'.join(S))
print('OK written', sum(len(x) for x in S))
