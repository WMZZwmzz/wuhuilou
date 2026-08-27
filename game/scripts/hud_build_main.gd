class_name HudBuildMain
extends RefCounted
## HUD 常驻层与弹窗面板的构建(自 hud.gd 纯搬迁,C5):状态条/楼层时钟/背包/提示等
## 左右上面板、弹窗纸纹容器。运行时更新逻辑(render_hud/open_modal 等)仍留在 Hud。

static func inv_line(h, parent: VBoxContainer, key_text: String, val_text: String) -> Dictionary:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key: Label = h._label(key_text, 12, h.COL["text_dim"], hb)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val: Label = h._label(val_text, 12, h.COL["text_body"], hb)
	parent.add_child(hb)
	return {"key": key, "val": val}

static func build_hud(h) -> void:
	var layer: CanvasLayer = h._layer(20)
	h.hud_root = Control.new()
	h.hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.hud_root.theme = h._theme()
	layer.add_child(h.hud_root)
	h.hud_root.visible = false

	# —— 左上:状态(理智 / 电量 / 体力) ——
	var status: PanelContainer = h._corner_panel(Control.PRESET_TOP_LEFT, 14, 14)
	h.hud_root.add_child(status)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(v)
	var stat_row := func(t: String) -> Dictionary:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l: Label = h._label(t, 12, h.COL["text_dim"], hb)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(hb)
		return {"hb": hb}
	var r1: Dictionary = stat_row.call("理 智")
	h.sanity_val = h._label("100", 12, h.COL["text_body"], r1["hb"])
	var sb1: Dictionary = h._bar(v, h.COL["sanity_a"], h.COL["sanity_b"])
	h.sanity_track = sb1["track"]
	h.sanity_fill = sb1["fill"]
	var r2: Dictionary = stat_row.call("电 量")
	h.battery_val = h._label("--", 12, h.COL["text_body"], r2["hb"])
	# 电量小图标(纯描边矩形 + 内部填充随电量伸缩,参考稿 .batt-icon)
	var batt_icon := Panel.new()
	var bis := StyleBoxFlat.new()
	bis.bg_color = Color(0, 0, 0, 0)
	bis.border_color = h.COL["text_dim"]
	bis.set_border_width_all(1)
	bis.set_corner_radius_all(0)
	batt_icon.add_theme_stylebox_override("panel", bis)
	batt_icon.custom_minimum_size = Vector2(15, 9)
	batt_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	batt_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r2["hb"].add_child(batt_icon)
	r2["hb"].move_child(batt_icon, 0)
	h.batt_fill_rect = ColorRect.new()
	h.batt_fill_rect.color = h.COL["text_dim"]
	h.batt_fill_rect.position = Vector2(2, 2)
	h.batt_fill_rect.size = Vector2(0, 5)
	h.batt_fill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	batt_icon.add_child(h.batt_fill_rect)
	var sb2: Dictionary = h._bar(v, h.COL["battery_a"], h.COL["battery_b"])
	h.battery_track = sb2["track"]
	h.battery_fill = sb2["fill"]
	stat_row.call("体 力")
	var sb3: Dictionary = h._bar(v, h.COL["stamina_a"], h.COL["stamina_b"])
	h.stamina_track = sb3["track"]
	h.stamina_fill = sb3["fill"]
	# 理智条双渐变:常态冷色 / 低理智血色(参考稿 #app.low 换色)
	h._sanity_norm_tex = h.sanity_fill.texture
	var lg := Gradient.new()
	lg.set_color(0, Color.html("6d1010"))
	lg.set_color(1, Color.html("c22a2a"))
	h._sanity_low_tex = GradientTexture1D.new()
	h._sanity_low_tex.gradient = lg
	h._sanity_low_tex.width = 64

	# —— 右上:楼层与时钟 ——
	var clock: PanelContainer = h._corner_panel(Control.PRESET_TOP_RIGHT, -14, 14)
	h.hud_root.add_child(clock)
	var cv := VBoxContainer.new()
	cv.custom_minimum_size = Vector2(96, 0)
	cv.add_theme_constant_override("separation", 2)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.add_child(cv)
	h.floor_val = h._label("1F", 24, h.COL["text_main"], cv)
	h.floor_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.floor_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.time_val = h._label("0:00", 16, h.COL["danger"], cv)
	h.time_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.time_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# —— 顶中:当前目标(比例锚点宽度,自适应分辨率) ——
	h.objective = h._label("找到妹妹 —— 1304", 13, h.COL["text_dim"], h.hud_root)
	h.objective.set_anchor(SIDE_LEFT, 0.25)
	h.objective.set_anchor(SIDE_RIGHT, 0.75)
	h.objective.set_anchor(SIDE_TOP, 0.0)
	h.objective.set_anchor(SIDE_BOTTOM, 0.0)
	h.objective.offset_left = 0
	h.objective.offset_right = 0
	h.objective.offset_top = 14
	h.objective.offset_bottom = 40
	h.objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.objective.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	h.objective.add_theme_constant_override("outline_size", 4)

	# —— 左下:背包 ——
	var inv: PanelContainer = h._corner_panel(Control.PRESET_BOTTOM_LEFT, 14, -14)
	h.hud_root.add_child(inv)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 5)
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv.add_child(iv)
	h._label("背 包", 11, h.COL["text_faint"], iv)
	var isep := ColorRect.new()
	isep.color = h.COL["line"]
	isep.custom_minimum_size = Vector2(0, 1)
	isep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iv.add_child(isep)
	var bat_line := inv_line(h, iv, "电池", "×1(按1使用)")
	h.inv_bat_key = bat_line["key"]
	var a_line := inv_line(h, iv, "药瓶A(批号2048)", "×0(按2)")
	h.inv_a_key = a_line["key"]
	h.inv_a_val = a_line["val"]
	var b_line := inv_line(h, iv, "药瓶B(批号2051)", "×0(按3)")
	h.inv_b_key = b_line["key"]
	h.inv_b_val = b_line["val"]
	var candle_line := inv_line(h, iv, "香烛", "×0(按4使用)")
	h.inv_candle_key = candle_line["key"]
	h.inv_candle_val = candle_line["val"]
	var relic_line := inv_line(h, iv, "遗物", "0 / 13")
	h.inv_relic_key = relic_line["key"]
	h.inv_relic_val = relic_line["val"]

	# —— 右下:操作提示 ——
	var hint_l: Label = h._label("WASD 移动 · 鼠标 视角 · E 互动\nF 手电 · Shift 奔跑 · Ctrl 蹲伏 · M 静音", 12, h.COL["text_faint"], h.hud_root)
	hint_l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint_l.offset_left = -330
	hint_l.offset_top = -70
	hint_l.offset_right = -16
	hint_l.offset_bottom = -16
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	hint_l.add_theme_constant_override("outline_size", 4)

	h.crosshair = ColorRect.new()
	h.crosshair.color = Color(1, 1, 1, 0.65)
	h.crosshair.size = Vector2(4, 4)
	h.crosshair.set_anchors_preset(Control.PRESET_CENTER)
	h.crosshair.position = Vector2(-2, -2)
	h.crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.hud_root.add_child(h.crosshair)
	h.crosshair.visible = false
	# 准星外圈光环(细环微亮,参考稿 .hud-crosshair 的双圈)
	h.crosshair_ring = TextureRect.new()
	var rg := Gradient.new()
	rg.offsets = PackedFloat32Array([0.0, 0.55, 0.68, 1.0])
	rg.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.26), Color(1, 1, 1, 0.0)])
	var rgt := GradientTexture2D.new()
	rgt.gradient = rg
	rgt.fill = GradientTexture2D.FILL_RADIAL
	rgt.fill_from = Vector2(0.5, 0.5)
	rgt.fill_to = Vector2(0.5, 0.0)
	rgt.width = 24
	rgt.height = 24
	h.crosshair_ring.texture = rgt
	h.crosshair_ring.set_anchors_preset(Control.PRESET_CENTER)
	h.crosshair_ring.position = Vector2(-12, -12)
	h.crosshair_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.hud_root.add_child(h.crosshair_ring)
	h.crosshair_ring.visible = false
	h.prompt = h._label("", 15, h.COL["text_strong"], h.hud_root)
	h.prompt.set_anchors_preset(Control.PRESET_CENTER)
	h.prompt.position = Vector2(-240, 58)
	h.prompt.custom_minimum_size = Vector2(480, 22)
	h.prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	h.prompt.add_theme_constant_override("outline_size", 6)
	h.prompt.visible = false
	h.subtitle = h._label("", 16, h.COL["text_main"], h.hud_root)
	h.subtitle.set_anchor(SIDE_LEFT, 0.08)
	h.subtitle.set_anchor(SIDE_RIGHT, 0.92)
	h.subtitle.set_anchor(SIDE_TOP, 1.0)
	h.subtitle.set_anchor(SIDE_BOTTOM, 1.0)
	h.subtitle.offset_left = 0
	h.subtitle.offset_right = 0
	h.subtitle.offset_top = -190
	h.subtitle.offset_bottom = -90
	h.subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	h.subtitle.add_theme_constant_override("outline_size", 6)
	# 侵蚀闪烁作用的目标标签(时钟/理智数值/目标/楼层——均无外部 modulate 依赖)
	h._flicker_labels = [h.time_val, h.sanity_val, h.objective, h.floor_val]
	# HUD 分块错落入场的目标(参考稿 fadeUp 节奏)
	h._hud_blocks = [status, clock, h.objective, inv, hint_l]

