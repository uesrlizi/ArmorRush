# 场景生产规范（原「六章法」）

> 场景（world）换皮/新增的唯一定稿流程。做新场景前通读，做完回写本文档 + 会话记忆（两边同步，本文为准）。
> **术语：「章」= world_N 场景（章节链已死，2026-10-21 起洗牌袋轮换）；历史段落保留原称，读时替换。**

## 0. 场景池现状（洗牌袋轮换制，2026-10-21 起）

六关已为平行场景，无顺序链、无末章：`scenes/world/world_1.tscn`（一「锈雨废都」）、`world_2`（二「精炼所工业带」）、`world_3`（三「雪原警戒点」）、`world_4`（四「珊瑚辐合夜」）、`world_5`（五「破晓云廊」）、`world_6`（六「赤沙矿区」；**2026-10-22 暂时出池**——BOSS「赤轮」待返工，`RunState.SCENES` 内注释停用，正常入口抽不到，编辑器直跑仍可单关测试，返工验收后取消注释即恢复）。开机入口 = `entry.tscn`（run/main_scene，**纯跳板**：开局即抽关立即跳转，启动页由第一关自己的 TitleScreen 负责）。

- **轮换袋在 `RunState`**：`SCENES` 全场景池 + `FIRST_POOL` 开局白名单（"只包含"语义：不在白名单里的场景永远不会当首关）。入口"开始"调 `start_run()` 清分 + 整袋洗牌 + 只从白名单抽首关；此后每次通关 `draw_next()` 从袋抽下一关，袋空整袋重洗——每 N 关全场景恰好各一次、周期内不重复（袋边界首尾允许相接，Tetris 式）。**新章进池 = 往 `SCENES` 加一行**；不许当首关就不进 `FIRST_POOL`。
- 转场：BOSS 击败 → `Spawner.stop()` → 真实时间 1.7s（`Balance.CHAPTER_CLEAR_DELAY`，让爆散播完）→ `RunState.begin_handoff()` + 全局黑场 → `change_scene_to_file(RunState.draw_next())`。
- 新场景 `_ready`：`RunState.take_handoff()` 为真 → 跳启动页落地即战（满血=全新玩家实例）；为假（编辑器直跑）→ 照常启动页。编辑器直跑任一场景 = 单关测试：杀 BOSS 照样滚动进下一关，要锁章用 `RunState.hold_chapter`。
- 死亡重开 = 新一局：`start_run()` 清分 + 整袋重洗 + 白名单重掷首关，**哪里死不再哪里复活**（2026-10-21 定）；相邻两关永不相同——`draw_next()` 抽中上一关即换抽（袋内无重复，跨袋边界同样成立）。`RunState.score` 跨关累计，新一局清零。
- 延迟窗口内玩家暴毙 → 走死亡结算不切场景。

## 0b. 项目目录账（2026-10-21 分层定稿）

```
scenes/   entry.tscn（入口跳板=main_scene）
          world/    world_1..6.tscn（关卡）
          units/    enemy_N / enemy_drone_N / enemy_shield_N / elite_N / boss_N
          player/   player.tscn / thruster_flame.tscn
          weapons/  player_bullet / enemy_bullet / mortar_trail / slag_pool / plasma_bolt / dawn_bolt / coral_bolt / red_chip
          props/    obstacle / platform_crate / scaffold_1..6
          fx/       爆/闪/花/烟/尾迹/预警闪光
          ui/       touch_controls
          previews/ 开发预览场（rust/readability/fog_check/slash）
          archive/  留档孤儿（下一轮改版时删）
scripts/  core/     autoload 五件（balance/run_state/comms/sfx/scene_fade）+ ui_font/platforms/entry
          world/    main（关卡控制器）/spawner/terrain/scroll_object/world_strip/obstacle/aerial_fog
          units/    敌/精英/BOSS 能力脚本全家 + eye_glow/overhead_bar
          weapons/  bullet/heavy_missile/mortar_shell/plasma_missile/plasma_mine/ground_blast/slag_pool/coral_orb/coral_tide/flak_shell/arc_fence/ore_cart
          player/   player/thruster_flame
          fx/ ui/ dev/（autotest + 预览脚本）
assets/   world_1..6/（各章主题件）+ common/（跨章件）+ fonts/ branding/ sfx/ vo/
```

- **场景文件名 = `<单位>_N.tscn`**（N=world 序号，从 1 起）；单位叫什么（哨兵/钢嵴/白鲸…）写在 BOSS 血条与文档里，不进文件名。
- **共享脚本按职能进目录，不带序号**（boss.gd/elite_mortar.gd/main.gd 跨章共用）。
- assets 沿用主题前缀（env_<主题>_* / enemy_<主题>_* / boss_<主题>_*），分层靠 world_N 文件夹不靠改名。
- **ch 字样已废弃**（章节概念已死）：新文件/文件夹一律 world_N 或主题名。

## 1. 定章

- 从 `art_proposals/proposal_N_*.svg` 拿定稿提案；从 `generate_proposals.py` 的 `PROPOSALS` 表取精确色板与分层账（远 0.9 / 中 0.55 / 地 0）。
- 六套提案已实装（五=generate_proposals2.py 方案五，正本=`dawn_ch5/提案_v1_破晓云廊.md`；六=方案六，正本=`red_desert_ch6/提案_v1_赤沙矿区.md`）；七（溺海都会）已出提案待实装。再做新章 = 先出提案评审再进本流程。

