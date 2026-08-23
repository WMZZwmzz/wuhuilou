extends RefCounted
## 4F 诊所

static func build(m) -> void:
	m.setup_env(0.1, Color.html("223038"), Color.html("070b0e"), 0.05)
	FloorCommon.room_shell(m, 20.0, 16.0)
	FloorCommon.build_elevator(m)
	m.add_light(Color.html("9ab8cc"), 0.35, 9.0, 0, 2.9, 4, 0.15)
	# 候诊椅
	for i in 3:
		Props.waiting_chair(m, -6 + i * 1.1, 3)
		m.colliders.append(Rect2(-6 + i * 1.1 - 0.3, 3 - 0.9, 0.6, 1.8))
	# 诊室(+X 后侧,门口 x 7.4~8.6)
	m.add_wall(6.5, -6, 0.3, 4.2)
	m.add_wall(6.95, -4.05, 0.9, 0.3)
	m.add_wall(9.15, -4.05, 1.1, 0.3)
	Props.wood_desk(m, 8, -6.4, 0.0, 2.4, 1.0, 0.85, "5a5248")
	m.colliders.append(Rect2(8 - 1.2, -6.4 - 0.5, 2.4, 1.0))
	var reg_book := Node3D.new()
	reg_book.position = Vector3(8, 0.88, -6.2)
	reg_book.rotation.y = 0.35
	m.floor_root.add_child(reg_book)
	var rp := MeshInstance3D.new()
	var rpb := BoxMesh.new()
	rpb.size = Vector3(0.34, 0.024, 0.26)
	rp.mesh = rpb
	rp.material_override = m.pmat({"color": Color.html("d8d2be"), "roughness": 0.9})
	rp.position = Vector3(0, 0.012, 0)
	reg_book.add_child(rp)
	var rc := MeshInstance3D.new()
	var rcb := BoxMesh.new()
	rcb.size = Vector3(0.36, 0.026, 0.28)
	rc.mesh = rcb
	rc.material_override = m.pmat({"color": Color.html("3c5450"), "roughness": 0.6, "clearcoat": 0.3, "cc_rough": 0.4})
	rc.position = Vector3(0, 0.026, -0.015)
	reg_book.add_child(rc)
	m.add_light(Color.html("c8d8b0"), 0.3, 5.0, 8, 2.7, -6, 0.1)
	# 处方登记册(权限卡)
	var reg_cb := func() -> void:
		if not m.G.flags.get("card4F", false):
			m.G.flags["card4F"] = true
			m.gain_card("5F")
			m.H.set_objective("乘电梯前往 5F 网吧")
		else:
			m.H.show_msg("登记册最后一页写着:\"5F 网管室——那段录像,就差一个批号。\"")
	m.add_inter(Vector3(8, 1.0, -6.2), "处方登记册", reg_cb, 2.2)
	# 听诊器(遗物)
	var steth := Props.stethoscope_prop(m)
	steth.position = Vector3(7.1, 0.92, -6.5)
	m.floor_root.add_child(steth)
	var steth_cb := func() -> void:
		if m.G.flags.get("relic4F", false):
			return
		m.G.flags["relic4F"] = true
		if is_instance_valid(steth):
			steth.free()
		m.gain_relic("听诊器")
	var steth_cond := func() -> bool: return not m.G.flags.get("relic4F", false)
	m.add_inter(Vector3(7.1, 1.0, -6.5), "听诊器", steth_cb, 2.0, steth_cond)
	# 药柜(+X 墙,主厅内):两次搜刮分别取得 A/B 两瓶药
	var cab := Props.medicine_cabinet(m, 9.5, -1.5, -PI / 2.0)
	m.colliders.append(Rect2(9.5 - 0.8, -1.5 - 0.225, 1.6, 0.45))
	var cab_cb := func() -> void:
		if not m.G.flags.get("pillA", false):
			m.G.flags["pillA"] = true
			m.G.pills["a"] += 1
			if is_instance_valid(cab["bottle_a"]):
				cab["bottle_a"].free()
			m.H.show_msg("搜出一瓶镇静片。药瓶A,批号 TX-2048。标签被水渍泡得模糊。", 4.6)
		elif not m.G.flags.get("pillB", false):
			m.G.flags["pillB"] = true
			m.G.pills["b"] += 1
			if is_instance_valid(cab["bottle_b"]):
				cab["bottle_b"].free()
			m.H.show_msg("药柜深处还有一瓶。药瓶B,批号 TX-2051。瓶身摸上去有点温,像刚被人握过。", 5.0)
		else:
			m.H.show_msg("药柜空了。只剩蟑螂爬过的痕迹。")
	m.add_inter(Vector3(9.2, 1.2, -1.5), "药柜", cab_cb, 2.2)
	# 处方批号页(候诊椅上):真伪辨别的第一环——完整药典在 8F 档案室(跨层回溯设计)
	var page: MeshInstance3D = m.add_quad(0.5, 0.7, m.pmat({"color": Color.html("cfc6a8"), "roughness": 0.9}), -6, 0.5, 3, 0.3, -PI / 2.2)
	var page_cb := func() -> void:
		m.open_modal({
			"title": "处 方 批 号 页",
			"body": "\"本院镇静片,真伪以批号为准。\n真伪对照表详见《药典》正本——存 8F 档案室,编号宗 08。\"\n\n批号就印在瓶身上:A 瓶 TX-2048,B 瓶 TX-2051。\n可哪边是真,哪边是假,这一页没写。",
			"choices": [{"text": "收好残页", "fn": func() -> void:
				m.close_modal()
				m.H.show_msg("批号:TX-2048 / TX-2051。答案在 8F——如果还要回来的话。", 5.2)}],
		})
	m.add_inter(Vector3(-6, 0.5, 3), "处方批号页", page_cb, 2.0)
	# 人体模型(走廊中央,哭泣天使)—— 光面塑料,清漆反光
	var mann := Node3D.new()
	var mk_mat := func(hex: String) -> StandardMaterial3D:
		return m.pmat({"color": Color.html(hex), "roughness": 0.45, "clearcoat": 0.5, "cc_rough": 0.3})
	var m_body := MeshInstance3D.new()
	var bcy := CylinderMesh.new()
	bcy.top_radius = 0.16
	bcy.bottom_radius = 0.22
	bcy.height = 1.15
	m_body.mesh = bcy
	m_body.material_override = mk_mat.call("b8b0a2")
	m_body.position = Vector3(0, 0.85, 0)
	var m_head := MeshInstance3D.new()
	var hsp := SphereMesh.new()
	hsp.radius = 0.15
	hsp.height = 0.3
	m_head.mesh = hsp
	m_head.material_override = mk_mat.call("c4bcae")
	m_head.position = Vector3(0, 1.55, 0)
	var m_arm := MeshInstance3D.new()
	var ac := CylinderMesh.new()
	ac.top_radius = 0.045
	ac.bottom_radius = 0.045
	ac.height = 0.7
	m_arm.mesh = ac
	m_arm.material_override = mk_mat.call("b8b0a2")
	m_arm.position = Vector3(0.22, 1.15, 0)
	m_arm.rotation.z = 0.5
	var m_arm2 := MeshInstance3D.new()
	m_arm2.mesh = ac
	m_arm2.material_override = mk_mat.call("b8b0a2")
	m_arm2.position = Vector3(-0.22, 1.15, 0)
	m_arm2.rotation.z = -0.5
	# 五叉轮底座 + 髋 + 双腿 + 颈 + 肩球(医疗教学模型式)
	var stem := MeshInstance3D.new()
	var stc := CylinderMesh.new()
	stc.top_radius = 0.028
	stc.bottom_radius = 0.032
	stc.height = 0.3
	stem.mesh = stc
	stem.material_override = mk_mat.call("b8b0a2")
	stem.position = Vector3(0, 0.2, 0)
	mann.add_child(stem)
	for i in 5:
		var piv := Node3D.new()
		piv.rotation.y = i * TAU / 5.0
		mann.add_child(piv)
		var limb := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.013
		lc.bottom_radius = 0.013
		lc.height = 0.44
		limb.mesh = lc
		limb.material_override = mk_mat.call("b8b0a2")
		limb.rotation.z = PI / 2.0 - 0.07
		limb.position = Vector3(0.2, 0.06, 0)
		piv.add_child(limb)
		var wheel := MeshInstance3D.new()
		var wc := CylinderMesh.new()
		wc.top_radius = 0.032
		wc.bottom_radius = 0.032
		wc.height = 0.02
		wheel.mesh = wc
		wheel.material_override = m.pmat({"color": Color.html("2c2c2e"), "roughness": 0.7})
		wheel.rotation.x = PI / 2.0
		wheel.position = Vector3(0.4, 0.035, 0)
		wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piv.add_child(wheel)
	var hip := MeshInstance3D.new()
	var hpb := BoxMesh.new()
	hpb.size = Vector3(0.3, 0.16, 0.18)
	hip.mesh = hpb
	hip.material_override = mk_mat.call("b8b0a2")
	hip.position = Vector3(0, 0.43, 0)
	mann.add_child(hip)
	for sx: float in [-0.09, 0.09]:
		var leg := MeshInstance3D.new()
		var gc := CylinderMesh.new()
		gc.top_radius = 0.05
		gc.bottom_radius = 0.055
		gc.height = 0.32
		leg.mesh = gc
		leg.material_override = mk_mat.call("b8b0a2")
		leg.position = Vector3(sx, 0.3, 0)
		mann.add_child(leg)
	var neck := MeshInstance3D.new()
	var nc := CylinderMesh.new()
	nc.top_radius = 0.035
	nc.bottom_radius = 0.04
	nc.height = 0.1
	neck.mesh = nc
	neck.material_override = mk_mat.call("c4bcae")
	neck.position = Vector3(0, 1.47, 0)
	mann.add_child(neck)
	for sx: float in [-0.22, 0.22]:
		var shoulder := MeshInstance3D.new()
		var spm := SphereMesh.new()
		spm.radius = 0.07
		spm.height = 0.14
		shoulder.mesh = spm
		shoulder.material_override = mk_mat.call("b8b0a2")
		shoulder.position = Vector3(sx, 1.38, 0)
		mann.add_child(shoulder)
	mann.add_child(m_body)
	mann.add_child(m_head)
	mann.add_child(m_arm)
	mann.add_child(m_arm2)
	mann.position = Vector3(0, 0, -2)
	m.floor_root.add_child(mann)
	var scare := {"count": 0}
	var drip_t := 3.0   # 诊所滴水环境音(设计文档:4F"水滴滴落,阴冷")
	m.floor_update = func(dt: float) -> void:
		drip_t -= dt
		if drip_t <= 0.0:
			drip_t = 5.0 + randf() * 9.0
			m.S.play_buf("drip", 1.5)
		if m.G.flags.get("mannGone", false) or not is_instance_valid(mann):
			return
		var to_m: Vector3 = mann.position - m.player_pos
		to_m.y = 0.0
		var dist := to_m.length()
		var fwd: Vector3 = m.cam_forward()
		var looking := dist < 11.0 and to_m.normalized().dot(fwd) > 0.35
		if not looking:
			var dir: Vector3 = m.player_pos - mann.position
			dir.y = 0.0
			if dir.length() > 0.1:
				mann.position += dir.normalized() * 1.5 * dt
			mann.look_at(Vector3(m.player_pos.x, mann.position.y, m.player_pos.z))
		if dist < 1.3:
			scare["count"] += 1
			m.change_sanity(-12.0)
			m.H.red_flash()
			m.S.sting()
			m.shake = 2.0
			mann.position = Vector3(0, 0, -2)
			m.H.show_msg("模型冰凉的指尖擦过你的后颈。\n它退回了走廊中央,摆回原来的姿势。理智 −12", 5.0)
			if scare["count"] >= 3:
				m.G.flags["mannGone"] = true
				mann.visible = false
				m.get_tree().create_timer(2.5).timeout.connect(func() -> void:
					m.H.show_msg("再回头,模型不见了。诊室的地板上留着一圈灰白的人形粉印。", 4.6))
	m.tp_list([
		{"x": 8.0, "z": -4.6, "yaw": 0.0},
		{"x": 7.2, "z": -5.6, "yaw": 0.11},
		{"x": 8.2, "z": -1.5, "yaw": -PI / 2.0},
		{"x": -6.0, "z": 1.5, "yaw": PI},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("4F 诊所。找到权限卡(诊室)·小心走廊里的人体模型")
	m.H.show_msg("4F。消毒水的味道,淡得像回忆。走廊里站着一个\"人\"。", 5.2)
