class_name FloorCommon
extends RefCounted
## 公共楼层搭建:房间外壳 + 电梯间(与原 three.js 版几何/碰撞一致)
## WALL_H 单一来源为 main.gd 的 m.WALL_H(楼层脚本均经此引用)

static func room_shell(m, w := 20.0, d := 16.0) -> void:
	# 地板(做旧抛光:清漆 + 砖缝法线) / 天花
	var fmat: StandardMaterial3D = m.pmat({
		"tex": m.T.tex.get("floor"), "normal": m.T.tex.get("floor_n"),
		"uv1": Vector3(w / 4.0, d / 4.0, 1.0),
		"roughness": 0.48, "clearcoat": 0.35, "cc_rough": 0.4,
		"normal_scale": 0.85,
		"color": Color.html("6b675e") if m.T.tex.get("floor") == null else Color.WHITE,
	})
	m.add_floor_plane(w, d, fmat, 0, 0, 0, true)
	var cmat: StandardMaterial3D = m.pmat({
		"tex": m.T.tex.get("ceil"), "normal": m.T.tex.get("wall_n"),
		"uv1": Vector3(w / 4.0, d / 4.0, 1.0),
		"roughness": 0.95, "normal_scale": 0.3,
		"color": Color.html("4a473f") if m.T.tex.get("ceil") == null else Color.WHITE,
	})
	m.add_floor_plane(w, d, cmat, 0, m.WALL_H, 0, false)
	# 四周外墙(+Z 侧中央留 2.4m 电梯口)
	m.add_wall(-w / 2.0, 0.0, 0.3, d)
	m.add_wall(w / 2.0, 0.0, 0.3, d)
	m.add_wall(0.0, -d / 2.0, w, 0.3)
	m.add_wall(-(w / 4.0 + 0.6), d / 2.0, w / 2.0 - 1.2, 0.3)
	m.add_wall((w / 4.0 + 0.6), d / 2.0, w / 2.0 - 1.2, 0.3)
	# 东西长墙的分段壁柱(南北墙有门 / 电梯口,不加;位置避开 2F 窗与各层贴墙家具)
	for sx: float in [-w / 2.0, w / 2.0]:
		for sz: float in [-4.0, 4.0]:
			m.add_box(0.3, m.WALL_H - 0.1, 0.46, m._trim_mat("pilaster"), sx, (m.WALL_H - 0.1) / 2.0, sz, false)

## 电梯间:统一位于 +Z 侧中央
static func build_elevator(m) -> void:
	var mt: StandardMaterial3D = m.pmat({
		"tex": m.T.tex.get("metal"), "normal": m.T.tex.get("metal_n"),
		"metallic": 0.85, "roughness": 0.38, "normal_scale": 0.3,
		"color": Color.html("7c8084") if m.T.tex.get("metal") == null else Color.WHITE,
	})
	# 侧墙面错开 ±1.2 平面(南墙段端面所在),北端收进后墙体内——避免共面 z-fighting
	m.add_wall(-1.37, 8.925, 0.3, 1.85, mt, false)
	m.add_wall(1.37, 8.925, 0.3, 1.85, mt, false)
	m.add_wall(0.0, 9.75, 3.0, 0.3, mt, false)
	# 双开门(带碰撞,防止穿模)
	var dm: StandardMaterial3D = m.pmat({
		"tex": m.T.tex.get("metal"), "normal": m.T.tex.get("metal_n"),
		"metallic": 0.85, "roughness": 0.3, "normal_scale": 0.25,
		"color": Color.html("7c8084") if m.T.tex.get("metal") == null else Color.WHITE,
	})
	var dl: MeshInstance3D = m.add_box(1.2, 2.6, 0.12, dm, -0.6, 1.3, 7.98, false)
	var dr: MeshInstance3D = m.add_box(1.2, 2.6, 0.12, dm, 0.6, 1.3, 7.98, false)
	m.colliders.append(Rect2(-1.2, 7.9, 2.4, 0.18))
	m.elevator_doors = {"dl": dl, "dr": dr}
	# 门楣横梁(北脸凸出墙面 1cm,避开共面):从门顶 2.6 一直补到天花 3.2,填满门洞上方
	m.add_box(3.0, 0.6, 0.2, mt, 0, 2.9, 7.94, false)
	# 轿厢顶/底板:电梯间外凸于房间天花与地板平面(z>8)之外,需自行封闭,否则门开时看穿
	m.add_box(3.04, 0.12, 1.9, mt, 0, m.WALL_H - 0.06, 8.95, false)
	m.add_box(3.04, 0.12, 1.9, mt, 0, -0.06, 8.95, false)
	m.add_box(0.44, 0.18, 0.04, m.pmat({"color": Color.html("101410"), "roughness": 0.6}), 0, 2.86, 7.85, false)
	var ind := MeshInstance3D.new()
	var ic := CylinderMesh.new()
	ic.top_radius = 0.03
	ic.bottom_radius = 0.03
	ic.height = 0.02
	ind.mesh = ic
	ind.material_override = m.pmat({"color": Color.html("0a2012"), "emission": Color.html("4ade6a"), "emission_energy": 2.0})
	ind.rotation.x = PI / 2.0
	ind.position = Vector3(0, 2.86, 7.82)
	ind.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.floor_root.add_child(ind)
	m.add_box(2.3, 0.03, 0.18, mt, 0, 0.015, 7.82, false)
	# 电梯内小灯 + 呼梯面板(轿厢氛围小灯不开影)
	m.add_light(Color.html("aaccdd"), 0.5, 4.0, 0, 2.4, 8.9, 0.1, false)
	var panel: StandardMaterial3D = m.pmat({
		"color": Color.html("222826"), "emission": Color.html("1a3326"),
		"emission_energy": 1.2, "metallic": 0.3, "roughness": 0.5,
	})
	m.add_box(0.3, 0.42, 0.06, panel, 1.55, 1.45, 7.93, false)
	# 呼梯按钮(上行红 / 下行绿,微光)
	for b: Array in [[1.52, "8a2e28"], [1.38, "2e5a3c"]]:
		var btn := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.022
		bc.bottom_radius = 0.022
		bc.height = 0.016
		btn.mesh = bc
		btn.material_override = m.pmat({"color": Color.html(b[1]), "emission": Color.html(b[1]), "emission_energy": 0.45, "roughness": 0.4})
		btn.rotation.x = PI / 2.0
		btn.position = Vector3(1.55, b[0], 7.885)
		btn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.floor_root.add_child(btn)
	m.add_inter(Vector3(1.55, 1.4, 7.8), "呼梯面板", func() -> void:
		m.open_elevator_ui(), 2.2)
