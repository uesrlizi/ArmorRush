class_name BalanceWorld3
## 第三章（雪原）调参：电浆布雷车 + 强袭悬空机甲「哨兵」+ 电浆浮雷——本章数值唯一出处，章设计正本见 design/worlds.md。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。（原 scripts/core/balance.gd 拆分）
## 跨章共用件见 balance_combat.gd（重击导弹/失衡/机枪流基准档）。
# ---- 电浆浮雷（第三章精英/BOSS 共用：高抛入位→蓄能→近炸的空中封锁件） ----
# 惩罚账（art_proposals/snowfield_ch3/提案_v2 §2 几何账）：雷悬「当地地表−100」、
# 玩家站立中心=地表−30 → 雷人距恒 70：侦测 110 → 引信 0.28 → 站雷下必吃；
# 跑动穿越引信期内位移 168（冲刺 252）>判定 106 → 冲过免；跳跃顶点距 4 →
# 跳=吃（台阶口起跳是重点猎物）。蓄能期不引信（落雷到引信读得出承诺窗）。
# 寿命到点哑熄（无伤淡出）——雷是空间封锁不是雷管，等待永远是合法反制。
const PLASMA_MINE_HOVER_CLEAR := 100.0 # 悬停净空：当地地表上方
const PLASMA_MINE_WARMUP := 0.7        # 蓄能时长（渐显=变危险的二段预警，期间不引信）
const PLASMA_MINE_PROXIMITY := 110.0   # 近炸侦测半径（无宽限：宽限只给伤害判定）
const PLASMA_MINE_FUSE := 0.28         # 引信时长（快闪）：跑动穿越的免雷窗口
const PLASMA_MINE_LIFETIME := 4.5      # 悬停寿命，到点哑熄（无伤淡出）
const PLASMA_MINE_DAMAGE := 10
const PLASMA_MINE_BLAST_RADIUS := 80.0
const PLASMA_MINE_FENCE_SPACING := 280.0 # 布雷带间距（>爆球直径 160：不连锁、缝可读）

# ---- 第三章精英·电浆布雷车（垂发高抛浮雷，落点=按玩家速度推算的前方承诺带） ----
# 教学位：把白鲸的「浮雷封锁」提前教给玩家——读落点、承诺通过/绕行/等哑熄。
const ELITE_MINE_SCORE := 60
const ELITE_MINE_ATTACK_RANGE := 2200.0
const ELITE_MINE_VOLLEY_HALF_LIFE := 2.4 # 齐射触发半衰期（同 ch1/ch2 精英的泊松节奏）
const ELITE_MINE_VOLLEY_COUNT := 3     # 同帧齐布（v2.1 2→3 弹数下限上调；一次性撒布，非逐孔梯次）
const ELITE_MINE_LEAD_MIN := 150.0     # 承诺带基点距玩家最近（停着不动雷也落在脚下前方）
const ELITE_MINE_LEAD_MAX := 700.0
const ELITE_MINE_FLIGHT := 0.85        # 高抛飞行时长（弹道解算用，弧顶≈+370px 屏内）

# ---- 第三章 BOSS·强袭悬空机甲「哨兵」（260×180 机体 hover 370：足底 460=t2 ----
# 站立头顶上方 10px、对最高台阶 536 净空 76px；高度与 ch1 直升机同档、宽度放开，
# 碰撞 246×168）。招式=电浆弹雨 ⇄ 浮雷封锁（**一次性齐撒**：预警后全数同帧出舱，
# 与臼炮逐孔梯次读法分家），间插电浆枪直瞄普攻（plasma_bolt.tscn=bullet.gd 纯
# 换皮，速度/伤害复用 BOSS_SWEEP_*）。弹雨：肩部 4 垂发仓口（画布 x71/87/151/167）
# 逐孔轮发 PlasmaMissile——HeavyMissile 纯视觉换皮（追踪/爆炸语法同 ch1 弹雨，
# 见 plasma_missile.gd）。布雷：腰部布雷舱（BayPort 画布 (122,138)）撒布承诺带
# （间距 FENCE_SPACING 有缝）。
const SENTINEL_HOVER_Y := 370.0
const SENTINEL_RAIN_COUNT := 4         # 一轮电浆导弹=4 仓口 1:1（phase2 +2 回绕）
const SENTINEL_RAIN_STAGGER := 0.26
const SENTINEL_RAIN_DAMAGE := 10
const SENTINEL_RAIN_BLAST_RADIUS := 70.0
const SENTINEL_RAIN_RECOVER := 1.4
const SENTINEL_MINE_COUNT := 4         # 一轮齐撒雷数（v2.1 3→4 弹数下限上调；phase2 +1）
const SENTINEL_MINE_LEAD_MIN := 150.0
const SENTINEL_MINE_LEAD_MAX := 1000.0
const SENTINEL_MINE_FLIGHT := 0.55     # 齐撒抛送-悬停入位时长（ST_MINE_FIRE 窗=此值+0.35）
const SENTINEL_MINE_RECOVER := 1.3
const SENTINEL_PHASE2_RAIN_BONUS := 2
const SENTINEL_PHASE2_MINE_BONUS := 1
