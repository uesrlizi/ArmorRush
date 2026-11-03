class_name DawnBurst
extends Node2D
## 啸雷空爆（第五章 啸雷弹定距空爆读法，贴图+粒子，fx 规约禁程序化
## _draw）：v2 平涂四层+烟——结构对齐 coral_burst/red_burst 已验收语言
## （层明细见 dawn_burst.tscn 头注）：Star 白星闪（能量给射线不给面积，
## 兼任爆区闪——GroundBlast show_flash=false）+ Ring 细冲击环（空爆环）
## + Sparks 火星流 + Shards 弹壳碎片（fx_dawn_flakshard 身份件，高炮弹幕
## 的弹壳崩碎）+ Smoke 小股暗紫烟团（空爆燃油雾体量层，无地面尘——
## 空中没有贴地语义）。替代 flash_burst 硬边大盘当爆区闪（v1 判丑：
## 白芯叠大饼/万能圆盘）。one_shot explosiveness=1.0 在 _ready 整批出生。
## 由 FlakShell._detonate 生成（调用方先定位再入树），不池化，0.75s 自清。
## power：爆径耦合倍率（调用方按 blast_radius/90 传入——精英 90=1.0、
## BOSS 110≈1.22）——场景里的速度/阻尼/尺寸是 90 爆径的基准档，_ready
## 复制材质按 power 等比放大（场景仍是检查器可调的正本，运行时不写回）。

const LIFETIME := 0.75

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
