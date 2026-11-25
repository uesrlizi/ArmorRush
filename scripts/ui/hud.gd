class_name HUD
extends CanvasLayer
## 得分/关卡数/用时/倍率、操作提示、游戏结束面板。
## 血条/气槽已移到角色头顶（scripts/overhead_bar.gd），左上角不再有。
## 顶栏两角对称收边：左上「用时 mm:ss → 横线 → 关卡 N」竖排一列，右上「得分 → 横线
## → 倍率 ×N」镜像——得分与倍率同侧（倍率是计分乘数，读数挨着读，2026-11-08 用户定；
## run_loop.md §2，倍率关时不建）；
## BOSS 血条居中，共用顶带。
## 启动页待机时战斗 UI 整组藏起，进战斗按"横线展开 → 得分/用时滑入 → 关卡数
## 半拍跟进 → 帮助跟进"的次序点亮（系统启动感；每进一关重播=关卡数亮相）。
## 操作提示按输入设备分文案（手柄/键鼠，热插拔即切；
## 移动端不显示——触控按钮自明）。重开输入由 TouchControls 统一接管
## （任意键/点屏，结算画面），本层不再监听。

const SCORE_RULE_WIDTH := 220.0  # 两角横线（用时/得分下各一条）的展开终宽
const SCORE_RULE_HEIGHT := 3.0
const STAGE_FONT_SIZE := 24      # 关卡数/倍率比顶行读数(30)低一档：挂横线下当副标题
const RIGHT_LABEL_WIDTH := 400.0 # 右上组标签框宽（右锚右对齐：得分/倍率，只需容得下最长读数）
const SCORE_SLIDE := 18.0        # 顶栏读数（用时/得分/关卡/倍率）的滑入滑出量（px）

# 拾取栏（run_loop.md §4，LOOT_ENABLED 才建）：开局空、捡到一个加一枚成员色图标，
# 新关按持有表重摆（装备跨关携带）。攒满 6 枚 = 6×30+5×4 = 200，与得分横线 220 同量级。
const LOADOUT_ICON := 30.0       # 图标边长
const LOADOUT_ITEM_GAP := 4.0    # 图标间距
const LOADOUT_TOP := 48.0        # 关卡数顶 → 图标顶（关卡 24 号字高 ~35 + 留白 13）
const NOTICE_GAP := 10.0         # 图标底 → 播报行顶
const LOOT_FLY_TIME := 0.5       # 图标从机体飞到拾取栏（先升后横的弧线，缓入缓出）
const LOOT_FLY_SCALE := 0.6      # 飞行图标的起始缩放（落位回弹到 1.0）
const NOTICE_HOLD := 2.6         # 播报行停留（用户反馈「显示文字之后太快到下一关」）
const NOTICE_FADE := 0.3         # 播报行淡出时长
const NOTICE_SEG_GAP := 8.0      # 播报行名字与效果半句的间距

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

var _score_home_offsets := Vector2.ZERO # 得分标签右锚偏移(左, 右)：滑入按偏移走，不依赖布局时机
var _intro_played := false
var _help_allowed := true # 移动端不显示操作提示（触控按钮自明）
var _stage_label: Label
var _stage_home_x := 0.0
var _time_label: Label
var _time_home_x := 0.0
var _time_rule: ColorRect
var _mult_label: Label               # 倍率档位读数（疾驰倍率，run_loop.md §2；倍率关=空文本不亮）
var _mult_home_offsets := Vector2.ZERO # 倍率标签右锚偏移(左, 右)：滑入按偏移走，同得分标签
var _shown_mult := 0                 # 倍率标签当前显示档（跳变才重绘；涨档闪一下提注意）
var _mult_pop_tween: Tween
var _shown_seconds := -1 # 用时标签当前显示的整秒（跳秒才刷新文本）
var _result_title: Label       # 结算面板（顶部天空带，程序化搭，见 _build_result_ui）
var _result_rule: ColorRect
var _result_groups: Array = [] # 统计组：[组= [字Label, 数Label]]，统一字号只靠明度分层
var _loot_group: Array = [] # 拾取清单预备组（§4）：show_result 时有拾取才入列 _result_groups
var _loadout: Control            # 拾取栏（整组进退场走容器；LOOT_ENABLED 关=不建）
var _loadout_home_x := 0.0
var _loadout_row: Array[TextureRect] = []      # 栏内图标，按入栏先后从左到右
var _loadout_members: Array[StringName] = []   # 与 _loadout_row 一一对应的成员 id
var _notice: Control             # 拾取播报行（成员名满墨 + 效果 0.75 墨）
var _notice_home_x := 0.0
var _notice_name: Label
var _notice_desc: Label
var _notice_tween: Tween
var _fly: TextureRect            # 正在飞入槽位的图标（同一时刻至多一枚）
var _fly_tween: Tween
var _result_hint: Label
var _result_tween: Tween
var _boss_bar: BossBar
var _boss_impact_bar: BossBar
var _boss_name: Label
var _boss_shown := false # BOSS 在场记账：录制隐藏档回落时按它还原名条/血条显隐
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
	if BalanceGlobal.LOOT_ENABLED:
		_build_loadout(font)
	_game_over.visible = false
	hide_result()
	if Platforms.is_mobile():
		_help_allowed = false
		_help_label.visible = false
	else:
		_apply_help_text()
		# 手柄热插拔即切提示文案。
		Input.joy_connection_changed.connect(
				func(_device: int, _connected: bool) -> void: _apply_help_text())
	_apply_ui_tier() # 录制隐藏档跨章/跨局延续：新场景落地即沿用（RunState.ui_tier）


