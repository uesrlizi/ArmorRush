class_name HUD
extends CanvasLayer
## 得分、操作提示、游戏结束面板。
## 血条/气槽已移到角色头顶（scripts/overhead_bar.gd），左上角不再有。
## 启动页待机时战斗 UI 整组藏起，进战斗按"横线展开 → 得分滑入 → 帮助跟进"
## 的次序点亮（系统启动感）。操作提示按输入设备分文案（手柄/键鼠，热插拔即切；
## 移动端不显示——触控按钮自明）。重开输入由 TouchControls 统一接管
## （任意键/点屏，结算画面），本层不再监听。

const SCORE_RULE_WIDTH := 220.0  # 得分下装饰横线的展开终宽
const SCORE_RULE_HEIGHT := 3.0

const HELP_TEXT_KEYBOARD := "A/D 移动 · 空格 跳跃/按住推进 · J 斩击 · K/右键 射击"
const HELP_TEXT_GAMEPAD := "左摇杆 移动 · A 跳跃/按住推进 · Y/左扳机 斩击 · RB/右扳机 射击"

const BOSS_BAR_WIDTH := 700.0
const BOSS_BAR_HEIGHT := 12.0

@onready var _score_label: Label = $Root/ScoreLabel
@onready var _score_rule: ColorRect = $Root/ScoreRule
@onready var _help_label: Label = $Root/HelpLabel
@onready var _game_over: VBoxContainer = $Root/GameOver
@onready var _game_over_score: Label = $Root/GameOver/GameOverScore

var _score_home_x := 0.0
var _intro_played := false
var _help_allowed := true # 移动端不显示操作提示（触控按钮自明）
var _boss_bar: BossBar
var _boss_impact_bar: BossBar
var _boss_name: Label
var _warning_label: Label
var _warning_tween: Tween


func _ready() -> void:
	add_to_group("hud") # BOSS 按组找到 HUD：入场亮血条+WARNING，击退收血条
	# 中文界面用系统字体兜底（Godot 内置默认字体没有 CJK 字形）。
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Arial",
	])
	for node in find_children("*", "Label", true, false):
		(node as Label).add_theme_font_override("font", font)
	_build_boss_ui(font)
	_game_over.visible = false
	_score_home_x = _score_label.position.x
	if OS.has_feature("mobile"):
		_help_allowed = false
		_help_label.visible = false
	else:
		_apply_help_text()
		# 手柄热插拔即切提示文案。
		Input.joy_connection_changed.connect(
				func(_device: int, _connected: bool) -> void: _apply_help_text())


## 操作提示按输入设备分文案：接着手柄显示手柄版，否则键鼠版。
func _apply_help_text() -> void:
	_help_label.text = HELP_TEXT_GAMEPAD \
			if Input.get_connected_joypads().size() > 0 else HELP_TEXT_KEYBOARD


## BOSS 战 UI 全部程序化搭（main.tscn 不放节点）：顶部居中血条+机名、
## 大字 WARNING 闪两轮。全平涂纯字/色块，无底板。
func _build_boss_ui(font: SystemFont) -> void:
	var root: Control = $Root
	_boss_name = Label.new()
	_boss_name.text = "未登记大型机"
	_boss_name.add_theme_font_override("font", font)
	_boss_name.add_theme_font_size_override("font_size", 20)
	_boss_name.add_theme_color_override("font_color", Balance.HP_BAR_ENEMY_COLOR)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.anchor_left = 0.5
	_boss_name.anchor_right = 0.5
	_boss_name.position = Vector2(-BOSS_BAR_WIDTH * 0.5, 22.0)
	_boss_name.size = Vector2(BOSS_BAR_WIDTH, 26.0)
	root.add_child(_boss_name)

	_boss_bar = BossBar.new()
	_boss_bar.anchor_left = 0.5
	_boss_bar.anchor_right = 0.5
	_boss_bar.position = Vector2(-BOSS_BAR_WIDTH * 0.5, 52.0)
	_boss_bar.size = Vector2(BOSS_BAR_WIDTH, BOSS_BAR_HEIGHT)
	root.add_child(_boss_bar)

	# 冲击条（AC6 式失衡条）：血条下方一根黄条，打满=失衡（硬直+受伤加深）
	_boss_impact_bar = BossBar.new()
	_boss_impact_bar.fill_color = Balance.HP_BAR_IMPACT_COLOR
	_boss_impact_bar.anchor_left = 0.5
	_boss_impact_bar.anchor_right = 0.5
	_boss_impact_bar.position = Vector2(-BOSS_BAR_WIDTH * 0.5,
			52.0 + BOSS_BAR_HEIGHT + 6.0)
	_boss_impact_bar.size = Vector2(BOSS_BAR_WIDTH, 7.0)
	root.add_child(_boss_impact_bar)

	_warning_label = Label.new()
	_warning_label.text = "WARNING"
	_warning_label.add_theme_font_override("font", font)
	_warning_label.add_theme_font_size_override("font_size", 92)
	_warning_label.add_theme_color_override("font_color", Balance.HP_BAR_ENEMY_COLOR)
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.anchor_left = 0.5
	_warning_label.anchor_right = 0.5
	_warning_label.position = Vector2(-600.0, 170.0)
	_warning_label.size = Vector2(1200.0, 120.0)
	_warning_label.visible = false
	root.add_child(_warning_label)

	hide_boss()


