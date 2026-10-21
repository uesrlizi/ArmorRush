# -*- coding: utf-8 -*-
# 玩家机甲提案 · 现有素材画风版
# 画风账（对齐 assets/player_mech_body.svg / enemy_rust_walker_body.svg）：
#   纯平涂零描边；玩家=冷炭黑 4 阶(#1d2024/#26292e/#2e3238/#3c4148)+橙 #ffa04a；
#   发光=实心小块+同形低透明(0.18)光晕；体块分离靠明度差和 1px 级深色缝(深色底形)。
# 比例账：画布 132x112（游戏内尺寸级），朝右，脚底 y=97，整机高 ~95 宽 ~112（含前伸枪）——短粗。
# 形状语言账（提炼自用户描形）：肩甲断顶线/头下沉露脸/胸口浮板/后高前低楔形躯干/
#   逆关节小腿(后膝块+前倾刃+后刺)/长趾护趾脚/双轨步枪低持/块间深色缝。
# 部件组（可拆件，对应用户命名）：pack/leg-far/waist/hip/torso/chest-top/thigh/foot/shin/gun/forearm/upperarm/head/pauldron/antenna

S = []
A = S.append
A('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -12 132 112" width="132" height="112">')
A('<!-- 玩家机甲提案 v1：形状语言提炼自用户正侧描形，画风对齐现役素材（平涂/炭黑4阶/橙强调）。朝右，脚底 y=97。 -->')

A('<!-- 远侧腿（最深，几乎藏于近侧腿后） -->')
A('<g id="leg-far">')
A('  <polygon points="30,44 46,42 50,66 44,84 28,84 24,60" fill="#1d2024"/>')
A('  <polygon points="20,86 48,84 52,90 48,96 22,96" fill="#1d2024"/>')
A('</g>')

A('<!-- 背包（补自参考图） -->')
A('<g id="pack">')
A('  <polygon points="14,18 30,8 40,12 42,34 34,44 18,42" fill="#26292e"/>')
A('  <polygon points="18,20 32,12 38,15 39,32 32,40 22,38" fill="#2e3238"/>')
A('  <rect x="24" y="18" width="10" height="6.5" fill="#ffa04a" opacity="0.18"/>')
A('  <rect x="26" y="20" width="6" height="2.5" fill="#ffa04a"/>')
A('</g>')

A('<!-- 腰 -->')
A('<g id="waist">')
A('  <rect x="58" y="26" width="26" height="12" fill="#1d2024"/>')
A('  <polygon points="62,27 68,27 64,37 58,37" fill="#ffa04a" opacity="0.85"/>')
A('</g>')

A('<!-- 胯 -->')
A('<g id="hip">')
A('  <polygon points="48,34 90,34 94,46 86,54 56,54 44,44" fill="#26292e"/>')
A('  <polygon points="54,38 86,38 89,45 84,50 60,50 50,44" fill="#2e3238"/>')
A('  <circle cx="70" cy="46" r="5" fill="#1d2024"/>')
A('</g>')

A('<!-- 躯干（后高前低楔形） -->')
A('<g id="torso">')
A('  <polygon points="38,18 78,14 96,26 94,42 84,50 58,50 42,46 34,30" fill="#2e3238"/>')
A('  <polygon points="44,20 76,16 92,27 90,40 66,46 44,42" fill="#3c4148"/>')
A('  <polygon points="80,44 90,40 94,42 86,49" fill="#26292e"/>')
A('  <rect x="86" y="34" width="8" height="2" fill="#1d2024" opacity="0.8"/>')
A('  <rect x="86" y="38" width="8" height="2" fill="#1d2024" opacity="0.8"/>')
A('  <rect x="91" y="26" width="3.5" height="9" fill="#ffa04a" opacity="0.9"/>')
A('</g>')

A('<!-- 躯干-肩（胸口浮板） -->')
A('<g id="chest-top">')
A('  <polygon points="54,10 90,6 98,18 92,32 58,30" fill="#3c4148"/>')
A('  <polygon points="56,12 88,9 94,18 90,29 60,27" fill="#2e3238"/>')
A('</g>')

A('<!-- 大腿 -->')
A('<g id="thigh">')
A('  <polygon points="56,38 76,36 80,58 72,68 56,64 50,50" fill="#26292e"/>')
A('  <polygon points="60,42 74,40 77,56 70,63 60,60" fill="#2e3238"/>')
A('</g>')

