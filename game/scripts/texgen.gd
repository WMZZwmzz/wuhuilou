class_name TexGen
extends RefCounted
## 程序化贴图:大面积表面(墙/地/顶)由 GPU 噪声着色器渲染(SubViewport),小面(门/金属)与
## 法线退回 CPU 噪声画布(Image 逐像素 + Sobel);文本/图形贴图走 SubViewport 绘制。
## 中文字体从系统加载(微软雅黑);零外部素材,headless 下 GPU/文本贴图退回纯色。

var font: FontFile
var tex := {}            # 名称 -> ImageTexture(共享;uv 平铺靠材质 uv1_scale)
var _headless := false

func _init() -> void:
	_headless = (DisplayServer.get_name() == "headless")
	font = _load_cjk_font()

static func _load_cjk_font() -> FontFile:
	for p: String in [
		"C:/Windows/Fonts/msyh.ttc",
		"C:/Windows/Fonts/simhei.ttf",
		"C:/Windows/Fonts/simsun.ttc",
	]:
		if FileAccess.file_exists(p):
			var f := FontFile.new()
			f.load_dynamic_font(p)
			return f
	return null

# ---------- 基础画布工具(对齐原 canvas 2D 用法) ----------

static func fill_rect_color(img: Image, x: float, y: float, w: float, h: float, col: Color) -> void:
	var r := Rect2i(int(x), int(y), int(ceil(w)), int(ceil(h)))
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	for yy in range(r.position.y, r.end.y):
		for xx in range(r.position.x, r.end.x):
			img.set_pixel(xx, yy, col)

static func blend_rect(img: Image, x: float, y: float, w: float, h: float, col: Color) -> void:
	# col.a < 1 时逐像素混叠,等价 canvas 半透明 fillRect
	var r := Rect2i(int(x), int(y), int(ceil(w)), int(ceil(h)))
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if col.a >= 0.999:
		for yy in range(r.position.y, r.end.y):
			for xx in range(r.position.x, r.end.x):
				img.set_pixel(xx, yy, col)
		return
	for yy in range(r.position.y, r.end.y):
		for xx in range(r.position.x, r.end.x):
			var dst := img.get_pixel(xx, yy)
			img.set_pixel(xx, yy, dst.lerp(col, col.a))

static func to_texture(img: Image, renorm := false) -> ImageTexture:
	# 4.7 起 Texture2D 无 repeat 属性;材质侧默认按 UV>1 重复采样。
	# mipmap 必须在这里生成,否则远处/掠射角闪烁成色块(像素感主要来源之一);法线需逐级重归一化
	if not img.has_mipmaps():
		img.generate_mipmaps(renorm)
	return ImageTexture.create_from_image(img)

# ---------- 法线贴图:高度图 Sobel ----------

static func height_to_normal(himg: Image, strength: float = 2.0) -> ImageTexture:
	var w := himg.get_width()
	var h := himg.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	# 高度抽取走 PackedByteArray(R 通道),避免 w*h 次跨语言 get_pixel 调用(B5)
	var raw := himg.get_data()
	var hv := PackedFloat32Array()
	hv.resize(w * h)
	for i in w * h:
		hv[i] = float(raw[i * 3]) / 255.0
	for y in h:
		for x in w:
			var hl := hv[y * w + ((x - 1 + w) % w)]
			var hr := hv[y * w + ((x + 1) % w)]
			var hu := hv[((y - 1 + h) % h) * w + x]
			var hd := hv[((y + 1) % h) * w + x]
			var dx := (hr - hl) * strength
			var dy := (hd - hu) * strength
			var n := Vector3(-dx, dy, 1.0).normalized()
			out.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	return to_texture(out, true)

func _make_normal(size: int, height_draw: Callable, strength: float) -> ImageTexture:
	var hi := Image.create(size, size, false, Image.FORMAT_RGB8)
	height_draw.call(hi)
	return height_to_normal(hi, strength)

# ---------- UI 做旧纹理(纯 CPU,headless 下同样可用) ----------

## 整数格点 hash → [0,1)
static func _n2(xi: int, yi: int) -> float:
	var h := (xi * 374761393 + yi * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h) / 2147483647.0

## 周期化平滑值噪声(px/py 为格点周期,保证纹理可无缝平铺)
static func _vnoise(x: float, y: float, px: int, py: int) -> float:
	var xi := int(floor(x))
	var yi := int(floor(y))
	var fx := x - xi
	var fy := y - yi
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x0 := posmod(xi, px)
	var x1 := posmod(xi + 1, px)
	var y0 := posmod(yi, py)
	var y1 := posmod(yi + 1, py)
	var a := _n2(x0, y0)
	var b := _n2(x1, y0)
	var c := _n2(x0, y1)
	var d := _n2(x1, y1)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

