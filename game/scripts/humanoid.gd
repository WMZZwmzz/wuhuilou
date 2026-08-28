class_name Humanoid
extends RefCounted
## 程序化雕刻人形:全部网格由代码生成(旋转成型 lathe / 位移球体 sculpt / 路径管 tube),
## 取代原始体(胶囊+方块)拼装的人物建模。CPU 侧构建,headless 环境同样可用。
## 对外入口 build(m, cfg):cfg 键与返回字典键与旧 props.human_figure 契约完全一致;
## 新增键:apron(围裙)/ polo(网管服)/ uniform(保安服细节)/ silhouette(黑色剪影)/ sil_alpha。

const FRONT := -PI / 2.0   # lathe θ=−π/2 朝向 -Z(正面)

# 贴图基准:生成器的 UV 为世界米制,故需声明每张平铺贴图代表多大的世界尺寸,
# 材质侧 uv1_scale = 1 / tile(米),使织纹/毛孔密度与部件大小无关。
const CLOTH_TILE_M := 0.12
const SKIN_TILE_M := 0.07

## 各面料一张 tile 覆盖的真实世界尺寸(m)。程序化织纹与外部 CC0 扫描的尺度不同,
## 混用时必须分别换算 uv1_scale,否则外部布料会明显过粗/过细。
static func _fabric_tile(fab: String) -> float:
	match fab:
		"cloth_cotton": return 0.10
		"cloth_denim": return 0.16
		"cloth_satin": return 0.20
		"leather_brown": return 0.28
	return CLOTH_TILE_M

# ---------- 基础网格工具 ----------