## 录制隐藏档（F1/F2 两档；状态正本与档位语义见 RunState.ui_tier）：
## F1=隐顶栏信息 HUD+结算面板，语音播报（含字幕文字）一并停；
## F2=在 1 的基础上连头顶血条/BOSS 血条/WARNING 全隐=画面完全无 UI。
## 再按同键回落：F1 在 0↔1 间切换，F2 在 0↔2 间切换（档 2 按 F1 退到档 1）。
## 注意：结算画面的"任意键重开"监听在 TouchControls——按 F1/F2 也会触发重开，
## 档位经 RunState 延续到新场景，录制不受影响。
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var tier := RunState.ui_tier
	if event.keycode == KEY_F1:
		tier = 1 if tier != 1 else 0
	elif event.keycode == KEY_F2:
		tier = 2 if tier != 2 else 0
	else:
		return
	RunState.ui_tier = tier
	get_viewport().set_input_as_handled()
	_apply_ui_tier()


## 把当前档位落到本场景全部 UI（HUD._ready 与每次按键都调）。
func _apply_ui_tier() -> void:
	var tier := RunState.ui_tier
	# 档 1：顶栏信息整组+结算面板全藏；档 0 按战斗态还原（启动页待机本就该藏）。
	if tier >= 1:
		for node in _combat_nodes():
			node.visible = false
		hide_result()
		_cancel_loot_fx() # 拾取播报/飞入图标属信息 UI，同档藏（装备记账照走）
	elif _intro_played:
		show_combat_instant()
	# 档 2：BOSS 名条/血条/冲击条一并藏；档 0/1 按 BOSS 在场还原。
	_set_boss_ui_visible(_boss_shown and tier < 2)
	if tier >= 2 and _warning_tween != null:
		_warning_tween.kill()
		_warning_label.visible = false
	Comms.set_muted(tier >= 1)


## BOSS 名条/血条/冲击条三件套统一显隐（含不透明度复位：阵亡退场淡过后
## 再拉出新 BOSS 的兜底，原 show_boss 手写三行收拢于此）。
func _set_boss_ui_visible(v: bool) -> void:
	for node: CanvasItem in [_boss_name, _boss_bar, _boss_impact_bar]:
		node.visible = v
		node.modulate.a = 1.0


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


