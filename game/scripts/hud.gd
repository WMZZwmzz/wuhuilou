class_name Hud
extends Node
## 全部 2D UI:HUD / 弹窗 / 字幕 / 转场 / 标题 / 结局 / 死亡 / 暂停 / 调试栏 / 画面滤镜
## (原 HTML+CSS 界面的对等移植,文案与布局保持一致)

signal start_requested
signal ending_advanced
signal restart_requested
signal retry_requested
signal to_title_requested
signal pause_resumed

const FONT_PATHS := [
	"C:/Windows/Fonts/msyh.ttc", "C:/Windows/Fonts/simhei.ttf", "C:/Windows/Fonts/simsun.ttc",
]

var theme_font: FontFile
# HUD 引用
var sanity_val: Label
var battery_val: Label
var sanity_fill: TextureRect
var battery_fill: TextureRect
var stamina_fill: TextureRect
var floor_val: Label
var time_val: Label
var objective: Label
var inv_bat_key: Label
var inv_a_key: Label
var inv_a_val: Label
var inv_b_key: Label
var inv_b_val: Label
var inv_candle_key: Label
var inv_candle_val: Label
var inv_relic_key: Label
var inv_relic_val: Label
var hud_root: Control
var crosshair: ColorRect
var prompt: Label
var subtitle: Label
# 弹窗
var modal_root: Control
var modal_title: Label
var modal_body: Label
var modal_choices: VBoxContainer
var modal_timer_bar: ColorRect
var modal_timer_wrap: Control
var modal_countdown: Timer
var modal_timeout_fn: Callable
var _modal_total := 0.0
var _modal_left := 0.0
# 转场 / 全屏画面
var fade_root: Control
var fade_label: Label
var fade_sub: Label
var title_screen: Control
var ending_screen: Control
var ending_title: Label
var ending_text: Label
var ending_hint: Label
var ending_stats: RichTextLabel
var restart_btn: Button
var gameover_screen: Control
var go_text: Label
var pause_hint: Control
var debug_bar: VBoxContainer
# 滤镜
var effect_rect: ColorRect
var red_flash_rect: TextureRect

var _sub_hide_tween: Tween

func _ready() -> void:
	theme_font = _load_font()
	_build_all()

static func _load_font() -> FontFile:
	for p: String in FONT_PATHS:
		if FileAccess.file_exists(p):
			var f := FontFile.new()
			f.load_dynamic_font(p)
			return f
	return null

func _theme() -> Theme:
	var t := Theme.new()
	if theme_font:
		t.default_font = theme_font
	t.default_font_size = 14
	return t

# ---------- 样式工具 ----------

static func _sbox(bg: Color, border: Color = Color(0, 0, 0, 0), radius := 4, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.8
	s.content_margin_bottom = margin * 0.8
	return s

static func _sbox_px(bg: Color, border: Color, radius: int, m_l: int, m_r: int, m_t: int, m_b: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = m_l
	s.content_margin_right = m_r
	s.content_margin_top = m_t
	s.content_margin_bottom = m_b
	return s

func _label(text: String, size: int, color: Color, parent: Control) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _bar(parent: Control, grad_from: Color, grad_to: Color) -> TextureRect:
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.08)
	bg.custom_minimum_size = Vector2(166, 8)
	bg.clip_contents = true
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, grad_from)
	grad.set_color(1, grad_to)
	var gtex := GradientTexture1D.new()
	gtex.gradient = grad
	gtex.width = 64
	fill.texture = gtex
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.size = Vector2(166, 8)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	parent.add_child(bg)
	return fill
func _style_button(b: Button) -> void:
	b.add_theme_color_override("font_color", Color.html("c9c0aa"))
	b.add_theme_color_override("font_hover_color", Color.html("efe6cc"))
	b.add_theme_color_override("font_pressed_color", Color.html("efe6cc"))
	b.add_theme_color_override("font_disabled_color", Color(0.79, 0.75, 0.67, 0.35))
	b.add_theme_stylebox_override("normal", _sbox_px(Color.html("1c1915"), Color.html("3d362d"), 4, 16, 16, 11, 11))
	b.add_theme_stylebox_override("hover", _sbox_px(Color.html("2a251e"), Color.html("6a5f4c"), 4, 16, 16, 11, 11))
	b.add_theme_stylebox_override("pressed", _sbox_px(Color.html("2a251e"), Color.html("6a5f4c"), 4, 16, 16, 11, 11))
	b.add_theme_stylebox_override("disabled", _sbox_px(Color(0.11, 0.10, 0.08, 0.35), Color.html("3d362d"), 4, 16, 16, 11, 11))

