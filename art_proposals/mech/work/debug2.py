# -*- coding: utf-8 -*-
# 调试2：全量探针
import re

src = open(r'C:\Users\31715\Documents\GodotProject\2d-ac\art_proposals\mech\手动绘制机甲.svg', encoding='utf-8').read()
body = src[src.index('<g id="_腿-远"'):src.index('</svg>')]

body = body.replace('class="cls-1"', 'fill="#2e3238"')
body = body.replace('class="cls-2"', 'fill="#26292e"')
body = body.replace('class="cls-3"', 'fill="#1d2024"')
body = body.replace('class="cls-4"', 'fill="#3c4148"')

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
print('overrides len:', len(overrides))
for pid, color in overrides:
    before = body
    body = re.sub(r'(id="%s"[^>]*?)class="[^"]*"' % pid, r'\1fill="%s"' % color, body)
    body = re.sub(r'(id="%s"[^>]*?)fill="[^"]*"' % pid, r'\1fill="%s"' % color, body)
    m = re.search(r'<[^>]*%s[^>]*' % pid, body)
    f = re.search(r'fill="([^"]*)"', m.group(0)) if m else None
    print(pid, '-> want', color, '| got', f.group(1) if f else '??', '| body changed:', before != body)

m = re.search(r'<rect id="_大臂"[^>]*', body)
print('FINAL 大臂:', m.group(0)[:100])
