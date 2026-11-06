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
const RUSH_HP_DISCOUNT_ON := true     # RUSH BOSS 血量打折（未经精英预教=一阶段整段缺席）
const RUSH_HP_DISCOUNT := 0.7         # 打折系数 ×全量血（数字待调参）
const RUSH_NO_HEAL := true            # RUSH 击破间不回血：血量跨场景携带（满血只给到进 RUSH 为止）
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
const BOSS_SCORE_TRIGGER := 50       # 击杀分攒满刷一场 BOSS；打完清零重计
const SPAWN_ENEMY_GAP_MIN := 1200.0
const SPAWN_ENEMY_GAP_MAX := 2400.0
const SPAWN_OBSTACLE_GAP_MIN := 1800.0
const SPAWN_OBSTACLE_GAP_MAX := 2600.0
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
