class_name Humanoid
extends RefCounted
## 程序化雕刻人形:全部网格由代码生成(旋转成型 lathe / 位移球体 sculpt / 路径管 tube),
## 取代原始体(胶囊+方块)拼装的人物建模。CPU 侧构建,headless 环境同样可用。
## 对外入口 build(m, cfg):cfg 键与返回字典键与旧 props.human_figure 契约完全一致;
## 新增键:apron(围裙)/ polo(网管服)/ uniform(保安服细节)/ silhouette(黑色剪影)/ sil_alpha。

const FRONT := -PI / 2.0   # lathe θ=−π/2 朝向 -Z(正面)

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

static func _mesh(pos: PackedVector3Array, nrm: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am

## 轮廓旋转成型:profile 为 [[半径, y], …](自下而上,y 递增)。
## opts: theta_len/theta_off(局部弧段,正面在 θ=−π/2)、z_scale(前后压扁)、
##       wave_amp/wave_freq(下摆波浪,自底向顶线性衰减)、caps(封底/封盖)。
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
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	pos.resize(rows * cols)
	nrm.resize(rows * cols)
	uv.resize(rows * cols)
	for r in rows:
		var pa: Array = profile[maxi(0, r - 1)]
		var pb: Array = profile[mini(rows - 1, r + 1)]
		var dr: float = float(pb[0]) - float(pa[0])
		var dy: float = float(pb[1]) - float(pa[1])
		var tl: float = maxf(0.0001, sqrt(dr * dr + dy * dy))
		var n_rad: float = dy / tl
		var n_y: float = -dr / tl
		var wf: float = wave_amp * (1.0 - float(r) / float(maxi(1, rows - 1)))
		for c in cols:
			var f: float = float(c) / float(radial_seg)
			var th: float = theta_off + f * theta_len
			var rad: float = float(profile[r][0])
			if wf != 0.0:
				rad += wf * sin(th * wave_freq)
			var cp := cos(th)
			var sp := sin(th)
			var i: int = r * cols + c
			pos[i] = Vector3(cp * rad, float(profile[r][1]), sp * rad * z_scale)
			nrm[i] = Vector3(n_rad * cp, n_y, n_rad * sp * z_scale).normalized()
			uv[i] = Vector2(f, float(r) / float(maxi(1, rows - 1)))
	for r in rows - 1:
		for c in radial_seg:
			var a: int = r * cols + c
			var b: int = a + 1
			var cc: int = a + cols
			var d: int = cc + 1
			idx.append_array(PackedInt32Array([a, d, cc, a, b, d]))
	if caps:
		# 底盖(朝 -Y)
		var cb := pos.size()
		pos.append(Vector3(0, float(profile[0][1]), 0))
		nrm.append(Vector3.DOWN)
		uv.append(Vector2(0.5, 0.0))
		for c in radial_seg:
			idx.append_array(PackedInt32Array([cb, c + 1, c]))
		# 顶盖(朝 +Y)
		var ct := pos.size()
		var lr := (rows - 1) * cols
		pos.append(Vector3(0, float(profile[rows - 1][1]), 0))
		nrm.append(Vector3.UP)
		uv.append(Vector2(0.5, 1.0))
		for c in radial_seg:
			idx.append_array(PackedInt32Array([ct, lr + c, lr + c + 1]))
	return _mesh(pos, nrm, uv, idx)

## 位移球体:y_range 为归一化 y 裁剪范围(-1 底 … 1 顶);displace(dir, u, v) -> Vector3 位移偏移。
## z_scale 前后压扁(椭球截面)。
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
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	pos.resize(rows * cols)
	nrm.resize(rows * cols)
	uv.resize(rows * cols)
	for i in rows:
		var t: float = float(i) / float(maxi(1, rows - 1))
		var alpha: float = lerpf(a_bot, a_top, t)   # 自底向顶
		var sy := cos(alpha)
		var sr := sin(alpha)
		for c in cols:
			var u: float = float(c) / float(seg)
			var th := u * TAU
			var dir := Vector3(sr * cos(th), sy, sr * sin(th))
			var p := Vector3(dir.x * r, dir.y * r, dir.z * r * z_scale)
			if displace.is_valid():
				p += displace.call(dir, u, t)
			var k: int = i * cols + c
			pos[k] = p
			nrm[k] = dir.normalized()
			uv[k] = Vector2(u, t)
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
		uv.append(Vector2(0.5, 0.0))
		for c in seg:
			idx.append_array(PackedInt32Array([pb, c + 1, c]))
	if has_pole_t:
		# 顶极点(朝 +Y)
		var pt := pos.size()
		var lr := (rows - 1) * cols
		pos.append(Vector3(0, r, 0))
		nrm.append(Vector3.UP)
		uv.append(Vector2(0.5, 1.0))
		for c in seg:
			idx.append_array(PackedInt32Array([pt, lr + c, lr + c + 1]))
	return _mesh(pos, nrm, uv, idx)

## 路径锥削管:path 为 Vector3 折线,radii 为等长半径序列(自底向顶)。
static func tube(path: Array, radii: Array, seg := 10) -> ArrayMesh:
	var n := path.size()
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	pos.resize(n * (seg + 1))
	nrm.resize(n * (seg + 1))
	uv.resize(n * (seg + 1))
	for i in n:
		var p: Vector3 = path[i]
		var t: Vector3 = (path[mini(n - 1, i + 1)] - path[maxi(0, i - 1)]).normalized()
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
			nrm[k] = dir
			uv[k] = Vector2(f, float(i) / float(maxi(1, n - 1)))
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
		cap_n = -(path[1] - path[0]).normalized()
	nrm.append(cap_n)
	uv.append(Vector2(0.5, 0.0))
	for c in seg:
		idx.append_array(PackedInt32Array([c0, c + 1, c]))
	return _mesh(pos, nrm, uv, idx)

## 合并网格:parts 为 [[ArrayMesh, Transform3D], …] → 单表面(静态部件降节点数)。
static func merge(parts: Array) -> ArrayMesh:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for part in parts:
		var src: Array = part[0].surface_get_arrays(0)
		var xf: Transform3D = part[1]
		var base: int = pos.size()
		var sp: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
		var sn: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
		var su: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
		var si: PackedInt32Array = src[Mesh.ARRAY_INDEX]
		for i in sp.size():
			pos.append(xf * sp[i])
			nrm.append((xf.basis * sn[i]).normalized())
			uv.append(su[i])
		for i in si.size():
			idx.append(base + si[i])
	return _mesh(pos, nrm, uv, idx)

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
	# ---- 下半身 ----
	if not legless and not robe and not skirt:
		_legs(root, mats, s, sitting)
	elif robe and not sitting:
		_robe_stand(root, mats, s)
		_legs(root, mats, s, false)
	elif robe and sitting:
		_robe_sit(root, mats, s)
	elif skirt:
		_skirt(root, mats, s)
	if legless:
		_pelvis(root, mats, s)
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
			[0.054 * s, 0.0], [0.05 * s, -0.06 * s], [0.046 * s, -0.16 * s],
			[0.04 * s, -0.26 * s], [0.037 * s, -0.31 * s],
		], 12, {"caps": true}), mats["top"], Vector3.ZERO)
		var fore := Node3D.new()
		fore.position = Vector3(0, -0.31 * s, 0)
		fore.rotation.x = 1.3 if pose == "sit" else (0.18 if pose == "stand" else 0.1)
		arm.add_child(fore)
		_mi(fore, lathe([
			[0.041 * s, 0.0], [0.043 * s, -0.05 * s], [0.037 * s, -0.14 * s],
			[0.031 * s, -0.22 * s], [0.029 * s, -0.28 * s],
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
	var cloth: Texture2D = null if plastic else m.T.tex.get("cloth")
	var cloth_n: Texture2D = null if plastic else m.T.tex.get("cloth_n")
	var tex_args := func(hex: String, rough: float) -> Dictionary:
		return {"color": Color.html(hex), "tex": cloth, "roughness": rough,
			"normal": cloth_n, "normal_scale": 0.55,
			"clearcoat": cc, "cc_rough": cc_r, "double_sided": true}
	out["top"] = m.pmat(tex_args.call(cfg.get("top_hex", "3a4652"), 0.45 if plastic else 0.92))
	out["bottom"] = m.pmat(tex_args.call(cfg.get("bottom_hex", "2a3240"), 0.5 if plastic else 0.9))
	out["skin"] = m.pmat({"color": Color.html(cfg.get("skin_hex", "b09a80")), "tex": m.T.tex.get("skin"),
		"normal": m.T.tex.get("skin_n"), "normal_scale": 0.5,
		"roughness": 0.35 if plastic else 0.82, "clearcoat": cc, "cc_rough": cc_r})
	out["hair"] = m.pmat({"color": Color.html(cfg.get("hair_hex", "2c2620")), "roughness": 0.95})
	out["shoe"] = m.pmat({"color": Color.html(cfg.get("shoe_hex", "1e1a16")), "roughness": 0.85})
	out["sole"] = m.pmat({"color": Color.html(cfg.get("shoe_hex", "1e1a16")).darkened(0.4), "roughness": 0.9})
	out["dark"] = m.pmat({"color": Color.html("14100e"), "roughness": 0.9})
	out["eye"] = m.pmat({"color": Color.html("ded6c4"), "roughness": 0.3 if plastic else 0.55})
	out["iris"] = m.pmat({"color": Color.html("1c1814"), "roughness": 0.4})
	out["blank"] = m.pmat({"color": Color.html("e8e2d4"), "roughness": 0.9})
	if cfg.has("cap_hex"):
		out["cap"] = m.pmat({"color": Color.html(cfg["cap_hex"]), "roughness": 0.8})
	if cfg.get("apron", false):
		out["apron"] = m.pmat({"color": Color.html("ded8c6"), "tex": m.T.tex.get("cloth"),
			"normal": m.T.tex.get("cloth_n"), "normal_scale": 0.45, "roughness": 0.9, "double_sided": true})
	return out

# ---------- 部件 ----------

## 站/坐姿双腿(渐变锥削四肢 + 雕刻脚型)
static func _legs(root: Node3D, mats: Dictionary, s: float, sitting: bool) -> void:
	for sx: float in [-1.0, 1.0]:
		var px: float = sx * 0.09 * s
		if sitting:
			# 大腿前伸(-Y 建模绕 X 旋 90°→ 指向 -Z)
			_mi(root, lathe([
				[0.056 * s, -0.44 * s], [0.064 * s, -0.30 * s], [0.072 * s, -0.15 * s], [0.078 * s, 0.0],
			], 12, {"caps": true}), mats["bottom"], Vector3(px, 0.47 * s, -0.02 * s), Vector3(PI / 2.0, 0, 0))
			_mi(root, lathe([
				[0.036 * s, -0.44 * s], [0.038 * s, -0.38 * s], [0.05 * s, -0.26 * s],
				[0.06 * s, -0.12 * s], [0.056 * s, 0.0],
			], 12, {"caps": true}), mats["bottom"], Vector3(px, 0.44 * s, -0.45 * s))
			_foot(root, mats, s, Vector3(px, 0.03 * s, -0.50 * s))
		else:
			_mi(root, lathe([
				[0.058 * s, -0.45 * s], [0.068 * s, -0.30 * s], [0.075 * s, -0.15 * s], [0.078 * s, 0.0],
			], 12, {"caps": true}), mats["bottom"], Vector3(px, 0.91 * s, 0))
			_mi(root, lathe([
				[0.035 * s, -0.45 * s], [0.037 * s, -0.38 * s], [0.048 * s, -0.24 * s],
				[0.055 * s, -0.10 * s], [0.057 * s, 0.0],
			], 12, {"caps": true}), mats["bottom"], Vector3(px, 0.46 * s, 0))
			_foot(root, mats, s, Vector3(px, 0.03 * s, -0.045 * s))

## 鞋:鞋面(踝部收窄/前掌宽/脚尖微翘)+ 鞋底 + 鞋跟
static func _foot(root: Node3D, mats: Dictionary, s: float, pos: Vector3) -> void:
	var disp := func(dir: Vector3, _u: float, _v: float) -> Vector3:
		var off := Vector3.ZERO
		# 脚踝处收窄隆起(后上方)
		var ankle := smoothstep(0.25, 0.65, dir.z) * smoothstep(0.15, 0.55, dir.y)
		off.x -= dir.x * ankle * 0.45
		off.y += 0.012 * s * ankle
		# 脚尖微翘
		off.y += 0.01 * s * smoothstep(0.55, 0.9, -dir.z)
		return off
	var body := _mi(root, sculpt_sphere(0.052 * s, 12, 10, disp, Vector2(-1, 1), 2.15), mats["shoe"], pos)
	body.scale = Vector3(0.92, 0.62, 1.0)
	# 鞋底:深色薄椭圆盘
	var sole := _mi(root, lathe([
		[0.001 * s, -0.004 * s], [0.05 * s, -0.004 * s], [0.052 * s, 0.0], [0.05 * s, 0.004 * s], [0.001 * s, 0.004 * s],
	], 12), mats["sole"], pos + Vector3(0, 0.004 * s, -0.01 * s), Vector3.ZERO, false)
	sole.scale = Vector3(0.94, 1.0, 2.05)
	# 鞋跟:后侧小块
	_mi(root, lathe([
		[0.001 * s, 0.0], [0.026 * s, 0.0], [0.028 * s, 0.014 * s], [0.001 * s, 0.014 * s],
	], 10), mats["sole"], pos + Vector3(0, 0.006 * s, 0.075 * s), Vector3.ZERO, false)

## 躯干(旋转成型剖面 + 三角肌)+ 颈 + 锁骨
static func _torso(upper: Node3D, mats: Dictionary, s: float) -> void:
	_mi(upper, lathe([
		[0.148 * s, 0.005 * s], [0.15 * s, 0.09 * s], [0.132 * s, 0.19 * s], [0.116 * s, 0.27 * s],
		[0.126 * s, 0.35 * s], [0.146 * s, 0.45 * s], [0.15 * s, 0.51 * s],
		[0.104 * s, 0.565 * s], [0.06 * s, 0.615 * s],
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
	_mi(upper, lathe([[0.046 * s, 0.0], [0.05 * s, 0.09 * s]], 12), mats["skin"], Vector3(0, 0.545 * s, 0))

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
	if face == "human":
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
		var scalp := _mi(head, sculpt_sphere(0.121 * s, 16, 12, Callable(), Vector2(0.05, 1.0)), mats["hair"], Vector3(0, 0.118 * s, 0.012 * s))
		scalp.scale = Vector3(1.0, 1.02, 1.03)
		for sx: float in [-1.0, 1.0]:
			var sb := _mi(head, sculpt_sphere(0.028 * s, 8, 6), mats["hair"], Vector3(sx * 0.098 * s, 0.085 * s, -0.01 * s), Vector3.ZERO, false)
			sb.scale = Vector3(0.35, 0.9, 0.6)
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

## 返回 {"root": Node3D(挂相机下), "lens": StandardMaterial3D}
static func build_viewmodel(m) -> Dictionary:
	var mats := {
		"skin": m.pmat({"color": Color.html("b09a80"), "tex": m.T.tex.get("skin"),
			"normal": m.T.tex.get("skin_n"), "normal_scale": 0.45, "roughness": 0.82}),
		"sleeve": m.pmat({"color": Color.html("3a4248"), "tex": m.T.tex.get("cloth"),
			"normal": m.T.tex.get("cloth_n"), "normal_scale": 0.5, "roughness": 0.92}),
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
	# ---- 右手(握持:掌包筒身 + 两节屈指链)----
	var grip_parts: Array = []
	grip_parts.append([sculpt_sphere(0.036, 10, 8, Callable(), Vector2(-1, 1), 1.15),
		_xf(Vector3(0.008, -0.052, -0.015), Vector3.ZERO, Vector3(0.9, 1.05, 0.85))])
	for i in 4:
		var fx: float = (-0.02 + i * 0.014)
		var r0: float = 1.75 - i * 0.06
		grip_parts.append_array(_finger_parts(
			Vector3(0.008 + fx, -0.062, -0.038),
			[Vector3(r0, 0, 0), Vector3(r0 + 0.85, 0, 0)],
			[0.034, 0.024], [0.0078, 0.0062, 0.0055], 1.0))
	grip_parts.append_array(_finger_parts(
		Vector3(0.045, -0.05, -0.012),
		[Vector3(0.5, 0, -0.6), Vector3(1.0, 0, -0.6)],
		[0.026, 0.02], [0.0095, 0.008, 0.007], 1.0))
	_mi(root, merge(grip_parts), mats["skin"], Vector3.ZERO, Vector3.ZERO, false)
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
	return {"root": root, "lens": lens}

# ---------- 静态合并(A4):肢体不动的人形把子树并成单网格 ----------

## 合并结果缓存:cache_key -> ArrayMesh(材质已烘焙进 surface)。同外观的假人跨实例共享,
## 10F 的 12 个坐姿假人由 ≈23 网格实例收敛为 3 套网格 × 12 实例。
static var _merged_meshes := {}

## 把 figure 子树(fig_root 之下)的全部 MeshInstance 按材质分组合并为单个多 surface 实例。
## 必须在完成摆姿(arm_r / fore_l 等枢轴旋转)之后调用——合并会释放这些节点;
## 之后不要再触碰 build() 返回的骨架引用。楼层切换随 floor_root 一起释放,缓存键
## 由调用方保证含全部外观因子(配色/姿态/剪影 alpha),避免串用他人材质。
static func merge_static(fig_root: Node3D, cache_key := "") -> void:
	var mis: Array = fig_root.find_children("*", "MeshInstance3D", true, false)
	if mis.is_empty():
		return
	if cache_key != "" and _merged_meshes.has(cache_key):
		for mi in mis:
			mi.free()
		_attach_merged(fig_root, _merged_meshes[cache_key])
		return
	var groups := {}   # Material -> {pos,nrm,uv,idx}(保持插入序决定 surface 序)
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
				"uv": PackedVector2Array(), "idx": PackedInt32Array()}
		var g: Dictionary = groups[mat]
		for sfc in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(sfc)
			var sp: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var su: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var si: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if si.is_empty():
				continue
			var off: int = g["pos"].size()
			for i in sp.size():
				g["pos"].append(base * sp[i])
				g["nrm"].append((base.basis * sn[i]).normalized())
				g["uv"].append(su[i])
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
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.surface_set_material(k, mat)
		k += 1
	for mi in mis:
		mi.free()
	if cache_key != "":
		_merged_meshes[cache_key] = am
	_attach_merged(fig_root, am)

static func _attach_merged(fig_root: Node3D, am: ArrayMesh) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = am
	fig_root.add_child(mi)
