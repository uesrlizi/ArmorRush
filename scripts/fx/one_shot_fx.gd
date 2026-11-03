class_name OneShotFx
extends Node2D
## 一次性小特效通用收尾：入树即开闸全部 GPUParticles2D（one_shot
## explosiveness=1 整批出生），寿命到点自清。纯视觉小件（触电迸溅/
## 凿孔尘）共用——层配置全在 tscn（检查器可调正本），脚本只管触发与
## 自清，fx 规约同 coral_burst.gd。调用方先定位再入树（one_shot 粒子
## 在 _ready 整批出生，入树后挪节点会喷在原点）。

@export var lifetime := 0.7

var _t := 0.0


func _ready() -> void:
	for p in get_children():
		if p is GPUParticles2D:
			(p as GPUParticles2D).emitting = true


func _process(delta: float) -> void:
	_t += delta
	if _t >= lifetime:
		queue_free()
