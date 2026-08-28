extends RefCounted
## 2F 麻将馆

static func build(m) -> void:
	m.setup_env(0.05, Color.html("1a2030"), Color.html("05070c"), 0.06)
	FloorCommon.room_shell(m, 20.0, 16.0)
	FloorCommon.build_elevator(m)
	# 麻将桌(中央)
	m.add_box(2.2, 0.1, 2.2, m.pmat({"color": Color.html("3a2c1c"), "roughness": 0.5, "clearcoat": 0.3}), 0, 0.78, 0, false)
	var felt_mat: StandardMaterial3D = m.tex_mat("mj", "2d4a33", {"roughness": 0.95})
	m.add_floor_plane(2.0, 2.0, felt_mat, 0, 0.84, 0, true)
	for p: Array in [[-0.9, -0.9], [0.9, -0.9], [-0.9, 0.9], [0.9, 0.9]]:
		m.add_box(0.12, 0.78, 0.12, m.pmat({"color": Color.html("2c2216")}), p[0], 0.39, p[1], false)
	m.add_box(0.9, 0.5, 0.9, m.pmat({"color": Color.html("2c2216")}), 0, 0.25, 0)
	# 桌裙(绒布垂沿)+ 两处麻将牌堆
	var skirt_mat: StandardMaterial3D = m.pmat({"color": Color.html("1e3327"), "roughness": 0.95})
	for s: Array in [[0.0, 1.095, 2.26, 0.03], [0.0, -1.095, 2.26, 0.03], [1.095, 0.0, 0.03, 2.26], [-1.095, 0.0, 0.03, 2.26]]:
		m.add_box(s[2], 0.48, s[3], skirt_mat, s[0], 0.5, s[1], false)
	Props.mahjong_heap(m, m.floor_root, 0.72, 0.85, -0.5)
	Props.mahjong_heap(m, m.floor_root, -0.7, 0.85, -0.62)
	# 陈守财:背对入口(-Z 方向坐,面朝北),玩家从南侧电梯来看到的是背影
	# 参数化人形:老年驼背 + 长衫 + 无脸白板(平时藏在脑后,转头后正对玩家)
	var fig := Props.human_figure(m, {
		"pose": "sit", "hunch": 0.55, "robe": true,
		"face": "blank", "hair": "short",
		"top_hex": "2e3440", "skin_hex": "8a7a62", "hair_hex": "3a342c",
	})
	var man: Node3D = fig["root"]
	var head: Node3D = fig["head"]
	# 右手捏着一张立牌(前臂微抬)
	fig["fore_r"].rotation.x = 1.45
	var tile := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.05, 0.024, 0.07)
	tile.mesh = tb
	tile.material_override = m.pmat({"color": Color.html("ede6d2"), "roughness": 0.45})
	tile.rotation.z = 0.35
	tile.position = Vector3(0, -0.365, -0.005)
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fig["fore_r"].add_child(tile)
	# 坐椅:座板 + 四腿 + 靠背板 + 顶帽(靠背在身后 +Z 侧)
	var wood: StandardMaterial3D = m.pmat({"color": Color.html("40301e"), "roughness": 0.72})
	var seat := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.5, 0.05, 0.48)
	seat.mesh = sb
	seat.material_override = wood
	seat.position = Vector3(0, 0.44, 0)
	man.add_child(seat)
	for p: Array in [[-0.21, -0.2], [0.21, -0.2], [-0.21, 0.2], [0.21, 0.2]]:
		var lg := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.05, 0.42, 0.05)
		lg.mesh = lb
		lg.material_override = wood
		lg.position = Vector3(p[0], 0.21, p[1])
		man.add_child(lg)
	var chair_b := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.5, 0.7, 0.08)
	chair_b.mesh = cb
	chair_b.material_override = wood
	chair_b.position = Vector3(0, 0.55, 0.32)
	man.add_child(chair_b)
	var cap := MeshInstance3D.new()
	var cmb := BoxMesh.new()
	cmb.size = Vector3(0.54, 0.06, 0.1)
	cap.mesh = cmb
	cap.material_override = wood
	cap.position = Vector3(0, 0.93, 0.32)
	man.add_child(cap)
	man.position = Vector3(0, 0, -1.5)
	man.rotation.y = 0.0
	m.floor_root.add_child(man)
	var state := {"stay": 0.0, "turned": false}
	# 麻将谜题
	var solve_mj := func() -> void:
		if m.G.flags.get("mjSolved", false):
			return
		m.G.flags["mjSolved"] = true
		m.add_game_minutes(10)
		m.gain_relic("缺白板的麻将")
		m.after(2.8, func(): m.gain_card("3F"))
		m.after(6.4, func(): m.H.show_msg("老人的声音在背后响起,很轻:\"……替我,摸一把。\"", 4.6))
		m.after(8.0, func() -> void:
			if is_instance_valid(man):
				man.visible = false)
		m.H.set_objective("乘电梯前往 3F 幼儿园")
	var old_man_turn := func(violate: bool) -> void:
		if state["turned"]:
			return
		state["turned"] = true
		m.G.violations += 1
		m.change_sanity(-m.G.NUM["violation"])
		m.H.red_flash()
		m.S.sting()
		m.shake = 2.0
		m.H.show_msg("老人的头,缓缓地、缓缓地转了过来。\n一直转过了肩膀。那里没有五官,只有一张白板般的脸。理智 −%d" % int(m.G.NUM["violation"]), 6.0)
		m.after(0.6, func() -> void:
			if is_instance_valid(man):
				man.rotation.y = PI)
		m.after(4.2, func() -> void:
			if is_instance_valid(man):
				man.visible = false
			m.H.show_msg("你跌坐在地。再抬头时,桌边的椅子空了。", 4.2)
			if violate and not m.G.flags.get("mjSolved", false):
				m.after(3.2, func(): solve_mj.call()))
	var mj_cb := func() -> void:
		m.open_modal({
			"title": "麻 将 桌",
			"body": "桌上的麻将牌自己排成了两个字:\"救救我\"。\n牌桌对面,老人背对你坐着,手里摸着一张牌,一动不动。\n桌角压着一副旧麻将和一个卡片套。\n\n(楼道里安静得能听见你的心跳。跑动和喧哗都会惊动这里的\"东西\"。)",
			"choices": [
				{"text": "出声问他:\"老爷爷,你还好吗?\"", "fn": func() -> void:
					m.close_modal()
					old_man_turn.call(true)},
				{"text": "放轻呼吸,悄悄取走桌角的旧麻将和卡片套", "fn": func() -> void:
					m.close_modal()
					solve_mj.call()},
				{"text": "掀翻牌桌", "fn": func() -> void:
					m.close_modal()
					old_man_turn.call(true)},
			],
		})
	var mj_cond := func() -> bool: return not m.G.flags.get("mjSolved", false)
	m.add_inter(Vector3(0, 1.0, -0.6), "麻将桌", mj_cb, 2.3, mj_cond)
	# 杂物间(-X 后角,门口 x -8.2~-6.5 @ z=-5.5)
	m.add_wall(-6.5, -6.75, 0.3, 2.5)
	m.add_wall(-9.1, -5.5, 1.8, 0.3)
	Props.shelf_unit(m, -8.6, -6.4, 0.0)
	m.colliders.append(Rect2(-8.6 - 0.9, -6.4 - 0.35, 1.8, 0.7))
	var bat2 := Props.battery_prop(m)
	bat2.rotation.z = PI / 2.0
	bat2.position = Vector3(-8.85, 0.95, -6.4)
	m.floor_root.add_child(bat2)
	var shelf_cb := func() -> void:
		m.G.flags["bat2F"] = true
		m.G.batteries += 1
		m.H.show_msg("旧货架上摸到一节电池。+1 电池", 4.2)
		if is_instance_valid(bat2):
			bat2.free()
	var shelf_cond := func() -> bool: return not m.G.flags.get("bat2F", false)
	m.add_inter(Vector3(-8.5, 0.8, -6.2), "杂物间货架", shelf_cb, 2.0, shelf_cond)
	# 窗台 + 窗框(窗组整体上移,避开墙腰线)
	m.add_box(1.2, 0.08, 0.5, m.pmat({"color": Color.html("3a3c40")}), -9.6, 1.1, 2)
	Props.window_set(m, -9.83, 1.95, 2, PI / 2.0, 1.0, 1.4)
	var win_cb := func() -> void:
		m.H.show_msg("窗外的城市灯火通明。可玻璃反光里,你身后的房间——坐着两桌人。")
	m.add_inter(Vector3(-9.4, 1.2, 2), "窗户", win_cb, 2.0)
	# 楼层逻辑:麻将碰撞环境音 + 奔跑噪音 / 停留过久 → 老人转头
	# (麻将声是入场文案"麻将声……在黑暗里响着"的落地产物;解谜后仍在响)
	var mj_t := 2.5
	m.floor_update = func(dt: float) -> void:
		mj_t -= dt
		if mj_t <= 0.0:
			mj_t = 3.0 + randf() * 6.0
			m.S.play_at("mahjong", Vector3(0, 1.0, -0.6), randf_range(0.5, 0.85), randf_range(0.88, 1.12))
		if m.G.flags.get("mjSolved", false) or state["turned"]:
			return
		var d := Vector2(m.player_pos.x, m.player_pos.z + 1.5).length()
		if d < 8.0 and m.G.running:
			old_man_turn.call(false)
			return
		if d < 3.2:
			state["stay"] += dt
			if state["stay"] > 9.0:
				old_man_turn.call(false)
		if is_instance_valid(head):
			head.rotation.z = sin(Time.get_ticks_msec() * 0.0012) * 0.05
	m.tp_list([
		{"x": 0.0, "z": 1.2, "yaw": 0.0},
		{"x": -8.5, "z": -4.9, "yaw": 0.0},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("黑暗的麻将馆。找到通往上层的权限卡(小心桌边的老人)")
	m.H.show_msg("2F。一片漆黑。麻将声……在黑暗里响着。", 5.0)