## 2. 环境美术（半程序化）

- **资产按章节分层（2026-10-21）**：`assets/common/`（fx/玩家件/子弹/箱子）+ `assets/world_1..4/`（各章六件套+单位件+BOSS 件+章专属弹种贴图）；`fonts/ sfx/ vo/` 留 assets 根（独立域）。bake 脚本的 ASSETS 产物路径各指本章文件夹；**新章起文件名沿用主题前缀（env_<主题>_* 等），分层靠文件夹不靠改名**。
- 复制上章 `bake_chX_assets.py`（复用 `generate_proposals.py` 的 `Svg` 类），六件套画布与世界坐标账**不变**：

| 件 | 画布 | tile | 世界账 |
| --- | --- | --- | --- |
| far 远景条 | 1024x1300 | 1024（视差 0.9） | 画布底=世界 730 |
| mid 中景条 | **2048**x520 透明底 | 2048（视差 0.55） | 画布底=世界 700；多段各异构图防重复 |
| ground_top 表面带 | **640x66**（=A/B 两个 320 变体拼花） | 无平铺相位，terrain.gd 按块序号奇偶取半幅 | 纹内烘焙：顶缘亮线 0..2.5 / 走道带花 2.5..56 / 立面 AO 渐隐 56..66 / x=0,320,640 块间竖缝 |
| ground_fill | 16x256 | — | 立面渐变 face_hi→face_lo（0.42 处到位）+ 烘焙 4 条层理横线；sprite 拉伸 320x634 接在带底 |
| ground 兜底条 | 256x480 | — | = ground_top 内容 + 深处渐变 |
| deck 桥面 | 720x26 | — | 桥墩色走 `scaffold_chX` 的 `pier_color`（章配） |

- ThorVG 硬约束：禁 filter/pattern/use/text/transform；rect+rotate 会崩（烘等价 polygon）；平铺接缝两侧留空（far 24px / mid 40px）。
- **地块 v2 分层（2026-10-21 实装）**：走道带花低密度、A/B 两半按块序号奇偶交替（消灭平铺重复感）；立面=AO 渐隐（带正下投影，立体感主来源）+ 层理（fill 纹内烘焙，渐疏渐淡）+ 块间缝上密下疏（terrain.gd 顶点色）+ 露头细节横杆（`Terrain.seam_color/detail_color` @export 按章配，ch1 用脚本默认）；掉档墙面全露当剖面秀场，**不画顶缘包角**（用户定案）。设计语言正本=`art_proposals/terrain_blocks/ground_v2.py`（提案预览与实机同源）；四章纹理烘焙=`terrain_blocks/bake_ground_v2.py`（覆盖 assets/world_N 原名，tscn 引用不动）。**漏光坑（用户抓）**：band 纹里 AO 渐隐带（y56..66）是半透明，而 fill 精灵从 66 才起——AO 背后是空的直接透天空，高档位背后亮天空最明显；修=bake 时 AO 下垫不透明 face_hi 底，交付前像素断言四张 band min_alpha=255。提案层另有**桥面变体 `draw_ground_deck`**（云上高架/跨海栈桥：走道带+薄箱梁+排架柱渐隐入云海/海面），world 主题若要"桥"读法照此出提案——**五章已实装桥式读法（=拆地块桥面变体上机，地块读法=桥不是山体）**：terrain.gd 的 fill 缩放按**贴图实际尺寸**算（默认 16x256 行为不变），桥式模式为 opt-in 导出（`bridge_girder/brace/column_textures/column_xs/sea_y`）：每块画 箱梁（整幅宽，块间接缝烘贴图两端）+剪刀撑+排架柱 ×2，不再画 fill 立面/露头横杆/缝。排架柱=**实色细柱**（宽 20，无渐隐——半透明柱让海透过来=前后读反），按挡位选贴图：需要长度=sea_y−柱顶，取高度最接近且不短于的那张（三挡 110/170/230），柱底统一钉在 `bridge_sea_y`=860 的**固定海面线**上=海平面固定、柱随地形换挡，柱身按 (块序+柱序) 奇偶镜像微错。**云海=场景独立层**（不归地块管）：底层 GroundStrip（env_dawn_ground 3200×480，薰衣草底+椭圆云垫阵列+浅云带，低对比大笔触）+前景云沿 SeaFront（env_dawn_sea_front 3200×150，画在 Terrain 之后遮柱脚=「没入海面」的层级实体化）——两层都是 world 锚定（scroll=0）**与地面同速滚动**，柱上不烘云团（会动的柱驮云团在滚动海上=错层）；桥件贴图原生分辨率（拉伸小图糊不出柱子）。独层地标=天梯缆塔 3200×900，条带位 (8,270) **居中挂载**：画布 y0=世界 −180，塔基画布 840=世界 660 沉云海——新独层地标先按挂载点反推画布 y 再动笔。
- **条带里不画"唯一地标"**（太阳、巨环等）：小 tile 同屏重复 2~3 份穿帮。大件地标走独层宽 tile，见 §5。
- 种子固定（每条带一个），重跑结果一致。每章种子记进 §7 索引。

