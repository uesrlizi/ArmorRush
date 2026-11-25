# 更改日志：BOSS 多选机制

## 01 · 2026-11-25 场景可登记多台 BOSS + RUSH 按 BOSS 抽再配场景

**起因**：用户提出「调整下 BOSS 机制，要允许一个场景有多个对应 BOSS，随机刷其中一个，最终站 BOSS 连战也是按 BOSS 抽然后配场景」，并要求做雪原的新 BOSS「机械冰蠕」（AC6 冰雪蠕虫/泰拉瑞亚毁灭者方向：真钻地、不悬浮，机制见 [_更改日志_BOSS实装_冰钻.md](_更改日志_BOSS实装_冰钻.md)）。

**改动**：

- **登记表正本=`RunState.WORLD_BOSSES`**：场景路径 → BOSS 场景路径数组（首项=主位，`debug_spawn_boss()` 无参出主位=探针与直开场景的确定性入口）。十张场景全部登记（雪原两台：哨兵+冰钻）。world 场景的 `Spawner.boss_scene` 导出摘除（含 ext_resource），只留给没登记的场景兜底（loot_armory 试装场）。
- **普通关**：BOSS 遭遇触发时 `RunState.draw_boss_for_world()` 在本场景名单里现抽——本局没打过的优先，名单全打过才清账重抽；`Spawner.spawn_run_boss()` 是战斗路径唯一出场口。
- **RUSH 改版**：先抽 BOSS（本局没打过的里随机挑 `RUN_RUSH_COUNT` 台，不够用打过的补，阵容内 BOSS 不重复；同一张场景登记的多台不同时进一套阵容），再逐台配场景——优先本局没去过的、且避开上一关；单宿主 BOSS（冰钻只有雪原）无处挪时允许重访/相邻同场景（同场景换一台 BOSS）。`RunState.pending_boss` 随 `draw_next()` 携带给落地场景的 Spawner（取即清）；`current_boss` 记本关出阵的 BOSS（探针读）。
- **玩家侧索敌通用化**：`Enemy.aim_point()`（索敌点，默认=本体）+ `Enemy.is_targetable()`（是否可索敌）+ `Enemy.aim_of()`（Node2D 统一入口）三个虚方法；玩家枪口俯仰/预判瞄准/自动开火 LOS/肩炮瞄准/近战锁定/蜂巢导弹归航全部改走索敌点并跳过不可索敌单位。普通单位行为零变化（默认实现=原样），钻地体靠覆写实现「全埋地下=不可打」。

**探针**：`probe_run_loop` C/D 段改按新阵容账（BOSS 不重复且没打过的优先、配的场景=登记场景、场景与 BOSS 双双不重复、通关空串）；`tests/transition_probe` 纯 API 段+真实流程段同步改（普通关袋内不重复照旧；RUSH 断言配场景=抽定 BOSS 的登记场景、阵容 BOSS 不重复、落地即战的就是抽定那台；相邻重复只在单宿主强制时放行）；`probe_worm` R 段覆盖登记表抽签（两台都出、打过的让位、RUSH 配场景 120 局）。

**坑 / 注意**：

- 抽签账全走 `RunState._rng`（定种子可复现，探针在用）。
- `check_asset_refs.py` 报的 `res://scenes/units/boss_` 断链是既有误报（`boss_%d.tscn` 格式串被当部分路径，HEAD 一样报），非本轮引入。
- autotest 各章 BOSS 能力探针按机型分叉，`BossWorm` 落进「无通用探针跳过」分支（能力探针在 probe_worm）。
- **过程事故（自省）**：给 `enemy.gd` 抽 `_end_stagger()` 时把失衡分支里的 `return` 缩进少了一个 tab，变成全敌人每帧无条件提前返回——敌方 AI（翻转/索敌/开火/移动）全灭，w3 autotest 三条 FAIL（哨兵不翻转/精英不出弹/瘫后不浮动）。蠕虫探针全绿没拦住（蠕虫完全自管主循环），最后靠 HEAD 基线对照+最小复现探针定位。教训：重构共享基类的控制流时，改动后必须跑一条覆盖基类 AI 的现役探针（w1/w3 autotest），不能只跑新机自己的探针。

**待用户游戏内验收**：雪原两张 BOSS 的实际抽签手感（同一局雪原可能出哨兵或冰钻）、RUSH 阵容的配场景手感（同场景换一台 BOSS 的重访读法）。
