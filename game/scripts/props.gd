class_name Props
extends RefCounted
## 场景物品参数化建模库:原始体组合(Box/Cylinder/Sphere/Torus Mesh)。
## 规约:装饰子件一律不注册碰撞(家具的碰撞足迹由楼层脚本按原占位尺寸手动登记);
## 细小件(把手/火苗/指针/按钮/香)不投影;材质在每个生成器内只创建一次并复用。

# ---------- 内部小工具 ----------

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

static func _box(w: float, h: float, d: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(w, h, d)
	return b

static func _cyl(tr: float, br: float, h: float, seg := 14) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = tr
	c.bottom_radius = br
	c.height = h
	c.radial_segments = seg
	return c

static func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s

static func _tor(ir: float, orr: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = ir
	t.outer_radius = orr
	return t

static func _root(m, x: float, z: float, ry := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(x, 0, z)
	n.rotation.y = ry
	m.floor_root.add_child(n)
	return n

# ---------- 家具 ----------

## 木桌:面板 + 四腿 + 后裙板 + 前抽屉条(带把手)
static func wood_desk(m, x: float, z: float, ry: float, w := 2.4, d := 1.0, h := 0.85, wood_hex := "4a3d2e") -> Node3D:
	var root := _root(m, x, z, ry)
	var top_mat: StandardMaterial3D = m.pmat({"color": Color.html(wood_hex), "roughness": 0.62, "clearcoat": 0.25, "cc_rough": 0.5})
	var leg_mat: StandardMaterial3D = m.pmat({"color": Color.html(wood_hex).darkened(0.25), "roughness": 0.78})
	var hw: StandardMaterial3D = m.pmat({"color": Color.html("9aa0a6"), "metallic": 0.9, "roughness": 0.3})
	_mi(root, _box(w, 0.06, d), top_mat, Vector3(0, h - 0.03, 0))
	for p: Array in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		_mi(root, _box(0.08, h - 0.06, 0.08), leg_mat, Vector3(p[0] * (w / 2.0 - 0.09), (h - 0.06) / 2.0 + 0.03, p[1] * (d / 2.0 - 0.09)))
	_mi(root, _box(w - 0.24, 0.16, 0.04), leg_mat, Vector3(0, h - 0.16, -d / 2.0 + 0.06))
	_mi(root, _box(w * 0.55, 0.15, 0.04), leg_mat, Vector3(0, h - 0.15, d / 2.0 - 0.03))
	_mi(root, _cyl(0.02, 0.02, 0.1), hw, Vector3(0, h - 0.15, d / 2.0 + 0.005), Vector3(PI / 2.0, 0, 0), false)
	return root

## 木椅:四腿 + 座板 + 靠背双柱双横条
static func chair(m, x: float, z: float, ry: float, col_hex := "40301e") -> Node3D:
	var root := _root(m, x, z, ry)
	var wood: StandardMaterial3D = m.pmat({"color": Color.html(col_hex), "roughness": 0.7})
	_mi(root, _box(0.45, 0.05, 0.45), wood, Vector3(0, 0.45, 0))
	for p: Array in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		_mi(root, _box(0.05, 0.45, 0.05), wood, Vector3(p[0] * 0.19, 0.225, p[1] * 0.19))
	for sx: float in [-0.18, 0.18]:
		_mi(root, _box(0.05, 0.52, 0.05), wood, Vector3(sx, 0.73, -0.2))
		_mi(root, _box(0.42, 0.07, 0.03), wood, Vector3(0, 0.68, -0.2))
		_mi(root, _box(0.42, 0.07, 0.03), wood, Vector3(0, 0.88, -0.2))
	return root

## 大厅长椅:两端侧板腿 + 座板 + 靠背 + 扶手
static func bench(m, x: float, z: float, ry: float, length := 3.4, col_hex := "50412f") -> Node3D:
	var root := _root(m, x, z, ry)
	var wood: StandardMaterial3D = m.pmat({"color": Color.html(col_hex), "roughness": 0.72})
	_mi(root, _box(length, 0.06, 0.55), wood, Vector3(0, 0.44, 0))
	_mi(root, _box(length, 0.42, 0.05), wood, Vector3(0, 0.71, -0.25))
	for sx: float in [-(length / 2.0 - 0.16), length / 2.0 - 0.16]:
		_mi(root, _box(0.08, 0.42, 0.5), wood, Vector3(sx, 0.21, 0))
		_mi(root, _box(0.26, 0.05, 0.55), wood, Vector3(sx * 0.92, 0.66, 0))
		_mi(root, _box(0.05, 0.2, 0.05), wood, Vector3(sx * 0.92, 0.55, 0.2))
	return root

## 候诊椅(单座):金属脚 + 座垫 + 靠背垫 + 扶手
static func waiting_chair(m, x: float, z: float, ry := 0.0) -> Node3D:
	var root := _root(m, x, z, ry)
	var frame: StandardMaterial3D = m.pmat({"color": Color.html("2c3a40"), "metallic": 0.6, "roughness": 0.5})
	var pad: StandardMaterial3D = m.pmat({"color": Color.html("39505c"), "roughness": 0.92})
	_mi(root, _box(0.5, 0.05, 0.48), frame, Vector3(0, 0.4, -0.1))
	_mi(root, _box(0.56, 0.09, 0.5), pad, Vector3(0, 0.45, -0.1))
	_mi(root, _box(0.56, 0.52, 0.09), pad, Vector3(0, 0.72, -0.32))
	for sx: float in [-0.24, 0.24]:
		_mi(root, _box(0.05, 0.4, 0.05), frame, Vector3(sx, 0.2, -0.3))
		_mi(root, _box(0.05, 0.48, 0.05), frame, Vector3(sx, 0.24, 0.18))
		_mi(root, _box(0.06, 0.05, 0.46), frame, Vector3(sx * 1.2, 0.64, -0.08))
	return root

## 货架:四立柱 + 层板 + 背斜撑
static func shelf_unit(m, x: float, z: float, ry: float, w := 1.8, h := 1.8, layers := 3, col_hex := "463826") -> Node3D:
	var root := _root(m, x, z, ry)
	var wood: StandardMaterial3D = m.pmat({"color": Color.html(col_hex), "roughness": 0.85})
	for p: Array in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		_mi(root, _box(0.06, h, 0.06), wood, Vector3(p[0] * (w / 2.0 - 0.04), h / 2.0, p[1] * 0.32))
	for i in layers:
		_mi(root, _box(w, 0.05, 0.72), wood, Vector3(0, 0.12 + float(i) * (h - 0.2) / float(layers - 1), 0))
	for sx: float in [-w / 2.0 + 0.1, w / 2.0 - 0.1]:
		_mi(root, _box(0.05, h - 0.1, 0.05), wood, Vector3(sx, h / 2.0, -0.32), Vector3(0.35 * signf(sx), 0, 0.5))
	return root

## 信箱墙:背板 + 5×4 箱门阵(一扇微开)+ 部分名牌条
static func mailbox_wall(m, x: float, z: float, ry := 0.0) -> Node3D:
	var root := _root(m, x, z, ry)
	var metal: StandardMaterial3D = m.pmat({
		"tex": m.T.tex.get("metal"), "color": Color.html("3c4038") if m.T.tex.get("metal") == null else Color.WHITE,
		"metallic": 0.45, "roughness": 0.55,
	})
	var door_mat: StandardMaterial3D = m.pmat({
		"tex": m.T.tex.get("metal"), "color": Color.html("484d44") if m.T.tex.get("metal") == null else Color.WHITE,
		"metallic": 0.4, "roughness": 0.6,
	})
	var name_mat: StandardMaterial3D = m.pmat({"color": Color.html("b8ad8e"), "roughness": 0.9})
	_mi(root, _box(4.2, 1.6, 0.1), metal, Vector3(0, 0.8, 0))
	for ci in 5:
		for ri in 4:
			var px: float = -4.2 / 2.0 + (ci + 0.5) * 0.84
			var py: float = 0.16 + (ri + 0.5) * 0.4
			var open := (ci == 3 and ri == 2)
			var rot := Vector3(0, 0.55 if open else 0.0, 0)
			var pz := 0.14 if open else 0.08
			_mi(root, _box(0.72, 0.32, 0.05), door_mat, Vector3(px + (0.16 if open else 0.0), py, pz), rot)
			if ri == 1:
				_mi(root, _box(0.3, 0.045, 0.012), name_mat, Vector3(px, py + 0.1, 0.112), Vector3.ZERO, false)
	return root

## 药柜:柜体 + 层板 + 半透明玻璃门 + 把手;返回两瓶药(供逐瓶拾取)与杂瓶
static func medicine_cabinet(m, x: float, z: float, ry: float) -> Dictionary:
	var root := _root(m, x, z, ry)
	var body: StandardMaterial3D = m.pmat({"color": Color.html("3c4a44"), "roughness": 0.8})
	var glass: StandardMaterial3D = m.pmat({"color": Color(0.62, 0.76, 0.8, 0.24), "roughness": 0.12, "metallic": 0.1, "transparent": true})
	var hw: StandardMaterial3D = m.pmat({"color": Color.html("9aa0a6"), "metallic": 0.9, "roughness": 0.3})
	_mi(root, _box(1.6, 1.8, 0.05), body, Vector3(0, 0.9, -0.2))
	for sx: float in [-0.775, 0.775]:
		_mi(root, _box(0.05, 1.8, 0.45), body, Vector3(sx, 0.9, 0))
	for sy: float in [0.025, 1.775]:
		_mi(root, _box(1.6, 0.05, 0.45), body, Vector3(0, sy, 0))
	for sy: float in [0.62, 1.2]:
		_mi(root, _box(1.5, 0.04, 0.4), body, Vector3(0, sy, 0))
	for sx: float in [-0.38, 0.38]:
		_mi(root, _box(0.72, 1.66, 0.02), glass, Vector3(sx, 0.9, 0.235))
		_mi(root, _cyl(0.018, 0.018, 0.1), hw, Vector3(sx + (0.3 if sx < 0 else -0.3), 0.9, 0.26), Vector3(PI / 2.0, 0, 0), false)
	var bottle_a := pill_bottle(m, "3a5a7c")
	bottle_a.position = Vector3(-0.35, 0.66, 0.02)
	root.add_child(bottle_a)
	var bottle_b := pill_bottle(m, "6a4632")
	bottle_b.position = Vector3(0.32, 1.24, 0.02)
	root.add_child(bottle_b)
	for p: Array in [[-0.1, 0.66], [0.12, 0.66], [-0.15, 1.24]]:
		var extra := pill_bottle(m, "8a8f96")
		extra.position = Vector3(p[0], p[1], 0.02)
		root.add_child(extra)
	return {"root": root, "bottle_a": bottle_a, "bottle_b": bottle_b}

## 消防柜:红壳 + 玻璃门 + 灭火器 + 水带卷 + 电池(柜内)
static func fire_cabinet(m, x: float, z: float, ry: float) -> Dictionary:
	var root := _root(m, x, z, ry)
	var red: StandardMaterial3D = m.pmat({"color": Color.html("7c2a24"), "roughness": 0.6, "clearcoat": 0.2, "cc_rough": 0.5})
	var glass: StandardMaterial3D = m.pmat({"color": Color(0.7, 0.78, 0.8, 0.2), "roughness": 0.1, "transparent": true})
	var chrome: StandardMaterial3D = m.pmat({"color": Color.html("9aa0a6"), "metallic": 0.9, "roughness": 0.25})
	_mi(root, _box(0.6, 0.8, 0.04), red, Vector3(0, 0.4, -0.13))
	for sx: float in [-0.275, 0.275]:
		_mi(root, _box(0.05, 0.8, 0.3), red, Vector3(sx, 0.4, 0))
	for sy: float in [0.02, 0.78]:
		_mi(root, _box(0.6, 0.05, 0.3), red, Vector3(0, sy, 0))
	_mi(root, _box(0.56, 0.7, 0.02), glass, Vector3(0, 0.4, 0.145))
	for sy: float in [0.22, 0.6]:
		_mi(root, _box(0.5, 0.03, 0.03), chrome, Vector3(0, sy, 0))
	# 灭火器
	var ext_mat: StandardMaterial3D = m.pmat({"color": Color.html("a8352c"), "roughness": 0.5, "clearcoat": 0.3, "cc_rough": 0.4})
	_mi(root, _cyl(0.05, 0.05, 0.28, 16), ext_mat, Vector3(-0.14, 0.4, 0.01))
	_mi(root, _cyl(0.018, 0.018, 0.07, 10), chrome, Vector3(-0.14, 0.575, 0.01))
	_mi(root, _box(0.07, 0.02, 0.03), chrome, Vector3(-0.14, 0.61, 0.01))
	_mi(root, _cyl(0.02, 0.02, 0.012, 10), m.pmat({"color": Color.html("e8e4d0"), "emission": Color.html("c8d8b0"), "emission_energy": 0.4}), Vector3(-0.1, 0.58, 0.01), Vector3(0, 0, PI / 2.0), false)
	_mi(root, _cyl(0.008, 0.008, 0.2, 8), m.pmat({"color": Color.html("1a1a1a"), "roughness": 0.9}), Vector3(-0.08, 0.5, 0.02), Vector3(0, 0, -0.7), false)
	# 水带卷
	_mi(root, _tor(0.05, 0.085), m.pmat({"color": Color.html("c8bfa8"), "roughness": 0.95}), Vector3(0.15, 0.45, 0.01), Vector3(PI / 2.0, 0, 0))
	var battery := battery_prop(m)
	battery.position = Vector3(0.0, 0.09, 0.02)
	root.add_child(battery)
	return {"root": root, "battery": battery}

## 门:门框(双柱+顶梁)+ 门扇 + 金属把手;glow 版加门缝暖光条
static func door_set(m, x: float, z: float, ry: float, mat: Material, glow := false, w := 1.1, h := 2.2) -> Node3D:
	var root := _root(m, x, z, ry)
	var frame: StandardMaterial3D = m.pmat({"color": Color.html("2e2620"), "roughness": 0.72})
	var hw: StandardMaterial3D = m.pmat({"color": Color.html("9aa0a6"), "metallic": 0.9, "roughness": 0.25})
	for sx: float in [-(w / 2.0 + 0.06), w / 2.0 + 0.06]:
		_mi(root, _box(0.12, h + 0.15, 0.16), frame, Vector3(sx, (h + 0.15) / 2.0, 0))
	_mi(root, _box(w + 0.34, 0.13, 0.16), frame, Vector3(0, h + 0.075, 0))
	_mi(root, _box(w, h, 0.1), mat, Vector3(0, h / 2.0, 0))
	_mi(root, _box(0.05, 0.05, 0.03), hw, Vector3(w / 2.0 - 0.14, 1.05, 0.06), Vector3.ZERO, false)
	_mi(root, _cyl(0.011, 0.011, 0.13, 10), hw, Vector3(w / 2.0 - 0.14, 1.05, 0.1), Vector3(PI / 2.0, 0, 0), false)
	if glow:
		var seam: StandardMaterial3D = m.pmat({"color": Color.html("ffb054"), "emission": Color.html("ffb054"), "emission_energy": 1.8})
		for sx: float in [-(w / 2.0 - 0.012), w / 2.0 - 0.012]:
			_mi(root, _box(0.018, h - 0.08, 0.015), seam, Vector3(sx, h / 2.0 + 0.04, 0.056), Vector3.ZERO, false)
		_mi(root, _box(w - 0.02, 0.015, 0.015), seam, Vector3(0, h - 0.012, 0.056), Vector3.ZERO, false)
	return root

## 窗:外框 + 十字棂 + 暗玻璃(夜色反光)+ 双托墩
static func window_set(m, x: float, y: float, z: float, ry: float, w := 1.0, h := 1.4) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, y, z)
	root.rotation.y = ry
	m.floor_root.add_child(root)
	var frame: StandardMaterial3D = m.pmat({"color": Color.html("2a2c30"), "metallic": 0.4, "roughness": 0.6})
	var glass: StandardMaterial3D = m.pmat({"color": Color.html("0a0f18"), "unshaded": true, "emission": Color.html("0a0f18"), "emission_energy": 1.0})
	_mi(root, _box(w, 0.07, 0.1), frame, Vector3(0, h / 2.0 - 0.035, 0))
	_mi(root, _box(w, 0.07, 0.1), frame, Vector3(0, -h / 2.0 + 0.035, 0))
	for sx: float in [-(w / 2.0 - 0.035), w / 2.0 - 0.035]:
		_mi(root, _box(0.07, h, 0.1), frame, Vector3(sx, 0, 0))
	_mi(root, _box(0.035, h - 0.12, 0.05), frame, Vector3(0, 0, 0.005))
	_mi(root, _box(w - 0.12, 0.035, 0.05), frame, Vector3(0, 0, 0.005))
	var g := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w - 0.06, h - 0.06)
	g.mesh = qm
	g.material_override = glass
	g.position = Vector3(0, 0, -0.01)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(g)
	for sx: float in [-(w / 2.0 - 0.08), w / 2.0 - 0.08]:
		_mi(root, _box(0.08, 0.06, 0.16), frame, Vector3(sx, -h / 2.0 - 0.01, 0.04))
	return root

## 中式供桌:厚面板 + 四圆腿 + 前后牙板 + 侧裙
static func altar_table(m, x: float, z: float, ry: float, w := 3.2, d := 1.1, h := 1.0) -> Node3D:
	var root := _root(m, x, z, ry)
	var lacquer: StandardMaterial3D = m.pmat({"color": Color.html("3c2c1a"), "roughness": 0.5, "clearcoat": 0.3, "cc_rough": 0.4})
	var wood: StandardMaterial3D = m.pmat({"color": Color.html("2e2114"), "roughness": 0.72})
	_mi(root, _box(w, 0.09, d), lacquer, Vector3(0, h - 0.045, 0))
	for p: Array in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		_mi(root, _cyl(0.045, 0.05, h - 0.09, 10), wood, Vector3(p[0] * (w / 2.0 - 0.2), (h - 0.09) / 2.0, p[1] * (d / 2.0 - 0.2)))
	for sz: float in [-(d / 2.0 - 0.02), d / 2.0 - 0.02]:
		_mi(root, _box(w - 0.36, 0.14, 0.035), wood, Vector3(0, h - 0.16, sz))
	for sx: float in [-(w / 2.0 - 0.02), w / 2.0 - 0.02]:
		_mi(root, _box(0.035, 0.12, d - 0.38), wood, Vector3(sx, h - 0.16, 0))
	return root

# ---------- 道具 ----------

## 手电筒:筒身 + 头环 + 透镜(自发光)+ 尾盖 + 防滑环。横躺姿态,由调用方摆位
static func flashlight_prop(m) -> Node3D:
	var root := Node3D.new()
	root.rotation.z = PI / 2.0
	var metal: StandardMaterial3D = m.pmat({"color": Color.html("333a40"), "metallic": 0.75, "roughness": 0.4})
	_mi(root, _cyl(0.042, 0.046, 0.2, 16), metal, Vector3(0, 0, 0))
	_mi(root, _cyl(0.054, 0.054, 0.05, 16), metal, Vector3(0, 0.11, 0))
	_mi(root, _cyl(0.049, 0.049, 0.012, 16), m.pmat({"color": Color.html("fff2d8"), "emission": Color.html("ffe8c0"), "emission_energy": 1.2}), Vector3(0, 0.142, 0), Vector3.ZERO, false)
	_mi(root, _cyl(0.05, 0.05, 0.025, 16), metal, Vector3(0, -0.112, 0))
	for sy: float in [-0.05, 0.05]:
		_mi(root, _cyl(0.047, 0.047, 0.015, 16), metal, Vector3(0, sy, 0))
	_mi(root, _box(0.024, 0.016, 0.012), m.pmat({"color": Color.html("8a9096"), "metallic": 0.8, "roughness": 0.4}), Vector3(0.044, 0.02, 0), Vector3.ZERO, false)
	return root

## 电池:金属柱 + 铜顶帽 + 金色环带。立式,由调用方旋转/摆位
static func battery_prop(m) -> Node3D:
	var root := Node3D.new()
	var metal: StandardMaterial3D = m.pmat({"color": Color.html("383c40"), "metallic": 0.65, "roughness": 0.42})
	_mi(root, _cyl(0.023, 0.023, 0.095, 14), metal, Vector3(0, 0, 0))
	_mi(root, _cyl(0.025, 0.025, 0.018, 14), m.pmat({"color": Color.html("b08d57"), "metallic": 0.85, "roughness": 0.35}), Vector3(0, 0.056, 0), Vector3.ZERO, false)
	_mi(root, _cyl(0.0238, 0.0238, 0.02, 14), m.pmat({"color": Color.html("c8a23c"), "metallic": 0.5, "roughness": 0.5}), Vector3(0, 0.02, 0), Vector3.ZERO, false)
	_mi(root, _cyl(0.0245, 0.0245, 0.008, 14), metal, Vector3(0, -0.05, 0), Vector3.ZERO, false)
	return root

## 药瓶:瓶身 + 瓶盖 + 标签环
static func pill_bottle(m, cap_hex := "3a5a7c") -> Node3D:
	var root := Node3D.new()
	_mi(root, _cyl(0.03, 0.03, 0.1, 12), m.pmat({"color": Color.html("e8e4d8"), "roughness": 0.55}), Vector3(0, 0, 0))
	_mi(root, _cyl(0.026, 0.026, 0.032, 12), m.pmat({"color": Color.html(cap_hex), "roughness": 0.5}), Vector3(0, 0.066, 0), Vector3.ZERO, false)
	_mi(root, _cyl(0.0305, 0.0305, 0.05, 12), m.pmat({"color": Color.html("cfc8b0"), "roughness": 0.85}), Vector3(0, -0.004, 0), Vector3.ZERO, false)
	return root

## 香炉(三足):碗身 + 口沿 + 双耳 + 三足 + 香灰 + 三炷香。
## 返回 tip_mat:解谜后将其 emission 调为红亮即"点燃"
static func incense_burner(m, x: float, y: float, z: float) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(x, y, z)
	m.floor_root.add_child(root)
	var bronze: StandardMaterial3D = m.pmat({
		"tex": m.T.tex.get("metal"), "color": Color.html("4f5d52") if m.T.tex.get("metal") == null else Color.WHITE,
		"metallic": 0.7, "roughness": 0.45,
	})
	_mi(root, _cyl(0.17, 0.11, 0.14, 18), bronze, Vector3(0, 0.1, 0))
	_mi(root, _tor(0.155, 0.185), bronze, Vector3(0, 0.17, 0), Vector3(PI / 2.0, 0, 0))
	for sx: float in [-0.17, 0.17]:
		_mi(root, _tor(0.018, 0.033), bronze, Vector3(sx, 0.2, 0))
	_mi(root, _cyl(0.142, 0.142, 0.028, 18), m.pmat({"color": Color.html("b0a894"), "roughness": 0.98}), Vector3(0, 0.165, 0))
	for i in 3:
		var pivot := Node3D.new()
		pivot.rotation.y = PI / 2.0 + i * TAU / 3.0
		root.add_child(pivot)
		_mi(pivot, _cyl(0.02, 0.026, 0.12, 10), bronze, Vector3(0.105, 0.05, 0), Vector3(0, 0, -0.24))
	var stick_mat: StandardMaterial3D = m.pmat({"color": Color.html("c8b894"), "roughness": 0.9})
	var tip_mat: StandardMaterial3D = m.pmat({"color": Color.html("3a2c22"), "emission": Color.html("241812"), "emission_energy": 0.05})
	var tips: Array = []
	for i in 3:
		var ang := PI / 2.0 + i * TAU / 3.0 + 0.5
		var hh: float = [0.42, 0.38, 0.34][i]
		var sx := cos(ang) * 0.055
		var sz := sin(ang) * 0.055
		_mi(root, _cyl(0.005, 0.009, hh, 6), stick_mat, Vector3(sx, 0.172 + hh / 2.0, sz), Vector3(sz * 0.12, 0, -sx * 0.12), false)
		tips.append(_mi(root, _sph(0.013), tip_mat, Vector3(sx * 1.1, 0.178 + hh, sz * 1.1), Vector3.ZERO, false))
	return {"root": root, "tip_mat": tip_mat, "tips": tips}

## 一对红蜡烛(烛台 + 烛身 + 火苗自发光)
static func candle_pair(m, x: float, y: float, z: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, y, z)
	m.floor_root.add_child(root)
	var brass: StandardMaterial3D = m.pmat({"color": Color.html("8a6a3a"), "metallic": 0.8, "roughness": 0.4})
	var wax: StandardMaterial3D = m.pmat({"color": Color.html("9c2a22"), "roughness": 0.7})
	var flame: StandardMaterial3D = m.pmat({"color": Color.html("ffb066"), "emission": Color.html("ffab55"), "emission_energy": 2.2})
	for sx: float in [-0.12, 0.12]:
		_mi(root, _cyl(0.055, 0.065, 0.02, 14), brass, Vector3(sx, 0.01, 0))
		_mi(root, _cyl(0.024, 0.024, 0.2, 12), wax, Vector3(sx, 0.12, 0))
		_mi(root, _cyl(0.004, 0.004, 0.03, 6), m.pmat({"color": Color.html("1a1410"), "roughness": 1.0}), Vector3(sx, 0.23, 0), Vector3.ZERO, false)
		var fl := _mi(root, _sph(0.018), flame, Vector3(sx, 0.26, 0), Vector3.ZERO, false)
		fl.scale = Vector3(0.9, 1.8, 0.9)
	return root

## 遗照相框:黑框四条 + 衬底 + 遗照贴片(前置)+ 框下托板
static func portrait_stand(m, x: float, y: float, z: float, portrait_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, y, z)
	m.floor_root.add_child(root)
	var fr: StandardMaterial3D = m.pmat({"color": Color.html("141210"), "roughness": 0.5, "clearcoat": 0.4, "cc_rough": 0.3})
	_mi(root, _box(0.86, 0.07, 0.05), fr, Vector3(0, 0.49, 0.01))
	_mi(root, _box(0.86, 0.07, 0.05), fr, Vector3(0, -0.49, 0.01))
	for sx: float in [-0.42, 0.42]:
		_mi(root, _box(0.07, 1.05, 0.05), fr, Vector3(sx, 0, 0.01))
	_mi(root, _box(0.8, 1.0, 0.02), m.pmat({"color": Color.html("26221e"), "roughness": 0.9}), Vector3(0, 0, 0))
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.78, 0.98)
	q.mesh = qm
	q.material_override = portrait_mat
	q.position = Vector3(0, 0, 0.015)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(q)
	_mi(root, _box(0.5, 0.04, 0.09), fr, Vector3(0, -0.56, 0.03))
	return root

