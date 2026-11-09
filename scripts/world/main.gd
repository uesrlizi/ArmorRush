extends Node2D
## 主场景：只做接线——玩家血量/死亡、击杀得分、跑局计时、结算/HUD 进退场、重开、系统播报转发。
## 小恐龙式启动：开机先进启动页（机甲在原点平地待命，不刷怪、不播报、UI 藏起），
## 点击/任意键才进战斗（系统播报 + HUD 依次点亮；操作延迟解锁，
## 开始那一下的按键不许直接变成跳跃/攻击）。
## 死亡重开：全局黑屏转场（Fade autoload）进重掷的新一关启动页（哪里死不再哪里复活），再点一次才开始。
## 黑屏放全局的原因：场景内的转场层会随旧场景卸载，reload 空档帧闪清屏色。
## 章节推进：击败 BOSS → 延迟 → 抽下一关 → 全局黑场切入；分数跨关累计走
## RunState，新关跳过启动页落地即战（满血来自全新玩家实例；RUSH 击破间
## 不回血例外，见 run_loop.md §1）。局内循环 v2：固定普通关 + 第 5 关 RUSH
## 终局（没抽到的场景连战）+ 通关结算，总开关 RUN_LOOP_ENABLED（balance_global）
## 拨 false 即整套退回旧的无限滚动关。输入跨关连续：系统启动音只开局播一次、
## 交接路径操作立即解锁，按住的键/触控指经 RunState 交接认领不脱手。

## 内容开关（编辑器里直接打勾；_ready 时转发给 Spawner / 预警组件）。
@export_group("内容开关")
## 追击大型机（关 = 全程不遭遇 BOSS）
@export var enable_boss := true
## 精英·导弹车（关 = 选怪池不含精英）
@export var enable_elite := true
## 威胁提醒（关 = 重击没有枪口预警闪光与警告音，直接出弹——无预警硬核模式）
@export var enable_threat_warnings := true

@export_group("场景")
## 清屏色与本章天色同源（转场空档/极端露边时的兜底底色）
@export var sky_color := Color(0.702, 0.663, 0.498)

var score := 0
var _clock_running := false # 跑局计时中：进战斗起走，死亡/通关转场即停（启动页待机不计）

@onready var _player: Player = $Player
@onready var _spawner: Spawner = $Spawner
@onready var _hud: HUD = $HUD
@onready var _touch_controls: TouchControls = $TouchControls
@onready var _title_screen: TitleScreen = $TitleScreen


func _ready() -> void:
	RenderingServer.set_default_clear_color(sky_color)
	# 内容开关转发：BOSS/精英走 Spawner，威胁提醒走预警组件（静态开关，全实例共享）
	_spawner.boss_enabled = enable_boss
	_spawner.elite_enabled = enable_elite
	ThreatFlash.warnings_enabled = enable_threat_warnings
	_player.died.connect(_on_player_died)
	_spawner.enemy_killed.connect(_on_enemy_killed)
	_spawner.boss_defeated.connect(_on_boss_defeated)
	_touch_controls.restart_requested.connect(_on_restart_requested)
	score = RunState.score # 分数跨章累计：黑场交接进来的新章从上一章接着算
	_hud.set_score(score)
	_hud.set_progress(" ".join(RunState.progress_parts())) # 关卡进度/用时同理跨关接续（新一局由 start_run 归零）
	_hud.set_play_time(RunState.play_time)
	_player.hp_changed.connect(Comms.notify_hp)
	_hud.hide_for_title()
	_title_screen.accepted.connect(_on_title_accepted)
	if RunState.take_handoff():
		# 黑场交接进新章：跳过启动页，落地即战斗（全新玩家实例=满血，
		# 原"击败回血"由这个满状态开场替代；RUSH 击破间不回血时改为接上一台
		# 的血量，run_loop.md §1）；不播系统启动播报（整局只在开局那次），
		# 操作立即解锁——按住的移动键跨关不松手，落地就在走
		# （触控件经 RunState 交接认领，按住的手指同理）。
		_title_screen.queue_free()
		_player.carry_over_hp(RunState.take_handover_hp())
		_player.carry_over_shield(RunState.take_handover_shield())
		_enter_combat(true)
	# 开机亮屏：首启与重开回来同路，从全黑渐亮露出启动页。
	Fade.reveal()


func _on_title_accepted() -> void:
	_enter_combat()


