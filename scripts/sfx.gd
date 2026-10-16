extends Node
## 音效总管（autoload 名：Sfx）——战斗/移动/环境音效的唯一发声口。
## 工程做法沿两项目验证过的套路（台账见 design/sfx.md）：
## - 固定播放池 + 空闲优先、全忙偷最旧：杜绝逐事件 new/free 节点；
## - 开机全量预载音库，战斗中零懒加载；
## - 音库 = 注册字典（键 → 变体文件/db/随机 pitch 范围/逐键节流），
##   事件代码只调 play(key, strength)，不碰任何 player；
## - 多变体随机轮播 + 随机 pitch + 逐键节流：防习惯化、防连射刷屏；
## - 推进连续音走专用播放器，非对称平滑（点火快、收火带余焰），
##   档位直接吃 Player 的喷焰 flame_level（视觉/听觉同源）；
## - 环境床走 Amb 总线循环（锈雨），场景切换时 set_amb(key) 换。
## 全非定位："镜头即耳朵"——侧视跟焦，战斗事件永远在画面内，位置不参与混音；
## Comms 语音走它自己的 Radio 总线，与本处互不掺和。
## 响度档位纪律（改音库先读）：命中确认（近战命中/受击/爆炸）> 出手（枪/斩）
## > 移动（跳/落地/脚步）> 环境。要改全库平衡拧 Master/Sfx/Amb 总线推子，
## 别散改这里逐键 dB——这里的档位只表达"谁压得住谁"。

const POOL_SIZE := 12
const SFX_DIR := "res://assets/sfx"
const SFX_BUS := "Sfx"
const AMB_BUS := "Amb"
const AMB_DB := -18.0

## 循环音键：gen_sfx.py 已保证接缝，这里运行时设 LOOP_FORWARD（不依赖 .import）。
## 预载统一走本清单——新增循环音忘在这里就是永远静默（thrust_loop 踩过）。
const LOOP_KEYS: Array[StringName] = [&"thrust_loop", &"slide_loop", &"amb_rust_loop"]

## 环境床注册：场景键 → 文件名。新场景（废都之外的提案）在此加行。
const AMBS := {&"rust": &"amb_rust_loop"}

var _lib := {}         # StringName -> {paths, db, pitch:[lo,hi], throttle_ms}
var _streams := {}     # StringName -> Array[AudioStream]（全量预载）
var _pool: Array[AudioStreamPlayer] = []
var _pool_started: Array[int] = [] # 各声道起播时刻，全忙时偷最旧
var _last_played := {} # StringName -> msec（逐键节流）
var _thrust: AudioStreamPlayer
var _thrust_target := 0.0
var _thrust_smooth := 0.0
var _thrust_on := false
var _slide: AudioStreamPlayer
var _slide_target := 0.0
var _slide_smooth := 0.0
var _slide_on := false
var _amb: AudioStreamPlayer
var _amb_key := &""


func _ready() -> void:
	# 树暂停（结算定格）时音效照常收尾，与 Comms 同规。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(SFX_BUS)
	_ensure_bus(AMB_BUS)
	_fill_lib()
	_preload()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_pool.append(p)
		_pool_started.append(0)
	_thrust = AudioStreamPlayer.new()
	_thrust.bus = SFX_BUS
	add_child(_thrust)
	_slide = AudioStreamPlayer.new()
	_slide.bus = SFX_BUS
	add_child(_slide)
	_amb = AudioStreamPlayer.new()
	_amb.bus = AMB_BUS
	_amb.volume_db = AMB_DB
	add_child(_amb)
	set_amb(&"rust")


func _exit_tree() -> void:
	# 退出兜底：常播循环（推进/滑行/环境床）停掉释放 playback，退出零泄漏。
	_thrust.stop()
	_slide.stop()
	_amb.stop()


## ---- 发声口 ----