## 做旧纸纹:泛黄纸底 + 多频颗粒 + 污渍斑 + 边缘磨损暗角(四周无缝平铺)
## HUD 侧用 StyleBoxTexture.modulate_color 压暗染色成暗纸底色。
## headless 返回 null(调用方已有纹理缺失分支,QA 无 UI 不需要这张图)。
static func paper_texture(size := 256) -> ImageTexture:
	if DisplayServer.get_name() == "headless":
		return null
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var fx := float(x) / float(size)
			var fy := float(y) / float(size)
			var g := _vnoise(fx * 5.0, fy * 5.0, 5, 5) * 0.5 \
				+ _vnoise(fx * 17.0 + 3.0, fy * 17.0, 17, 17) * 0.3 \
				+ _vnoise(fx * 41.0, fy * 41.0 + 5.0, 41, 41) * 0.2
			var stain := smoothstep(0.60, 0.78, _vnoise(fx * 3.0 + 11.0, fy * 3.0 + 4.0, 3, 3)) * 0.16
			var ex := minf(fx, 1.0 - fx)
			var ey := minf(fy, 1.0 - fy)
			var edge := 1.0 - smoothstep(0.0, 0.085, minf(ex, ey)) * 0.38
			var v := clampf((0.80 + (g - 0.5) * 0.24 - stain) * edge, 0.0, 1.0)
			img.set_pixel(x, y, Color(v * 0.97, v * 0.91, v * 0.72))
	return to_texture(img)

## 老胶片颗粒:单层灰度随机,供全屏低透明度颗粒层(headless 返回 null,颗粒层跳过)
static func grain_texture(size := 128) -> ImageTexture:
	if DisplayServer.get_name() == "headless":
		return null
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v := clampf(0.5 + (randf() - 0.5) * 1.6, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return to_texture(img)

# ---------- GPU 程序化贴图(墙面/地面等大面积表面) ----------
# 值噪声 + fbm 在着色器里逐像素生成,1024² 细度远超 CPU 画布且零启动开销;
# 一 tile 对应物理 3m×3.2m(墙)/ 4m×4m(地、顶),与 main.gd / floor_common.gd 的 uv1 平铺一致。

const NOISE_LIB := "
float n_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float n_val(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = n_hash(i);
	float b = n_hash(i + vec2(1.0, 0.0));
	float c = n_hash(i + vec2(0.0, 1.0));
	float d = n_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float n_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * n_val(p);
		p = p * 2.03 + vec2(11.7, 9.2);
		a *= 0.5;
	}
	return v;
}
"

# 老旧抹灰墙面:霉斑变色 + 批刮横纹 + 涂料剥落 + 石膏板竖缝 + 下部深绿墙裙与垂痕
const WALL_SHADER := "
shader_type canvas_item;
%NOISE%
void fragment() {
	vec2 p = UV * vec2(3.0, 3.2);
	vec3 col = vec3(0.545, 0.522, 0.455);
	col *= 0.90 + 0.20 * n_fbm(p * 1.3);                    // 大尺度霉斑/变色
	col *= 0.955 + 0.09 * n_fbm(p * 5.0 + 31.0);            // 中尺度抹灰不均
	col += (n_val(p * 240.0) - 0.5) * 0.055;                // 细颗粒(漆膜砂眼)
	float rows = p.y * 18.0 + n_val(vec2(p.x * 3.0, floor(p.y * 18.0))) * 1.4;
	col += sin(rows * 6.28318) * 0.020 * (0.5 + 0.5 * n_val(p * vec2(30.0, 2.0)));  // 批刮横纹
	float peel = smoothstep(0.64, 0.70, n_fbm(p * 2.1 + 57.0));
	col = mix(col, col * vec3(0.82, 0.80, 0.74) + 0.015, peel * 0.9);               // 涂料剥落斑块
	float seam = min(abs(UV.x - 0.3333), abs(UV.x - 0.6667)) * 3.0;
	col *= 1.0 - smoothstep(0.012, 0.004, seam) * 0.13;     // 石膏板竖缝(每米一条)
	col *= mix(1.03, 0.74, pow(UV.y, 1.5));                 // 上亮下暗积尘
	float band = smoothstep(0.60, 0.625, UV.y);             // 墙裙分界(下 38%)
	vec3 bcol = vec3(0.235, 0.265, 0.215) * (0.82 + 0.36 * n_fbm(p * 2.5 + 91.0));
	bcol += (n_val(p * 240.0) - 0.5) * 0.05;
	col = mix(col, bcol, band);
	col *= 1.0 - exp(-pow((UV.y - 0.622) * 120.0, 2.0)) * 0.30;   // 墙裙压线
	float drip = smoothstep(0.55, 0.85, n_val(vec2(p.x * 14.0, 3.7)));
	col *= 1.0 - band * drip * smoothstep(0.62, 0.78, UV.y) * 0.30; // 墙裙垂渍
	COLOR = vec4(col, 1.0);
}
"

