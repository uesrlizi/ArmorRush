class_name ThrusterFlame
extends Node2D
## 推进喷焰：挂在机体背部喷口上的独立特效节点（不烘进角色图，可独立动画）。
## 焰朝 +Y（向下喷），纯 _draw 三层锥形焰体（橙外焰→黄中焰→白热芯）逐帧抖动。
## 强度档由 Player 每帧喂目标值：1.5=近战冲刺主焰/腿焰过烧、1.0=推进上升全开/姿控焰巡航、
## 0.75=近战悬停、0.5=近战缓沉/主焰纯前进巡航（倒退主焰熄火）、
## 0.45=下落反推缓降（下降段重力偏小的原因就是它在反推）、0=熄火。
## 节点由 Player 按朝向镜像摆放（喷口在背部），焰自身对称无需再翻转。
## 也挂水平姿控固定喷口（腿焰朝 -X=前进、腰焰朝 +X=倒退，rotate ±90°），分档同款。
## （2026-10-16 曾短暂换过 GPUParticles2D 粒子版，用户实测观感不佳回退本版——
## 火箭引擎焰是固定形态的持续焰，直接绘制比粒子合适；粒子版见 git/记忆。）
## 三层色板可换（装备通道，design/run_loop.md §4：背推=主焰色、腿推=姿控焰色），
## 默认=出厂暖焰；只换色相不动形态与各层透明度账。

const ATTACK_SPEED := 14.0 # 点火：强度上升速率（级/秒），要跟手
const RELEASE_SPEED := 6.0 # 熄火：强度回落速率（级/秒），带一点余焰
const LEN := 26.0          # 满强度焰长（px）
const MAX_LEVEL := 1.5     # 强度上限：近战冲刺主焰/腿焰过烧档（>1 = 更长更亮的过烧焰）

var _level := 0.0  # 当前强度（平滑后）
var _target := 0.0 # 目标强度
# 外层/中层/热芯色（RGB；透明度按层固定×强度，见 _draw）。热芯 2026-10-19 从近白
# (1.0,0.96,0.86) 压暖到琥珀：三章冰白天底上白芯直接消失（亮度≈天空），暖芯在深底
# 三章都保读；形态不动（钦定例外）。
const DEFAULT_OUTER := Color(1.0, 0.5, 0.12)
const DEFAULT_MID := Color(1.0, 0.76, 0.28)
const DEFAULT_CORE := Color(1.0, 0.87, 0.52)
var _outer := DEFAULT_OUTER
var _mid := DEFAULT_MID
var _core := DEFAULT_CORE


func set_target(level: float) -> void:
	_target = clampf(level, 0.0, MAX_LEVEL)


## 换焰色（外/中/芯三层）：装备生效瞬间与跨关恢复调用。
func set_palette(outer: Color, mid: Color, core: Color) -> void:
	_outer = outer
	_mid = mid
	_core = core


## 回出厂暖焰（推进槽卸下时；_refresh_mod_visuals 空槽分支调用）。
func reset_palette() -> void:
	set_palette(DEFAULT_OUTER, DEFAULT_MID, DEFAULT_CORE)


func _process(delta: float) -> void:
	var speed := ATTACK_SPEED if _target > _level else RELEASE_SPEED
	_level = move_toward(_level, _target, speed * delta)
	queue_redraw()


func _draw() -> void:
	if _level <= 0.01:
		return
	# 双正弦伪随机抖动：焰长与焰尖横摆都在颤，避免静态感
	var t := Time.get_ticks_msec() / 1000.0
	var flicker := 1.0 + 0.16 * sin(t * 47.0) + 0.1 * sin(t * 89.0 + 1.7)
	var sway := 1.6 * sin(t * 61.0 + 0.6) * _level
	var flame_len := LEN * _level * flicker
	# 外层锥 → 内层锥 → 热芯，逐层收窄缩短。
	_draw_cone(5.5, flame_len, sway, Color(_outer, 0.42 * _level))
	_draw_cone(3.4, flame_len * 0.78, sway * 0.7, Color(_mid, 0.7 * _level))
	_draw_cone(1.9, flame_len * 0.52, sway * 0.45, Color(_core, 0.95 * _level))


## 等腰焰锥：喷口宽 w，长 l，焰尖横偏 sway，朝 +Y。
func _draw_cone(w: float, l: float, sway: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, 0.0), Vector2(w, 0.0), Vector2(sway, l),
	]), color)
