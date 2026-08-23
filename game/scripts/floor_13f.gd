extends RefCounted
## 13F 住宅层

static func build(m) -> void:
	m.setup_env(0.16, Color.html("38343c"), Color.html("0a0a10"), 0.04)
	FloorCommon.room_shell(m, 20.0, 16.0)
	FloorCommon.build_elevator(m)
	m.add_light(Color.html("d8c8a8"), 0.4, 10.0, 0, 2.9, 0, 0.05)
	# 走廊两侧的门全是 1304(共享同一木门材质:木纹法线 + 旧清漆)
	var door_mat: StandardMaterial3D = m.tex_mat("door", "5d4530", {
		"normal": m.T.tex.get("door_n"), "normal_scale": 0.5,
		"roughness": 0.55, "clearcoat": 0.45, "cc_rough": 0.35,
	})
	var plq_mat: StandardMaterial3D = m.tex_mat("plaque", "2e2b26", {"roughness": 0.5})
	var door_cb := func() -> void:
		m.H.show_msg("门牌:1304。门锁着。\n门后没有呼吸声,也没有灯光。这不是那扇门。")
	for p: Array in [[-6, -7.83], [-2, -7.83], [2, -7.83], [6, -7.83], [-6, 7.83], [-4, 7.83], [4, 7.83], [6, 7.83]]:
		var x: float = p[0]
		var z: float = p[1]
		Props.door_set(m, x, z, PI if z > 0 else 0.0, door_mat)
		var pl := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.5, 0.3)
		pl.mesh = qm
		pl.material_override = plq_mat
		pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pl.position = Vector3(x + 0.75, 1.8, z + (-0.06 if z > 0 else 0.06))
		if z > 0:
			pl.rotation.y = PI
		m.floor_root.add_child(pl)
		m.add_inter(Vector3(x, 1.2, z + (-0.45 if z > 0 else 0.45)), "1304", door_cb, 1.2)
	# 走廊尽头的 1304(-Z 中央,发光,自发光供辉光拾取)
	var end_mat: StandardMaterial3D = m.tex_mat("door", "5d4530", {
		"normal": m.T.tex.get("door_n"), "normal_scale": 0.5,
		"roughness": 0.5, "clearcoat": 0.5, "cc_rough": 0.35,
		"emission": Color.html("584828"), "emission_energy": 1.6,
	})
	Props.door_set(m, 0, -7.84, 0.0, end_mat, true, 1.2, 2.3)
	var pl2_mat: StandardMaterial3D = m.tex_mat("plaque", "2e2b26", {
		"roughness": 0.5, "emission": Color.html("666044"), "emission_energy": 1.8,
	})
	var pl2 := MeshInstance3D.new()
	var qm2 := QuadMesh.new()
	qm2.size = Vector2(0.7, 0.42)
	pl2.mesh = qm2
	pl2.material_override = pl2_mat
	pl2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pl2.position = Vector3(0, 2.0, -7.77)
	m.floor_root.add_child(pl2)
	m.add_light(Color.html("e8d8a8"), 0.5, 5.0, 0, 2.0, -6.8, 0.08)
	var end_cb := func() -> void:
		if m.G.flags.get("diaryRead", false):
			m.H.show_msg("日记贴身收着。她不在这一层——在 B2,在锅炉旁,在那颗\"心脏\"边上。", 4.6)
			return
		m.open_modal({
			"title": "1304 · 日 记(一)",
			"body": "【第1天】哥,我知道你一定会来。别坐电梯,那个穿保安服的人没有影子。\n\n【第2天】我出不去。走廊昨天是直的,今天是弯的。所有门牌都写着1304——那是我们家的门牌,它为什么要用?因为我一直在想家吗。",
			"choices": [{"text": "翻下一页", "fn": func() -> void:
				m.close_modal()
				m.open_modal({
					"title": "1304 · 日 记(二)",
					"body": "【第3天】这栋楼在吃人。我能听见他们的声音,他们都很冷。有个打麻将的爷爷、有个幼儿园的老师……他们不是坏人,他们只是走不掉。\n\n【第4天】它开始学我说话。学得很像,但它记不住\"砚哥\"两个字。哥,如果你听见\"我\"叫你别的,那不是我。",
					"choices": [{"text": "翻下一页", "fn": func() -> void:
						m.close_modal()
						m.open_modal({
							"title": "1304 · 日 记(三)",
							"body": "【第5天】它说只要我留下,就放你走。别信它,它想让你来换我。\n\n【第6天】我的手有时候不是我的。趁现在还是我在写:十二个去世的人,每样留下了一样东西,集齐十三样,去锅炉房,点亮它们,念出我们的名字。它的力气,是从\"被忘记\"里长出来的。",
							"choices": [{"text": "翻到最后一页", "fn": func() -> void:
								m.close_modal()
								m.open_modal({
									"title": "1304 · 最 后 一 页",
									"body": "【第7天】如果我真的出不去了,请你把十三件东西找齐,在锅炉房把它们点亮,念出我们的名字。这样我们就能走了。哥,对不起。\n\n——最后一页里,夹着一张字条:\n\"哥,它想让你来换我。别信任何叫你'哥'的东西。\n——我只叫你'砚哥'。\"",
									"choices": [{"text": "把日记贴身收好", "fn": func() -> void:
										m.close_modal()
										m.G.flags["diaryRead"] = true
										m.gain_relic("林音的日记")
										m.add_game_minutes(10)
										m.change_sanity(-10.0)
										m.H.red_flash()
										m.get_tree().create_timer(2.6).timeout.connect(func(): m.gain_card("B1"))
										m.get_tree().create_timer(5.2).timeout.connect(func() -> void:
											m.H.show_msg("电梯面板上,一个从未亮过的按钮亮了:B1。\n出口钥匙在老周身上。结局,在锅炉房。", 6.0))
										m.H.set_objective("下行 B1 停车场 —— 出口钥匙在老周身上")}],
								})}],
						})}],
				})}],
		})
	m.add_inter(Vector3(0, 1.2, -7.5), "1304 —— 这扇门在发光", end_cb, 2.4)
	# 13F 消防柜(玻璃内:灭火器 + 水带卷 + 电池,最后一格)
	var fcab := Props.fire_cabinet(m, 8.5, 5.7, PI)
	m.colliders.append(Rect2(8.5 - 0.3, 5.7 - 0.15, 0.6, 0.3))
	var bat_cb := func() -> void:
		if m.G.flags.get("bat13F", false):
			return
		m.G.flags["bat13F"] = true
		m.G.batteries += 1
		if is_instance_valid(fcab["battery"]):
			fcab["battery"].free()
		m.H.show_msg("消防柜的玻璃碎了,里面躺着一节电池。+1 电池")
	var bat_cond := func() -> bool: return not m.G.flags.get("bat13F", false)
	m.add_inter(Vector3(8.5, 0.4, 5.5), "楼道消防柜里的电池", bat_cb, 2.0, bat_cond)
	# 发光门旁:一本上锁的日记(纯氛围,呼应 texgen 的 diary 贴图)
	Props.diary_prop(m, -1.5, -7.5, 0.0)
	m.add_inter(Vector3(-1.5, 0.2, -7.4), "音的日记", func() -> void:
		m.H.show_msg("暗红封皮上写着一个\"音\"字。上了小铜锁,打不开。", 3.6), 1.2)
	m.floor_update = func(_dt: float) -> void:
		pass
	m.tp_list([
		{"x": 0.0, "z": -6.2, "yaw": 0.0},
		{"x": 8.5, "z": 4.2, "yaw": PI},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("13F。走廊尽头,那扇门在等你。")
	m.H.show_msg("13F。整层的门牌都是 1304。\n只有走廊尽头那扇,门缝里透着暖光。", 5.6)
	m.S.music_box()