# 墙面法线:橘皮凹凸 + 批刮起伏 + 麻点 + 竖缝凹槽,采样邻域高度差直接得法线
const WALL_NORMAL_SHADER := "
shader_type canvas_item;
%NOISE%
float wall_h(vec2 uv) {
	vec2 p = uv * vec2(3.0, 3.2);
	float h = 0.5;
	h += (n_fbm(p * 7.0 + 13.0) - 0.5) * 0.35;              // 橘皮中尺度起伏
	h += (n_val(p * 160.0) - 0.5) * 0.12;                   // 细微粒
	float rows = p.y * 18.0 + n_val(vec2(p.x * 3.0, floor(p.y * 18.0))) * 1.4;
	h += sin(rows * 6.28318) * 0.045;                       // 批刮纹起伏
	h -= smoothstep(0.78, 0.95, n_val(p * 90.0 + 40.0)) * 0.18;  // 麻点
	h -= smoothstep(0.012, 0.004, min(abs(uv.x - 0.3333), abs(uv.x - 0.6667)) * 3.0) * 0.5;  // 竖缝
	return h;
}
void fragment() {
	vec2 e = vec2(1.5 / 1024.0, 0.0);
	float dx = (wall_h(UV + e) - wall_h(UV - e)) * 2.2;
	float dy = (wall_h(UV + e.yx) - wall_h(UV - e.yx)) * 2.2;
	vec3 n = normalize(vec3(-dx, dy, 1.0));
	COLOR = vec4(n * 0.5 + 0.5, 1.0);
}
"

# 1m 方砖地面:砖色微差 + 磨损 + 跨砖污渍 + 深缝与崩边
const FLOOR_SHADER := "
shader_type canvas_item;
%NOISE%
void fragment() {
	vec2 p = UV * 4.0;
	float th = n_hash(floor(p));
	vec3 col = mix(vec3(0.415, 0.395, 0.365), vec3(0.45, 0.435, 0.40), th);  // 每砖微差
	col *= 0.90 + 0.24 * n_fbm(p * 3.0 + th * 7.0);         // 砖内磨损
	col *= 0.88 + 0.24 * n_fbm(p * 0.8 + 5.0);              // 跨砖污渍
	col += (n_val(p * 320.0) - 0.5) * 0.05;                 // 细颗粒
	vec2 g = abs(fract(p) - 0.5);
	float groove = smoothstep(0.482, 0.494, max(g.x, g.y));
	col = mix(col, vec3(0.13, 0.12, 0.10) * (0.8 + 0.4 * n_val(p * 90.0)), groove);  // 砖缝
	col *= 1.0 - smoothstep(0.40, 0.475, max(g.x, g.y)) * (1.0 - groove) * 0.18;     // 砖缘积灰
	float crack = smoothstep(0.74, 0.78, n_val(p * 26.0 + vec2(7.0, 3.0)));
	col *= 1.0 - crack * (1.0 - groove) * 0.25;             // 细裂纹
	float chip = smoothstep(0.55, 0.85, n_val(p * 50.0 + 20.0)) * groove;
	col = mix(col, col * 0.82 + 0.02, chip * 0.6);          // 缝缘崩缺
	COLOR = vec4(col, 1.0);
}
"

# 地面法线:平缓起伏 + 细粒 + 砖缝凹槽 + 缘口微翘
const FLOOR_NORMAL_SHADER := "
shader_type canvas_item;
%NOISE%
float floor_h(vec2 uv) {
	vec2 p = uv * 4.0;
	float h = 0.5;
	h += (n_fbm(p * 2.2 + 3.0) - 0.5) * 0.18;
	h += (n_val(p * 220.0) - 0.5) * 0.06;
	vec2 g = abs(fract(p) - 0.5);
	float groove = smoothstep(0.482, 0.494, max(g.x, g.y));
	h -= groove * 0.6;
	h += smoothstep(0.44, 0.478, max(g.x, g.y)) * (1.0 - groove) * 0.06;
	return h;
}
void fragment() {
	vec2 e = vec2(1.5 / 1024.0, 0.0);
	float dx = (floor_h(UV + e) - floor_h(UV - e)) * 2.4;
	float dy = (floor_h(UV + e.yx) - floor_h(UV - e.yx)) * 2.4;
	vec3 n = normalize(vec3(-dx, dy, 1.0));
	COLOR = vec4(n * 0.5 + 0.5, 1.0);
}
"

