class_name BalancePlayer
## 玩家调参：移动/跳跃/重力/自动开火/滑行火花/喷口/玩家子弹/近战/推进/死亡震动——本域数值唯一出处。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。（原 scripts/core/balance.gd 拆分）
# ---- 玩家 ----
const PLAYER_MAX_HP := 100
const PLAYER_MOVE_SPEED := 600.0 # 保留手调值（原 420）
const PLAYER_ACCELERATION := 1800.0 # 水平加/减速度（px/s²），速度不再瞬间突变
const PLAYER_JUMP_VELOCITY := -450.0
const PLAYER_GRAVITY_ASCENT := 1200.0  # 上升段重力
const PLAYER_GRAVITY_DESCENT := 800.0 # 下降段重力略减，模拟主动反推缓降
const PLAYER_FIRE_COOLDOWN := 0.22

# ---- 自动开火（唯一的开火方式，手动开火已移除：射程内有敌+连线无地形遮挡才打） ----
const PLAYER_AUTO_FIRE := true         # 总开关：false=不开枪（纯近战，没有手动兜底）
const PLAYER_AUTO_FIRE_RANGE := 1400.0 # 自动开火射程（与杂兵攻击距离同档：够得着你才还手）

# ---- 地面滑行火花 ----
const SLIDE_SPARK_MIN_SPEED := 220.0 # 贴地水平速度超过该值才刮火花
const SLIDE_SPARK_LAND_VY := 450.0   # 重落地踢火花的下坠速度门槛
# ---- 喷口可动摆动（玩家） ----
const NOZZLE_SWING_DEG := 35.0   # 喷口摆幅上限（度）：默认朝左下；纯前进抬向正后(+)，倒退/竖直推进/缓降压向正下(−)
const NOZZLE_TURN_SPEED := 240.0 # 喷口摆动速度（度/秒）
const NOZZLE_CRUISE_FLAME := 0.5 # 主焰纯前进巡航档（半焰；倒退时主焰熄火，只出视觉，推进声仍只跟真实推进走）
const NOZZLE_DASH_FLAME := 1.5   # 近战突进/斩击主焰过烧档（>1 超出旧上限，ThrusterFlame.MAX_LEVEL 放行）
const VERNIER_CRUISE_FLAME := 1.0 # 腰/腿姿控焰巡航档（全焰）
const VERNIER_DASH_FLAME := 1.5   # 近战突进/斩击腿焰过烧档（冲刺没有后退，腰焰不跟冲刺）

# ---- 玩家子弹 ----
const PLAYER_BULLET_SPEED := 2400.0
const PLAYER_BULLET_DAMAGE := 5
const BULLET_IMPACT_MIN_TRAVEL := 48.0 # 出膛后飞满这段才喷命中迸溅（贴脸撞墙不在枪口上开花）