func _layer(idx: int) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = idx
	add_child(layer)
	return layer

static func _spacer(parent: Control, h: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)

# ---------- 画面滤镜(色差 + 暗角 + 低理智色偏,3D 之上、UI 之下) ----------

func _build_effect_layer() -> void:
	var layer := _layer(10)
	effect_rect = ColorRect.new()
	effect_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	effect_rect.material = ShaderMaterial.new()
	effect_rect.material.shader = sh
	layer.add_child(effect_rect)

	red_flash_rect = TextureRect.new()
	red_flash_rect.stretch_mode = TextureRect.STRETCH_SCALE
	red_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	red_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(120.0/255, 0, 0, 0.55))
	grad.set_color(1, Color(60.0/255, 0, 0, 0.85))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	red_flash_rect.texture = gtex
	red_flash_rect.modulate.a = 0.0
	layer.add_child(red_flash_rect)

func set_distort(level: float) -> void:
	effect_rect.material.set_shader_parameter("distort", level)

func red_flash() -> void:
	red_flash_rect.modulate.a = 1.0
	var tw := red_flash_rect.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(red_flash_rect, "modulate:a", 0.0, 0.25)

# ---------- HUD ----------

func _inv_line(parent: VBoxContainer, key_text: String, val_text: String) -> Dictionary:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key := _label(key_text, 12, Color.html("9a917f"), hb)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := _label(val_text, 12, Color.html("cfc6b2"), hb)
	parent.add_child(hb)
	return {"key": key, "val": val}

