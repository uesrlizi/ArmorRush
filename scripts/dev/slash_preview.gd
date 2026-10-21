extends Node2D
## 刃光排查场景（临时）：按 MELEE_SWINGS 配置渲染两段挥砍的时间线定格
## （扫掠 25% / 60% / 收势满环），含 y 压扁投影与同弧两遍的半侧裁剪分层，
## 单帧截图自退。godot --path . res://scenes/previews/slash_preview.tscn

const STATES := [0.25, 0.6, 1.0] # 扫掠进度取样点


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.55, 0.65, 0.75) # 中灰蓝底，兼看加色亮暗表现
	bg.size = Vector2(2400, 1080)
	add_child(bg)

	for i in 2:
		var cfg: Dictionary = Player.MELEE_SWINGS[i]
		var from_deg: float = cfg.from_deg
		var to_deg: float = cfg.to_deg
		for j in STATES.size():
			var root := Node2D.new() # 模拟 SlashRoot：y 压扁投影
			root.scale = Vector2(1.0, Balance.MELEE_SQUASH)
			root.position = Vector2(400.0 + 700.0 * j, 300.0 + 500.0 * i)
			add_child(root)
			var far := SlashArc.new()
			var near := SlashArc.new()
			for arc: SlashArc in [far, near]:
				arc.pivot_offset = cfg.pivot
				arc.radius = cfg.radius
				arc.thickness = cfg.thickness
				arc.color_core = cfg.color_core
				arc.color_outer = cfg.color_outer
				arc.depth_dim = Balance.MELEE_FAR_DIM
			far.clip = SlashArc.Clip.UPPER
			near.clip = SlashArc.Clip.LOWER
			var body := ColorRect.new() # 机体占位块（40×60），画在远/近层之间
			body.color = Color(0.35, 0.42, 0.5)
			body.size = Vector2(40, 60)
			body.position = Vector2(-20, -30)
			var p: float = STATES[j]
			var eased := 1.0 - pow(1.0 - p, 3.0)
			var head := lerpf(from_deg, to_deg, eased)
			root.add_child(far)
			root.add_child(body)
			root.add_child(near)
			far.show_arc(from_deg, head, 1.0, 1.0)
			near.show_arc(from_deg, head, 1.0, 1.0)

	_shoot()


func _shoot() -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://autotest_shots/slash_preview.png"))
	print("[preview] saved")
	get_tree().quit()
