class_name RedBurst
extends Node2D
## 红砂爆蕗（矿区爆破读法，贴图+粒子，fx 规约禁程序化 _draw）：v3 平涂
## 五层——结构对齐 coral_burst/explosion_burst 已验收语言（层明细见
## red_burst.tscn 头注）：Star 白星闪（能量给射线不给面积）+ Ring 细冲击
## 环 + Sparks 火星流 + Shards 岩屑崩射（fx_red_rock 身份件）+ Dust 砂尘
## 横铺。替代 flash_burst 硬边大盘当爆区闪（凿岩装药起爆 v1 判丑：白芯
## 叠大饼/万能圆盘）。one_shot explosiveness=1.0 在 _ready 整批出生。
## 由 DrillCharge._detonate 生成（调用方先定位再入树），不池化，0.8s 自清。
## power：爆径耦合倍率（调用方按 blast_radius/90 传入）——场景里的速度/
## 阻尼/尺寸是 90 爆径的基准档，_ready 复制材质按 power 等比放大（场景
## 仍是检查器可调的正本，运行时不写回）。

const LIFETIME := 0.8

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