static func build_modal(h) -> void:
	var layer: CanvasLayer = h._layer(50)
	h.modal_root = Control.new()
	h.modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.modal_root.theme = h._theme()
	h.modal_root.visible = false
	layer.add_child(h.modal_root)
	h.modal_dim = ColorRect.new()
	h.modal_dim.color = Color(0, 0, 0, 0.62)
	h.modal_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.modal_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.modal_root.add_child(h.modal_dim)
	modal_panel_build(h)
	h.modal_countdown = Timer.new()
	h.modal_countdown.wait_time = 0.1
	h.add_child(h.modal_countdown)

static func modal_panel_build(h) -> void:
	h.modal_panel = PanelContainer.new()
	h.modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	h.modal_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	h.modal_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	h.modal_panel.custom_minimum_size = Vector2(560, 0)
	# 做旧纸底(90 年代档案/住户通知质感):纸纹平铺 + 暗纸染色,四边 8px 磨损边;
	# headless 无纸纹时退纯色 StyleBoxFlat(仅 QA 用,渲染结果不受影响)
	var msb: StyleBox = null
	if h._paper_tex != null:
		var tsb := StyleBoxTexture.new()
		tsb.texture = h._paper_tex
		tsb.modulate_color = h.COL["modal_paper"]
		tsb.texture_margin_left = 8
		tsb.texture_margin_right = 8
		tsb.texture_margin_top = 8
		tsb.texture_margin_bottom = 8
		tsb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		tsb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		msb = tsb
	else:
		msb = h._sb(h.COL["modal_bg"], Color.TRANSPARENT, h.RADIUS["modal"], 32, 26)
	msb.content_margin_left = 32
	msb.content_margin_right = 32
	msb.content_margin_top = 26
	msb.content_margin_bottom = 26
	h.modal_panel.add_theme_stylebox_override("panel", msb)
	h._tint_panels.append({"sb": msb, "bg": h.COL["modal_paper"], "border": Color.TRANSPARENT})
	h.modal_panel.resized.connect(func() -> void:
		h.modal_panel.pivot_offset = h.modal_panel.size * 0.5)
	h.modal_root.add_child(h.modal_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	h.modal_panel.add_child(v)
	h.modal_title = h._label("", 22, h.COL["text_main"], v)
	var sep := ColorRect.new()
	sep.color = Color(h.COL["cinnabar"].r, h.COL["cinnabar"].g, h.COL["cinnabar"].b, 0.5)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sep)
	# 倒计时条:圆角轨道 + 圆角填充,剩余 <25% 时转为亮红
	h.modal_timer_track = Panel.new()
	h.modal_timer_track.custom_minimum_size = Vector2(0, 4)
	h.modal_timer_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.modal_timer_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.modal_timer_track.add_theme_stylebox_override("panel", h._sb(h.COL["bar_track"], Color(0, 0, 0, 0), 2, 0, 0, false))
	h.modal_timer_fill_sb = h._sb(h.COL["danger"], Color(0, 0, 0, 0), 2, 0, 0, false)
	h.modal_timer_fill = Panel.new()
	h.modal_timer_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.modal_timer_fill.add_theme_stylebox_override("panel", h.modal_timer_fill_sb)
	h.modal_timer_track.add_child(h.modal_timer_fill)
	v.add_child(h.modal_timer_track)
	h.modal_timer_track.visible = false
	h.modal_body = h._label("", 14, h.COL["text_body"], v)
	h.modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.modal_body.custom_minimum_size = Vector2(500, 0)
	h.modal_choices = VBoxContainer.new()
	h.modal_choices.add_theme_constant_override("separation", 10)
	v.add_child(h.modal_choices)