## 听诊器:胶管环 + Y 形双耳管 + 听头 + 耳塞
static func stethoscope_prop(m) -> Node3D:
	var root := Node3D.new()
	var tube: StandardMaterial3D = m.pmat({"color": Color.html("22262a"), "roughness": 0.6})
	var steel: StandardMaterial3D = m.pmat({"color": Color.html("8a8f96"), "metallic": 0.9, "roughness": 0.3})
	_mi(root, _tor(0.115, 0.165), tube, Vector3(0, 0, 0))
	for sx: float in [-0.05, 0.05]:
		_mi(root, _cyl(0.011, 0.011, 0.17, 8), steel, Vector3(sx, 0.15, 0), Vector3(0, 0, -signf(sx) * 0.5), false)
		_mi(root, _sph(0.022), m.pmat({"color": Color.html("5c5148"), "roughness": 0.85}), Vector3(sx - signf(sx) * 0.08, 0.225, 0), Vector3.ZERO, false)
	_mi(root, _cyl(0.05, 0.05, 0.022, 14), steel, Vector3(0, -0.175, 0.01), Vector3(PI / 2.0, 0, 0))
	root.rotation.z = 0.08
	return root

## 壁挂监控:壁座 + 双段臂 + 云台 + 外壳 + 屏幕 + 状态点。屏幕材质由调用方构造(headless 回退)
static func monitor_rig(m, x: float, y: float, z: float, ry: float, screen_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, y, z)
	root.rotation.y = ry
	m.floor_root.add_child(root)
	var steel: StandardMaterial3D = m.pmat({"color": Color.html("3a3f44"), "metallic": 0.8, "roughness": 0.4})
	var shell: StandardMaterial3D = m.pmat({"color": Color.html("22262a"), "roughness": 0.55, "metallic": 0.3})
	_mi(root, _box(0.3, 0.4, 0.06), steel, Vector3(0, 0, -0.55))
	_mi(root, _box(0.07, 0.07, 0.34), steel, Vector3(0, 0.05, -0.38))
	_mi(root, _box(0.14, 0.1, 0.1), steel, Vector3(0, 0, -0.2))
	_mi(root, _box(1.56, 0.98, 0.15), shell, Vector3(0, 0, 0))
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.42, 0.84)
	q.mesh = qm
	q.material_override = screen_mat
	q.position = Vector3(0, 0.02, 0.083)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(q)
	_mi(root, _sph(0.013), m.pmat({"color": Color.html("5a1410"), "emission": Color.html("ff3a2a"), "emission_energy": 1.4}), Vector3(0.68, -0.4, 0.085), Vector3.ZERO, false)
	return root

