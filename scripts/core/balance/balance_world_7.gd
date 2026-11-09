class_name BalanceWorld7
## 第七章（溺海都会）调参：海防炮车「岸炮」+ 打捞巡防舰「沉锚」+ 跳弹/深弹涌浪——本章数值唯一出处，章设计正本见 design/worlds.md。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。（原 scripts/core/balance.gd 拆分）
## 跨章共用件见 balance_combat.gd（重击导弹/失衡/机枪流基准档）。
# ---- 跳弹（第七章精英/BOSS 共用：平抛发射→连跳弹道，见 skip_shell.gd） ----
# 惩罚账（提案_v1 §2 + v2 变更段 2026-11-03）：**平抛鱼雷**——水平初速向玩家
# 一侧出膛（**不瞄人**，炮位定平射向；v1 解算落玩家脚下，正常行进下落点全在
# 行进方向身后=「跳的没意义」，用户判死），发射点在船体下部（艏部下管，鱼雷
# 语汇；BOSS 技能A 压低到 ANCHOR_SKIP_FIRE_Y 发射），重力拉浅垂弧触甲板
# （发射净空 60 → 落差 60..180 按档），触地反弹 apex 固定 90、水平速度按跳序
# 衰减（跳距 509/432/367 可预判），第 4 次触地=球爆。**对冲几何**：玩家 +X
# 行进 vs 弹 −X 平抛/跳=迎面相遇——平射段在头部高度（停=被平射命中），首跳
# 带与跳弧全在玩家**前方**；**跳过弹体=免**（纯跳脚底 +67 > 弹体接触带；跳弧
# 中段 f∈[0.3,0.7] 弹高 >78 站立擦顶不中）。撞台阶立面（埋深超限）=撞墙当场
# 起爆，零穿模。真弹道抛体（不是贴地滑行跟随件，禁令不适用）。
const SKIP_SHELL_SPEED := 1300.0       # 平抛初速（水平，向玩家一侧）
const SKIP_SHELL_HOP_APEX := 90.0      # 每跳弹道顶高（纯跳 67 可越过）
const SKIP_SHELL_HOP_SPEED := 1200.0   # 首跳水平速度（跳距 509）
const SKIP_SHELL_HOP_DECAY := 0.85     # 逐跳速度衰减（跳距 509/432/367）
const SKIP_SHELL_HOPS := 3             # 跳数（第 4 次触地=球爆）
const SKIP_SHELL_CONTACT_RADIUS := 22.0    # 弹体接触半径（+玩家半宽 26 宽限）
const SKIP_SHELL_WALL_PENETRATION := 40.0  # 触地埋深超过此值=撞台阶立面（起爆）

# ---- 第七章精英·海防炮车「岸炮」（俯仰真瞄海防炮，双连跳弹） ----
# 教学位：把「沉锚」的跳弹齐射提前教给玩家——读落点溅花+弹跳节奏，
# 落点=你现在站着的地方：看到溅花就跳，停=吃，顺着跑被下一跳追咬。
const ELITE_SHORE_SCORE := 60
const ELITE_SHORE_ATTACK_RANGE := 2200.0
const ELITE_SHORE_VOLLEY_HALF_LIFE := 2.4 # 齐射触发半衰期（同前六章精英的泊松节奏）
const ELITE_SHORE_VOLLEY_COUNT := 2    # 轮内双发梯次
const ELITE_SHORE_VOLLEY_STAGGER := 0.55
const ELITE_SHORE_SKIP_DAMAGE := 12
const ELITE_SHORE_SKIP_BLAST_RADIUS := 90.0 # 末跳球爆（+玩家半宽宽限）

