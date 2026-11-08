class_name BalanceWorld9
## 第九章（雷暴线场）调参：放线车「架线」+ 浮空巡线舰「引雷」+ 跨缆/引雷针链/
## 断缆甩弧——本章数值唯一出处，章设计正本见 design/worlds.md + 威胁设计
## art_proposals/storm_ch9/威胁设计_ch9.md（§0 唯一参照系、§5 数值表；终审 R1-R16 裁定）。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。
## 跨章共用件见 balance_combat.gd（失衡/后摇/走位框架/MORTAR_GRAVITY）。
## 时间原点约定（R13）：每一手的全部时刻从**发射方 ThreatFlash 亮起 t=0** 起算，
## lead 也在 t=0 采样（玩家位置 px、速度 vx）。高度 h = 地表 g − 世界 y（向上为正）。

# ---- 跨缆 LiveSpan（第九章核心危险件：双桩 + 桩顶直缆，见 live_span.gd） ----
# 读法只看桩高：高缆 H110（判定带 h∈[102,118]，站立头顶 60 余量 42）=贴地钻过、
# 别跳（纯跳 0.109s 头顶升过 102）；低缆 H40（带 h∈[32,48]）=站着必被打，
# 有效横宽 376（R8：320+2×(玩家半宽 20+半厚 8)）> 纯跳 h≥48 窗 329px → 纯跳
# 过不去，按住推进（0.13s 后 h≥48）飞越或刹停等熄。
# 时序（R13）：闪光 0.6 → 双桩出膛（梯次 0.1，各自飞到 t=1.3 同时落地）→ 紧绷
# 灰缆 idle 0.3（无伤）→ 爬电 0.6（电花 A→B，无伤）→ 带电 [2.2, 3.2]（伤 10，
# 触一次整套溃散；否则寿命到点熄灭）。
const LIVE_SPAN_WARN := 0.6         # 发射方 ThreatFlash 驻留（出膛前）
const LIVE_SPAN_FLIGHT := 0.7       # 首桩飞行（t=0.6 出膛 → 1.3 落地）
const LIVE_SPAN_STAGGER := 0.1      # 次桩晚 0.1 出膛、飞 0.6，同刻落地
const LIVE_SPAN_IDLE := 0.3         # 紧绷灰缆（无伤）
const LIVE_SPAN_CRAWL := 0.6        # 爬电（二段预警，无伤）
const LIVE_SPAN_LIVE := 1.0         # 带电期（唯一判定期）
const LIVE_SPAN_LENGTH := 320.0     # 跨距（缆 [x1, x1+320]）
const LIVE_SPAN_HIGH_H := 110.0     # 高桩高 = 高缆高
const LIVE_SPAN_LOW_H := 40.0       # 低桩高 = 低缆高
const LIVE_SPAN_HALF_THICK := 8.0   # 缆判定半厚（玩家 AABB 40×60 到缆线段距离 ≤8）
const LIVE_SPAN_DAMAGE := 10
# 落位（R13）：x1 = px − 160 + clamp(vx·2.1, −400, 1260)。站桩=缆以玩家为中心；
# 满速 x1=1100、缆 [1100,1420]，t=2.2 带电时玩家中心 1320 正在缆下。
const LIVE_SPAN_LEAD_TIME := 2.1
const LIVE_SPAN_LEAD_MIN := -400.0
const LIVE_SPAN_LEAD_MAX := 1260.0
# 平移（R6）：只许向前 +X，≤160（32px 步进重试），带电时刻补 +位移/600（idle 延长）；
# 超上限取消本次。同台（跨度内每 32px 采样 surface_y_at 不变档）+ 脚手架避让
# （R7：[x1−40, x1+360] 不与 floating obstacles 的 x 区间重叠）都走这把尺。
const LIVE_SPAN_SHIFT_MAX := 160.0
const LIVE_SPAN_SHIFT_STEP := 32.0
const LIVE_SPAN_SHIFT_SPEED := 600.0   # 补时口径：位移/600（=玩家满速）
const LIVE_SPAN_SCAFFOLD_PAD_L := 40.0
const LIVE_SPAN_SCAFFOLD_PAD_R := 40.0 # x1+320+40 = x1+360
const LIVE_SPAN_TIER_SAMPLE := 32.0

# ---- 第九章精英·放线车「架线」（固定射角桩炮架，单套跨缆，高/低轮流） ----
# 教学位：只预教 BOSS 技能 A 跨缆（同一件两种相反解法=全章最难读的一手）。
# 第一套固定高缆（先教「别跳」），第二套低缆（再教「飞或刹」），此后交替。
# 冷却闸（R5）：自己上一套熄灭/溃散前不出新套（live_spans 组同主存活 ≤1）。
const ELITE_STRINGER_SCORE := 60
const ELITE_STRINGER_ATTACK_RANGE := 2200.0
const ELITE_STRINGER_VOLLEY_HALF_LIFE := 2.4 # 同八章精英泊松节奏（叠套由冷却闸压住）