## 挂钟:外圈 + 面盘 + 四主刻度 + 时/分针(返回 pivot 供按 G.time 转动)
static func wall_clock(m, x: float, y: float, z: float, ry: float) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(x, y, z)
	root.rotation.y = ry
	m.floor_root.add_child(root)
	var rim: StandardMaterial3D = m.pmat({"color": Color.html("322a20"), "roughness": 0.6})
	var face: StandardMaterial3D = m.pmat({"color": Color.html("d8d2c0"), "roughness": 0.85})
	_mi(root, _tor(0.17, 0.198), rim, Vector3(0, 0, 0))
	_mi(root, _cyl(0.172, 0.172, 0.03, 24), face, Vector3(0, 0, 0.008), Vector3(PI / 2.0, 0, 0))
	for p: Array in [[0.0, 0.138, 0.014, 0.036], [0.0, -0.138, 0.014, 0.036], [0.138, 0.0, 0.036, 0.014], [-0.138, 0.0, 0.036, 0.014]]:
		_mi(root, _box(p[2], p[3], 0.006), m.pmat({"color": Color.html("2a241c"), "roughness": 0.8}), Vector3(p[0], p[1], 0.026), Vector3.ZERO, false)
	var hp := Node3D.new()
	hp.position = Vector3(0, 0, 0.032)
	root.add_child(hp)
	_mi(hp, _box(0.016, 0.1, 0.006), m.pmat({"color": Color.html("2a241c"), "roughness": 0.7}), Vector3(0, 0.032, 0), Vector3.ZERO, false)
	var mp := Node3D.new()
	mp.position = Vector3(0, 0, 0.038)
	root.add_child(mp)
	_mi(mp, _box(0.011, 0.145, 0.006), m.pmat({"color": Color.html("1a1610"), "roughness": 0.7}), Vector3(0, 0.048, 0), Vector3.ZERO, false)
	_mi(root, _sph(0.014), m.pmat({"color": Color.html("8a6a3a"), "metallic": 0.7, "roughness": 0.4}), Vector3(0, 0, 0.042), Vector3.ZERO, false)
	return {"root": root, "hp": hp, "mp": mp}

