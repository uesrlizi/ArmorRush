# Armor Rush（装甲疾驰）

> 非官方同人项目：a fan game inspired by *ARMORED CORE VI* — not affiliated with or endorsed by FromSoftware / Bandai Namco. 开源、非营利。

Godot 4.7 制作的 AC（Armored Core）风味 2D 机甲跑酷。一台没登记的残机在封锁区里向纵深突围，能走多远走多远。

## 操作

| 动作 | 键 | 手柄 |
| --- | --- | --- |
| 移动 | A / D | 左摇杆 |
| 跳跃 / 空中按住=AC6 式推进上升 | 空格 / W | A 键 |
| 开火 | K / 右键 | RT |
| 近战二段斩 | J / X | Y 键 |
| 死亡后重开 | 任意键 / 点屏 | 任意键 / 点屏 |

近战段序固定：一段下劈，后摇内再按才接二段上挑；近战绕过盾卫的防御减免。推进槽空中快回、落地即回。左下角操作提示按输入设备自动切换（接着手柄显示手柄版，移动端不显示）。

## 威胁分层（杂兵 / 精英 / BOSS）

- **威胁规约**：杂兵是拿来打的（敌弹 2 伤蹭血，不承担"躲"的设计责任）；"躲"的义务只在重击层，且**先预警后伤害**——但预警只在发射器上（**枪口预警闪光+警告音**，统一入口 `ThreatFlash.warn()`：`threat_flash.tscn` 红色高亮光晕+细线十字+细实线环、固定 0.6s 驻留提醒，`threat_warn` 双声滴滴同拍——精英齐射/BOSS 扫射/弹雨同一语汇，与攻击类型/出弹窗解耦，只负责把视线钉到威胁源；top_level 钉枪口世界位）。**特效规约：不写程序化绘制，全用贴图素材+引擎节点**（Sprite2D/粒子），颜色/大小/时长是导出参数，编辑器里自己调（`fx_*.svg` + `threat_flash.tscn` / `flash_burst.tscn`）。不做虚空区域标记。躲避动词只有跑酷动词——跳/推进升/贴地/借地形，没有闪避键。
- **失衡（AC6 式冲击/STAGGER：枪射攒失衡→瘫住→近战砍）**：玩家攻击带冲击值（**枪弹 8——持续射击就是主积累手段**，近战 45/60 快速垫格），打满目标失衡上限即失衡硬直——停摆不出招、受伤 ×1.5、BOSS 瘫沉给你近战爆发窗。冲击在**最后一次受击 1.4s 后才开始衰减**（30/s，断了节奏清得很快），连打只涨不掉。失衡恢复后有**免疫期**（杂兵 3s/精英 6s/BOSS 8s）攒不了冲击，防连续失衡锁死。上限：杂兵 30（4 发）/ 精英 90（12 发）/ BOSS 140（18 发命中）；硬直 0.9/1.8/3.2s。BOSS 的冲击条在 HUD 血条下方（黄色）。
- **精英·导弹车**：跑过 `ELITE_MIN_DISTANCE` 后进选怪池（15%）。继承步行炮台的车体与受击/死亡全套（击退响应 0.25，重甲钝感），攻击层替换为周期导弹齐射：枪口预警闪光（0.6s 固定）+ 0.5s 出弹窗 → 真追踪导弹 → 落地**球状爆伤**（半径 95+玩家宽限：跳跃顶点逃不掉，必须推进升空）。
- **BOSS 追击大型机**：`BOSS_FIRST_DISTANCE`（6000）首遇，击退后 12000 再遇。锁画面右缘与玩家同行——跑酷不断、镜头不接管。**平时钉在构图位**（镜头中心右侧 1000，画面右 5/6）：不追人不压进，距离由玩家是否推进决定。**移动是真物理**（速度+加速度+比例趋近，无坐标吸附/瞬移），横向速度上限 640；**扫射全程锚点冻结**（开炮停稳）——玩家推进自然拉近，这就是近战窗口：冲刺 900 > 它的上限 640，停驻期能破防贴脸。锚点从玩家位置直算不经 Camera2D：玩家死亡的震屏（offset）不会把 BOSS 抽得瞬移。两招交替：**高位扫射**（机体真的压到射高 390 再开火——本体机动就是预警，枪口预警 0.35s 后**机枪流**：≈12 发/秒持续 1.6s、散布半角 2° 扫成扇面；枪口 410 在最高地形站立头顶 470 之上，贴地/起跳安全、滞空挨打；二阶段双机枪 2.2s）⇄ **导弹雨**（发射臂闪光 → 追踪导弹齐射：追玩家脚底、飞过即锁向砸地、撞地爆球）。半血进二阶段：节奏加快、双机枪、导弹+2。击退得 300 分，血条在 HUD 顶部（遭遇时 WARNING 闪字）。
- **追踪导弹规约**（`heavy_missile.gd`）：有限转向率（3.2rad/s，可甩但甩不干净）追玩家脚底（瞄脚底让弹道自然收束地面）；目标落到弹道后方（已飞过）或追踪超时 3s 即锁死朝向直线飞行，必撞地不缠斗；只与地面耦合（穿过机体不引爆），撞地即爆，球状检测（`ground_blast.gd`，引爆帧一次结算）。
- 数值全部在 `balance.gd` 的 `HEAVY_*` / `ELITE_*` / `BOSS_*` 段。实现：导弹 `heavy_missile.gd`、爆伤 `ground_blast.gd`；精英继承 `Enemy` 只换攻击层，BOSS 也继承 `Enemy`（瞄准/受击/死亡复用），画面锚定/纵向机动/出招状态机自管；调度在 `spawner.gd`（BOSS 非池化）。
- **占位美术**：BOSS 机体仍为平涂方块 SVG（`assets/boss_dreadnought_*.svg`）；精英导弹车已出正式图 `assets/elite_mortar_body.svg`（60×80 车体+肩部垂发舱一体构图：小头前置红眼缝、两仓垂发舱后置高过头=一轮 2 发，发射方向跟仓口实际朝向）；特效全部是贴图素材（`assets/fx_*.svg`）+ 场景参数（`threat_flash.tscn` / `flash_burst.tscn` / `muzzle_flash.tscn` 枪口焰（旧版淡暖黄观感+粒子曲线） / `missile_smoke.tscn` 拉烟 + `missile_flame.tscn` 导弹尾焰），编辑器里直接调；**例外：推进焰 `thruster_flame.gd` 经用户拍板保留 `_draw` 固定形态焰**（火箭引擎焰直接绘制比粒子合适，粒子版已回退）；正式美术后补。

