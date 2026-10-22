extends Node
## 全局调参表（autoload 名：Balance）——所有可调数值的唯一出处。
## 只在这里改数值，场景和脚本不保存副本，避免"改了没效果"的遮蔽问题。

# ---- 玩家 ----
const PLAYER_MAX_HP := 100
const PLAYER_MOVE_SPEED := 600.0 # 保留手调值（原 420）
const PLAYER_ACCELERATION := 1800.0 # 水平加/减速度（px/s²），速度不再瞬间突变
const PLAYER_JUMP_VELOCITY := -400.0
const PLAYER_GRAVITY_ASCENT := 1200.0  # 上升段重力
const PLAYER_GRAVITY_DESCENT := 800.0 # 下降段重力略减，模拟主动反推缓降
const PLAYER_FIRE_COOLDOWN := 0.22

# ---- 地面滑行火花 ----
const SLIDE_SPARK_MIN_SPEED := 220.0 # 贴地水平速度超过该值才刮火花
const SLIDE_SPARK_LAND_VY := 450.0   # 重落地踢火花的下坠速度门槛

# ---- 枪臂可动瞄准（玩家与敌人共用） ----
const GUN_PITCH_MAX_DEG := 60.0       # 枪臂俯仰上限（度，正=朝上）
const GUN_PITCH_RETURN_SPEED := 180.0 # 无目标时回平速度（度/秒）

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

# ---- 敌人（步行炮台） ----
const ENEMY_MAX_HP := 20
const ENEMY_SCORE := 10
const ENEMY_ATTACK_RANGE := 1400.0

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
const ENEMY_BULLET_DAMAGE := 1     # 扫射多发命中：单发从 5 降为 2（一梭 3~5 发全中 6~10 伤，逼走位）

# ---- 重击通用（精英/BOSS 共用） ----
# 规约：先预警后伤害；但预警只在发射器上（枪口预警闪光，threat_flash.gd，
# 固定 0.6s 驻留提醒，与各武器出弹窗解耦），不做虚空区域标记，也不给武器精灵染色。
# 导弹=两段式（无动力抛体滑行 → 末段比例导引）：出膛初速=发射器枪口的
# 实际朝向（精英=垂发仓口朝天固定射角；BOSS=近乎竖直朝玩家微倾，±扇面散布
# 由发射方并入）×THROW_SPEED×随机+**载机速度继承**（2026-10-16 三改：继承
# 加→删→加回——弹体姿态跟炮口不跟速度，后退不会把弹头拽得"朝后飞"，
# 动量又看得见）。滑行段只受重力拉弧、不喷烟；
# **按时长开机**（滑行 COAST_TIME 秒即点火，不等过顶——上升段就压弯进拦截，
# 更果断）——点火喷烟，弹体轴由比例导引从炮口朝向起转（转向率=N×视线角
# 速度，自动打提前量，交叉目标迎头截住而非尾追），开机后恒速沿弹体轴巡航。
# **弹体姿态既不朝速度也不朝加速度**：滑行段钉炮口（继承的漂移看得到、姿态
# 不歪）；**速度模型别再动**——推力/阻力版实测"飞一半停天上"已回退。
# 到时锁死直线扎地（不做"飞过即锁直"）。
# 爆炸=球状检测：贴地必中、跳跃顶点逃不掉，必须推进升空拉开球半径。
const HEAVY_GUN_WARN_TIME := 0.5      # 预警后的出弹窗（预警闪光固定 0.6s 先行，见 threat_flash.gd）
const HEAVY_MISSILE_SPEED := 1000.0   # 开机后巡航速度
const HEAVY_MISSILE_TURN_RADIUS := 280.0 # 转向半径（px）：直接调弯有多急；角速度=速度/半径
const HEAVY_MISSILE_TRACK_MAX := 3.0  # 开机后追踪时长上限（秒），到点锁死防缠斗
const HEAVY_MISSILE_FOOT_OFFSET := 36.0 # 瞄准点：玩家碰撞中心下方多少（≈脚底）
const HEAVY_MISSILE_SPREAD_DEG := 12.0  # 抛掷方向散布半角（度）
const HEAVY_MISSILE_THROW_SPEED := 800.0 # 上抛初速大小（px/s，独立于巡航速度）
const HEAVY_MISSILE_COAST_GRAVITY := 2600.0 # 滑行段重力（px/s²）：拉弧的急缓
const HEAVY_MISSILE_COAST_TIME := 0.2   # 滑行时长（秒）：到点开机点火（不等过顶）
const HEAVY_MISSILE_PN_N := 3.5         # 比例导引导航比 N：转向率=N×视线角速度
const HEAVY_BLAST_LINGER := 0.25      # 爆炸闪光驻留（纯视觉，伤害只在引爆帧结算）

