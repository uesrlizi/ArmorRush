class_name BalanceWorld8
## 第八章（镜盐之原）调参：钻机车「喷井」+ 悬浮采盐联合机「盐磨」+ 间歇泉/
## 定镜灼烤——本章数值唯一出处，章设计正本见 design/worlds.md + 提案
## art_proposals/salt_ch8/提案_v1_镜盐之原.md（§2 几何数字表）。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。
## 跨章共用件见 balance_combat.gd（重击导弹/失衡/机枪流基准档）。

# ---- 间歇泉（第八章核心危险件：静止地裂 → 瞬时汽柱，见 salt_geyser.gd） ----
# 惩罚账（提案 §2）：**离=唯一反制**（0.7s 预警窗内跑出 mark，600×0.7=420
# > 柱半宽 45+26 ✓）；**跳≠过**（柱高 360 = 纯跳 67 的 5.4 倍，柱寿 0.55s 内
# 推进可爬 ~176，第一眼即「别跳，跑」——读法验收项）；**穿缝=免**（BOSS 泉幕
# 间距 232−90=142 > 玩家宽 52）；等全灭后跑过空场=免（梯次远→近，身后先灭）。
# mark=静止落点零地形跟随（装药/锚桩同族）；汽柱=静止竖直件；贴地跟随禁令不受累。
const SALT_GEYSER_WARN := 0.7      # mark 预警窗（地裂环纹+预漏白汽渐急）
const SALT_GEYSER_ERUPT := 0.55    # 喷发持续（柱寿）
const SALT_GEYSER_CLOSE := 0.2     # 收柱淡出
const SALT_GEYSER_WIDTH := 90.0    # 柱宽（AABB 判定半宽 45+玩家半宽宽限）
const SALT_GEYSER_HEIGHT := 360.0  # 柱顶高（地表−360；纯跳 67 的 5.4 倍）
const SALT_GEYSER_DAMAGE := 10     # 一次喷发至多一次

# ---- 裂地镖（间歇泉的运载弹：弹落点=mark，见 salt_dart.gd） ----
# 真实枪口律：泉的 mark 由裂地镖从出膛口（精英钻尖/BOSS 腹口）落地生成
# （ch6 装药同构）；弹体小 16x8 快速一闪即落，读法归地面标记本身。
const SALT_DART_SPEED := 2400.0    # 平飞速度档（飞行时长按距离 clamp 反推）
const SALT_DART_FLIGHT_MIN := 0.45
const SALT_DART_FLIGHT_MAX := 0.85

# ---- 第八章精英·钻机车「喷井」（固定射角钻塔，单发裂地镖） ----
# 教学位：把「盐磨」的间歇泉提前教给玩家——「柱是墙不是弹」（跳≠过、只有离）
# 必须由精英单发纯净教；mark 落点=玩家当时脚下（无 lead），看到地裂环纹就跑。
const ELITE_GUSHER_SCORE := 60
const ELITE_GUSHER_ATTACK_RANGE := 2200.0
const ELITE_GUSHER_VOLLEY_HALF_LIFE := 2.4 # 齐射触发半衰期（同前七章精英的泊松节奏）

# ---- 第八章 BOSS·悬浮采盐联合机「盐磨」（300×180 机体 hover 370：船底 460
# =t2 站立头顶上方 10px、对最高台阶 536 净空 76px，同驳船/哨兵/鮟鱇/断云/
# 赤轮/沉锚档。招式=间歇泉幕（技能A）⇄ 定镜灼烤（技能B）+ 融盐重弹（普攻=
# 单发点放，2026-11-06 用户「别像普通机枪，要配得上镜阵聚焦口」：镜阵聚热
# 熔出的盐弹，同 ch2 排炮重弹「出手锁定的一次性形态」家族——离散点放无逐发
# 跟踪，可跳越/挪位）。分工账：泉幕=罚站桩与罚直线穿行（离/穿缝/等），灼点=
# 罚匀速与罚慢挪（变速变向）——全章语言=「变速变向，读线走位」。 ----
const SALTMILL_HOVER_Y := 370.0

