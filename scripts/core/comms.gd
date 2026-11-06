extends Node
## 系统播报（autoload 名：Comms）——非人声机电提示：作战开始 + 两档低 AP。
## 无剧情、无角色。台词在 data/comms.json（仅 SYSTEM 一名说话人），语音由
## tools/bake_tts.py --backend piper 烘焙（韵律保留），机械感由运行时电台链
## （带通+EQ+削波+重压缩+噪底+限幅，见 _setup_audio）做。语音缺失时退化为纯字幕。

const BUS_NAME := "Radio"
const DATA_PATH := "res://data/comms.json"
const VO_DIR := "res://assets/vo"

const SUBTITLE_AT_TOP := false  # true=顶部居中（旧版，与 BOSS 血条/WARNING 打架），false=底部居中（AC6 位）
const SUBTITLE_WIDTH := 640.0   # 视口 2400 下的正文换行宽度；分隔横线同宽（AC6：线=字幕列宽）
const SPEAKER_FONT_SIZE := 24
const TEXT_FONT_SIZE := 28
const TEXT_COLOR := Color(1, 1, 1)           # AC6 式全白（人名+正文统一），不加投影/描边
const LINE_HEIGHT := 3.0
const LINE_COLOR := Color(1, 1, 1, 0.6)
const BOX_SEPARATION := 6
const SUBTITLE_TOP_MARGIN := 26.0    # 顶部模式：字幕块离屏幕上缘
const SUBTITLE_BOTTOM_MARGIN := 90.0 # 底部模式：字幕块离屏幕下缘（AC6 位）

var _enabled := true
var muted := false # 录制静音闸（F1 档，HUD 接线 set_muted）：人声+字幕+静噪全停
var _speakers := {}
var _lines := {}
var _pending: Array = [] # 播报中又触发一条：只压一条最新的，其余丢弃（系统音可丢了重触）
var _playing := false
var _line_seq := 0       # 代际号：打断时 +1，旧协程 await 醒来对不上号就自行退出
var _hp_tier := 0        # 0=正常 1=50% 档已播 2=25% 档已播（回升越阈值+余量才归零）

var _voice: AudioStreamPlayer
var _squelch: AudioStreamPlayer
var _bed: AudioStreamPlayer # 常驻静噪底床：频道开着的沙沙声，人声一停就掐
var _sq_open: AudioStream
var _sq_close: AudioStream
var _box: VBoxContainer
var _speaker_label: Label
var _text_label: Label


func _ready() -> void:
	# 游戏结束定格（树暂停）时通讯照常收尾：阵亡反应台词要在结算画面上播完。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_data()
	_setup_audio()
	_setup_ui()


## ---- 事件入口（main.gd 接线） ----

## 作战开始播报。announce=false 用于章末黑场交接进新关：系统启动音整局只在
## 开局（首启/死亡重开的启动页）播一次，跨关不重复；但掐残留播报、复位低 AP
## 档照做（上一关结尾的低 AP 提示属于上一场仗，不跟着进新关）。
func notify_combat_start(announce := true) -> void:
	_hp_tier = 0
	# 重开进战斗：掐掉上局残留的播报（死亡瞬间触发的低 AP 等），
	# 不然新一局开场顶着一句"AP剩余25%"，很出戏。系统音可丢了重触。
	_pending.clear()
	if _playing:
		_line_seq += 1 # 代际号推进：旧收尾协程醒来对不上号自行退出
		_playing = false
		_box.visible = false
		_voice.stop()
	if announce:
		say("sys_combat")


func notify_hp(current: int, max_hp: int) -> void:
	if not _enabled or max_hp <= 0:
		return
	var ratio := float(current) / float(max_hp)
	if ratio <= BalanceGlobal.COMMS_HP_WARN_T2 and _hp_tier < 2:
		_hp_tier = 2
		say("sys_hp_crit")
	elif ratio <= BalanceGlobal.COMMS_HP_WARN_T1 and _hp_tier < 1:
		_hp_tier = 1
		say("sys_hp_warn")
	elif ratio >= BalanceGlobal.COMMS_HP_WARN_T1 + BalanceGlobal.COMMS_HP_REARM_MARGIN and _hp_tier > 0:
		_hp_tier = 0


## 录制静音闸（F1 档开、回落档 0 关，HUD 接线）：掐掉在播的人声/字幕/静噪
## 底床，后续播报一律不出（say 入口挡）。打断逻辑与 notify_combat_start 同款：
## 代际号推进，旧收尾协程醒来对不上号自行退出。
func set_muted(on: bool) -> void:
	muted = on
	if not on:
		return
	_hp_tier = 0
	_pending.clear()
	if _playing:
		_line_seq += 1
		_playing = false
	_box.visible = false
	_voice.stop()
	_bed.stop()


