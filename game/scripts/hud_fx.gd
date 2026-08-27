class_name HudFx
extends RefCounted
## HUD 全屏特效层的构建(自 hud.gd 纯搬迁,C5):画面滤镜(色差+暗角+低理智色偏)、
## 状态侵蚀层(血色染色/CRT 扫描线/颗粒/幽灵字迹)。只接收 Hud 实例写字段,
## 运行时每帧逻辑(set_distort/red_flash/_process 更新等)仍留在 Hud。

const CORRUPT_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float corrupt = 0.0;
uniform float pulse = 0.0;
uniform float aspect = 1.7778;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(11.7, 9.2);
		a *= 0.5;
	}
	return v;
}
void fragment() {
	vec2 uv = SCREEN_UV;
	float c = clamp(corrupt, 0.0, 1.0);
	// 轻微 UV 扭曲:仅重度侵蚀启动,幅度极小以保可读性
	if (c > 0.5) {
		float w = (c - 0.5) * 2.0;
		uv += vec2(sin(uv.y * 17.0 + TIME * 2.3), cos(uv.x * 15.0 + TIME * 1.9)) * 0.0022 * w;
	}
	vec4 col = texture(screen_tex, uv);
	// 血色染色 + 整体压暗
	col.rgb = mix(col.rgb, col.rgb * vec3(0.80, 0.52, 0.50), c * 0.30);
	col.rgb *= 1.0 - 0.16 * c;
	vec2 d = uv - vec2(0.5, 0.5);
	// 边缘血色晕染:随心跳搏动,自屏幕边缘向内渗入
	float edge = smoothstep(0.32, 0.78, length(d));
	float seep = edge * c * (0.55 + 0.35 * pulse);
	col.rgb = mix(col.rgb, vec3(0.30, 0.035, 0.03), seep * 0.5);
	// 裂纹:噪声等值线网,侵蚀重度时自边缘向中心蔓延
	float n = fbm(uv * vec2(aspect, 1.0) * 6.5);
	float crack = 1.0 - smoothstep(0.0, 0.030, abs(n - 0.5));
	float spread = smoothstep(0.55, 0.95, c);
	float from_edge = smoothstep(0.12, 0.62, length(d));
	float crack_amt = crack * spread * from_edge;
	col.rgb = mix(col.rgb, vec3(0.10, 0.045, 0.04), crack_amt * 0.85);
	col.rgb += vec3(0.22, 0.04, 0.03) * crack_amt * pulse * 0.35;
	// 漂移暗影:雾状诡异图案缓慢游移
	float veil = fbm(uv * 2.6 + vec2(TIME * 0.025, -TIME * 0.018));
	float shadow_amt = smoothstep(0.55, 0.9, veil) * c * 0.30;
	col.rgb *= 1.0 - shadow_amt;
	// 低频闪烁:重度侵蚀偶发一帧级压暗
	if (c > 0.6) {
		float f = hash12(vec2(floor(TIME * 8.0), 7.31));
		col.rgb *= 1.0 - step(0.94, f) * 0.20 * ((c - 0.6) / 0.4);
	}
	COLOR = vec4(col.rgb, 1.0);
}
"""

const SCAN_SHADER := """
shader_type canvas_item;
// CRT 扫描线(每 3px 一条 1px 暗线)+ 缓慢下移的暖色亮带(参考稿 .layer-scan/.layer-roll)
uniform float scan_alpha = 0.10;
uniform float band_alpha = 0.028;
uniform float band_speed = 0.10;
void fragment() {
	float scan = scan_alpha * (1.0 - step(1.0, mod(FRAGCOORD.y, 3.0)));
	float band = exp(-pow((fract(UV.y + TIME * band_speed) - 0.5) * 5.5, 2.0));
	vec3 col = vec3(0.80, 0.77, 0.71) * band;
	COLOR = vec4(col, scan + band * band_alpha);
}
"""

# ---------- 画面滤镜(色差 + 暗角 + 低理智色偏,3D 之上、UI 之下) ----------

static func build_effect_layer(h) -> void:
	var layer: CanvasLayer = h._layer(10)
	h.effect_rect = ColorRect.new()
	h.effect_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float distort = 0.0;
uniform float vignette = 0.42;
uniform float ca = 0.0012;
vec3 hue_rotate(vec3 c, float a) {
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	float u = cos(a), t = sin(a);
	return c * u + cross(w, c) * t + w * dot(w, c) * (1.0 - u);
}
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r2 = dot(d, d);
	vec2 off = d * ca * r2 * 3.0;
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	if (distort > 0.5) {
		float sat = distort > 1.5 ? 0.55 : 0.75;
		float con = distort > 1.5 ? 1.15 : 1.08;
		float hue = (distort > 1.5 ? -14.0 : -6.0) * 0.017453;
		col = hue_rotate(col, hue);
		float l = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(l), col, sat);
		col = (col - 0.5) * con + 0.5;
	}
	float v = smoothstep(0.55, 1.55, length(d) * 2.1);
	col *= 1.0 - vignette * v;
	COLOR = vec4(col, 1.0);
}
"""
	h.effect_rect.material = ShaderMaterial.new()
	h.effect_rect.material.shader = sh
	layer.add_child(h.effect_rect)

	h.red_flash_rect = TextureRect.new()
	h.red_flash_rect.stretch_mode = TextureRect.STRETCH_SCALE
	h.red_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.red_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(120.0/255, 0, 0, 0.55))
	grad.set_color(1, Color(60.0/255, 0, 0, 0.85))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	h.red_flash_rect.texture = gtex
	h.red_flash_rect.modulate.a = 0.0
	layer.add_child(h.red_flash_rect)

# ---------- 状态侵蚀层(理智驱动的动态恐怖氛围) ----------
# 覆盖层位于 HUD(20)之上、弹窗(50)/转场(60)/全屏画面(70)之下:
# 3D + HUD 一起被血色/裂纹/暗影侵蚀,而关键决策界面保持干净可读。

static func build_corruption_layer(h) -> void:
	var layer: CanvasLayer = h._layer(25)
	# 老胶片颗粒:压在侵蚀着色器之下的低透明度噪点,去掉 UI/画面的「矢量干净感」
	if h._grain_tex != null:
		var grain := TextureRect.new()
		grain.texture = h._grain_tex
		grain.stretch_mode = TextureRect.STRETCH_TILE
		grain.set_anchors_preset(Control.PRESET_FULL_RECT)
		grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grain.modulate = Color(1.0, 0.97, 0.92, 0.055)
		layer.add_child(grain)
	# CRT 扫描线 + 滚动亮带(强度收敛,保 3D 画面可读)
	h.scan_rect = ColorRect.new()
	h.scan_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.scan_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ssh := Shader.new()
	ssh.code = SCAN_SHADER
	h.scan_rect.material = ShaderMaterial.new()
	h.scan_rect.material.shader = ssh
	layer.add_child(h.scan_rect)
	h.corrupt_rect = ColorRect.new()
	h.corrupt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.corrupt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = CORRUPT_SHADER
	h.corrupt_rect.material = ShaderMaterial.new()
	h.corrupt_rect.material.shader = sh
	layer.add_child(h.corrupt_rect)
	# 幽灵字迹:重度侵蚀时在屏幕边缘短暂浮现
	h.ghost_root = Control.new()
	h.ghost_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.ghost_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(h.ghost_root)
	for i in 3:
		var gl: Label = h._label("", 18, Color(0.55, 0.12, 0.10, 1.0), h.ghost_root, true)
		gl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		gl.add_theme_constant_override("outline_size", 4)
		gl.modulate.a = 0.0
		h._ghost_labels.append(gl)