# ---- 失衡（AC6 式冲击/STAGGER：枪射打满失衡→BOSS 瘫住→近战砍） ----
# 枪弹冲击注入远超衰减——**持续射击就能打满失衡**；停止受击宽限一段时间后
# 冲击才开始掉（掉速快，断了节奏就前功尽弃）。失衡恢复后有一段免疫期攒不了，
# 防连续失衡无限锁死。失衡期：停摆+受伤加深——近战的正式入口。
const PLAYER_BULLET_IMPACT := 8.0    # 玩家枪弹冲击（≈36/s 注入；BOSS 140 ≈ 4s 命中打满）
const MELEE_IMPACT_1 := 40.0         # 近战一段冲击
const MELEE_IMPACT_2 := 40.0         # 近战二段冲击
const IMPACT_DECAY_DELAY := 1.4      # 宽限期（秒）：最后一次受击后这么久才开始掉
const IMPACT_DECAY := 30.0           # 宽限后的衰减速度（/s）：断了节奏清得很快
const STAGGER_DMG_MULT := 1.5        # 失衡期受伤加深（AC6 同款乘区）
const STAGGER_SFX_DELAY := 0.15      # 失衡音延迟（秒）：主击声先落地，钟鸣随后补位
const IMPACT_RESIST_GRUNT := 40.0    # 杂兵失衡
const IMPACT_RESIST_ELITE := 40.0    # 精英
const IMPACT_RESIST_BOSS := 160.0    # BOSS
const STAGGER_TIME_GRUNT := 0.9      # 失衡硬直时长
const STAGGER_TIME_ELITE := 1.8
const STAGGER_TIME_BOSS := 4.0
const STAGGER_IMMUNITY_GRUNT := 3.0  # 失衡恢复后的冲击免疫期（攒不了）
const STAGGER_IMMUNITY_ELITE := 6.0
const STAGGER_IMMUNITY_BOSS := 8.0
const BOSS_STAGGER_SINK := 26.0      # BOSS 失衡瘫沉幅度（px，瘫而不坠地）

# ---- 敌人（精英·导弹车：周期导弹齐射，枪口预警） ----
const ELITE_MIN_DISTANCE := 3000.0  # 玩家跑过这段距离后精英才进选怪池
const ELITE_MAX_HP := 15
const ELITE_SCORE := 60
const ELITE_ATTACK_RANGE := 2200.0
const ELITE_VOLLEY_HALF_LIFE := 2.2 # 齐射触发半衰期（平均 ~3.2s 一轮，泊松采样同杂兵）
const ELITE_VOLLEY_COUNT := 2       # 每轮导弹数
const ELITE_VOLLEY_STAGGER := 0.28  # 轮内发射间隔
const ELITE_MISSILE_DAMAGE := 8
const ELITE_BLAST_RADIUS := 95.0    # 爆炸球半径（玩家判定另加半宽宽限）

# ---- BOSS（追击大型机：水平弹簧构图位同行，扫射 ⇄ 弹雨 轮换、间插普攻直射） ----
# 跑酷不断、镜头不接管：BOSS 是"追击段落"不是关卡。水平是放松的弹簧——玩家推进
# 把 BOSS 压近、倒退把它甩出画面右缘（出画不打断出招，站定它自己踱回来）；
# 扫射只变高度（压到射高开火）。动作之间只隔各自后摇，无独立间歇；
# 离玩家过近压住不出招（贴脸反应窗）。
const BOSS_SCORE_TRIGGER := 100       # 击杀分攒满刷一场 BOSS；打完清零重计
const BOSS_MAX_HP := 600
const BOSS_DEFENSE := 5             # 防御力
									# 近战绕盾全额（15/25）——强化"枪射攒失衡→近战爆发"的分工
const BOSS_SCORE := 100
const BOSS_HOVER_Y := 240.0         # 悬浮基准高度（绝对世界 y，不随地形成跳变）
const BOSS_BOB_AMPLITUDE := 6.0     # 悬停浮动幅度
const BOSS_BOB_SPEED := 2.0
const BOSS_SCREEN_ANCHOR := 1000.0  # 平时位置按构图定：镜头中心右侧 1000（画面右 5/6 处，
									# 距右缘 200）。不追人不压进
const BOSS_ANCHOR_STIFFNESS := 3.0  # 纵向压高/入场滑入的增益：期望速度=距离×系数（比例趋近，饱和到上限）
const BOSS_MOVE_STIFFNESS := 1.2    # 水平弹簧劲度（刻意放松）：稳态滞后=玩家速度÷系数——
									# 满速倒退 600 → 滞后 500px，足够把 BOSS 甩出画面右缘；推进则反向压近