## 启动页待机：战斗 UI 全组藏起（Main 在标题路径调）。
func hide_for_title() -> void:
	_intro_played = false
	for node: CanvasItem in [_score_label, _score_rule, _help_label]:
		node.visible = false


## 重开直进战斗：不播启动动画，整组立即就位。
func show_combat_instant() -> void:
	_intro_played = true
	for node: CanvasItem in [_score_label, _score_rule, _help_label]:
		node.visible = true
		node.modulate.a = 1.0
	_help_label.visible = _help_allowed
	_score_label.position.x = _score_home_x
	_score_rule.size = Vector2(SCORE_RULE_WIDTH, SCORE_RULE_HEIGHT)


## 进战斗启动动画：横线从左展开、得分标签随之滑入，帮助文字半拍后跟进。
func play_intro() -> void:
	if _intro_played:
		return
	_intro_played = true
	for node: CanvasItem in [_score_label, _score_rule, _help_label]:
		node.visible = true
	_help_label.visible = _help_allowed
	_score_label.modulate.a = 0.0
	_score_label.position.x = _score_home_x - 18.0
	_score_rule.size = Vector2(0.0, SCORE_RULE_HEIGHT)
	_help_label.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_score_label, "modulate:a", 1.0, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_score_label, "position:x", _score_home_x, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_score_rule, "size", Vector2(SCORE_RULE_WIDTH, SCORE_RULE_HEIGHT), 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_help_label, "modulate:a", 1.0, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func set_score(score: int) -> void:
	_score_label.text = "得分 %d" % score


func show_game_over(score: int) -> void:
	_game_over_score.text = "最终得分 %d" % score
	_game_over.visible = true
	Sfx.play(&"ui_gameover")


## ---- BOSS 战 UI（Boss 按组调用） ----

func show_boss() -> void:
	_boss_bar.reset()
	_boss_bar.visible = true
	_boss_impact_bar.reset()
	_boss_impact_bar.visible = true
	_boss_name.visible = true


func set_boss_hp(ratio: float) -> void:
	_boss_bar.set_ratio(ratio)


func set_boss_impact(ratio: float) -> void:
	_boss_impact_bar.set_ratio(ratio)


func hide_boss() -> void:
	_boss_bar.visible = false
	_boss_impact_bar.visible = false
	_boss_name.visible = false


## WARNING 大字闪两轮（AC6 式遭遇警报），结束自隐；重复调用重启闪烁。
func flash_warning() -> void:
	if _warning_tween != null:
		_warning_tween.kill()
	_warning_label.visible = true
	_warning_label.modulate.a = 1.0
	_warning_tween = create_tween()
	for i in 4:
		_warning_tween.tween_property(_warning_label, "modulate:a", 0.1, 0.22)
		_warning_tween.tween_property(_warning_label, "modulate:a", 1.0, 0.22)
	_warning_tween.tween_callback(func() -> void: _warning_label.visible = false)