## 唯一播放入口。strength 0..1 线性微调响度（钳 0.25..1.5），1=音库基准。
func play(key: StringName, strength := 1.0) -> void:
	var e: Dictionary = _lib.get(key, {})
	if e.is_empty():
		return
	var now := Time.get_ticks_msec()
	var throttle := int(e.get("throttle", 0))
	if throttle > 0 and now - int(_last_played.get(key, -1_000_000_000)) < throttle:
		return
	_last_played[key] = now
	var streams: Array = _streams.get(key, [])
	if streams.is_empty():
		return
	var idx := _take_voice(now)
	var p := _pool[idx]
	_pool_started[idx] = now
	p.stream = streams[randi() % streams.size()]
	p.volume_db = float(e["db"]) + linear_to_db(clampf(strength, 0.25, 1.5))
	var pitch: Array = e["pitch"]
	p.pitch_scale = randf_range(float(pitch[0]), float(pitch[1]))
	p.play()


## 脚步已砍（滑行移动配脚步声画不同步）：地面摩擦改走 set_slide。


## 推进连续音档位：直接喂 Player 的喷焰 flame_level（0=熄火）。
func set_thrust(level: float) -> void:
	_thrust_target = clampf(level, 0.0, 1.0)


## 地面滑行摩擦档位：喂速度比（0=静止/空中），Player 每帧报。
func set_slide(level: float) -> void:
	_slide_target = clampf(level, 0.0, 1.0)


func _process(delta: float) -> void:
	# 循环音平滑，点火快、收火带余焰；sqrt 曲线让低档位响度变化体感更线性。
	_thrust_smooth = lerpf(_thrust_smooth, _thrust_target,
			1.0 - exp(-delta / (0.06 if _thrust_target > _thrust_smooth else 0.22)))
	_slide_smooth = lerpf(_slide_smooth, _slide_target,
			1.0 - exp(-delta / (0.09 if _slide_target > _slide_smooth else 0.18)))
	if _thrust_target > 0.0 and not _thrust_on:
		var ts := _first_stream(&"thrust_loop")
		if ts != null:
			_thrust.stream = ts
			_thrust.play()
			_thrust_on = true
	if _thrust_on:
		_thrust.volume_db = lerpf(-24.0, -7.0, sqrt(_thrust_smooth))
		_thrust.pitch_scale = 0.88 + 0.24 * _thrust_smooth
		if _thrust_target <= 0.0 and _thrust_smooth < 0.01:
			_thrust.stop()
			_thrust_on = false
	if _slide_target > 0.0 and not _slide_on:
		var ss := _first_stream(&"slide_loop")
		if ss != null:
			_slide.stream = ss
			_slide.play()
			_slide_on = true
	if _slide_on:
		_slide.volume_db = lerpf(-34.0, -20.0, sqrt(_slide_smooth))
		_slide.pitch_scale = 0.92 + 0.12 * _slide_smooth
		if _slide_target <= 0.0 and _slide_smooth < 0.01:
			_slide.stop()
			_slide_on = false


## 环境床：按场景键换循环。同键零开销；缺键停床。
## （单场景期直接换流不淡化；四套场景齐了再考虑交叉。）
func set_amb(key: StringName) -> void:
	if key == _amb_key:
		return
	_amb_key = key
	var stream := _first_stream(key) if AMBS.has(key) else null
	if stream == null:
		_amb.stop()
		return
	_amb.stream = stream
	_amb.play()


## ---- 内部 ----

## 借声道：空闲优先；全忙偷"最早开始"的（挤掉最老的声音）。
func _take_voice(now: int) -> int:
	for i in POOL_SIZE:
		if not _pool[i].playing:
			return i
	var oldest := 0
	for i in POOL_SIZE:
		if _pool_started[i] < _pool_started[oldest]:
			oldest = i
	return oldest


func _first_stream(key: StringName) -> AudioStream:
	var streams: Array = _streams.get(key, [])
	return streams[0] if not streams.is_empty() else null


