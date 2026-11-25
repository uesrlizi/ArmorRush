class_name BalanceWorld3
## 第三章（雪原）调参：电浆布雷车 + 强袭悬空机甲「哨兵」+ 电浆浮雷 + 机械冰蠕「冰钻」（钻地体）——本章数值唯一出处，章设计正本见 design/worlds.md。
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
const PLASMA_MINE_DAMAGE := 15
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
const SENTINEL_RAIN_DAMAGE := 15
const SENTINEL_RAIN_BLAST_RADIUS := 70.0
const SENTINEL_RAIN_RECOVER := 1.4
const SENTINEL_MINE_COUNT := 4         # 一轮齐撒雷数（v2.1 3→4 弹数下限上调；phase2 +1）
const SENTINEL_MINE_LEAD_MIN := 150.0
const SENTINEL_MINE_LEAD_MAX := 1000.0
const SENTINEL_MINE_FLIGHT := 0.55     # 齐撒抛送-悬停入位时长（ST_MINE_FIRE 窗=此值+0.35）
const SENTINEL_MINE_RECOVER := 1.3
const SENTINEL_PHASE2_RAIN_BONUS := 2
const SENTINEL_PHASE2_MINE_BONUS := 1

# ---- 第三章 BOSS·机械冰蠕「冰钻」（BossWorm；全表首台钻地体——不悬浮） ----
# 形体：钻头头部 200x160（节点原点=头心）+ 10 体节（100x170，逐节收细）+ 尾节，全长≈920。
# 构图：不占悬浮锚——潜行时在玩家右侧地下蛇行（地表航迹报位），出招=破土→腾空/露头→入地；
#       潜行=框架的后摇期（ST_RECOVER），阶梯后摇缩短=潜行更短、出招更密。
# 层级：钻地体挂场景的 burrow_container（Terrain 之后画）=地下部分被地块盖住；航迹/破土/
#       入地特效走弹容器（前景）。
# 伤害律：只有冲撞态有接触伤 WORM_RAM_DAMAGE（破土上升/跃袭贯空/横冲通场/啄击，一次招式至多
#         一下）；露头/失衡瘫地/潜行碰到无伤——近战爆发窗不许被接触伤封死。
# 索敌律：只认露出地面的体节（Enemy.aim_point/is_targetable 覆写）——全埋地下=不可索敌不可打，
#         子弹/近战只打得到露出地面的碰撞形状（埋着的形状逐帧关）。
const WORM_SEG_SCALES := [1.0, 0.9956, 0.9824, 0.9604, 0.9296, 0.89, 0.8416, 0.7844, 0.7184, 0.6436, 0.5]
const WORM_SEG_LEN := 100.0      # 体节画布长（缩放前）；头 200x160、体节裸筒高 120
const WORM_SEG_TUCK := 30.0      # 相邻体节套叠量（缩放前）：弯道外侧张口由它盖住
const WORM_HEAD_TUCK := 24.0     # 头套压住首节的量
const WORM_EXPOSE_INSET := 0.3   # 露出判定：体心高出地表「体高×本系数」才算露出（半埋不算，子弹不往地里打）
const WORM_BURROW_MIN_DEPTH := 60.0  # 地下路径贴地安全深度：潜行/接近段采样点不得浅于此（防无预告露头）
const WORM_WALL_MARGIN := 110.0      # 落点离墙余量：破土/砸落点距「更高的邻块」块边至少这么多（头半宽 80）
# ---- 潜行（后摇期）：右锚地下贴轨巡游（期望速度=锚点速度+偏差×增益） ----
const WORM_CRUISE_X := 1000.0        # 潜行锚在玩家右侧多少（屏幕 x≈1800）
const WORM_CRUISE_SURGE := 220.0     # 前后涌动幅度（px）
const WORM_CRUISE_SURGE_SPEED := 1.9 # 涌动角速度（rad/s）
const WORM_CRUISE_DEPTH := 160.0     # 潜行深度（当地地表以下；台阶上方余量=本值−64>头半径 80）
const WORM_CRUISE_WEAVE := 26.0      # 深度起伏幅度（px）
const WORM_CRUISE_WEAVE_SPEED := 2.6
const WORM_CRUISE_TRACK := 3.5       # 贴轨增益：离轨点越远修正越快（/s）
const WORM_CRUISE_SPEED_MAX := 1600.0 # 追赶速度上限（>玩家跑速 600=甩不脱）
const WORM_CRUISE_IDLE_SPEED := 260.0 # 速度下限：追上了也贴着锚点来回游，不许原地停死
const WORM_TURN_RATE := 2.4          # 潜行转向角速度上限（rad/s，低速按比例收）：900px/s 时回转半径≈375
const WORM_ACCEL := 2600.0           # 速度趋近加速度（px/s²）
const WORM_ENTER_TIME := 0.7         # 入场到第一手的潜行时长（秒）
const WORM_WAKE_DEPTH := 100.0       # 航迹读数：浅于此全亮
const WORM_WAKE_FADE := 140.0        # 再深这么多航迹淡没（=潜得深=丢信号）
# ---- 破土前摇（各招共用）：贴着破土点缓缓上顶 + 地面隆起预警 ----
const WORM_WINDUP := 0.6             # 隆起预警时长（秒；ThreatFlash 固定 0.6s 驻留同档）
const WORM_WINDUP_RISE := 76.0       # 预警期上顶行程（px）：120 深顶到 44 深
const WORM_APPROACH_SPEED := 1300.0  # 地下接近段速度
const WORM_PATH_ACCEL := 5200.0      # 路径段速度切换的加速度（破土/砸落要跟手）
# ---- 普攻·露头吐锥（破土→竖身矮拱→头回钩盯人→口部三连冰锥×N 轮→回缩预告→仰头直扎入地） ----
# 这一手是「从地里探出来」不是「跳出来」：拱矮（露出≈头+4 节）、后半截始终埋着——拱高 300 时
# 啄击一冲整条都离了地，读法跟跃袭撞车。
const WORM_REAR_AHEAD := 720.0       # 破土点在玩家（按跑速预测）前方多少（站桩者露头位=右 520）
const WORM_REAR_HEIGHT := 240.0      # 身拱顶离地高度
const WORM_REAR_HEAD_HEIGHT := 195.0 # 露头位离地高度（地面近战一刀够得着：仰角<28°）
const WORM_REAR_HEAD_BACK := 200.0   # 露头位相对拱顶向玩家侧回钩多少（px）
const WORM_NECK_YAW_DEG := 50.0      # 颈关节：头相对体节切线的最大偏转（露头时转头盯人）
const WORM_REAR_HOLD := 1.15         # 露头吐锥时长（秒；二阶段 +WORM_REAR_HOLD_P2）
const WORM_REAR_HOLD_P2 := 0.7
const WORM_REAR_BURSTS := 2          # 冰锥轮数（二阶段 +1）
const WORM_REAR_BURST_GAP := 0.6     # 轮间隔（秒）
const WORM_SHARD_COUNT := 3          # 每轮冰锥数（错拍直瞄）
const WORM_SHARD_GAP := 0.1          # 错拍间隔（秒）
const WORM_SHARD_SPEED := 900.0
const WORM_SHARD_DAMAGE := 6         # 同机枪流档（受击窗内一轮只结算一发）
const WORM_REAR_TELL := 0.42         # 啄击回缩预告（秒）：口部 ThreatFlash + 头后缩
const WORM_REAR_TELL_PULL := 26.0    # 回缩行程（px）
const WORM_REAR_PECK_SPEED := 1800.0
const WORM_REAR_REACH := 580.0       # 啄击水平够得着的距离（站桩者露头位在 520 外：必在射程内；跑过头的=超出，原地入地不啄）
const WORM_REAR_RECOVER := 0.9       # 招后潜行时长（秒）
# ---- 技能A·跃袭（左后破土→过顶贯空→右前砸落） ----
const WORM_LEAP_BEHIND := 330.0      # 破土点在玩家（按跑速预测到破土时刻）身后多少
const WORM_LEAP_HEIGHT := 380.0      # 贯空拱顶离地高度（p2 压到 WORM_LEAP_HEIGHT_P2：纯跳也挨撞）
const WORM_LEAP_HEIGHT_P2 := 260.0
const WORM_LEAP_MIN_SPAN := 620.0    # 破土点→砸落点最小水平跨度（站桩者也有一道完整弧）
const WORM_LEAP_SLAM_AHEAD := 60.0   # 砸落点在玩家（按跑速预测到砸落时刻）前方多少：匀速跑=被砸
const WORM_LEAP_FLIGHT := 0.85        # 破土到砸落的滞空时长估计（秒）：砸落点按它外推玩家跑速
const WORM_LEAP_RISE_SPEED := 1500.0
const WORM_LEAP_FALL_SPEED := 1750.0
const WORM_LEAP_RECOVER := 1.2
# ---- 技能B·横冲（右前破出→贴地通场→左前扎入；p2 扎入后高位回冲一趟） ----
const WORM_SWEEP_AHEAD := 760.0      # 破出点在玩家（按跑速预测）前方多少
const WORM_SWEEP_LANE := 78.0        # 通场带中心离地高度（裸筒 120：上半露出、下缘犁雪）
const WORM_SWEEP_BAND_HALF := 90.0   # 通场带半高（相对带心）：裸筒半高 60+玩家半高 24+余量 6——玩家碰撞中心落带内即撞
const WORM_SWEEP_PAST := 250.0       # 通场越过玩家（按跑速预测）身后多少才扎入（甩头回冲整段留在屏内：冲太远=回程从画外撞来）
const WORM_SWEEP_SPEED := 2000.0
const WORM_SWEEP_RETURN_LANE := 185.0 # p2 回冲带中心离地高度：贴地=免、悬空低处=撞（先升后降）
const WORM_SWEEP_TURN_BACK := 170.0   # p2 回程破出点在扎入点左侧多少（U 形甩头的甩幅）
const WORM_SWEEP_RETURN_LEAD := 2.4   # p2 回程终点按玩家跑速外推多少秒（回程到达时刻的估计）
const WORM_SWEEP_RECOVER := 1.1
const WORM_RAM_DAMAGE := 18          # 冲撞伤（截击机俯冲同档：机体冲撞=全游戏最重一击）
# ---- 失衡=击出地面（打满冲击→摔出地表、贴地滑到玩家脚下=近战爆发窗） ----
const WORM_IMPACT_SCALE := 0.7       # 失衡阈值系数（露出窗口才吃得到冲击，阈值让一档）
const WORM_KNOCKOUT_SPEED := 1500.0
const WORM_KNOCKOUT_SKID := 610.0    # 触地后的贴地滑行长度：≥露出前身全长（≈760）−摔落段，身体才整条摊到地上
const WORM_KNOCKOUT_PAST := 150.0    # 头最多滑过玩家这么多（停在玩家左侧 150 以内=贴脸近战）
const WORM_KNOCKOUT_FAR := 760.0     # 瘫倒点离玩家右侧最远
const WORM_KNOCKOUT_TOUCHDOWN := 460.0 # 头在玩家左侧（身后破土上升中）挨满：冲过头的触地点（玩家右侧）
const WORM_REST_HEIGHT := 62.0       # 瘫倒时头心离地（头半径）
