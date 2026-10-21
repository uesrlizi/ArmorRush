extends Node2D
## 电浆爆闪（贴图+粒子，fx 规约禁程序化 _draw）：Core 白热→冰蓝火球层 + Arc
## 八向电弧层 + Glow 余晖层，one_shot explosiveness=1.0 在 _ready 整批出生。
## 由 PlasmaMissile/PlasmaMine 引爆处生成（调用方先定位再入树），不池化，0.7s 自清。
## 层级账：本节点与 ExplosionBurst 同位（引爆处后于 GroundBlast 入树=画在爆区
## 闪上面），层内 ADD 叠亮不压底。

const LIFETIME := 0.7

var _life := 0.0


func _ready() -> void:
	for p in get_children():
		if p is GPUParticles2D:
			(p as GPUParticles2D).emitting = true


func _process(delta: float) -> void:
	_life += delta
	if _life >= LIFETIME:
		queue_free()