## 麻将牌堆:三摞叠牌 + 一张立牌,挂到指定父节点(桌面)
static func mahjong_heap(m, parent: Node3D, x: float, y: float, z: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, y, z)
	parent.add_child(root)
	var ivory: StandardMaterial3D = m.pmat({"color": Color.html("ede6d2"), "roughness": 0.45})
	for p: Array in [[-0.06, 0.02, 0.0], [0.02, -0.03, 0.01], [0.08, 0.03, -0.02]]:
		_mi(root, _box(0.05, 0.022, 0.068), ivory, Vector3(p[0], 0.011, p[1]))
		_mi(root, _box(0.05, 0.022, 0.068), ivory, Vector3(p[0] + 0.006, 0.033, p[1] + 0.004), Vector3(0, 0.08, 0.02))
	_mi(root, _box(0.05, 0.07, 0.022), ivory, Vector3(-0.13, 0.045, 0.05), Vector3(-1.25, 0.4, 0), false)
	return root

## 日记本(diary 贴图封面 + 白页边),平放微斜
static func diary_prop(m, x: float, z: float, ry := 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, 0, z)
	root.rotation = Vector3(0, ry + 0.35, 0.03)
	m.floor_root.add_child(root)
	_mi(root, _box(0.28, 0.014, 0.4), m.pmat({"color": Color.html("e2dcc8"), "roughness": 0.9}), Vector3(0, 0.012, 0.004))
	_mi(root, _box(0.3, 0.016, 0.42), m.tex_mat("diary", "7a3040", {"roughness": 0.6, "clearcoat": 0.3, "cc_rough": 0.4}), Vector3(0, 0.026, 0))
	return root

