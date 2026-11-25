class_name WormMound
extends Node2D
## 破土隆起预警（冰钻各招共用的破土前摇件）：节点原点钉在破土点的地表线上。
## 入树即 warn——雪丘从地里顶起来（长高+微颤）+ 峰顶 ThreatFlash（标准预警语汇：
## 闪光+警告音同拍，固定 0.6s 驻留）+ 预漏雪粉。到 release()（头破土那一拍）整件交给
## 破土爆雪接走后自清；没人来接（招被打断）由兜底寿命淡掉——可见物不许瞬灭。
## 隆起贴图/粒子层在本场景，脚本只管长起、颤、收。

@export var grow_time := 0.24  # 雪丘长到满的时长（秒）
@export var life := 3.0        # 兜底寿命（秒）：超时无人 release 就淡掉

@onready var _dome: Sprite2D = $Dome
@onready var _warn: ThreatFlash = $Peak/ThreatFlash

var _t := 0.0
var _released := false


func _ready() -> void:
	_dome.scale = Vector2(0.7, 0.2)
	_warn.warn()


func _process(delta: float) -> void:
	if _released:
		return
	_t += delta
	var p := clampf(_t / grow_time, 0.0, 1.0)
	_dome.scale = Vector2(lerpf(0.7, 1.0, p), lerpf(0.2, 1.0, 1.0 - (1.0 - p) * (1.0 - p)))
	_dome.position.x = sin(_t * 58.0) * 1.6 * (1.0 - 0.5 * p) # 顶起来的颤
	if _t >= life:
		_fade()


## 破土那一拍调：整件交给破土爆雪（同帧、同点、更大更亮）接走。
func release() -> void:
	if _released:
		return
	_released = true
	_warn.reset()
	queue_free()


func _fade() -> void:
	if _released:
		return
	_released = true
	_warn.reset()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
