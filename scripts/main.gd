extends Node2D
## 主场景：只做接线——玩家血量/死亡、击杀得分、重开、系统播报转发。
## 小恐龙式启动：开机先进启动页（机甲在原点平地待命，不刷怪、不播报、UI 藏起），
## 点击/任意键才进战斗（系统播报 + HUD 依次点亮；操作延迟解锁，
## 开始那一下的按键不许直接变成跳跃/攻击）。
## 死亡重开：全局黑屏转场（Fade autoload）回到启动页，再点一次才开始。
## 黑屏放全局的原因：场景内的转场层会随旧场景卸载，reload 空档帧闪清屏色。
## 章节推进：击败 BOSS → 延迟 → 全局黑场 → next_scene（下一章 Main 场景）；
## 分数跨章累计走 RunState，新章跳过启动页落地即战（满血来自全新玩家实例）。

## 内容开关（编辑器里直接打勾；_ready 时转发给 Spawner / 预警组件）。
@export_group("内容开关")
## 追击大型机（关 = 全程不遭遇 BOSS）
@export var enable_boss := true
## 精英·导弹车（关 = 选怪池不含精英）
@export var enable_elite := true
## 威胁提醒（关 = 重击没有枪口预警闪光与警告音，直接出弹——无预警硬核模式）
@export var enable_threat_warnings := true

@export_group("章节")
## 通关（击败 BOSS）后黑场进入的下一章；空 = 末章，击败后照常续跑不切场景
@export_file("*.tscn") var next_scene := ""
## 清屏色与本章天色同源（转场空档/极端露边时的兜底底色）
@export var sky_color := Color(0.702, 0.663, 0.498)

var score := 0

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
	_player.hp_changed.connect(Comms.notify_hp)
	_hud.hide_for_title()
	_title_screen.accepted.connect(_on_title_accepted)
	if RunState.take_handoff():
		# 黑场交接进新章：跳过启动页，落地即战斗（全新玩家实例=满血，
		# 原"击败回血"由这个满状态开场替代）。
		_title_screen.queue_free()
		_enter_combat()
	# 开机亮屏：首启与重开回来同路，从全黑渐亮露出启动页。
	Fade.reveal()


func _on_title_accepted() -> void:
	_enter_combat()


## 进战斗：系统播报 + HUD 依次点亮 + 机体切换（掐待机汽/头顶条渐亮/操作
## 延迟解锁）+ 刷怪上线。
func _enter_combat() -> void:
	_player.enter_combat()
	_hud.play_intro()
	_touch_controls.fade_in_controls()
	Comms.notify_combat_start()
	_spawner.start()


func _on_enemy_killed(points: int) -> void:
	score += points
	RunState.score = score
	_hud.set_score(score)


func _on_player_died() -> void:
	# 触控 UI 随失控渐隐停用（全屏开火区不闭嘴会吃掉"点屏重开"）。
	_touch_controls.fade_out_controls()
	# 玩家爆炸先播完（树暂停会冻住所有特效），延迟 GAME_OVER_DELAY 再定格出结算。
	# 按真实时间计时（ignore_time_scale），命中顿帧不影响演出窗口。
	get_tree().create_timer(Balance.GAME_OVER_DELAY, true, false, true).timeout.connect(
		func() -> void:
			_hud.show_game_over(score)
			get_tree().paused = true
	)


## 重开：Fade 渐黑 → 全黑略停一拍 → 重载；新场景 _ready 里 Fade.reveal()
## 接棒渐亮。树先解除暂停（否则转场 tween 不跑）；世界短暂复活无碍——
## 玩家已毁、敌人见尸停火。章内重开 = 这一行从头再来，跨章累计的分数清零。
func _on_restart_requested() -> void:
	RunState.score = 0
	get_tree().paused = false
	Fade.transition(func() -> void: get_tree().reload_current_scene())


## 本章通关（BOSS 被击败）：延迟让爆散演出播完 → 全局黑场 → 换下一章场景。
## 分数随击杀实时累进 RunState，新章 _ready 接走；黑场交接旗标让新章跳过
## 启动页落地即战。分数门槛刷 BOSS 的调度照旧——末章（next_scene 空）不切。
func _on_boss_defeated() -> void:
	if next_scene == "" or RunState.hold_chapter:
		return
	_spawner.stop() # 转场窗口不再补怪（场上残敌照常行动，跑酷不断）
	get_tree().create_timer(Balance.CHAPTER_CLEAR_DELAY, true, false, true).timeout.connect(
		func() -> void:
			if _player.is_dead():
				return # 延迟窗口内玩家暴毙：走死亡结算，不切章
			RunState.begin_handoff()
			Fade.transition(func() -> void: get_tree().change_scene_to_file(next_scene))
	)
