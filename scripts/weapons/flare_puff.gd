class_name FlarePuff
extends Bullet
## 硫焰扫掠焰团（第十章 BOSS「井口」普攻）：直线语法与 bullet.gd 完全一致（方向恒定、
## 速度/伤害由发射方赋值），只多一道触地闸——下一步落到当地地表以下就在地表上灭掉，
## 弹体永不进入地形内部（终审 R9「弹体处于地形内帧数 0」）。触地口径=弹心过地表（场景
## 碰撞只扫玩家层），与 threat_calc_ch10.py 的「y≥g 即灭」同账。

var _terrain: Terrain


func _physics_process(delta: float) -> void:
	if _terrain == null:
		_terrain = get_tree().get_first_node_in_group("terrain") as Terrain
	if _terrain != null and not is_queued_for_deletion():
		var nxt := global_position + (_direction * speed + _inherit) * delta
		if nxt.y >= _terrain.surface_y_at(nxt.x):
			_spawn_impact(global_position, true)
			queue_free()
			return
	super(delta)