## 跑局信息顶栏（同 BOSS UI 程序化搭，免改 8 个关卡场景）：左上「用时 → 横线 → 关卡」，
## 右上「得分 → 横线 → 倍率」——得分与倍率同侧（倍率是计分乘数，读数挨着读）。
## 各章 tscn 里的 ScoreLabel/ScoreRule 摆在左上，是顶栏的字号/字色/线色/边距模板（各章
## 按天色配过深浅，单一来源）：用时组照模板原位新建；得分组改右锚，按同一边距镜像到
## 右上角（右对齐）。关卡数挂左横线下 10px、倍率挂右横线下 10px。ui_cjk 的数字是等宽
## 字形，跳秒不抖。
func _build_run_info(font: Font) -> void:
	var root: Control = $Root
	var ink := _score_label.get_theme_color("font_color")
	var label_pos := _score_label.position # 模板摆位（tscn 左上）：两角组共用的边距/字框
	var label_size := _score_label.size
	var rule_pos := _score_rule.position

	# 左上：用时 → 横线（横线展开从左端长出：pivot 默认原点）→ 关卡。
	_time_label = Label.new()
	_time_label.add_theme_font_override("font", font)
	_time_label.add_theme_font_size_override("font_size",
			_score_label.get_theme_font_size("font_size"))
	_time_label.add_theme_color_override("font_color", ink)
	_time_label.position = label_pos
	_time_label.size = label_size
	root.add_child(_time_label)
	_time_home_x = label_pos.x

	_time_rule = ColorRect.new()
	_time_rule.color = _score_rule.color
	_time_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_rule.position = rule_pos
	_time_rule.size = Vector2(SCORE_RULE_WIDTH, SCORE_RULE_HEIGHT)
	root.add_child(_time_rule)

	_stage_label = Label.new()
	_stage_label.add_theme_font_override("font", font)
	_stage_label.add_theme_font_size_override("font_size", STAGE_FONT_SIZE)
	_stage_label.add_theme_color_override("font_color", Color(ink, 0.85))
	_stage_label.position = Vector2(rule_pos.x, rule_pos.y + 10.0)
	root.add_child(_stage_label)
	_stage_home_x = _stage_label.position.x

	# 右上：得分 → 横线（横线展开从右端长出）。tscn 节点已在树里：先改锚、再显式写
	# 左右偏移（改锚时引擎按旧视觉位置重算偏移，随即整组覆盖）；上下偏移沿用模板。
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.anchor_left = 1.0
	_score_label.anchor_right = 1.0
	_score_label.offset_left = -RIGHT_LABEL_WIDTH - label_pos.x
	_score_label.offset_right = -label_pos.x
	_score_home_offsets = Vector2(_score_label.offset_left, _score_label.offset_right)
	_score_rule.anchor_left = 1.0
	_score_rule.anchor_right = 1.0
	_score_rule.offset_left = -SCORE_RULE_WIDTH - rule_pos.x
	_score_rule.offset_right = -rule_pos.x
	_score_rule.pivot_offset = Vector2(SCORE_RULE_WIDTH, 0.0)

	# 倍率读数挂在得分横线下（右上组第二行，与左上「关卡」对称）。倍率关=空文本
	# 照常进战斗 UI 组藏亮（省得各处判空），文本只有 set_mult（开）才写。
	# 右锚控件：先设位置/尺寸再入树（入树前父区=0，偏移=给定值，同 BOSS UI 惯例）。
	_mult_label = Label.new()
	_mult_label.add_theme_font_override("font", font)
	_mult_label.add_theme_font_size_override("font_size", STAGE_FONT_SIZE)
	_mult_label.add_theme_color_override("font_color", Color(ink, 0.85))
	_mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mult_label.anchor_left = 1.0
	_mult_label.anchor_right = 1.0
	_mult_label.position = Vector2(-RIGHT_LABEL_WIDTH - label_pos.x, rule_pos.y + 10.0)
	_mult_label.size = Vector2(RIGHT_LABEL_WIDTH, _stage_label.size.y)
	_mult_home_offsets = Vector2(_mult_label.offset_left, _mult_label.offset_right)
	root.add_child(_mult_label)

	_build_loadout(font)
	_build_result_ui(font)


