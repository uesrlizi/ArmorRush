class_name HUD
extends CanvasLayer
## 得分/关卡数/用时、操作提示、游戏结束面板。
## 血条/气槽已移到角色头顶（scripts/overhead_bar.gd），左上角不再有。
## 顶栏两角对称收边：左上「得分 → 横线 → 关卡 N」竖排一列，右上「用时 mm:ss
## → 横线」镜像；BOSS 血条居中，三块共用顶带。
## 启动页待机时战斗 UI 整组藏起，进战斗按"横线展开 → 得分/用时滑入 → 关卡数
## 半拍跟进 → 帮助跟进"的次序点亮（系统启动感；每进一关重播=关卡数亮相）。
## 操作提示按输入设备分文案（手柄/键鼠，热插拔即切；
## 移动端不显示——触控按钮自明）。重开输入由 TouchControls 统一接管
## （任意键/点屏，结算画面），本层不再监听。

const SCORE_RULE_WIDTH := 220.0  # 得分下装饰横线的展开终宽
const SCORE_RULE_HEIGHT := 3.0
const STAGE_FONT_SIZE := 24      # 关卡数比得分(30)低一档：挂横线下当副标题
const TIME_LABEL_WIDTH := 400.0  # 用时标签框宽（右对齐，只需容得下最长读数）
const SCORE_SLIDE := 18.0        # 得分/关卡/用时的滑入滑出量（px）

# 结算面板（顶部天空带）：标题带 y 0..300 都是无天空/远景剪影区，不压场景元素。
const RESULT_TITLE_Y := 40.0    # 标题 Label 顶（72 号字基线约在 112）
const RESULT_RULE_W := 620.0    # 标题下横线宽
const RESULT_HINT_Y := 228.0    # 呼吸提示顶
const RESULT_TEXT_SIZE := 28    # 统计行统一字号：单档消灭组间大小不齐（数字满墨/汉字 0.75 只靠明度分层）
const BREATHE_PERIOD := 1.5     # 提示呼吸周期（与启动页同款）
const BREATHE_MIN := 0.45       # 呼吸下限（modulate.a）

## 操作提示只列最简 WASD（单手方案；方向键/空格同样可用但不占提示位）。
## 开火全自动，提示里没有射击。
const HELP_TEXT_KEYBOARD := "A/D 移动 · W 跳跃/按住推进 · S 斩击"
const HELP_TEXT_GAMEPAD := "左摇杆 移动 · A 跳跃/按住推进 · X 斩击"

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
var _stage_label: Label
var _stage_home_x := 0.0
var _time_label: Label
var _time_home_offsets := Vector2.ZERO # 用时标签右锚偏移(左, 右)：滑入按偏移走，不依赖布局时机
var _time_rule: ColorRect
var _shown_seconds := -1 # 用时标签当前显示的整秒（跳秒才刷新文本）
var _result_title: Label       # 结算面板（顶部天空带，程序化搭，见 _build_result_ui）
var _result_rule: ColorRect
var _result_groups: Array = [] # 统计三组：[组= [字Label, 数Label]]，统一字号只靠明度分层
var _result_hint: Label
var _result_tween: Tween
var _boss_bar: BossBar
var _boss_impact_bar: BossBar
var _boss_name: Label
var _warning_label: Label
var _warning_tween: Tween


func _ready() -> void:
	add_to_group("hud") # BOSS 按组找到 HUD：入场亮血条+WARNING，击退收血条
	# 中文界面用打包的思源黑体子集（Web 端无系统字体，见 ui_font.gd）。
	var font := UIFont.cjk()
	for node in find_children("*", "Label", true, false):
		(node as Label).add_theme_font_override("font", font)
	_build_boss_ui(font)
	_build_run_info(font)
	_game_over.visible = false
	hide_result()
	_score_home_x = _score_label.position.x
	if Platforms.is_mobile():
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
func _build_boss_ui(font: Font) -> void:
	var root: Control = $Root
	_boss_name = Label.new()
	_boss_name.text = "未登记大型机"
	_boss_name.add_theme_font_override("font", font)
	_boss_name.add_theme_font_size_override("font_size", 20)
	# 机体名跟本章得分字色（各章 tscn 按天色定深/浅=同一条可读性账，单一来源；
	# 阵营味道由正下方信号红粗血条承担，细字不再吃信号红）。
	_boss_name.add_theme_color_override("font_color",
			_score_label.get_theme_color("font_color"))
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

	# 冲击条（AC6 式失衡条）：血条下方一根条，从中心向两边填充；打满=失衡
	# （硬直+受伤加深）；实值白、虚值黄（虚影=宽限衰减的拖尾），失衡期整条
	# 匀速排空当硬直计时器（读数在 boss.gd 换源）
	_boss_impact_bar = BossBar.new()
	_boss_impact_bar.center_fill = true
	_boss_impact_bar.fill_color = BalanceGlobal.HP_BAR_IMPACT_FILL_COLOR
	_boss_impact_bar.ghost_color = BalanceGlobal.HP_BAR_IMPACT_COLOR
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
	_warning_label.add_theme_color_override("font_color", BalanceGlobal.HP_BAR_ENEMY_COLOR)
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.anchor_left = 0.5
	_warning_label.anchor_right = 0.5
	_warning_label.position = Vector2(-600.0, 170.0)
	_warning_label.size = Vector2(1200.0, 120.0)
	_warning_label.visible = false
	root.add_child(_warning_label)

	hide_boss()