## ---- 播报内核 ----

func say(id: String) -> void:
	if not _enabled or muted:
		return
	if _playing:
		if _pending.size() < 1 and not _pending.has(id):
			_pending.append(id)
		return
	_start_line(id)


func _start_line(id: String) -> void:
	var line: Dictionary = _lines.get(id, {})
	if line.is_empty():
		return
	_line_seq += 1
	var seq := _line_seq
	_playing = true
	var text: String = line.get("text", "")
	_show_subtitle(str(line.get("speaker", "SYSTEM")), text)
	if BalanceGlobal.COMMS_RADIO_FX:
		_play_sfx(_sq_open)
		if _bed.stream != null and not _bed.playing:
			_bed.play() # 频道开：静噪底床进
	var stream := _load_vo(id)
	if stream != null:
		_voice.stream = stream
		_voice.play() # 播完由 finished 信号收尾
	else:
		# 语音没烘/未导入：纯字幕按字数估时（55ms/字符），链路照常走完
		var duration := clampf(0.055 * float(text.length()), 1.2, 4.0)
		await _sleep(duration)
		if seq != _line_seq:
			return
		_finish_line()


func _on_voice_finished() -> void:
	_finish_line()


func _finish_line() -> void:
	if BalanceGlobal.COMMS_RADIO_FX:
		_play_sfx(_sq_close)
		_bed.stop() # 频道关：底床随闭合音掐掉
	await _sleep(0.3)
	if not _playing:
		return # 休眠期间被打断：字幕已归新台词管
	_box.visible = false
	_playing = false
	if not _pending.is_empty():
		var next := str(_pending.pop_front())
		await _sleep(0.4) # 连播之间留半拍
		if not _playing:  # 间隙里又起了新播报：让位
			_start_line(next)


func _sleep(sec: float) -> void:
	# 按真实时间计时（ignore_time_scale）：命中顿帧/树暂停都不影响通讯节奏
	await get_tree().create_timer(sec, true, false, true).timeout


## ---- 资源与设施 ----

func _load_data() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_warning("Comms: 缺少 %s，播报停用" % DATA_PATH)
		_enabled = false
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_speakers = parsed.get("speakers", {})
		_lines = parsed.get("lines", {})
	else:
		push_warning("Comms: %s 解析失败，播报停用" % DATA_PATH)
		_enabled = false


