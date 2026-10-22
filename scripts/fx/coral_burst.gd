class_name CoralBurst
extends Node2D
## 珊瑚爆蕗（贴图+粒子，fx 规约禁程序化 _draw）：v2.5 全平涂——Ring 冲击环 +
## FlashCore 白芯闪光 + Dots 余烬点 + Shards 棘瓣碎屑（结构对齐 explosion_burst
## 的平涂语言；层明细见 coral_burst.tscn 头注），one_shot explosiveness=1.0
## 在 _ready 整批出生。
## 由 CoralOrb 撞地/放电舱出潮处生成（调用方先定位再入树），不池化，0.7s 自清。
## 层级账：与 ExplosionBurst 同位（引爆处后于 GroundBlast 入树=画在爆区
## 闪上面），层内 ADD 叠亮不压底。
## power：爆径耦合倍率（调用方按 blast_radius/90 传入）——场景里的速度/阻尼/
## 尺寸是 90 爆径的基准档，_ready 复制材质并按 power 等比放大（场景仍是
## 检查器可调的正本，运行时不写回）。

const LIFETIME := 0.7

var power := 1.0

var _life := 0.0


func _ready() -> void:
	for p in get_children():
		if p is GPUParticles2D:
			var particles := p as GPUParticles2D
			if power != 1.0:
				var mat := particles.process_material as ParticleProcessMaterial
				mat = mat.duplicate()
				mat.initial_velocity_min *= power
				mat.initial_velocity_max *= power
				mat.damping_min *= power
				mat.damping_max *= power
				mat.scale_min *= power
				mat.scale_max *= power
				particles.process_material = mat
			particles.emitting = true


func _process(delta: float) -> void:
	_life += delta
	if _life >= LIFETIME:
		queue_free()