## 入口地垫:暗红薄垫 + 深色包边
static func floor_mat(m, x: float, z: float, ry := 0.0) -> Node3D:
	var root := _root(m, x, z, ry)
	var mat: StandardMaterial3D = m.pmat({"color": Color.html("5a2320"), "roughness": 0.95})
	var edge: StandardMaterial3D = m.pmat({"color": Color.html("3c1714"), "roughness": 0.95})
	_mi(root, _box(1.4, 0.016, 0.9), mat, Vector3(0, 0.008, 0))
	_mi(root, _box(1.4, 0.018, 0.06), edge, Vector3(0, 0.009, 0.42))
	_mi(root, _box(1.4, 0.018, 0.06), edge, Vector3(0, 0.009, -0.42))
	for sx: float in [-0.67, 0.67]:
		_mi(root, _box(0.06, 0.018, 0.78), edge, Vector3(sx, 0.009, 0))
	return root

## 矮柜(3F 藏身点):高 0.8m,可遮挡蹲伏玩家;门缝与把手压色
static func low_cabinet(m, x: float, z: float, ry := 0.0, col_hex := "6a5232") -> Node3D:
	var root := _root(m, x, z, ry)
	var body: StandardMaterial3D = m.pmat({"color": Color.html(col_hex), "roughness": 0.75})
	var dark: StandardMaterial3D = m.pmat({"color": Color.html("3a2c18"), "roughness": 0.8})
	_mi(root, _box(1.6, 0.78, 0.6), body, Vector3(0, 0.39, 0))
	_mi(root, _box(1.62, 0.04, 0.62), dark, Vector3(0, 0.79, 0))
	for i in 2:
		_mi(root, _box(0.74, 0.7, 0.02), dark, Vector3(-0.39 + i * 0.78, 0.39, 0.3))
	for i in 2:
		_mi(root, _box(0.16, 0.03, 0.04), m.pmat({"color": Color.html("c8b46a"), "metallic": 0.6, "roughness": 0.4}), Vector3(-0.39 + i * 0.78, 0.5, 0.32))
	return root

