class_name BalanceWorld1
## 第一章（锈雨）调参：精英导弹车 + 追击直升机专属段——本章数值唯一出处，章设计正本见 design/worlds.md。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。（原 scripts/core/balance.gd 拆分）
## 走位框架与机枪流基准档在 balance_combat.gd（boss.gd/pursuit_boss.gd 与后续各章共用）。
# ---- 敌人（精英·导弹车：周期导弹齐射，枪口预警） ----
const ELITE_SCORE := 60
const ELITE_ATTACK_RANGE := 2200.0
const ELITE_VOLLEY_HALF_LIFE := 2.2 # 齐射触发半衰期（平均 ~3.2s 一轮，泊松采样同杂兵）
const ELITE_VOLLEY_COUNT := 2       # 每轮导弹数
const ELITE_VOLLEY_STAGGER := 0.28  # 轮内发射间隔
const ELITE_MISSILE_DAMAGE := 8
const ELITE_BLAST_RADIUS := 95.0    # 爆炸球半径（玩家判定另加半宽宽限）
# ---- 第一章 BOSS·追击直升机（本章专属段） ----
# 高位扫射：BOSS 真的机动到射高再开火（本体压下来就是预警），不虚空射击。
# 射高=枪口 410：最高地形站立头顶（536-66=470）之下余量 60px，
# 跳跃顶点擦不到，滞空挨打。持续机枪流（不是齐射）：小散布角扫成扇面。
const BOSS_SWEEP_Y := 350.0         # 扫射期机体中心目标高度（世界 y）
const BOSS_SWEEP_AIM_TIME := 0.35   # 到射高后到开火的预警窗（与预警闪光同长）
const BOSS_SWEEP_DURATION := 1.6    # 一阶段扫射持续时长（二阶段 2.2）
const BOSS_SWEEP_DURATION_P2 := 2.2
const BOSS_SWEEP_SPREAD_DEG := 1.0  # 散布半角（度）：弹流扫成窄扇面
const BOSS_SWEEP_TWIN_OFFSET := 16.0 # 二阶段双机枪：上下枪口各偏移多少
const BOSS_SWEEP_RECOVER := 1.2     # 扫射后摇（秒）：后摇到点直接出下一手，动作间无独立间歇
# 导弹雨：背部导弹舱预警闪光 → 追踪导弹逐孔齐射；没打中就在玩家身后锁向砸地，球状爆伤。
const BOSS_RAIN_COUNT := 4          # 一轮导弹数
const BOSS_RAIN_STAGGER := 0.26     # 出膛间隔：拉大发弹节拍，配合各自拱顶读得出"轮次"
const BOSS_RAIN_DAMAGE := 10        # 单发伤害：满轮吃满 40（二阶段 60），可活但疼
const BOSS_RAIN_BLAST_RADIUS := 70.0
const BOSS_RAIN_RECOVER := 1.4      # 弹雨后摇（秒）
const BOSS_PHASE2_RAIN_BONUS := 2   # 二阶段导弹 +2 发