const BOSS_MOVE_MAX_SPEED := 700.0  # 横向机动速度上限：<近战冲刺 900——出招间隙冲刺能破防贴脸
const BOSS_MOVE_ACCEL := 1400.0     # 横向加/减速度：规避需要时间，不再是零反应锁距离
const BOSS_ENTER_SPEED := 1500.0    # 入场滑入速度上限
const BOSS_VERT_MAX_SPEED := 320.0  # 纵向机动速度上限
const BOSS_VERT_ACCEL := 900.0      # 纵向加/减速度
const BOSS_ENTER_TIME := 0.9        # 入场滑入时长
const BOSS_SWEEP_RECOVER := 1.2     # 扫射后摇（秒）：后摇到点直接出下一手，动作间无独立间歇
const BOSS_RAIN_RECOVER := 1.4      # 弹雨后摇（秒）
const BOSS_DIRECT_RECOVER := 0.9    # 普攻直射后摇（秒）
const BOSS_PHASE2_RECOVER_SCALE := 0.6 # 二阶段后摇缩短比例
const BOSS_PHASE2_RATIO := 0.5      # 半血进二阶段
const BOSS_PHASE2_RAIN_BONUS := 2   # 二阶段导弹 +2 发
const BOSS_ATTACK_MIN_DISTANCE := 700.0 # 离玩家水平距小于此不出招：硬直贪刀后 BOSS 弹回这个距离才重新开火（脱身反应窗）
# 高位扫射：BOSS 真的机动到射高再开火（本体压下来就是预警），不虚空射击。
# 射高=枪口 410：最高地形站立头顶（536-66=470）之下余量 60px，
# 跳跃顶点擦不到，滞空挨打。持续机枪流（不是齐射）：小散布角扫成扇面。
const BOSS_SWEEP_Y := 350.0         # 扫射期机体中心目标高度（世界 y）
const BOSS_SWEEP_AIM_TIME := 0.35   # 到射高后到开火的预警窗（与预警闪光同长）
const BOSS_SWEEP_DURATION := 1.6    # 一阶段扫射持续时长（二阶段 2.2）
const BOSS_SWEEP_DURATION_P2 := 2.2
const BOSS_SWEEP_FIRE_INTERVAL := 0.085 # 机枪发弹间隔（≈12 发/秒）
const BOSS_SWEEP_SPREAD_DEG := 1.0  # 散布半角（度）：弹流扫成窄扇面
const BOSS_SWEEP_TWIN_OFFSET := 16.0 # 二阶段双机枪：上下枪口各偏移多少
const BOSS_ROTOR_SPIN := 14.0        # 尾旋翼转速（rad/s，整周旋转）
const BOSS_ROTOR_WOBBLE := 0.035     # 主旋翼呼吸摆幅（rad：侧视刃边不整周旋转）
const BOSS_ROTOR_WOBBLE_SPEED := 19.0 # 主旋翼摆动频率
const BOSS_SWEEP_SPEED := 1000.0
const BOSS_SWEEP_DAMAGE := 8        # 机枪单发轻（12发/s 持续流）；威胁靠命中数累积
# 直射=普攻：同一把机枪换瞄准——枪臂真瞄玩家（无预判）朝人扫一短梭，子弹与高扫
# 同款（SPEED/DAMAGE 共用 BOSS_SWEEP_*），只有射击时长不同。无重击警告（枪臂全程
# 真瞄，瞄准本身就是预警），技能（扫射/弹雨）之间各插一段。
const BOSS_DIRECT_DURATION := 0.5    # 普攻直射时长（秒）：短梭填充段，技能间穿插
# 导弹雨：背部导弹舱预警闪光 → 追踪导弹逐孔齐射；没打中就在玩家身后锁向砸地，球状爆伤。
const BOSS_RAIN_COUNT := 4          # 一轮导弹数
const BOSS_RAIN_STAGGER := 0.26     # 出膛间隔：拉大发弹节拍，配合各自拱顶读得出"轮次"
const BOSS_RAIN_DAMAGE := 10        # 单发伤害：满轮吃满 40（二阶段 60），可活但疼
const BOSS_RAIN_BLAST_RADIUS := 70.0

# ---- 熔渣火区（第二章精英/BOSS 共用：驻留地面危险，tick 结算） ----
const SLAG_POOL_RADIUS := 90.0
const SLAG_POOL_DAMAGE := 3            # 每 tick 伤害（站满一轮 ≈ 16~21）
const SLAG_POOL_TICK := 0.4            # tick 周期
const SLAG_POOL_WARMUP := 0.35         # 落地蓄热：开伤前缓冲（落地溅开→变危险，二段预警）

# ---- 迫击炮弹道（熔渣弹：真抛体，与导弹彻底分家，见 mortar_shell.gd） ----
const MORTAR_GRAVITY := 4000.0        # ≈4×玩家重力：弧快不掉速，全程 ~0.7s、弧顶 ≈+120px
const ELITE_SLAG_FLIGHT := 0.7        # 臼炮车弹飞行时长（解算初速用）
const BARGE_SLAG_FLIGHT := 0.75       # 驳船臼炮弹飞行时长

# ---- 第二章精英·熔渣臼炮车（垂发高抛，落点=按玩家速度推算的前方路面） ----
# 教学位：把 BOSS 的"熔渣封路"提前教给玩家——读弧线、离开落点、跳越火区。
# 相对速度即机制：落点带 lead，匀速直线跑会一头扎进火区，躲=变速/绕行/跳越。
const ELITE_SLAG_MAX_HP := 15
const ELITE_SLAG_SCORE := 60
const ELITE_SLAG_ATTACK_RANGE := 2200.0
const ELITE_SLAG_VOLLEY_HALF_LIFE := 2.4 # 齐射触发半衰期（同 ch1 精英的泊松节奏）
const ELITE_SLAG_VOLLEY_COUNT := 3   # v2.1 2→3（弹数下限统一上调，ch1 基准不动）
const ELITE_SLAG_VOLLEY_STAGGER := 0.35
const ELITE_SLAG_SHELL_DAMAGE := 0    # 落地无溅射伤害（火区才是威胁，教学纯净版）
const ELITE_SLAG_LEAD_MAX := 850.0    # 提前量上限（封路落点最远在前方这段）
const ELITE_SLAG_POOL_TIME := 2.2     # 精英火区驻留时长（BOSS 版更长）