## 儿童桌椅(3F 教室):矮桌四圆腿 + 小椅
static func child_desk(m, x: float, z: float, ry := 0.0) -> Node3D:
	var root := _root(m, x, z, ry)
	var wood: StandardMaterial3D = m.pmat({"color": Color.html("8a6a3e"), "roughness": 0.7})
	_mi(root, _box(0.9, 0.05, 0.6), wood, Vector3(0, 0.5, 0))
	for p: Array in [[-0.38, -0.23], [0.38, -0.23], [-0.38, 0.23], [0.38, 0.23]]:
		_mi(root, _cyl(0.025, 0.025, 0.5), wood, Vector3(p[0], 0.25, p[1]))
	_mi(root, _box(0.14, 0.04, 0.04), wood, Vector3(0.3, 0.35, 0), Vector3(0.5, 0, 0))
	_mi(root, _box(0.5, 0.04, 0.04), wood, Vector3(0, 0.44, -0.26), Vector3(0.5, 0, 0))
	return root

static func child_chair(m, x: float, z: float, ry := 0.0) -> Node3D:
	var root := _root(m, x, z, ry)
	var wood: StandardMaterial3D = m.pmat({"color": Color.html("7a5c34"), "roughness": 0.72})
	_mi(root, _box(0.34, 0.04, 0.32), wood, Vector3(0, 0.28, 0))
	_mi(root, _box(0.34, 0.36, 0.03), wood, Vector3(0, 0.46, -0.15))
	for p: Array in [[-0.14, -0.12], [0.14, -0.12], [-0.14, 0.12], [0.14, 0.12]]:
		_mi(root, _cyl(0.018, 0.018, 0.28), wood, Vector3(p[0], 0.14, p[1]))
	return root