## 结算面板（顶部天空带，程序化搭同 BOSS UI；免改 7 个关卡场景）。
## 构图（mock 七章验证过）：居中标题 → 短横线 → 统计组（得分/关卡/用时/受击/倍率，统一
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

	# 统计组「得分 1230 · 关卡 3 · 用时 05:32 · 受击 2 · 最高倍率 ×3.0」：**整行统一 28 号**
	# ——大小混排的层级试过两轮都被否（孤位大数字挖豁口/分数时长大关卡小=组间不齐），
	# 单尺寸从根上消灭大小差；数字满墨、汉字 0.75 档只靠明度分层。同一基线、整行水平
	# 居中，位置在 show_result 时按实际文本宽度现算。后两组=疾驰倍率的局级回执
	# （run_loop.md §2；反制数待后续进组），倍率关不建（旧制三组）。
	# 拾取清单（run_loop.md §4 结算回执）另建一组预备着：装备可能在本关中途才捡到，
	# 建 UI 时还不知道有没有——show_result 时一件没捡就不入列（不占位不留空组）。
	_result_groups = []
	var specs: Array = [["得分", "0"], ["关卡", "2"], ["用时", "00:00"]]
	if BalanceGlobal.MULT_ENABLED:
		specs.append_array([["受击", "0"], ["最高倍率", "×1.0"]])
	if BalanceGlobal.LOOT_ENABLED:
		specs.append(["拾取", ""])
	for spec: Array in specs:
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
	if BalanceGlobal.LOOT_ENABLED:
		_loot_group = _result_groups.pop_back() # 预备组：不常驻列，show_result 按需入列

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
## （标题下落淡入 → 横线自中心展开 → 统计组左到右依次上浮），返回入场
## 动画时长——重开提示不随入场出，由 Main 开闸时调 show_restart_hint 同拍点亮
## （看见提示=能按，防误触）。progress=RunState.progress_parts()（[标签, 读数]，
## 「关卡 4/5」/「最终战 2/3」）。hits/mult_max=疾驰倍率局级回执（受击数/最高档
## 乘数=查 BalanceGlobal.MULT_VALUES，run_loop.md §2；倍率关不展示，传什么都行）。
## cleared=true 为通关结算（RUSH 阵容打空，run_loop.md §1）：换标题，不拍
## gameover 音（暂无通关音，宁缺毋滥）。loot=本局拾取清单（RunState.loot_labels()，
## run_loop.md §4 结算回执；空串=一件没捡，不建组）。反制数待后续进组。
## 录制隐藏档 1 起整面板不建（信息 UI，F1 档即隐），返回 0。
func show_result(score: int, progress: PackedStringArray, play_time: float,
		cleared := false, hits := 0, mult_max := 1, loot := "") -> float:
	if RunState.ui_tier >= 1:
		return 0.0
	_result_title.text = "作战完成" if cleared else "游戏结束"
	# 通关标题不吃 GameOver 的死亡红：换本章墨色（横线/统计同款，第一眼读法=
	# 完成，不是又一场失败；死亡路径照旧走各章结算标题色）。
	var ink := _score_label.get_theme_color("font_color")
	var title_rgb := (_game_over.get_node("GameOverTitle") as Label).get_theme_color("font_color")
	_result_title.add_theme_color_override("font_color", ink if cleared else title_rgb)
	_result_groups[0][0].text = "得分"
	_result_groups[0][1].text = str(score)
	_result_groups[1][0].text = progress[0]
	_result_groups[1][1].text = progress[1]
	_result_groups[2][0].text = "用时"
	_result_groups[2][1].text = format_time(play_time)
	if BalanceGlobal.MULT_ENABLED:
		_result_groups[3][1].text = str(hits)
		_result_groups[4][1].text = "×%.1f" % BalanceGlobal.MULT_VALUES[mult_max - 1]
	_result_groups.erase(_loot_group) # 拾取组按本局实况入列（重复调用不叠组）
	if not loot.is_empty() and not _loot_group.is_empty():
		_loot_group[1].text = loot
		_result_groups.append(_loot_group)
	_layout_result_units()
	for node: CanvasItem in [_result_title, _result_rule, _result_hint]:
		node.visible = true
	for segs: Array in _result_groups:
		for node: CanvasItem in segs:
			node.visible = true
	_play_result_intro()
	if not cleared:
		Sfx.play(&"ui_gameover")
	return _result_intro_time()


## 结算入场动画总长（末组统计浮齐）：重开闸从这之后才开（Main 拿返回值锁闸）。
## 组数随倍率开关变（旧制三组=0.86s / 带受击+最高倍率五组=1.02s），与
## _play_result_intro 的时序公式对账（末组 delay 0.3+0.08×(n−1) + 0.4）。
func _result_intro_time() -> float:
	return 0.3 + 0.08 * (_result_groups.size() - 1) + 0.4


## 统计组（得分 1230 · 关卡 3 · 用时 05:32 · 受击 2 · 最高倍率 ×3.0）整行统一 28 号
## （数字满墨、汉字 0.75 档，只靠明度分层），同一基线水平居中。
## 组间距 64 > 段内 8：先分组成一张成绩单。
func _layout_result_units() -> void:
	var group_gap := 64.0
	var seg_gap := 8.0
	var font: Font = (_result_groups[0][0] as Label).get_theme_font(&"font")
	# 单字号下基线天然同线；仍走 ascent 计算定位（字号将来要调也只动常量）。
	var baseline_y := RESULT_TITLE_Y + 110.0 + font.get_ascent(RESULT_TEXT_SIZE)
	# 先摆一遍拿真实宽度：Label 换文本后尺寸是延迟跟随的（同帧读 size 仍是旧文本宽——
	# 拾取组建 UI 时是空串，不先归位就按 0 宽排，整行被推偏半个清单宽），量前先
	# reset_size 把尺寸收回到当前文本的最小尺寸。
	var widths: Array[float] = []
	var total := 0.0
	for gi in _result_groups.size():
		var segs: Array = _result_groups[gi]
		var w := 0.0
		for si in segs.size():
			if si > 0:
				w += seg_gap
			(segs[si] as Label).reset_size()
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


## 结算入场：标题自上落位淡入 → 横线自中心展开 → 统计组左到右依次上浮。
## 总时长须与 _result_intro_time 对账（末组 delay 0.3+0.08×(n−1) + 0.4）。
## 重开提示不在这里出：留到开闸（show_restart_hint）。
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
	_result_tween = tw


