class_name BalanceWorld10
## 第十章（硫焰地热田）调参：井口封堵车「窜井」+ 自升式钻井平台「井口」+ 硫焰井口/
## 硫云爆燃/硫焰扫掠——本章数值唯一出处，章设计正本见 design/worlds.md + 威胁设计
## art_proposals/sulfur_ch10/威胁设计_ch10.md（§0 唯一参照系、§5 数值表；终审裁定 R1-R17）。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。
## 跨章共用件见 balance_combat.gd（失衡/后摇/走位框架/MORTAR_GRAVITY）。
## 时间原点约定（R3）：每一手的全部时刻从**发射方 ThreatFlash 亮起 t=0** 起算，
## lead 也在 t=0 采样（玩家位置 px、速度 vx）。档位名只用 tier0(g=664)/tier1(g=600)/
## tier2(g=536)；高度 h = 地表 g − 世界 y（向上为正）。

# ---- 硫焰井口 SulfurVent（本章核心危险件：落地钉死的竖直焰墙，见 sulfur_vent.gd） ----
# 时序（绝对时间）：闪光 [0,0.6] → 钻头飞 0.7 → 落位 1.3 → 钻入到 1.7 → 亮井 1.7 起（无伤）
# → 首喷 2.3+0.6k（纵队第 k 口靠亮井期延长 0.6k 实现）→ 喷 0.45 / 息 0.75（周期 1.2）。
# BOSS 井每口 3 喷（熄灭=首喷+2.85）；精英井每口 2 喷（熄灭=首喷+1.65）。
const VENT_WARN := 0.6              # 发射方 DrillPort ThreatFlash 驻留（出钻前，warn() 同拍）
const VENT_FLIGHT := 0.7            # 钻头飞行（t=0.6 出膛 → 1.3 落位）
const VENT_BURROW := 0.4            # 钻入（1.3 → 1.7）
const VENT_FIRST_LIT := 0.6         # 亮井到首喷（1.7 → 2.3）
const VENT_FLARE_ON := 0.45         # 单次喷发
const VENT_FLARE_OFF := 0.75        # 息窗（周期 1.2）
const VENT_PULSES := 3              # BOSS 纵队井每口喷数（相对首喷 0/1.2/2.4）
const VENT_WIDTH := 64.0            # 井筒宽（判定半宽 32 + 玩家半宽 20 = 有效半宽 52）
const VENT_HEIGHT := 220.0          # 焰柱高（纯跳脚底最高 83.4 = 38% → 跳≠过）
const VENT_DAMAGE := 15             # 每次喷发至多结算一次
const VENT_DRILL_STAGGER := 0.15    # 纵队钻头出膛梯次（只是视觉节奏，不进时间线）
# 落位：xv = px + clamp(vx·2.4, 240, 1440)——满速玩家 t=2.4 抵达井位恰处第一喷。
const VENT_LEAD_TIME := 2.4
const VENT_LEAD_MIN := 240.0
const VENT_LEAD_MAX := 1440.0
const VENT_STAGGER := 0.6           # 纵队第 k 口首喷 = 2.3 + 0.6k
const VENT_PITCH := 360.0           # 纵队间距
# 档位边界避让（R10）：距任一 320·n 小于 52 → 依次试 +96、−96；仍不合格（含脚手架
# ±104 重叠）取消该口；纵队被取消的口留空，其余口保持原 k 与首喷。
const VENT_EDGE_MIN := 52.0
const VENT_EDGE_RETRY := 96.0
const VENT_SCAFFOLD_PAD := 104.0
const VENT_CHUNK_W := 320.0
# 亮井闪烁（R11）：f = min(1/剩余到下一喷时间, 4) Hz。
const VENT_BLINK_MAX_HZ := 4.0

# ---- 第十章精英·井口封堵车「窜井」（固定射角钻机架，单口双喷，教「等息穿」） ----
# 教学位：只预教 BOSS 技能 A 的单口节拍读法（看第一喷、息窗里穿）。
# 冷却闸：本车上一口井熄灭前不出新套（"sulfur_vents" 组同主存活 ≤1）。
const ELITE_FOUNTAIN_SCORE := 60
const ELITE_FOUNTAIN_ATTACK_RANGE := 2200.0
const ELITE_FOUNTAIN_VOLLEY_HALF_LIFE := 2.4
const ELITE_FOUNTAIN_PULSES := 2    # 喷 [2.3,2.75] / 息 [2.75,3.5] / 喷 [3.5,3.95]，3.95 熄