# ---- 第二章 BOSS·悬浮冶炼驳船（300×180 船体 hover 370：船底 460=t2 站立头顶 ----
# 上方 10px、对最高台阶 536 净空 76px。招式=排炮弹幕墙 ⇄ 熔渣封路，间插直瞄普攻
# （直瞄复用 BOSS_DIRECT_*/BOSS_SWEEP_*）。弹幕墙：船艏 3 真实炮位（wy 350/380/410，
# =画布 y70/100/130 舱门），基准俯角+每轮整体摆动（缝轮轮换）；每发出膛前沿射线
# 采样地形，埋弹抬角校平（至多 2 次），仍埋该炮本轮哑火（被地形挡住不打）。
const BARGE_MAX_HP := 700
const BARGE_HOVER_Y := 370.0
const BARGE_WALL_BASE_DEG := [1.0, 6.0, 11.0] # 三炮位基准俯角（左向开火，正=向下）
const BARGE_WALL_SWEEP_DEG := 3.0     # 每轮扇面整体摆动幅 ±（phase2 换 5）
const BARGE_WALL_FLATTEN_DEG := 3.0   # 埋弹校平抬角步长
const BARGE_WALL_FLATTEN_MAX := 2     # 校平次数上限，超出=该炮本轮哑火
const BARGE_WALL_SAMPLE_STEP := 80.0  # 射线地形采样步长
const BARGE_WALL_SAMPLE_RANGE := 1500.0
const BARGE_WALL_BURST := 5           # 每门发数（phase2 +2）
const BARGE_WALL_BURST_INTERVAL := 0.09
const BARGE_WALL_PORT_STAGGER := 0.12 # 炮位梯次间隔
const BARGE_WALL_RECOVER := 1.3
const BARGE_SLAG_COUNT := 4           # 一轮熔渣弹=4 垂发孔 1:1（phase2 +2 回绕）
const BARGE_SLAG_STAGGER := 0.3
const BARGE_SLAG_RECOVER := 1.4
const BARGE_SLAG_DAMAGE := 8
const BARGE_SLAG_BLAST_RADIUS := 45.0 # 落地小溅射（BOSS 版比精英多这一口）
const BARGE_SLAG_POOL_TIME := 2.8
const BARGE_SLAG_LEAD_MAX := 900.0
const BARGE_PHASE2_SLAG_BONUS := 2
const BARGE_PHASE2_BURST_BONUS := 2
const BARGE_PHASE2_SWEEP_DEG := 5.0

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
const ELITE_MINE_MAX_HP := 15
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
const SENTINEL_MAX_HP := 750
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

# ---- 珊瑚重弹（第四章精英/BOSS 共用：慢速可见能量重球，lead 瞄准，撞地爆蕗） ----
# 惩罚账（art_proposals/coral_ch4/提案_v2_珊瑚重设计.md §2 + v2.1 调参）：弹速
# 900 慢于机枪流=弹体自读（看得见、侧移即躲）；爆区翻倍（90/80→180/160）=
# 慢+大=压制面读法（实机"又慢又弱"打回，2026-10-21）。lead=玩家速度×飞行
# 时长在出膛瞬间一次解算、clamp 承诺带——BOSS 炮口距 ~1300 → 飞行 ~1.45s →
# 满速跑 lead ~870 ≤ LEAD_MAX 950（clamp 不吃满=惩罚成立）。急停/变向=免，
# 站桩吃脚下（承诺带哲学，同臼炮 lead 账）。
const CORAL_ORB_SPEED := 900.0        # 重弹恒速（px/s）

# ---- 珊瑚潮（第四章 BOSS 专属危险件：固定高度的能量涌浪墙，飞越=反制） ----
# v2.1 重做（实机"像甲虫爬+地块间高低瞬移"打回）：**不管地面**——浪墙钉在
# 绝对高度带 [BAND_TOP, BAND_BOTTOM]（纵跨 120，覆盖三档地块站立带中心
# 634/570/506），只沿 x 涌动、台阶零瞬移。反制=推进升空飞越（纯跳 apex
# 只在最高档擦得过得 439<458，低档必须飞）；浮空脚手架高台=合法掩体
# （平台顶中心 ~440 在带上缘之外）。后撤跑 600>涌速 520 甩得开，射程到点
# 哑熄（无伤）——等待永远合法。
const CORAL_TIDE_SPEED := 520.0       # 涌速（px/s，≈玩家跑速 0.87 倍）
const CORAL_TIDE_RANGE := 1500.0      # 射程（涌满即哑熄）
const CORAL_TIDE_BAND_TOP := 520.0    # 浪墙高度带上缘（绝对世界 y）
const CORAL_TIDE_BAND_BOTTOM := 640.0 # 浪墙高度带下缘（绝对世界 y）
const CORAL_TIDE_RADIUS := 36.0       # 判定半厚（带缘外扩，+玩家半宽 26 宽限）
const CORAL_TIDE_DAMAGE := 8          # 灼烧一次即溃散（浪墙不是驻留区）