## 启动流程（小恐龙式）

开机即从全黑渐亮（0.5s）进启动页：机甲在原点平地待命（不刷怪、UI 藏起、锈雨照下），屏幕提示"点击屏幕或按任意键开始"（移动端为"触摸屏幕开始"）。任意输入后进战斗——"主系统，作战模式。"播报 + HUD 依次点亮 + 头顶条渐亮 + 触控按钮渐显（开场无喷焰——推进器点火演出已删，全焰+推进音会被读成误触发推进）；操作延迟约半秒解锁（COMBAT_INPUT_DELAY），开始那一下的按键不会直接变成跳跃/攻击。死亡时机体失控，触控 UI 渐隐停用（全屏开火区不闭嘴会吃掉重开输入）。死亡重开（任意键 / 点屏，结算出现后 0.4s 防抖挡残留输入）完整渐黑（0.5s）→ 全黑略停一拍（0.25s）→ 重载 → 从黑渐亮回到启动页，再点一次才开始。转场黑屏在全局 autoload 层（`scripts/scene_fade.gd`，名 `Fade`）——放场景内会随旧场景卸载，reload 空档帧闪清屏色（踩过）。待机时机体每隔几秒排一口待机汽（推进器小喷焰）。

## 风格规约（做任何视觉/UI 前先读）