func _setup_audio() -> void:
	# 电台总线：优先吃 default_bus_layout.tres 烘焙的同名总线——Web 导出上
	# 运行时 add_bus 建的总线不出声（实测全游戏音量喂不出去，2026-10-17 定罪）；
	# 没有烘焙时才运行时补建（保持工程自洽，双路径等价）。
	# 链序：带通限频 → EQ 提亮 → 软削波 grit → 重压缩（统一响度+泵感）
	#   → 拍背延迟（喇叭空间感）→ 限幅。
	# 临场感的来源是压缩+常驻噪底+grit 的动态，而不是把人声滤窄——
	# 光滤窄没有动态，就是"很平很假"的根源。
	if AudioServer.get_bus_index(BUS_NAME) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_NAME)
		AudioServer.set_bus_send(idx, "Master")
	# 电台后期链（BalanceGlobal.COMMS_RADIO_FX 关闭时整段跳过=纯干声空听）。
	# 必须独立于总线创建：总线可能来自 .tres 烘焙，效果要挂得上已存在的总线。
	if BalanceGlobal.COMMS_RADIO_FX:
		var fx_bus := AudioServer.get_bus_index(BUS_NAME)
		var high := AudioEffectHighPassFilter.new()
		high.cutoff_hz = 320.0
		var low := AudioEffectLowPassFilter.new()
		low.cutoff_hz = 3200.0
		var eq := AudioEffectEQ10.new()
		eq.set_band_gain_db(6, BalanceGlobal.COMMS_RADIO_PRESENCE_DB) # ~2kHz 穿透感
		eq.set_band_gain_db(7, BalanceGlobal.COMMS_RADIO_PRESENCE_DB * 0.5)
		var dist := AudioEffectDistortion.new()
		dist.mode = AudioEffectDistortion.MODE_CLIP
		dist.pre_gain = BalanceGlobal.COMMS_RADIO_DRIVE_DB # 推高进削波器=drive
		var comp := AudioEffectCompressor.new()
		comp.threshold = BalanceGlobal.COMMS_RADIO_COMP_THRESHOLD_DB
		comp.ratio = BalanceGlobal.COMMS_RADIO_COMP_RATIO
		comp.attack_us = 8000 # Godot 4 压缩器：攻击微秒/释放毫秒（两单位不同名）
		comp.release_ms = 120
		comp.gain = BalanceGlobal.COMMS_RADIO_COMP_GAIN_DB
		var slap := AudioEffectDelay.new()
		slap.dry = 1.0
		slap.tap1_active = false # 拍背延迟已被用户否掉（听成复读），留参数备复活
		slap.tap1_delay_ms = BalanceGlobal.COMMS_RADIO_SLAP_MS
		slap.tap1_level_db = BalanceGlobal.COMMS_RADIO_SLAP_LEVEL_DB
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		for effect: AudioEffect in [high, low, eq, dist, comp, slap, limiter]:
			AudioServer.add_bus_effect(fx_bus, effect)
	# Web 端非 Master 总线不出声（引擎级，详见 sfx.gd 同款注释），改道 Master；
	# 代价：COMMS_RADIO_FX 的总线效果在 Web 端不生效（干声直出）。
	var out_bus := "Master" if Platforms.is_web() else BUS_NAME
	_voice = AudioStreamPlayer.new()
	_voice.bus = out_bus
	_voice.volume_db = BalanceGlobal.COMMS_VOICE_VOLUME_DB
	_voice.finished.connect(_on_voice_finished)
	add_child(_voice)
	_squelch = AudioStreamPlayer.new()
	_squelch.bus = out_bus
	_squelch.volume_db = -6.0
	add_child(_squelch)
	_bed = AudioStreamPlayer.new()
	_bed.bus = out_bus
	_bed.volume_db = BalanceGlobal.COMMS_NOISE_BED_DB
	_bed.finished.connect(_bed.play) # 循环：缝隙被压缩泵感和语音掩住
	add_child(_bed)
	_sq_open = _load_stream(VO_DIR + "/_squelch_open.wav")
	_sq_close = _load_stream(VO_DIR + "/_squelch_close.wav")


func _setup_ui() -> void:
	# AC6 式顶部居中字幕：人名（小号白字）→ 分隔横线 → 正文（大号白字）。
	# 分隔线与正文换行宽度同源（SUBTITLE_WIDTH），线永远等于字幕列宽；
	# 可读性靠纯白本身（不加投影/描边，保持平涂画风）。
	var layer := CanvasLayer.new()
	layer.layer = 10 # 压过 HUD（默认层 1）与触控层
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_box = VBoxContainer.new()
	if SUBTITLE_AT_TOP:
		_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_box.offset_top = SUBTITLE_TOP_MARGIN
		_box.grow_vertical = Control.GROW_DIRECTION_END
	else:
		_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_box.offset_bottom = -SUBTITLE_BOTTOM_MARGIN
		_box.grow_vertical = Control.GROW_DIRECTION_BEGIN # 向上长，底边钉在边距上
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", BOX_SEPARATION)
	root.add_child(_box)
	# 中文界面用打包的思源黑体子集，同 hud.gd（见 ui_font.gd）。
	var font := UIFont.cjk()
	_speaker_label = Label.new()
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker_label.add_theme_font_override("font", font)
	_speaker_label.add_theme_font_size_override("font_size", SPEAKER_FONT_SIZE)
	# 分隔横线：与正文换行列同宽居中
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(SUBTITLE_WIDTH, LINE_HEIGHT)
	rule.color = LINE_COLOR
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label = Label.new()
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(SUBTITLE_WIDTH, 0)
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.add_theme_font_override("font", font)
	_text_label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	for label: Label in [_speaker_label, _text_label]:
		label.add_theme_color_override("font_color", TEXT_COLOR)
	_box.add_child(_speaker_label)
	_box.add_child(rule)
	_box.add_child(_text_label)
	_box.visible = false


func _show_subtitle(speaker_id: String, text: String) -> void:
	var spk: Dictionary = _speakers.get(speaker_id, {})
	_speaker_label.text = str(spk.get("name", speaker_id)) # 全白（AC6），JSON 阵营色暂不参与
	_text_label.text = text
	_box.visible = true


func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	_squelch.stream = stream
	_squelch.play()


func _load_vo(id: String) -> AudioStream:
	# mp3 = edge-tts 正式语音优先；wav = piper 本地烘焙
	var mp3 := _load_stream("%s/%s.mp3" % [VO_DIR, id])
	if mp3 != null:
		return mp3
	return _load_stream("%s/%s.wav" % [VO_DIR, id])


func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