# 技能A 间歇泉幕：腹口（BayPort）预警 → 裂地镖 5 枚梯次远→近，落点锚玩家
# **当时**位置前后铺开（无 lead）→ 各自 mark→汽柱。梯次远→近=身后先灭，
# 「等全灭跑过空场」也是合法反制。
const SALTMILL_GEYSER_COUNT := 5
const SALTMILL_GEYSER_SPAN := 900.0     # 最远 mark 在玩家前方
const SALTMILL_GEYSER_REAR := 28.0      # 最近 mark 在玩家身后
const SALTMILL_GEYSER_STAGGER := 0.15   # 出膛梯次（远→近）
const SALTMILL_GEYSER_RECOVER := 1.3

# 技能B 定镜灼烤：镜翼蓄光 → 干燥光束线（镜面→落点，无伤=反向预告：先看见
# 烧哪）→ 灼点 tick 区。**半 lead**（玩家速度×时长 clamp LEAD_MAX，ArcFence
# 同账）——罚匀速不罚变速：匀速跑 600×1.1=660 > clamp 400 → 灼点卡在跑者
# 前方 ≤400 处必经；停=吃（lead≈0 落脚下）；变速/变向=免（ch2/ch4/ch6 相对
# 速度家族）。梯次连点压挪位路线。
const SALTMILL_BURN_COUNT := 2          # 一轮灼点数（p2 +1）
const SALTMILL_BURN_STAGGER := 0.6      # 梯次连点
const SALTMILL_PHASE2_BURN_BONUS := 1
const SALTMILL_PHASE2_BURN_STAGGER := 0.5
const SALTMILL_BURN_RECOVER := 1.4

# ---- 定镜灼烤（第八章 BOSS 技能B：干燥光束线 → lead 灼点，见 mirror_burn.gd） ----
# 灼点=SlagPool 语法换皮（蓄热期=光束线预告窗，亮起不咬人；tick 期=咬人），
# 视觉=盐面灼白斑+蒸汽（量级同 ch2 火区）。
const MIRROR_BURN_GLOW := 0.5           # 镜翼蓄光（光束线之前的翼面泛粉）
const MIRROR_BURN_LEAD_TIME := 1.1      # lead 时长（玩家速度×1.1）
const MIRROR_BURN_LEAD_MAX := 400.0     # lead 距离 clamp（ArcFence 同账）
const MIRROR_BURN_BEAM := 0.4           # 干燥光束线驻留（无伤预告）
const MIRROR_BURN_TICK_TIME := 0.9      # 灼点 tick 区持续
const MIRROR_BURN_RADIUS := 80.0
const MIRROR_BURN_DAMAGE := 6           # 每 tick 6
const MIRROR_BURN_TICK := 0.3

# ---- 融盐重弹（第八章 BOSS 普攻：镜阵聚热熔盐点放，见 salt_bolt.tscn） ----
# 惩罚账（ch2 排炮重弹同族=「出手锁定的一次性形态」）：单发慢大弹朝玩家
# **出手瞬间**位置（无预判无逐发跟踪，离散点放不是弹流），弹体自读、可跳越/
# 挪位；p2 双发各自重瞄（间隔内再瞄一次，仍是离散点放）。开火戏=枪口焰+熔杏
# 爆闪双叠+fire_heavy 专配出膛音（同 ch2 重弹的「重炮点放」份量）。
const SALTMILL_MOLTEN_SPEED := 700.0    # 机枪流七成档：慢大弹可读可跳越
const SALTMILL_MOLTEN_DAMAGE := 12      # 单发（ch2 重弹同账：旧短梭满吃 48 → 单发 12，普攻低于技能）
const SALTMILL_MOLTEN_DELAY := 0.12     # 枪臂真瞄到位的一拍再点放（方向锁定在出手瞬间）
const SALTMILL_MOLTEN_TWIN_GAP := 0.15  # p2 双发间隔（第二发各自重瞄）
const SALTMILL_PHASE2_MOLTEN_BONUS := 1
