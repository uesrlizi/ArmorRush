class_name BalanceGlobal
## 全局系统调参：头顶血条/死亡结算与转场/启动页/系统播报/刷怪间距/地形/镜头。
## 只在这里改数值，场景和脚本不保存副本，避免“改了没效果”的遮蔽问题。（原 scripts/core/balance.gd 拆分）
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
# ---- 死亡结算与章节转场 ----
const GAME_OVER_DELAY := 1.1              # 死亡→定格的延迟：让玩家爆炸播完再暂停出结算
# 结算重开闸（防误触）：入场动画播完才受理重开，「点击屏幕或按任意键重新开始」
# 提示与开闸同拍亮起=看见提示才能按。开关拨 false 回旧制（面板一出即开闸）。
const RESULT_RESTART_AFTER_INTRO := true
const RESULT_RESTART_LOCK := 0.0          # 阵亡结算：动画播完后再多锁几秒
const CLEAR_RESTART_LOCK := 1.0           # 通关结算：多锁 1 秒（打赢那一下手最忙，最易误触）
const RESULT_CUT_HELD_INPUT := true       # 战斗结束（阵亡/通关）即断开按住的操作：须松开重按才算
# ---- 章节转场（击败 BOSS → 延迟 → 黑场 → 下一章；下一章场景路径在各 Main 场景上） ----
const CHAPTER_CLEAR_DELAY := 1.7          # 击败→黑场的延迟（秒）：连串爆散先播完，胜利余韵一拍再切
# ---- 局内循环 v2（design/run_loop.md §1：固定 5 关 + RUSH 终局 + 通关结算） ----
# 整批新机制全带开关：总开关拨 false 即整套退回旧制（无限滚动关、每章转场满血），
# 分项开关再单独回退各自细则——快速 A/B 与回退都只动这里。
const RUN_LOOP_ENABLED := true        # 总开关：false=旧制无限滚动关（RUSH/通关结算一并消失）
const RUN_NORMAL_LEVELS := 4          # 普通关数：洗牌袋照抽；没抽到的场景留作 RUSH 阵容
const RUN_RUSH_COUNT := 3             # RUSH 连战 BOSS 台数（7 场景池=每局恰好看满 7 台；池更大=从没抽到的里随机挑）
const RUSH_NO_MOBS := true            # RUSH 无杂兵：小怪/精英全停（障碍照常=跑酷不断）
const RUSH_HP_DISCOUNT_ON := true     # RUSH BOSS 血量打折（未经精英预教=一阶段整段缺席；2026-11-11 用户定恢复）
const RUSH_HP_DISCOUNT := 0.7         # 打折系数 ×全量血
const RUSH_NO_HEAL := true            # RUSH 击破间不回血：血量跨场景携带（满血只给到进 RUSH 为止）
# ---- 疾驰倍率（design/run_loop.md §2：动态难度=负反馈，不是玩家成长） ----
# 五档，计分乘数查 MULT_VALUES 表（×1.0~×3.0，2026-11-09 用户定：原「档号即倍率」
# ×5 积分太胀；档位照旧 5 档，涨档账/密度乘区/BOSS 触发全不动）：按对敌输出（防御后实际伤害）涨进度+击杀收头，受击按伤害量扣（不按发数，
# =唯一掉档来源，无停手流失——2026-11-08 用户调向：BOSS 战靠输出爬升、停手不罚）；
# 进度跨关保持不清（只 start_run 新一局归零）；档位=刷怪密度档（SPAWN_ENEMY_GAP
# 乘区，打得越好怪越凶，受击掉档=自动退出高密度）+计分乘数（计分用涨前档，见
# Main._on_enemy_killed）。BOSS 触发照旧按基础分（Spawner._boss_score_accum 不乘）
# ——否则高倍率吞掉自己的收益。状态正本在 RunState（mult_* 段），数字全待调参。
# 反制（威胁擦身结算）随擦弹砍掉降级为结算展示，暂无事件源。失衡不独立涨：失衡期
# 受伤×1.5 加深会多打出伤害，输出渠道自动兑现打失衡的奖励。
const MULT_ENABLED := true       # 总开关：false=旧制（计分不乘、密度不动、结算不带受击/倍率行）
const MULT_MAX := 5              # 档位上限（=MULT_VALUES 表长）
const MULT_VALUES := [1.0, 1.5, 2.0, 2.5, 3.0] # 每档计分乘数（下标=档位-1；密度/涨档账不查此表）
const MULT_STEP := 20.0          # 每涨 1 档所需进度
const MULT_DAMAGE_FACTOR := 0.2  # 输出涨进度=防御后实际伤害×此系数（BOSS 400 实伤=80=+4 档，用户锚点）
const MULT_KILL_FACTOR := 0.6    # 击杀收头涨进度=基础击杀分×此系数（无人机5→3/步行10→6/盾卫25→15/BOSS 50→30）
const MULT_HIT_FACTOR := 10.0    # 受击扣进度=伤害量×此系数（严苛档：弹雨 10 伤=-100 清空，1 伤蹭弹=-10 半档）
const MULT_GAP_STEP := 0.86      # 密度乘区：每档 SPAWN_ENEMY_GAP ×此系数（第 5 档≈0.547=1.8 倍密度，2026-11-08 用户定放缓）
# ---- 难度阶梯（design/run_loop.md §3：关序只管 BOSS 出招密度+体量增长） ----
# 后摇 ×0.95^(n−1)（下限 0.9=封顶档实际生效，出招密度最高 +11%）、第 4 关起齐射
# 弹数 +1、BOSS 体量两根曲线（2026-11-08 用户修正废止「血量一律不加」红线；
# 2026-11-10 用户定拉高+拆开，2026-11-11 用户定 ×3.0 偏硬回落 ×2.2——装备期望
# 输出 ×1.12~×1.24（6 槽 15 成员按掉率 0.5 蒙特卡洛），血量曲线须跑赢它；
# 失衡不必涨那么多；杂兵/精英血量与失衡账仍一律不加）。
# 杂兵/精英密度归疾驰倍率，阶梯不碰刷怪流（两旋钮不拧一条流互相污染因果）。
# 凶度封顶第 4 关档：RUSH 连战（stage=5）与旧制无限滚动都封在 RUN_NORMAL_LEVELS
# 档（换算入口在 RunState.ladder_* 四方法）。
const LADDER_ENABLED := true          # 总开关：false=旧制（阶梯各项全不随关序缩放）
const LADDER_RECOVER_MULT := 0.95     # 后摇每关缩放系数（BOSS 出招密度渐紧）
const LADDER_RECOVER_MIN := 0.9       # 后摇缩放下限（封顶后出招节奏封死；0.857 的实际最低点被它接住）
const LADDER_EXTRA_BULLET_STAGE := 4  # 从这关起齐射类弹数 +1
# 体量两根曲线拆开：血量 ×1.30/关 封顶 ×2.2（1.30³=2.197≈2.2=第 4 关实际生效值，
# 逐关 1.30/1.69/2.20）；失衡阈值 ×1.2/关 封顶 ×1.7（1.2³=1.73→截 1.7）——失衡=玩家
# 爆发窗（枪攒失衡→近战爆发的循环），只温和上涨：血量通胀由失衡窗相对变多对冲，
# 后期 BOSS 不木桩化（封顶档失衡频率相对 +29%）；若与血量同涨=纯数值通胀=血包。
# RUSH 血量折扣恢复（RUSH_HP_DISCOUNT_ON=true）：封顶档 2.2×0.7≈1.54×原血。
const LADDER_GROWTH_MULT := 1.30      # BOSS 血量每关缩放系数
const LADDER_GROWTH_MAX := 2.2        # 血量封顶倍率（=第 4 关档实际值）
const LADDER_IMPACT_MULT := 1.2       # BOSS 失衡阈值每关缩放系数
const LADDER_IMPACT_MAX := 1.7        # 失衡阈值封顶倍率（=第 4 关档实际值）
# ---- 轻肉鸽装备（design/run_loop.md §4：BOSS 概率爆装备，槽位/成员正本在 balance_mods.gd） ----
# 掉落源=BOSS 击杀（普通 4+RUSH 3）×爆率=期望 ≈3.5 次/局；同槽位不爆（从未持有槽掷）；
# 装备芯片=槽位图标×成员色（颜色即预告）；斜抛+渐混吸附一条连续弧不落地=实际必捡
# （禁「躲弹漏捡」双随机叠加）；转场兜底=Main 对在途件自动授予。
# 状态正本在 RunState（mods_* 段），数字全待调参。
const LOOT_ENABLED := true            # 总开关：false=旧制（BOSS 不掉装备）
const LOOT_DROP_CHANCE := 0.5         # 每台 BOSS 的爆率（7.6 待定旋钮：RUSH 是否同率、精英 25% 备选）
# 斜抛+渐混吸附：击杀点弹出 → 朝玩家定速斜抛（缓弧看得清颜色预告）→ 后程渐混追踪。
# 飞行时长 T=BASE+距离/PER 截到 [MIN,MAX]：近距也留够起飞读感、远距不拖节奏。
const LOOT_FLIGHT_BASE := 0.55        # 斜抛时长基数（秒）
const LOOT_FLIGHT_PER := 1100.0       # 每 px 距离加的时长（700px→1.19s / 1400px→1.82s）
const LOOT_FLIGHT_MIN := 1.15         # 下限（秒）：颜色预告+起飞读感窗
const LOOT_FLIGHT_MAX := 1.85         # 上限（秒）：远距不拖节奏
const LOOT_SHOT_GRAVITY := 1300.0     # 斜抛重力（px/s²，玩家重力的 ~1/6）：缓弧看得出抛物线
const LOOT_SHOT_LIFT_MAX := 700.0     # 竖直初速上限（px/s，向上）：弧顶≈起点上 190px，不出画面顶
const LOOT_HOME_AT := 0.45            # 飞行进到这时长比例开始混入追踪
const LOOT_HOME_FULL := 0.9           # 到这时长比例纯追踪（直奔玩家）
const LOOT_HOME_MIN_SPEED := 650.0    # 追踪段速度下限（px/s）
const LOOT_HOME_MAX_SPEED := 1000.0   # 追踪段速度上限（px/s）
const LOOT_CLEAR_DELAY := 5.0         # 有掉落时击败→黑场延迟（秒，无掉落照旧 CHAPTER_CLEAR_DELAY）：
									  # 斜抛+吸附 1.15~1.85s 到手 + 播报行滑入 0.35s + 停 2.6s + 一拍余量