# ---- 第四章精英·炮台车「海葵」（背驮海葵发射器，三连珊瑚重弹 lead 瞄准） ----
# 教学位：把「鮟鱇」的珊瑚重炮提前教给玩家——读炮口预警+看慢弹落点，
# 变向/急停离承诺带，匀速直线跑被逐发压在路径上。
# 弹数下限 v2.1 统一上调（用户：憋半天就两发太少；ch1 基准不动）。
const ELITE_ANEMONE_MAX_HP := 15
const ELITE_ANEMONE_SCORE := 60
const ELITE_ANEMONE_ATTACK_RANGE := 2200.0
const ELITE_ANEMONE_VOLLEY_HALF_LIFE := 2.4 # 齐射触发半衰期（同前三章精英的泊松节奏）
const ELITE_ANEMONE_VOLLEY_COUNT := 3 # 轮内三发梯次
const ELITE_ANEMONE_VOLLEY_STAGGER := 0.5
const ELITE_ANEMONE_ORB_DAMAGE := 8
const ELITE_ANEMONE_BLAST_RADIUS := 160.0 # 爆区球（v2.1 翻倍：慢+大=压制面读法）
const ELITE_ANEMONE_LEAD_BACK := 240.0   # 承诺带后沿：急退也追一段（站桩不豁免）
const ELITE_ANEMONE_LEAD_MAX := 620.0    # 承诺带前沿上限

# ---- 第四章 BOSS·深海猎杀舰「鮟鱇」（v2 舰体=背炮+钓灯+腹闸；300×180 ----
# hover 370：船底 460=t2 站立头顶上方 10px、对最高台阶 536 净空 76px，同
# 驳船/哨兵档。招式=珊瑚重炮 ⇄ 珊瑚潮（腹下放电舱吐贴地涌浪），间插钓灯
# 能量束直射（coral_bolt.tscn=bullet.gd 纯换皮，复用 BOSS_DIRECT_*/BOSS_SWEEP_*）。
# 重弹出膛瞬间 lead 解算（瞄准锁定在开火时机，真实枪口律）。
const ANGLER_MAX_HP := 750
const ANGLER_HOVER_Y := 370.0
const ANGLER_VOLLEY_COUNT := 4        # 一轮重弹数（v2.1 3→4，对齐 ch1/ch3 弹雨档；phase2 +1）
const ANGLER_VOLLEY_STAGGER := 0.55
const ANGLER_ORB_DAMAGE := 10
const ANGLER_ORB_BLAST_RADIUS := 180.0 # 爆区球（v2.1 翻倍：慢+大=压制面读法）
const ANGLER_ORB_LEAD_BACK := 280.0
const ANGLER_ORB_LEAD_MAX := 950.0    # 满速跑 lead ~870 落带内（clamp 不吃满）
const ANGLER_VOLLEY_RECOVER := 1.4
const ANGLER_TIDE_COUNT := 2          # 一轮珊瑚潮波数（v2.1 1→2；phase2 +1=三波）
const ANGLER_TIDE_DROP_STAGGER := 0.9 # 波间隔：连波逼持续滞空
const ANGLER_TIDE_RECOVER := 1.3
const ANGLER_PHASE2_VOLLEY_BONUS := 1
const ANGLER_PHASE2_TIDE_BONUS := 1

# ---- 啸雷弹（第五章精英/BOSS 共用：定距空爆的防空重击弹，见 flak_shell.gd） ----
# 惩罚账（art_proposals/dawn_ch5/提案_v1_破晓云廊.md §2 几何数字表）：直线无
# 重力+定距引信（出膛瞬间按炮口→玩家当时位置的距离解算爆点）——**停=吃/动=免**，
# 与 ch4 重弹的 lead 惩罚互为镜像（那边罚匀速跑，这边罚不跑）。全速跑在
# 预警 0.6s+飞行 ~0.58s 内位移 708px ≫ 爆区 136，必过；站桩/近战硬直
# （RECOVER_CONTROL 0.35 → ~126px）在猎杀半径内；悬停=吃（防空语义）。
# 射线撞台阶立面=早爆（掩体合法，不校平）。追踪语汇零涉及。
const FLAK_SHELL_SPEED := 2400.0      # 弹速（=玩家弹速档：读法靠炮口预警+引信芯快闪）

# ---- 第五章精英·防空炮车「响哨」（双管高炮俯仰跟踪，双连啸雷弹） ----
# 教学位：把「断云」的啸雷提前教给玩家——读炮口预警+引信芯快闪，
# 爆点=开火瞬间自己所在点：听到/看到预警就保持移动，停=吃。
const ELITE_SIREN_MAX_HP := 15
const ELITE_SIREN_SCORE := 60
const ELITE_SIREN_ATTACK_RANGE := 2200.0
const ELITE_SIREN_VOLLEY_HALF_LIFE := 2.4 # 齐射触发半衰期（同前四章精英的泊松节奏）
const ELITE_SIREN_VOLLEY_COUNT := 2 # 轮内双发梯次
const ELITE_SIREN_VOLLEY_STAGGER := 0.45
const ELITE_SIREN_FLAK_DAMAGE := 8
const ELITE_SIREN_FLAK_BLAST_RADIUS := 90.0 # 爆区球（+玩家半宽 26 宽限）