## 跑局正计时：只在战斗中走（阵亡/通关转场即停表）；累计值存 RunState 跨关延续，
## HUD 跳秒才刷新文本。
func _process(delta: float) -> void:
	if not _clock_running:
		return
	RunState.play_time += delta
	_hud.set_play_time(RunState.play_time)
	_hud.set_mult(RunState.multiplier()) # 疾驰倍率读数上屏（跳变才重绘；跨关保持不清档）


## 进战斗：系统播报 + HUD 依次点亮 + 机体切换（掐待机汽/头顶条渐亮/操作
## 延迟解锁）+ 刷怪上线。handoff=true 为章末黑场交接：不播系统启动音、
## 操作立即解锁（跨关衔接连续），其余照常。
func _enter_combat(handoff := false) -> void:
	_player.enter_combat(handoff)
	_hud.play_intro()
	_touch_controls.fade_in_controls()
	Comms.notify_combat_start(not handoff)
	_hud.set_mult(RunState.multiplier()) # 落地显示携带档（跨关保持，run_loop.md §2；首喂不闪）
	_spawner.start()
	_clock_running = true


func _on_enemy_killed(points: int) -> void:
	# 计分唯一公式=击杀分×当时倍率（run_loop.md §2）：用涨前档——这一刀按你正在骑的
	# 倍率结账，涨档从下一次击杀生效；倍率关=档恒 1，公式退化为旧制加分。
	var mult := RunState.multiplier()
	RunState.mult_add_kill(points)
	score += points * mult
	RunState.score = score
	_hud.set_score(score)


func _on_player_died() -> void:
	_clock_running = false # 停表：结算报的就是阵亡这一刻的用时
	_cut_held_input()
	_hud.play_outro() # 顶栏随失控退场（信息移入结算面板，不再重复）
	_spawner.stop() # 结算期彻底停刷：残弹打出的击杀分不再把 BOSS 拉进场盖住结算
	# 触控 UI 随失控渐隐停用（活着的触控件会先认领触摸，吃掉"点屏重开"）。
	_touch_controls.fade_out_controls()
	# 玩家爆炸先播完再出结算（按真实时间计时，命中顿帧不影响演出窗口）。世界不冻结：
	# 敌人/BOSS 认 is_dead 停火、移动层照常=自然待机；重开受理在结算动画播完才开闸。
	get_tree().create_timer(BalanceGlobal.GAME_OVER_DELAY, true, false, true).timeout.connect(
		func() -> void:
			var intro := _hud.show_result(score, RunState.progress_parts(), RunState.play_time,
					false, RunState.hits_taken, RunState.mult_max_run, RunState.loot_labels())
			_arm_restart_after(intro, BalanceGlobal.RESULT_RESTART_LOCK)
	)


## 结算重开闸（防误触）：入场动画播完 + 额外锁定后才受理重开，重开提示同拍
## 亮起（看见提示=能按）。RESULT_RESTART_AFTER_INTRO=false 回旧制：面板一出即开闸。
func _arm_restart_after(intro: float, extra_lock: float) -> void:
	var wait := intro + extra_lock if BalanceGlobal.RESULT_RESTART_AFTER_INTRO else 0.0
	if wait <= 0.0:
		_hud.show_restart_hint()
		_touch_controls.arm_restart()
		return
	get_tree().create_timer(wait, true, false, true).timeout.connect(func() -> void:
		_hud.show_restart_hint()
		_touch_controls.arm_restart())


## 战斗结束（阵亡/通关）断开按住的操作：键盘/手柄按住态一律松开，须真的
## 松手重按才再算数——按着的方向/跳跃不带进结算与下一局（触控指由
## fade_out_controls 的 release 放掉）。重开受理只认新按下（非 echo），
## 结算期间一直按着的键不会触发重开。开关 RESULT_CUT_HELD_INPUT。
func _cut_held_input() -> void:
	if not BalanceGlobal.RESULT_CUT_HELD_INPUT:
		return
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action):
			Input.action_release(action)


## 重开：死亡即新一局——RunState.start_run() 清分+整袋重洗+白名单重掷首关
## （不再原地复活同一关），Fade 渐黑 → 全黑略停一拍 → 切入新关；新场景
## _ready 里 Fade.reveal() 接棒渐亮。结算后世界本就照跑（不冻结），直接转场。
func _on_restart_requested() -> void:
	Fade.transition(func() -> void:
		get_tree().change_scene_to_file(RunState.start_run()))