static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _xf(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	var b := Basis().scaled(scl)
	if rot.x != 0.0:
		b = Basis(Vector3.RIGHT, rot.x) * b
	if rot.y != 0.0:
		b = Basis(Vector3.UP, rot.y) * b
	if rot.z != 0.0:
		b = Basis(Vector3.BACK, rot.z) * b
	return Transform3D(b, pos)

static func _mesh(pos: PackedVector3Array, nrm: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array, colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	if colors.size() == pos.size():
		arrays[Mesh.ARRAY_COLOR] = colors
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am

## 米制 UV:按行/列累加真实 3D 弧长(单位=米),使贴图密度与部件尺寸无关。
## pos 为 rows×cols 网格(索引 = r*cols+c);row_arc[r] 为第 r-1 行到第 r 行的行间距(米)。
static func _metric_uv(pos: PackedVector3Array, rows: int, cols: int, row_arc: PackedFloat32Array) -> PackedVector2Array:
	var uv := PackedVector2Array()
	uv.resize(rows * cols)
	var v_acc := 0.0
	for r in rows:
		if r > 0:
			v_acc += row_arc[r]
		var u_acc := 0.0
		for c in cols:
			if c > 0:
				u_acc += (pos[r * cols + c] - pos[r * cols + c - 1]).length()
			uv[r * cols + c] = Vector2(u_acc, v_acc)
	return uv

## 轮廓旋转成型:profile 为 [[半径, y], …](自下而上,y 递增)。
## opts: theta_len/theta_off(局部弧段,正面在 θ=−π/2)、z_scale(前后压扁)、
##       wave_amp/wave_freq(下摆波浪,自底向顶线性衰减)、caps(封底/封盖)。
## 法线由 (∂P/∂profile, ∂P/∂θ) 解析求得(含波浪导数与 z_scale),UV 为世界米制。
static func lathe(profile: Array, radial_seg := 14, opts := {}) -> ArrayMesh:
	var theta_len: float = opts.get("theta_len", TAU)
	var theta_off: float = opts.get("theta_off", 0.0)
	var z_scale: float = opts.get("z_scale", 1.0)
	var wave_amp: float = opts.get("wave_amp", 0.0)
	var wave_freq: int = opts.get("wave_freq", 6)
	var caps: bool = opts.get("caps", false)
	var rows: int = profile.size()
	var full: bool = theta_len >= TAU - 0.001
	var cols: int = radial_seg + (1 if full else 0)
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	pos.resize(rows * cols)
	nrm.resize(rows * cols)
	# profile 的逐行弧长(米)与中心差分切量
	var row_arc := PackedFloat32Array()
	row_arc.resize(rows)
	var dR := PackedFloat32Array()
	var dY := PackedFloat32Array()
	dR.resize(rows)
	dY.resize(rows)
	for r in rows:
		var pa: Array = profile[maxi(0, r - 1)]
		var pb: Array = profile[mini(rows - 1, r + 1)]
		dR[r] = float(pb[0]) - float(pa[0])
		dY[r] = float(pb[1]) - float(pa[1])
		if r > 0:
			var qr: Array = profile[r - 1]
			var rr: Array = profile[r]
			var drr: float = float(rr[0]) - float(qr[0])
			var dry: float = float(rr[1]) - float(qr[1])
			row_arc[r] = sqrt(drr * drr + dry * dry)
	var rows_d := maxf(1.0, float(rows - 1))
	for r in rows:
		# 该行波浪幅度与它对行向的导数(自底向顶线性衰减)
		var wf: float = wave_amp * (1.0 - float(r) / rows_d)
		var dwf_dr: float = -wave_amp / rows_d
		var yy: float = float(profile[r][1])
		var base_r: float = float(profile[r][0])
		for c in cols:
			var th: float = theta_off + float(c) / float(radial_seg) * theta_len
			var cp := cos(th)
			var sp := sin(th)
			var sw := sin(th * wave_freq)
			var cw := cos(th * wave_freq)
			var rad: float = base_r + wf * sw
			# ∂rad/∂θ 与 ∂rad/∂行(含波浪项)
			var drad_dth: float = wf * float(wave_freq) * cw
			var drad_dr: float = dR[r] + dwf_dr * sw
			var i: int = r * cols + c
			pos[i] = Vector3(cp * rad, yy, sp * rad * z_scale)
			# 切向量:沿 profile 方向 与 沿 θ 方向
			var tr := Vector3(cp * drad_dr, dY[r], sp * drad_dr * z_scale)
			var tt := Vector3(-sp * rad + cp * drad_dth, 0.0, (cp * rad + sp * drad_dth) * z_scale)
			var n := tr.cross(tt)
			if n.length() < 1e-9:
				n = Vector3(cp, 0.0, sp)
			n = n.normalized()
			# 定向外侧(lathe 的朝外半球由方位角决定)
			if n.dot(Vector3(cp, 0.0, sp)) < 0.0:
				n = -n
			nrm[i] = n
	var uv := _metric_uv(pos, rows, cols, row_arc)
	# 侧壁每行的四边形数 = cols-1:整圆时最末一格接到重复的接缝列,开口弧时不能越过末列
	for r in rows - 1:
		for c in cols - 1:
			var a: int = r * cols + c
			var b: int = a + 1
			var cc: int = a + cols
			var d: int = cc + 1
			idx.append_array(PackedInt32Array([a, d, cc, a, b, d]))
	if caps and full:
		# 封口手性以实测为准:此顺序下整具人形无任何 surface 报朝向矛盾(consist=1.0);
		# 写成 [cb, c+1, c] / [ct, lr+c, lr+c+1] 会让两片盖共 24 个三角形与 96 个侧壁三角形反向。
		var cb := pos.size()
		pos.append(Vector3(0, float(profile[0][1]), 0))
		nrm.append(Vector3.DOWN)
		uv.append(Vector2(0.0, 0.0))
		for c in radial_seg:
			idx.append_array(PackedInt32Array([cb, c, c + 1]))
		# 顶盖(朝 +Y)
		var ct := pos.size()
		var lr := (rows - 1) * cols
		pos.append(Vector3(0, float(profile[rows - 1][1]), 0))
		nrm.append(Vector3.UP)
		uv.append(Vector2(float(profile[rows - 1][0]), 0.0))
		for c in radial_seg:
			idx.append_array(PackedInt32Array([ct, lr + c + 1, lr + c]))
	return _mesh(pos, nrm, uv, idx)

## 球面参数 (u,t) → 位移后的顶点位置(t 自底向顶;alpha 由 a_bot 走到 a_top)。
static func _sph_pt(r: float, z_scale: float, a_bot: float, a_top: float, disp: Callable, u: float, t: float) -> Vector3:
	var alpha := lerpf(a_bot, a_top, t)
	var sy := cos(alpha)
	var sr := sin(alpha)
	var th := u * TAU
	var dir := Vector3(sr * cos(th), sy, sr * sin(th))
	var p := Vector3(dir.x * r, dir.y * r, dir.z * r * z_scale)
	if disp.is_valid():
		p += disp.call(dir, u, t)
	return p

## 位移球体:y_range 为归一化 y 裁剪范围(-1 底 … 1 顶);displace(dir, u, v) -> Vector3 位移偏移。
## z_scale 前后压扁(椭球截面)。
## 有位移或 z_scale≠1 时,法线由参数域中心差分的切向量叉积求得(原实现直接取未位移径向,
## 会把下颌/颧骨/眼窝/鼻梁等雕刻细节在光照下抹平);真球面走解析快速路径。
static func sculpt_sphere(r: float, seg := 16, rings := 12, displace: Callable = Callable(), y_range := Vector2(-1.0, 1.0), z_scale := 1.0) -> ArrayMesh:
	var a_top := acos(clampf(y_range.y, -1.0, 1.0))
	var a_bot := acos(clampf(y_range.x, -1.0, 1.0))
	var has_pole_t: bool = absf(y_range.y - 1.0) < 0.001
	var has_pole_b: bool = absf(y_range.x + 1.0) < 0.001
	var rows: int = rings
	if has_pole_t:
		rows -= 1
	if has_pole_b:
		rows -= 1
	var cols: int = seg + 1
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	pos.resize(rows * cols)
	nrm.resize(rows * cols)
	# 非球面(位移/压扁)必须重求法线;真球面保留快速路径,省掉每顶点 4 次求值
	var need_normal_work: bool = displace.is_valid() or absf(z_scale - 1.0) > 0.001
	var eu := 0.25 / float(maxi(1, seg))
	var et := 0.25 / float(maxi(1, rows - 1))
	for i in rows:
		var t: float = float(i) / float(maxi(1, rows - 1))
		for c in cols:
			var u: float = float(c) / float(seg)
			var k: int = i * cols + c
			pos[k] = _sph_pt(r, z_scale, a_bot, a_top, displace, u, t)
			if not need_normal_work:
				var alpha0 := lerpf(a_bot, a_top, t)
				nrm[k] = Vector3(sin(alpha0) * cos(u * TAU), cos(alpha0), sin(alpha0) * sin(u * TAU))
				continue
			var alpha := lerpf(a_bot, a_top, t)
			var sr := sin(alpha)
			var sy := cos(alpha)
			var th := u * TAU
			var dir := Vector3(sr * cos(th), sy, sr * sin(th))
			# u 方向天然周期(θ=u·TAU),可直接中心差分;t 方向在裁剪端点改单侧差分
			var pu := _sph_pt(r, z_scale, a_bot, a_top, displace, u + eu, t) - _sph_pt(r, z_scale, a_bot, a_top, displace, u - eu, t)
			var t_hi := minf(t + et, 1.0)
			var t_lo := maxf(t - et, 0.0)
			var pv := _sph_pt(r, z_scale, a_bot, a_top, displace, u, t_hi) - _sph_pt(r, z_scale, a_bot, a_top, displace, u, t_lo)
			var n := pu.cross(pv)
			if n.length() < 1e-12:
				n = dir
			n = n.normalized()
			if n.dot(dir) < 0.0:
				n = -n
			nrm[k] = n
	# 行间距取 meridinal 方向两列(θ=0 与 θ≈π/2)的真实 3D 距离均值,兼顾 z_scale
	var row_arc := PackedFloat32Array()
	row_arc.resize(rows)
	var c_side: int = mini(cols - 1, maxi(1, seg / 4))
	for i in range(1, rows):
		var d0 := (pos[i * cols] - pos[(i - 1) * cols]).length()
		var d1 := (pos[i * cols + c_side] - pos[(i - 1) * cols + c_side]).length()
		row_arc[i] = (d0 + d1) * 0.5
	var uv := _metric_uv(pos, rows, cols, row_arc)
	for i in rows - 1:
		for c in seg:
			var a: int = i * cols + c
			var b: int = a + 1
			var cc: int = a + cols
			var d: int = cc + 1
			idx.append_array(PackedInt32Array([a, d, cc, a, b, d]))
	if has_pole_b:
		# 底极点(朝 -Y)
		var pb := pos.size()
		pos.append(Vector3(0, -r, 0))
		nrm.append(Vector3.DOWN)
		uv.append(Vector2(uv[0].x, 0.0))
		for c in seg:
			idx.append_array(PackedInt32Array([pb, c + 1, c]))
	if has_pole_t:
		# 顶极点(朝 +Y)
		var pt := pos.size()
		var lr := (rows - 1) * cols
		pos.append(Vector3(0, r, 0))
		nrm.append(Vector3.UP)
		uv.append(Vector2(uv[0].x, uv[rows * cols - 1].y))
		for c in seg:
			idx.append_array(PackedInt32Array([pt, lr + c, lr + c + 1]))
	return _mesh(pos, nrm, uv, idx)

## 路径锥削管:path 为 Vector3 折线,radii 为等长半径序列(自底向顶)。
## 法线计入半径沿路径的变化率(锥度),UV 为世界米制。
static func tube(path: Array, radii: Array, seg := 10) -> ArrayMesh:
	var n := path.size()
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	pos.resize(n * (seg + 1))
	nrm.resize(n * (seg + 1))
	var row_arc := PackedFloat32Array()
	row_arc.resize(n)
	for i in n:
		var p: Vector3 = path[i]
		var prv: Vector3 = path[maxi(0, i - 1)]
		var nxt: Vector3 = path[mini(n - 1, i + 1)]
		var t: Vector3 = (nxt - prv).normalized()
		# 半径对弧长的导数(中心差分,按实际段长归一)
		var ds: float = maxf(0.0001, (nxt - prv).length())
		var drds: float = (float(radii[mini(n - 1, i + 1)]) - float(radii[maxi(0, i - 1)])) / ds
		if i > 0:
			row_arc[i] = float((Vector3(path[i]) - Vector3(path[i - 1])).length())
		var up := Vector3.UP
		if absf(up.dot(t)) > 0.98:
			up = Vector3.RIGHT
		var bn := up.cross(t).normalized()
		var bb := bn.cross(t).normalized()
		for c in seg + 1:
			var f: float = float(c) / float(seg)
			var th := f * TAU
			var rad: float = float(radii[i])
			var dir := bn * cos(th) + bb * sin(th)
			var k: int = i * (seg + 1) + c
			pos[k] = p + dir * rad
			var cn := dir - t * drds
			nrm[k] = cn.normalized() if cn.length() > 1e-9 else dir
	var uv := _metric_uv(pos, n, seg + 1, row_arc)
	for i in n - 1:
		for c in seg:
			var a: int = i * (seg + 1) + c
			var b: int = a + 1
			var cc: int = a + seg + 1
			var d: int = cc + 1
			idx.append_array(PackedInt32Array([a, d, cc, a, b, d]))
	# 起端封口
	var c0 := pos.size()
	pos.append(path[0])
	var cap_n := Vector3.DOWN
	if n > 1:
		cap_n = -(Vector3(path[1]) - Vector3(path[0])).normalized()
	nrm.append(cap_n)
	uv.append(Vector2.ZERO)
	for c in seg:
		idx.append_array(PackedInt32Array([c0, c + 1, c]))
	return _mesh(pos, nrm, uv, idx)

## 合并网格:parts 为 [[ArrayMesh, Transform3D], …] → 单表面(静态部件降节点数)。
## 注意:产出的单表面不带 surface 材质,材质一律由调用方经 _mi 的 material_override 提供
## (与 merge_static 按材质分组、保留 surface 材质的语义不同)。
static func merge(parts: Array) -> ArrayMesh:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var any_col := false
	for part in parts:
		var src: Array = part[0].surface_get_arrays(0)
		var xf: Transform3D = part[1]
		var base: int = pos.size()
		var sp: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
		var sn: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
		var su: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
		var si: PackedInt32Array = src[Mesh.ARRAY_INDEX]
		# 未使用的通道返回 null(并非空数组),必须先取 Variant 再判类型
		var raw_col = src[Mesh.ARRAY_COLOR] if src.size() > Mesh.ARRAY_COLOR else null
		var has_col: bool = raw_col is PackedColorArray and (raw_col as PackedColorArray).size() == sp.size()
		if has_col:
			any_col = true
		for i in sp.size():
			pos.append(xf * sp[i])
			nrm.append((xf.basis * sn[i]).normalized())
			uv.append(su[i])
			col.append((raw_col as PackedColorArray)[i] if has_col else Color.WHITE)
		for i in si.size():
			idx.append(base + si[i])
	return _mesh(pos, nrm, uv, idx, col if any_col else PackedColorArray())

## 平面四边形(朝 +Z,可配合节点旋转朝向)
static func flat_quad(w: float, h: float) -> ArrayMesh:
	var hw := w * 0.5
	var hh := h * 0.5
	var pos := PackedVector3Array([Vector3(-hw, -hh, 0), Vector3(hw, -hh, 0), Vector3(hw, hh, 0), Vector3(-hw, hh, 0)])
	var nrm := PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var uv := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	var idx := PackedInt32Array([0, 2, 1, 0, 3, 2])
	return _mesh(pos, nrm, uv, idx)

# ---------- 整体组装(props.human_figure 契约) ----------

static func build(m, cfg := {}) -> Dictionary:
	var mats := _materials(m, cfg)
	var s: float = cfg.get("scale", 1.0)
	var pose: String = cfg.get("pose", "stand")
	var sitting: bool = pose == "sit" or pose == "slump"
	var legless: bool = cfg.get("legless", false)
	var robe: bool = cfg.get("robe", false)
	var skirt: bool = cfg.get("skirt", false)
	var root := Node3D.new()
	var hip_y: float = (0.47 if sitting else 0.92) * s
	var legs := {}
	# ---- 下半身 ----
	if not legless and not robe and not skirt:
		legs = _legs(root, mats, s, sitting)
	elif robe and not sitting:
		_robe_stand(root, mats, s)
		legs = _legs(root, mats, s, false)
	elif robe and sitting:
		_robe_sit(root, mats, s)
	elif skirt:
		_skirt(root, mats, s)
	if legless:
		_pelvis(root, mats, s)
	elif not legs.is_empty():
		_hips(root, mats, s, sitting)
	# ---- 上半身(髋枢轴:驼背/瘫坐前倾)----
	var upper := Node3D.new()
	upper.position = Vector3(0, hip_y, 0)
	root.add_child(upper)
	upper.rotation.x = -float(cfg.get("hunch", 0.0)) * 0.42
	if pose == "slump":
		upper.rotation.x = -0.52
	_torso(upper, mats, s)
	if cfg.get("uniform", false):
		_uniform_detail(upper, mats, s)
	# ---- 头(颈顶枢轴;五官朝 -Z)----
	var head := Node3D.new()
	head.position = Vector3(0, 0.60 * s, 0)
	upper.add_child(head)
	if pose == "slump":
		head.rotation.x = -0.5
		head.rotation.z = 0.15
	_head(head, mats, cfg, s)
	# ---- 手臂(肩枢轴→上臂→肘枢轴→前臂→手)----
	var arms := {}
	for side: Array in [["l", -1.0], ["r", 1.0]]:
		var sgn: float = side[1]
		var arm := Node3D.new()
		arm.position = Vector3(sgn * 0.215 * s, 0.50 * s, 0.0)
		arm.rotation.z = sgn * 0.1
		arm.rotation.x = 0.55 if sitting else 0.06
		if pose == "slump":
			arm.rotation.x = 0.9
		upper.add_child(arm)
		_mi(arm, lathe([
			[0.04 * s, -0.31 * s], [0.043 * s, -0.24 * s], [0.05 * s, -0.13 * s],
			[0.062 * s, -0.04 * s], [0.075 * s, 0.0],
		], 12, {"caps": true}), mats["top"], Vector3.ZERO)
		var fore := Node3D.new()
		fore.position = Vector3(0, -0.31 * s, 0)
		fore.rotation.x = 1.3 if pose == "sit" else (0.18 if pose == "stand" else 0.1)
		arm.add_child(fore)
		_mi(fore, lathe([
			[0.029 * s, -0.28 * s], [0.032 * s, -0.20 * s], [0.038 * s, -0.10 * s],
			[0.045 * s, -0.03 * s], [0.048 * s, 0.0],
		], 12, {"caps": true}), mats["top"], Vector3.ZERO)
		var hand := _mi(fore, _hand_mesh(mats, s, sgn), mats["skin"], Vector3.ZERO)
		arms[side[0]] = {"arm": arm, "fore": fore, "hand": hand}
	# ---- 服装附加 ----
	if cfg.get("apron", false):
		_apron(root, mats, s)
	if cfg.get("polo", false):
		_polo(upper, arms, mats, s)
	if cfg.get("no_shadow", false) or cfg.get("silhouette", false):
		for pm: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return {
		"root": root, "head": head,
		"arm_l": arms["l"]["arm"], "arm_r": arms["r"]["arm"],
		"fore_l": arms["l"]["fore"], "fore_r": arms["r"]["fore"],
		"hand_l": arms["l"]["hand"], "hand_r": arms["r"]["hand"],
		# ---- 新增(步态驱动用;旧键与语义未变)----
		# upper 是躯干枢轴(驼背/瘫坐前倾就挂在这里),此前从未暴露,导致楼层只能去动 root。
		"upper": upper,
		"hip_l": legs.get("hip_l"), "hip_r": legs.get("hip_r"),
		"knee_l": legs.get("knee_l"), "knee_r": legs.get("knee_r"),
		"ankle_l": legs.get("ankle_l"), "ankle_r": legs.get("ankle_r"),
		# robe 坐姿 / skirt / legless 不建腿:对应枢轴为 null,驱动需自行守卫。
		"legged": not legs.is_empty(),
		"rig": {"scale": s, "pose": pose, "stride": 0.62 * s, "heel": Vector3(0, 0.02 * s, 0.075 * s)},
	}

# ---------- 材质 ----------

static func _materials(m, cfg: Dictionary) -> Dictionary:
	var plastic: bool = cfg.get("plastic", false)
	var out := {}
	if cfg.get("silhouette", false):
		var a: float = cfg.get("sil_alpha", 0.88)
		var sm: StandardMaterial3D = m.pmat({"unshaded": true, "transparent": true, "roughness": 1.0,
			"no_cache": true})   # 随后写入带 alpha 的剪影色,各实例不同
		sm.albedo_color = Color(0.02, 0.02, 0.04, a)
		for k in ["top", "bottom", "skin", "hair", "shoe", "sole", "dark", "eye", "iris"]:
			out[k] = sm
		return out
	var cc: float = 0.5 if plastic else 0.0
	var cc_r: float = 0.3
	# 怨灵半透明:alpha 烘进 albedo 并传 transparent(材质按签名缓存,事后改色会污染他人)
	var al: float = clampf(float(cfg.get("alpha", 1.0)), 0.05, 1.0)
	var trans: bool = al < 0.999
	# 面料槽:外部 CC0 扫描优先,缺失(如删掉 textures/)自动回退程序化 cloth
	var fab: String = String(cfg.get("fabric", "cloth"))
	if not m.T.has(fab):
		fab = "cloth"
	var cloth: Texture2D = null if plastic else m.T.tex.get(fab)
	var cloth_n: Texture2D = null if plastic else m.T.tex.get("cloth_n")
	var tile_c := Vector3.ONE / _fabric_tile(fab)
	var tile_s := Vector3.ONE / SKIN_TILE_M
	var tex_args := func(hex: String, rough: float) -> Dictionary:
		var col := Color.html(hex)
		col.a = al
		return {"color": col, "tex": cloth, "roughness": rough,
			"normal": cloth_n, "normal_scale": 0.55, "uv1": tile_c,
			"clearcoat": cc, "cc_rough": cc_r, "double_sided": true, "transparent": trans}
	out["top"] = m.pmat(tex_args.call(cfg.get("top_hex", "3a4652"), 0.45 if plastic else 0.92))
	out["bottom"] = m.pmat(tex_args.call(cfg.get("bottom_hex", "2a3240"), 0.5 if plastic else 0.9))
	var skin_col := Color.html(cfg.get("skin_hex", "b09a80"))
	skin_col.a = al
	out["skin"] = m.pmat({"color": skin_col, "tex": m.T.tex.get("skin"),
		"normal": m.T.tex.get("skin_n"), "normal_scale": 0.5, "uv1": tile_s,
		"roughness": 0.35 if plastic else 0.82, "clearcoat": cc, "cc_rough": cc_r,
		"transparent": trans, "subsurf": 0.0 if plastic else 0.38, "subsurf_skin": not plastic})
	var hair_col := Color.html(cfg.get("hair_hex", "2c2620"))
	hair_col.a = al
	out["hair"] = m.pmat({"color": hair_col, "roughness": 0.95, "transparent": trans})
	var shoe_col := Color.html(cfg.get("shoe_hex", "1e1a16"))
	shoe_col.a = al
	# 皮鞋用皮革扫描(缺失回退纯色):鞋面是全身少数非布料表面,布料质感会立刻穿帮
	var leather: Texture2D = m.T.tex.get("leather_brown") if m.T.has("leather_brown") else null
	out["shoe"] = m.pmat({"color": shoe_col, "roughness": 0.85, "transparent": trans,
		"tex": leather, "normal": m.T.tex.get("cloth_n"), "normal_scale": 0.4,
		"uv1": Vector3.ONE / _fabric_tile("leather_brown")})
	out["sole"] = m.pmat({"color": Color.html(cfg.get("shoe_hex", "1e1a16")).darkened(0.4), "roughness": 0.9})
	out["dark"] = m.pmat({"color": Color.html("14100e"), "roughness": 0.9})
	out["eye"] = m.pmat({"color": Color.html("ded6c4"), "roughness": 0.3 if plastic else 0.55})
	out["iris"] = m.pmat({"color": Color.html("1c1814"), "roughness": 0.4})
	out["blank"] = m.pmat({"color": Color.html("e8e2d4"), "roughness": 0.9})
	if cfg.has("cap_hex"):
		out["cap"] = m.pmat({"color": Color.html(cfg["cap_hex"]), "roughness": 0.8})
	if cfg.get("apron", false):
		out["apron"] = m.pmat({"color": Color.html("ded8c6"), "tex": m.T.tex.get("cloth"),
			"normal": m.T.tex.get("cloth_n"), "normal_scale": 0.45, "uv1": tile_c,
			"roughness": 0.9, "double_sided": true})
	return out

# ---------- 部件 ----------

## 站/坐姿双腿(渐变锥削四肢 + 雕刻脚型),建成 髋→膝→踝 枢轴链供步态驱动。
## 零旋转时各网格的世界变换与「直接挂 root」的旧写法逐位相同(链上每级局部位置
## 由旧的世界坐标反解得到),因此本函数可单独作为一次纯结构改造落地。
## 返回 {"hip_l","hip_r","knee_l","knee_r","ankle_l","ankle_r"};踝同时充当脚锚点。
static func _legs(root: Node3D, mats: Dictionary, s: float, sitting: bool) -> Dictionary:
	var out := {}
	for side: Array in [["l", -1.0], ["r", 1.0]]:
		var sgn: float = side[1]
		var px: float = sgn * 0.09 * s
		var hip := Node3D.new()
		var knee := Node3D.new()
		var ankle := Node3D.new()
		root.add_child(hip)
		hip.add_child(knee)
		knee.add_child(ankle)
		if sitting:
			# 大腿 90° 前伸烘进网格自身,枢轴静止时保持单位旋转(驱动可直接叠加摆动)
			hip.position = Vector3(px, 0.47 * s, -0.02 * s)
			_mi(hip, lathe([
				[0.056 * s, -0.44 * s], [0.064 * s, -0.30 * s], [0.072 * s, -0.15 * s], [0.078 * s, 0.0],
			], 12, {"caps": true}), mats["bottom"], Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
			knee.position = Vector3(0, -0.03 * s, -0.43 * s)
			_mi(knee, lathe([
				[0.036 * s, -0.44 * s], [0.038 * s, -0.38 * s], [0.05 * s, -0.26 * s],
				[0.06 * s, -0.12 * s], [0.056 * s, 0.0],
			], 12, {"caps": true}), mats["bottom"], Vector3.ZERO)
			ankle.position = Vector3(0, -0.44 * s, 0)
			_foot(ankle, mats, s, Vector3(0, 0.03 * s, -0.05 * s))
		else:
			hip.position = Vector3(px, 0.91 * s, 0)
			_mi(hip, lathe([
				[0.058 * s, -0.45 * s], [0.068 * s, -0.30 * s], [0.075 * s, -0.15 * s], [0.078 * s, 0.0],
			], 12, {"caps": true}), mats["bottom"], Vector3.ZERO)
			knee.position = Vector3(0, -0.45 * s, 0)
			_mi(knee, lathe([
				[0.035 * s, -0.45 * s], [0.037 * s, -0.38 * s], [0.048 * s, -0.24 * s],
				[0.055 * s, -0.10 * s], [0.057 * s, 0.0],
			], 12, {"caps": true}), mats["bottom"], Vector3.ZERO)
			ankle.position = Vector3(0, -0.45 * s, 0)
			_foot(ankle, mats, s, Vector3(0, 0.02 * s, -0.045 * s))
		out["hip_" + String(side[0])] = hip
		out["knee_" + String(side[0])] = knee
		out["ankle_" + String(side[0])] = ankle
	return out

## 鞋:鞋面(踝部收窄/前掌宽/脚尖微翘)+ 鞋底 + 鞋跟
static func _foot(root: Node3D, mats: Dictionary, s: float, pos: Vector3) -> void:
	var rr := 0.052 * s   # 鞋型球半径:位移量必须按它取比例(dir 是单位向量)
	var disp := func(dir: Vector3, _u: float, _v: float) -> Vector3:
		var off := Vector3.ZERO
		# 脚踝处收窄隆起(后上方):按半径比例收 45%,不能写成绝对量否则截面翻面
		var ankle := smoothstep(0.25, 0.65, dir.z) * smoothstep(0.15, 0.55, dir.y)
		off.x -= dir.x * ankle * 0.45 * rr
		off.y += 0.012 * s * ankle
		# 脚尖微翘
		off.y += 0.01 * s * smoothstep(0.55, 0.9, -dir.z)
		return off
	var body := _mi(root, sculpt_sphere(0.052 * s, 12, 10, disp, Vector2(-1, 1), 1.9), mats["shoe"], pos)
	body.scale = Vector3(0.92, 0.62, 1.0)
	# 鞋底:深色薄椭圆盘
	var sole := _mi(root, lathe([
		[0.001 * s, -0.004 * s], [0.05 * s, -0.004 * s], [0.052 * s, 0.0], [0.05 * s, 0.004 * s], [0.001 * s, 0.004 * s],
	], 12), mats["sole"], pos + Vector3(0, 0.004 * s, -0.01 * s), Vector3.ZERO, false)
	sole.scale = Vector3(0.94, 1.0, 1.8)
	# 鞋跟:后侧小块
	_mi(root, lathe([
		[0.001 * s, 0.0], [0.026 * s, 0.0], [0.028 * s, 0.014 * s], [0.001 * s, 0.014 * s],
	], 10), mats["sole"], pos + Vector3(0, 0.006 * s, 0.075 * s), Vector3.ZERO, false)

## 躯干(旋转成型剖面 + 三角肌)+ 颈 + 锁骨
static func _torso(upper: Node3D, mats: Dictionary, s: float) -> void:
	_mi(upper, lathe([
		[0.148 * s, 0.005 * s], [0.15 * s, 0.09 * s], [0.132 * s, 0.19 * s], [0.116 * s, 0.27 * s],
		[0.128 * s, 0.35 * s], [0.152 * s, 0.45 * s], [0.168 * s, 0.51 * s],
		[0.128 * s, 0.565 * s], [0.078 * s, 0.615 * s],
	], 16, {"z_scale": 0.74}), mats["top"], Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		var del := _mi(upper, sculpt_sphere(0.082 * s, 12, 8), mats["top"], Vector3(sx * 0.183 * s, 0.495 * s, 0))
		del.scale = Vector3(1.0, 0.88, 0.92)
		# 锁骨:自颈根向肩的细弯管(贴上胸表面)
		_mi(upper, tube([
			Vector3(sx * 0.05 * s, 0.585 * s, -0.055 * s),
			Vector3(sx * 0.10 * s, 0.545 * s, -0.048 * s),
			Vector3(sx * 0.145 * s, 0.515 * s, -0.032 * s),
		], [0.005 * s, 0.006 * s, 0.0045 * s], 8), mats["skin"], Vector3.ZERO, Vector3.ZERO, false)
	# 颈:起点下探进肩窝(旧写法从 0.545 起,肩加宽后仍显出「长脖子」)
	_mi(upper, lathe([[0.054 * s, 0.0], [0.05 * s, 0.055 * s], [0.048 * s, 0.115 * s]], 12),
		mats["skin"], Vector3(0, 0.505 * s, 0))

## 骨盆体量:接住躯干底缘与两条大腿(缺它则「板子下插两根棍」)
static func _hips(root: Node3D, mats: Dictionary, s: float, sitting: bool) -> void:
	# 坐姿髋枢轴在 0.47(站姿 0.92)→ 整体下降 0.45 并略前移(坐时胯部前送)
	var dy: float = -0.45 * s if sitting else 0.0
	var dz: float = -0.06 * s if sitting else 0.0
	_mi(root, lathe([
		[0.152 * s, 0.70 * s], [0.168 * s, 0.80 * s], [0.172 * s, 0.90 * s], [0.158 * s, 0.99 * s],
	], 16, {"z_scale": 0.78}), mats["bottom"], Vector3(0, dy, dz))

## 无腿模式:骨盆段(教学模型挂底座)
static func _pelvis(root: Node3D, mats: Dictionary, s: float) -> void:
	_mi(root, lathe([
		[0.152 * s, 0.0], [0.14 * s, 0.07 * s], [0.118 * s, 0.13 * s], [0.1 * s, 0.16 * s],
	], 14, {"z_scale": 0.75, "caps": true}), mats["bottom"], Vector3(0, 0.005 * s, 0))

## 头部:雕刻头骨(下颌锥收/眉弓/颧骨/下巴/鼻梁/后脑)+ 五官 + 发型/帽
static func _head(head: Node3D, mats: Dictionary, cfg: Dictionary, s: float) -> void:
	var R := 0.115 * s   # 头骨基准半径(位移统一按半径比例)
	var disp := func(dir: Vector3, _u: float, _v: float) -> Vector3:
		var off := Vector3.ZERO
		# 下颌锥收(下半脸向下巴方向渐窄;按半径比例收 30%)
		var jaw := smoothstep(0.05, 0.55, -dir.y)
		off.x -= dir.x * jaw * 0.30 * R
		# 下巴(前下微凸)
		off.z += 0.05 * R * (1.0 - smoothstep(-0.55, -0.3, dir.y)) * smoothstep(0.6, 0.88, -dir.z)
		# 太阳穴微收(按半径比例收 12%)
		off.x -= dir.x * 0.12 * R * smoothstep(0.55, 0.9, absf(dir.x)) * smoothstep(0.0, 0.35, dir.y) * smoothstep(0.75, 0.35, dir.y)
		# 颧骨(两侧前方微凸)
		off.z += 0.06 * R * smoothstep(0.4, 0.75, absf(dir.x)) \
			* (1.0 - smoothstep(0.18, 0.42, absf(dir.y - 0.06))) * smoothstep(0.15, 0.55, -dir.z)
		# 眉弓(眼上方横脊)
		off.z += 0.05 * R * smoothstep(0.45, 0.8, -dir.z) * smoothstep(0.02, 0.25, dir.y) * smoothstep(0.5, 0.2, dir.y)
		# 鼻梁基座(细窄纵脊,自眉间下行)
		off.z -= 0.055 * R * exp(-dir.x * dir.x * 42.0) \
			* smoothstep(-0.12, 0.12, dir.y) * (1.0 - smoothstep(0.28, 0.5, dir.y)) * smoothstep(0.4, 0.75, -dir.z)
		# 眼窝(眼球四周微陷)
		off.z += 0.07 * R * exp(-dir.y * dir.y * 9.0) * smoothstep(0.02, 0.1, absf(absf(dir.x) - 0.375)) * smoothstep(0.4, 0.8, -dir.z)
		# 后脑
		off.z += 0.10 * R * smoothstep(0.3, 0.8, dir.z) * smoothstep(-0.2, 0.4, dir.y)
		return off
	var skull := _mi(head, sculpt_sphere(R, 20, 16, disp, Vector2(-0.92, 1.0)), mats["skin"], Vector3(0, 0.105 * s, 0.004 * s))
	skull.scale = Vector3(0.94, 1.06, 0.98)
	var face: String = cfg.get("face", "human")
	if face == "human" or face == "blurred":
		for sx: float in [-1.0, 1.0]:
			# 眼球 + 虹膜 + 上眼睑
			_mi(head, sculpt_sphere(0.013 * s, 10, 8), mats["eye"], Vector3(sx * 0.043 * s, 0.118 * s, -0.092 * s), Vector3.ZERO, false)
			_mi(head, sculpt_sphere(0.007 * s, 8, 6), mats["iris"], Vector3(sx * 0.043 * s, 0.117 * s, -0.103 * s), Vector3.ZERO, false)
			var lid := _mi(head, sculpt_sphere(0.016 * s, 8, 6), mats["skin"], Vector3(sx * 0.043 * s, 0.128 * s, -0.1 * s), Vector3(0.5, 0, 0), false)
			lid.scale = Vector3(1.2, 0.45, 0.75)
			# 耳
			_mi(head, sculpt_sphere(0.027 * s, 8, 6), mats["skin"], Vector3(sx * 0.106 * s, 0.10 * s, 0.008 * s), Vector3(0, -sx * 0.25, 0), false)
			# 眉
			_mi(head, lathe([
				[0.109 * s, 0.0], [0.113 * s, 0.004 * s], [0.109 * s, 0.008 * s],
			], 8, {"theta_len": 0.42, "theta_off": (FRONT - 0.52) if sx < 0 else (FRONT + 0.10)}), mats["hair"], Vector3(0, 0.146 * s, 0), Vector3.ZERO, false)
		# 鼻:楔形(微倾)+ 两侧鼻翼
		_mi(head, lathe([
			[0.006 * s, 0.0], [0.012 * s, -0.008 * s], [0.013 * s, -0.018 * s],
			[0.009 * s, -0.028 * s], [0.003 * s, -0.033 * s],
		], 10), mats["skin"], Vector3(0, 0.115 * s, -0.104 * s), Vector3(-0.12, 0, 0), false)
		for sx: float in [-1.0, 1.0]:
			var wing := _mi(head, sculpt_sphere(0.009 * s, 8, 6), mats["skin"], Vector3(sx * 0.014 * s, 0.103 * s, -0.102 * s), Vector3.ZERO, false)
			wing.scale = Vector3(1.1, 0.7, 0.85)
		# 上唇(薄)/ 下唇(厚):两道弧板
		_mi(head, lathe([
			[0.012 * s, -0.0012 * s], [0.098 * s, 0.0], [0.102 * s, 0.0012 * s], [0.012 * s, 0.0024 * s],
		], 10, {"theta_len": 1.25, "theta_off": FRONT - 0.625}), mats["skin"], Vector3(0, 0.058 * s, 0), Vector3.ZERO, false)
		_mi(head, lathe([
			[0.012 * s, -0.002 * s], [0.097 * s, -0.001 * s], [0.101 * s, 0.001 * s], [0.012 * s, 0.002 * s],
		], 10, {"theta_len": 1.05, "theta_off": FRONT - 0.525}), mats["skin"], Vector3(0, 0.046 * s, 0), Vector3.ZERO, false)
	if face == "blurred":
		# 面部模糊(《美术风格指南》对管理员的要求):在五官外罩一层平滑皮肤壳,只留头型。
		# 半径必须 ≥1.06R:眼球在 x=±0.043 处凸到约 -0.105,而 1.035R 的壳在该纬度只到
		# 约 -0.0935(比眼睛浅 11 mm),遮不住;y_range 收到 -0.95 让壳覆盖到下颌。
		var veil := _mi(head, sculpt_sphere(R * 1.06, 16, 12, Callable(), Vector2(-0.95, 1.0)),
			mats["skin"], Vector3(0, 0.105 * s, 0.004 * s), Vector3.ZERO, false)
		veil.scale = Vector3(0.94, 1.06, 0.98)
	elif face == "hollow":
		for sx: float in [-1.0, 1.0]:
			_mi(head, sculpt_sphere(0.024 * s, 10, 8), mats["dark"], Vector3(sx * 0.043 * s, 0.115 * s, -0.09 * s), Vector3.ZERO, false)
		var mo := _mi(head, sculpt_sphere(0.032 * s, 10, 8), mats["dark"], Vector3(0, 0.05 * s, -0.096 * s), Vector3.ZERO, false)
		mo.scale = Vector3(1.0, 0.8, 0.5)
	elif face == "blank":
		var disc := lathe([
			[0.001 * s, -0.006 * s], [0.106 * s, -0.006 * s], [0.106 * s, 0.006 * s], [0.001 * s, 0.006 * s],
		], 18, {"caps": false})
		_mi(head, disc, mats["blank"], Vector3(0, 0.105 * s, -0.116 * s), Vector3(-PI / 2.0, 0, 0), false)
	# ---- 发型 / 帽 ----
	if mats.has("cap"):
		var crown := _mi(head, sculpt_sphere(0.12 * s, 14, 10, Callable(), Vector2(0.25, 1.0)), mats["cap"], Vector3(0, 0.125 * s, 0.006 * s))
		crown.scale = Vector3(1.02, 0.95, 1.02)
		# 帽檐:前半水平弧板(贴额前伸出)
		var brim := lathe([
			[0.03 * s, -0.004 * s], [0.1 * s, -0.004 * s], [0.1 * s, 0.004 * s], [0.03 * s, 0.004 * s],
		], 12, {"theta_len": 2.4, "theta_off": FRONT - 1.2})
		_mi(head, brim, mats["cap"], Vector3(0, 0.19 * s, 0), Vector3.ZERO)
	elif cfg.get("hair", "short") != "bald":
		# 与颅骨同基准缩放(再外扩 2%)并上移裁切,否则发壳像扣碗压在额头上
		var scalp := _mi(head, sculpt_sphere(0.121 * s, 16, 12, Callable(), Vector2(0.22, 1.0)),
			mats["hair"], Vector3(0, 0.112 * s, 0.014 * s))
		scalp.scale = Vector3(0.94 * 1.02, 1.06 * 1.02, 0.98 * 1.03)
		for sx: float in [-1.0, 1.0]:
			# 侧发:鬓角到耳后,打破光滑半球轮廓
			var sb := _mi(head, sculpt_sphere(0.03 * s, 8, 6), mats["hair"],
				Vector3(sx * 0.092 * s, 0.088 * s, 0.012 * s), Vector3.ZERO, false)
			sb.scale = Vector3(0.34, 1.05, 0.62)
		# 后脑发量
		var nape := _mi(head, sculpt_sphere(0.072 * s, 10, 8), mats["hair"], Vector3(0, 0.082 * s, 0.072 * s), Vector3.ZERO, false)
		nape.scale = Vector3(1.18, 0.92, 0.62)
		if cfg.get("hair", "short") == "bun":
			var bun := _mi(head, sculpt_sphere(0.052 * s, 10, 8), mats["hair"], Vector3(0, 0.19 * s, 0.075 * s), Vector3.ZERO, false)
			bun.scale = Vector3(1.0, 0.9, 1.0)

## 指节链:沿 -Y 逐节屈曲的锥削管;rots 为各节绝对 Euler,lengths/radii 供节数
static func _finger_parts(base: Vector3, rots: Array, lengths: Array, radii: Array, s: float) -> Array:
	var parts: Array = []
	var pos := base
	for i in lengths.size():
		var L: float = lengths[i] * s
		var r_base: float = radii[mini(i, radii.size() - 1)] * s
		var r_tip: float = radii[mini(i + 1, radii.size() - 1)] * s
		var rot: Vector3 = rots[mini(i, rots.size() - 1)]
		parts.append([lathe([
			[r_tip * 0.85, -L], [r_tip, -L * 0.55], [r_base * 0.98, -L * 0.06], [r_base, 0.0],
		], 8, {"caps": true}), _xf(pos, rot)])
		pos += _xf(Vector3.ZERO, rot).basis * Vector3(0, -L, 0)
	return parts

## 手:掌(压扁椭球)+ 四指三节链 + 拇指两节,合并为单网格
static func _hand_mesh(mats: Dictionary, s: float, sgn: float) -> ArrayMesh:
	var parts: Array = []
	# 掌
	parts.append([sculpt_sphere(0.05 * s, 10, 8, Callable(), Vector2(-1, 1), 0.55),
		_xf(Vector3(0, -0.31 * s, 0), Vector3.ZERO, Vector3(0.82, 1.15, 1.0))])
	# 四指:三节链(近节→中节→远节,越远端越屈)
	var fl: Array = [0.062, 0.068, 0.062, 0.05]
	for i in 4:
		var fx: float = (-0.024 + i * 0.016) * s
		var tot: float = fl[i]
		var r0: float = 0.14 + i * 0.02
		parts.append_array(_finger_parts(
			Vector3(fx, -0.352 * s, 0.002 * s),
			[Vector3(r0, 0, 0), Vector3(r0 + 0.2, 0, 0), Vector3(r0 + 0.48, 0, 0)],
			[tot * 0.44, tot * 0.33, tot * 0.23],
			[0.0115, 0.0098, 0.0082, 0.0074], s))
	# 拇指:两节链(斜向掌侧,对掌位)
	parts.append_array(_finger_parts(
		Vector3(sgn * 0.036 * s, -0.3 * s, -0.012 * s),
		[Vector3(0.3, 0, -sgn * 0.75), Vector3(0.62, 0, -sgn * 0.75)],
		[0.03, 0.024], [0.0125, 0.0105, 0.0088], s))
	return merge(parts)

# ---------- 服装 ----------

## 站姿长衫:波浪下摆 + 立领 + 交领斜襟 + 垂坠褶
static func _robe_stand(root: Node3D, mats: Dictionary, s: float) -> void:
	_mi(root, lathe([
		[0.268 * s, 0.025 * s], [0.255 * s, 0.10 * s], [0.232 * s, 0.28 * s],
		[0.21 * s, 0.5 * s], [0.196 * s, 0.72 * s], [0.19 * s, 0.90 * s],
	], 16, {"z_scale": 0.92, "wave_amp": 0.02 * s, "wave_freq": 7}), mats["top"], Vector3.ZERO)
	_mi(root, lathe([
		[0.145 * s, 0.80 * s], [0.15 * s, 0.86 * s], [0.158 * s, 0.90 * s],
	], 14, {"z_scale": 0.9}), mats["top"], Vector3.ZERO)
	_mi(root, lathe([
		[0.163 * s, 0.50 * s], [0.166 * s, 0.62 * s], [0.162 * s, 0.74 * s], [0.155 * s, 0.84 * s],
	], 10, {"theta_len": 2.4, "theta_off": FRONT - 1.55, "z_scale": 0.92}), mats["top"], Vector3.ZERO)
	# 垂坠褶:袍面纵向细脊
	for i in 5:
		var th := FRONT + (i - 2.0) * 0.5
		var pts := []
		for p: Array in [[0.88, 0.193], [0.55, 0.213], [0.18, 0.249]]:
			pts.append(Vector3(cos(th) * (p[1] + 0.003) * s, p[0] * s, sin(th) * (p[1] + 0.003) * s * 0.92))
		_mi(root, tube(pts, [0.005 * s, 0.006 * s, 0.004 * s], 8), mats["top"], Vector3.ZERO, Vector3.ZERO, false)

## 坐姿长衫:座垫 + 前襟垂片(波浪沿)
static func _robe_sit(root: Node3D, mats: Dictionary, s: float) -> void:
	var seat := lathe([
		[0.001 * s, -0.05 * s], [0.21 * s, -0.05 * s], [0.21 * s, 0.05 * s], [0.001 * s, 0.05 * s],
	], 14)
	_mi(root, seat, mats["top"], Vector3(0, 0.45 * s, -0.21 * s))
	_mi(root, lathe([
		[0.225 * s, 0.05 * s], [0.215 * s, 0.12 * s], [0.19 * s, 0.3 * s], [0.16 * s, 0.48 * s],
	], 12, {"theta_len": 2.6, "theta_off": FRONT - 1.3, "wave_amp": 0.012 * s, "wave_freq": 5}), mats["top"], Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		_foot(root, mats, s, Vector3(sx * 0.09 * s, 0.03 * s, -0.5 * s))

## 锥裙(波浪沿)+ 腰带 + 垂坠褶
static func _skirt(root: Node3D, mats: Dictionary, s: float) -> void:
	_mi(root, lathe([
		[0.24 * s, 0.03 * s], [0.22 * s, 0.22 * s], [0.192 * s, 0.44 * s],
		[0.172 * s, 0.66 * s], [0.158 * s, 0.86 * s],
	], 16, {"z_scale": 0.95, "wave_amp": 0.016 * s, "wave_freq": 8}), mats["bottom"], Vector3.ZERO)
	_mi(root, lathe([
		[0.156 * s, 0.84 * s], [0.162 * s, 0.90 * s],
	], 14, {"z_scale": 0.95}), mats["bottom"], Vector3.ZERO)
	# 垂坠褶:裙面纵向细脊
	for i in 5:
		var th := FRONT + (i - 2.0) * 0.55
		var pts := []
		for p: Array in [[0.82, 0.162], [0.5, 0.21], [0.12, 0.233]]:
			pts.append(Vector3(cos(th) * (p[1] + 0.003) * s, p[0] * s, sin(th) * (p[1] + 0.003) * s * 0.95))
		_mi(root, tube(pts, [0.004 * s, 0.005 * s, 0.004 * s], 8), mats["bottom"], Vector3.ZERO, Vector3.ZERO, false)

## 苏梅围裙:前片(弧面)+ 腰系带
static func _apron(root: Node3D, mats: Dictionary, s: float) -> void:
	_mi(root, lathe([
		[0.235 * s, 0.30 * s], [0.245 * s, 0.55 * s], [0.238 * s, 0.80 * s],
	], 12, {"theta_len": 1.9, "theta_off": FRONT - 0.95, "z_scale": 0.95}), mats["apron"], Vector3.ZERO)
	_mi(root, lathe([
		[0.242 * s, 0.80 * s], [0.248 * s, 0.84 * s],
	], 14, {"z_scale": 0.95}), mats["apron"], Vector3.ZERO)

## 网管服:polo 领座 + 短袖筒(随上臂枢轴)
static func _polo(upper: Node3D, arms: Dictionary, mats: Dictionary, s: float) -> void:
	_mi(upper, lathe([
		[0.062 * s, 0.56 * s], [0.072 * s, 0.60 * s], [0.066 * s, 0.64 * s],
	], 12), mats["top"], Vector3.ZERO)
	for key in ["l", "r"]:
		_mi(arms[key]["arm"], lathe([
			[0.052 * s, -0.15 * s], [0.058 * s, -0.09 * s], [0.062 * s, -0.02 * s],
		], 12, {"caps": true}), mats["top"], Vector3.ZERO)

## 保安服细节:前襟扣列 + 肩章 + 胸牌
static func _uniform_detail(upper: Node3D, mats: Dictionary, s: float) -> void:
	var btn := lathe([
		[0.001 * s, -0.003 * s], [0.008 * s, -0.003 * s], [0.008 * s, 0.003 * s], [0.001 * s, 0.003 * s],
	], 8)
	for p: Array in [[0.16, 0.112], [0.29, 0.096], [0.42, 0.106]]:
		_mi(upper, btn, mats["dark"], Vector3(0, p[0] * s, -p[1] * s), Vector3(-PI / 2.0, 0, 0), false)
	for sx: float in [-1.0, 1.0]:
		var ep := _mi(upper, sculpt_sphere(0.05 * s, 8, 6), mats["dark"], Vector3(sx * 0.155 * s, 0.545 * s, 0))
		ep.scale = Vector3(1.3, 0.16, 0.5)
	_mi(upper, lathe([
		[0.132 * s, 0.30 * s], [0.136 * s, 0.38 * s], [0.13 * s, 0.40 * s],
	], 8, {"theta_len": 0.5, "theta_off": FRONT + 0.25, "z_scale": 0.74}), mats["eye"], Vector3.ZERO, Vector3.ZERO, false)

# ---------- 特殊实体网格 ----------

## B2"母亲"浮现脸:浮雕式半张脸面具(下颌锥收/鼻梁/眼窝/张口均为位移),供肉壁表面挂载
static func mini_face(r: float) -> ArrayMesh:
	var disp := func(dir: Vector3, _u: float, _v: float) -> Vector3:
		var off := Vector3.ZERO
		# 下颌锥收(按半径比例)
		var jaw := smoothstep(0.05, 0.55, -dir.y)
		off.x -= dir.x * jaw * 0.32 * r
		off.z -= r * 0.16 * smoothstep(0.25, 0.7, -dir.z) * smoothstep(0.1, 0.5, -dir.y)
		# 鼻梁:中央纵脊微凸
		off.z -= r * 0.13 * exp(-dir.x * dir.x * 55.0) \
			* smoothstep(-0.15, 0.1, dir.y) * (1.0 - smoothstep(0.32, 0.55, dir.y)) * smoothstep(0.45, 0.75, -dir.z)
		# 眼窝凹陷(两只)
		for sx: float in [-1.0, 1.0]:
			var dx := dir.x - sx * 0.38
			var dy := dir.y - 0.12
			var sock := exp(-(dx * dx + dy * dy) * 26.0) * smoothstep(0.3, 0.75, -dir.z)
			off.z += r * 0.34 * sock
		# 张口凹陷
		var mx := dir.x
		var my := dir.y + 0.42
		var mo := exp(-(mx * mx + my * my) * 30.0) * smoothstep(0.25, 0.7, -dir.z)
		off.z += r * 0.3 * mo
		return off
	return sculpt_sphere(r, 16, 12, disp, Vector2(-0.85, 1.0), 0.95)

## 7F 纸人剪影:袖身分离 + 手型指口 + 锯齿袍摆的单面薄片(居中于原点,高 1.9)
static func paper_man_mesh() -> ArrayMesh:
	var pts := PackedVector2Array([
		# 右半(自头顶顺时针):头 → 颈 → 肩袖 → 肘 → 袖口 → 手指 → 袍身 → 摆锯齿
		Vector2(0.0, 0.95), Vector2(0.10, 0.89), Vector2(0.15, 0.82), Vector2(0.16, 0.72),
		Vector2(0.12, 0.62),
		Vector2(0.17, 0.58), Vector2(0.22, 0.38), Vector2(0.25, 0.24),
		Vector2(0.26, 0.10), Vector2(0.27, 0.02),
		Vector2(0.26, -0.05), Vector2(0.29, -0.09), Vector2(0.26, -0.12), Vector2(0.23, -0.09),
		Vector2(0.21, -0.14),
		Vector2(0.22, -0.30), Vector2(0.26, -0.50), Vector2(0.30, -0.70), Vector2(0.31, -0.82),
		Vector2(0.26, -0.87), Vector2(0.22, -0.80), Vector2(0.18, -0.90), Vector2(0.13, -0.82),
		Vector2(0.08, -0.93), Vector2(0.0, -0.88),
		# 左半(镜像)
		Vector2(-0.08, -0.93), Vector2(-0.13, -0.82), Vector2(-0.18, -0.90), Vector2(-0.22, -0.80),
		Vector2(-0.26, -0.87), Vector2(-0.31, -0.82), Vector2(-0.30, -0.70),
		Vector2(-0.26, -0.50), Vector2(-0.22, -0.30),
		Vector2(-0.21, -0.14),
		Vector2(-0.23, -0.09), Vector2(-0.26, -0.12), Vector2(-0.29, -0.09), Vector2(-0.26, -0.05),
		Vector2(-0.27, 0.02), Vector2(-0.26, 0.10),
		Vector2(-0.25, 0.24), Vector2(-0.22, 0.38), Vector2(-0.17, 0.58),
		Vector2(-0.12, 0.62),
		Vector2(-0.16, 0.72), Vector2(-0.15, 0.82), Vector2(-0.10, 0.89),
	])
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		# 兜底:退化轮廓退化为矩形片
		pts = PackedVector2Array([Vector2(-0.3, -0.95), Vector2(0.3, -0.95), Vector2(0.3, 0.95), Vector2(-0.3, 0.95)])
		tri = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	for p in pts:
		pos.append(Vector3(p.x, p.y, 0.0))
		nrm.append(Vector3(0, 0, -1))
		uv.append(Vector2((p.x + 0.31) / 0.62, (p.y + 0.95) / 1.9))
	# 单面薄片(材质双面渲染)
	var idx := PackedInt32Array()
	for i in tri.size() / 3:
		var b := i * 3
		idx.append(tri[b])
		idx.append(tri[b + 1])
		idx.append(tri[b + 2])
	return _mesh(pos, nrm, uv, idx)

# ---------- 第一人称视图模型(手持手电)----------

## 返回 {"root": Node3D(挂相机下), "lens": StandardMaterial3D,
##        "fingers": Array[Node3D](4 个指根枢轴), "thumb": Node3D}
## fingers/thumb 供 main 在开关手电时驱动屈指(整体抬落之外)。
static func build_viewmodel(m) -> Dictionary:
	var mats := {
		"skin": m.pmat({"color": Color.html("b09a80"), "tex": m.T.tex.get("skin"),
			"normal": m.T.tex.get("skin_n"), "normal_scale": 0.45,
			"uv1": Vector3.ONE / SKIN_TILE_M, "roughness": 0.82}),
		"sleeve": m.pmat({"color": Color.html("3a4248"), "tex": m.T.tex.get("cloth"),
			"normal": m.T.tex.get("cloth_n"), "normal_scale": 0.5,
			"uv1": Vector3.ONE / CLOTH_TILE_M, "roughness": 0.92}),
		"metal": m.pmat({"color": Color.html("8a9098"), "metallic": 0.85, "roughness": 0.35}),
		"grip": m.pmat({"color": Color.html("22262a"), "roughness": 0.9}),
	}
	var root := Node3D.new()
	# ---- 手电筒(筒身沿 -Z,含锥头/透镜/尾盖)----
	_mi(root, lathe([
		[0.026, 0.02], [0.023, -0.03], [0.022, -0.10], [0.026, -0.135],
	], 14, {"caps": true}), mats["metal"], Vector3(0, 0, 0.06), Vector3.ZERO, false)
	_mi(root, lathe([
		[0.033, -0.04], [0.036, -0.02], [0.03, 0.0],
	], 14), mats["metal"], Vector3(0, 0, -0.105), Vector3.ZERO, false)
	var lens: StandardMaterial3D = m.pmat({"color": Color.html("fff4d8"), "emission": Color.html("fff2d0"), "emission_energy": 0.0, "roughness": 0.2,
		"no_cache": true})   # 开关手电时逐帧改 emission_energy_multiplier
	var lens_disc := lathe([
		[0.001, -0.002], [0.028, -0.002], [0.028, 0.002], [0.001, 0.002],
	], 12)
	_mi(root, lens_disc, lens, Vector3(0, 0, -0.147), Vector3(-PI / 2.0, 0, 0), false)
	_mi(root, lathe([[0.02, -0.014], [0.024, 0.0]], 12, {"caps": true}), mats["grip"], Vector3(0, 0, 0.075), Vector3.ZERO, false)
	# ---- 右手(握持:掌包筒身 + 两节屈指链;指与掌分建枢轴,便于开关手电时屈指)----
	var palm_only: Array = [[sculpt_sphere(0.036, 10, 8, Callable(), Vector2(-1, 1), 1.15),
		_xf(Vector3(0.008, -0.052, -0.015), Vector3.ZERO, Vector3(0.9, 1.05, 0.85))]]
	_mi(root, merge(palm_only), mats["skin"], Vector3.ZERO, Vector3.ZERO, false)
	var fingers: Array = []
	for i in 4:
		var fx: float = -0.02 + i * 0.014
		var r0: float = 1.75 - i * 0.06
		var kc := Node3D.new()          # 指根(掌指关节)枢轴:curl 直接叠加在 rotation.x 上
		kc.position = Vector3(0.008 + fx, -0.062, -0.038)
		root.add_child(kc)
		_mi(kc, merge(_finger_parts(Vector3.ZERO,
			[Vector3(r0, 0, 0), Vector3(r0 + 0.85, 0, 0)], [0.034, 0.024], [0.0078, 0.0062, 0.0055], 1.0)),
			mats["skin"], Vector3.ZERO, Vector3.ZERO, false)
		fingers.append(kc)
	var thumb := Node3D.new()
	thumb.position = Vector3(0.045, -0.05, -0.012)
	root.add_child(thumb)
	_mi(thumb, merge(_finger_parts(Vector3.ZERO,
		[Vector3(0.5, 0, -0.6), Vector3(1.0, 0, -0.6)], [0.026, 0.02], [0.0095, 0.008, 0.007], 1.0)),
		mats["skin"], Vector3.ZERO, Vector3.ZERO, false)
	# ---- 右前臂(自画面右下伸向手)----
	var arm := Node3D.new()
	arm.position = Vector3(0.075, -0.155, 0.24)
	var target := Vector3(0.012, -0.052, -0.01)
	var dir := (target - arm.position).normalized()
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.98:
		up = Vector3.RIGHT
	var z_ax := -dir
	var x_ax := up.cross(z_ax).normalized()
	var y_ax := z_ax.cross(x_ax).normalized()
	arm.basis = Basis(x_ax, y_ax, z_ax)
	root.add_child(arm)
	_mi(arm, lathe([
		[0.052, -0.30], [0.046, -0.16], [0.042, -0.06], [0.04, 0.0],
	], 12, {"caps": true}), mats["sleeve"], Vector3.ZERO, Vector3(PI / 2.0, 0, 0), false)
	return {"root": root, "lens": lens, "fingers": fingers, "thumb": thumb}

# ---------- 静态合并(A4):肢体不动的人形把子树并成单网格 ----------

## 合并结果缓存:cache_key -> ArrayMesh(材质已烘焙进 surface)。同外观的假人跨实例共享,
## 10F 的 12 个坐姿假人由 ≈23 网格实例收敛为 3 套网格 × 12 实例。
## 缓存键由调用方负责含全部外观因子,且**必须**含楼层实例 id 做材质隔离;因此每次场景重载
## 都会产生一批新键 → 用 LRU 上限治理,避免长跑(反复死亡重试)显存单调增长。
static var _merged_meshes := {}
static var _merge_order: PackedStringArray = []
static var _merge_stats := {"hits": 0, "misses": 0, "evictions": 0}
const MERGE_CACHE_MAX := 48

static func merge_cache_stats() -> Dictionary:
	return _merge_stats.duplicate()

static func _merge_cache_put(cache_key: String, am: ArrayMesh) -> void:
	if _merged_meshes.has(cache_key):
		return
	_merged_meshes[cache_key] = am
	_merge_order.append(cache_key)
	while _merge_order.size() > MERGE_CACHE_MAX:
		var oldest: String = _merge_order[0]
		_merge_order.remove_at(0)
		_merged_meshes.erase(oldest)
		_merge_stats["evictions"] = int(_merge_stats["evictions"]) + 1

## 把 figure 子树(fig_root 之下)的全部 MeshInstance 按材质分组合并为单个多 surface 实例。
## 必须在完成摆姿(arm_r / fore_l 等枢轴旋转)之后调用——合并会释放这些节点;
## 之后不要再触碰 build() 返回的骨架引用。楼层切换随 floor_root 一起释放,缓存键
## 由调用方保证含全部外观因子(配色/姿态/剪影 alpha),避免串用他人材质。
static func merge_static(fig_root: Node3D, cache_key := "") -> void:
	var mis: Array = fig_root.find_children("*", "MeshInstance3D", true, false)
	if mis.is_empty():
		return
	if cache_key != "" and _merged_meshes.has(cache_key):
		_merge_stats["hits"] = int(_merge_stats["hits"]) + 1
		for mi in mis:
			mi.free()
		_attach_merged(fig_root, _merged_meshes[cache_key])
		return
	if cache_key != "":
		_merge_stats["misses"] = int(_merge_stats["misses"]) + 1
	var groups := {}   # Material -> {pos,nrm,uv,col,idx}(保持插入序决定 surface 序)
	for mi in mis:
		var base := Transform3D.IDENTITY
		var n: Node = mi
		while n != fig_root and n is Node3D:
			base = (n as Node3D).transform * base
			n = n.get_parent()
		var mat: Material = mi.material_override
		if mat == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			mat = mi.mesh.surface_get_material(0)
		if mat == null or mi.mesh == null:
			continue
		if not groups.has(mat):
			groups[mat] = {"pos": PackedVector3Array(), "nrm": PackedVector3Array(),
				"uv": PackedVector2Array(), "col": PackedColorArray(), "ncol": 0,
				"idx": PackedInt32Array()}
		var g: Dictionary = groups[mat]
		for sfc in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(sfc)
			var si: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if si.is_empty():
				continue
			var sp: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var su: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			# 未使用的通道返回 null(并非空数组),必须先取 Variant 再判类型
			var raw_col = arr[Mesh.ARRAY_COLOR] if arr.size() > Mesh.ARRAY_COLOR else null
			var has_col: bool = raw_col is PackedColorArray and (raw_col as PackedColorArray).size() == sp.size()
			if has_col:
				g["ncol"] = int(g["ncol"]) + sp.size()
			var off: int = g["pos"].size()
			for i in sp.size():
				g["pos"].append(base * sp[i])
				g["nrm"].append((base.basis * sn[i]).normalized())
				g["uv"].append(su[i])
				# 无顶点色的部件按白填充,避免与带 AO 的部件合并时被整体压暗
				g["col"].append((raw_col as PackedColorArray)[i] if has_col else Color.WHITE)
			for i in si.size():
				g["idx"].append(off + si[i])
	var am := ArrayMesh.new()
	var k := 0
	for mat: Material in groups:
		var g: Dictionary = groups[mat]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g["pos"]
		arrays[Mesh.ARRAY_NORMAL] = g["nrm"]
		arrays[Mesh.ARRAY_TEX_UV] = g["uv"]
		arrays[Mesh.ARRAY_INDEX] = g["idx"]
		var vp: PackedVector3Array = g["pos"]
		if int(g["ncol"]) > 0 and int(g["ncol"]) == vp.size():
			arrays[Mesh.ARRAY_COLOR] = g["col"]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.surface_set_material(k, mat)
		k += 1
	for mi in mis:
		mi.free()
	if cache_key != "":
		_merge_cache_put(cache_key, am)
	_attach_merged(fig_root, am)

static func _attach_merged(fig_root: Node3D, am: ArrayMesh) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = am
	fig_root.add_child(mi)
