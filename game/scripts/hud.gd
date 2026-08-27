class_name Hud
extends Node
## 全部 2D UI:HUD / 弹窗 / 字幕 / 转场 / 标题 / 结局 / 死亡 / 暂停 / 调试栏 / 画面滤镜
## 2026-08 中式档案恐怖化改版(去「网页卡片感」):
##   - 字体:正文改宋体/仿宋系,氛围文案(幽灵字迹/短信/死亡文本)改楷体手写(美术风格指南 §6)
##   - 全 UI 直角化(RADIUS 归零);配色由中性灰转暗褐纸/锈褐低饱和;阴影改深色大扩散
##   - 弹窗与标题短信卡改做旧纸底(StyleBoxTexture + TexGen.paper_texture 程序化纸纹)
##   - 全屏老胶片颗粒层(侵蚀层最底,3D 与 HUD 均蒙颗粒);状态条加 25% 刻度线
##   - 中式恐怖元素:标题朱砂「封」印、死亡画面「卒」字印、弹窗分隔线朱批色
##   - 侵蚀 tint 系统兼容 StyleBoxTexture(纸纹面板按 modulate_color 血化)
## 2026-08 UI 规范化改版:
##   - 顶部集中定义设计令牌(配色/圆角/间距/动效时长),所有组件统一取值,保证样式一致
##   - HUD 面板改为 PanelContainer + 锚点贴边 + grow 方向,不同分辨率下贴边不漂移
##   - 文本五级层次并整体提亮一档;面板统一描边+投影;目标/提示加描边提升可读性
##   - 按钮统一 normal/hover/pressed/focus/disabled 五态,悬停微放大过渡
##   - 弹窗 BACK 缓动弹入 + 选项错落淡入;字幕/交互提示/暂停/HUD 均有淡入淡出
## 2026-08 状态侵蚀层(动态恐怖氛围):
##   - 侵蚀值由理智(70→0 映射 0→1,叠加 5:00 后深夜压迫)驱动,每帧指数平滑,无跳变
##   - 覆盖层(CanvasLayer 25,HUD 之上、弹窗/全屏界面之下):血色染色、边缘血晕(心跳
##     搏动)、噪声裂纹自边缘蔓延、漂移暗影、低频闪烁、轻微 UV 扭曲——强度随侵蚀值渐变
##   - UI 细节渗透:面板/弹窗描边渐变干血色、按钮边框与文字染色、电梯转场标题血化
##   - 重度侵蚀:HUD 低幅正弦抖动、时钟/数值 glitch 闪烁、屏幕边缘幽灵字迹浮现
##   - 可读性保障:所有效果中心留白、覆盖层不接收输入,弹窗/结局/死亡画面位于其上不受干扰
## 对外接口(signal、公开属性与方法)与原版完全一致,QA 脚本不受影响。
## 2026-08 氛围再打磨(取材 horror-game-ui 参考稿,取其精华去其糟粕):
##   - CRT 扫描线 + 缓慢滚动暖色亮带入侵蚀层;暗角强度随理智收紧(满 0.40 → 归零 0.68)
##   - 标题/结局/死亡大字加红青错位 glitch(标题周期闪断,结局/死亡入场一次即归于死寂)
##   - 标题新副题「一栋有去无回的楼」+ 朱红分隔线 + 英文小字 + 烛火呼吸光晕
##   - 菜单按钮改幽灵样式:悬停浮现「」括号、微放大、同级压暗(参考稿 .gbtn)
##   - 目标文本打字机 + 光标;HUD 分块错落淡入;低理智状态条血化呼吸
##   - 电量小图标、时钟临近 6:00 渐红、准星外圈光环
##   - 未移植:设置面板(无后端接线)、演示指示条、道具格子栏(现有列表信息量更大)

signal start_requested
signal ending_advanced
signal restart_requested
signal retry_requested
signal to_title_requested
signal pause_resumed

## 正文:宋体/仿宋系(90 年代档案感,见 09-视听设计/美术风格指南.md 第六节)
const FONT_PATHS := [
	"C:/Windows/Fonts/simsun.ttc", "C:/Windows/Fonts/simfang.ttf",
	"C:/Windows/Fonts/simhei.ttf", "C:/Windows/Fonts/msyh.ttc",
]
## 手写:楷体(幽灵字迹 / 短信 / 死亡文本等氛围文案)
const HAND_FONT_PATHS := [
	"C:/Windows/Fonts/simkai.ttf", "C:/Windows/Fonts/simsun.ttc",
]

# ---------- 设计令牌(全 UI 统一规范) ----------