## 本章通关（BOSS 被击败）：掉装备（§4）→ 延迟让爆散演出播完 → 抽下一关 →
## 全局黑场切入（旧制=轮换袋无限滚动）。局内循环 v2（run_loop.md §1）：第
## RUN_NORMAL_LEVELS 关后进 RUSH 终局逐台连战，击破间不回血（血量跨场景携带）；
## 阵容打空=通关——不切场景，原地出通关结算，本局到此结束（重开=新一局）。
## hold_chapter 锁章（自测）照旧不转场也不掉装备（autotest 不碰 mods）。
func _on_boss_defeated(at: Vector2) -> void:
	if RunState.hold_chapter:
		return
	# 掉落击杀瞬掷定、BOSS 终爆那一拍爆出（装备从终爆里炸出来）；定时器与
	# boss.gd/pursuit_boss.gd 的终爆同签名=同受顿帧时间缩放，严格同拍。
	var member := _roll_loot()
	if not member.is_empty():
		get_tree().create_timer(BalanceCombat.BOSS_DEATH_FINALE_TIME).timeout.connect(
			func() -> void:
				if not _player.is_dead():
					spawn_loot_drop(member, at))
	_spawner.stop() # 转场窗口不再补怪（场上残敌照常行动，跑酷不断）
	# 有掉落：黑场拉长到 LOOT_CLEAR_DELAY（终爆拍爆出 → 斜抛+吸附到手 → 播报行读完
	# 再切；用户反馈「显示文字之后太快到下一关」）。计时刻从击败起算：终爆 ~0.9s 在
	# 窗口内播完，剩 ~4s 给斜抛 1.15~1.85s + 播报 2.6s，兜底仍在。
	var delay := BalanceGlobal.CHAPTER_CLEAR_DELAY
	if not member.is_empty():
		delay = BalanceGlobal.LOOT_CLEAR_DELAY
	get_tree().create_timer(delay, true, false, true).timeout.connect(
		func() -> void:
			if _player.is_dead():
				return # 延迟窗口内玩家暴毙：走死亡结算，不切场景
			LootPickup.collect_in_flight() # 转场兜底：在途掉落就地授予，一次都不许丢
			_clock_running = false # 转场/结算不计时：新关进战斗再接着走
			var was_rush := RunState.rush_active # draw_next 会推进局状态，先留影
			var next := RunState.draw_next()
			if next.is_empty():
				_show_clear_result() # RUSH 阵容打空=通关：本局结束
				return
			if was_rush and BalanceGlobal.RUSH_NO_HEAL:
				RunState.handover_hp = _player.hp # 击破间不回血：血量带进下一台
				RunState.handover_shield = _player.shield # 盾同账：击破间不回充（§4）
			RunState.begin_handoff()
			Fade.transition(func() -> void:
				get_tree().change_scene_to_file(next))
	)


## 装备掉落（run_loop.md §4）：开关/dev 冻结闸闸在这里，爆率×掉落表在
## RunState.roll_drop（掉落表=未持有槽，全持有=空掷不掉）。返回掷中的成员
## （空=不掉）；实体在 BOSS 终爆那一拍由 spawn_loot_drop 生成。
func _roll_loot() -> StringName:
	if not BalanceGlobal.LOOT_ENABLED or RunState.loot_frozen or _player.is_dead():
		return &""
	return RunState.roll_drop()


## 生成一件装备芯片（探针可直调定成员）：从击杀点原地弹出（x 收进画面内），朝玩家
## 位置斜抛、后程渐混吸附（不落地，不用地形）；图标=槽位、颜色=成员。
func spawn_loot_drop(member: StringName, at: Vector2) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var half_w := get_viewport_rect().size.x * 0.5
	var cam_x := _player.global_position.x + BalanceGlobal.CAMERA_X_OFFSET
	var x := clampf(at.x, cam_x - half_w + 120.0, cam_x + half_w - 120.0)
	var drop := LootPickup.new()
	drop.setup(member, Vector2(x, at.y))
	container.add_child(drop)


## 通关结算（run_loop.md §1）：不切场景不黑场——BOSS 已亡、刷怪已停，世界
## 照跑（结算不冻结惯例），结算面板从天空带进场；本局结束，操作收线（机体
## 停在原地、按住的操作断开），重开闸比阵亡多锁 CLEAR_RESTART_LOCK（打赢那下
## 手正忙，最易误触），任意键/点屏=新一局。
func _show_clear_result() -> void:
	_player.input_enabled = false
	_cut_held_input()
	_touch_controls.fade_out_controls()
	_hud.play_outro() # 顶栏退场（信息移入结算面板，不再重复）
	var intro := _hud.show_result(score, RunState.progress_parts(), RunState.play_time,
			true, RunState.hits_taken, RunState.mult_max_run, RunState.loot_labels())
	_arm_restart_after(intro, BalanceGlobal.CLEAR_RESTART_LOCK)