# 天花:抹灰大块水渍暗斑 + 潮斑环 + 细颗粒(法线复用墙面 wall_n)
const CEIL_SHADER := "
shader_type canvas_item;
%NOISE%
void fragment() {
	vec2 p = UV * 4.0;
	vec3 col = vec3(0.29, 0.278, 0.245);
	col *= 0.72 + 0.55 * n_fbm(p * 1.4);                    // 大块明暗
	float stain = smoothstep(0.58, 0.70, n_fbm(p * 0.9 + 40.0));
	col = mix(col, col * vec3(0.70, 0.66, 0.60), stain);    // 渗水黄斑
	float peel = smoothstep(0.63, 0.72, n_fbm(p * 2.6 + 77.0));
	col = mix(col, vec3(0.345, 0.325, 0.295), peel * 0.8);  // 涂料剥落露灰底
	col += (n_val(p * 260.0) - 0.5) * 0.05;
	COLOR = vec4(col, 1.0);
}
"

func proc_texture(size: int, code: String, renorm := false) -> ImageTexture:
	# SubViewport 渲染一片全屏噪声着色器后取回图像;headless 无渲染返回 null(调用方退纯色)
	if _headless:
		return null
	var sh := Shader.new()
	sh.code = code.replace("%NOISE%", NOISE_LIB)
	var vp := SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := ColorRect.new()
	rect.size = Vector2(size, size)
	var sm := ShaderMaterial.new()
	sm.shader = sh
	rect.material = sm
	vp.add_child(rect)
	return await _render_vp(vp, renorm)

# ---------- 文本/图形贴图(需要渲染;headless 返回 null,调用方退纯色) ----------

func text_texture(w: int, h: int, paint: Callable) -> ImageTexture:
	if _headless:
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var painter := Control.new()
	painter.size = Vector2(w, h)
	painter.draw.connect(func(): paint.call(painter))
	vp.add_child(painter)
	return await _render_vp(vp)

## 批处理取图核心:挂树 → 统一等待两个 frame_post_draw(兜底)→ 取图释放。
## prepare() 先挂全部 SubViewport 再统一 await,串行白等 ≈38 帧收敛为 2 帧。
func _render_vp(vp: SubViewport, renorm := false) -> ImageTexture:
	Engine.get_main_loop().root.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	return to_texture(img, renorm)

