class_name BalanceEnemy
## 杂兵调参：步行炮台/状态机/物理击退/悬浮无人机/盾卫/敌弹——本域数值唯一出处。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。（原 scripts/core/balance.gd 拆分）
# ---- 敌人（步行炮台） ----
const ENEMY_MAX_HP := 20
const ENEMY_SCORE := 10
const ENEMY_ATTACK_RANGE := 1400.0

# ---- 精英（全章统一：血量只有这一份，不按章分；2026-11-04 定案，原每章一份×7） ----
const ELITE_MAX_HP := 25

# ---- 敌人状态机（移动/攻击两层独立，半衰期掷骰驱动：p = 1 - 2^(-Δt/t½)） ----
# 期望等待 = t½ / ln2 ≈ 1.44 × t½；帧率无关、无记忆（同波敌人天然错开开火）。
const ENEMY_MANEUVER_HALF_LIFE := 1.5  # 待机→机动的触发半衰期
const ENEMY_MANEUVER_SPEED := 130.0    # 机动平移速度（px/s）
const ENEMY_MANEUVER_DIST_MIN := 40.0  # 单次机动距离下限（px）
const ENEMY_MANEUVER_DIST_MAX := 140.0 # 单次机动距离上限（px）：短距离前后踱步
const ENEMY_FIRE_HALF_LIFE := 2.0      # 待机→扫射的触发半衰期
const ENEMY_BURST_MIN := 3             # 单次扫射发数下限
const ENEMY_BURST_MAX := 5             # 单次扫射发数上限
const ENEMY_BURST_INTERVAL := 0.11     # 扫射内发弹间隔（≈9 发/秒，另叠 ±20% 抖动）

# ---- 敌人物理（CharacterBody2D 重力 + 玩家攻击击退） ----
const ENEMY_GRAVITY := 1000.0          # 步行族下落重力（悬浮族/boss 不用）；与玩家下降段同级
const ENEMY_KNOCKBACK_GUN := 90.0      # 被枪弹命中的击退冲量（px/s，沿弹道方向）
const ENEMY_KNOCKBACK_MELEE := 280.0   # 被近战命中的击退冲量（px/s，沿玩家面朝方向）
const ENEMY_KNOCKBACK_DECEL := 600.0   # 击退滑行减速度（px/s²）：滑距 = v²/2a（枪 ~7px / 近战 ~65px）
const ENEMY_KNOCKBACK_MAX := 320.0     # 击退速度幅值上限（扫射连发逐发微推，不叠到飞出去）

# ---- 敌人（悬浮无人机：更小更脆的飞行单位） ----
const DRONE_MAX_HP := 10          # 步行者的半血：一发近战/两发子弹带走
const DRONE_SCORE := 5
const DRONE_HOVER_MIN := 60.0     # 出生抬升下限（地表到舱底）；上限保证近战竖向够得着
const DRONE_HOVER_MAX := 110.0    # （玩家碰撞中心离地 30、斩击竖向容差 105：60~110 全程可达）
const DRONE_BOB_AMPLITUDE := 8.0  # 悬停浮动幅度（px，整机浮动：舱体+枪臂+碰撞盒一起）
const DRONE_BOB_SPEED := 3.0      # 悬停浮动角速度（rad/s）

# ---- 敌人（盾卫：防御力挡弹不挡刀） ----
const SHIELD_MAX_HP := 30
const SHIELD_DEFENSE := 10        # 子弹 2 伤先扣 10 → 只蹭 1（结算下限 1）：打不动但不免疫
const SHIELD_SCORE := 25

# ---- 敌人子弹 ----
const ENEMY_BULLET_SPEED := 1040.0 # 原速 520 的两倍
const ENEMY_BULLET_DAMAGE := 3     # 杂兵一梭（3~5 发 ≤0.55s）落在受击无敌窗内=只结算一发
