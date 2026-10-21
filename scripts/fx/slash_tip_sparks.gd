extends CPUParticles2D
## 刃口碎光：挥砍扫掠期由 Player 生成、跟随刃口连续喷洒的细小光点
## （挂在弹容器里，global_coords 模式下粒子留在世界坐标形成拖尾）。
## 扫掠结束 Player 置 emitting=false，本脚本等最后一批粒子走完寿命再自灭。

var _grace := 0.0


func _ready() -> void:
	_grace = lifetime + 0.15


func _process(delta: float) -> void:
	if not emitting:
		_grace -= delta
		if _grace <= 0.0:
			queue_free()