# ---- 第十章 BOSS·自升式钻井平台「井口」（300×180 hover 370：船底 460、对最高台阶 536
# 净空 76）。轮换 A 井压线 → 普攻 → B 硫云爆燃 → 普攻；后摇 A 1.4 / B 1.4 / 普攻
# BOSS_DIRECT_RECOVER 0.9，p2 ×0.6（框架）。 ----
const WELLHEAD_HOVER_Y := 370.0

# 技能A 井压线：DrillPort 预警 → 纵队 3 口（p2 4 口）xk = xv + k·360。
const WELLHEAD_VENT_COUNT := 3
const WELLHEAD_VENT_P2_BONUS := 1
const WELLHEAD_RECOVER := 1.4

# 技能B 硫云爆燃：VentPort 预警 0.6 → 硫气弹 0.5 入带 → 引火线 [1.1,1.8] → 1.8 自带右端
# （BOSS 侧）向左点燃，火锋 2500px/s，燃烧窗 [1.8,2.4]：燃烧区 = [max(锋, xL), xR]，2.4 燃完
# 不驻留。带 = 固定绝对高度 y∈[428,512]，横向 xL = px + clamp(vx·1.0, 0, 600)，宽 1000
# （满速 [600,1600]、站桩 [0,1000]，lead 只向前）。罚 tier2 站立与 tier1 起跳；tier1/tier0
# 贴地免；推进飞越（threat_calc R8：满速 tier2 最晚 1.6 起跳、tier1 最晚 1.4 起跳免）。
const SULFUR_CLOUD_WARN := 0.6
const SULFUR_CLOUD_FEED_FLIGHT := 0.5
const SULFUR_CLOUD_IGNITE := 1.8
const SULFUR_CLOUD_FRONT_SPEED := 2500.0
const SULFUR_CLOUD_BURN := 0.6
const SULFUR_CLOUD_BAND_TOP := 428.0
const SULFUR_CLOUD_BAND_BOTTOM := 512.0
const SULFUR_CLOUD_SPAN := 1000.0
const SULFUR_CLOUD_LEAD_TIME := 1.0
const SULFUR_CLOUD_LEAD_MAX := 600.0
const SULFUR_CLOUD_DAMAGE := 15
# 派招闸（R7）：[xL, xL+1000] 内 tier2(g=536) 累计宽度 ≥320 才派 B；
# 受罚区间闸（R16）：xRrel = lead+1000，t* = (xRrel+4500)/(vx+2500)，
# I = [px+vx·t*−20, px+vx·2.4+20]，tier2 与 I 的交集宽度 ≥40 才派 B。
# 任一不满足 → 本轮改派 A，B 冷却不消耗（下一次轮到 B 再查）。
const SULFUR_CLOUD_TIER2_MIN_WIDTH := 320.0
const SULFUR_CLOUD_PENALTY_MIN_WIDTH := 40.0
const SULFUR_CLOUD_PENALTY_PAD := 20.0
const SULFUR_CLOUD_TIER2_Y := 536.0
const WELLHEAD_CLOUD_RECOVER := 1.4

# 普攻 硫焰扫掠：NozzlePort（世界 y=424）出手锁定 7 团（p2 8 团），全部穿过出手瞬间
# 玩家中心 x，到靶高 h = 210..0 步进 35（p2 加 h=245），down/up 每轮交替；梯次 0.07、
# 首团延迟 0.12、速度 850、伤 7/团。逐发校平（R9）：沿射线每 16px 采样 surface_y_at，
# 埋入则抬角 6°（减小下俯），至多 2 次，仍埋 → 该发哑火不生成弹体。
# 读法（R7）：火鞭出手时继续往前跑=免；停下/站桩=吃（后撤不是解：threat_calc 扫 0..1000px 均中）。
const FLARE_SWEEP_PUFFS := 7
const FLARE_SWEEP_P2_BONUS := 1
const FLARE_SWEEP_H_TOP := 210.0
const FLARE_SWEEP_H_STEP := 35.0
const FLARE_SWEEP_SPEED := 850.0
const FLARE_SWEEP_GAP := 0.07
const FLARE_SWEEP_DELAY := 0.12
const FLARE_SWEEP_DAMAGE := 9       # 普攻火鞭 7 团连串：受击无敌窗内只结算一团（扫射类单发略提）
const FLARE_SWEEP_SAMPLE := 16.0
const FLARE_SWEEP_LIFT_DEG := 6.0
const FLARE_SWEEP_LIFT_MAX := 2