## 跑局信息（本局第几关 + 正计时用时）程序化搭（同 BOSS UI，免改 7 个关卡场景）。
## 位置全从左上得分组派生：关卡数挂得分横线下 10px、与横线左缘对齐；用时标签与
## 横线按左上组的边距镜像到右上角（右锚定，右对齐）。字色/线色取本章得分同款
## （各章 tscn 按天色定深浅，单一来源）。ui_cjk 的数字是等宽字形，跳秒不抖。
func _build_run_info(font: Font) -> void:
	var root: Control = $Root
	var ink := _score_label.get_theme_color("font_color")

	_stage_label = Label.new()
	_stage_label.add_theme_font_override("font", font)
	_stage_label.add_theme_font_size_override("font_size", STAGE_FONT_SIZE)
	_stage_label.add_theme_color_override("font_color", Color(ink, 0.85))
	_stage_label.position = Vector2(_score_rule.position.x, _score_rule.position.y + 10.0)
	root.add_child(_stage_label)
	_stage_home_x = _stage_label.position.x

	# 右锚控件：先设位置/尺寸再入树（入树前父区=0，偏移=给定值，同 BOSS UI 惯例）。
	_time_label = Label.new()
	_time_label.add_theme_font_override("font", font)
	_time_label.add_theme_font_size_override("font_size",
			_score_label.get_theme_font_size("font_size"))
	_time_label.add_theme_color_override("font_color", ink)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.anchor_left = 1.0
	_time_label.anchor_right = 1.0
	_time_label.position = Vector2(-TIME_LABEL_WIDTH - _score_label.position.x,
			_score_label.position.y)
	_time_label.size = Vector2(TIME_LABEL_WIDTH, _score_label.size.y)
	_time_home_offsets = Vector2(_time_label.offset_left, _time_label.offset_right)
	root.add_child(_time_label)

	_time_rule = ColorRect.new()
	_time_rule.color = _score_rule.color
	_time_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_rule.anchor_left = 1.0
	_time_rule.anchor_right = 1.0
	_time_rule.position = Vector2(-SCORE_RULE_WIDTH - _score_rule.position.x,
			_score_rule.position.y)
	_time_rule.size = Vector2(SCORE_RULE_WIDTH, SCORE_RULE_HEIGHT)
	_time_rule.pivot_offset = Vector2(SCORE_RULE_WIDTH, 0.0) # 展开动画从右端长出
	root.add_child(_time_rule)

	_build_result_ui(font)