## 重开开闸同拍（Main 调）：提示淡入后转呼吸——提示亮起=此刻起按键才算数。
## 面板没建（录制隐藏档）时空转。
func show_restart_hint() -> void:
	if not _result_hint.visible:
		return
	if _result_tween != null:
		_result_tween.kill()
	var tw := create_tween()
	tw.tween_property(_result_hint, "modulate:a", 0.8, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_breathe_hint)
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
	for segs: Array in _result_groups + [_loot_group]:
		for node: CanvasItem in segs:
			node.visible = false
			node.modulate.a = 0.0


## 战斗 UI 整组（启动页藏起、进战斗点亮）。
func _combat_nodes() -> Array[CanvasItem]:
	var nodes: Array[CanvasItem] = [
		_score_label, _score_rule, _stage_label, _time_label, _time_rule,
		_mult_label, _help_label]
	if _loadout != null:
		nodes.append(_loadout)
		nodes.append(_notice)
	return nodes


## 启动页待机：战斗 UI 全组藏起（Main 在标题路径调）。结算面板一并收掉。
func hide_for_title() -> void:
	_intro_played = false
	for node in _combat_nodes():
		node.visible = false
	hide_result()


## 重开直进战斗：不播启动动画，整组立即就位（档 1 起整组不亮，回落档 0 走这里还原）。
func show_combat_instant() -> void:
	_intro_played = true
	if RunState.ui_tier >= 1:
		return
	for node in _combat_nodes():
		node.visible = true
		node.modulate.a = 1.0
	_help_label.visible = _help_allowed
	_time_label.position.x = _time_home_x
	_time_rule.size = Vector2(SCORE_RULE_WIDTH, SCORE_RULE_HEIGHT)
	_stage_label.position.x = _stage_home_x
	_score_label.offset_left = _score_home_offsets.x
	_score_label.offset_right = _score_home_offsets.y
	_score_rule.scale.x = 1.0
	_mult_label.offset_left = _mult_home_offsets.x
	_mult_label.offset_right = _mult_home_offsets.y


## 进战斗启动动画：两角横线同拍展开（左线向右长、右线从右端向左长），用时/得分
## 各自从外侧滑入；关卡数/倍率半拍后从横线下滑出（每进一关重播=关卡亮相）；帮助文字收尾。
func play_intro() -> void:
	if _intro_played:
		return
	_intro_played = true
	if RunState.ui_tier >= 1: # 录制隐藏档：启动动画不播，回落档 0 走 show_combat_instant 还原
		return
	for node in _combat_nodes():
		node.visible = true
	_help_label.visible = _help_allowed
	_prepare_intro_outro()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_time_label, "modulate:a", 1.0, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_time_label, "position:x", _time_home_x, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_time_rule, "size", Vector2(SCORE_RULE_WIDTH, SCORE_RULE_HEIGHT), 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_score_label, "modulate:a", 1.0, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_score_label, "offset_left", _score_home_offsets.x, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_score_label, "offset_right", _score_home_offsets.y, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_score_rule, "scale:x", 1.0, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mult_label, "modulate:a", 1.0, 0.35).set_delay(0.15) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mult_label, "offset_left", _mult_home_offsets.x, 0.35).set_delay(0.15) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mult_label, "offset_right", _mult_home_offsets.y, 0.35).set_delay(0.15) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stage_label, "modulate:a", 1.0, 0.35).set_delay(0.15) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stage_label, "position:x", _stage_home_x, 0.35).set_delay(0.15) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _loadout != null:
		tw.tween_property(_loadout, "modulate:a", 1.0, 0.35).set_delay(0.2) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_loadout, "position:x", _loadout_home_x, 0.35).set_delay(0.2) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_help_label, "modulate:a", 1.0, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 退场起点=进场终态的反演（读数向外滑出淡掉、横线缩回起点），随后按此态退场。
func _prepare_intro_outro() -> void:
	_time_label.modulate.a = 0.0
	_time_label.position.x = _time_home_x - SCORE_SLIDE
	_time_rule.size = Vector2(0.0, SCORE_RULE_HEIGHT)
	_stage_label.modulate.a = 0.0
	_stage_label.position.x = _stage_home_x - SCORE_SLIDE
	_score_label.modulate.a = 0.0
	_score_label.offset_left = _score_home_offsets.x + SCORE_SLIDE
	_score_label.offset_right = _score_home_offsets.y + SCORE_SLIDE
	_score_rule.scale.x = 0.0
	_mult_label.modulate.a = 0.0
	_mult_label.offset_left = _mult_home_offsets.x + SCORE_SLIDE
	_mult_label.offset_right = _mult_home_offsets.y + SCORE_SLIDE
	_help_label.modulate.a = 0.0
	if _loadout != null:
		_loadout.modulate.a = 0.0
		_loadout.position.x = _loadout_home_x - SCORE_SLIDE
	if _notice != null:
		_notice.modulate.a = 0.0
		_notice.position.x = _notice_home_x - SCORE_SLIDE