A('<!-- 脚（长趾+护趾） -->')
A('<g id="foot">')
A('  <polygon points="32,86 44,82 58,84 82,84 86,90 85,97 33,97" fill="#26292e"/>')
A('  <polygon points="36,87 78,86 82,92 81,95 36,95" fill="#2e3238"/>')
A('  <polygon points="64,82 82,84 86,90 85,95 70,94" fill="#3c4148"/>')
A('  <rect x="34" y="94" width="46" height="3" fill="#1d2024"/>')
A('  <circle cx="62" cy="85" r="3" fill="#1d2024"/>')
A('</g>')

A('<!-- 小腿（逆关节：后膝块+前倾刃+后刺） -->')
A('<g id="shin">')
A('  <polygon points="52,52 64,50 74,56 72,68 68,82 60,88 48,84 44,72 46,60" fill="#26292e"/>')
A('  <polygon points="56,56 68,54 70,64 66,78 60,84 52,78 50,64" fill="#2e3238"/>')
A('  <polygon points="50,54 66,52 68,62 56,64" fill="#3c4148"/>')
A('  <polygon points="48,48 54,44 56,52 52,54" fill="#3c4148"/>')
A('  <circle cx="60" cy="60" r="3.5" fill="#1d2024"/>')
A('  <line x1="54" y1="56" x2="66" y2="62" stroke="#3c4148" stroke-width="1.5"/>')
A('</g>')

A('<!-- 枪（双轨步枪，低持前指） -->')
A('<g id="gun">')
A('  <polygon points="62,46 70,44 122,68 124,78 114,80 62,58" fill="#1d2024"/>')
A('  <polygon points="64,48 120,71 121,75 66,55" fill="#2e3238"/>')
A('  <polygon points="60,42 76,40 80,56 64,58" fill="#2e3238"/>')
A('  <rect x="66" y="37" width="8" height="3.5" fill="#26292e"/>')
A('  <circle cx="70" cy="38.7" r="1.8" fill="#ffa04a"/>')
A('  <polygon points="118,68 127,72 126,82 117,79" fill="#1d2024"/>')
A('  <polygon points="72,58 78,60 74,68 68,64" fill="#1d2024"/>')
A('  <polygon points="80,58 88,60 84,68 78,64" fill="#26292e"/>')
A('</g>')

A('<!-- 小臂+手 -->')
A('<g id="forearm">')
A('  <polygon points="56,44 64,40 90,56 84,64" fill="#26292e"/>')
A('  <polygon points="59,46 65,43 85,56 81,60" fill="#2e3238"/>')
A('  <circle cx="58" cy="46" r="3.5" fill="#1d2024"/>')
A('  <polygon points="84,56 94,60 90,70 80,64" fill="#26292e"/>')
A('</g>')

A('<!-- 大臂（大半藏肩甲下） -->')
A('<g id="upperarm">')
A('  <polygon points="52,38 64,36 66,50 54,52" fill="#26292e"/>')
A('</g>')

A('<!-- 头部（下沉，露于肩甲后上） -->')
A('<g id="head">')
A('  <polygon points="16,12 26,4 44,2 50,8 48,18 38,22 22,20" fill="#3c4148"/>')
A('  <polygon points="20,12 28,7 42,6 46,9 44,16 36,19 24,17" fill="#2e3238"/>')
A('  <rect x="38" y="6" width="11" height="8" fill="#ffa04a" opacity="0.18"/>')
A('  <rect x="40" y="8" width="7" height="4" fill="#ffa04a"/>')
A('  <rect x="30" y="16" width="8" height="1.5" fill="#1d2024" opacity="0.8"/>')
A('</g>')

A('<!-- 肩膀（大肩甲，断顶线，后向悬出） -->')
A('<g id="pauldron">')
A('  <polygon points="33,28 35,14 43,7 72,3 89,12 93,31 85,39 60,41 43,39" fill="#1d2024"/>')
A('  <polygon points="35,27 37,15 44,9 71,5 87,13 90,30 83,37 60,38 45,36" fill="#3c4148"/>')
A('  <polygon points="40,30 62,36 82,35 89,29 83,37 60,38 45,36" fill="#2e3238"/>')
A('</g>')

A('<!-- 天线（前扫） -->')
A('<g id="antenna">')
A('  <line x1="26" y1="4" x2="36" y2="-7" stroke="#1d2024" stroke-width="1.5"/>')
A('  <circle cx="36.5" cy="-8" r="1.6" fill="#ffa04a"/>')
A('</g>')

A('</svg>')
open(r'C:\Users\31715\Documents\GodotProject\2d-ac\art_proposals\mech\player_mech_proposal_v1.svg', 'w', encoding='utf-8').write('\n'.join(S))
print('written', sum(len(x) for x in S))