const LOOT_GRAB_RANGE := 46.0         # 抵达判定距离（px，到玩家碰撞中心近旁即授予）
const LOOT_ICON_SHADOW_ALPHA := 0.45  # 图标硬投影不透明度（拾取栏/飞入图标的同形黑影；0=关）
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
const ELITE_MIN_DISTANCE := 3000.0  # 玩家跑过这段距离后精英才进选怪池
#const BOSS_SCORE_TRIGGER := 250 
const BOSS_SCORE_TRIGGER := 200       # 击杀分攒满刷一场 BOSS；打完清零重计
const SPAWN_ENEMY_GAP_MIN := 1200.0
const SPAWN_ENEMY_GAP_MAX := 2400.0
const SPAWN_OBSTACLE_GAP_MIN := 1800.0
const SPAWN_OBSTACLE_GAP_MAX := 2600.0
const SPAWN_BACKTRACK_MAX := 600.0  # 往左跑的负位移记账上限：最多欠这么多，回头不用跑全程补给
const ENEMY_LEFT_BEHIND_MARGIN := 1200.0 # 被玩家往左甩脱的小怪：完全出右缘再留半屏即回收（须远大于出生点距右缘 ~360）
const OBSTACLE_DESPAWN_MARGIN := 1200.0 # 障碍完全出画面后再留半屏才回收（玩家回头走不見消失）
const PLATFORM_HOVER_MIN := 100.0  # 断桥顶面悬在地表上方的最小高度
const PLATFORM_HOVER_MAX := 200.0  # 断桥顶面悬在地表上方的最大高度
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