## 3. 单位美术（重设计但锚点钉死）

**铁律：美术重画、骨架锚点不动**——锚点逐像素对齐后，tscn 节点位不用重调：

| 单位 | 画布 | 锚点 |
| --- | --- | --- |
| 步行者 | 56x52，地面 y=50 | 眼 (15.5,18.3) halo r5.3/core r2.4；肩 joint (16,24)；前缘 x<6 留空给枪臂 |
| 无人机 | 38x42（悬浮） | 眼 (12,14.4) halo r4.4/core r2.0；ArmPivot 画布 (15.2,21) |
| 盾卫 | 56x52 | 眼 (23.5,18.3)；肩 joint (24,24)（复用本章枪臂） |
| 精英 | 60x80，地面 y=80 | 眼 (19,26.5)；两仓口 (38.5,1.5)/(49.5,1.5)=pivot(44,1.5)±5.5，与 ELITE_VOLLEY_COUNT 1:1。**本行=垂发车基线（ch1/2/3）；能力精英挂点可偏离（ch4 海葵发射器 ArmPivot (44,8)/Muzzle (44,6)，仓口作废），以各章 §8 行与烘焙头注为准** |
| BOSS | 300x180，原点 (150,90) | 眼条带 y60..66 含 (55,63)（EyeGlow 节点 (-95,-27)）；导弹仓口画布 x 83/105/167/189 @ y26（与 BOSS_RAIN_COUNT 1:1）；枪口=臂画布 (2,~4)→Muzzle(-93,8)，臂 flip_v、offset(-95,-20)、pivot(-51,15)。**本行=换皮基线（直升机族 ch1/ch4）；能力 BOSS 画布/锚点可整本偏离（ch3 哨兵 260×180），以各章 §8 行与提案锚点账为准** |

- 机甲四阶色（LIGHT/BODY/BELLY/GAP）+ 红/黄信号色，随章调色相；阵营语言的底层是"独眼红=敌"，明度随背景章反转（见 §6）。
- BOSS 允许挪 Rotor/TailRotor 两个动画节点，新局部坐标写进 bake 注释和 tscn（章四：Rotor (122,-26)→画布 (272,64) 涵道内、TailRotor (122,22)→(272,112)）。
- 能力挂件（真实炮位/弹舱/机库等）按本章能力脚本增补（见 §4b）：数量与位置是**玩法参数**，美术组装照锚点摆；新锚点写进本章 SVG 头注释并回填 §8 本章行（ch2 驳船墙炮门画布 (27,70)/(19.5,100)/(35,123) 即此例）。

## 4. 视觉接线（杂兵与环境=纯换皮）

- 杂兵三件套+脚手架：每单位一张编号变体 `scenes/units/<单位>_N.tscn`（N=world 序号），**复用同一脚本，只换贴图**（浮空 BOSS 另改 Rotor/TailRotor 节点位——仅限仍用 `boss.gd` 的章）。
- `world_X.tscn` 复制场景，换：Spawner 的场景引用、三条 WorldStrip 贴图、Terrain band/fill（@export）、AerialFog color（@export）、Main sky_color（=天顶色）、HUD 字色（按背景亮暗，见 §6）。
- `RunState.SCENES` 加一行新章路径（不许当首关就不进 `FIRST_POOL`）；无 next_scene 接线、无末章概念。
- 探针 `tests/transition_probe.gd`：不变式断言（白名单首抽/整轮不重复/永远滚动/跨关分数/交接满血），`SCENES` 加场景自动覆盖无需改探针；看门狗 90s。

## 4b. 能力接线（精英/BOSS=能力单位）

**新场景默认带本章能力设计**：场景本体与本章精英+BOSS 的能力同批生产，不是纯视觉换皮——纯换皮只属于杂兵与环境（§4）。能力=新弹种、新行为、或既有件的重新组合，生态位不要求无重叠（见下「设计自由度」）。能力主题在 §1 定章时一并定；动手前过本节门检，配 §7 步骤 0 的几何账。

**机制（同框架换能力脚本）**：精英/BOSS 各一套新 `.gd`（scripts/units/）+ 编号场景 `scenes/units/elite_N.tscn`/`boss_N.tscn`；视觉仍按 §3 骨架换皮，挂件按能力增补；框架优先复用公共库（见下），ch1 直升机 `boss.gd` **不迁移**（已调稳，不为 DRY 冒回归险）。

- 被替位的旧 tscn **留档一章**（`scenes/archive/`），下一章改版时删上上章孤儿（现无孤儿；boss_ch3 场景名已被哨兵顶替复用，无留档）。
- `Spawner.debug_spawn_boss/_elite` 返回 Node2D/Enemy；autotest BOSS/精英段按机型分叉，**子类判据必须排在父类之前**（哨兵/鮟鱇/断云都是 PursuitBoss，先匹配 PursuitBoss 会接错分支），弹种判定按章写（`PlasmaMissile` 是 `HeavyMissile` 子类，`is HeavyMissile` 自然命中）。

**每章能力设计门检（动手前逐条过，配 §7 步骤 0 的几何账）**：