- **全游戏平涂：无描边、无边框、无底板、无阴影。** UI 就是纯字加颜色，不要给任何东西套框或垫底。
- 美术手写 SVG，AC6 设计语言。四套场景提案全保留，后续都会装（锈雨废都已实装）。
- **阵营色（敌我识别的统一出处）**：玩家点缀琥珀 `#ffa04a`，敌方点缀锈红 `#ff5140`，命中迸溅继承发射方的阵营色。**子弹当前敌我共用同一颗亮黄 `#ffee58` 细长水滴**（纯色无弹芯，单一资源 `bullet_player.svg`；第一代琥珀/锈红双色水滴存档于 `bullet_enemy.svg`，要恢复区分把 enemy_bullet.tscn 的贴图改回去即可）。敌弹贴图纵向压 0.7（enemy_bullet.tscn 里 Sprite2D scale）：慢弹凝视得住显短粗，快弹拖尾显细长，压细反向补偿观感差；非均匀缩放只能加在 Sprite 上，加在会旋转的 Area2D 上斜飞会被剪切。
- 字幕/HUD 中文，统一走 `UIFont.cjk()`（打包的思源黑体子集 `assets/fonts/ui_cjk.ttf`）。Web 导出拿不到系统字体，SystemFont 在网页上全是豆腐块；**改了界面文案/播报台词要重跑 `py -3 tools/subset_font.py`**，否则新字在 Web 端缺字。

## 架构速览

- **内容开关**：Main 节点的导出参数（编辑器 Inspector 打勾）——`enable_boss`（追击大型机）/ `enable_elite`（精英·导弹车）/ `enable_threat_warnings`（威胁提醒=枪口预警闪光+警告音，统一走 `ThreatFlash.warn()`；关=闪光与警告音都不出、直接出招）。_ready 转发给 Spawner（`boss_enabled`/`elite_enabled` 门控）与预警组件（`ThreatFlash.warnings_enabled` 静态开关，出招节拍不变）。
- `scripts/balance.gd` — **所有可调数值的唯一出处**（autoload `Balance`）。场景和脚本不存副本，改了没效果先查是不是有副本遮蔽。
- `scripts/scroll_object.gd` + `spawner.gd` — 按玩家带符号位移刷怪 + 对象池回收；地形 `terrain.gd` 高低三档连续，`world_strip.gd` 平铺背景。
- `scripts/comms.gd` — 系统播报（autoload `Comms`）：**非人声机电提示，无剧情无角色**。只有三条：作战开始 + 两档低 AP（50%/25%，滞回防重复）。字幕（AC6 式白字+分隔横线）+ 电台总线（320–3200Hz 带通，效果链 `Balance.COMMS_RADIO_FX` 开关，当前关）。
- `scripts/sfx.gd` — 音效总管（autoload `Sfx`）：固定 12 声道池 + 注册字典音库 + 逐键节流，全非定位（镜头即耳朵）；推进连续音吃 Player 喷焰档位，环境床走 Amb 总线。台账见 `design/sfx.md`。
- `default_bus_layout.tres` — Sfx/Amb/Radio 三条总线的烘焙布局，**必配**：Web 导出上运行时 `AudioServer.add_bus` 建的总线不出声（2026-10-17 实测定罪），代码里 `_ensure_bus`/Comms 的运行时补建只是桌面兜底。
- `data/comms.json` — 播报单一数据源：`text`=中文字幕，`tts`=英文朗读，说话人含 edge-tts/piper 两套音色参数。

## 系统播报规约

- **只有系统音，不做人声角色、不做剧情对白**（用户定案：剧情线整体砍掉）。失败不播报。
- **声音配方分两层，缺一就是"平"**：烘焙层保留韵律起伏（comms.json 说话人 `piper` 块：`noise_scale` 0.5，压太低=抑扬全无；`length_scale` 1.3 控制语速），运行层电台链造临场感（comms.gd `_setup_audio`：带通 320–3200 → EQ 2k 提亮 → 软削波 → 重压缩（泵感+统一响度）→ 拍背延迟 → 限幅，外加常驻静噪底床 `_static_bed.wav` 随频道开关门控）。调口味改 balance.gd 的 `COMMS_RADIO_*` 常量。Godot 4 音频 API 坑：压缩器 `attack_us`（微秒）/`release_ms`（毫秒）异形单位；削波用 `pre_gain`，没有 `drive_db`。
- 台词口径：开场 "Main system, combat mode."；低 AP 报 "AP remaining fifty/twenty-five percent."。新增播报词条照这个口径，短、平、无感情。