## 结算面板（顶部天空带，程序化搭同 BOSS UI；免改 7 个关卡场景）。
## 构图（mock 七章验证过）：居中标题 → 短横线 → 统计三组（得分/关卡/用时，统一
## 28 号同基线、组间距 64）→ 呼吸提示；整带 y 0..300 都是无天空/远景剪影区，
## 不压高架桥、地面与机体。信息与旧 HUD 重复（旧 HUD 已退场）。全平涂无底板；
## 字色/线色取本章得分同款（暗场章自动浅色），标题沿用各章结算标题色。
func _build_result_ui(font: Font) -> void:
	var root: Control = $Root
	var ink := _score_label.get_theme_color("font_color")
	# 标题色沿用各章 GameOverTitle 的结算标题色（tscn 按天色配过；亮天=暗红、暗场=橙红）。
	var title_rgb := (_game_over.get_node("GameOverTitle") as Label).get_theme_color("font_color")

	_result_title = Label.new()
	_result_title.add_theme_font_override("font", font)
	_result_title.add_theme_font_size_override("font_size", 72)
	_result_title.add_theme_color_override("font_color", title_rgb)
	_result_title.text = "游戏结束"
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.anchor_left = 0.5
	_result_title.anchor_right = 0.5
	_result_title.position = Vector2(-600.0, RESULT_TITLE_Y)
	_result_title.size = Vector2(1200.0, 90.0)
	root.add_child(_result_title)

	_result_rule = ColorRect.new()
	_result_rule.color = ink
	_result_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_rule.anchor_left = 0.5
	_result_rule.anchor_right = 0.5
	_result_rule.position = Vector2(-RESULT_RULE_W * 0.5, RESULT_TITLE_Y + 76.0)
	_result_rule.size = Vector2(RESULT_RULE_W, SCORE_RULE_HEIGHT)
	_result_rule.pivot_offset = Vector2(RESULT_RULE_W * 0.5, 0.0) # 从中心向两侧展开
	root.add_child(_result_rule)

	# 统计三组「得分 1230 · 关卡 3 · 用时 05:32」：**整行统一 28 号**——大小混排的层级
	# 试过两轮都被否（孤位大数字挖豁口/分数时长大关卡小=组间不齐），单尺寸从根上
	# 消灭大小差；数字满墨、汉字 0.75 档只靠明度分层。同一基线、整行水平居中，
	# 位置在 show_result 时按实际文本宽度现算。
	_result_groups = []
	for spec: Array in [["得分", "0"], ["关卡", "2"], ["用时", "00:00"]]:
		var segs: Array = []
		for i in 2:
			var label := Label.new()
			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", RESULT_TEXT_SIZE)
			label.add_theme_color_override("font_color",
					ink if i == 1 else Color(ink, 0.75))
			label.text = spec[i]
			root.add_child(label)
			segs.append(label)
		_result_groups.append(segs)

	_result_hint = Label.new()
	_result_hint.add_theme_font_override("font", font)
	_result_hint.add_theme_font_size_override("font_size", 24)
	_result_hint.add_theme_color_override("font_color", ink)
	_result_hint.text = "点击屏幕或按任意键重新开始"
	_result_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_hint.anchor_left = 0.5
	_result_hint.anchor_right = 0.5
	_result_hint.position = Vector2(-600.0, RESULT_HINT_Y)
	_result_hint.size = Vector2(1200.0, 32.0)
	root.add_child(_result_hint)
	hide_result()


## 结算建立（Main 在 GAME_OVER_DELAY 到点时调）：摆数据 → 播入场
## （标题下落淡入 → 横线自中心展开 → 统计四段左到右依次上浮 → 提示呼吸接管）。
func show_result(score: int, stage: int, play_time: float) -> void:
	_result_groups[0][0].text = "得分"
	_result_groups[0][1].text = str(score)
	_result_groups[1][0].text = "关卡"
	_result_groups[1][1].text = str(stage)
	_result_groups[2][0].text = "用时"
	_result_groups[2][1].text = format_time(play_time)
	_layout_result_units()
	for node: CanvasItem in [_result_title, _result_rule, _result_hint]:
		node.visible = true
	for segs: Array in _result_groups:
		for node: CanvasItem in segs:
			node.visible = true
	_play_result_intro()
	Sfx.play(&"ui_gameover")


## 统计三组（得分 1230 · 关卡 3 · 用时 05:32）同一基线水平居中：得分/用时数字 40 号
## 统计三组（得分 1230 · 关卡 3 · 用时 05:32）整行统一 28 号（数字满墨、汉字 0.75 档，
## 只靠明度分层），同一基线水平居中。组间距 64 > 段内 8：先分组成一张成绩单。
func _layout_result_units() -> void:
	var group_gap := 64.0
	var seg_gap := 8.0
	var font: Font = (_result_groups[0][0] as Label).get_theme_font(&"font")
	# 单字号下基线天然同线；仍走 ascent 计算定位（字号将来要调也只动常量）。
	var baseline_y := RESULT_TITLE_Y + 110.0 + font.get_ascent(RESULT_TEXT_SIZE)
	# 先摆一遍拿真实宽度（隐藏的 Label 尺寸照常随文本长）。
	var widths: Array[float] = []
	var total := 0.0
	for gi in _result_groups.size():
		var segs: Array = _result_groups[gi]
		var w := 0.0
		for si in segs.size():
			if si > 0:
				w += seg_gap
			w += (segs[si] as Label).size.x
		if gi > 0:
			w += group_gap
		widths.append(w)
		total += w
	var x := 1200.0 - total * 0.5
	for gi in _result_groups.size():
		var segs: Array = _result_groups[gi]
		if gi > 0:
			x += group_gap
		for si in segs.size():
			if si > 0:
				x += seg_gap
			var label: Label = segs[si]
			label.position = Vector2(x, baseline_y
					- font.get_ascent(label.get_theme_font_size(&"font_size")))
			x += label.size.x