1. **教学位**：本章精英预教 BOSS 哪一手？一章只预教一手（挑最难读的）；可读性高的招 BOSS 现场教（ch1 导弹车预教弹雨、ch2 臼炮车预教封路）。
2. **悬浮账**：BOSS 全悬浮——64px 台阶地形下地面巨物必卡死/穿模；精英可地面车（玩家路过它，不需保持构图位）。高度由弹道需求推导，浮空脚手架无碰撞（仅可踩）不构成约束；对最高台阶（536）净空 ≥70px（bob/瘫沉后 ≥50）。
3. **真实枪口律**：任何弹幕=N 真实炮位×瞄准方向×开火时机，无虚空出弹点。打站立带必须下俯，且逐发沿射线采样 `surface_y_at` 校平（抬角至多 2 次，仍埋该炮本轮哑火）。水平弹流永远打不到站立玩家（地形合法水平带 y<536 与站立带 470-664 不相交）——那是"惩罚滞空"武器的几何根源（ch1 扫射同账）。
4. **相对速度**：要"惩罚匀速直线跑"就用 lead 落点（`MortarShell.compute_lead_target`，时长已知一次算完）；追踪弹默认是 ch1 专属语言，别章不用——**例外：纯视觉换皮追踪弹可跨章**（ch3 哨兵电浆弹雨=PlasmaMissile，HeavyMissile 语法零改动只换外观）。
5. **数值命名**：Balance 新段按机体命名（`BARGE_*`/`ELITE_SLAG_*`），禁用章号。
6. **读法/量级**：新危险件/特效动手前先答"玩家第一眼看成什么"——贴图尺寸/特效量级对标同类现役（尾迹烟=fx_smoke 档）。同坑两案（ch2 尾迹"纯火星"太小看不见、ch3 浮雷 44px+逐孔梯次被误读"导弹卡天上"）：**第一眼读法是验收项，不是加分项**；拿不准先出光栅/实机帧自检，再进战斗调试。

**设计自由度**：

- **BOSS 能力生态位不要求无重叠**——玩家操作就那么几个，**新组合/新视觉也算新设计**；别为"补生态位"硬造新弹种（ch5 的"罚停留"定位成立，但那是这一章的选题，不是通用门槛）。
- **不必每个 BOSS 都装可动机枪做普攻直射**——真瞄臂短点放是现役惯例，不是门检要求；普攻段可以换形式（固定射角弹幕、机体动作、环境联动都行）。
- **章节专属弹种可按本章背景调色**（它是这个世界专属的，只保本章可读性，非强制）：ch5 啸雷弹=白热金主带+暗紫壳双色（上暗紫天区靠白热带读、金霞地平带靠暗壳剪影读）。**高速弹的读法=拉长度**：弹速 2400 下短弹几乎不可见，拉到 112 全长曳光矢=每秒掠过自长 21 次、高速拖成一条轨迹线——快弹别在配色上死磕，先拉长度。

**公共弹药/危险件库（新行为=新弹种，禁改既有弹种的制导语法）**：

| 件 | 语法 | 已用 |
| --- | --- | --- |
| `Bullet` | 直线（方向恒定，可带载体速度 inherit） | 全章机枪/弹幕/直瞄 |
| `HeavyMissile` | 玩家追踪（抛体滑行→比例导引） | ch1 导弹车/弹雨 |
| `PlasmaMissile` | =HeavyMissile 纯视觉换皮（`extends HeavyMissile`，语法零改动：SVG 矢弹+电光尾迹+冰蓝爆） | ch3 哨兵电浆弹雨 |
| `MortarShell` | 真弹道（落点+时长解算初速，MORTAR_GRAVITY≈4×玩家；弹体/尾迹独立资产） | ch2 熔渣封路 |
| `PlasmaMine` | 空中封锁件：真弹道高抛入位→悬停蓄能（渐亮二段预警）→近炸引信；寿命到点哑熄（无伤）——「站=吃/冲过=免/跳=吃」；投放=**一次性齐撒**（同帧全出，与臼炮逐孔梯次分家） | ch3 精英布雷车/哨兵浮雷封锁 |
| `CoralOrb` | 珊瑚重弹：**慢速可见能量重球**（弹速 CORAL_ORB_SPEED 慢于机枪流=弹体自读，侧移即躲），出膛瞬间 lead 瞄准（玩家速度×飞行时长，时距从决策点起算，clamp 承诺带），撞地即爆蕗（GroundBlast+coral_burst 粒群，无残留；爆区 180/160=慢+大压制面）——急停/变向=免，匀速跑被压在路径上 | ch4 精英海葵/鮟鱇 |
| `CoralTide` | 固定高度涌浪墙：**不管地面**，浪墙钉绝对高度带 [520,640] 纵跨盖满三档站立带，只沿 x 涌动；灼烧一次即溃散，射程到点哑熄——**飞越=反制**（纯跳仅最高档擦得过，低档须推进升空；浮空脚手架高台=掩体） | ch4 鮟鱇 |
| `CoralBolt`（coral_bolt.tscn） | 直射弹=bullet.gd 纯换皮（语法零改动） | ch4 鮟鱇钓灯直射 |
| `FlakShell` | **定距空爆**的防空弹：直线无重力+出膛瞬间按「炮口→玩家当时位置」距离解算引信（爆点=发射时玩家所在点，**无 lead**），到点 GroundBlast 空中爆（flash_color 白热金）；撞地形=早爆（掩体合法不校平）——**停=吃/动=免**，与 CoralOrb 的 lead 惩罚互为镜像（罚停留不罚跑）；读法=炮口预警+弹上引信芯越闪越急（fx_dawn_flak.svg 曳光矢） | ch5 精英响哨/断云 |
| `DawnBolt`（dawn_bolt.tscn） | 直射弹=bullet.gd 纯换皮（语法零改动，紫白曳光矢） | ch5 断云机鼻直射 |
| `ArcFence` | **落点围栏**：双锚桩解算弹道（MORTAR_GRAVITY）落到玩家**当时位置**两侧（无 lead）→桩上火花蓄能（渐亮二段预警）→竖直电幕立起（各自桩位各自贴当地地表的竖直线段）；触幕一次整套溃散，寿命到点哑熄（无伤）——**停=被围（出笼交税/飞越/等）/跑=提前出带免**；与 ch5 啸雷「停=吃」互补（那边罚不跑，这边罚跑晚了）；纯跳过不了幕（幕高 150/200 > 跳 apex 底 103），推进 ≥204 飞越=免 | ch6 精英锚桩/赤轮 |
| `OreCart` | **贴地滚行**危险件：腹舱出舱坠落→恒速滚向玩家（台阶=y 快速归位）；命中一次结算、车继续滚；寿命到点/滚出射程脱轨哑熄（无伤）——**纯跳可过**（车 84 高 < 跳 apex 底 103）、站桩=吃 | ch6 赤轮 |
| `RedChip`（red_chip.tscn） | 直射弹=bullet.gd 纯换皮（语法零改动，红砂弹石；亮沙底靠暗壳剪影读） | ch6 赤轮斗轮弹石 |
| `coral_embers`/`coral_burst` | 珊瑚粒群粒子件（余烬尾迹/爆蕗绽放，fx_flame 交红 ramp）——**科若尔 FX 语汇=柔光+粒群+平滑波浪，禁锯齿/高频白芯（闪电感）** | ch4 全系 |
| `GroundBlast` | 单次球状爆区（`flash_color` 可染，默认橙红；`show_flash` 可关） | 爆类落地/空中 |
| `SlagPool` | 驻留 tick 区（蓄热二段预警） | ch2 火区 |