# ---- 第五章 BOSS·高空截击机「断云」（300×180 机体 hover 370：机腹 460=t2 ----
# 站立头顶上方 10px、对最高台阶 536 净空 76px，同驳船/哨兵/鮟鱇档。招式=
# 啸雷齐射 ⇄ 俯冲突袭（首次机体冲撞：预警 0.6s→锁定出手点→2100px/s 直线
# 通场扫地面通道→过冲拉起返锚），间插机鼻曳光直射（dawn_bolt.tscn=bullet.gd
# 纯换皮，速度/伤害复用 BOSS_SWEEP_*）。分工账：啸雷 hunts 空中与驻停
# （爆在玩家当时所在点），俯冲 hunts 地面通道（飞行玩家不在通场带）——
# 玩家被迫两头换层。俯冲线每帧 clamp 中心 y ≤ 当地地表−120（滑过台阶上缘
# 不穿模）；通场带覆盖 [地表−210, 地表−30]：站立=被撞、纯跳 apex −127=被撞
# （压"跳过一切"）、推进 ≥204px 或横移出锁定线=免。
const INTERCEPTOR_MAX_HP := 750
const INTERCEPTOR_HOVER_Y := 370.0
const INTERCEPTOR_FLAK_COUNT := 3        # 一轮啸雷数（phase2 +1）
const INTERCEPTOR_FLAK_STAGGER := 0.35   # 弹串节拍（追赶读法：每 840px 一朵）
const INTERCEPTOR_FLAK_DAMAGE := 10
const INTERCEPTOR_FLAK_BLAST_RADIUS := 110.0
const INTERCEPTOR_FLAK_RECOVER := 1.3
const INTERCEPTOR_DIVE_WARN := 0.6       # 机鼻预警+尾焰增亮时长
const INTERCEPTOR_DIVE_SPEED := 2100.0   # 俯冲速度（直线锁定线，出手瞬间锁一次）
const INTERCEPTOR_DIVE_CLEAR := 120.0    # 通场净空：中心线压在当地地表上空这么高
const INTERCEPTOR_DIVE_OVERSHOOT := 500.0 # 过冲距离（穿过锁定点后继续冲这么远再拉起）
const INTERCEPTOR_DIVE_DAMAGE := 12      # 机体冲撞（每次俯冲至多结算一次）
const INTERCEPTOR_DIVE_RECOVER := 1.2
const INTERCEPTOR_PHASE2_FLAK_BONUS := 1

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
const ELITE_PILER_MAX_HP := 15
const ELITE_PILER_SCORE := 60
const ELITE_PILER_ATTACK_RANGE := 2200.0
const ELITE_PILER_VOLLEY_HALF_LIFE := 2.4 # 齐射触发半衰期（同前五章精英的泊松节奏）
const ELITE_PILER_FENCE_HALF := 140.0  # 桩落点半宽（笼内=被围）
const ELITE_PILER_FENCE_TOP := 150.0   # 幕高（纯跳 apex 底 −103 跳不过，教学纯净版幕稍矮）
const ELITE_PILER_FENCE_WARMUP := 0.8  # 桩上火花蓄能（二段预警，比 BOSS 版多留 0.1s 读）
const ELITE_PILER_FENCE_LIFE := 1.6    # 幕存活时长，到点哑熄（无伤）
const ELITE_PILER_FENCE_DAMAGE := 8
const ELITE_PILER_STAKE_FLIGHT := 0.5  # 桩抛体飞行时长（弹道解算用）

# ---- 第六章 BOSS·斗轮采集舰「赤轮」（300×180 机体 hover 370：船底 460=t2 ----
# 站立头顶上方 10px；最低点=斗轮缘 454（bob 后对最高台阶 536 净空 76），同
# 驳船/哨兵/鮟鱇/断云档。招式=电网闸 ⇄ 溜矿车（腹舱倾泻贴地滚向玩家），间插
# 斗轮弹石直射（red_chip.tscn=bullet.gd 纯换皮，速度/伤害复用 BOSS_SWEEP_*）。
# 分工账：电网闸 hunts 滞留者（笼+税：停=围/动=免/出笼交税或飞越），溜矿车
# hunts 地面驻留节奏（跳的拍子：纯跳可过、双车节拍减半）——玩家被迫在
# 跑/跳/飞三态间换挡（全部走地面轴，与 ch5 啸雷/俯冲的换层账同构）。
const REDWHEEL_MAX_HP := 750
const REDWHEEL_HOVER_Y := 370.0
const REDWHEEL_FENCE_HALF := 200.0     # 桩落点半宽（笼内=被围）
const REDWHEEL_FENCE_TOP := 200.0      # 幕高（推进 ≥204 飞越=免）
const REDWHEEL_FENCE_WARMUP := 0.7     # 桩上火花蓄能（p2 0.55：跑=免的窗口收窄）
const REDWHEEL_FENCE_LIFE := 2.2       # 幕存活时长
const REDWHEEL_FENCE_DAMAGE := 10
const REDWHEEL_FENCE_LEAD_MAX := 400.0 # 半 lead：落带中心按玩家速度前/后移的上限
                                       # （惩罚缓移与后撤，全速跑仍出带）
