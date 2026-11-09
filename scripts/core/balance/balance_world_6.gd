class_name BalanceWorld6
## 第六章（赤沙矿区）调参：打桩车「锚桩」+ 斗轮采集舰「赤轮」+ 电网闸/凿岩装药/斗轮抛石——本章数值唯一出处，章设计正本见 design/worlds.md。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。（原 scripts/core/balance.gd 拆分）
## 跨章共用件见 balance_combat.gd（重击导弹/失衡/机枪流基准档/臼炮重力）。
# ---- 电网闸（第六章精英/BOSS 共用：锚桩落点→竖直电幕围栏，见 arc_fence.gd） ----
# 惩罚账（art_proposals/red_desert_ch6/提案_v1_赤沙矿区.md §2）：两桩钉玩家
# 当时位置两侧（无 lead——「桩钉住你现在的位置」就是机制），预警→桩飞→蓄能
# 全程 ~1.3s 后幕立起：全速跑位移 780 > 半宽——**跑=免**；站桩/近战后摇
# （RECOVER_CONTROL 0.35）位移 ~270 留在带内=**被围**，出笼=触幕交税或
# 推进飞越（幕高 200：纯跳 apex 底 −103 跳不过）或等哑熄。触幕一次即整套
# 溃散（同潮墙「灼烧即溃」）；到点哑熄（无伤）——等待永远合法。

# ---- 第六章精英·打桩车「锚桩」（双桩炮架固定射角，落点围栏预教电网闸） ----
# 教学位：把「赤轮」的电网闸提前教给玩家——读桩落点与蓄能火花，
# 桩钉住的是你现在的位置：看到落桩就保持移动，停=被围。
const ELITE_PILER_SCORE := 60
const ELITE_PILER_ATTACK_RANGE := 2200.0
const ELITE_PILER_VOLLEY_HALF_LIFE := 2.4 # 齐射触发半衰期（同前五章精英的泊松节奏）
const ELITE_PILER_FENCE_HALF := 140.0  # 桩落点半宽（笼内=被围）
const ELITE_PILER_FENCE_TOP := 150.0   # 幕高（纯跳 apex 底 −103 跳不过，教学纯净版幕稍矮）
const ELITE_PILER_FENCE_WARMUP := 0.8  # 桩上火花蓄能（二段预警，比 BOSS 版多留 0.1s 读）
const ELITE_PILER_FENCE_LIFE := 1.6    # 幕存活时长，到点哑熄（无伤）
const ELITE_PILER_FENCE_DAMAGE := 12
const ELITE_PILER_STAKE_FLIGHT := 0.5  # 桩抛体飞行时长（弹道解算用）

# ---- 第六章 BOSS·斗轮采集舰「赤轮」（300×180 机体 hover 370：船底 460=t2 ----
# 站立头顶上方 10px；最低点=斗轮缘 454（bob 后对最高台阶 536 净空 76），同
# 驳船/哨兵/灯笼鱼/截击机档。招式=电网闸 ⇄ 凿岩齐射（腹舱抛装药封跑线路径，
# 见 DRILL_CHARGE 段），间插斗轮抛石普攻（见 REDWHEEL_LOB 段：斗轮提速吐料→
# 朝玩家当时位置抛弹石群，机枪短梭已废）。分工账：电网闸 hunts 滞留者（笼+税：
# 停=围/动=免/出笼交税或飞越），凿岩齐射 hunts 匀速跑线路径（lead 走廊），抛石
# 落点锁定 hunts 站桩与直线冲脸——玩家被迫在站/跑/飞三态间换挡，反制=变速变向
# （相对速度语言，ch2/ch4 同族）。
const REDWHEEL_HOVER_Y := 370.0
const REDWHEEL_FENCE_HALF := 200.0     # 桩落点半宽（笼内=被围）
const REDWHEEL_FENCE_TOP := 200.0      # 幕高（推进 ≥204 飞越=免）
const REDWHEEL_FENCE_WARMUP := 0.7     # 桩上火花蓄能（p2 0.55：跑=免的窗口收窄）
const REDWHEEL_FENCE_LIFE := 2.2       # 幕存活时长
const REDWHEEL_FENCE_DAMAGE := 15
const REDWHEEL_FENCE_LEAD_MAX := 400.0 # 半 lead：落带中心按玩家速度前/后移的上限
									   # （惩罚缓移与后撤，全速跑仍出带）
