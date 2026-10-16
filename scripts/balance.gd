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
const ENEMY_BULLET_DAMAGE := 2     # 扫射多发命中：单发从 5 降为 2（一梭 3~5 发全中 6~10 伤，逼走位）

# ---- 重击通用（精英/BOSS 共用） ----
# 规约：先预警后伤害；但预警只在发射器上（枪口预警闪光，threat_flash.gd，
# 固定 0.6s 驻留提醒，与各武器出弹窗解耦），不做虚空区域标记，也不给武器精灵染色。
# 导弹=两段式（无动力抛体滑行 → 末段比例导引）：出膛初速=发射器枪口的
# 实际朝向（精英=垂发仓口朝天固定射角；BOSS=近乎竖直朝玩家微倾，±扇面散布
# 由发射方并入）×THROW_SPEED×随机+**载机速度继承**（2026-10-16 三改：继承
# 加→删→加回——弹体姿态跟炮口不跟速度，后退不会把弹头拽得"朝后飞"，
# 动量又看得见）。滑行段只受重力拉弧、不喷烟；
# **按时长开机**（滑行 COAST_TIME 秒即点火，不等过顶——上升段就压弯进拦截，
# 更果断）——点火喷烟，弹体轴由比例导引转动（转向率=N×视线角速度，自动打
# 提前量，交叉目标迎头截住而非尾追），速度按**推力-阻力**收敛：沿弹体轴
# THRUST 推进、线性阻力 DRAG，末速=THRUST/DRAG≈巡航速度（游戏里模拟空气
# 阻力的通常做法：不真算气动，推力-阻力平衡出巡航速度）；到时锁死直线
# 扎地、只吃阻力自然减速（不做"飞过即锁直"）。
# 爆炸=球状检测：贴地必中、跳跃顶点逃不掉，必须推进升空拉开球半径。
const HEAVY_GUN_WARN_TIME := 0.5      # 预警后的出弹窗（预警闪光固定 0.6s 先行，见 threat_flash.gd）
const HEAVY_MISSILE_SPEED := 1000.0   # 巡航速度（=THRUST/DRAG；转向半径按它导出）
const HEAVY_MISSILE_THRUST := 3600.0  # 开机推力（px/s²，沿弹体轴）：~0.3s 收敛到巡航速度
const HEAVY_MISSILE_DRAG := 3.6       # 开机段线性空气阻力（/s）：末速=THRUST/DRAG=1000 恰为巡航速度
const HEAVY_MISSILE_TURN_RADIUS := 360.0 # 转向半径（px）：直接调弯有多急；角速度=速度/半径
const HEAVY_MISSILE_TRACK_MAX := 1.4  # 开机后追踪时长上限（秒），到点锁死防缠斗
const HEAVY_MISSILE_FOOT_OFFSET := 36.0 # 瞄准点：玩家碰撞中心下方多少（≈脚底）
const HEAVY_MISSILE_SPREAD_DEG := 12.0  # 抛掷方向散布半角（度）
const HEAVY_MISSILE_THROW_SPEED := 1300.0 # 上抛初速大小（px/s，独立于巡航速度）
const HEAVY_MISSILE_COAST_GRAVITY := 2600.0 # 滑行段重力（px/s²）：拉弧的急缓
const HEAVY_MISSILE_COAST_TIME := 0.4   # 滑行时长（秒）：到点开机点火（不等过顶）
const HEAVY_MISSILE_PN_N := 3.5         # 比例导引导航比 N：转向率=N×视线角速度
const HEAVY_BLAST_LINGER := 0.25      # 爆炸闪光驻留（纯视觉，伤害只在引爆帧结算）