const REDWHEEL_FENCE_RECOVER := 1.3
const REDWHEEL_STAKE_FLIGHT := 0.55    # 桩抛体飞行时长（弹道解算用）
const REDWHEEL_PHASE2_FENCE_WARMUP := 0.55
const REDWHEEL_CART_COUNT := 1         # 一轮矿车数（p2 2，间隔 0.55：跳窗减半）
const REDWHEEL_CART_STAGGER := 0.55
const REDWHEEL_CART_RECOVER := 1.2
const REDWHEEL_PHASE2_CART_BONUS := 1

# ---- 溜矿车（第六章 BOSS 专属危险件：贴地滚向玩家的可跳矿车，见 ore_cart.gd） ----
# 惩罚账（提案 §2）：滚速 520（≈跑速 0.87）对滚合速 1120，碰撞 64×84——
# 纯跳 apex 底 −103 vs 车顶 −84 跳得过（余量 19px）；站桩=吃（一次结算，
# 车继续滚）；寿命到点脱轨哑熄（无伤）——等待永远合法。
const ORE_CART_SPEED := 520.0
const ORE_CART_DAMAGE := 10
const ORE_CART_LIFETIME := 4.0

# ---- 击毁反馈（爆炸特效本体参数在 explosion_burst.gd，这里只管手感） ----
const KILL_SHAKE_STRENGTH := 6.0  # 击毁镜头震动幅度（近战命中 7，这里略低）
const KILL_HITSTOP_TIME := 0.04   # 击毁顿帧时长（真实时间）
const KILL_HITSTOP_SCALE := 0.15  # 击毁顿帧时间流速（比近战顿帧温和）

# ---- 头顶血条（世界空间，scripts/overhead_bar.gd） ----
# 配色按实机雾天采样调的：战斗带上空 #8c8467（中明度、极低饱和的橄榄驼色），
# 雾天顶 #bbae85，地面 #3f3c34。雾天饱和度极低 → 用"高饱和 + 中明度"的色度
# 对比，明度即便贴近背景也压得住；纯提亮会没进雾里。
const HP_BAR_DAMAGED_ONLY := true     # 敌人满血隐藏头顶条（玩家血条/气槽常显）
const HP_BAR_HEIGHT := 5.0
const BOOST_BAR_HEIGHT := 3.0
const BOOST_BAR_GAP := 3.0            # 玩家气槽与血条的间距
const HP_BAR_PLAYER_WIDTH := 64.0
const HP_BAR_PLAYER_OFFSET_Y := -56.0 # 玩家条组挂在原点上方多少（精灵视觉顶约 -42）
const HP_BAR_ENEMY_MARGIN_Y := 16.0   # 敌条在碰撞盒顶面再抬多少
const HP_BAR_ENEMY_WIDTH_MIN := 30.0
const HP_BAR_ENEMY_WIDTH_MAX := 56.0
const HP_BAR_GHOST_DAMP := 4.0        # 虚影指数插值阻尼（/秒）：越大跟得越紧、缩得越快
const HP_BAR_PLAYER_COLOR := Color(0.18, 0.71, 0.34)  # 深翠绿（提饱和、压明度）
const HP_BAR_BOOST_COLOR := Color(0.18, 0.49, 0.88)   # 深钴蓝（同理）
const HP_BAR_GHOST_COLOR := Color(1.0, 1.0, 1.0)      # 虚影满白（亮、显眼）
const HP_BAR_ENEMY_COLOR := Color(1.0, 0.32, 0.25)    # 阵营信号红
const HP_BAR_IMPACT_COLOR := Color(1.0, 0.8, 0.22)    # 冲击条黄（AC6 式失衡条）
const HP_BAR_IMPACT_FILL_COLOR := Color(1.0, 1.0, 1.0) # 冲击条实值白（虚值黄=IMPACT_COLOR，用户定的反转）

# ---- 玩家死亡与结算 ----
const PLAYER_DAMAGE_SHAKE_STRENGTH := 8.0 # 玩家受击的镜头震动（击毁 6 / 死亡 10 之间）
const PLAYER_DEATH_SHAKE_STRENGTH := 10.0 # 玩家被毁的镜头震动（比击毁敌人更重）
const GAME_OVER_DELAY := 1.1              # 死亡→定格的延迟：让玩家爆炸播完再暂停出结算

# ---- 章节转场（击败 BOSS → 延迟 → 黑场 → 下一章；下一章场景路径在各 Main 场景上） ----
const CHAPTER_CLEAR_DELAY := 1.7          # 击败→黑场的延迟（秒）：连串爆散先播完，胜利余韵一拍再切

# ---- 启动页（小恐龙式站桩待机 → 进战斗） ----
const COMBAT_INPUT_DELAY := 0.5      # 进战斗后到解锁操作的延迟（秒）：启动演出期不应答输入
const IDLE_PUFF_TIME := 0.4          # 待机小喷焰单口时长
const IDLE_PUFF_LEVEL := 0.35        # 待机小喷焰峰值档位
const IDLE_PUFF_INTERVAL_MIN := 1.6  # 待机小喷焰间隔下限（秒）
const IDLE_PUFF_INTERVAL_MAX := 3.2  # 待机小喷焰间隔上限（秒）