const REDWHEEL_FENCE_RECOVER := 1.3
const REDWHEEL_STAKE_FLIGHT := 0.55    # 桩抛体飞行时长（弹道解算用）
const REDWHEEL_PHASE2_FENCE_WARMUP := 0.55

# ---- 凿岩装药（第六章 BOSS 技能B：lead 走廊 + 定延时起爆，见 drill_charge.gd） ----
# 惩罚账（art_proposals/red_desert_ch6/提案_v1_赤沙矿区.md §2b）：装药抛体解算
# 落到玩家前进路径上，**落点即静止**（钉在落点路面，零地形跟随——贴地跑行类
# 已判死：台阶瞬移，同珊瑚潮 v1 死因），落点=玩家速度×(飞行+引信) clamp 半 lead
# ——匀速直线跑被装药线封在走廊里（尾弹贴着跑者爆），站桩=装药落在脚下
# （飞行 0.7 + 引信 1.0 ≈1.7s 反应窗内跑离爆区=免）；变速/变向=装药落在身后。
# 引信期红灯渐急=二段预警；到点一次性球爆（无驻留区）。间距 > 爆球直径：
# 不连锁、缝可读。
const REDWHEEL_CHARGE_COUNT := 3        # 一轮装药数（p2 +1：走廊拉长）
const REDWHEEL_CHARGE_STAGGER := 0.18   # 出膛梯次
const REDWHEEL_CHARGE_FLIGHT := 0.7     # 抛体飞行时长（MORTAR_GRAVITY 解算用）
const REDWHEEL_CHARGE_FUSE := 1.0       # 落地定延时起爆（红灯渐急=二段预警）
const REDWHEEL_CHARGE_DAMAGE := 15
const REDWHEEL_CHARGE_RADIUS := 120.0
const REDWHEEL_CHARGE_SPACING := 260.0  # 装药间距（>爆球直径 240：不连锁、缝可读）
const REDWHEEL_CHARGE_LEAD_MAX := 700.0 # 半 lead：走廊中心前/后移的上限
const REDWHEEL_CHARGE_RECOVER := 1.3
const REDWHEEL_PHASE2_CHARGE_BONUS := 1

# ---- 斗轮抛石（第六章 BOSS 普攻：斗轮=武器。2026-11-02 替掉机枪短梭） ----
# 弹=red_lob.tscn（bullet.gd 抛体语法 gravity>0，与 red_chip 直射弹分家登记）。
# 每枚按 Bullet.solve_lob_velocity 解到玩家**出手瞬间**位置（无 lead、无跟踪），
# 再按序号在固定扇里错开初速方向——石群落点围着玩家当时位置散布：站桩/直线
# 冲脸=吃，看弧线挪位=免；弧线从头顶盖下来，滞空不免费。抛体不贴地（贴地跟随
# 类已判死），落地即 ImpactBurst 迸溅。提速吐料的一拍=读法（普攻不挂预警闪）。
const REDWHEEL_LOB_COUNT := 5           # 一轮弹石数（p2 +1；石群落点散布，受击无敌窗内多石只结算一石）
const REDWHEEL_LOB_DAMAGE := BalanceCombat.BOSS_SWEEP_DAMAGE # 跨文件引用：机枪流基准档（balance_combat.gd）。单石同机枪档：威胁分层不变，autotest 排空闸按此值数
const REDWHEEL_LOB_GRAVITY := 2000.0    # 抛体重力：MORTAR 4000 的一半、玩家上升 1200 的 1.7×——弧看得见、落得干脆
const REDWHEEL_LOB_RANGE_SPEED := 1000.0 # 飞行时长=水平距/此值（再 clamp）：远=飞久弧高
const REDWHEEL_LOB_FLIGHT_MIN := 0.6
const REDWHEEL_LOB_FLIGHT_MAX := 1.2    # 构图位 ~1100 时 ≈1.1s；探针 1400 处封顶
const REDWHEEL_LOB_SPREAD_STEP_DEG := 6.0 # 相邻石初速方向夹角（5 石=±12°，落点簇宽 ≈±200）
const REDWHEEL_LOB_WINDUP := 0.3        # 斗轮提速吐料的一拍
const REDWHEEL_LOB_STAGGER := 0.09      # 逐石出膛节拍（轮转一格一石）
const REDWHEEL_PHASE2_LOB_BONUS := 1