## 网吧电脑位(5F):桌 + 显示器(屏面材质由楼层给,可发光)+ 键盘
static func pc_terminal(m, x: float, z: float, ry := 0.0, screen_mat: Material = null, desk_hex := "4a4038") -> Node3D:
	var root := _root(m, x, z, ry)
	var desk: StandardMaterial3D = m.pmat({"color": Color.html(desk_hex), "roughness": 0.8})
	_mi(root, _box(1.2, 0.05, 0.7), desk, Vector3(0, 0.72, 0))
	for p: Array in [[-0.55, -0.3], [0.55, -0.3], [-0.55, 0.3], [0.55, 0.3]]:
		_mi(root, _box(0.05, 0.72, 0.05), desk, Vector3(p[0], 0.36, p[1]))
	var plas: StandardMaterial3D = m.pmat({"color": Color.html("1c1c1e"), "roughness": 0.5})
	var smat: Material = screen_mat if screen_mat != null else plas
	_mi(root, _box(0.56, 0.36, 0.035), plas, Vector3(0, 1.12, -0.16))
	_mi(root, _box(0.5, 0.3, 0.005), smat, Vector3(0, 1.12, -0.14), Vector3.ZERO, false)
	_mi(root, _box(0.08, 0.18, 0.08), plas, Vector3(0, 0.86, -0.16))
	_mi(root, _box(0.3, 0.03, 0.2), plas, Vector3(0, 0.86, -0.1))
	_mi(root, _box(0.42, 0.025, 0.16), m.pmat({"color": Color.html("2a2a2c"), "roughness": 0.6}), Vector3(0, 0.755, 0.08))
	return root

## 铁皮档案柜(8F):0.9×1.9×0.5,四层抽屉线 + 标签槽 + 把手
static func file_cabinet(m, x: float, z: float, ry := 0.0, col_hex := "5a6158") -> Node3D:
	var root := _root(m, x, z, ry)
	var body: StandardMaterial3D = m.pmat({"color": Color.html(col_hex), "metallic": 0.35, "roughness": 0.6})
	var seam: StandardMaterial3D = m.pmat({"color": Color.html("3c423c"), "roughness": 0.7})
	_mi(root, _box(0.9, 1.9, 0.5), body, Vector3(0, 0.95, 0))
	_mi(root, _box(0.92, 0.03, 0.52), seam, Vector3(0, 1.9, 0))
	for i in 4:
		var y := 0.42 + i * 0.44
		_mi(root, _box(0.84, 0.02, 0.03), seam, Vector3(0, y, 0.255))
		_mi(root, _box(0.24, 0.07, 0.012), m.pmat({"color": Color.html("d8cfb4"), "roughness": 0.9}), Vector3(0, y + 0.2, 0.257))
		_mi(root, _box(0.12, 0.025, 0.035), m.pmat({"color": Color.html("c8b46a"), "metallic": 0.6, "roughness": 0.4}), Vector3(0.3, y + 0.08, 0.26))
	return root

## 立镜(9F):木框 + 高反光镜面(metallic 1.0 / roughness 0.05)
static func mirror_stand(m, x: float, z: float, ry := 0.0, face_mat: Material = null) -> Node3D:
	var root := _root(m, x, z, ry)
	var frame: StandardMaterial3D = m.pmat({"color": Color.html("3c2f22"), "roughness": 0.65})
	_mi(root, _box(0.86, 2.1, 0.07), frame, Vector3(0, 1.05, 0))
	var fmat: Material = face_mat if face_mat != null else m.pmat({
		"color": Color.html("b8c2cc"), "metallic": 1.0, "roughness": 0.05,
		"clearcoat": 1.0, "cc_rough": 0.03,
	})
	_mi(root, _box(0.72, 1.9, 0.012), fmat, Vector3(0, 1.08, 0.036))
	for sx: float in [-0.18, 0.18]:
		_mi(root, _box(0.05, 0.05, 0.1), frame, Vector3(sx, 0.03, 0))
	return root