# ---- 失衡（AC6 式冲击/STAGGER：枪射打满失衡→BOSS 瘫住→近战砍） ----
# 枪弹冲击注入远超衰减——**持续射击就能打满失衡**；停止受击宽限一段时间后
# 冲击才开始掉（掉速快，断了节奏就前功尽弃）。失衡恢复后有一段免疫期攒不了，
# 防连续失衡无限锁死。失衡期：停摆+受伤加深——近战的正式入口。
const PLAYER_BULLET_IMPACT := 8.0    # 玩家枪弹冲击（≈36/s 注入；BOSS 140 ≈ 4s 命中打满）
const MELEE_IMPACT_1 := 45.0         # 近战一段冲击（快速垫一格）
const MELEE_IMPACT_2 := 60.0         # 近战二段冲击
const IMPACT_DECAY_DELAY := 1.4      # 宽限期（秒）：最后一次受击后这么久才开始掉
const IMPACT_DECAY := 30.0           # 宽限后的衰减速度（/s）：断了节奏清得很快
const STAGGER_DMG_MULT := 1.5        # 失衡期受伤加深（AC6 同款乘区）
const IMPACT_RESIST_GRUNT := 30.0    # 杂兵失衡上限：4 发枪弹
const IMPACT_RESIST_ELITE := 90.0    # 精英：≈12 发
const IMPACT_RESIST_BOSS := 140.0    # BOSS：≈18 发命中
const STAGGER_TIME_GRUNT := 0.9      # 失衡硬直时长
const STAGGER_TIME_ELITE := 1.8
const STAGGER_TIME_BOSS := 3.2
const STAGGER_IMMUNITY_GRUNT := 3.0  # 失衡恢复后的冲击免疫期（攒不了）
const STAGGER_IMMUNITY_ELITE := 6.0
const STAGGER_IMMUNITY_BOSS := 8.0
const BOSS_STAGGER_SINK := 26.0      # BOSS 失衡瘫沉幅度（px，瘫而不坠地）

# ---- 敌人（精英·导弹车：周期导弹齐射，枪口预警） ----
const ELITE_MIN_DISTANCE := 3000.0  # 玩家跑过这段距离后精英才进选怪池
const ELITE_MAX_HP := 60
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
const BOSS_SCORE_TRIGGER := 20       # 击杀分攒满刷一场 BOSS；打完清零重计
const BOSS_MAX_HP := 700
const BOSS_SCORE := 300
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
const BOSS_SWEEP_Y := 390.0         # 扫射期机体中心目标高度（世界 y）
const BOSS_SWEEP_AIM_TIME := 0.35   # 到射高后到开火的预警窗（与预警闪光同长）
const BOSS_SWEEP_DURATION := 1.6    # 一阶段扫射持续时长（二阶段 2.2）
const BOSS_SWEEP_DURATION_P2 := 2.2
const BOSS_SWEEP_FIRE_INTERVAL := 0.085 # 机枪发弹间隔（≈12 发/秒）
const BOSS_SWEEP_SPREAD_DEG := 1.0  # 散布半角（度）：弹流扫成窄扇面；@1300px≈±45px，
									# 最低弹道 455 仍在站立头顶 470 之上——贴地安全
const BOSS_SWEEP_TWIN_OFFSET := 16.0 # 二阶段双机枪：上下枪口各偏移多少
const BOSS_SWEEP_SPEED := 1500.0
const BOSS_SWEEP_DAMAGE := 8        # 机枪单发轻（12发/s 持续流）；威胁靠命中数累积
# 直射=普攻：同一把机枪换瞄准——枪臂真瞄玩家（无预判）朝人扫一短梭，子弹与高扫
# 同款（SPEED/DAMAGE 共用 BOSS_SWEEP_*），只有射击时长不同。无重击警告（枪臂全程
# 真瞄，瞄准本身就是预警），技能（扫射/弹雨）之间各插一段。
const BOSS_DIRECT_DURATION := 0.5    # 普攻直射时长（秒）：短梭填充段，技能间穿插
# 导弹雨：发射臂充能光晕 → 追踪导弹齐射；没打中就在玩家身后锁向砸地，球状爆伤。
const BOSS_RAIN_COUNT := 4          # 一轮导弹数
const BOSS_RAIN_STAGGER := 0.26     # 出膛间隔：拉大发弹节拍，配合各自拱顶读得出"轮次"
const BOSS_RAIN_DAMAGE := 10        # 单发伤害：满轮吃满 40（二阶段 60），可活但疼
const BOSS_RAIN_BLAST_RADIUS := 70.0

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

# ---- 玩家死亡与结算 ----
const PLAYER_DAMAGE_SHAKE_STRENGTH := 8.0 # 玩家受击的镜头震动（击毁 6 / 死亡 10 之间）
const PLAYER_DEATH_SHAKE_STRENGTH := 10.0 # 玩家被毁的镜头震动（比击毁敌人更重）
const GAME_OVER_DELAY := 1.1              # 死亡→定格的延迟：让玩家爆炸播完再暂停出结算

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
const COMMS_VOICE_VOLUME_DB := 2.0   # 人声在电台总线上的电平
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