## 文本层次:强调 / 主要 / 正文 / 次要 / 弱化
var COL := {
	"text_strong": Color.html("e8ddc4"),
	"text_main": Color.html("d6cbaf"),
	"text_body": Color.html("bfb397"),
	"text_dim": Color.html("96896e"),
	"text_faint": Color.html("756a54"),
	# 面板(暗褐纸 / 锈褐,低饱和)
	"panel_bg": Color(0.055, 0.048, 0.034, 0.86),
	"panel_border": Color(0.42, 0.34, 0.24, 0.55),
	"panel_shadow": Color(0.0, 0.0, 0.0, 0.55),
	"modal_bg": Color(0.10, 0.088, 0.058, 0.97),
	"modal_paper": Color(0.155, 0.135, 0.09),  # 弹窗纸纹染色(StyleBoxTexture.modulate_color)
	"line": Color(0.44, 0.33, 0.22, 0.42),
	# 按钮
	"btn_bg": Color.html("191410"),
	"btn_bg_hover": Color.html("271d12"),
	"btn_bg_press": Color.html("100c08"),
	"btn_border": Color.html("3a2e20"),
	"btn_border_hover": Color.html("6e5b3c"),
	"btn_text": Color.html("c4b896"),
	"btn_text_hover": Color.html("e8d9a8"),
	"btn_text_press": Color.html("d8cca4"),
	"btn_text_disabled": Color(0.72, 0.68, 0.60, 0.40),
	# 状态条渐变(理智/电量/体力,沿用原配色)与语义色
	"sanity_a": Color.html("5a7a8c"), "sanity_b": Color.html("8fb6c4"),
	"battery_a": Color.html("8c7a3a"), "battery_b": Color.html("d4c26a"),
	"stamina_a": Color.html("5c7a4a"), "stamina_b": Color.html("9cc47a"),
	"bar_track": Color(1.0, 1.0, 1.0, 0.07),
	"danger": Color.html("b05a4e"),
	"danger_hot": Color.html("d4705c"),
	"accent": Color.html("b89a5e"),
	# 朱砂(印章 / 死亡「卒」/ 分隔线朱批)
	"cinnabar": Color.html("9e3a2c"),
	# glitch 双色(红/青错位切片,参考稿 .glitch)
	"glitch_red": Color.html("c25a4e"),
	"glitch_teal": Color.html("4a7070"),
}
## 直角(去网页卡片感;圆角归零,边缘靠纸纹磨损与阴影塑形)
var RADIUS := {"bar": 0, "btn": 0, "panel": 0, "modal": 0}
## 动效时长:快(悬停/淡入) / 中(面板入场) / 慢(转场)
var DUR := {"fast": 0.14, "mid": 0.24, "slow": 0.8}
## HUD 状态条固定轨道宽(px)
var BAR_W := 178.0

var theme_font: FontFile
var hand_font: FontFile
# HUD 引用
var sanity_val: Label
var battery_val: Label
var sanity_fill: TextureRect
var battery_fill: TextureRect
var stamina_fill: TextureRect
var sanity_track: Panel
var battery_track: Panel
var stamina_track: Panel
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
var modal_dim: ColorRect
var modal_title: Label
var modal_body: Label
var modal_choices: VBoxContainer
var modal_timer_track: Panel
var modal_timer_fill: Panel
var modal_timer_fill_sb: StyleBoxFlat
var modal_countdown: Timer
var modal_timeout_fn: Callable
var modal_panel: PanelContainer
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
var _prompt_tween: Tween
var _prompt_last := ""

# ---------- 状态侵蚀(理智驱动的动态恐怖) ----------

## 干血色描边(侵蚀时面板/按钮边框的渐变目标)
const BLOOD_BORDER := Color(0.42, 0.16, 0.13, 0.6)
## 幽灵字迹池:重度侵蚀时在屏幕边缘短暂浮现
const GHOST_TEXTS := ["它在看你", "别回头", "数到七", "1304", "不是妹妹", "快跑"]

var corrupt_rect: ColorRect
var ghost_root: Control
var _paper_tex: ImageTexture
var _grain_tex: ImageTexture
var _corrupt_target := 0.0
var _corrupt_cur := 0.0
var _corrupt_stage := -1
var _tint_panels: Array = []
var _tint_buttons: Array = []
var _flicker_labels: Array = []
var _ghost_labels: Array = []
var _flicker_t := 3.0
var _flicker_dur := 0.0
var _ghost_t := 8.0
var _ghost_dur := 0.0
var _ghost_active: Label = null
var _ghost_tween: Tween
var _last_aspect := -1.0   # 侵蚀层 aspect 只随视口尺寸变化写(每帧 set_shader_parameter 会失效重绘)

## 侵蚀值视为零:低于阈值直接短路(阈值远小于视觉可辨的最小值)
static func c_zero(v: float) -> bool:
	return v < 0.001

# ---------- 参考稿移植:CRT 扫描 / 打字机 / glitch / HUD 入场 ----------
var scan_rect: ColorRect
var _obj_full := ""
var _obj_shown := 0
var _obj_type_t := 0.0
var _obj_caret_t := 0.0
var _obj_done := true
var _hud_blocks: Array = []
var _hud_base: Array = []
var _hud_in_tweens: Array = []
var _glitch_sets: Array = []
var _go_glitch: Dictionary
var _ending_glitch: Dictionary
var _go_buttons: Control
var _go_zu: Control
var _go_tweens: Array = []
var _sanity_norm_tex: GradientTexture1D
var _sanity_low_tex: GradientTexture1D
var _sanity_low := false
var _sanity_pulse: Tween
var batt_fill_rect: ColorRect
var crosshair_ring: TextureRect

func _ready() -> void:
	theme_font = _load_font()
	hand_font = _load_hand_font()
	_paper_tex = TexGen.paper_texture()
	_grain_tex = TexGen.grain_texture()
	_build_all()
	# 布局尺寸变化后 _rh_cache 的进度条宽度缓存需整体作废(下一帧全量重写)
	get_viewport().size_changed.connect(_invalidate_rh_cache)

func _invalidate_rh_cache() -> void:
	_rh_cache.clear()

static func _load_font() -> FontFile:
	for p: String in FONT_PATHS:
		if FileAccess.file_exists(p):
			var f := FontFile.new()
			f.load_dynamic_font(p)
			return f
	return null

static func _load_hand_font() -> FontFile:
	for p: String in HAND_FONT_PATHS:
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

# ---------- 样式工具(全部从设计令牌取值) ----------

