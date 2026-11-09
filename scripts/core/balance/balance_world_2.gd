class_name BalanceWorld2
## 第二章（精炼厂）调参：熔渣臼炮车 + 悬浮冶炼驳船 + 熔渣火区/臼炮弹道——本章数值唯一出处，章设计正本见 design/worlds.md。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。（原 scripts/core/balance.gd 拆分）
## 跨章共用件见 balance_combat.gd（重击导弹/失衡/机枪流基准档）。
# ---- 熔渣火区（第二章精英/BOSS 共用：驻留地面危险，tick 结算） ----
const SLAG_POOL_RADIUS := 90.0
const SLAG_POOL_DAMAGE := 4            # 每 tick 伤害（驻留 tick 不进受击无敌窗；站满一轮 ≈ 22~28）
const SLAG_POOL_TICK := 0.4            # tick 周期
const SLAG_POOL_WARMUP := 0.35         # 落地蓄热：开伤前缓冲（落地溅开→变危险，二段预警）
# ---- 臼炮弹飞行时长（弹道解算用；滑行段重力=MORTAR_GRAVITY，见 balance_combat.gd） ----
const ELITE_SLAG_FLIGHT := 0.7        # 臼炮车弹飞行时长（解算初速用）
const BARGE_SLAG_FLIGHT := 0.75       # 驳船臼炮弹飞行时长
# ---- 第二章精英·熔渣臼炮车（垂发高抛，落点=按玩家速度推算的前方路面） ----
# 教学位：把 BOSS 的"熔渣封路"提前教给玩家——读弧线、离开落点、跳越火区。
# 相对速度即机制：落点带 lead，匀速直线跑会一头扎进火区，躲=变速/绕行/跳越。
const ELITE_SLAG_SCORE := 60
const ELITE_SLAG_ATTACK_RANGE := 2200.0
const ELITE_SLAG_VOLLEY_HALF_LIFE := 2.4 # 齐射触发半衰期（同 ch1 精英的泊松节奏）
const ELITE_SLAG_VOLLEY_COUNT := 3   # v2.1 2→3（弹数下限统一上调，ch1 基准不动）
const ELITE_SLAG_VOLLEY_STAGGER := 0.35
const ELITE_SLAG_SHELL_DAMAGE := 0    # 落地无溅射伤害（火区才是威胁，教学纯净版）
const ELITE_SLAG_LEAD_MAX := 850.0    # 提前量上限（封路落点最远在前方这段）
const ELITE_SLAG_POOL_TIME := 2.2     # 精英火区驻留时长（BOSS 版更长）
# ---- 第二章 BOSS·悬浮冶炼驳船（300×180 船体 hover 370：船底 460=t2 站立头顶 ----
# 上方 10px、对最高台阶 536 净空 76px。招式=排炮弹幕墙 ⇄ 熔渣封路，间插排炮重弹
# 普攻（2026-11-02 机枪短梭→单发慢速熔渣重弹：弹体自读可跳越，出手锁定无跟踪；
# 后摇仍走 BOSS_DIRECT_RECOVER）。弹幕墙：船艏 3 真实炮位（wy 350/380/410，
# =画布 y70/100/130 舱门），基准俯角+每轮整体摆动（缝轮轮换）；每发出膛前沿射线
# 采样地形，埋弹抬角校平（至多 2 次），仍埋该炮本轮哑火（被地形挡住不打）。
const BARGE_HOVER_Y := 370.0
const BARGE_WALL_BASE_DEG := [1.0, 6.0, 11.0] # 三炮位基准俯角（左向开火，正=向下）
const BARGE_WALL_SWEEP_DEG := 3.0     # 每轮扇面整体摆动幅 ±（phase2 换 5）
const BARGE_WALL_FLATTEN_DEG := 3.0   # 埋弹校平抬角步长
const BARGE_WALL_FLATTEN_MAX := 2     # 校平次数上限，超出=该炮本轮哑火
const BARGE_WALL_SAMPLE_STEP := 80.0  # 射线地形采样步长
const BARGE_WALL_SAMPLE_RANGE := 1500.0
const BARGE_WALL_BURST := 5           # 每门发数（phase2 +2）
const BARGE_WALL_BURST_INTERVAL := 0.09
const BARGE_WALL_DAMAGE := 15         # 墙幕弹单发（技能档；同门一梭落在受击无敌窗内=吃一发）。弹体沿用机枪弹，伤害与机枪档分家；须≠BARGE_SLUG_DAMAGE（autotest 按伤害值分辨弹种）
const BARGE_WALL_PORT_STAGGER := 0.12 # 炮位梯次间隔
const BARGE_WALL_RECOVER := 1.3
const BARGE_SLAG_COUNT := 4           # 一轮熔渣弹=4 垂发孔 1:1（phase2 +2 回绕）
const BARGE_SLAG_STAGGER := 0.3
const BARGE_SLAG_RECOVER := 1.4
const BARGE_SLAG_DAMAGE := 12
const BARGE_SLAG_BLAST_RADIUS := 45.0 # 落地小溅射（BOSS 版比精英多这一口）
const BARGE_SLAG_POOL_TIME := 2.8
const BARGE_SLAG_LEAD_MAX := 900.0
const BARGE_PHASE2_SLAG_BONUS := 2
const BARGE_PHASE2_BURST_BONUS := 2
const BARGE_PHASE2_SWEEP_DEG := 5.0
const BARGE_SLUG_SPEED := 1000.0       # 排炮重弹（普攻）：机枪流 1000 的七成（2026-11-03 用户「太慢读不出炮弹」500→700），慢大弹仍可跳越
const BARGE_SLUG_DAMAGE := 12         # 单发普攻（本来就是重弹档，不随技能上调；技能弹 15 仍更疼）
const BARGE_SLUG_DELAY := 0.12        # 枪臂真瞄到位的一拍再点放（方向锁定在出手瞬间）
const BARGE_SLUG_TWIN_GAP := 0.15     # 二阶段双发间隔（第二发各自重瞄，仍是离散点放）
const BARGE_PHASE2_SLUG_BONUS := 1    # 二阶段 +1 发
