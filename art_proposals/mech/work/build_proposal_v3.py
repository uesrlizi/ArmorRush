# -*- coding: utf-8 -*-
# 玩家机甲提案 v3 · 大块化减法重画
# 原则：形状≤26、每部位最多两块、相邻明度差≥2档、橙色点缀全稿仅3处（面甲/腰斜纹/躯干感应条）
# 形状语言不变（用户描形提炼：双峰肩甲/头下沉/浮胸板/楔形躯干/逆关节刃小腿/护趾脚/低持长枪）

S = []
A = S.append
A('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -12 132 112" width="132" height="112">')
A('<!-- 玩家机甲提案 v3：大块减法版。平涂/炭黑4阶/橙点缀x3。朝右，脚底 y=97。 -->')

A('<g id="leg-far">')
A('  <polygon points="26,46 44,44 48,68 42,84 28,84 24,62" fill="#1d2024"/>')
A('  <polygon points="20,86 46,84 50,92 46,96 24,96" fill="#1d2024"/>')
A('</g>')

A('<g id="pack">')
A('  <polygon points="12,20 28,10 40,14 42,34 34,44 16,42" fill="#26292e"/>')
A('  <rect x="22" y="18" width="10" height="6.5" fill="#ffa04a" opacity="0.18"/>')
A('  <rect x="24" y="20" width="6" height="2.5" fill="#ffa04a"/>')
A('</g>')

A('<!-- 胯（含腰，橙色斜纹点缀2） -->')
A('<g id="hip">')
A('  <polygon points="50,44 88,44 93,55 85,62 56,62 45,53" fill="#1d2024"/>')
A('  <polygon points="56,47 64,47 60,60 52,60" fill="#ffa04a" opacity="0.85"/>')
A('</g>')

A('<!-- 躯干（楔形，橙色感应条点缀3） -->')
A('<g id="torso">')
A('  <polygon points="36,16 80,10 98,26 94,42 82,48 56,48 40,42" fill="#2e3238"/>')
A('  <rect x="91" y="28" width="3.5" height="9" fill="#ffa04a" opacity="0.9"/>')
A('</g>')

A('<!-- 大腿 -->')
A('<g id="thigh">')
A('  <polygon points="56,54 78,52 82,70 74,78 58,76 50,62" fill="#2e3238"/>')
A('</g>')

A('<!-- 脚 -->')
A('<g id="foot">')
A('  <polygon points="30,84 44,80 60,82 82,82 86,88 85,97 31,97" fill="#26292e"/>')
A('  <polygon points="60,80 82,82 86,88 85,93 64,92" fill="#3c4148"/>')
A('  <rect x="32" y="94" width="48" height="3" fill="#1d2024"/>')
A('</g>')

A('<!-- 小腿（逆关节刃） -->')
A('<g id="shin">')
A('  <polygon points="50,62 66,60 76,66 74,78 68,88 56,90 46,84 44,72" fill="#1d2024"/>')
A('  <polygon points="50,64 66,62 68,72 56,74" fill="#3c4148"/>')
A('</g>')

A('<!-- 枪 -->')
A('<g id="gun">')
A('  <polygon points="60,46 68,44 122,68 124,78 114,80 60,58" fill="#1d2024"/>')
A('  <polygon points="62,48 120,70 121,74 64,55" fill="#2e3238"/>')
A('  <polygon points="118,68 127,72 126,82 117,79" fill="#1d2024"/>')
A('</g>')

A('<!-- 小臂+手 -->')
A('<g id="forearm">')
A('  <polygon points="56,44 64,40 90,56 84,64" fill="#26292e"/>')
A('  <polygon points="84,56 94,60 90,70 80,64" fill="#1d2024"/>')
A('</g>')

A('<!-- 大臂 -->')
A('<polygon id="upperarm" points="52,40 64,38 66,52 54,54" fill="#1d2024"/>')

A('<!-- 头部（橙色面甲点缀1） -->')
A('<g id="head">')
A('  <polygon points="30,6 40,-2 56,-4 62,2 60,10 50,16 36,16" fill="#3c4148"/>')
A('  <rect x="48" y="-2" width="11" height="8" fill="#ffa04a" opacity="0.18"/>')
A('  <rect x="50" y="0" width="7" height="4" fill="#ffa04a"/>')
A('</g>')

A('<!-- 肩膀（双峰带谷，断顶线） -->')
A('<g id="pauldron">')
A('  <polygon points="44,34 40,16 52,4 74,2 94,12 98,30 88,42 60,44" fill="#1d2024"/>')
A('  <polygon points="47,31 44,17 54,7 73,5 90,14 93,29 85,39 61,41" fill="#26292e"/>')
A('  <polygon points="50,14 62,7 82,8 92,16 90,28 62,36" fill="#3c4148"/>')
A('</g>')

A('<!-- 天线 -->')
A('<g id="antenna">')
A('  <line x1="42" y1="-3" x2="52" y2="-12" stroke="#1d2024" stroke-width="1.5"/>')
A('  <circle cx="52.5" cy="-13" r="1.6" fill="#ffa04a"/>')
A('</g>')

A('</svg>')
open(r'C:\Users\31715\Documents\GodotProject\2d-ac\art_proposals\mech\player_mech_proposal_v1.svg', 'w', encoding='utf-8').write('\n'.join(S))
print('written', sum(len(x) for x in S))