# ---- 第九章 BOSS·浮空巡线舰「引雷」（300×180 门型横担机体 hover 370：船底 460、
# 对最高台阶 536 净空 76，同驳船/哨兵/…/盐磨档）。轮换 A 跨缆网 → 普攻 → B 引雷针链
# → 普攻；后摇 A 1.3 / B 1.4 / 普攻 BOSS_DIRECT_RECOVER 0.9，p2 ×0.6（框架）。 ----
const CONDUCTOR_HOVER_Y := 370.0

# 技能A 跨缆网：腹舱双桩口（BayPort）预警 → 跨缆。p1 一套、高/低每轮交替；
# p2 两段固定先高后低：第二段 x1′ = 第一段末端 + 360，带电晚 0.6（R14：满速
# 高缆 [1100,1420] 带电 [2.2,3.2]，低缆 [1780,2100] 带电 [2.8,3.8]；中心 2.413s
# 出高缆带、2.92s 进低缆带，换层窗 [2.413, 2.79] = 0.377s）。读法链=先钻后飞。
const CONDUCTOR_SPAN_P2_GAP := 360.0
const CONDUCTOR_SPAN_P2_LIVE_DELAY := 0.6
const CONDUCTOR_SPAN_RECOVER := 1.3

# 技能B 引雷针链（罚跳 + 罚贴针停 + 罚满速直冲，R1/R12）：背部 RodPorts 逐孔
# ThreatFlash [0,0.6] → 逐孔出针（飞 0.6，梯次 0.1：针1 落地 1.2/针2 1.3/针3 1.4
# [p2 针4 1.5]）→ 针尖充能环渐急（针1 充能 [1.2,2.2]，无伤）→ 放电：针1 在 2.2，
# 之后每 0.25s（p2 0.2）跳下一根。放电=Muzzle→针1 主弧/针k−1→针k 跳弧（线段
# ±8，存活 0.15s，伤 8）+ 该针底爆（GroundBlast r90 贴地，伤 10）。针高 120 →
# 弧带 h∈[112,128]：站立头顶 60 余量 52=站缝安全，跳到弧带=挨弧。
# 落位（R12）：针1 = px + clamp(vx·1.95, −300, 1170)，其余每根 +300。
# 满速针位 1170/1470/1770（p2 2070）：直冲 t=2.45 正压针2 底爆吃 10；解一停进缝心
# 1320（t≈2.03 起刹于 1220）；解二停针列前 ≤1040（t≤1.57 起刹于 ≤940）。
const ROD_WARN := 0.6
const ROD_FLIGHT := 0.6
const ROD_STAGGER := 0.1
const ROD_CHARGE := 1.0
const ROD_HOP := 0.25
const ROD_P2_HOP := 0.2
const ROD_HEIGHT := 120.0
const ROD_ARC_HALF_THICK := 8.0
const ROD_ARC_LIFE := 0.15
const ROD_BURST_RADIUS := 90.0
const ROD_BURST_DAMAGE := 10
const ROD_ARC_DAMAGE := 8
const ROD_COUNT := 3
const ROD_P2_BONUS := 1
const ROD_SPACING := 300.0
const ROD_LEAD_TIME := 1.95
const ROD_LEAD_MIN := -300.0
const ROD_LEAD_MAX := 1170.0
const ROD_SCAFFOLD_PAD := 110.0     # R7：各针 ±110 不得与 floating obstacles 重叠（重叠后移 +300 重试一次）
const CONDUCTOR_ROD_RECOVER := 1.4

# ---- 断缆甩弧 ArcLash（第九章 BOSS 普攻：arc_lash.tscn=bullet.gd 纯换皮直线弹） ----
# R11 几何：出膛点=Muzzle global_position（悬浮静姿 ≈ (x_p+1332, 306)），瞄出手
# 瞬间玩家中心（无预判无逐发跟踪）。满速保持：相对速度 ≈600+700=1300，t≈1.025s
# 在 x_p+615 相遇，弹线该处高出玩家中心 ~92 > 37 → 保持前跑可钻过弹；弹线在
# x_p−200 扎地埋掉；静止/刹停=吃 12；纯跳可越（h≥37 窗 0.625s > 扫过 0.24s）。
# 读法=「罚停留」。p2 双发各自重瞄。普攻不挂 ThreatFlash（换形四家惯例）。
const ARC_LASH_SPEED := 700.0
const ARC_LASH_DAMAGE := 12
const ARC_LASH_DELAY := 0.12        # 放电球一闪的预备拍（方向锁定在出手瞬间）
const ARC_LASH_TWIN_GAP := 0.15
const ARC_LASH_P2_BONUS := 1