## 阵亡退场（Main 在玩家死亡时调）：进场动画倒放——帮助先走，读数向外滑出淡掉，
## 两角横线缩回起点；BOSS 名条/血条/冲击条同拍淡出。0.6s 落定，正好盖住爆炸白闪。
## 信息将移入结算面板，顶栏不再重复。转场切章不调本入口（切章走 hide_for_title）。
func play_outro() -> void:
	_prepare_intro_outro()
	if _loadout != null:
		_cancel_fly() # 飞行中的图标直接落位（不在退场里继续飞）
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_help_label, "modulate:a", 0.0, 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_time_label, "modulate:a", 0.0, 0.3).set_delay(0.08) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_time_label, "position:x", _time_home_x - SCORE_SLIDE, 0.3) \
			.set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_time_rule, "size", Vector2(0.0, SCORE_RULE_HEIGHT), 0.35) \
			.set_delay(0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_stage_label, "modulate:a", 0.0, 0.3).set_delay(0.08) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_stage_label, "position:x", _stage_home_x - SCORE_SLIDE, 0.3) \
			.set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_score_label, "modulate:a", 0.0, 0.3).set_delay(0.08) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_score_label, "offset_left", _score_home_offsets.x + SCORE_SLIDE, 0.3) \
			.set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_score_label, "offset_right", _score_home_offsets.y + SCORE_SLIDE, 0.3) \
			.set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_mult_label, "modulate:a", 0.0, 0.3).set_delay(0.08) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_mult_label, "offset_left", _mult_home_offsets.x + SCORE_SLIDE, 0.3) \
			.set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_mult_label, "offset_right", _mult_home_offsets.y + SCORE_SLIDE, 0.3) \
			.set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_score_rule, "scale:x", 0.0, 0.35).set_delay(0.1) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if _loadout != null:
		tw.tween_property(_loadout, "modulate:a", 0.0, 0.3).set_delay(0.08) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(_loadout, "position:x", _loadout_home_x - SCORE_SLIDE, 0.3) \
				.set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if _notice.visible:
			if _notice_tween != null:
				_notice_tween.kill()
			tw.tween_property(_notice, "modulate:a", 0.0, 0.25) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for node: CanvasItem in [_boss_name, _boss_bar, _boss_impact_bar]:
		if node.visible:
			tw.tween_property(node, "modulate:a", 0.0, 0.3) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		for node in _combat_nodes():
			node.visible = false
		_boss_shown = false
		_set_boss_ui_visible(false)
		_warning_label.visible = false)


func set_score(score: int) -> void:
	_score_label.text = "得分 %d" % score


## 进度读数（RunState.progress_parts 拼好的「关卡 4/5」/「最终战 1/3」）。
func set_progress(text: String) -> void:
	_stage_label.text = text


## 跑局用时（Main 逐帧喂累计秒数）：跳秒才刷新文本。
func set_play_time(seconds: float) -> void:
	var whole := floori(seconds)
	if whole == _shown_seconds:
		return
	_shown_seconds = whole
	_time_label.text = "用时 " + format_time(seconds)


## 倍率读数（Main 每帧喂 RunState.multiplier() 档位，跳档才动文本；显示值=该档
## 计分乘数，查 BalanceGlobal.MULT_VALUES）。涨档闪一下提注意——档位=刷怪密度档，
## 「怪变凶的因」在这里可见；掉档是负反馈不庆祝，安静回落。倍率关/Main 没喂过=
## 不亮（空文本）。开场首喂（0→1）不算涨档。
func set_mult(tier: int) -> void:
	if not BalanceGlobal.MULT_ENABLED or tier == _shown_mult:
		return
	var rose := tier > _shown_mult and _shown_mult > 0
	_shown_mult = tier
	_mult_label.text = "倍率 ×%.1f" % BalanceGlobal.MULT_VALUES[tier - 1]
	if rose and _mult_label.visible:
		if _mult_pop_tween != null:
			_mult_pop_tween.kill()
		_mult_label.modulate.a = 0.3
		_mult_pop_tween = create_tween()
		_mult_pop_tween.tween_property(_mult_label, "modulate:a", 1.0, 0.3) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 正计时读数 mm:ss（分钟不封顶：一小时以上读作 75:12）。
static func format_time(seconds: float) -> String:
	var whole := floori(seconds)
	return "%02d:%02d" % [floori(whole / 60.0), whole % 60]


## ---- 轻肉鸽装备 UI（run_loop.md §4；LOOT_ENABLED 才建） ----