# ---- 系统播报（非人声机电提示：台词见 data/comms.json，语音 tools/bake_tts.py 烘焙） ----
const COMMS_RADIO_FX := false         # 电台后期链总开关（false=干声空听，squelch/噪底一并静音）
const COMMS_HP_WARN_T1 := 0.5        # 低 AP 一档：剩余 50%（血量比例）
const COMMS_HP_WARN_T2 := 0.25       # 低 AP 二档：剩余 25%
const COMMS_HP_REARM_MARGIN := 0.10  # AP 回升超过一档+余量才允许重新触发（滞回）
const COMMS_VOICE_VOLUME_DB := -4.0  # 人声在电台总线上的电平（2026-10-16 实听 +2 太响，降 6dB）
# 电台链调味（comms.gd 运行时建总线，不依赖 .tres）：临场感=压缩泵感+常驻噪底+轻削波
const COMMS_RADIO_PRESENCE_DB := 4.0  # EQ ~2kHz 提亮（机电线的"穿透"感）
const COMMS_RADIO_DRIVE_DB := 5.0     # 软削波 grit：进削波器的预推增益（越大越"隔着机器"，过头会脏）
const COMMS_RADIO_COMP_THRESHOLD_DB := -24.0 # 压缩阈值：语音按到统一响度并造泵感
const COMMS_RADIO_COMP_RATIO := 7.0   # 压缩比（无线电重压缩，越大泵感越强）
const COMMS_RADIO_COMP_GAIN_DB := 7.0 # 压缩补偿增益
const COMMS_RADIO_SLAP_MS := 22.0     # 拍背延迟：须压在 Haas 融合窗（~25ms）内才成"空间感"，一超就听成复读
const COMMS_RADIO_SLAP_LEVEL_DB := -18.0
const COMMS_NOISE_BED_DB := -26.0     # 常驻静噪沙底电平（频道开着的"底"）

# ---- 刷怪间距（按玩家带符号位移累计） ----
const SPAWN_ENEMY_GAP_MIN := 1200.0
const SPAWN_ENEMY_GAP_MAX := 2400.0
const SPAWN_OBSTACLE_GAP_MIN := 1800.0
const SPAWN_OBSTACLE_GAP_MAX := 2600.0
const OBSTACLE_DESPAWN_MARGIN := 1200.0 # 障碍完全出画面后再留半屏才回收（玩家回头走不見消失）
const PLATFORM_HOVER_MIN := 100.0  # 断桥顶面悬在地表上方的最小高度
const PLATFORM_HOVER_MAX := 200.0  # 断桥顶面悬在地表上方的最大高度

# ---- 飞行（AC6 式推进：地面按跳=跳跃；空中按住跳=持续上升） ----
const BOOST_THRUST_ACCEL := 930.0     # 推进加速度（px/s²），等比压缩
const BOOST_MAX_ASCENT_SPEED := 320.0 # 推进上升速度上限，等比压缩
const BOOST_CAPACITY := 1.8           # 推进槽容量（满槽可连续推进的秒数）
const BOOST_DRAIN_PER_SEC := 1.0      # 推进时每秒消耗
const BOOST_REGEN_PER_SEC := 1.5      # 非推进时每秒回充（原 0.9：满槽 ~1.2s 回满，AC6 式快回）
const BOOST_REGEN_DELAY_AIR := 0.30   # 空中松开推进到开始回充的间隔（很短的一拍，不是"晾一段时间"）
const BOOST_REGEN_DELAY_GROUND := 0.0 # 落地立即开始回充（AC6 落地回气）

# ---- 地块（高低不平的连续地形） ----
const TERRAIN_CHUNK_WIDTH := 320.0 # 单块地块宽度（首尾相接，无随机间距）
const TERRAIN_TIER_COUNT := 3      # 高度档数（含最低档）
const TERRAIN_TIER_STEP := 64.0    # 相邻档位高差
const TERRAIN_TIER_BASE_Y := 664.0 # 最低档顶面（= 原地面下移一档）；中位档恰为原地面 600，整体不偏上
const TERRAIN_RUN_MIN := 2         # 同一高度连续块数下限（一段不要太碎）
const TERRAIN_RUN_MAX := 4         # 同一高度连续块数上限
const TERRAIN_INTRO_SEG_LEN := 8   # 开局平地段长度（块）：启动页空场，原点附近不放高低差
const TERRAIN_INTRO_SEG_TIER := 1  # 开局平地段高度档：中位档（= 原地面 600）
const TERRAIN_INTRO_WEST_SEG_LEN := 2 # 段 -1（原点以西）平地块数：启动页画面左缘也不露台阶

# ---- 镜头 ----
const CAMERA_X_OFFSET := 400.0 # 玩家固定在画面左 1/3（2400 的 1/6）
const CAMERA_Y := 450.0        # 高度锁死，飞行范围由天花板约束在画面内
const MOBILE_CAMERA_Y_OFFSET := 64.0 # 移动端镜头额外下移两档：地面/战斗区抬到屏幕上半，躲手指；天花板出画上沿，允许角色飞出画面
