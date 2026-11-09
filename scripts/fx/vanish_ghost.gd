class_name VanishGhost
extends Sprite2D
## 消失残影：消失承接规范（design/worlds.md §4c）里「自己渐隐」的通用件。本体一帧
## 回池/销毁时，把它的精灵按当帧外观（贴图/帧/翻转/全局变换/沿树叠乘的 modulate/
## 有效材质）复制一份进弹容器，原地快淡后自清——本体的生命周期与池化不动，视觉
## 消失交给残影。只认 Sprite2D；粒子/_draw 件走断流过继或承接。

const DEFAULT_TIME := 0.08


## 复制 src 当帧外观，time 秒内淡到 0（缓起急收：首帧基本满亮，与本体最后一帧接得上）。
## grow>1 时同步放大（破盾环一类「扩散散掉」读法）。src 不可见/不在树上时静默跳过。
static func spawn(src: Sprite2D, time := DEFAULT_TIME, grow := 1.0) -> void:
	if src == null or src.texture == null or not src.is_visible_in_tree():
		return
	var container := src.get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var g := VanishGhost.new()
	g.texture = src.texture
	g.centered = src.centered
	g.offset = src.offset
	g.flip_h = src.flip_h
	g.flip_v = src.flip_v
	g.hframes = src.hframes
	g.vframes = src.vframes
	g.frame = src.frame
	g.region_enabled = src.region_enabled
	g.region_rect = src.region_rect
	g.material = _effective_material(src)
	g.modulate = _global_modulate(src)
	# 容器是原点无变换的 Node：局部即全局；先定位再入树。残影静止不动，关插值
	#（补间写 scale 时渲染即所写）。
	g.transform = src.get_global_transform()
	g.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	container.add_child(g)
	var tw := g.create_tween()
	tw.set_parallel(true)
	tw.tween_property(g, "modulate:a", 0.0, time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if grow != 1.0:
		tw.tween_property(g, "scale", g.scale * grow, time) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(g.queue_free)


## 精灵子树统一出残影（多件拼装：芯片+字形等）。top_level 件（枪口焰/预警）
## 自管位置与寿命，不复制。
static func spawn_tree(root: Node, time := DEFAULT_TIME) -> void:
	if root is CanvasItem and not (root as CanvasItem).visible:
		return
	if root is Sprite2D:
		spawn(root as Sprite2D, time)
	for c in root.get_children():
		if c is CanvasItem and (c as CanvasItem).top_level:
			continue
		spawn_tree(c, time)


static func _global_modulate(n: CanvasItem) -> Color:
	var c := n.self_modulate
	var cur: Node = n
	while cur is CanvasItem:
		c *= (cur as CanvasItem).modulate
		cur = cur.get_parent()
	return c


static func _effective_material(n: CanvasItem) -> Material:
	var cur: Node = n
	while cur is CanvasItem:
		var ci := cur as CanvasItem
		if not ci.use_parent_material:
			return ci.material
		cur = cur.get_parent()
	return null