func _build_hud() -> void:
	var layer := _layer(20)
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.theme = _theme()
	layer.add_child(hud_root)
	hud_root.visible = false

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(14, 14)
	panel.custom_minimum_size = Vector2(190, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _sbox(Color(0.03, 0.03, 0.04, 0.55), Color(160.0/255, 150.0/255, 130.0/255, 0.25)))
	hud_root.add_child(panel)
	var v := VBoxContainer.new()
	v.position = Vector2(10, 8)
	v.custom_minimum_size = Vector2(170, 0)
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var row := func(t: String, parent_v: VBoxContainer) -> Dictionary:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 0)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _label(t, 12, Color.html("a89f8d"), hb)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent_v.add_child(hb)
		return {"hb": hb}
	var r1: Dictionary = row.call("理 智", v)
	sanity_val = _label("100", 12, Color.html("a89f8d"), r1["hb"])
	sanity_fill = _bar(v, Color.html("5a7a8c"), Color.html("8fb6c4"))
	var r2: Dictionary = row.call("电 量", v)
	battery_val = _label("--", 12, Color.html("a89f8d"), r2["hb"])
	battery_fill = _bar(v, Color.html("8c7a3a"), Color.html("d4c26a"))
	var r3: Dictionary = row.call("体 力", v)
	stamina_fill = _bar(v, Color.html("5c7a4a"), Color.html("9cc47a"))

	var clock := Panel.new()
	clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock.position = Vector2(-204, 14)
	clock.custom_minimum_size = Vector2(190, 0)
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.add_theme_stylebox_override("panel", _sbox(Color(0.03, 0.03, 0.04, 0.55), Color(160.0/255, 150.0/255, 130.0/255, 0.25)))
	hud_root.add_child(clock)
	var cv := VBoxContainer.new()
	cv.position = Vector2(12, 8)
	cv.custom_minimum_size = Vector2(166, 0)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.add_child(cv)
	floor_val = _label("1F", 22, Color.html("d8d0c0"), cv)
	time_val = _label("0:00", 15, Color.html("b8625a"), cv)

	objective = _label("找到妹妹 —— 1304", 13, Color.html("8d8574"), hud_root)
	objective.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective.position = Vector2(-120, 14)
	objective.custom_minimum_size = Vector2(240, 20)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var inv := Panel.new()
	inv.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	inv.position = Vector2(14, -168)
	inv.custom_minimum_size = Vector2(220, 0)
	inv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv.add_theme_stylebox_override("panel", _sbox(Color(0.03, 0.03, 0.04, 0.55), Color(160.0/255, 150.0/255, 130.0/255, 0.25)))
	hud_root.add_child(inv)
	var iv := VBoxContainer.new()
	iv.position = Vector2(10, 8)
	iv.custom_minimum_size = Vector2(200, 0)
	iv.add_theme_constant_override("separation", 5)
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv.add_child(iv)
	var bat_line := _inv_line(iv, "电池", "×1(按1使用)")
	inv_bat_key = bat_line["key"]
	var a_line := _inv_line(iv, "药瓶A(批号2048)", "×0(按2)")
	inv_a_key = a_line["key"]
	inv_a_val = a_line["val"]
	var b_line := _inv_line(iv, "药瓶B(批号2051)", "×0(按3)")
	inv_b_key = b_line["key"]
	inv_b_val = b_line["val"]
	var candle_line := _inv_line(iv, "香烛", "×0(按4使用)")
	inv_candle_key = candle_line["key"]
	inv_candle_val = candle_line["val"]
	var relic_line := _inv_line(iv, "遗物", "0 / 13")
	inv_relic_key = relic_line["key"]
	inv_relic_val = relic_line["val"]

	var hint_l := _label("WASD 移动 · 鼠标 视角 · E 互动\nF 手电 · Shift 奔跑 · Ctrl 蹲伏 · M 静音", 11, Color.html("6f695c"), hud_root)
	hint_l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint_l.position = Vector2(-260, -54)
	hint_l.custom_minimum_size = Vector2(246, 40)
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.65)
	crosshair.size = Vector2(4, 4)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-2, -2)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(crosshair)
	crosshair.visible = false
	prompt = _label("", 15, Color.html("e8dfc8"), hud_root)
	prompt.set_anchors_preset(Control.PRESET_CENTER)
	prompt.position = Vector2(-240, 58)
	prompt.custom_minimum_size = Vector2(480, 22)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	prompt.add_theme_constant_override("outline_size", 6)
	prompt.visible = false
	subtitle = _label("", 16, Color.html("d6cdb8"), hud_root)
	subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle.position = Vector2(-460, -140)
	subtitle.custom_minimum_size = Vector2(920, 60)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	subtitle.add_theme_constant_override("outline_size", 6)

func render_hud(g) -> void:
	if not hud_root.visible:
		return
	sanity_val.text = str(ceil(g.sanity))
	sanity_fill.size.x = 166 * clampf(g.sanity, 0.0, 100.0) / 100.0
	battery_val.text = str(ceil(g.battery)) if g.has_flash else "--"
	battery_fill.size.x = 166 * (clampf(g.battery, 0.0, 100.0) / 100.0 if g.has_flash else 0.0)
	stamina_fill.size.x = 166 * clampf(g.stamina, 0.0, 100.0) / 100.0
	var t := int(minf(359.0, g.time))
	time_val.text = "%d:%02d" % [int(t / 60), t % 60]
	floor_val.text = g.floor_id
	inv_bat_key.text = "电池"
	inv_bat_key.get_parent().get_child(1).text = "×%d(按1使用)" % g.batteries
	inv_a_val.text = "×%d(按2)" % g.pills["a"]
	inv_b_val.text = "×%d(按3)" % g.pills["b"]
	inv_candle_val.text = "×%d(按4使用)" % g.candles
	inv_relic_val.text = "%d / 13" % g.relics
	inv_a_key.add_theme_color_override("font_color", Color.html("9cc47a") if g.knows_pills else Color.html("9a917f"))
	inv_b_key.add_theme_color_override("font_color", Color.html("a0483e") if g.knows_pills else Color.html("9a917f"))
	set_distort(2.0 if g.sanity < 25.0 else (1.0 if g.sanity < 50.0 else 0.0))

func set_objective(t: String) -> void:
	objective.text = t