## 结算入场：标题自上落位淡入 → 横线自中心展开 → 统计四段左到右依次上浮 → 提示淡入。
func _play_result_intro() -> void:
	if _result_tween != null:
		_result_tween.kill()
	_result_title.modulate.a = 0.0
	_result_title.position.y = RESULT_TITLE_Y - 14.0
	_result_rule.scale.x = 0.0
	_result_hint.modulate.a = 0.0
	for segs: Array in _result_groups:
		for node: Control in segs:
			node.modulate.a = 0.0
			node.position.y += 12.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_result_title, "modulate:a", 1.0, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_result_title, "position:y", RESULT_TITLE_Y, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_result_rule, "scale:x", 1.0, 0.45).set_delay(0.12) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for gi in _result_groups.size():
		var delay := 0.3 + 0.08 * gi
		for si in _result_groups[gi].size():
			var node: Control = _result_groups[gi][si]
			tw.tween_property(node, "modulate:a",
					0.75 if si == 0 else 1.0, 0.4).set_delay(delay) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(node, "position:y", node.position.y - 12.0, 0.4) \
					.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_result_hint, "modulate:a", 0.8, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_breathe_hint)
	_result_tween = tw


## 提示呼吸闪烁（与启动页同周期同下限，谷底起相——启动页同款语言）。
func _breathe_hint() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(_result_hint, "modulate:a", 0.36, BREATHE_PERIOD * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_result_hint, "modulate:a", 0.8, BREATHE_PERIOD * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_result_tween = tw


## 收掉结算面板（重开转场走 hide_for_title 一并清；本入口给显式复位用）。
func hide_result() -> void:
	if _result_tween != null:
		_result_tween.kill()
		_result_tween = null
	for node: CanvasItem in [_result_title, _result_rule, _result_hint]:
		node.visible = false
		node.modulate.a = 0.0
	for segs: Array in _result_groups:
		for node: CanvasItem in segs:
			node.visible = false
			node.modulate.a = 0.0


## 战斗 UI 整组（启动页藏起、进战斗点亮）。
func _combat_nodes() -> Array[CanvasItem]:
	var nodes: Array[CanvasItem] = [
		_score_label, _score_rule, _stage_label, _time_label, _time_rule, _help_label]
	return nodes


## 启动页待机：战斗 UI 全组藏起（Main 在标题路径调）。结算面板一并收掉。
func hide_for_title() -> void:
	_intro_played = false
	for node in _combat_nodes():
		node.visible = false
	hide_result()


## 重开直进战斗：不播启动动画，整组立即就位。
func show_combat_instant() -> void:
	_intro_played = true
	for node in _combat_nodes():
		node.visible = true
		node.modulate.a = 1.0
	_help_label.visible = _help_allowed
	_score_label.position.x = _score_home_x
	_score_rule.size = Vector2(SCORE_RULE_WIDTH, SCORE_RULE_HEIGHT)
	_stage_label.position.x = _stage_home_x
	_time_label.offset_left = _time_home_offsets.x
	_time_label.offset_right = _time_home_offsets.y
	_time_rule.scale.x = 1.0


## 进战斗启动动画：两角横线同拍展开（左线向右长、右线从右端向左长），得分/用时
## 各自从外侧滑入；关卡数半拍后从横线下滑出（每进一关重播=关卡亮相）；帮助文字收尾。
func play_intro() -> void:
	if _intro_played:
		return
	_intro_played = true
	for node in _combat_nodes():
		node.visible = true
	_help_label.visible = _help_allowed
	_prepare_intro_outro()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_score_label, "modulate:a", 1.0, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_score_label, "position:x", _score_home_x, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_score_rule, "size", Vector2(SCORE_RULE_WIDTH, SCORE_RULE_HEIGHT), 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_time_label, "modulate:a", 1.0, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_time_label, "offset_left", _time_home_offsets.x, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_time_label, "offset_right", _time_home_offsets.y, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_time_rule, "scale:x", 1.0, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stage_label, "modulate:a", 1.0, 0.35).set_delay(0.15) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stage_label, "position:x", _stage_home_x, 0.35).set_delay(0.15) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_help_label, "modulate:a", 1.0, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 退场起点=进场终态的反演（读数向外滑出淡掉、横线缩回起点），随后按此态退场。