## 拾取栏（HUD 左上「关卡」下，常驻）：开局空、捡到一个加一枚成员色图标；新关落地
## 按持有表摆出（装备跨关携带）。回答「装到身上看不出来」（装甲/推进/枪成员的机体
## 通道太细，栏是常驻的总账）。播报行挂在栏下滑出，同平涂语言（名满墨/效果 0.75 墨）。
func _build_loadout(font: Font) -> void:
	var root: Control = $Root
	_loadout = Control.new()
	_loadout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loadout.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS # 96 画布缩到 30：三线性
	_loadout.position = Vector2(_stage_label.position.x, _stage_label.position.y + LOADOUT_TOP)
	root.add_child(_loadout)
	_loadout_home_x = _loadout.position.x

	_notice = Control.new()
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.position = Vector2(_loadout.position.x, _loadout.position.y + LOADOUT_ICON + NOTICE_GAP)
	root.add_child(_notice)
	_notice_home_x = _notice.position.x
	for i in 2:
		var label := Label.new()
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", STAGE_FONT_SIZE)
		label.add_theme_color_override("font_color",
				_score_label.get_theme_color("font_color") if i == 0
				else Color(_score_label.get_theme_color("font_color"), 0.75))
		_notice.add_child(label)
		if i == 0:
			_notice_name = label
		else:
			_notice_desc = label
	_notice.visible = false
	rebuild_loadout() # 新关落地按持有表摆出（装备跨关携带）


## 栏内/飞行图标件（TextureRect 居中保比例，缩放绕中心）+ 同形黑影硬投影
## （BalanceGlobal.LOOT_ICON_SHADOW_ALPHA：成员色直显后浅色成员在亮天章被天色吃掉
## ——不是底板也不是描边，同形黑影右下错开 2px、show_behind_parent 垫在本体下）。
func _make_loot_icon(tex: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(LOADOUT_ICON, LOADOUT_ICON)
	icon.pivot_offset = icon.size * 0.5
	if BalanceGlobal.LOOT_ICON_SHADOW_ALPHA > 0.0:
		var shadow := TextureRect.new()
		shadow.texture = tex
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow.size = icon.size
		shadow.position = Vector2(2, 2)
		shadow.modulate = Color(0, 0, 0, BalanceGlobal.LOOT_ICON_SHADOW_ALPHA)
		shadow.show_behind_parent = true
		icon.add_child(shadow)
	return icon


## 队尾第 index 枚图标在拾取栏里的左上角位置（栏容器局部坐标）。
func _loadout_slot_pos(index: int) -> Vector2:
	return Vector2(index * (LOADOUT_ICON + LOADOUT_ITEM_GAP), 0.0)


## 按持有表重摆（新关落地/退场重进；槽位序、成员色，不画空槽）。
func rebuild_loadout() -> void:
	if _loadout == null:
		return
	for icon in _loadout_row:
		icon.queue_free()
	_loadout_row.clear()
	_loadout_members.clear()
	for slot: StringName in BalanceMods.SLOTS:
		var member := RunState.mod_member(slot)
		if not member.is_empty():
			_append_loadout_icon(member)


## 队尾加一枚成员色图标；pop=落位一拍（放大回弹）。
func _append_loadout_icon(member: StringName, pop := false) -> void:
	var icon := _make_loot_icon(LootIcons.glyph_of(member))
	icon.modulate = BalanceMods.MEMBERS[member]["tint"]
	icon.position = _loadout_slot_pos(_loadout_row.size())
	_loadout.add_child(icon)
	_loadout_row.append(icon)
	_loadout_members.append(member)
	if pop:
		icon.scale = Vector2.ONE * 1.45
		create_tween().tween_property(icon, "scale", Vector2.ONE, 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 拾取播报（LootPickup 授予时调；装备已入表）：同一枚图标以成员色从机体屏幕位
## 起飞，先升后横弧线落到拾取栏队尾（0.5s），落位回弹一拍；起飞同时栏下滑出
## 「成员名 效果」停留后淡出。from=机体在视口里的位置（get_global_transform_with_canvas）。
## 录制隐藏档 1 起/栏未亮=只记账不演（回落档 0 或新关由 rebuild_loadout 摆出）。
func announce_loot(member: StringName, from: Vector2) -> void:
	if _loadout == null:
		return
	if RunState.ui_tier >= 1 or not _loadout.visible:
		rebuild_loadout()
		return
	_cancel_fly()
	var fly := _make_loot_icon(LootIcons.glyph_of(member))
	fly.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	fly.modulate = BalanceMods.MEMBERS[member]["tint"]
	($Root as Control).add_child(fly)
	_fly = fly
	var p0 := from - fly.size * 0.5 + Vector2(0.0, -24.0) # 从躯干起飞
	var p2 := _loadout.position + _loadout_slot_pos(_loadout_row.size())
	var p1 := Vector2(p0.x, p2.y) # 控制点=先升后横（出机体向上抬，再扫进左上角）
	fly.position = p0
	fly.scale = Vector2.ONE * LOOT_FLY_SCALE
	_fly_tween = create_tween()
	_fly_tween.tween_method(func(t: float) -> void:
		var u := 1.0 - t
		fly.position = p0 * (u * u) + p1 * (2.0 * u * t) + p2 * (t * t)
		fly.scale = Vector2.ONE * lerpf(LOOT_FLY_SCALE, 1.0, t),
		0.0, 1.0, LOOT_FLY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_fly_tween.tween_callback(_dock_loot.bind(member))
	_show_notice(member)


## 落位：飞行图标收起，队尾加一枚同色图标并回弹一拍。
func _dock_loot(member: StringName) -> void:
	if _fly != null:
		_fly.queue_free()
		_fly = null
	_fly_tween = null
	_append_loadout_icon(member, true)


## 播报行「成员名 效果」：同顶栏读数的滑入语言（左侧滑入 18px+淡入），停 NOTICE_HOLD
## 后淡出；名字满墨、效果 0.75 墨（同结算统计行的明度分层）。
func _show_notice(member: StringName) -> void:
	var info: Dictionary = BalanceMods.MEMBERS[member]
	_notice_name.text = info["label"]
	_notice_desc.text = info.get("desc", "")
	_notice_name.reset_size() # Label 换文本后尺寸延迟跟随：量宽前先收回（结算拾取组同坑）
	_notice_desc.reset_size()
	_notice_desc.position.x = _notice_name.size.x + NOTICE_SEG_GAP
	if _notice_tween != null:
		_notice_tween.kill()
	_notice.visible = true
	_notice.modulate.a = 0.0
	_notice.position.x = _notice_home_x - SCORE_SLIDE
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_notice, "modulate:a", 1.0, 0.35).set_delay(0.12) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_notice, "position:x", _notice_home_x, 0.35).set_delay(0.12) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_notice, "modulate:a", 0.0, NOTICE_FADE).set_delay(NOTICE_HOLD) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void: _notice.visible = false)
	_notice_tween = tw