func show_msg(text: String, dur := 4.2) -> void:
	subtitle.text = text
	subtitle.modulate.a = 1.0
	if _sub_hide_tween and _sub_hide_tween.is_valid():
		_sub_hide_tween.kill()
	_sub_hide_tween = subtitle.create_tween()
	_sub_hide_tween.tween_interval(dur)
	_sub_hide_tween.tween_property(subtitle, "modulate:a", 0.0, 1.0)

func set_hud_visible(on: bool) -> void:
	hud_root.visible = on
	crosshair.visible = on

func set_prompt(text: String) -> void:
	prompt.visible = not text.is_empty()
	prompt.text = text

# ---------- 弹窗 ----------

func _build_modal() -> void:
	var layer := _layer(50)
	modal_root = Control.new()
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.theme = _theme()
	modal_root.visible = false
	layer.add_child(modal_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(dim)
	modal_panel_build()
	modal_countdown = Timer.new()
	modal_countdown.wait_time = 0.1
	add_child(modal_countdown)

var modal_panel: PanelContainer

func modal_panel_build() -> void:
	modal_panel = PanelContainer.new()
	modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	modal_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	modal_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	modal_panel.custom_minimum_size = Vector2(560, 0)
	modal_panel.add_theme_stylebox_override("panel", _sbox_px(Color.html("12100e"), Color.html("4a4237"), 6, 30, 30, 26, 26))
	modal_root.add_child(modal_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	modal_panel.add_child(v)
	modal_title = _label("", 19, Color.html("ddd2ba"), v)
	modal_timer_wrap = Control.new()
	modal_timer_wrap.custom_minimum_size = Vector2(500, 3)
	v.add_child(modal_timer_wrap)
	var tb_bg := ColorRect.new()
	tb_bg.color = Color(1, 1, 1, 0.08)
	tb_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	tb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_timer_wrap.add_child(tb_bg)
	modal_timer_bar = ColorRect.new()
	modal_timer_bar.color = Color.html("a0483e")
	modal_timer_bar.size = Vector2(500, 3)
	modal_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_timer_wrap.add_child(modal_timer_bar)
	modal_timer_wrap.visible = false
	modal_body = _label("", 14, Color.html("b3aa97"), v)
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.custom_minimum_size = Vector2(500, 0)
	modal_choices = VBoxContainer.new()
	modal_choices.add_theme_constant_override("separation", 10)
	v.add_child(modal_choices)

func _on_modal_tick() -> void:
	_modal_left -= 0.1
	modal_timer_bar.size.x = 500 * maxf(0.0, _modal_left / _modal_total)
	if _modal_left <= 0.0:
		modal_countdown.stop()
		if modal_timeout_fn.is_valid():
			modal_timeout_fn.call()

func open_modal(cfg: Dictionary) -> void:
	modal_root.visible = true
	modal_title.text = cfg.get("title", "")
	modal_body.text = cfg.get("body", "")
	for c in modal_choices.get_children():
		c.queue_free()
	if cfg.has("countdown"):
		modal_timer_wrap.visible = true
		_modal_total = cfg["countdown"]
		_modal_left = _modal_total
		modal_timer_bar.size.x = 500
		modal_timeout_fn = cfg.get("on_timeout", func(): close_modal())
		if not modal_countdown.timeout.is_connected(_on_modal_tick):
			modal_countdown.timeout.connect(_on_modal_tick)
		modal_countdown.start()
	else:
		modal_timer_wrap.visible = false
		modal_countdown.stop()
	for ch: Dictionary in cfg.get("choices", []):
		var b := Button.new()
		b.text = ch.get("text", "")
		if ch.get("disabled", false):
			b.disabled = true
			if ch.has("reason"):
				b.text += "(%s)" % ch["reason"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		_style_button(b)
		var fn: Callable = ch.get("fn", Callable())
		b.pressed.connect(func() -> void:
			modal_countdown.stop()
			if fn.is_valid():
				fn.call())
		modal_choices.add_child(b)

func close_modal() -> void:
	modal_root.visible = false
	modal_countdown.stop()

func modal_visible() -> bool:
	return modal_root.visible

func find_choice(text: String, starts_with := false) -> Button:
	for c in modal_choices.get_children():
		if c is Button and c.visible and not c.disabled:
			if (starts_with and c.text.strip_edges().begins_with(text)) or (not starts_with and text in c.text):
				return c
	return null

# ---------- 转场 / 全屏画面 ----------

func _build_fade() -> void:
	var layer := _layer(60)
	fade_root = Control.new()
	fade_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_root.theme = _theme()
	fade_root.visible = false
	fade_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade_root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_root.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_root.add_child(v)
	fade_label = _label("", 44, Color.html("cfc6b0"), v)
	fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade_label.custom_minimum_size = Vector2(400, 60)
	fade_sub = _label("", 13, Color.html("6f695c"), v)
	fade_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade_sub.custom_minimum_size = Vector2(400, 20)

func fade_show(label_text: String, sub: String) -> void:
	fade_root.visible = true
	fade_root.modulate.a = 1.0
	fade_label.text = label_text
	fade_sub.text = sub

func fade_out() -> void:
	fade_root.visible = true
	var tw := fade_root.create_tween()
	tw.tween_property(fade_root, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func() -> void:
		fade_root.visible = false
		fade_root.modulate.a = 1.0)

func _build_screens() -> void:
	var layer := _layer(70)
	title_screen = Control.new()
	title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_screen.theme = _theme()
	layer.add_child(title_screen)
	var tv := VBoxContainer.new()
	tv.set_anchors_preset(Control.PRESET_CENTER)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_screen.add_child(tv)
	var th := _label("无 回 楼", 52, Color.html("d8cfba"), tv)
	th.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	th.custom_minimum_size = Vector2(640, 70)
	th.add_theme_color_override("font_outline_color", Color(140.0/255, 120.0/255, 80.0/255, 0.25))
	th.add_theme_constant_override("outline_size", 14)
	var ts := _label("一栋只在午夜出现的老旧居民楼 · Demo(1F–13F + B1/B2)", 13, Color.html("7d7566"), tv)
	ts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spacer(tv, 34)
	var sms := Panel.new()
	sms.add_theme_stylebox_override("panel", _sbox_px(Color.html("16181d"), Color.html("2c3038"), 10, 18, 18, 14, 14))
	sms.custom_minimum_size = Vector2(420, 0)
	tv.add_child(sms)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	sms.add_child(sv)
	_label("来自 林音 · 23:47", 11, Color.html("67707e"), sv)
	_label("哥,我在1304等你。\n别坐电梯,别相信穿保安服的人。", 15, Color.html("c9d2e0"), sv)
	_spacer(tv, 34)
	var start := Button.new()
	start.text = "进 入 大 楼"
	start.add_theme_font_size_override("font_size", 17)
	start.add_theme_color_override("font_color", Color.html("d0c7b0"))
	start.add_theme_color_override("font_hover_color", Color.html("f0e7cc"))
	start.custom_minimum_size = Vector2(240, 48)
	start.add_theme_stylebox_override("normal", _sbox_px(Color(0, 0, 0, 0), Color.html("5a5245"), 4, 46, 46, 13, 13))
	start.add_theme_stylebox_override("hover", _sbox_px(Color.html("1d1a15"), Color.html("8a7d63"), 4, 46, 46, 13, 13))
	start.pressed.connect(func(): start_requested.emit())
	tv.add_child(start)
	_spacer(tv, 30)
	var ctrl := _label("WASD 移动 · 鼠标 视角 · E 互动 · F 手电 · Shift 奔跑 · Ctrl 蹲伏\n数字键 1/2/3/4 使用背包道具 · M 静音", 12, Color.html("6b6457"), tv)
	ctrl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctrl.custom_minimum_size = Vector2(640, 40)
	_spacer(tv, 18)
	var warn := _label("建议佩戴耳机 · 含恐怖元素 · 规则有真有假,今晚——请自己判断", 11, Color.html("5a4438"), tv)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.custom_minimum_size = Vector2(640, 20)

	ending_screen = Control.new()
	ending_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	ending_screen.theme = _theme()
	ending_screen.visible = false
	layer.add_child(ending_screen)
	var click_catch := Button.new()
	click_catch.flat = true
	click_catch.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_catch.pressed.connect(func(): ending_advanced.emit())
	ending_screen.add_child(click_catch)
	var ev := VBoxContainer.new()
	ev.set_anchors_preset(Control.PRESET_CENTER)
	ev.alignment = BoxContainer.ALIGNMENT_CENTER
	ev.add_theme_constant_override("separation", 26)
	ev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending_screen.add_child(ev)
	ending_title = _label("", 30, Color.html("d8cfba"), ev)
	ending_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_title.custom_minimum_size = Vector2(560, 44)
	ending_text = _label("", 16, Color.html("c8bfa9"), ev)
	ending_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_text.custom_minimum_size = Vector2(560, 120)
	ending_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_hint = _label("—— 点击继续 ——", 12, Color.html("6f6759"), ev)
	ending_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_stats = RichTextLabel.new()
	ending_stats.bbcode_enabled = true
	ending_stats.fit_content = true
	ending_stats.custom_minimum_size = Vector2(560, 0)
	ending_stats.visible = false
	ev.add_child(ending_stats)
	restart_btn = Button.new()
	restart_btn.text = "回到标题"
	restart_btn.visible = false
	_style_button(restart_btn)
	restart_btn.pressed.connect(func(): restart_requested.emit())
	ev.add_child(restart_btn)

	gameover_screen = Control.new()
	gameover_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	gameover_screen.theme = _theme()
	gameover_screen.visible = false
	layer.add_child(gameover_screen)
	var gv := VBoxContainer.new()
	gv.set_anchors_preset(Control.PRESET_CENTER)
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	gv.add_theme_constant_override("separation", 24)
	gv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameover_screen.add_child(gv)
	var gt := _label("你 留 在 了 楼 里", 34, Color.html("8e3b32"), gv)
	gt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gt.custom_minimum_size = Vector2(560, 50)
	go_text = _label("", 15, Color.html("a89f8d"), gv)
	go_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	go_text.custom_minimum_size = Vector2(520, 0)
	go_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 12)
	gv.add_child(gh)
	var retry := Button.new()
	retry.text = "从本层重新开始"
	_style_button(retry)
	retry.pressed.connect(func(): retry_requested.emit())
	gh.add_child(retry)
	var to_title := Button.new()
	to_title.text = "回到标题"
	_style_button(to_title)
	to_title.pressed.connect(func(): to_title_requested.emit())
	gh.add_child(to_title)

	var pl := _layer(40)
	pause_hint = Control.new()
	pause_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_hint.visible = false
	pl.add_child(pause_hint)
	var pdim := ColorRect.new()
	pdim.color = Color(0, 0, 0, 0.55)
	pdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_hint.add_child(pdim)
	var ptext := _label("已暂停 —— 点击画面继续", 16, Color.html("c9c0aa"), pause_hint)
	ptext.set_anchors_preset(Control.PRESET_CENTER)
	ptext.position = Vector2(-140, -12)
	ptext.custom_minimum_size = Vector2(280, 24)
	ptext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_hint.gui_input.connect(func(ev2: InputEvent) -> void:
		if ev2 is InputEventMouseButton and ev2.pressed:
			pause_resumed.emit())

func show_title(on: bool) -> void:
	title_screen.visible = on

func show_ending(title_text: String, text: String) -> void:
	ending_screen.visible = true
	ending_title.text = title_text
	ending_text.text = text
	ending_hint.visible = true
	ending_stats.visible = false
	restart_btn.visible = false

func show_gameover(text: String) -> void:
	gameover_screen.visible = true
	go_text.text = text

func show_pause(on: bool) -> void:
	pause_hint.visible = on

# ---------- 调试栏 ----------

func build_debug(buttons: Array) -> void:
	var layer := _layer(80)
	debug_bar = VBoxContainer.new()
	debug_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_bar.position = Vector2(-110, 60)
	debug_bar.add_theme_constant_override("separation", 4)
	layer.add_child(debug_bar)
	for entry: Array in buttons:
		var b := Button.new()
		b.text = entry[0]
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", Color.html("99cc99"))
		b.add_theme_color_override("font_hover_color", Color.html("cceecc"))
		b.pressed.connect(func(): (entry[1] as Callable).call())
		debug_bar.add_child(b)

func _build_all() -> void:
	_build_effect_layer()
	_build_hud()
	_build_modal()
	_build_fade()
	_build_screens()