## 语音烘焙（TTS）

```
python tools/bake_tts.py                   # edge-tts 微软神经声（首选，需网络），增量补缺
python tools/bake_tts.py --backend piper   # piper 本地神经声（离线）
python tools/bake_tts.py --force           # 全量重烘
python tools/bake_tts.py --list            # 列台词与音色
```

- 产物 `assets/vo/<id>.mp3|.wav`，comms.gd 按 mp3 优先、wav 兜底加载；squelch 开合音效由脚本纯标准库合成。
- **坑**：edge-tts 并发会触发 403 临时封禁（脚本已固定串行）；失败会留 0 字节残文件（脚本已加清理）。
- **piper 音色模型**存 `tools/piper_voices/`（约 345MB，不入库，丢了要重下）：lessac-high(SYSTEM) / hfc_female-medium(VELA) / ryan-high(WARDEN) / joe-medium(OUTPOST)。下载用 GitHub 加速镜像 + 分块（单连接被限到 ~40KB/s，分块 ~1MB/s）：

```
P=https://ghfast.top/https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models
python tools/chunked_download.py $P/vits-piper-en_US-lessac-high.tar.bz2 lessac.tar.bz2 8
# 其余同构：hfc_female-medium / ryan-high / joe-medium；解包后 .onnx/.onnx.json 拷进 tools/piper_voices/
```

- 下载源教训：HuggingFace 直连不通；hf-mirror.com 会无预警截断大文件（lessac 反复卡死在同一字节就是它）；l2arctic 是非母语口音库，别拿来配主要角色；kathleen/alan/danny 在 GitHub 发布页没有打包。
- 改台词流程：改 `data/comms.json` → 跑烘焙（增量只补改过的）→ 完事。改中文字幕（`text` 字段）不用重烘，只有改 `tts`（英文朗读）才要。

## 音效合成（SFX）

```
pip install soundfile numpy    # 实录解码依赖（一次）
py -3 tools/gen_sfx.py         # 实录转换+合成垫，输出 assets/sfx/（秒级，字节级可复现）
```

- 26 个 wav：枪/斩/命中/爆炸/推进循环/锈雨环境床。台账与响度档位见 `design/sfx.md`。
- 方法论（别回退）：物理声（枪/金属/挥砍/脚步）必须实录为底——纯合成被判出戏；
  合成只保留纯噪声能量（爆炸/循环床）与电子源（UI sting）。CC0 素材在 `tools/ref_sfx/`（含 LICENSE）。
- 每个文件名 crc32 定种子：重生成字节不变；新音效 = gen_sfx.py 转换清单加行 + sfx.gd 音库注册 + 事件处 `Sfx.play(...)`。
- 循环音（推进/环境床）接缝由脚本保证（延长段交叉 + 频率 snap + 母带绕环收敛），Godot 侧运行时设 LOOP_FORWARD，不依赖 .import。
- 生成后要 `"$G" --headless --import` 一次，游戏里才 `load()` 得到。

## 自验流程（Godot 是 Steam 版）

```
G="C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$G" --headless --check-only --script res://scripts/xxx.gd   # 单脚本语法
"$G" --headless --quit-after 120                              # 整场景跑，看报错
"$G" -- --autotest                                            # 全流程自测（必须带窗口！）
```

- `--check-only` 不注册 autoload：引用 `Balance`/`Comms` 报 Identifier not found 属预期，以整场景跑为准。
- `--autotest` 无头模式没有渲染帧，截图协程会永远挂起，必须带窗口跑；截图落 `autotest_shots/`。
- 新增资源（音频等）后先 `"$G" --headless --import` 再验，否则 `load()` 拿不到。

## 未做 / 待定

- edge-tts 神经声重烘（质量上限更高的网络后端；现为 piper 本地音）。
- 更多系统播报词条（如弹药/补给类），照"系统播报规约"口径加。
- 精英/BOSS 占位美术换正式 SVG；导弹发射/落地爆炸的专用音效配方（现暂借敌枪/敌爆声）。
- BOSS 击退奖励演出（补给掉落/撤退航线）；二阶段换招（现为同招提速加量）。
