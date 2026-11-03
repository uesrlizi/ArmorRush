class_name BalanceCombat
## 跨章共用战斗调参：枪臂瞄准/重击导弹/失衡/BOSS 走位框架/机枪流基准档/臼炮重力/击毁反馈。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。（原 scripts/core/balance.gd 拆分）
## 章专属数值见 balance_world_N.gd；BOSS_SCORE_TRIGGER/ELITE_MIN_DISTANCE（刷怪闸）在 balance_global.gd。
# ---- 枪臂可动瞄准（玩家与敌人共用） ----
const GUN_PITCH_MAX_DEG := 60.0       # 枪臂俯仰上限（度，正=朝上）
const GUN_PITCH_RETURN_SPEED := 180.0 # 无目标时回平速度（度/秒）
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
const IMPACT_RESIST_BOSS := 240.0    # BOSS
const STAGGER_TIME_GRUNT := 0.9      # 失衡硬直时长
const STAGGER_TIME_ELITE := 1.8
const STAGGER_TIME_BOSS := 4.0
const STAGGER_IMMUNITY_GRUNT := 3.0  # 失衡恢复后的冲击免疫期（攒不了）
const STAGGER_IMMUNITY_ELITE := 6.0
const STAGGER_IMMUNITY_BOSS := 8.0
const BOSS_STAGGER_SINK := 26.0      # BOSS 失衡瘫沉幅度（px，瘫而不坠地）
# ---- BOSS（追击大型机：水平弹簧构图位同行，扫射 ⇄ 弹雨 轮换、间插普攻直射） ----
# 跑酷不断、镜头不接管：BOSS 是"追击段落"不是关卡。水平是放松的弹簧——玩家推进
# 把 BOSS 压近、倒退把它甩出画面右缘（出画不打断出招，站定它自己踱回来）；
# 扫射只变高度（压到射高开火）。动作之间只隔各自后摇，无独立间歇；
# 离玩家过近压住不出招（贴脸反应窗）。
const BOSS_DEFENSE := 5             # 防御力
									# 近战绕盾全额（15/25）——强化"枪射攒失衡→近战爆发"的分工
const BOSS_SCORE := 50
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
const BOSS_DIRECT_RECOVER := 0.9    # 普攻直射后摇（秒）
const BOSS_PHASE2_RECOVER_SCALE := 0.6 # 二阶段后摇缩短比例
const BOSS_PHASE2_RATIO := 0.5      # 半血进二阶段
const BOSS_ATTACK_MIN_DISTANCE := 700.0 # 离玩家水平距小于此不出招：硬直贪刀后 BOSS 弹回这个距离才重新开火（脱身反应窗）
# ---- 机枪流基准档（跨章共用：真瞄直射/扫射的弹道与旋翼表现；ch2/3/5/7 按此档换皮参照） ----
const BOSS_SWEEP_FIRE_INTERVAL := 0.085 # 机枪发弹间隔（≈12 发/秒）
const BOSS_ROTOR_SPIN := 14.0        # 尾旋翼转速（rad/s，整周旋转）
const BOSS_ROTOR_WOBBLE := 0.035     # 主旋翼呼吸摆幅（rad：侧视刃边不整周旋转）
const BOSS_ROTOR_WOBBLE_SPEED := 19.0 # 主旋翼摆动频率
const BOSS_SWEEP_SPEED := 1000.0
const BOSS_SWEEP_DAMAGE := 8        # 机枪单发轻（12发/s 持续流）；威胁靠命中数累积
# 直射=普攻：同一把机枪换瞄准——枪臂真瞄玩家（无预判）朝人扫一短梭，子弹与高扫
# 同款（SPEED/DAMAGE 共用 BOSS_SWEEP_*），只有射击时长不同。无重击警告（枪臂全程
# 真瞄，瞄准本身就是预警），技能（扫射/弹雨）之间各插一段。
const BOSS_DIRECT_DURATION := 0.5    # 普攻直射时长（秒）：短梭填充段，技能间穿插
# ---- 迫击炮弹道（熔渣弹：真抛体，与导弹彻底分家，见 mortar_shell.gd） ----
const MORTAR_GRAVITY := 4000.0        # ≈4×玩家重力：弧快不掉速，全程 ~0.7s、弧顶 ≈+120px
# ---- 击毁反馈（爆炸特效本体参数在 explosion_burst.gd，这里只管手感） ----
const KILL_SHAKE_STRENGTH := 6.0  # 击毁镜头震动幅度（近战命中 7，这里略低）
const KILL_HITSTOP_TIME := 0.04   # 击毁顿帧时长（真实时间）
const KILL_HITSTOP_SCALE := 0.15  # 击毁顿帧时间流速（比近战顿帧温和）