# ---- 第七章 BOSS·打捞巡防舰「沉锚」（300×180 机体 hover 370：船底 460=t2 ----
# 站立头顶上方 10px、对最高台阶 536 净空 76px，同驳船/哨兵/灯笼鱼/截击机/赤轮档。
# 招式=跳弹齐射（艏炮俯仰真瞄→逐发梯次 SkipShell，每发落玩家**当时**脚下）
# ⇄ 深弹涌浪（艉舱向艉侧抛 DepthCharge 落海→定延时闷爆→SeaSurge 固定高度带
# 漫桥，见 SEA_SURGE 段），间插舰炮曳光直射（sea_bolt.tscn=bullet.gd 纯换皮，
# 速度/伤害复用 BOSS_SWEEP_*）。分工账：跳弹 hunts 地面站位与顺向跑（跳=反制），
# 涌浪 hunts 低处停留（上=反制）——两手都把玩家往"上"赶。
const ANCHOR_HOVER_Y := 370.0
const ANCHOR_SKIP_FIRE_Y := 480.0      # 跳弹发射高度（绝对锚，技能A 压低用）：
									   # 船底 570→管口 ~540，对档 664 甲板落差 ~120；
									   # 同 ch1 扫射压高语言（本体压下来=预警）
const ANCHOR_SKIP_CLEAR := 150.0       # 发射高度对当地地表的净空账：锚 ≤ 地表−150
									   # （船底=锚+90 ≥ 地表上方 60，高台阶自动抬高）
const ANCHOR_SKIP_COUNT := 2           # 一轮跳弹数（p2 +1=三连波）
const ANCHOR_SKIP_STAGGER := 0.45      # 弹串节拍（p2 0.35：追赶读法）
const ANCHOR_PHASE2_SKIP_BONUS := 1
const ANCHOR_PHASE2_SKIP_STAGGER := 0.35
const ANCHOR_SKIP_DAMAGE := 15
const ANCHOR_SKIP_BLAST_RADIUS := 100.0
const ANCHOR_SKIP_RECOVER := 1.3
const ANCHOR_CHARGE_COUNT := 2         # 一轮深弹数（同波涌浪，一次投放）
const ANCHOR_CHARGE_STAGGER := 0.25    # 出舱梯次
const ANCHOR_CHARGE_TOSS := 260.0      # 艉侧抛出水平初速（抛离玩家一侧）
const ANCHOR_SURGE_RECOVER := 1.4

# ---- 深弹涌浪（第七章 BOSS 技能B：固定绝对高度带漫桥，见 sea_surge.gd） ----
# 惩罚账（提案 §2）：深弹落海（白沫水花）→ 定延时闷爆（青白晕）→ 涌浪漫桥
# ——三重预警 ≈2.0s 反应窗。**固定绝对高度带**（不管地面、零地形跟随，珊瑚潮
# 同类合法件）：水面从屏下升到 FLOOD_Y，驻留，退去。p1 只淹最低档（基准档
# 脚底 664 > 620 吃，二档 600 免）；p2 淹到二档（600 > 584 吃）——纯跳脚底
# 597 在 p1 够（<620）在 p2 不够（>584）=「跳不过去就飞」的二阶段加压；
# 浮空脚手架/断桥顶（地表−100..−200）=合法掩体。一次涌浪至多结算一次。
const SEA_SURGE_SEA_Y := 860.0         # 海面固定线（同 bridge_sea_y）
const DEPTH_CHARGE_FUSE := 0.6         # 落海→闷爆定延时
const SEA_SURGE_FLOOD_Y := 620.0       # 水面高度（绝对世界 y；p1）
const SEA_SURGE_PHASE2_FLOOD_Y := 584.0 # 水面高度（p2：淹到二档）
const SEA_SURGE_SWELL := 0.6           # 涌起预告（浪冠从屏底缓升）
const SEA_SURGE_RISE := 0.35           # 漫桥（水面升到 FLOOD_Y）
const SEA_SURGE_HOLD := 0.55           # 驻留
const SEA_SURGE_RECEDE := 0.6          # 退去
const SEA_SURGE_DAMAGE := 15
