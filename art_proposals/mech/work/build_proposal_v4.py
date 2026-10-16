# -*- coding: utf-8 -*-
# 玩家机甲提案 v4 · 单值大块版
# 铁律：每个形状只有一个值，无内嵌面/无描边/无渐变；相邻形状明度差≥2档
# 玩家色账：#1d2024 最深(框架/远侧/枪) → #26292e 暗板 → #2e3238 中板 → #3c4148 受光板
# 橙 #ffa04a 仅3处：面甲(+光晕) / 胯斜纹 / 躯干感应条

S = []
A = S.append
A('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -24 132 124" width="132" height="124">')
A('<!-- 玩家机甲提案 v4：形状语言提炼自用户正侧描形；单值大块平涂，画风对齐现役素材。朝右，脚底 y=97。 -->')

A('<g id="leg-far">')
A('  <polygon points="26,46 44,44 48,68 42,84 28,84 24,62" fill="#1d2024"/>')
A('  <polygon points="20,86 46,84 50,92 46,96 24,96" fill="#1d2024"/>')
A('</g>')

A('<g id="pack">')
A('  <polygon points="12,20 28,10 40,14 42,34 34,44 16,42" fill="#26292e"/>')
A('  <rect x="22" y="18" width="10" height="6.5" fill="#ffa04a" opacity="0.18"/>')
A('  <rect x="24" y="20" width="6" height="2.5" fill="#ffa04a"/>')
A('</g>')

A('<g id="hip">')
A('  <polygon points="50,44 88,44 93,55 85,62 56,62 45,53" fill="#1d2024"/>')
A('  <polygon points="56,47 64,47 60,60 52,60" fill="#ffa04a" opacity="0.85"/>')
A('</g>')

A('<g id="torso">')
A('  <polygon points="36,16 80,10 98,26 94,42 82,48 56,48 40,42" fill="#2e3238"/>')
A('  <polygon points="56,40 94,34 92,42 82,48 58,48" fill="#26292e"/>')
A('  <rect x="89" y="33" width="3.5" height="9" fill="#ffa04a" opacity="0.9"/>')
A('</g>')

A('<g id="thigh">')
A('  <polygon points="56,54 78,52 82,70 74,78 58,76 50,62" fill="#2e3238"/>')
A('</g>')

A('<g id="foot">')
A('  <polygon points="30,84 44,80 60,82 82,82 86,88 85,97 31,97" fill="#26292e"/>')
A('  <polygon points="60,80 82,82 86,88 85,93 64,92" fill="#3c4148"/>')
A('  <rect x="32" y="94" width="48" height="3" fill="#1d2024"/>')
A('</g>')

A('<g id="shin">')
A('  <polygon points="50,62 66,60 76,66 74,78 68,88 56,90 46,84 44,72" fill="#1d2024"/>')
A('  <polygon points="50,64 66,62 68,72 56,74" fill="#3c4148"/>')
A('</g>')

A('<g id="gun">')
A('  <polygon points="60,46 68,44 122,68 124,78 114,80 60,58" fill="#1d2024"/>')
A('  <polygon points="62,48 120,70 121,74 64,55" fill="#2e3238"/>')
A('  <polygon points="118,68 127,72 126,82 117,79" fill="#1d2024"/>')
A('</g>')

A('<g id="forearm">')
A('  <polygon points="56,44 64,40 90,56 84,64" fill="#26292e"/>')
A('  <polygon points="84,56 94,60 90,70 80,64" fill="#1d2024"/>')
A('</g>')

A('<polygon id="upperarm" points="52,40 64,38 66,52 54,54" fill="#1d2024"/>')

A('<g id="head">')
A('  <polygon points="22,-4 32,-12 48,-13 54,-7 52,1 42,8 28,8" fill="#3c4148"/>')
A('  <rect x="40" y="-9" width="11" height="8" fill="#ffa04a" opacity="0.18"/>')
A('  <rect x="42" y="-7" width="7" height="4" fill="#ffa04a"/>')
A('</g>')

A('<g id="pauldron">')
A('  <polygon points="52,44 48,18 60,6 80,4 102,14 106,32 96,44 68,46" fill="#1d2024"/>')
A('  <polygon points="55,41 51,19 62,8 79,6 99,15 103,31 94,42 68,43" fill="#3c4148"/>')
A('</g>')

A('<g id="antenna">')
A('  <line x1="34" y1="-13" x2="44" y2="-21" stroke="#1d2024" stroke-width="1.5"/>')
A('  <circle cx="44.5" cy="-22" r="1.6" fill="#ffa04a"/>')
A('</g>')

A('</svg>')
open(r'C:\Users\31715\Documents\GodotProject\2d-ac\art_proposals\mech\player_mech_proposal_v1.svg', 'w', encoding='utf-8').write('\n'.join(S))
print('written', sum(len(x) for x in S))
