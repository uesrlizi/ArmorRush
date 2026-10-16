shader_type canvas_item;
// 轮廓光（rim light）副本 shader：在本体贴图 alpha 边缘向外扩一圈纯色描边，
// 本体内部区域透明（a - c.a），因此副本叠在哪个 z 都不会糊住本体细节。
// 用法：复制一份 Sprite2D 同贴图同变换，挂本材质，z_index 垫到本体后面。
uniform vec4 rim_color : source_color = vec4(1.0, 0.89, 0.7, 0.95); // 暖天光（呼应钠灯）
uniform float width_px : hint_range(0.0, 8.0) = 2.0; // 纹理像素单位的描边宽

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * width_px;
	float a = c.a;
	a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV + px).a);
	a = max(a, texture(TEXTURE, UV - px).a);
	a = max(a, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
	COLOR = vec4(rim_color.rgb, max(a - c.a, 0.0) * rim_color.a);
}