## 飞行中的图标收掉并按持有表重摆（新播报顶替/退场/隐藏档切换时调）——授予已入表，
## 重摆=这枚直接落位，不会丢。
func _cancel_fly() -> void:
	if _fly_tween != null:
		_fly_tween.kill()
		_fly_tween = null
	if _fly != null:
		_fly.queue_free()
		_fly = null
		rebuild_loadout()


## 拾取演出整体收掉（标题页/录制隐藏档）：飞行图标直接落位、播报行立即藏。
func _cancel_loot_fx() -> void:
	if _loadout == null:
		return
	_cancel_fly()
	if _notice_tween != null:
		_notice_tween.kill()
		_notice_tween = null
	_notice.visible = false


## 旧 GameOver VBox 已由顶部天空带结算取代（_build_result_ui/show_result）——
## 下方仅保留 tscn 遗留节点引用，不再写入。


## ---- BOSS 战 UI（Boss 按组调用） ----

## boss_name：机体名写进血条上方标签（§0b「单位名写在 BOSS 血条」的接线；
## 缺省=未登记，兜底旧调用不炸）。录制隐藏档 2 起三件套不亮（记账照走，
## 回落档 0/1 按 _boss_shown 还原）。
func show_boss(boss_name: String = "未登记大型机") -> void:
	_boss_name.text = boss_name
	_boss_bar.reset() # 血条出生满格
	_boss_impact_bar.reset(0.0) # 冲击条出生空格：满格虚影衰减会演出一段"逐渐变短"
	_boss_shown = true
	_set_boss_ui_visible(RunState.ui_tier < 2)


func set_boss_hp(ratio: float) -> void:
	_boss_bar.set_ratio(ratio)


func set_boss_impact(ratio: float) -> void:
	_boss_impact_bar.set_ratio(ratio)


func hide_boss() -> void:
	_boss_shown = false
	_set_boss_ui_visible(false)


## WARNING 大字闪两轮（AC6 式遭遇警报），结束自隐；重复调用重启闪烁。
## 录制隐藏档 2 起不闪（F2=完全无 UI）。
func flash_warning() -> void:
	if RunState.ui_tier >= 2:
		return
	if _warning_tween != null:
		_warning_tween.kill()
	_warning_label.visible = true
	_warning_label.modulate.a = 1.0
	_warning_tween = create_tween()
	for i in 4:
		_warning_tween.tween_property(_warning_label, "modulate:a", 0.1, 0.22)
		_warning_tween.tween_property(_warning_label, "modulate:a", 1.0, 0.22)
	_warning_tween.tween_callback(func() -> void: _warning_label.visible = false)