## 统一面板样式:圆角 + 细描边 + 下投影
func _sb(bg: Color, border: Color = Color(0, 0, 0, 0), radius := 8, m_h := 12, m_v := 10, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = m_h
	s.content_margin_right = m_h
	s.content_margin_top = m_v
	s.content_margin_bottom = m_v
	if shadow:
		s.shadow_color = COL["panel_shadow"]
		s.shadow_size = 22
		s.shadow_offset = Vector2(0, 2)
	return s

func _label(text: String, size: int, color: Color, parent: Control, hand := false) -> Label:
	var l := Label.new()
	l.text = text
	if hand and hand_font != null:
		l.add_theme_font_override("font", hand_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## 状态条:圆角轨道 + 渐变内嵌填充。返回 {track, fill}
func _bar(parent: Control, grad_from: Color, grad_to: Color) -> Dictionary:
	var track := Panel.new()
	track.custom_minimum_size = Vector2(BAR_W, 8)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", _sb(COL["bar_track"], Color(0, 0, 0, 0), RADIUS["bar"], 0, 0, false))
	var fill := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, grad_from)
	grad.set_color(1, grad_to)
	var gtex := GradientTexture1D.new()
	gtex.gradient = grad
	gtex.width = 64
	fill.texture = gtex
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.position = Vector2(2, 2)
	fill.size = Vector2(0, 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	# 25% 间隔刻度线(老式仪表),叠在填充条之上
	for i in 3:
		var tick := ColorRect.new()
		tick.color = Color(0, 0, 0, 0.38)
		tick.size = Vector2(1, 6)
		tick.position = Vector2(BAR_W * (i + 1) / 4.0 - 0.5, 1)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(tick)
	parent.add_child(track)
	return {"track": track, "fill": fill}

func _set_bar(fill: TextureRect, track: Panel, frac: float) -> void:
	var w := maxf(0.0, track.size.x - 4.0) * clampf(frac, 0.0, 1.0)
	fill.size = Vector2(w, 4.0)

## 统一按钮五态样式 + 悬停微放大反馈。pool=true 为弹窗按钮池注册(仅首次,换内容时不再登记)
func _style_button(b: Button, font_size := 14, pool := false) -> void:
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", COL["btn_text"])
	b.add_theme_color_override("font_hover_color", COL["btn_text_hover"])
	b.add_theme_color_override("font_pressed_color", COL["btn_text_press"])
	b.add_theme_color_override("font_disabled_color", COL["btn_text_disabled"])
	b.add_theme_color_override("font_focus_color", COL["btn_text_hover"])
	var bd: Color = COL["btn_border"]
	var n := _sb(COL["btn_bg"], bd, RADIUS["btn"], 18, 11, false)
	var h := _sb(COL["btn_bg_hover"], COL["btn_border_hover"], RADIUS["btn"], 18, 11, false)
	var p := _sb(COL["btn_bg_press"], COL["btn_border_hover"], RADIUS["btn"], 18, 11, false)
	var f := _sb(COL["btn_bg_hover"], COL["accent"], RADIUS["btn"], 18, 11, false)
	var d := _sb(Color(COL["btn_bg"].r, COL["btn_bg"].g, COL["btn_bg"].b, 0.45), Color(bd.r, bd.g, bd.b, 0.5), RADIUS["btn"], 18, 11, false)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", f)
	b.add_theme_stylebox_override("disabled", d)
	_hover_anim(b)
	if pool:
		return   # 弹窗按钮池:样式已建,侵蚀染色登记只在首次创建时做(池内复用不重复注册)
	# 注册进状态侵蚀着色表(理智恶化时边框/文字渐变血色);顺带清理已释放按钮
	if _tint_buttons.size() > 96:
		var alive: Array = []
		for e: Dictionary in _tint_buttons:
			if is_instance_valid(e["b"]):
				alive.append(e)
		_tint_buttons = alive
	_tint_buttons.append({
		"b": b, "n": n, "h": h,
		"nb": n.border_color, "hb": h.border_color, "fc": COL["btn_text"],
	})

## 悬停/移出时的平滑亮度过渡
func _hover_anim(c: Control) -> void:
	c.mouse_entered.connect(func() -> void:
		_mod_to(c, Color(1.06, 1.06, 1.06, 1.0)))
	c.mouse_exited.connect(func() -> void:
		_mod_to(c, Color(1.0, 1.0, 1.0, 1.0)))

func _mod_to(c: Control, target: Color) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate", target, DUR["fast"]).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

## 锚定于某个角落、随内容自适应尺寸的面板
func _corner_panel(preset: Control.LayoutPreset, margin_x: int, margin_y: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(preset)
	p.offset_left = margin_x
	p.offset_right = margin_x
	p.offset_top = margin_y
	p.offset_bottom = margin_y
	match preset:
		Control.PRESET_TOP_RIGHT:
			p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			p.grow_vertical = Control.GROW_DIRECTION_END
		Control.PRESET_BOTTOM_LEFT:
			p.grow_horizontal = Control.GROW_DIRECTION_END
			p.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_RIGHT:
			p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			p.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_:
			p.grow_horizontal = Control.GROW_DIRECTION_END
			p.grow_vertical = Control.GROW_DIRECTION_END
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _sb(COL["panel_bg"], COL["panel_border"], RADIUS["panel"], 14, 12)
	p.add_theme_stylebox_override("panel", sb)
	_tint_panels.append({"sb": sb, "bg": sb.bg_color, "border": sb.border_color})
	return p

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

# ---------- 画面滤镜(色差 + 暗角 + 低理智色偏,构建在 hud_fx.gd,纯搬迁 C5) ----------

func _build_effect_layer() -> void:
	HudFx.build_effect_layer(self)

func set_distort(level: float) -> void:
	effect_rect.material.set_shader_parameter("distort", level)

func red_flash() -> void:
	red_flash_rect.modulate.a = 1.0
	var tw := red_flash_rect.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(red_flash_rect, "modulate:a", 0.0, 0.25)

# ---------- 状态侵蚀层(理智驱动的动态恐怖氛围) ----------
# 覆盖层位于 HUD(20)之上、弹窗(50)/转场(60)/全屏画面(70)之下:
# 3D + HUD 一起被血色/裂纹/暗影侵蚀,而关键决策界面保持干净可读。

## 着色器常量与侵蚀层/幽灵字迹构建搬至 hud_fx.gd(C5)

func _build_corruption_layer() -> void:
	HudFx.build_corruption_layer(self)

func _process(delta: float) -> void:
	if corrupt_rect == null:
		return
	var want := _corrupt_target if hud_root.visible else 0.0
	# 全程无侵蚀且已归零(标题/暂停):跳过全部每帧写,只保留目标衰减
	if c_zero(_corrupt_cur) and c_zero(want):
		hud_root.position = Vector2.ZERO
		return
	# 指数平滑:状态切换时氛围平滑过渡,不跳变
	_corrupt_cur = lerpf(_corrupt_cur, want, minf(1.0, delta * 1.6))
	var c := _corrupt_cur
	# 心跳同步脉冲(与 sfx.gd 的心跳音同频段)
	var pulse := 0.0
	if c > 0.3:
		var rate := 1.4 if c > 0.6 else 1.0
		var ph := fmod(Time.get_ticks_msec() * 0.001 * rate, 1.0)
		pulse = pow(maxf(0.0, sin(ph * TAU)), 3.0)
	corrupt_rect.material.set_shader_parameter("corrupt", c)
	corrupt_rect.material.set_shader_parameter("pulse", pulse)
	var vp := get_viewport().get_visible_rect().size
	if vp.y > 0.0:
		var aspect := vp.x / vp.y
		if aspect != _last_aspect:
			_last_aspect = aspect
			corrupt_rect.material.set_shader_parameter("aspect", aspect)
	# 界面抖动:重度侵蚀时低幅正弦复合抖动(≤ ~2.6px,不伤可读性)
	if c > 0.45:
		var amp := (c - 0.45) / 0.55 * 2.6
		var t := Time.get_ticks_msec() * 0.001
		hud_root.position = Vector2(
			(sin(t * 13.0) + sin(t * 7.3) * 0.6) * amp,
			(cos(t * 11.0) + sin(t * 8.9) * 0.5) * amp * 0.8)
	else:
		hud_root.position = Vector2.ZERO
	_update_flicker(delta, c)
	_update_ghost(delta, c)
	# 分级渗透:面板描边/按钮/转场文字(量化到 5% 级,避免每帧改样式)
	var stage := int(c * 20.0)
	if stage != _corrupt_stage:
		_corrupt_stage = stage
		_apply_stage_tint(stage / 20.0)
	_update_glitch(delta)
	_update_objective_typing(delta)

func _update_flicker(delta: float, c: float) -> void:
	if c > 0.55:
		_flicker_t -= delta
		if _flicker_t <= 0.0:
			_flicker_t = 2.2 + randf() * 3.5
			_flicker_dur = 0.16 + randf() * 0.1
		if _flicker_dur > 0.0:
			_flicker_dur -= delta
			var a := 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.06))
			var m := clampf((c - 0.55) / 0.45, 0.0, 1.0)
			for l: Label in _flicker_labels:
				if is_instance_valid(l):
					l.modulate.a = lerpf(1.0, a, m)
			return
	for l: Label in _flicker_labels:
		if is_instance_valid(l) and l.modulate.a != 1.0:
			l.modulate.a = 1.0

func _update_ghost(delta: float, c: float) -> void:
	if c < 0.72:
		if _ghost_active != null:
			_clear_ghost()
		return
	_ghost_t -= delta
	if _ghost_t <= 0.0 and _ghost_active == null:
		_ghost_t = 5.0 + randf() * 6.0
		_spawn_ghost(c)
	if _ghost_active != null:
		_ghost_dur -= delta
		if _ghost_dur <= 0.0:
			_clear_ghost()

func _clear_ghost() -> void:
	if _ghost_tween and _ghost_tween.is_valid():
		_ghost_tween.kill()
	if _ghost_active and is_instance_valid(_ghost_active):
		_ghost_active.modulate.a = 0.0
	_ghost_active = null

func _spawn_ghost(c: float) -> void:
	var l: Label = _ghost_labels[randi() % _ghost_labels.size()]
	l.text = GHOST_TEXTS[randi() % GHOST_TEXTS.size()]
	l.add_theme_font_size_override("font_size", 14 + randi() % 3)
	var vp := get_viewport().get_visible_rect().size
	var side := randi() % 4
	var pos := Vector2.ZERO
	match side:
		0: pos = Vector2(vp.x * randf_range(0.05, 0.28), vp.y * randf_range(0.10, 0.32))
		1: pos = Vector2(vp.x * randf_range(0.66, 0.90), vp.y * randf_range(0.10, 0.35))
		2: pos = Vector2(vp.x * randf_range(0.05, 0.28), vp.y * randf_range(0.58, 0.82))
		_: pos = Vector2(vp.x * randf_range(0.66, 0.90), vp.y * randf_range(0.58, 0.82))
	l.position = pos
	l.modulate.a = 0.0
	_ghost_active = l
	_ghost_dur = 2.8
	_ghost_tween = l.create_tween()
	var peak := 0.14 + 0.10 * clampf((c - 0.72) / 0.28, 0.0, 1.0)
	_ghost_tween.tween_property(l, "modulate:a", peak, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ghost_tween.tween_interval(0.9)
	_ghost_tween.tween_property(l, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## 分级渗透:把当前侵蚀度应用到面板描边 / 按钮样式 / 转场标题
func _apply_stage_tint(k: float) -> void:
	for e: Dictionary in _tint_panels:
		var sb: StyleBox = e["sb"]
		var bg: Color = e["bg"]
		if sb is StyleBoxTexture:
			# 纸纹面板:整体染色向干血色沉去
			(sb as StyleBoxTexture).modulate_color = bg.lerp(Color(0.30, 0.10, 0.08), k * 0.6)
			continue
		var bd: Color = e["border"]
		(sb as StyleBoxFlat).bg_color = bg.lerp(bg * Color(0.95, 0.60, 0.58), k * 0.5)
		(sb as StyleBoxFlat).border_color = bd.lerp(BLOOD_BORDER, k * 0.85)
	var keep: Array = []
	for e: Dictionary in _tint_buttons:
		# 先判活再做类型化赋值:对已释放实例直接赋值会报
		# "Trying to assign invalid previously freed instance"(SCRIPT ERROR)
		if not is_instance_valid(e["b"]):
			continue
		var b: Button = e["b"]
		(e["n"] as StyleBoxFlat).border_color = (e["nb"] as Color).lerp(BLOOD_BORDER, k * 0.7)
		(e["h"] as StyleBoxFlat).border_color = (e["hb"] as Color).lerp(BLOOD_BORDER, k * 0.7)
		b.add_theme_color_override("font_color", (e["fc"] as Color).lerp(Color(0.86, 0.50, 0.42), k * 0.5))
		keep.append(e)
	_tint_buttons = keep
	if fade_label != null:
		fade_label.add_theme_color_override("font_color", Color.html("cfc6b0").lerp(Color(0.75, 0.30, 0.24), k * 0.7))

# ---------- HUD ----------

## HUD 常驻层构建搬至 hud_build_main.gd(C5)
func _build_hud() -> void:
	HudBuildMain.build_hud(self)

## render_hud 每帧被 main._process 调用。这里做「值缓存 + 变化才写」:
## add_theme_color_override / shader 参数 / Control.size 都没有同值早退,
## 无条件写会每帧触发控件失效重绘;Label.text 虽有早退但上方 %格式串分配也一并省掉。
var _rh_cache := {}

func render_hud(g) -> void:
	if not hud_root.visible:
		return
	var c := _rh_cache
	# 时钟文本与渐红(受同一分钟值驱动:t 不变则两个都不必写)
	var t: int = int(minf(359.0, g.time))
	if int(c.get("t", -1)) != t:
		c["t"] = t
		time_val.text = "%d:%02d" % [int(t / 60), t % 60]
		var urgent: float = clampf((g.time - 300.0) / 60.0, 0.0, 1.0)
		time_val.add_theme_color_override("font_color", COL["text_dim"].lerp(COL["danger_hot"], urgent))
	var f: String = g.floor_id
	if str(c.get("floor", "")) != f:
		c["floor"] = f
		floor_val.text = f
	# 理智(数值/条血色切换都由整数档驱动)
	var s_ceil: float = ceil(g.sanity)
	if float(c.get("s", -1.0)) != s_ceil:
		c["s"] = s_ceil
		sanity_val.text = str(s_ceil)
	var low: bool = g.sanity <= 30.0
	if low != _sanity_low:
		_sanity_low = low
		sanity_fill.texture = _sanity_low_tex if low else _sanity_norm_tex
		if low:
			sanity_val.add_theme_color_override("font_color", COL["danger_hot"])
			_sanity_pulse = sanity_fill.create_tween().set_loops()
			_sanity_pulse.tween_property(sanity_fill, "modulate", Color(1.6, 0.85, 0.8), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_sanity_pulse.tween_property(sanity_fill, "modulate", Color(1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			sanity_val.add_theme_color_override("font_color", COL["text_body"])
			if _sanity_pulse != null and _sanity_pulse.is_valid():
				_sanity_pulse.kill()
			sanity_fill.modulate = Color(1.0, 1.0, 1.0)
	_bar_cached("sb", sanity_fill, sanity_track, g.sanity / 100.0)
	# 电量(数字/进度条/电池图标同源)
	var has_flash: bool = g.has_flash
	var b_ceil: float = ceil(g.battery) if has_flash else -1.0
	if float(c.get("b", -2.0)) != b_ceil or bool(c.get("hf", true)) != has_flash:
		c["b"] = b_ceil
		c["hf"] = has_flash
		battery_val.text = str(b_ceil) if has_flash else "--"
	_bar_cached("bb", battery_fill, battery_track, (g.battery / 100.0) if has_flash else 0.0)
	_bar_cached("stb", stamina_fill, stamina_track, g.stamina / 100.0)
	if batt_fill_rect != null:
		var bw: float = (11.0 * clampf(g.battery / 100.0, 0.0, 1.0)) if has_flash else 0.0
		if absf(float(c.get("bw", -1.0)) - bw) > 0.25:
			c["bw"] = bw
			batt_fill_rect.size.x = bw
	# 道具数量(仅整数控变化才重排标签)
	if int(c.get("batc", -1)) != g.batteries:
		c["batc"] = g.batteries
		inv_bat_key.get_parent().get_child(1).text = "×%d(按1使用)" % g.batteries
	if int(c.get("pa", -1)) != g.pills["a"]:
		c["pa"] = g.pills["a"]
		inv_a_val.text = "×%d(按2)" % g.pills["a"]
	if int(c.get("pb", -1)) != g.pills["b"]:
		c["pb"] = g.pills["b"]
		inv_b_val.text = "×%d(按3)" % g.pills["b"]
	if int(c.get("ca", -1)) != g.candles:
		c["ca"] = g.candles
		inv_candle_val.text = "×%d(按4使用)" % g.candles
	if int(c.get("re", -1)) != g.relics:
		c["re"] = g.relics
		inv_relic_val.text = "%d / 13" % g.relics
	var kp: bool = g.knows_pills
	if bool(c.get("kp", false)) != kp:
		c["kp"] = kp
		inv_a_key.add_theme_color_override("font_color", Color.html("a8d488") if kp else COL["text_dim"])
		inv_b_key.add_theme_color_override("font_color", Color.html("c25a4e") if kp else COL["text_dim"])
	var dlevel: float = 2.0 if g.sanity < 25.0 else (1.0 if g.sanity < 50.0 else 0.0)
	if float(c.get("dl", -1.0)) != dlevel:
		c["dl"] = dlevel
		set_distort(dlevel)
	# 暗角随理智收紧(满理智 0.40 → 归零 0.68,参考稿 --vig-inner 动态暗角)
	var vig: float = 0.40 + (1.0 - clampf(g.sanity / 100.0, 0.0, 1.0)) * 0.28
	if absf(float(c.get("vig", -1.0)) - vig) > 0.002:
		c["vig"] = vig
		effect_rect.material.set_shader_parameter("vignette", vig)
	# 状态侵蚀目标:理智 70→0 映射 0→1;5:00 后深夜临近,叠加基础压迫感
	var ct: float = clampf((70.0 - g.sanity) / 70.0, 0.0, 1.0)
	ct = maxf(ct, clampf((g.time - 300.0) / 240.0, 0.0, 0.22))
	_corrupt_target = ct

## 进度条几何按 1/256 步长去重:亚像素宽度差不可见,跳过绝大多数无效化;
## 缓存随窗口尺寸变化整体作废(track 宽度在布局变化后需重算)。
func _bar_cached(key: String, fill: TextureRect, track: Panel, frac: float) -> void:
	var q := roundi(clampf(frac, 0.0, 1.0) * 256.0)
	if _rh_cache.get(key, -1) == q:
		return
	_rh_cache[key] = q
	_set_bar(fill, track, frac)

func set_objective(t: String) -> void:
	# 打字机:逐字浮现 + 光标闪烁,完成后定稿(参考稿 .obj-text.typing)
	_obj_full = t
	_obj_shown = 0
	_obj_type_t = 0.0
	_obj_caret_t = 0.0
	_obj_done = t.is_empty()
	objective.text = t if t.is_empty() else ""

func show_msg(text: String, dur := 4.2) -> void:
	subtitle.text = text
	if _sub_hide_tween and _sub_hide_tween.is_valid():
		_sub_hide_tween.kill()
	subtitle.modulate.a = 0.0
	_sub_hide_tween = subtitle.create_tween()
	_sub_hide_tween.tween_property(subtitle, "modulate:a", 1.0, DUR["mid"]).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_sub_hide_tween.tween_interval(dur)
	_sub_hide_tween.tween_property(subtitle, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func set_hud_visible(on: bool) -> void:
	crosshair.visible = on
	if crosshair_ring != null:
		crosshair_ring.visible = on
	if on:
		hud_root.visible = true
		_rh_cache.clear()   # 隐→显后全量重绘一次(入场动画期间轨道几何可能尚未稳定)
		# HUD 分块错落淡入 + 上浮归位(参考稿 fadeUp 入场节奏)
		for t: Tween in _hud_in_tweens:
			if t.is_valid():
				t.kill()
		_hud_in_tweens.clear()
		if _hud_base.is_empty():
			for blk: Control in _hud_blocks:
				_hud_base.append(blk.position.y)
		var delay := 0.0
		for i in _hud_blocks.size():
			var blk: Control = _hud_blocks[i]
			if not is_instance_valid(blk):
				continue
			var base_y: float = _hud_base[i]
			blk.modulate.a = 0.0
			blk.position.y = base_y + 14.0
			var tw := blk.create_tween()
			tw.tween_interval(delay)
			tw.tween_property(blk, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(blk, "position:y", base_y, 0.42).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			_hud_in_tweens.append(tw)
			delay += 0.06
	else:
		hud_root.visible = false

## 交互提示:文本变化时才重播淡入/淡出(update_interact 每帧调用)
func set_prompt(text: String) -> void:
	if text == _prompt_last:
		return
	_prompt_last = text
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	if text.is_empty():
		if prompt.visible:
			prompt.modulate.a = 1.0
			_prompt_tween = prompt.create_tween()
			_prompt_tween.tween_property(prompt, "modulate:a", 0.0, DUR["fast"])
			_prompt_tween.tween_callback(func() -> void:
				if _prompt_last.is_empty():
					prompt.visible = false
					prompt.modulate.a = 1.0)
	else:
		prompt.visible = true
		prompt.modulate.a = 0.2
		_prompt_tween = prompt.create_tween()
		_prompt_tween.tween_property(prompt, "modulate:a", 1.0, DUR["mid"]).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

# ---------- 弹窗 ----------

## 弹窗容器构建搬至 hud_build_main.gd(C5)
func _build_modal() -> void:
	HudBuildMain.build_modal(self)

func _on_modal_tick() -> void:
	_modal_left -= 0.1
	var ratio: float = maxf(0.0, _modal_left / _modal_total) if _modal_total > 0.0 else 0.0
	modal_timer_fill.size = Vector2(modal_timer_track.size.x * ratio, 4.0)
	modal_timer_fill_sb.bg_color = COL["danger_hot"] if ratio < 0.25 else COL["danger"]
	if _modal_left <= 0.0:
		modal_countdown.stop()
		if modal_timeout_fn.is_valid():
			modal_timeout_fn.call()

func open_modal(cfg: Dictionary) -> void:
	modal_root.visible = true
	# 背景压暗淡入 + 面板 BACK 缓动弹入(仅动 scale,可见性即时,不影响断言/截图)
	modal_dim.modulate.a = 0.0
	var dt := modal_dim.create_tween()
	dt.tween_property(modal_dim, "modulate:a", 1.0, DUR["mid"])
	modal_panel.pivot_offset = modal_panel.size * 0.5 if modal_panel.size.x > 0.0 else Vector2(280.0, 80.0)
	modal_panel.scale = Vector2(0.965, 0.965)
	var pt := modal_panel.create_tween()
	pt.tween_property(modal_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	modal_title.text = cfg.get("title", "")
	modal_body.text = cfg.get("body", "")
	if cfg.has("countdown"):
		modal_timer_track.visible = true
		_modal_total = cfg["countdown"]
		_modal_left = _modal_total
		modal_timer_fill.size = Vector2(modal_timer_track.size.x, 4.0)
		modal_timer_fill_sb.bg_color = COL["danger"]
		modal_timeout_fn = cfg.get("on_timeout", func(): close_modal())
		if not modal_countdown.timeout.is_connected(_on_modal_tick):
			modal_countdown.timeout.connect(_on_modal_tick)
		modal_countdown.start()
	else:
		modal_timer_track.visible = false
		modal_countdown.stop()
	# 按钮池:复用已有 Button 只换文本与回调(电梯面板 15 按钮 × 5 StyleBox 的重建开销免掉);
	# 多余的收起,不够的补建。find_choice 遍历的子节点保持连续前缀。
	var wanted: Array = cfg.get("choices", [])
	while modal_choices.get_child_count() > wanted.size():
		var last := modal_choices.get_child(modal_choices.get_child_count() - 1)
		modal_choices.remove_child(last)
		last.queue_free()
	var idx := 0
	for ch: Dictionary in wanted:
		var b: Button
		if idx < modal_choices.get_child_count():
			b = modal_choices.get_child(idx)
			b.show()
			b.disabled = false   # 复用按钮先解除上轮可能残留的禁用态
			var e := _tint_btn_of(b)
			if not e.is_empty():
				# 上轮侵蚀染色的边框色还原为注册时记录的原色
				(e["n"] as StyleBoxFlat).border_color = e["nb"]
				(e["h"] as StyleBoxFlat).border_color = e["hb"]
				b.add_theme_color_override("font_color", e["fc"])
		else:
			b = Button.new()
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_style_button(b, 14, true)
			b.pressed.connect(func() -> void:
				modal_countdown.stop()
				var fn2: Callable = b.get_meta("fn", Callable())
				if fn2.is_valid():
					fn2.call())
			modal_choices.add_child(b)
		b.text = ch.get("text", "")
		if ch.get("disabled", false):
			b.disabled = true
			if ch.has("reason"):
				b.text += "(%s)" % ch["reason"]
		b.set_meta("fn", ch.get("fn", Callable()))
		# 选项依次淡入,形成阅读节奏
		b.modulate = Color(1, 1, 1, 0)
		var it := b.create_tween()
		it.tween_interval(0.045 * idx)
		it.tween_property(b, "modulate", Color(1, 1, 1, 1), DUR["mid"])
		idx += 1

## 取按钮在侵蚀染色表中的登记项(不复用时无需重复注册/清理)
func _tint_btn_of(b: Button) -> Dictionary:
	for e: Dictionary in _tint_buttons:
		if is_instance_valid(e["b"]) and e["b"] == b:
			return e
	return {}

func close_modal() -> void:
	modal_root.visible = false
	modal_countdown.stop()
	modal_panel.scale = Vector2.ONE

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
	HudScreens.build_fade(self)

func fade_show(label_text: String, sub: String) -> void:
	fade_root.visible = true
	fade_root.modulate.a = 1.0
	fade_label.text = label_text
	fade_sub.text = sub

func fade_out() -> void:
	fade_root.visible = true
	var tw := fade_root.create_tween()
	tw.tween_property(fade_root, "modulate:a", 0.0, DUR["slow"]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		fade_root.visible = false
		fade_root.modulate.a = 1.0)

func _build_screens() -> void:
	HudScreens.build_screens(self)

func show_title(on: bool) -> void:
	title_screen.visible = on

func show_ending(title_text: String, text: String) -> void:
	ending_screen.visible = true
	ending_title.text = title_text
	ending_text.text = text
	# 标题入场:一次 glitch 闪断,之后归于平静(参考稿 .glitch-once)
	_start_glitch(_ending_glitch, 0.5)
	ending_hint.visible = true
	ending_stats.visible = false
	restart_btn.visible = false

func show_gameover(text: String) -> void:
	gameover_screen.visible = true
	go_text.text = text
	# 入场:标题一次 glitch 闪断,正文/印章/按钮错落淡入(参考稿死亡画面节奏)
	for t: Tween in _go_tweens:
		if t.is_valid():
			t.kill()
	_go_tweens.clear()
	_start_glitch(_go_glitch, 0.6)
	go_text.modulate.a = 0.0
	var tw := go_text.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(go_text, "modulate:a", 1.0, 0.7)
	_go_tweens.append(tw)
	if _go_zu != null:
		_go_zu.modulate.a = 0.0
		var tz := _go_zu.create_tween()
		tz.tween_interval(0.15)
		tz.tween_property(_go_zu, "modulate:a", 1.0, 0.45)
		_go_tweens.append(tz)
	if _go_buttons != null:
		_go_buttons.modulate.a = 0.0
		var tb := _go_buttons.create_tween()
		tb.tween_interval(1.0)
		tb.tween_property(_go_buttons, "modulate:a", 1.0, 0.6)
		_go_tweens.append(tb)

func show_pause(on: bool) -> void:
	pause_hint.visible = on
	if on:
		pause_hint.modulate.a = 0.0
		var tw := pause_hint.create_tween()
		tw.tween_property(pause_hint, "modulate:a", 1.0, DUR["fast"])
	else:
		pause_hint.modulate.a = 1.0

# ---------- 参考稿移植:幽灵菜单按钮 / glitch / 打字机 ----------

## 幽灵菜单按钮:无底框文字按钮,悬停浮现朱红「」括号、微放大、同级其他菜单项压暗
func _menu_button(text: String, font_size: int, parent: Control) -> Button:
	var b := Button.new()
	b.flat = true
	b.text = text
	b.set_meta("menu_item", true)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", COL["text_dim"])
	b.add_theme_color_override("font_hover_color", COL["text_strong"])
	b.add_theme_color_override("font_pressed_color", COL["text_strong"])
	b.add_theme_color_override("font_focus_color", COL["text_strong"])
	b.add_theme_color_override("font_disabled_color", COL["btn_text_disabled"])
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 24, 12, false))
	parent.add_child(b)
	# 「」括号:按钮子节点,绝对定位于两侧,不占布局
	var bc := Color(0.72, 0.25, 0.20)
	var lq := _label("「", font_size, bc, b)
	var rq := _label("」", font_size, bc, b)
	lq.modulate.a = 0.0
	rq.modulate.a = 0.0
	b.resized.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		lq.position = Vector2(-8.0 - lq.size.x, (b.size.y - lq.size.y) * 0.5)
		rq.position = Vector2(b.size.x + 8.0, (b.size.y - rq.size.y) * 0.5))
	b.mouse_entered.connect(func() -> void: _menu_hover(b, lq, rq, true))
	b.mouse_exited.connect(func() -> void: _menu_hover(b, lq, rq, false))
	return b

func _menu_hover(b: Button, lq: Label, rq: Label, on: bool) -> void:
	if b.has_meta("hover_tw") and (b.get_meta("hover_tw") as Tween).is_valid():
		(b.get_meta("hover_tw") as Tween).kill()
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(lq, "modulate:a", 1.0 if on else 0.0, 0.22)
	tw.tween_property(rq, "modulate:a", 1.0 if on else 0.0, 0.22)
	tw.tween_property(b, "scale", Vector2(1.05, 1.05) if on else Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	b.set_meta("hover_tw", tw)
	# 悬停项聚焦:同级其余菜单项压暗/恢复(参考稿 .menu:hover .gbtn:not(:hover))
	for c: Control in b.get_parent().get_children():
		if c is Button and c != b and c.has_meta("menu_item"):
			if c.has_meta("dim_tw") and (c.get_meta("dim_tw") as Tween).is_valid():
				(c.get_meta("dim_tw") as Tween).kill()
			var dt := c.create_tween()
			dt.tween_property(c, "modulate", Color(1, 1, 1, 0.35) if on else Color(1, 1, 1, 1), 0.3)
			c.set_meta("dim_tw", dt)

## glitch 双色拷贝:作为主标签的子节点(不进容器布局),burst 时错位闪现
func _glitch_pair(main: Label, font_size: int) -> Dictionary:
	var red := _label(main.text, font_size, COL["glitch_red"], main)
	var teal := _label(main.text, font_size, COL["glitch_teal"], main)
	for c: Label in [red, teal]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.horizontal_alignment = main.horizontal_alignment
		c.vertical_alignment = main.vertical_alignment
		c.autowrap_mode = main.autowrap_mode
		c.modulate.a = 0.0
	var gs := {"main": main, "red": red, "teal": teal, "periodic": false,
		"next": 0.0, "burst": 0.0, "step": 0.0}
	_glitch_sets.append(gs)
	return gs

func _start_glitch(gs: Dictionary, dur: float) -> void:
	if gs.is_empty():
		return
	var main: Label = gs["main"]
	if not is_instance_valid(main):
		return
	(gs["red"] as Label).text = main.text
	(gs["teal"] as Label).text = main.text
	gs["burst"] = dur
	gs["step"] = 0.0

func _glitch_off(gs: Dictionary) -> void:
	(gs["red"] as Label).modulate.a = 0.0
	(gs["teal"] as Label).modulate.a = 0.0
	(gs["red"] as Label).position = Vector2.ZERO
	(gs["teal"] as Label).position = Vector2.ZERO
	(gs["main"] as Label).modulate.a = 1.0

func _update_glitch(delta: float) -> void:
	for gs: Dictionary in _glitch_sets:
		var main: Label = gs["main"]
		if not is_instance_valid(main) or not main.is_visible_in_tree():
			if gs["burst"] > 0.0:
				gs["burst"] = 0.0
				_glitch_off(gs)
			continue
		if gs["periodic"]:
			gs["next"] -= delta
			if gs["next"] <= 0.0:
				gs["next"] = 4.5 + randf() * 4.5
				_start_glitch(gs, 0.32)
		if gs["burst"] > 0.0:
			gs["burst"] -= delta
			gs["step"] -= delta
			if gs["step"] <= 0.0:
				gs["step"] = 0.055
				var off := Vector2(randf_range(-7.0, 7.0), randf_range(-1.5, 1.5))
				(gs["red"] as Label).position = off
				(gs["teal"] as Label).position = -off * 0.75
				(gs["red"] as Label).modulate.a = 0.5
				(gs["teal"] as Label).modulate.a = 0.4
				main.modulate.a = 0.78 + randf() * 0.22
			if gs["burst"] <= 0.0:
				_glitch_off(gs)

## 目标文本打字机:逐字浮现 + 光标闪烁 0.9s 后定稿(参考稿 .obj-text.typing)
func _update_objective_typing(delta: float) -> void:
	if _obj_done or not objective.is_visible_in_tree():
		return
	if _obj_shown < _obj_full.length():
		_obj_type_t -= delta
		if _obj_type_t <= 0.0:
			_obj_type_t = 0.032
			_obj_shown += 1
			objective.text = _obj_full.substr(0, _obj_shown) + "丨"
		return
	_obj_caret_t += delta
	if _obj_caret_t >= 0.9:
		objective.text = _obj_full
		_obj_done = true
	elif fmod(_obj_caret_t, 0.45) < 0.22:
		objective.text = _obj_full + "丨"
	else:
		objective.text = _obj_full

# ---------- 调试栏 ----------

func build_debug(buttons: Array) -> void:
	var layer := _layer(80)
	debug_bar = VBoxContainer.new()
	debug_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_bar.position = Vector2(-120, 64)
	debug_bar.add_theme_constant_override("separation", 4)
	layer.add_child(debug_bar)
	for entry: Array in buttons:
		var b := Button.new()
		b.text = entry[0]
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", Color.html("8fd18f"))
		b.add_theme_color_override("font_hover_color", Color.html("c8eec8"))
		b.add_theme_stylebox_override("normal", _sb(Color(0.08, 0.11, 0.08, 0.85), Color.html("2e4430"), RADIUS["bar"], 10, 5, false))
		b.add_theme_stylebox_override("hover", _sb(Color(0.10, 0.15, 0.10, 0.9), Color.html("4a6b4a"), RADIUS["bar"], 10, 5, false))
		b.pressed.connect(func(): (entry[1] as Callable).call())
		debug_bar.add_child(b)

func _build_all() -> void:
	_build_effect_layer()
	_build_corruption_layer()
	_build_hud()
	_build_modal()
	_build_fade()
	_build_screens()
