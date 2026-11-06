class_name MirrorBurn
extends SlagPool
## 定镜灼烤的灼点（第八章 BOSS「盐磨」技能B 的驻留件）：SlagPool 语法换皮
## ——tick 判定/二段预警/生命周期全沿用火区件，只换视觉与预警读法：
##   预警=**干燥光束线**（镜面→落点，无伤）：先看见烧哪，再烧（反向预告，
##     提案 §2）；镜面=BOSS 翼尖聚焦口（beam_source，真实源点）。
##   蓄热期（SlagPool.warmup）=光束线驻留窗（0.4s，亮起不咬人）；灼点本体
##     在此窗内渐亮（盐面灼白斑浮现）。
##   tick 期=灼白斑咬人（6/0.3s，r80）+ 盐面蒸汽（fx_smoke 白汽苗上浮）。
## 惩罚账=BalanceWorld8.MIRROR_BURN 段注释：**半 lead**（玩家速度×1.1 clamp
## LEAD_MAX 400，落点由 BOSS 解算后注入）——罚匀速不罚变速；停=吃（lead≈0
## 落脚下）；梯次连点压挪位路线。
## .new() 纯代码自建视觉惯例（不带场景子节点）；group "mirror_burns"
## 供自测探针计数（slag_pools 组由父类照加）。数值全在 BalanceWorld8.MIRROR_BURN_*。

const BURN_TEXTURE := preload("res://assets/world_8/fx_salt_burn.svg")
const GLINT_TEXTURE := preload("res://assets/world_8/fx_salt_glint.svg")
const SMOKE_TEXTURE := preload("res://assets/common/fx_smoke.svg")

## 干燥光束线的源点（BOSS 镜阵翼尖聚焦口，世界坐标；Vector2.INF=无光束）。
var beam_source := Vector2.INF

var _beam: Line2D
var _beam_glint: Sprite2D


func _ready() -> void:
	_warmup = BalanceWorld8.MIRROR_BURN_BEAM # 蓄热期=光束线预告窗（亮起不咬人）
	lifetime = BalanceWorld8.MIRROR_BURN_BEAM + BalanceWorld8.MIRROR_BURN_TICK_TIME
	super() # tick 判定/蓄热/淡入淡出全沿用（含 slag_pools 组）
	_visual.texture = BURN_TEXTURE # 换皮：盐面灼白斑（画布按 r90 满幅同账）
	add_to_group("mirror_burns")
	if beam_source != Vector2.INF:
		# **落位后再建线**：调用方先 add_child 再写 global_position（先入树后
		# 定位惯例），_ready 此刻节点还在容器原点——立即建线会把 to_local 算成
		# 「落点+翼尖世界坐标」双倍偏移，可见段=灼点伸向屏幕右侧外的近水平
		# 拉丝（2026-11-06 用户报修的真凶）。deferred 到帧末，落位已完成。
		_build_beam.call_deferred()


## 干燥光束线：细线（镜面→落点）+ 落点光斑驻留（ADD 粉晕），随蓄热窗淡出
## ——「先看见烧哪」的反向预告本体。
func _build_beam() -> void:
	var to_local := beam_source - global_position
	_beam = Line2D.new()
	_beam.points = PackedVector2Array([to_local + Vector2(0.0, -8.0), Vector2(0.0, -6.0)])
	_beam.width = 5.0
	_beam.default_color = Color(1.0, 0.72, 0.82, 0.95) # 盐田粉光束（章信号色=预警灯语言）
	add_child(_beam)
	var addmat := CanvasItemMaterial.new()
	addmat.blend_mode = 1
	_beam_glint = Sprite2D.new()
	_beam_glint.texture = GLINT_TEXTURE
	_beam_glint.material = addmat
	_beam_glint.position = Vector2(0.0, -6.0)
	add_child(_beam_glint)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_beam, "modulate:a", 0.0, BalanceWorld8.MIRROR_BURN_BEAM) \
			.set_ease(Tween.EASE_IN)
	tw.tween_property(_beam_glint, "modulate:a", 0.0, BalanceWorld8.MIRROR_BURN_BEAM) \
			.set_ease(Tween.EASE_IN)


func _physics_process(delta: float) -> void:
	super(delta)
	# 蓄热期光斑呼吸（「线指着这里」的活性读法）；tick 期补盐面蒸汽
	if _warmup > 0.0 and _beam_glint != null:
		_beam_glint.scale = Vector2.ONE * (0.8 + 0.3 * sin(_life * 30.0))
	elif _life < lifetime - 0.4 and randf() < delta * 6.0:
		_spawn_steam()


## 盐面蒸汽：白汽苗上浮（fx_smoke 通用件，量级=尾迹烟档），tick 期稀疏补给。
func _spawn_steam() -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var puff := Sprite2D.new()
	puff.texture = SMOKE_TEXTURE
	puff.modulate = Color(1.0, 1.0, 1.0, 0.5)
	puff.scale = Vector2.ONE * randf_range(0.5, 0.9)
	container.add_child(puff)
	puff.global_position = global_position + Vector2(randf_range(-40.0, 40.0), -10.0)
	puff.reset_physics_interpolation()
	var tw := puff.create_tween()
	tw.set_parallel(true)
	tw.tween_property(puff, "position:y", puff.position.y - randf_range(50.0, 90.0),
			randf_range(0.7, 1.0)).set_ease(Tween.EASE_OUT)
	tw.tween_property(puff, "modulate:a", 0.0, randf_range(0.7, 1.0)).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(puff.queue_free)
