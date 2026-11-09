class_name BalanceWorld5
## 第五章（破晓云廊）调参：防空炮车「响哨」+ 高空截击机「截击机」+ 啸雷弹——本章数值唯一出处，章设计正本见 design/worlds.md。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。（原 scripts/core/balance.gd 拆分）
## 跨章共用件见 balance_combat.gd（重击导弹/失衡/机枪流基准档）。
# ---- 啸雷弹（第五章精英/BOSS 共用：定距空爆的防空重击弹，见 flak_shell.gd） ----
# 惩罚账（art_proposals/dawn_ch5/提案_v1_破晓云廊.md §2 几何数字表）：直线无
# 重力+定距引信（出膛瞬间按炮口→玩家当时位置的距离解算爆点）——**停=吃/动=免**，
# 与 ch4 重弹的 lead 惩罚互为镜像（那边罚匀速跑，这边罚不跑）。全速跑在
# 预警 0.6s+飞行 ~0.58s 内位移 708px ≫ 爆区 136，必过；站桩/近战硬直
# （RECOVER_CONTROL 0.35 → ~126px）在猎杀半径内；悬停=吃（防空语义）。
# 射线撞台阶立面=早爆（掩体合法，不校平）。追踪语汇零涉及。
const FLAK_SHELL_SPEED := 2400.0      # 弹速（=玩家弹速档：读法靠炮口预警+引信芯快闪）

# ---- 第五章精英·防空炮车「响哨」（双管高炮俯仰跟踪，双连啸雷弹） ----
# 教学位：把「截击机」的啸雷提前教给玩家——读炮口预警+引信芯快闪，
# 爆点=开火瞬间自己所在点：听到/看到预警就保持移动，停=吃。
const ELITE_SIREN_SCORE := 60
const ELITE_SIREN_ATTACK_RANGE := 2200.0
const ELITE_SIREN_VOLLEY_HALF_LIFE := 2.4 # 齐射触发半衰期（同前四章精英的泊松节奏）
const ELITE_SIREN_VOLLEY_COUNT := 2 # 轮内双发梯次
const ELITE_SIREN_VOLLEY_STAGGER := 0.45
const ELITE_SIREN_FLAK_DAMAGE := 12
const ELITE_SIREN_FLAK_BLAST_RADIUS := 90.0 # 爆区球（+玩家半宽 26 宽限）

# ---- 第五章 BOSS·高空截击机「截击机」（300×180 机体 hover 370：机腹 460=t2 ----
# 站立头顶上方 10px、对最高台阶 536 净空 76px，同驳船/哨兵/灯笼鱼档。招式=
# 啸雷齐射 ⇄ 俯冲突袭（首次机体冲撞：预警 0.6s→锁定出手点→2100px/s 直线
# 通场扫地面通道→过冲拉起返锚），间插机鼻曳光直射（dawn_bolt.tscn=bullet.gd
# 纯换皮，速度/伤害复用 BOSS_SWEEP_*）。分工账：啸雷 hunts 空中与驻停
# （爆在玩家当时所在点），俯冲 hunts 地面通道（飞行玩家不在通场带）——
# 玩家被迫两头换层。俯冲线每帧 clamp 中心 y ≤ 当地地表−120（滑过台阶上缘
# 不穿模）；通场带覆盖 [地表−210, 地表−30]：站立=被撞、纯跳 apex −127=被撞
# （压"跳过一切"）、推进 ≥204px 或横移出锁定线=免。
const INTERCEPTOR_HOVER_Y := 370.0
const INTERCEPTOR_FLAK_COUNT := 3        # 一轮啸雷数（phase2 +1）
const INTERCEPTOR_FLAK_STAGGER := 0.35   # 弹串节拍（追赶读法：每 840px 一朵）
const INTERCEPTOR_FLAK_DAMAGE := 15
const INTERCEPTOR_FLAK_BLAST_RADIUS := 110.0
const INTERCEPTOR_FLAK_RECOVER := 1.3
const INTERCEPTOR_DIVE_WARN := 0.6       # 机鼻预警+尾焰增亮时长
const INTERCEPTOR_DIVE_SPEED := 2100.0   # 俯冲速度（直线锁定线，出手瞬间锁一次）
const INTERCEPTOR_DIVE_CLEAR := 120.0    # 通场净空：中心线压在当地地表上空这么高
const INTERCEPTOR_DIVE_OVERSHOOT := 500.0 # 过冲距离（穿过锁定点后继续冲这么远再拉起）
const INTERCEPTOR_DIVE_DAMAGE := 18      # 机体冲撞（每次俯冲至多结算一次）
const INTERCEPTOR_DIVE_RECOVER := 1.2
const INTERCEPTOR_PHASE2_FLAK_BONUS := 1