- 代码惯例：`.new()` 出生的类**必须纯代码自建视觉**——不带场景子节点，`$节点` 必炸（GroundBlast/SlagPool/MortarShell 惯例）。
- 音效占位：新武器先用 `fire_enemy`/`boom_enemy`，专属配方后配。
- 反例存档："导弹加定点"（给追踪导弹伪装弹道武器）已被否——弹种语法混用一眼假。

**章例（ch2，照抄结构、不抄数值）**：精英=熔渣臼炮车（预教封路：lead 落点+驻留火区，落地无溅射=教学纯净版）；BOSS=悬浮冶炼驳船「钢嵴」（熔渣封路 4 垂发孔+火区 ⇄ 排炮弹幕墙 3 真实炮门±摆动扇+地形校平/哑火 + 直瞄普攻；hover 370、船底=t2 站立头顶上方 10px）。教训：尾迹类特效量级先对标同类现役再动手（烟=fx_smoke 档；首版"纯小火星"太小看不见被打回）。数值全在 Balance `BARGE_*/ELITE_SLAG_*/SLAG_POOL_*/MORTAR_*`。

**章例（ch3）**：精英=电浆布雷车（预教浮雷：承诺带落点+悬停近炸，双仓同帧齐布）；BOSS=强袭悬空机甲「哨兵」（BossSentinel，260×180 机体：高度同 ch1 直升机档、宽度放开、碰撞 246×168——**从零设计非补美术**，场景 `scenes/units/boss_3.tscn`，资产沿用 `boss_snow_body/gun.svg` 名）：电浆弹雨（**右肩双仓口 (151/167,26)**，4 发回绕复用，PlasmaMissile 换皮弹）⇄ 浮雷封锁（腰布雷闸 BayPort (122,138)→(-8,48)，**一次性齐撒** 4 枚同帧出舱）+ 电浆枪直瞄普攻（plasma_bolt.tscn=bullet.gd 纯换皮冰蓝矢弹，速度/伤害复用 BOSS_SWEEP_*）；hover 370 同驳船账。几何账/惩罚账正本=`art_proposals/snowfield_ch3/提案_v2_能力化.md`+`提案_v3_哨兵重设计.md`；数值全在 Balance `SENTINEL_*/ELITE_MINE_*/PLASMA_MINE_*`。**教训：新危险件的"第一眼读法"是验收项**——浮雷首版 44px+逐孔梯次被误读"导弹卡天上"，放大到 64 电极柱水雷剪影+同帧齐撒才立住。

