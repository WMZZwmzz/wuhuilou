extends RefCounted
## 10F 宴会厅

static func build(m) -> void:
	m.setup_env(0.12, Color.html("38262a"), Color.html("0a0508"), 0.05)
	FloorCommon.room_shell(m, 20.0, 16.0)
	FloorCommon.build_elevator(m)
	m.add_light(Color.html("e8b088"), 0.45, 12.0, 0, 2.9, 0, 0.15)
	m.add_light(Color.html("c86a58"), 0.35, 8.0, 0, 2.4, -3.5, 0.2, false)
	# 长桌(中央,东西向)+ 桌布 + 腐烂菜肴
	m.add_box(11.0, 0.1, 1.6, m.pmat({"color": Color.html("3c2a20"), "roughness": 0.6}), 0, 0.78, 0)
	m.colliders.append(Rect2(-5.5, -0.8, 11.0, 1.6))
	var cloth: StandardMaterial3D = m.pmat({"color": Color.html("6a5450"), "roughness": 0.95})
	m.add_box(11.2, 0.72, 1.8, cloth, 0, 0.38, 0, false)
	for p: Array in [[-4.2, 0], [-2.5, 0], [-0.8, 0], [0.9, 0], [2.6, 0], [4.3, 0]]:
		var plate := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.16
		pc.bottom_radius = 0.18
		pc.height = 0.025
		plate.mesh = pc
		plate.material_override = m.pmat({"color": Color.html("b8a890"), "roughness": 0.6, "clearcoat": 0.3})
		plate.position = Vector3(p[0], 0.84, 0)
		m.floor_root.add_child(plate)
		var food := MeshInstance3D.new()
		var fc := SphereMesh.new()
		fc.radius = 0.07
		fc.height = 0.06
		food.mesh = fc
		food.material_override = m.pmat({"color": Color.html("4a4228"), "roughness": 0.95})
		food.position = Vector3(p[0], 0.87, 0)
		food.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.floor_root.add_child(food)
	# 席位:两侧各 6(坐 11 个假人 + 1 空位)+ 主位 1(许文远,立于 -Z 端)
	var dummies: Array = []
	var tag_mat: StandardMaterial3D = m.pmat({"color": Color.html("d8cfb4"), "roughness": 0.9})
	var seat_x: Array = [-4.2, -2.5, -0.8, 0.9, 2.6, 4.3]
	var empty_side_idx := 4   # 南排第 5 席:没有假人、没有胸牌的"不存在的客人"之位
	for i in seat_x.size():
		var x: float = seat_x[i]
		# 北排(z=-1.3,面朝南对桌)6 席全坐(merged=true:静态肢体并成单网格,A4)
		Props.chair(m, x, -1.3, 0.0)
		var dn := Props.banquet_dummy(m, x, -1.3, PI, "46384a" if i % 2 == 0 else "3a3048", false, true)
		dummies.append(dn)
		# 南排(z=1.3,面朝北对桌)5 席 + 1 空位(空位有椅无假人)
		Props.chair(m, x, 1.3, PI)
		if i != empty_side_idx:
			var ds := Props.banquet_dummy(m, x, 1.3, 0.0, "3a3048" if i % 2 == 0 else "46384a", false, true)
			dummies.append(ds)
			var tag := MeshInstance3D.new()
			var tq := QuadMesh.new()
			tq.size = Vector2(0.16, 0.1)
			tag.mesh = tq
			tag.material_override = tag_mat
			tag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tag.position = Vector3(x, 0.84, 0.9)
			tag.rotation.y = PI
			m.floor_root.add_child(tag)
	# 主位:许文远(立姿假人,西装色,面朝长桌;身后主位椅)
	Props.chair(m, 0, -3.2, 0.0)
	Props.banquet_dummy(m, 0, -3.2, PI, "1e2430", true, true)
	m.colliders.append(Rect2(-0.25, -3.5, 0.5, 0.6))
	m.add_light(Color.html("e8c8a0"), 0.4, 4.5, 0, 2.2, -3.2, 0.1, false)
	# 席位谜题
	var solve_seat := func() -> void:
		m.G.flags["seat10F"] = true
		m.add_game_minutes(10)
		for d: Node3D in dummies:
			if is_instance_valid(d):
				var tw := d.create_tween()
				tw.tween_property(d, "rotation:x", -0.35, 1.4)
		m.H.show_msg("满桌假人同时向你低头。灯,一盏一盏暖了起来——\n宴会厅变成了婚礼现场,只差一步。", 6.0)
		m.after(4.4, func() -> void:
			m.gain_relic("烫金请柬")
			m.change_sanity(2.0)
			m.H.show_msg("主位的司仪眼眶发红:\"就差这一桌,我的婚礼……就差这一桌。\"\n\"她也在火里。我们没办成的,是两个人的一辈子。\"\n他双手把一张烫金请柬推到你面前。理智 +2", 7.2))
		m.after(9.0, func(): m.gain_card("11F"))
		m.H.set_objective("权限卡11F到手。乘电梯前往 11F 祭坛")
	var seat_cb := func() -> void:
		if m.G.flags.get("seat10F", false):
			m.H.show_msg("喜宴散了。长桌上只剩那张请柬的位置空着。")
			return
		m.open_modal({
			"title": "入 席",
			"body": "长桌两侧各六席,主位一席,共十三席。\n假人坐了十一位,每位胸前都别着写有名字的胸牌;\n主位立着穿西装的司仪,对着空无一人的新娘位说话。\n\n只有南排一席——没有假人,没有胸牌,餐具却摆得整整齐齐。\n(\"不存在的客人\",坐的是活人的位置。)",
			"choices": [
				{"text": "坐到没有胸牌的空位", "fn": func() -> void:
					m.close_modal()
					solve_seat.call()},
				{"text": "坐到主位", "fn": func() -> void:
					m.close_modal()
					m.change_sanity(-m.G.NUM["violation"])
					m.H.red_flash()
					m.S.sting()
					m.shake = 2.0
					m.H.show_msg("你刚碰到主位的椅背,司仪的手就按了上来——冰得像铁。\n\"这个位置,不是给活人留的。\"理智 −%d" % int(m.G.NUM["violation"]), 5.6)},
				{"text": "挤到假人旁边坐下", "fn": func() -> void:
					m.close_modal()
					m.change_sanity(-m.G.NUM["violation"])
					m.H.red_flash()
					m.S.sting()
					for d: Node3D in dummies:
						if is_instance_valid(d):
							d.look_at(Vector3(m.player_pos.x, d.position.y, m.player_pos.z))
					m.H.show_msg("满桌假人齐刷刷转头,胸牌哗啦作响。\n旁边的\"宾客\"凑近你,腐臭的呼吸擦过耳边。理智 −%d" % int(m.G.NUM["violation"]), 5.6)},
			],
		})
	m.add_inter(Vector3(float(seat_x[empty_side_idx]), 1.0, 1.3), "没有胸牌的空位", seat_cb, 2.0)
	# 主桌上的电池(数值平衡表:9F–10F ×2 之第二枚)
	var bat10 := Props.battery_prop(m)
	bat10.rotation.z = PI / 2.0
	bat10.position = Vector3(4.3, 0.86, 0.25)
	m.floor_root.add_child(bat10)
	var bat_cb := func() -> void:
		m.G.flags["bat10F"] = true
		m.G.batteries += 1
		if is_instance_valid(bat10):
			bat10.free()
		m.H.show_msg("腐坏的果盘底下压着一节电池。+1 电池", 4.2)
	var bat_cond := func() -> bool: return not m.G.flags.get("bat10F", false)
	m.add_inter(Vector3(4.3, 0.9, 0.25), "果盘下的电池", bat_cb, 1.8, bat_cond)
	# 住户须知(电梯口)
	var paper_mat: StandardMaterial3D = m.tex_mat("paper", "d8cfb4", {"roughness": 0.9})
	m.add_quad(1.1, 1.4, paper_mat, -2.4, 1.7, 7.6, PI, 0.0)
	m.add_inter(Vector3(-2.4, 1.5, 7.3), "《住户须知》", func() -> void:
		m.open_modal({
			"title": "10F 宴会厅 · 住户须知",
			"body": "一、入席请对号入座,空位留给未到的客人。\n\n二、席间请勿与任何人对视,转头的不是宾客。\n\n三、喜宴未散,请勿提前离席。",
			"choices": [{"text": "记住了", "fn": func() -> void: m.close_modal()}],
		}), 2.0)
	# 楼层逻辑:假人缓慢"呼吸"式起伏 + 偶发瓷器轻响
	var state := {"clink_t": 8.0}
	m.floor_update = func(dt: float) -> void:
		state["clink_t"] = state["clink_t"] - dt
		if state["clink_t"] <= 0.0:
			state["clink_t"] = 10.0 + randf() * 10.0
			# 瓷器轻响:从随便一位"宾客"的席位传来
			var ds: Array = dummies.filter(func(d: Node3D) -> bool: return is_instance_valid(d))
			if not ds.is_empty():
				var d0: Node3D = ds[randi() % ds.size()]
				m.S.play_at("click", d0.position + Vector3(0, 1.1, 0), 0.5, randf_range(0.8, 1.2))
			else:
				m.S.play_buf("click", 0.4, randf_range(0.8, 1.2))
		if not m.G.flags.get("seat10F", false):
			for i in dummies.size():
				# 呼吸微动统一走驱动(幅度/频率/逐体相位与旧写法等价)
				HumanoidAnim.breath_root(dummies[i], 0.008, 0.9 / TAU, i * 1.3 / TAU)
	m.tp_list([
		{"x": float(seat_x[empty_side_idx]), "z": 2.8, "yaw": 0.0},
		{"x": 0.0, "z": -4.8, "yaw": 0.0},
		{"x": 4.3, "z": 0.9, "yaw": 0.0},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("10F 宴会厅。数清席位,坐上\"不存在的客人\"的位置")
	m.H.show_msg("10F。甜腻的腐臭里,一桌喜宴停了三十年。", 5.2)