func draw_text_line(c: Control, s: String, x: float, y: float, size: int, col: Color, bold := false, center := false) -> void:
	var f: Font = font if font != null else ThemeDB.fallback_font
	if center:
		x += (c.size.x - f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) * 0.5
	if bold:
		c.draw_string_outline(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.4))
	c.draw_string(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# ---------- 全部贴图一次性生成 ----------
# 两阶段批处理(A1/B1):所有需 GPU/绘制的 SubViewport 先一次挂树,
# 统一 await 两个 frame_post_draw 后逐个取图——替代原来每张贴图串行各等两帧。
# 无头模式整段跳过(B6):headless 下贴图不被采样,材质走 has()==false 的纯色回退,
# 与 GPU 类贴图的既有语义一致。

func prepare() -> void:
	if _headless:
		return
	var vps: Dictionary = {}   # tex 名 -> SubViewport(已挂树待渲染)

	vps["wall"] = _vp_shader(1024, WALL_SHADER)
	vps["wall_n"] = _vp_shader(1024, WALL_NORMAL_SHADER)
	vps["floor"] = _vp_shader(1024, FLOOR_SHADER)
	vps["floor_n"] = _vp_shader(1024, FLOOR_NORMAL_SHADER)
	vps["ceil"] = _vp_shader(512, CEIL_SHADER)

	vps["mj"] = _vp_paint(256, 256, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 256, 256), Color.html("2d4a33"))
		for i in 400:
			c.draw_rect(Rect2(randf() * 256, randf() * 256, 4, 4), Color(0, 0, 0, 0.12))
		for i in 3:
			c.draw_rect(Rect2(128 - 72 + i * 50, 104, 40, 52), Color.html("efe8d0"))
		var chars := ["救", "救", "我"]
		for i in 3:
			draw_text_line(c, chars[i], 128 - 72 + i * 50 + 4, 140, 34, Color.html("222222"), true))

	vps["paper"] = _vp_paint(256, 256, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 256, 256), Color.html("d8cfb4"))
		for i in 200:
			c.draw_rect(Rect2(randf() * 256, randf() * 256, 4, 4), Color(0.1, 0.1, 0.08, 0.06))
		draw_text_line(c, "住 户 须 知", 0, 42, 15, Color.html("3a3428"), false, true)
		var lines := [
			"一、电梯限乘四人。若电梯内已有", "\"人\",请等下一班。", "二、若按钮13层亮起但无人按", "下,请立即退出。", "三、电梯内镜子不可直视超", "过三秒。", "四、若停靠后门迟迟不开,请", "闭眼、背对门站立。"]
		for i in lines.size():
			draw_text_line(c, lines[i], 30, 74 + i * 22, 13, Color.html("3a3428")))

	vps["obit"] = _vp_paint(256, 256, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 256, 256), Color.html("cfd4cf"))
		draw_text_line(c, "讣 告", 0, 36, 18, Color.html("2c302c"), true, true)
		var lines := ["赵氏三兄弟,皆殁于丁丑年", "大火。祭香之礼,先尊后幼:", "长子 赵大河(58)", "次子 赵二河(53)", "幼子 赵小河(41)", "——切不可乱了长幼。"]
		for i in lines.size():
			draw_text_line(c, lines[i], 28, 70 + i * 24, 13, Color.html("2c302c")))

	vps["monitor"] = _vp_paint(256, 200, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 256, 200), Color.html("0c1410"))
		c.draw_rect(Rect2(256 * 0.3, 20, 256 * 0.4, 160), Color.html("3f5a48"), false, 4.0)
		c.draw_rect(Rect2(127, 20, 2.5, 160), Color.html("3f5a48"))
		c.draw_circle(Vector2(128, 76), 13, Color.html("050a07"))
		c.draw_rect(Rect2(117, 88, 22, 42), Color.html("050a07"))
		draw_text_line(c, "CAM-01 00:03:12", 10, 186, 12, Color.html("7fae8c"))
		for i in 300:
			c.draw_rect(Rect2(randf() * 256, randf() * 200, 2, 2), Color(0.47, 0.7, 0.55, randf() * 0.08)))

	vps["portrait"] = _vp_paint(128, 160, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 128, 160), Color.html("1a1a1c"))
		c.draw_circle(Vector2(64, 64), 34, Color.html("3c3c40"))
		c.draw_rect(Rect2(22, 88, 84, 70), Color.html("3c3c40"))
		c.draw_rect(Rect2(4, 4, 120, 152), Color.html("8a8474"), false, 8.0)
		draw_text_line(c, "林 砚", 0, 146, 14, Color.html("9a9484"), false, true))

	vps["plaque"] = _vp_paint(128, 80, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 128, 80), Color.html("2e2b26"))
		c.draw_rect(Rect2(5, 5, 118, 70), Color.html("6a6250"), false, 4.0)
		draw_text_line(c, "1304", 0, 50, 42, Color.html("c8b46a"), true, true))

	vps["diary"] = _vp_paint(128, 160, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 128, 160), Color.html("7a3040"))
		c.draw_rect(Rect2(0, 0, 26, 160), Color.html("4a1c28"))
		draw_text_line(c, "音", 0, 76, 36, Color.html("d8c8a8"), true, true)
		draw_text_line(c, "日 记", 0, 116, 16, Color.html("d8c8a8"), false, true))

	vps["paperman"] = _vp_paint(128, 256, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 128, 256), Color.html("dcd6c4"))
		c.draw_circle(Vector2(128 * 0.38, 256 * 0.4), 10, Color.html("1a1a1a"))
		c.draw_circle(Vector2(128 * 0.62, 256 * 0.4), 10, Color.html("1a1a1a"))
		c.draw_arc(Vector2(64, 256 * 0.62), 26, 0.15 * TAU, 0.85 * TAU, 24, Color.html("1a1a1a"), 5)
		c.draw_rect(Rect2(128 * 0.2, 256 * 0.75, 128 * 0.6, 8), Color(150.0/255, 60.0/255, 50.0/255, 0.4)))

	# 3F 黑板:墨绿板面 + 三行褪色粉笔字
	vps["chalk"] = _vp_paint(256, 160, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 256, 160), Color.html("28402e"))
		for i in 240:
			c.draw_rect(Rect2(randf() * 256, randf() * 160, 3, 3), Color(1, 1, 1, 0.025))
		draw_text_line(c, "小朋友们要乖乖睡觉", 16, 44, 17, Color.html("e8e2ce"))
		draw_text_line(c, "老师一直看着你们呢", 24, 80, 17, Color.html("d8b0a0"))
		draw_text_line(c, "铃响之前 谁也不许走", 20, 118, 17, Color.html("cfd8e0")))

	# 3F 儿童画(蜡笔):太阳 + 小人 + 房子
	vps["crayon"] = _vp_paint(128, 128, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 128, 128), Color.html("e8ddc4"))
		c.draw_rect(Rect2(6, 6, 116, 116), Color.html("d8ccae"), false, 3.0)
		c.draw_circle(Vector2(36, 40), 14, Color.html("e8b84a"))
		for i in 8:
			c.draw_line(Vector2(36, 40) + Vector2(17, 0).rotated(i * TAU / 8.0), Vector2(36, 40) + Vector2(25, 0).rotated(i * TAU / 8.0), Color.html("e8b84a"), 3.0)
		c.draw_rect(Rect2(78, 56, 34, 40), Color.html("b06a4a"))
		c.draw_polygon(PackedVector2Array([Vector2(74, 58), Vector2(116, 58), Vector2(95, 38)]), PackedColorArray([Color.html("8a4a3a")]))
		c.draw_circle(Vector2(60, 88), 11, Color.html("e0c4a0"))
		c.draw_rect(Rect2(52, 98, 16, 22), Color.html("6a8ac0"))
		c.draw_circle(Vector2(56, 86), 2.2, Color.html("1a1a1a"))
		c.draw_circle(Vector2(64, 86), 2.2, Color.html("1a1a1a"))
		c.draw_arc(Vector2(60, 91), 4.5, 0.2 * TAU, 0.8 * TAU, 10, Color.html("1a1a1a"), 2))

	# 11F 壁画:暗底上的整栋楼,窗格零星亮灯、一扇红窗
	vps["mural"] = _vp_paint(256, 256, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 256, 256), Color.html("241a1e"))
		c.draw_circle(Vector2(128, 128), 92, Color(120.0/255, 30.0/255, 40.0/255, 0.35))
		c.draw_rect(Rect2(78, 52, 100, 176), Color.html("3a2e30"))
		c.draw_rect(Rect2(72, 224, 112, 8), Color.html("2c2224"))
		for fy in 12:
			for fx in 4:
				var wx := 88 + fx * 22
				var wy := 62 + fy * 14
				var lit := (fx * 7 + fy * 13) % 10 < 3
				var col: Color = Color.html("7a5a28") if lit else Color.html("181214")
				if fx == 2 and fy == 8:
					col = Color.html("a8282a")
				c.draw_rect(Rect2(wx, wy, 12, 8), col)
		draw_text_line(c, "每年今夜 · 无回", 0, 246, 13, Color.html("6a5448"), false, true))

	# 10F 请柬:红底金字囍卡
	vps["invite"] = _vp_paint(128, 176, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 128, 176), Color.html("8e2f32"))
		c.draw_rect(Rect2(8, 8, 112, 160), Color.html("c9a55a"), false, 3.0)
		c.draw_rect(Rect2(14, 14, 100, 148), Color.html("8e2f32"), false, 2.0)
		draw_text_line(c, "囍", 0, 78, 46, Color.html("e8c878"), true, true)
		draw_text_line(c, "许文远 · 苏晚晴", 0, 118, 14, Color.html("e8c878"), false, true)
		draw_text_line(c, "恭候光临", 0, 148, 12, Color.html("c9a55a"), false, true))

	# 12F 全家福:泛黄老照片,烧焦的边
	vps["photo"] = _vp_paint(128, 96, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 128, 96), Color.html("c8b48e"))
		c.draw_rect(Rect2(0, 0, 128, 96), Color(80.0/255, 60.0/255, 30.0/255, 0.18))
		c.draw_rect(Rect2(30, 26, 24, 52), Color.html("6a7a92"))
		c.draw_circle(Vector2(42, 22), 9, Color.html("d8c0a0"))
		c.draw_rect(Rect2(66, 34, 20, 44), Color.html("7a6250"))
		c.draw_circle(Vector2(76, 28), 7.5, Color.html("d8c0a0"))
		for i in 3:
			c.draw_rect(Rect2(0, i * 32, 128, 2), Color(60.0/255, 40.0/255, 20.0/255, 0.08))
		for i in 5:
			c.draw_polygon(PackedVector2Array([Vector2(i * 30, 0), Vector2(i * 30 + 14, 0), Vector2(i * 30 + 6, 10)]), PackedColorArray([Color(30.0/255, 18.0/255, 10.0/255, 0.55)])))

	# 纸人脸谱:纸底 + 墨线五官(7F 纸人正面)
	vps["paperface"] = _vp_paint(128, 128, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 128, 128), Color.html("dcd6c4"))
		for i in 120:
			c.draw_rect(Rect2(randf() * 128, randf() * 128, 3, 3), Color(0.1, 0.1, 0.08, 0.05))
		var ink := Color.html("1c1a18")
		c.draw_arc(Vector2(44, 52), 9, PI * 1.15, PI * 1.95, 12, ink, 4)
		c.draw_arc(Vector2(84, 52), 9, PI * 1.05, PI * 1.85, 12, ink, 4)
		c.draw_line(Vector2(34, 40), Vector2(54, 36), ink, 3)
		c.draw_line(Vector2(74, 36), Vector2(94, 40), ink, 3)
		c.draw_circle(Vector2(44, 54), 2.5, ink)
		c.draw_circle(Vector2(84, 54), 2.5, ink)
		c.draw_line(Vector2(64, 56), Vector2(62, 70), ink, 2)
		c.draw_arc(Vector2(64, 78), 12, PI * 0.15, PI * 0.85, 12, Color.html("a03028"), 4)
		c.draw_circle(Vector2(36, 70), 6, Color(0.7, 0.3, 0.2, 0.15))
		c.draw_circle(Vector2(92, 70), 6, Color(0.7, 0.3, 0.2, 0.15)))

	# 阶段一收尾:全部 viewport 已挂树,统一等待两帧后批量取图
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for k: String in vps:
		tex[k] = _collect_vp(vps[k], k == "wall_n" or k == "floor_n")

	_prepare_cpu_tex()