**章例（ch4；科若尔=红色化的电浆/能量武器[AC6 珊瑚=红色智能能量粒群，武库=步枪波浪束/振荡器/导弹]；正本=coral_ch4/提案_v2_珊瑚重设计.md，v1 闪电版留档 `提案_能力化.md`）**：精英=炮台车「海葵」（EliteAnemone，预教重弹：背驮海葵发射器[发射器=美术本体，Muzzle=海葵口]，三发梯次 CoralOrb）；BOSS=深海猎杀舰「鮟鱇」（BossAngler，**美术按能力重烘焙**=背驮大口径珊瑚重炮+艏部钓灯臂+腹下吊挂放电舱，独眼条带/Rotor 位沿用）：珊瑚重炮（炮位预警→逐发梯次 CoralOrb 慢弹 4 发/p2+1，出膛瞬间 lead 解算——弹体自读，惩罚"看到预警仍匀速跑"；爆区 180）⇄ 珊瑚潮（腹闸出舱爆蕗小瓣→CoralTide 固定高度涌浪墙；默认双波/p2 三波）+ 钓灯能量束直射（coral_bolt.tscn=bullet.gd 纯换皮波浪红束）。hover 370 同驳船账；锚点账=bake_coral_units.py 头注（精英 ArmPivot 画布 (44,8)/Muzzle (44,6)；BOSS Cannon/Muzzle (150,28)、ArmPivot (86,42)、BayPort (150,174)）；数值全在 Balance `ELITE_ANEMONE_*/ANGLER_*/CORAL_ORB_SPEED/CORAL_TIDE_*`。**教训四条**：①主题词先研究原作语汇再动手（闪电≠科若尔）；②FX 走规约正途（贴图+粒子，检查器可调），_draw 特效件全数删除；③量与压制的"手感弱"是验收项（爆区翻倍/潮墙化治瞬移/弹数下限上调都来自实机调参）；④爆区视觉要跟爆径耦合（GroundBlast 预置 scale 曾被 FlashBurst 补间 .from 覆盖=闪光从不随爆径变——修=FlashBurst.size_scale 并进补间两端+coral_burst.power 爆径耦合；潮墙=coral_tide_fx 粒子浪墙，静态贴图版"像死墙"被否）。

**章例（ch5；几何账正本=dawn_ch5/提案_v1_破晓云廊.md §2）**：精英=防空炮车「响哨」（EliteSiren，预教啸雷：双管高炮臂**俯仰真瞄**，双连定距空爆弹）；BOSS=高空截击机「断云」（BossInterceptor，300×180 镖形机体、无旋翼=双尾焰脉动[通用 fx_flame+加色]，独眼条带沿用）：啸雷齐射（背炮塔 Cannon (150,34) 俯仰跟随真瞄→逐发梯次 FlakShell 定距空爆 3 发/p2+1——**停=吃/动=免**，与 ch4 重弹 lead 惩罚互为镜像）⇄ **俯冲突袭**（首次机体冲撞：机鼻 Nose (14,84) 预警+尾焰增亮 0.6s→锁定出手点[玩家当时 x、当地地表−120]→2100px/s 直线通场→过冲 500px 拉起；通场带盖站立带：站立=被撞、**纯跳 apex 也被撞**、推进 ≥204px 或横移出锁定线=免；每帧 clamp 中心 y ≤ 当地地表−120 滑过台阶上缘）+ 机鼻曳光直射（dawn_bolt.tscn=bullet.gd 纯换皮）。分工账：啸雷 hunts 空中与驻停、俯冲 hunts 地面通道——玩家被迫两头换层。hover 370 同驳船档；碰撞 280×150（body_size 300×180，冲撞判定用 body_size+玩家半宽限）；锚点账=bake_dawn_units.py 头注（精英 ArmPivot 画布 (44,12)→局部 (14,-28)、臂枢端 (28,13)/Muzzle 臂局部 (-22,-3)；BOSS ArmPivot (60,74)/Cannon (150,34)、Nose (14,84)、尾焰画布 (286,86)/(286,106)）；数值全在 Balance `ELITE_SIREN_*/INTERCEPTOR_*/FLAK_SHELL_SPEED`。**探针教训三条**：①BOSS 段同样要单威胁源——戳技能前清杂兵+等威胁弹排空，否则上一手的余弹抢跑断言（掉血值≠招式伤害时先怀疑污染）；②**BOSS 也在 "enemies" 组**（Enemy.on_spawned 加的），清场循环必须跳过 "boss" 组成员，否则误杀本体；③状态机兜底看门狗进入状态时必须重置 _bt——预警把 _bt 减到 ≤0 再切状态，不重置=首帧判超时、招式自灭（探针逐拍打 bstate 时间线一跑定案）。**美术教训两笔**：①BOSS 双垂尾根部要埋进机体轮廓（悬在外=断件读法；先画后压的层序只有埋进去才成立）；②快弹读法=拉长度非调色（见「设计自由度」）。