## 音库注册：键 → paths(变体)/db/pitch(随机范围)/throttle(同键最小间隔 ms)。
## db 档位纪律见头注；新增音效 = gen_sfx.py 清单加行 + 此处注册 + 事件处 play。
func _fill_lib() -> void:
	_lib[&"fire_player"] = {"paths": ["fire_player_a", "fire_player_b", "fire_player_c"],
			"db": -10.0, "pitch": [0.96, 1.06], "throttle": 30}
	_lib[&"fire_enemy"] = {"paths": ["fire_enemy_a", "fire_enemy_b"],
			"db": -12.0, "pitch": [0.94, 1.04], "throttle": 0}
	_lib[&"melee_slash1"] = {"paths": ["melee_slash1_a", "melee_slash1_b"],
			"db": -7.0, "pitch": [0.97, 1.05], "throttle": 0}
	_lib[&"melee_slash2"] = {"paths": ["melee_slash2_a", "melee_slash2_b"],
			"db": -7.0, "pitch": [0.97, 1.05], "throttle": 0}
	_lib[&"melee_hit"] = {"paths": ["melee_hit_a", "melee_hit_b"],
			"db": -4.0, "pitch": [0.95, 1.08], "throttle": 0}
	_lib[&"melee_windup"] = {"paths": ["melee_windup"],
			"db": -15.0, "pitch": [0.96, 1.04], "throttle": 0}
	_lib[&"hit_enemy"] = {"paths": ["hit_enemy_a", "hit_enemy_b"],
			"db": -8.0, "pitch": [0.92, 1.10], "throttle": 60}
	_lib[&"hit_deflect"] = {"paths": ["hit_deflect"],
			"db": -9.0, "pitch": [0.96, 1.05], "throttle": 60}
	_lib[&"hit_player"] = {"paths": ["hit_player"],
			"db": -6.0, "pitch": [0.97, 1.05], "throttle": 0}
	_lib[&"hit_world"] = {"paths": ["hit_world"],
			"db": -14.0, "pitch": [0.90, 1.15], "throttle": 80}
	_lib[&"boom_enemy"] = {"paths": ["boom_enemy_a", "boom_enemy_b"],
			"db": -5.0, "pitch": [0.94, 1.06], "throttle": 40}
	_lib[&"boom_player"] = {"paths": ["boom_player"],
			"db": -2.0, "pitch": [1.0, 1.0], "throttle": 0}
	_lib[&"ui_gameover"] = {"paths": ["ui_gameover"],
			"db": -7.0, "pitch": [1.0, 1.0], "throttle": 0}
	# 威胁警告（AC6 式双声滴滴）：保命提示高档；pitch 不随机——警告要恒定辨识度；
	# 节流=文件时长（0.48s 取整），导弹车/BOSS 弹雨的预警确立瞬间触发，循环感由再次触发承担。
	_lib[&"threat_warn"] = {"paths": ["threat_warn"],
			"db": -6.0, "pitch": [1.0, 1.0], "throttle": 500}
	for key: StringName in _lib:
		_lib[key]["paths"] = (_lib[key]["paths"] as Array) \
				.map(func(n: String) -> String: return "%s/%s.wav" % [SFX_DIR, n])


func _preload() -> void:
	# 全量预载：小体量短 wav 一次性 load，战斗中零懒加载。
	for key: StringName in _lib:
		var list: Array = []
		for path: String in _lib[key]["paths"]:
			var stream := _load_wav(path, false)
			if stream != null:
				list.append(stream)
		_streams[key] = list
	# 循环音统一按 LOOP_KEYS 预载并设循环（thrust_loop 曾漏在两处注册之外=静默）。
	for key: StringName in LOOP_KEYS:
		_streams[key] = [_load_wav("%s/%s.wav" % [SFX_DIR, key], true)]


func _load_wav(path: String, loop: bool) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("Sfx: 缺少 %s（先跑 tools/gen_sfx.py 并 --import）" % path)
		return null
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		return null
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2 # 16-bit 单声道：2 字节/帧
	return stream


## 总线运行时创建（工程不依赖 default_bus_layout.tres，自洽）。
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