## 宴席假人(10F):坐姿躯干 + 头 + 肩球,布料色可调;胸牌由楼层另贴
static func banquet_dummy(m, x: float, z: float, ry := 0.0, cloth_hex := "46384a") -> Node3D:
	var root := _root(m, x, z, ry)
	var cloth: StandardMaterial3D = m.pmat({"color": Color.html(cloth_hex), "roughness": 0.92})
	var skin: StandardMaterial3D = m.pmat({"color": Color.html("a89a86"), "roughness": 0.85})
	_mi(root, _cyl(0.17, 0.22, 0.62), cloth, Vector3(0, 0.31, 0))
	for sx: float in [-0.1, 0.1]:
		_mi(root, _cyl(0.055, 0.055, 0.5), cloth, Vector3(sx, 0.25, 0.24), Vector3(PI / 2.0, 0, 0))
		_mi(root, _cyl(0.05, 0.05, 0.48), cloth, Vector3(sx, 0.24, 0.46))
	for sx: float in [-0.2, 0.2]:
		_mi(root, _sph(0.075), cloth, Vector3(sx, 0.58, 0))
		_mi(root, _cyl(0.04, 0.04, 0.3), cloth, Vector3(sx * 1.35, 0.5, 0), Vector3(0, 0, 0.7))
	_mi(root, _cyl(0.05, 0.055, 0.1), skin, Vector3(0, 0.64, 0))
	_mi(root, _sph(0.135), skin, Vector3(0, 0.78, 0.01))
	return root

## 轿车(B1):两层车身 + 四轮 + 深色车窗;无车牌(设定)
static func sedan_car(m, x: float, z: float, ry := 0.0, body_hex := "3a4048") -> Node3D:
	var root := _root(m, x, z, ry)
	var paint: StandardMaterial3D = m.pmat({"color": Color.html(body_hex), "metallic": 0.55, "roughness": 0.35, "clearcoat": 0.6, "cc_rough": 0.25})
	var glass: StandardMaterial3D = m.pmat({"color": Color.html("10141a"), "metallic": 0.4, "roughness": 0.15})
	var tire: StandardMaterial3D = m.pmat({"color": Color.html("141414"), "roughness": 0.95})
	_mi(root, _box(1.8, 0.5, 4.2), paint, Vector3(0, 0.55, 0))
	_mi(root, _box(1.6, 0.42, 2.1), glass, Vector3(0, 1.0, -0.15))
	_mi(root, _box(1.7, 0.06, 4.24), paint, Vector3(0, 0.81, 0))
	for p: Array in [[-0.82, -1.35], [0.82, -1.35], [-0.82, 1.35], [0.82, 1.35]]:
		var w := _mi(root, _cyl(0.32, 0.32, 0.22), tire, Vector3(p[0], 0.32, p[1]))
		w.rotation.z = PI / 2.0
	return root

## 立式锅炉(B2):罐体 + 顶盖 + 铆钉圈 + 侧管
static func boiler_unit(m, x: float, z: float, ry := 0.0, col_hex := "5a3a34") -> Node3D:
	var root := _root(m, x, z, ry)
	var metal: StandardMaterial3D = m.pmat({"color": Color.html(col_hex), "metallic": 0.5, "roughness": 0.55})
	_mi(root, _cyl(0.75, 0.8, 2.4), metal, Vector3(0, 1.2, 0))
	_mi(root, _cyl(0.82, 0.6, 0.35), metal, Vector3(0, 2.5, 0))
	for y: float in [0.6, 1.5, 2.3]:
		_mi(root, _tor(0.72, 0.78), m.pmat({"color": Color.html("3a241e"), "metallic": 0.5, "roughness": 0.6}), Vector3(0, y, 0), Vector3(PI / 2.0, 0, 0))
	_mi(root, _cyl(0.09, 0.09, 1.4), metal, Vector3(0.5, 1.6, 0.5), Vector3(0.6, 0, 0.4))
	_mi(root, _cyl(0.07, 0.07, 1.1), metal, Vector3(-0.55, 1.3, -0.4), Vector3(-0.5, 0.4, 0))
	return root

## 石祭坛(11F):粗石台 + 台面 + 供位凹槽
static func altar_stone(m, x: float, z: float, ry := 0.0) -> Node3D:
	var root := _root(m, x, z, ry)
	var stone: StandardMaterial3D = m.pmat({"color": Color.html("6a655c"), "roughness": 0.95})
	var top: StandardMaterial3D = m.pmat({"color": Color.html("7a7468"), "roughness": 0.9})
	_mi(root, _box(1.8, 0.85, 1.0), stone, Vector3(0, 0.425, 0))
	_mi(root, _box(2.0, 0.12, 1.2), top, Vector3(0, 0.91, 0))
	_mi(root, _box(1.2, 0.04, 0.5), m.pmat({"color": Color.html("2c2822"), "roughness": 0.8}), Vector3(0, 0.98, 0))
	for sx: float in [-0.7, 0.7]:
		_mi(root, _box(0.24, 1.0, 0.24), stone, Vector3(sx, 0.5, -0.5))
	return root

## 黑板(3F):木框 + 板面(板面材质由楼层给,可用 chalk 贴图)
static func chalkboard(m, x: float, y: float, z: float, ry := 0.0, face_mat: Material = null) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, y, z)
	root.rotation.y = ry
	m.floor_root.add_child(root)
	var frame: StandardMaterial3D = m.pmat({"color": Color.html("4a3624"), "roughness": 0.7})
	_mi(root, _box(2.6, 1.3, 0.06), frame, Vector3(0, 0, 0))
	var fmat: Material = face_mat if face_mat != null else m.pmat({"color": Color.html("28402e"), "roughness": 0.95})
	_mi(root, _box(2.44, 1.14, 0.012), fmat, Vector3(0, 0, 0.031))
	return root