**章例（ch6；几何账正本=red_desert_ch6/提案_v1_赤沙矿区.md §2）**：精英=打桩车「锚桩」（ElitePiler，预教电网闸：双桩炮架**固定射角**[垂发账，臂不俯仰]，单笼投放）；BOSS=斗轮采集舰「赤轮」（BossRedwheel，300×180 低矮宽驳、**斗轮=独立旋转件**[恒转+直射加速=signature 动画]、背甲双桩炮架+腹舱+船底双举升风扇[通用 fx_flame+加色]，独眼条带沿用）：电网闸（背甲炮架 Rack (210,38) 预警→双锚桩落到玩家**当时位置**两侧（无 lead，半 lead=按玩家速度 clamp LEAD_MAX 400 前后移）→蓄能火花渐亮→竖直电幕 [half 200/top 200/p2 蓄能 0.7→0.55]）⇄ 溜矿车（腹闸 BayPort (150,170) 预警→倾泻 OreCart 1/p2 2 辆间隔 0.55——纯跳可过、双车节拍减半）+ 斗轮弹石直射（red_chip.tscn=bullet.gd 纯换皮，轮毂心真瞄）。分工账：电网闸 hunts 滞留者（笼+税）、矿车 hunts 地面驻留节奏（跳的拍子）——玩家在跑/跳/飞三态间换挡（全走地面轴，与 ch5 换层账同构）。hover 370 同驳船档、斗轮缘 454=最低点（对 t536 台阶净空 76 同账）；碰撞 280×150；锚点账=bake_red_units.py 头注（精英 ArmPivot 画布 (44,12)→局部 (14,-28)、臂枢端 (17,40)/Muzzle 臂局部 (0,-34)；BOSS ArmPivot (-106,30)/Wheel 轮毂、Rack (60,-52)、BayPort (0,80)、风扇 (-30,64)/(80,64)）；数值全在 Balance `ELITE_PILER_*/REDWHEEL_*/ORE_CART_*`。**探针教训一笔**：电网闸伤害=矿车伤害（同 10）时，掉血值无法区分威胁源——单威胁源的"排空闸"必须把**驻留危险件（ArcFence/OreCart）连同预警态一起算进 quiet 判据**（BOSS 回 ST_ENTER/RECOVER 稳态才准戳），光等弹容器干净不够。**独层地标排布教训**：太阳+巨机两个地标挤不进 tile 3200 的防回绕安全带 [1200+半宽, 3200−1200−半宽]——一章一个独层大件，白热天光交给天顶渐变+尘带承担。

## 5. WorldStrip 接线账（踩过的坑全在这）

- 相位公式 `phase = fposmod((scroll_scale-1)*镜头x, tile_width)`，节点每帧钉在 `镜头x + phase`——**编辑器里挪节点 x 救不了任何平铺问题**。
- **region 覆盖账**：条带精灵是**居中挂载**（中心=镜头中心+phase，phase∈[0,tile)），不透明艺术条全覆盖要求 **region ≥ 2×tile + 视口 2400**（透明艺术条漏的部分透出后面的层=看不见，「视口+tile」的说法只在那种情况够用；tile=3200 配 region 6400 时左缘最多漏 1200px）；现役账：tile≤2000 用 6400（far/mid），tile=3200 用 **9600**（云海/云沿；8800 只有 1px 边际不取）；region=tile 时条带大部分相位整段停在屏外=隐形；**region 高 = 贴图高**（纵向会重复）。
- 唯一大件地标：**独层 + tile_width > 2400 → 同屏最多一份**（章四环层 tile 3200，屏上约 39s/空档 14s）。层序必须在不透明远条**之后**、MidStrip 之前（远条整幅天色会盖掉它前面的层）。
- 独层地标在贴图内的落位（**防回绕弹切**，章四环层二轮教训）：地标渲染位 `rel = phase − 3200 + tex_x`，phase 回绕（tile→0）时全部拷贝 +tile，落在 region 左边界外的那份**瞬间消失**——所以地标必须在回绕时刻全出屏：`tex_x ∈ [1200+地标半宽, tile−1200−地标半宽]`（环：半宽≈270 → tex_x=1600，两侧余量 130px）。落带内则进出场永远从屏幕边缘滑入滑出；节奏 ≈ 屏上 (tile−2400−2×半宽)/0.1 镜头px、空档 (2400+2×半宽)/0.1。

## 6. 背景 × 可读性定案（别再实验了）

- **亮背景章**（雪原）：黄弹/焰芯会隐形 → 可读性全部由压暗天光承担，共享弹/焰资产**原样不动**；焰内芯压暖琥珀。发射物的"自发光描边/光晕"思路已被否。
- **暗背景章**（珊瑚夜）："近黑=敌"反转 → 敌营用**比天亮一档**的亮钢蓝（章四：#9fb0d8/#5d6d94/#3f4c6e/#262f4a + 珊瑚灯 #ff7a45），独眼红 #ff4640 不变；HUD 分数/结算字色转浅 #dfe6ff（亮背景章是深字 0.13/0.17/0.21），GameOver 标题用亮红。
- 天清屏色 = 本章天顶色；AerialFog color = 本章雾色（雾只洗 far+mid，前景自然剪出）。

## 7. 校验流水线 + 过程守则

0. **能力几何账（设计期，美术/接线之前）**：新场景默认带本章能力设计（§4b）；本章精英/BOSS 的每招**先解账再写方案**——炮位/射角/弹道带/悬浮净空，按相机 frame 1:1 出数字表+示意图（视口 2400×1080、玩家屏幕 x=400、BOSS 锚点屏幕 x=1800）。解账是设计本身：账无解的案当场换掉，不存在"先做出来再试"；数字表/示意图收 `art_proposals/` 留档。（2026-10-21 增：ch2 低空掠地/平射弹墙两案都死于解账——账不前置=拍脑袋空想+白写代码。）
1. `tasklist` 确认编辑器离线（autotest 自带在线守卫会拒跑）→
2. `--headless --import` →
3. 相邻两章 `--quit-after` 冒烟 →
4. 无头 `transition_probe.tscn`（全链）→
5. 带窗 autotest：**本章自己的探针必跑（机型分叉后各章能力不同，见 §4b）+ 任一未改章跑回归**（`-- --autotest`，`--` 必须带）→
6. 光栅自验 + 游戏内截图 + `build_showcase.py` 对照表（暗底章环境条带要垫亮背板才读得出）→
7. 回写本文档 + 会话记忆。