func _prepare_intro_outro() -> void:
	_score_label.modulate.a = 0.0
	_score_label.position.x = _score_home_x - SCORE_SLIDE
	_score_rule.size = Vector2(0.0, SCORE_RULE_HEIGHT)
	_stage_label.modulate.a = 0.0
	_stage_label.position.x = _stage_home_x - SCORE_SLIDE
	_time_label.modulate.a = 0.0
	_time_label.offset_left = _time_home_offsets.x + SCORE_SLIDE
	_time_label.offset_right = _time_home_offsets.y + SCORE_SLIDE
	_time_rule.scale.x = 0.0
	_help_label.modulate.a = 0.0


## 阵亡退场（Main 在玩家死亡时调）：进场动画倒放——帮助先走，读数向外滑出淡掉，
## 两角横线缩回起点；BOSS 名条/血条/冲击条同拍淡出。0.6s 落定，正好盖住爆炸白闪。
## 信息将移入结算面板，顶栏不再重复。转场切章不调本入口（切章走 hide_for_title）。
func play_outro() -> void:
	_prepare_intro_outro()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_help_label, "modulate:a", 0.0, 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_score_label, "modulate:a", 0.0, 0.3).set_delay(0.08) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_score_label, "position:x", _score_home_x - SCORE_SLIDE, 0.3) \
			.set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_score_rule, "size", Vector2(0.0, SCORE_RULE_HEIGHT), 0.35) \
			.set_delay(0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_stage_label, "modulate:a", 0.0, 0.3).set_delay(0.08) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_stage_label, "position:x", _stage_home_x - SCORE_SLIDE, 0.3) \
			.set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_time_label, "modulate:a", 0.0, 0.3).set_delay(0.08) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_time_label, "offset_left", _time_home_offsets.x + SCORE_SLIDE, 0.3) \
			.set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_time_label, "offset_right", _time_home_offsets.y + SCORE_SLIDE, 0.3) \
			.set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_time_rule, "scale:x", 0.0, 0.35).set_delay(0.1) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for node: CanvasItem in [_boss_name, _boss_bar, _boss_impact_bar]:
		if node.visible:
			tw.tween_property(node, "modulate:a", 0.0, 0.3) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		for node in _combat_nodes():
			node.visible = false
		_boss_name.visible = false
		_boss_bar.visible = false
		_boss_impact_bar.visible = false
		_warning_label.visible = false)


func set_score(score: int) -> void:
	_score_label.text = "得分 %d" % score


func set_stage(stage: int) -> void:
	_stage_label.text = "关卡 %d" % stage


## 跑局用时（Main 逐帧喂累计秒数）：跳秒才刷新文本。
func set_play_time(seconds: float) -> void:
	var whole := floori(seconds)
	if whole == _shown_seconds:
		return
	_shown_seconds = whole
	_time_label.text = "用时 " + format_time(seconds)


## 正计时读数 mm:ss（分钟不封顶：一小时以上读作 75:12）。
static func format_time(seconds: float) -> String:
	var whole := floori(seconds)
	return "%02d:%02d" % [floori(whole / 60.0), whole % 60]


## 旧 GameOver VBox 已由顶部天空带结算取代（_build_result_ui/show_result）——
## 下方仅保留 tscn 遗留节点引用，不再写入。


## ---- BOSS 战 UI（Boss 按组调用） ----

## boss_name：机体名写进血条上方标签（§0b「单位名写在 BOSS 血条」的接线；
## 缺省=未登记，兜底旧调用不炸）。
func show_boss(boss_name: String = "未登记大型机") -> void:
	_boss_name.text = boss_name
	_boss_bar.reset() # 血条出生满格
	_boss_bar.visible = true
	_boss_impact_bar.reset(0.0) # 冲击条出生空格：满格虚影衰减会演出一段"逐渐变短"
	_boss_impact_bar.visible = true
	_boss_name.visible = true
	_boss_name.modulate.a = 1.0 # 阵亡退场后残留敌弹打死杂兵拉出新 BOSS 的兜底：
	_boss_bar.modulate.a = 1.0  # play_outro 淡过这仨，show_boss 得把不透明度抬回来。
	_boss_impact_bar.modulate.a = 1.0


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
