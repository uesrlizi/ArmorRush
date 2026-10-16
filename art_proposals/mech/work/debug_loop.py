# -*- coding: utf-8 -*-
# 调试：覆写循环内部观察
import re

src = open(r'C:\Users\31715\Documents\GodotProject\2d-ac\art_proposals\mech\手动绘制机甲.svg', encoding='utf-8').read()
body = src[src.index('<g id="_腿-远"'):src.index('</svg>')]

body = body.replace('class="cls-1"', 'fill="#2e3238"')
body = body.replace('class="cls-2"', 'fill="#26292e"')
body = body.replace('class="cls-3"', 'fill="#1d2024"')
body = body.replace('class="cls-4"', 'fill="#3c4148"')

print('--- base 之后:')
m = re.search(r'<rect id="_大臂"[^>]*', body)
print(m.group(0)[:100])
m = re.search(r'<rect id="_枪管"[^>]*', body)
print(m.group(0)[:100])

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
    before = body
    body = re.sub(r'(id="%s"[^>]*?)class="[^"]*"' % pid, r'\1fill="%s"' % color, body)
    body = re.sub(r'(id="%s"[^>]*?)fill="[^"]*"' % pid, r'\1fill="%s"' % color, body)
    if pid in ('_大臂', '_枪管'):
        m = re.search(r'<rect id="%s"[^>]*' % pid, body)
        print('--- after', pid, '->', color, '| changed:', before != body)
        print('   ', m.group(0)[:100])

print('--- 最终:')
m = re.search(r'<rect id="_大臂"[^>]*', body)
print(m.group(0)[:100])