守则：

- **接线类改动（层级/region/相位/节点）必须引擎内过目才算"修好"**——光栅自验只保"SVG 内容对"，保不了"接线对"。编辑器在线等不了验证时，交付话术是"已改待验"。
- 编辑器在线时改场景文件：**先重读磁盘**（编辑器可能已另存，节点带 unique_id、顺序可能变），并提醒用户"先重新加载场景再保存"防旧缓冲盖写。
- 运行时报 "Invalid access … on balance.gd" 先 grep 磁盘（旧缓冲回滚前科），别怀疑代码。
- 探针自己不能是 current_scene（先放占位节点顶包再 change_scene）；`--script` 模式不注册 autoload。
- 已知非回归：autotest 的 muzzle pin 探针偶发 FAIL = 截图滞后，复跑即过。
- **改名/迁移/分层类改动**：改完先跑 `python tools/check_asset_refs.py`（纯 Python，编辑器在线也可跑）全量核对 res:// 引用落盘（输出型路径 autotest_shots 放行），再进引擎流水线——§0b 目录账每动一次就过一遍。
- 每轮改完 grep 验磁盘真实内容。

## 8. 各章索引

| 章 | 场景 | 烘焙脚本 | 种子 | 敌营色板 | BOSS | HUD 字 |
| --- | --- | --- | --- | --- | --- | --- |
| 一 锈雨废都 | world/world_1 | art_proposals/bake_rust_assets.py | — | 暖褐近黑 | 重型武直「dreadnought」 | 深 |
| 二 精炼所工业带 | world/world_2 | refinery_ch2/bake_ref_assets.py | — | 冷绿 #4d5348 族 | 熔渣驳船「钢嵴」（BossBarge：封路+弹幕墙；船艏炮门画布 (27,70)/(19.5,100)/(35,123)） | 深 |
| 三 雪原警戒点 | world/world_3 | snowfield_ch3/bake_snow_assets.py | 3031/3032/3033 | 冷蓝灰 #5d6c76 族 | 强袭悬空机甲「哨兵」v3（`boss_ch3.tscn`+BossSentinel：电浆弹雨+浮雷齐撒+电浆枪直射；布雷闸画布 (122,138)；**弹雨仓口=右肩双孔 (151/167,26)，4 发回绕复用**（v3b 砍前肩）；无旋翼=推进焰脉动；v3 提案=同目录 提案_v3_哨兵重设计.md） | 深 |
| 四 珊瑚辐合夜 | world/world_4 | coral_ch4/bake_coral_assets.py + bake_coral_units.py（v2 单位/特效覆写） | 4041-4044 | 亮钢蓝 #5d6d94 族（反转） | 深海猎杀舰「鮟鱇」（BossAngler：珊瑚重炮+珊瑚潮+钓灯直射；Cannon/Muzzle (150,28)、ArmPivot (86,42)、BayPort (150,174)；精英=炮台车「海葵」预教重弹[ArmPivot (44,8)]；正本=coral_ch4/提案_v2_珊瑚重设计.md） | 浅 #dfe6ff |
| 五 破晓云廊 | world/world_5 | dawn_ch5/bake_dawn_assets.py + bake_dawn_units.py | 5051-5054（地块花=band 内 3111/3222） | 暗紫罗兰 #4e3c64 族（金霞补色域，不反转） | 高空截击机「断云」（BossInterceptor：啸雷齐射+俯冲突袭+机鼻曳光；Cannon (150,34)、ArmPivot (60,74)、Nose (14,84)、尾焰 (286,86)/(286,106)；精英=防空炮车「响哨」预教啸雷[ArmPivot (44,12)]；独层地标=天梯缆 env_dawn_ladder；正本=dawn_ch5/提案_v1_破晓云廊.md） | 浅 #dfe6ff |
| 六 赤沙矿区 | world/world_6 | red_desert_ch6/bake_red_assets.py + bake_red_units.py | 6061-6064/6071-6080（地块花=band 内 3111/3222） | 赤红暗棕 #6e3424 族（亮背景章，不反转） | 斗轮采集舰「赤轮」（BossRedwheel：电网闸+溜矿车+斗轮弹石；Wheel 轮毂画布 (44,120)=独立旋转件、Rack (210,38)、BayPort (150,170)、风扇 (120,154)/(230,154)；精英=打桩车「锚桩」预教电网闸[ArmPivot (44,12)，臂不俯仰]；独层地标=斗轮巨机 env_red_wheel；正本=red_desert_ch6/提案_v1_赤沙矿区.md） | 深 |

通用命名：`env_<主题>_far/mid/ground/ground_top/ground_fill/deck` + `enemy_<主题>_*` + `boss_<主题>_*`；独层地标另起名（如 `env_coral_ring`）。