## 建噪声 shader 的 SubViewport 并挂树
func _vp_shader(size: int, code: String) -> SubViewport:
	var sh := Shader.new()
	sh.code = code.replace("%NOISE%", NOISE_LIB)
	return _vp_new(size, size, func(rect: ColorRect) -> void:
		var sm := ShaderMaterial.new()
		sm.shader = sh
		rect.material = sm)

## 建绘制控件的 SubViewport 并登记 paint 回调(draw 在随后的渲染帧触发)
func _vp_paint(w: int, h: int, paint: Callable) -> SubViewport:
	var vp := _vp_new(w, h, Callable())
	var painter := vp.get_child(0) as Control
	painter.draw.connect(func(): paint.call(painter))
	return vp

func _vp_new(w: int, h: int, setup: Callable) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := ColorRect.new()
	rect.size = Vector2(w, h)
	vp.add_child(rect)
	if setup.is_valid():
		setup.call(rect)
	Engine.get_main_loop().root.add_child(vp)
	return vp

## 取图并释放 viewport(to_texture 内含 mipmap 生成)
func _collect_vp(vp: SubViewport, renorm: bool) -> ImageTexture:
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	return to_texture(img, renorm)

## 纯 CPU 贴图(小面材质/法线/人物基底):headless 下被 prepare() 整段跳过
func _prepare_cpu_tex() -> void:
	# 小面材质:CPU 画布
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(Color.html("5d4530"))
	for i in 8:
		blend_rect(img, i * 32, 0, 16, 256, Color(30.0/255, 18.0/255, 8.0/255, 0.15 + randf() * 0.15))
	tex.door = to_texture(img)

	img = Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(Color.html("7c8084"))
	for x in range(0, 256, 4):
		blend_rect(img, x, 0, 2, 256, Color(1, 1, 1, randf() * 0.06))
	blend_rect(img, 0, 0, 6, 256, Color(0, 0, 0, 0.3))
	blend_rect(img, 250, 0, 6, 256, Color(0, 0, 0, 0.3))
	tex.metal = to_texture(img)

	tex.door_n = _make_normal(256, func(hi: Image):
		hi.fill(Color(0.5, 0.5, 0.5))
		for x in range(0, 256, 3):
			var v := (70.0 + randf() * 90.0) / 255.0
			blend_rect(hi, x, 0, 2, 256, Color(v, v, v, 0.5)), 1.4)
	tex.metal_n = _make_normal(256, func(hi: Image):
		hi.fill(Color(0.5, 0.5, 0.5))
		for y in range(0, 256, 2):
			var v := (90.0 + randf() * 80.0) / 255.0
			blend_rect(hi, 0, y, 256, 1, Color(v, v, v, 0.4)), 0.8)

	# B2 肉壁:暗红底 + 深浅肉色斑块 + 血管纹
	img = Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(Color.html("6e3230"))
	for i in 90:
		var bx := randf() * 256.0
		var by := randf() * 256.0
		var br := 8.0 + randf() * 26.0
		blend_rect(img, bx - br, by - br * 0.7, br * 2.0, br * 1.4, Color.html("8a4640" if randf() < 0.5 else "54262a").darkened(randf() * 0.2))
	for i in 26:
		var vx := randf() * 256.0
		var vy := randf() * 256.0
		blend_rect(img, vx, vy, 2.0 + randf() * 3.0, 30.0 + randf() * 80.0, Color(40.0/255, 12.0/255, 14.0/255, 0.4))
	tex.flesh = to_texture(img)
	tex.flesh_n = _make_normal(256, func(hi: Image):
		hi.fill(Color(0.5, 0.5, 0.5))
		for i in 120:
			var bx := randf() * 256.0
			var by := randf() * 256.0
			var v := (100.0 + randf() * 120.0) / 255.0
			blend_rect(hi, bx, by, 10.0 + randf() * 24.0, 8.0 + randf() * 16.0, Color(v, v, v, 0.5)), 1.2)

	# ---------- 人物皮肤/布料(灰度基底,靠材质 albedo 染色)----------

	# 皮肤:细毛孔 + 泛红斑(与 skin_n 配合)
	img = Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var fx := float(x) / 128.0
			var fy := float(y) / 128.0
			var g := _vnoise(fx * 9.0, fy * 9.0, 9, 9) * 0.45 \
				+ _vnoise(fx * 33.0 + 4.0, fy * 33.0, 33, 33) * 0.35 \
				+ _vnoise(fx * 90.0 + 8.0, fy * 90.0 + 2.0, 90, 90) * 0.2
			var blotch := smoothstep(0.62, 0.75, _vnoise(fx * 4.0 + 21.0, fy * 4.0 + 13.0, 4, 4)) * 0.10
			var v := clampf(0.86 + (g - 0.5) * 0.16 - blotch, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.995, v * 0.985))
	tex.skin = to_texture(img)
	tex.skin_n = _make_normal(128, func(hi: Image):
		hi.fill(Color(0.5, 0.5, 0.5))
		for i in 700:
			var v := (110.0 + randf() * 60.0) / 255.0
			blend_rect(hi, randf() * 128.0, randf() * 128.0, 1.6, 1.6, Color(v, v, v, 0.5)), 0.7)

	# 布料:经纬织纹 + 微差 + 皱褶条痕
	img = Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var fx := float(x) / 128.0
			var fy := float(y) / 128.0
			var weave := (sin(fx * TAU * 12.0) * 0.5 + 0.5) * 0.6 + (cos(fy * TAU * 12.0) * 0.5 + 0.5) * 0.4
			var g := _vnoise(fx * 6.0, fy * 6.0, 6, 6) * 0.5 + _vnoise(fx * 20.0 + 3.0, fy * 20.0, 20, 20) * 0.5
			var wrinkle := smoothstep(0.55, 0.8, _vnoise(fx * 3.0 + 17.0, fy * 3.0 + 9.0, 3, 3)) * 0.12
			var v := clampf(0.84 + (weave - 0.5) * 0.10 + (g - 0.5) * 0.10 - wrinkle, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v * 0.99))
	tex.cloth = to_texture(img)
	tex.cloth_n = _make_normal(128, func(hi: Image):
		hi.fill(Color(0.5, 0.5, 0.5))
		for y in 128:
			for x in 128:
				var w := sin(float(x) / 128.0 * TAU * 12.0) * 0.5 + cos(float(y) / 128.0 * TAU * 12.0) * 0.5
				var v := 0.5 + w * 0.06
				hi.set_pixel(x, y, Color(v, v, v))
		for i in 26:
			blend_rect(hi, randf() * 128.0, randf() * 128.0, 2.0 + randf() * 3.0, 30.0 + randf() * 70.0, Color(0.32, 0.32, 0.32, 0.35)), 1.0)

	# 纸纹(纸人躯体):纸底 + 竖向纤维 + 斑点
	img = Image.create(128, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 128:
			var fx := float(x) / 128.0
			var fy := float(y) / 256.0
			var g := _vnoise(fx * 7.0, fy * 7.0, 7, 7) * 0.5 + _vnoise(fx * 30.0 + 3.0, fy * 30.0, 30, 30) * 0.5
			var fiber := sin(fy * 480.0 + _vnoise(fx * 12.0, fy * 12.0, 12, 12) * 6.0) * 0.03
			var v := clampf(0.88 + (g - 0.5) * 0.10 + fiber, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.985, v * 0.94))
	tex.papergrain = to_texture(img)

	# B2 脉络 emission:黑底 + 暗红随机走向粗线
	img = Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(Color(0.05, 0.012, 0.018))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 14:
		var vx := rng.randf() * 128.0
		var vy := rng.randf() * 128.0
		var ang := rng.randf() * TAU
		for j in 24:
			ang += (rng.randf() - 0.5) * 0.9
			var ln := 3.0 + rng.randf() * 4.0
			var nx := vx + cos(ang) * ln
			var ny := vy + sin(ang) * ln
			_img_line(img, vx, vy, nx, ny, 1.5 + rng.randf() * 2.0, Color(0.55, 0.08, 0.06))
			vx = nx
			vy = ny
	tex.vein = to_texture(img)

func has(name: String) -> bool:
	return tex.has(name) and tex[name] != null

## 逐像素粗线(供 CPU 画布纹理用)
static func _img_line(img: Image, x0: float, y0: float, x1: float, y1: float, w: float, col: Color) -> void:
	var steps := int(maxf(absf(x1 - x0), absf(y1 - y0))) + 1
	var hw := w * 0.5
	for i in steps + 1:
		var t := float(i) / float(steps)
		var px := lerpf(x0, x1, t)
		var py := lerpf(y0, y1, t)
		for yy in range(int(py - hw), int(py + hw) + 1):
			for xx in range(int(px - hw), int(px + hw) + 1):
				if xx >= 0 and xx < img.get_width() and yy >= 0 and yy < img.get_height():
					img.set_pixel(xx, yy, col)
