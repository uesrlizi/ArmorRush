class_name DrillCharge
extends Node2D
## 凿岩装药（第六章 BOSS「赤轮」技能B·凿岩齐射的危险件）：采矿爆破工序的
## 三段读法——**凿孔（抛体落点）→ 装药（钉地红灯渐急）→ 起爆（定延时球爆）**。
## 抛体按「落点+时长」解算初速（MORTAR_GRAVITY 真弹道同源），落地即钉在
## 落点路面竖直立起——**落点静止件，零地形跟随**（贴地跑行类已判死：台阶
## 瞬移，同珊瑚潮 v1 死因）。引信=定延时（**灯晕红斑**渐急=二段预警主读出
## 件，非近炸非驻留 tick；v1 整弹 alpha 闪烁在亮沙底上读作消失已废），到点
## 一次性球爆（GroundBlast 判定 + RedBurst 五层平涂爆裂，无残留区）。
## 飞行期拖尾复用臼炮 mortar_trail（同族抛体同配方；落定/起爆过继弹容器
## 淡完再清，同导弹拉烟收尾惯例）；落定凿孔尘=drill_plant_dust.tscn。
## 惩罚账=BalanceWorld7.REDWHEEL_CHARGE 段注释：lead 走廊封匀速跑的路径，反应窗内
## 跑离=免，变速/变向=装药落在身后。group "drill_charges" 供自测探针计数。
## 数值：伤害/半径/引信/飞行=调用方按 BalanceWorld6.REDWHEEL_CHARGE_* 注入。

const CHARGE_TEXTURE := preload("res://assets/world_6/fx_red_charge.svg")
const LAMP_TEXTURE := preload("res://assets/world_6/fx_red_glowlamp.svg")
const TRAIL := preload("res://scenes/weapons/mortar_trail.tscn")
const PLANT_DUST := preload("res://scenes/fx/drill_plant_dust.tscn")
const RED_BURST := preload("res://scenes/fx/red_burst.tscn")

enum Phase { FLY, FUSE }

var damage := 10
var blast_radius := 120.0
var flight_time := 0.7
var fuse_time := 1.0

var _phase := Phase.FLY
var _vel := Vector2.ZERO
var _terrain: Terrain
var _t := 0.0
var _visual: Sprite2D
var _lamp: Sprite2D
var _trail: Node2D
var _popped := false


## 先入树再调本方法。target 必须贴地（调用方按 lead 解算）。
func launch(terrain: Terrain, from: Vector2, target: Vector2, flight_time: float) -> void:
	_terrain = terrain
	self.flight_time = flight_time
	global_position = from
	var d := target - from
	var g := BalanceCombat.MORTAR_GRAVITY
	_vel = Vector2(d.x / flight_time, d.y / flight_time - 0.5 * g * flight_time)
	rotation = _vel.angle()
	reset_physics_interpolation() # 先入树后定位：不拖补间残影


## 出膛初速方向（调用方挂出膛焰用——真实枪口律：焰向=弹向）。
func initial_dir() -> Vector2:
	return _vel.normalized() if _vel.length_squared() > 0.0001 else Vector2.RIGHT


func _ready() -> void:
	add_to_group("drill_charges")
	_visual = Sprite2D.new()
	_visual.texture = CHARGE_TEXTURE
	add_child(_visual)
	var addmat := CanvasItemMaterial.new()
	addmat.blend_mode = 1
	_lamp = Sprite2D.new()
	_lamp.texture = LAMP_TEXTURE
	_lamp.material = addmat
	_lamp.visible = false
	add_child(_lamp) # 灯晕盖在弹体上（弹体暗壳底，加色红晕读「红灯」）
	_trail = TRAIL.instantiate()
	_trail.position = Vector2(-16.0, 0.0) # 弹尾（随弹体旋转，永远在速度反侧）
	add_child(_trail)


func _physics_process(delta: float) -> void:
	if _popped:
		return
	_t += delta
	match _phase:
		Phase.FLY:
			_vel.y += BalanceCombat.MORTAR_GRAVITY * delta
			global_position += _vel * delta
			rotation = _vel.angle()
			var surface := _terrain.surface_y_at(global_position.x) \
					if _terrain != null else target_y_fallback()
			if global_position.y >= surface:
				_plant(surface)
		Phase.FUSE:
			# 红灯渐急（二段预警主读出件）：灯晕 alpha+scale 随引信进度
			# 加快放大——「何时爆」的剩余时间信息层；弹体保持实心
			var urgency := clampf(_t / fuse_time, 0.0, 1.0)
			_lamp.modulate.a = urgency * (0.55 + 0.45 * sin(_t * (10.0 + 30.0 * urgency)))
			_lamp.scale = Vector2.ONE * (0.5 + 0.9 * urgency)
			if _t >= fuse_time:
				_detonate()


## 凿孔落定：钉在落点路面竖直立起（贴图 +X=钻头，转 90° 钻头朝下）+
## 凿孔尘（小尘点，与起爆全量爆裂拉开量级对比）；拖尾过继弹容器淡完再清。
func _plant(surface: float) -> void:
	_phase = Phase.FUSE
	_t = 0.0
	global_position = Vector2(global_position.x, surface - 18.0) # 钻头入土读法
	rotation = PI * 0.5
	reset_physics_interpolation()
	_lamp.visible = true
	_lamp.modulate.a = 0.0
	if _trail != null:
		for p in _trail.get_children():
			if p is GPUParticles2D:
				(p as GPUParticles2D).emitting = false
		var container0 := get_tree().get_first_node_in_group("projectile_container")
		if container0 != null:
			_trail.reparent(container0)
			get_tree().create_timer(0.8).timeout.connect(_trail.queue_free)
		_trail = null
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		var dust := PLANT_DUST.instantiate() as Node2D
		container.add_child(dust)
		dust.position = Vector2(global_position.x, surface - 4.0)
	Sfx.play(&"hit_deflect") # 占位：凿岩落定暂用弹开声


func target_y_fallback() -> float:
	return global_position.y


## 起爆：一次性球爆（无驻留区），爆心贴地；判定归 GroundBlast（爆区闪
## 关掉——硬边大盘判丑），视觉全权归 RedBurst 五层平涂爆裂。
func _detonate() -> void:
	_popped = true
	var surface := _terrain.surface_y_at(global_position.x) \
			if _terrain != null else global_position.y
	var at := Vector2(global_position.x, surface - 8.0)
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		var blast := GroundBlast.new()
		blast.damage = damage
		blast.radius = blast_radius
		blast.show_flash = false
		container.add_child(blast)
		blast.global_position = at
		blast.reset_physics_interpolation()
		var burst := RED_BURST.instantiate() as RedBurst
		burst.power = blast_radius / 90.0 # 场景基准档=90 爆径
		container.add_child(burst)
		burst.global_position = at
		burst.reset_physics_interpolation()
	Sfx.play(&"boom_enemy")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * 0.8)
	queue_free()
