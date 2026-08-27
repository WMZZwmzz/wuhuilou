class_name HudScreens
extends RefCounted
## 转场 / 全屏画面(标题 / 结局 / 死亡 / 暂停)的构建(自 hud.gd 纯搬迁,C5)。
## 运行时切换逻辑(show_title/show_ending 等)仍留在 Hud。

static func spacer(parent: Control, hgt: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, hgt)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)

static func build_fade(h) -> void:
	var layer: CanvasLayer = h._layer(60)
	h.fade_root = Control.new()
	h.fade_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.fade_root.theme = h._theme()
	h.fade_root.visible = false
	h.fade_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(h.fade_root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.fade_root.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.fade_root.add_child(v)
	h.fade_label = h._label("", 44, Color.html("cfc6b0"), v)
	h.fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.fade_label.custom_minimum_size = Vector2(400, 60)
	h.fade_sub = h._label("", 13, h.COL["text_faint"], v)
	h.fade_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.fade_sub.custom_minimum_size = Vector2(400, 20)

static func build_screens(h) -> void:
	var layer: CanvasLayer = h._layer(70)
	h.title_screen = Control.new()
	h.title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.title_screen.theme = h._theme()
	layer.add_child(h.title_screen)
	# 轻压暗背景,提升标题文本对比度
	var tdim := ColorRect.new()
	tdim.color = Color(0, 0, 0, 0.42)
	tdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	tdim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.title_screen.add_child(tdim)
	var tv := VBoxContainer.new()
	tv.set_anchors_preset(Control.PRESET_CENTER)
	tv.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tv.grow_vertical = Control.GROW_DIRECTION_BOTH
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.title_screen.add_child(tv)
	# 顶部小副题(宽字距,参考稿 .title-sub)
	var top_sub: Label = h._label("一 栋 有 去 无 回 的 楼", 12, h.COL["text_faint"], tv)
	top_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spacer(tv, 20)
	# 标题行:大字(旧印刷褪色) + 右上朱砂印章
	var trow := Control.new()
	trow.custom_minimum_size = Vector2(640, 92)
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(trow)
	# 烛火呼吸光晕(暖色径向,缓慢明暗,参考稿 .title-glow)
	var glow := TextureRect.new()
	var gg := Gradient.new()
	gg.set_color(0, Color(1.0, 0.72, 0.42, 0.09))
	gg.set_color(1, Color(1.0, 0.72, 0.42, 0.0))
	var ggt := GradientTexture2D.new()
	ggt.gradient = gg
	ggt.fill = GradientTexture2D.FILL_RADIAL
	ggt.fill_from = Vector2(0.5, 0.5)
	ggt.fill_to = Vector2(0.5, 0.0)
	ggt.width = 256
	ggt.height = 256
	glow.texture = ggt
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.set_anchors_preset(Control.PRESET_CENTER)
	glow.position = Vector2(-240, -260)
	glow.size = Vector2(480, 480)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trow.add_child(glow)
	var gtw: Tween = glow.create_tween().set_loops()
	gtw.tween_property(glow, "modulate:a", 1.0, 3.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	gtw.tween_property(glow, "modulate:a", 0.45, 3.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var th: Label = h._label("无 回 楼", 64, h.COL["text_main"], trow)
	th.set_anchors_preset(Control.PRESET_CENTER)
	th.grow_horizontal = Control.GROW_DIRECTION_BOTH
	th.grow_vertical = Control.GROW_DIRECTION_BOTH
	th.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	th.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	th.modulate = Color(0.96, 0.94, 0.90)
	th.add_theme_color_override("font_outline_color", Color(96.0/255, 74.0/255, 42.0/255, 0.30))
	th.add_theme_constant_override("outline_size", 12)
	# 大字 glitch:红/青错位拷贝周期闪断(参考稿 .glitch 常驻循环)
	var tgp: Dictionary = h._glitch_pair(th, 64)
	tgp["periodic"] = true
	tgp["next"] = 3.5
	var seal := PanelContainer.new()
	var seal_sb := StyleBoxFlat.new()
	seal_sb.bg_color = Color(0, 0, 0, 0)
	seal_sb.border_color = Color(h.COL["cinnabar"].r, h.COL["cinnabar"].g, h.COL["cinnabar"].b, 0.88)
	seal_sb.set_border_width_all(2)
	seal_sb.set_corner_radius_all(0)
	seal_sb.content_margin_left = 9
	seal_sb.content_margin_right = 9
	seal_sb.content_margin_top = 4
	seal_sb.content_margin_bottom = 6
	seal.add_theme_stylebox_override("panel", seal_sb)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.rotation = 0.1
	seal.position = Vector2(452, 2)
	trow.add_child(seal)
	var seal_text: Label = h._label("封", 26, h.COL["cinnabar"], seal, true)
	seal_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.25))
	seal_text.add_theme_constant_override("outline_size", 2)
	# 朱红分隔线 + 英文小字(参考稿 .title-head::after / .title-en)
	spacer(tv, 8)
	var div := TextureRect.new()
	var dg := Gradient.new()
	dg.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	dg.colors = PackedColorArray([
		Color(0.72, 0.25, 0.20, 0.0), Color(0.72, 0.25, 0.20, 0.62), Color(0.72, 0.25, 0.20, 0.0)])
	var dgt := GradientTexture1D.new()
	dgt.gradient = dg
	dgt.width = 128
	div.texture = dgt
	div.stretch_mode = TextureRect.STRETCH_SCALE
	div.custom_minimum_size = Vector2(150, 2)
	div.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(div)
	var en: Label = h._label("— T H E   T O W E R   O F   N O   R E T U R N —", 10, h.COL["text_faint"], tv)
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spacer(tv, 14)
	var ts: Label = h._label("一栋只在午夜出现的老旧居民楼 · Demo(1F–13F + B1/B2)", 13, h.COL["text_dim"], tv)
	ts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spacer(tv, 34)
	# 妹妹短信:旧信纸质感(纸纹平铺)+ 楷体手写(headless 无纸纹时退纯色,仅 QA 用)
	var sms := PanelContainer.new()
	if h._paper_tex != null:
		var tsb := StyleBoxTexture.new()
		tsb.texture = h._paper_tex
		tsb.modulate_color = Color(0.20, 0.175, 0.12)
		tsb.texture_margin_left = 8
		tsb.texture_margin_right = 8
		tsb.texture_margin_top = 8
		tsb.texture_margin_bottom = 8
		tsb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		tsb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		tsb.content_margin_left = 18
		tsb.content_margin_right = 18
		tsb.content_margin_top = 14
		tsb.content_margin_bottom = 14
		sms.add_theme_stylebox_override("panel", tsb)
	else:
		sms.add_theme_stylebox_override("panel", h._sb(Color(0.10, 0.085, 0.058), Color.TRANSPARENT, h.RADIUS["panel"], 18, 14))
	sms.custom_minimum_size = Vector2(420, 0)
	sms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(sms)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	sms.add_child(sv)
	h._label("来自 林音 · 23:47", 11, h.COL["text_dim"], sv)
	h._label("哥,我在1304等你。\n别坐电梯,别相信穿保安服的人。", 16, Color.html("d8ccb0"), sv, true)
	spacer(tv, 34)
	# 幽灵菜单按钮:悬停浮现「」括号 + 微放大(参考稿 .gbtn)
	var start: Button = h._menu_button("进 入 大 楼", 17, tv)
	start.pressed.connect(func(): h.start_requested.emit())
	# 呼吸脉动吸引视线(亮度 1.0↔1.05 循环,不影响可读性)
	var pulse: Tween = start.create_tween().set_loops()
	pulse.tween_property(start, "modulate", Color(1.05, 1.05, 1.05, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(start, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	spacer(tv, 30)
	var ctrl: Label = h._label("WASD 移动 · 鼠标 视角 · E 互动 · F 手电 · Shift 奔跑 · Ctrl 蹲伏\n数字键 1/2/3/4 使用背包道具 · M 静音", 12, h.COL["text_faint"], tv)
	ctrl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctrl.custom_minimum_size = Vector2(640, 40)
	spacer(tv, 18)
	var warn: Label = h._label("建议佩戴耳机 · 含恐怖元素 · 规则有真有假,今晚——请自己判断", 11, Color(h.COL["cinnabar"].r, h.COL["cinnabar"].g, h.COL["cinnabar"].b, 0.85), tv, true)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.custom_minimum_size = Vector2(640, 20)

	h.ending_screen = Control.new()
	h.ending_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.ending_screen.theme = h._theme()
	h.ending_screen.visible = false
	layer.add_child(h.ending_screen)
	var edim := ColorRect.new()
	edim.color = Color(0, 0, 0, 0.6)
	edim.set_anchors_preset(Control.PRESET_FULL_RECT)
	edim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.ending_screen.add_child(edim)
	var click_catch := Button.new()
	click_catch.flat = true
	click_catch.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_catch.pressed.connect(func(): h.ending_advanced.emit())
	h.ending_screen.add_child(click_catch)
	var ev := VBoxContainer.new()
	ev.set_anchors_preset(Control.PRESET_CENTER)
	ev.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ev.grow_vertical = Control.GROW_DIRECTION_BOTH
	ev.alignment = BoxContainer.ALIGNMENT_CENTER
	ev.add_theme_constant_override("separation", 24)
	ev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.ending_screen.add_child(ev)
	h.ending_title = h._label("", 32, h.COL["text_main"], ev)
	h.ending_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.ending_title.custom_minimum_size = Vector2(560, 46)
	h._ending_glitch = h._glitch_pair(h.ending_title, 32)
	h.ending_text = h._label("", 16, h.COL["text_body"], ev)
	h.ending_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.ending_text.custom_minimum_size = Vector2(560, 120)
	h.ending_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.ending_hint = h._label("—— 点击继续 ——", 12, h.COL["text_faint"], ev)
	h.ending_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 呼吸提示:透明度 1.0↔0.4 循环
	var hp: Tween = h.ending_hint.create_tween().set_loops()
	hp.tween_property(h.ending_hint, "modulate:a", 0.4, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hp.tween_property(h.ending_hint, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	h.ending_stats = RichTextLabel.new()
	h.ending_stats.bbcode_enabled = true
	h.ending_stats.fit_content = true
	h.ending_stats.custom_minimum_size = Vector2(560, 0)
	h.ending_stats.visible = false
	ev.add_child(h.ending_stats)
	h.restart_btn = h._menu_button("回 到 标 题", 15, ev)
	h.restart_btn.visible = false
	h.restart_btn.pressed.connect(func(): h.restart_requested.emit())

	h.gameover_screen = Control.new()
	h.gameover_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.gameover_screen.theme = h._theme()
	h.gameover_screen.visible = false
	layer.add_child(h.gameover_screen)
	var gdim := ColorRect.new()
	gdim.color = Color(0, 0, 0, 0.65)
	gdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	gdim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.gameover_screen.add_child(gdim)
	var gv := VBoxContainer.new()
	gv.set_anchors_preset(Control.PRESET_CENTER)
	gv.grow_horizontal = Control.GROW_DIRECTION_BOTH
	gv.grow_vertical = Control.GROW_DIRECTION_BOTH
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	gv.add_theme_constant_override("separation", 24)
	gv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.gameover_screen.add_child(gv)
	# 「卒」字朱砂印章:盖棺定论式的死亡标记
	var zu := PanelContainer.new()
	var zu_sb := StyleBoxFlat.new()
	zu_sb.bg_color = Color(0, 0, 0, 0)
	zu_sb.border_color = Color(h.COL["cinnabar"].r, h.COL["cinnabar"].g, h.COL["cinnabar"].b, 0.92)
	zu_sb.set_border_width_all(2)
	zu_sb.set_corner_radius_all(0)
	zu_sb.content_margin_left = 10
	zu_sb.content_margin_right = 10
	zu_sb.content_margin_top = 6
	zu_sb.content_margin_bottom = 8
	zu.add_theme_stylebox_override("panel", zu_sb)
	zu.custom_minimum_size = Vector2(84, 84)
	zu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	zu.pivot_offset = Vector2(42, 42)
	zu.rotation = 0.14
	gv.add_child(zu)
	h._go_zu = zu
	var zu_text: Label = h._label("卒", 54, h.COL["cinnabar"], zu, true)
	zu_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gt: Label = h._label("你 留 在 了 楼 里", 34, Color.html("8e3b32"), gv)
	gt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gt.custom_minimum_size = Vector2(560, 50)
	h._go_glitch = h._glitch_pair(gt, 34)
	h.go_text = h._label("", 16, h.COL["text_body"], gv, true)
	h.go_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.go_text.custom_minimum_size = Vector2(520, 0)
	h.go_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 12)
	gv.add_child(gh)
	var retry: Button = h._menu_button("从 本 层 重 新 开 始", 15, gh)
	retry.pressed.connect(func(): h.retry_requested.emit())
	var to_title: Button = h._menu_button("回 到 标 题", 15, gh)
	to_title.pressed.connect(func(): h.to_title_requested.emit())
	h._go_buttons = gh

	var pl: CanvasLayer = h._layer(40)
	h.pause_hint = Control.new()
	h.pause_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.pause_hint.visible = false
	pl.add_child(h.pause_hint)
	var pdim := ColorRect.new()
	pdim.color = Color(0, 0, 0, 0.55)
	pdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.pause_hint.add_child(pdim)
	var ptext: Label = h._label("已暂停 —— 点击画面继续", 16, h.COL["text_main"], h.pause_hint)
	ptext.set_anchors_preset(Control.PRESET_CENTER)
	ptext.offset_left = -160
	ptext.offset_right = 160
	ptext.offset_top = -14
	ptext.offset_bottom = 14
	ptext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.pause_hint.gui_input.connect(func(ev2: InputEvent) -> void:
		if ev2 is InputEventMouseButton and ev2.pressed:
			h.pause_resumed.emit())