# ---- 近战（AC6 式二段斩：停顿前摇 → 追击突进 → 斩击 → 后摇，全程滞空不下坠） ----
# 伤害账（两刀约束验算）：普通敌 20 HP —— 15<20 不至一刀秒、15+25≥40 两刀斩净；
# 盾卫 30 HP（近战绕盾全额）—— 15+15=30 恰好两刀，连段 15+25 更有余量。
const MELEE_DAMAGE_1 := 15          # 一段伤害（原 10，为盾卫"两刀必杀"抬到这里）
const MELEE_DAMAGE_2 := 25          # 二段伤害（原 15，同上）
const MELEE_WINDUP_TIME := 0.2     # 闲置起手前摇：明显的停顿滞空（架势）
const MELEE_WINDUP_COMBO_TIME := 0.05 # 连段衔接前摇：中间停顿短一点
const MELEE_DASH_SPEED := 900.0     # 追击突进速度（超过跑速，AC6 同款"加速突进斩"）
const MELEE_DASH_TIME_MAX := 0.45   # 突进时长上限：到点强制出刀（目标逃了就斩空）
const MELEE_STRIKE_RANGE := 150.0   # 目标进入该水平距离即发动斩击（竖向按 0.7 倍算）
const MELEE_STRIKE_TIME := 0.12     # 斩击：判定+刃光扫过时长
const MELEE_HIT_MOMENT := 0.5     # 伤害判定时机：斩击进度归一化 0..1（0=起斩瞬间，1=收斩瞬间，到点结算一次）
const MELEE_RECOVER_1 := 0.2       # 一段后摇（完整播放；连段预约在后摇期间登记，走完才接二段）
const MELEE_COMBO_WINDOW := 0.7    # 连段窗口（秒）：从斩击完成起算、独立计时，期间按键=预约二段
const MELEE_RECOVER_2 := 0.6       # 二段后摇（结束后回到空闲）
const MELEE_ANTIC_SPEED := 130.0    # 前摇反向预压速度
const MELEE_PITCH_MAX_DEG := 28.0   # 俯仰角上限（度）：朝锁定目标有限俯仰
const MELEE_HANG_DAMP := 14.0       # 滞空竖直速度指数阻尼（越大悬停越"钉住"）
const MELEE_HANG_SINK := 60.0       # 后摇期缓慢沉降的目标速度（推进器撑着）
const MELEE_RECOVER_CONTROL := 0.35 # 后摇期间水平操控系数（硬直但可微调）
const MELEE_HITSTOP_TIME := 0.05   # 命中顿帧时长（真实时间）
const MELEE_HITSTOP_SCALE := 0.05   # 顿帧期间时间流速
const MELEE_SHAKE_STRENGTH := 7.0   # 命中镜头震动初始幅度（px）
const MELEE_SHAKE_DECAY := 60.0     # 镜头震动衰减速度（px/s）
const MELEE_FADE_TIME := 0.16       # 刃光扫完后的消隐时长
const MELEE_FAR_DIM := 0.75         # 甩到机体身后（sinθ<0）那侧的亮度系数（按 sinθ 平滑过渡，非整层硬乘）
const MELEE_SQUASH := 0.42          # 挥砍平面 y 向压扁系数（2D 侧视的椭圆投影，越小越贴平）
const MELEE_HITBOX_OFFSET := 85.0   # 判定盒中心前移量
const MELEE_REACH := 150.0          # 判定盒前向长度
const MELEE_HEIGHT := 90.0          # 判定盒高度
# ---- 玩家死亡与结算 ----
const PLAYER_DAMAGE_SHAKE_STRENGTH := 8.0 # 玩家受击的镜头震动（击毁 6 / 死亡 10 之间）
const PLAYER_DEATH_SHAKE_STRENGTH := 10.0 # 玩家被毁的镜头震动（比击毁敌人更重）
# ---- 飞行（AC6 式推进：地面按跳=跳跃；空中按住跳=持续上升） ----
const BOOST_THRUST_ACCEL := 1000.0     # 推进加速度（px/s²），等比压缩
const BOOST_MAX_ASCENT_SPEED := 320.0 # 推进上升速度上限，等比压缩
const BOOST_CAPACITY := 2.5           # 推进槽容量（满槽可连续推进的秒数）
const BOOST_DRAIN_PER_SEC := 1.0      # 推进时每秒消耗
const BOOST_REGEN_PER_SEC := 2.0      # 非推进时每秒回充（原 0.9：满槽 ~1.2s 回满，AC6 式快回）
const BOOST_REGEN_DELAY_AIR := 0.50   # 空中松开推进到开始回充的间隔（很短的一拍，不是"晾一段时间"）
const BOOST_REGEN_DELAY_GROUND := 0.0 # 落地立即开始回充（AC6 落地回气）
const MELEE_BOOST_COST := 0.15        # 近战固定耗气：每刀起手一口价，不管时长（满槽 1.8 约扣 8%）
