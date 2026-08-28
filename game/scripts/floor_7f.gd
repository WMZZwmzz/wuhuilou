extends RefCounted
## 7F 灵堂

# 纸人薄体积厚度:侧面掠射角下避免只剩一条刃边而"消失"
const PM_THICKNESS := 0.012

static func build(m) -> void:
	m.setup_env(0.12, Color.html("30201c"), Color.html("0e0605"), 0.05)
	FloorCommon.room_shell(m, 20.0, 16.0)
	FloorCommon.build_elevator(m)
	# 供桌 + 香炉(-Z 中央)—— 上漆旧木
	Props.altar_table(m, 0, -5.2, 0.0)
	m.colliders.append(Rect2(-1.6, -5.75, 3.2, 1.1))
	var burner := Props.incense_burner(m, 0, 1.0, -5.2)
	Props.candle_pair(m, -1.15, 1.0, -5.2)
	Props.candle_pair(m, 1.15, 1.0, -5.2)
	# 遗照
	Props.portrait_stand(m, 0, 1.9, -7.8, m.tex_mat("portrait", "1a1a1c", {"roughness": 0.7}))
	m.add_light(Color.html("ff8860"), 0.75, 5.0, 0, 2.2, -6.5, 0.3)
	m.add_light(Color.html("ff9950"), 0.55, 5.0, -2.6, 2.2, -6.2, 0.3, false)
	var photo_cb := func() -> void:
		if not m.G.flags.get("photoSeen", false):
			m.G.flags["photoSeen"] = true
			var photo_drain := 10.0   # 遗照惊吓一次性扣值(文案同源)
			m.change_sanity(-photo_drain)
			m.H.red_flash()
			m.S.sting()
			m.H.show_msg("黑白照片上的人,穿着你的外套,是你的脸。\n照片下方的小字:\"林砚(1996–?)\"。理智 −%d" % int(photo_drain), 5.6)
		else:
			m.H.show_msg("遗照上的\"你\",嘴角似乎比刚才高了一点。")
	m.add_inter(Vector3(0, 1.7, -7.5), "遗照", photo_cb, 2.2)
	# 讣告(墙上)
	m.add_quad(1.4, 1.8, m.tex_mat("obit", "cfd4cf", {"roughness": 0.85}), -3.4, 1.7, -7.80, 0.0, 0.0)
	var obit_cb := func() -> void:
		m.open_modal({
			"title": "讣 告",
			"body": "赵氏三兄弟,皆殁于丁丑年大火。\n\n祭香之礼,先尊后幼:\n长子 赵大河(58)\n次子 赵二河(53)\n幼子 赵小河(41)\n\n——切不可乱了长幼。\n\n(获得线索:上香顺序之谜的答案就藏在这里。)",
			"choices": [{"text": "默记于心", "fn": func() -> void: m.close_modal()}],
		})
	m.add_inter(Vector3(-3.4, 1.6, -7.5), "讣告", obit_cb, 2.2)
	# 纸人 ×3(剪影人形前后双片成薄体积 + 脸谱贴片,双面半透明,不投影)
	var pms: Array = []
	var pm_mat: StandardMaterial3D = m.tex_mat("papergrain", "dcd6c4", {"roughness": 0.85, "transparent": true, "double_sided": true,
		"no_cache": true})   # 随后改 albedo_color;纸人材质不能与其他纸面共享
	pm_mat.albedo_color = Color(0.9, 0.88, 0.8, 0.92)
	var face_mat: StandardMaterial3D = m.tex_mat("paperface", "dcd6c4", {"roughness": 0.85, "no_cache": true})   # 随后开双面
	face_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sheet := Humanoid.paper_man_mesh()
	for p: Array in [[-4.5, -2], [4.5, -2], [-3, 4.5]]:
		var pm := Node3D.new()
		# 前后两张同网格薄片对置成体:侧看是窄腹而非纯刃边;
		# 单面网格靠反向 rotation.y 互补可见,两片都写 0/PI 会因背面剔除丢一侧。
		for side: Array in [[1, 0.0], [-1, PI]]:
			var panel := MeshInstance3D.new()
			panel.mesh = sheet
			panel.material_override = pm_mat
			panel.rotation.y = float(side[1])
			panel.position.z = PM_THICKNESS * 0.5 * float(side[0])
			panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pm.add_child(panel)
		# 脸谱贴片:薄片正面(网格法线/绕序均朝 -Z)经 look_at 后正对玩家,故仍贴 -Z 外侧
		var face := MeshInstance3D.new()
		face.mesh = Humanoid.flat_quad(0.3, 0.3)
		face.material_override = face_mat
		face.position = Vector3(0, 0.75, -PM_THICKNESS * 0.5 - 0.006)
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pm.add_child(face)
		pm.position = Vector3(p[0], 1.0, p[1])
		m.floor_root.add_child(pm)
		pms.append(pm)
	# 香炉谜题
	var wrong_incense := func() -> void:
		m.G.violations += 1
		m.change_sanity(-20.0)
		m.H.red_flash()
		m.S.sting()
		m.shake = 2.2
		# 纸人围拢动画(贴近玩家后退回原位)
		var target: Vector3 = m.player_pos
		target.y = 1.0
		for i in pms.size():
			var pm2: Node3D = pms[i]
			if not is_instance_valid(pm2):
				continue
			var start: Vector3 = pm2.position
			var goal := start.lerp(target, 0.8)
			var tw := pm2.create_tween()
			tw.tween_property(pm2, "position", goal, 1.8)
			tw.tween_interval(0.9)
			tw.tween_property(pm2, "position", start, 0.6)
		m.H.show_msg("香火\"轰\"地窜起绿焰。三个纸人转头望着你,拖着脚步围拢过来——\n又在三步之外齐齐停住,退回了原地。理智 −20", 6.2)
	var solve_incense := func() -> void:
		m.G.flags["incenseSolved"] = true
		# 三炷香点燃:香头转红亮
		var tm: StandardMaterial3D = burner["tip_mat"]
		tm.emission = Color.html("ff5a2a")
		tm.emission_energy_multiplier = 2.2
		m.add_game_minutes(10)
		m.gain_relic("未点燃的香")
		m.after(2.8, func() -> void:
			m.G.candles += 2
			m.H.show_msg("香案暗格里,还压着两支红香烛。+香烛 ×2(按4使用)", 4.6))
		m.after(5.4, func(): m.gain_card("8F"))
		m.after(8.2, func() -> void:
			m.H.show_msg("一个模糊的身影在供桌后作了个揖,散成灰白的光点。\n\"谢谢你,兄弟们等这炷香,等了三十年。\"", 6.2))
		m.H.set_objective("权限卡8F到手。乘电梯前往 8F 档案室")
	var incense_cb := func() -> void:
		if m.G.flags.get("incenseSolved", false):
			m.H.show_msg("香灰还温着。三缕青烟笔直向上。")
			return
		m.open_modal({
			"title": "上 香",
			"body": "香炉里插着三炷未点燃的香,分别刻着:\n「大河」「二河」「小河」。\n\n按什么顺序点燃?(提示:看看墙上的讣告——先尊后幼。)",
			"choices": [
				{"text": "大河 → 二河 → 小河(先尊后幼)", "fn": func() -> void:
					m.close_modal()
					solve_incense.call()},
				{"text": "小河 → 二河 → 大河(由幼至尊)", "fn": func() -> void:
					m.close_modal()
					wrong_incense.call()},
				{"text": "同时点燃三炷香", "fn": func() -> void:
					m.close_modal()
					wrong_incense.call()},
			],
		})
	m.add_inter(Vector3(0, 1.2, -5.0), "香炉(三炷香)", incense_cb, 2.2)
	# 灵堂杂物:供品桌(供品盘)+ 桌下电池
	var off_table := Node3D.new()
	off_table.position = Vector3(5.5, 0, 5.5)
	m.floor_root.add_child(off_table)
	var ot_mat: StandardMaterial3D = m.pmat({"color": Color.html("38301f"), "roughness": 0.7})
	var ot_top := MeshInstance3D.new()
	var otb := BoxMesh.new()
	otb.size = Vector3(0.5, 0.05, 0.5)
	ot_top.mesh = otb
	ot_top.material_override = ot_mat
	ot_top.position = Vector3(0, 0.38, 0)
	off_table.add_child(ot_top)
	for p: Array in [[-0.2, -0.2], [0.2, -0.2], [-0.2, 0.2], [0.2, 0.2]]:
		var ot_leg := MeshInstance3D.new()
		var olc := CylinderMesh.new()
		olc.top_radius = 0.02
		olc.bottom_radius = 0.022
		olc.height = 0.36
		ot_leg.mesh = olc
		ot_leg.material_override = ot_mat
		ot_leg.position = Vector3(p[0], 0.18, p[1])
		off_table.add_child(ot_leg)
	var plate := MeshInstance3D.new()
	var plc := CylinderMesh.new()
	plc.top_radius = 0.16
	plc.bottom_radius = 0.19
	plc.height = 0.03
	plc.radial_segments = 18
	plate.mesh = plc
	plate.material_override = m.pmat({"color": Color.html("d8d2c0"), "roughness": 0.85})
	plate.position = Vector3(0, 0.42, 0)
	off_table.add_child(plate)
	for p: Array in [[-0.06, 0.03], [0.05, 0.05], [0.0, -0.06]]:
		var offer := MeshInstance3D.new()
		var ofm := SphereMesh.new()
		ofm.radius = 0.042
		ofm.height = 0.084
		offer.mesh = ofm
		offer.material_override = m.pmat({"color": Color.html("e2d8be"), "roughness": 0.9})
		offer.position = Vector3(p[0], 0.46, p[1])
		offer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		off_table.add_child(offer)
	m.colliders.append(Rect2(5.25, 5.25, 0.5, 0.5))
	var bat7 := Props.battery_prop(m)
	bat7.rotation.z = PI / 2.0
	bat7.position = Vector3(5.58, 0.045, 5.42)
	m.floor_root.add_child(bat7)
	var bat_cb := func() -> void:
		if m.G.flags.get("bat7F", false):
			return
		m.G.flags["bat7F"] = true
		m.G.batteries += 1
		if is_instance_valid(bat7):
			bat7.free()
		m.H.show_msg("供品桌下滚出一节电池。+1 电池")
	var bat_cond := func() -> bool: return not m.G.flags.get("bat7F", false)
	m.add_inter(Vector3(5.5, 0.6, 5.5), "供品桌下的电池", bat_cb, 2.0, bat_cond)
	m.floor_update = func(_dt: float) -> void:
		for pm: Node3D in pms:
			if is_instance_valid(pm):
				pm.look_at(Vector3(m.camera.global_position.x, pm.position.y, m.camera.global_position.z))
	m.tp_list([
		{"x": 0.0, "z": -3.4, "yaw": 0.0},
		{"x": -3.4, "z": -5.9, "yaw": 0.0},
		{"x": 0.0, "z": -5.9, "yaw": 0.0},
		{"x": 5.5, "z": 4.2, "yaw": PI},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("7F 灵堂。按正确顺序上香(线索:讣告)")
	m.H.show_msg("7F。烛火通明的灵堂。三炷香,三张空椅。\n遗照上的人……你认识。", 5.2)
