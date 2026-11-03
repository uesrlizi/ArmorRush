class_name BalanceWorld4
## 第四章（珊瑚夜）调参：炮台车「海葵」+ 深海猎杀舰「鮟鱇」+ 珊瑚重弹/珊瑚潮——本章数值唯一出处，章设计正本见 design/worlds.md。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。（原 scripts/core/balance.gd 拆分）
## 跨章共用件见 balance_combat.gd（重击导弹/失衡/机枪流基准档）。
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
# 驳船/哨兵档。招式=珊瑚重炮 ⇄ 珊瑚潮（腹下放电舱吐贴地涌浪），间插钓灯爆闪
# 普攻（2026-11-02 机枪短梭→钓灯一次爆闪、径向慢矢齐放：一矢对准玩家、余矢
# 等分圆周，弹=coral_bolt.tscn 纯换皮；拉开距离即躲，贴脸 700 压招保底）。
# 三招三种几何：重炮=点（lead 慢弹）、潮=线（贴地涌浪）、爆闪=面（径向弹雾）。
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
const ANGLER_FLASH_COUNT := 6         # 钓灯爆闪（普攻）径向矢数（phase2 +2）
const ANGLER_FLASH_SPEED := 400.0     # 慢矢（机枪流 1000 的 0.4）：弹体自读，走开就躲
const ANGLER_FLASH_DAMAGE := 6        # 单矢轻：径向雾实际只吃 1~2 矢（满吃 36 仍 < 旧短梭 48）
const ANGLER_FLASH_DELAY := 0.15      # 钓灯亮起到爆闪的一拍（无预警闪，灯亮本身是读法）
const ANGLER_FLASH_WINDOW := 0.45     # 出手窗：爆闪后留一拍让矢散开再收势
const ANGLER_PHASE2_FLASH_BONUS := 2
