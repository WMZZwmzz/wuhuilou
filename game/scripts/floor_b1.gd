extends RefCounted
## B1 停车场(管理员追逐战)

static func build(m) -> void:
	m.setup_env(0.1, Color.html("2a3238"), Color.html("06080a"), 0.06)
	FloorCommon.room_shell(m, 24.0, 16.0)
	FloorCommon.build_elevator(m)
	m.add_light(Color.html("9ab0c0"), 0.4, 14.0, 0, 2.9, -1.0, 0.2)
	# 立柱 ×4(追逐掩体)
	var col_mat: StandardMaterial3D = m.pmat({
		"tex": m.T.tex.get("wall"), "normal": m.T.tex.get("wall_n"),
		"uv1": Vector3(0.4, 2.0, 1.0), "roughness": 0.9, "normal_scale": 0.6,
		"color": Color.html("6a6e68") if m.T.tex.get("wall") == null else Color(0.95, 0.95, 0.95),
	})
	for p: Array in [[-3.5, -3.0], [3.5, -3.0], [-3.5, 3.0], [3.5, 3.0]]:
		m.add_box(0.55, 3.2, 0.55, col_mat, p[0], 1.6, p[1])
		m.colliders.append(Rect2(p[0] - 0.28, p[1] - 0.28, 0.56, 0.56))
	# 无牌车辆 ×4(两排)
	var car_lights: Array = []
	var car_poses: Array = [[-7.0, -5.0, 0.0], [7.0, -5.0, 0.0], [-7.0, 4.0, 0.0], [7.0, 4.0, 0.0]]
	for i in car_poses.size():
		var p: Array = car_poses[i]
		Props.sedan_car(m, p[0], p[1], p[2], ["3a4048", "4a3a34", "33413c", "3c3c46"][i])
		m.colliders.append(Rect2(p[0] - 0.95, p[1] - 2.15, 1.9, 4.3))
		var cl: OmniLight3D = m.add_light(Color.html("e8e2c8"), 0.7, 7.0, p[0], 0.9, p[1] + (1.9 if p[2] < PI else -1.9), 0.0, false)
		# 随机亮灭的装饰灯:平时整灯 visible=false——不可见灯光不进光列表也不占阴影图集,
		# 比 energy=0 更彻底(能量为零仍参与每帧阴影 pass 渲染)
		cl.visible = false
		car_lights.append(cl)
	# 车内电池(西排前车,车窗摇下一半)
	var batB1 := Props.battery_prop(m)
	batB1.rotation.z = PI / 2.0
	batB1.position = Vector3(-7.0, 1.0, 3.2)
	m.floor_root.add_child(batB1)
	var bat_cb := func() -> void:
		m.G.flags["batB1"] = true
		m.G.batteries += 1
		if is_instance_valid(batB1):
			batB1.free()
		m.H.show_msg("那辆车的车窗摇下一半,杯架里卡着一节电池。+1 电池", 4.2)
	var bat_cond := func() -> bool: return not m.G.flags.get("batB1", false)
	m.add_inter(Vector3(-7.0, 1.0, 3.0), "车窗里的电池", bat_cb, 2.0, bat_cond)
	# 值班亭(+X 前角):对讲机(制造声响,引开老周)
	m.add_wall(9.6, 4.4, 0.3, 3.0)
	m.add_wall(7.9, 5.9, 3.8, 0.3)
	m.add_box(1.2, 0.9, 0.5, m.pmat({"color": Color.html("4a4438"), "roughness": 0.8}), 8.6, 0.45, 4.8)
	m.colliders.append(Rect2(8.0, 4.55, 1.2, 0.5))
	m.add_light(Color.html("c8a86a"), 0.35, 4.0, 8.6, 2.2, 4.8, 0.1, false)
	# 老周:保安服 + 保安帽 + 腰带 + 大串钥匙;全部件不投影(无影子)
	var fig := Props.human_figure(m, {
		"pose": "stand", "scale": 1.03, "face": "human", "no_shadow": true, "uniform": true,
		"cap_hex": "1e2430",
		"top_hex": "2c3444", "bottom_hex": "222a38", "skin_hex": "8a7a62", "hair_hex": "3a342c",
	})
	var zhou: Node3D = fig["root"]
	# 腰带 + 右胯钥匙串(同样无影)
	var belt := MeshInstance3D.new()
	var btm := TorusMesh.new()
	btm.inner_radius = 0.138
	btm.outer_radius = 0.158
	belt.mesh = btm
	belt.material_override = m.pmat({"color": Color.html("1a1e26"), "roughness": 0.8})
	belt.position = Vector3(0, 1.02, 0)
	belt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zhou.add_child(belt)
	var keys := MeshInstance3D.new()
	var kc := TorusMesh.new()
	kc.inner_radius = 0.05
	kc.outer_radius = 0.09
	keys.mesh = kc
	keys.material_override = m.pmat({"color": Color.html("c8b46a"), "metallic": 0.7, "roughness": 0.4})
	keys.position = Vector3(0.24, 0.93, 0.05)
	keys.rotation.x = PI / 2.0
	keys.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zhou.add_child(keys)
	zhou.position = Vector3(0, 0, 5.0)
	m.floor_root.add_child(zhou)
	var state := {
		"mode": "patrol", "wp": 0, "invest_t": 0.0, "lost_t": 0.0,
		"jingle_t": 0.0, "light_t": 4.0, "caught_msg": 0,
	}
	var wps: Array = [Vector3(0, 0, 5.0), Vector3(-7, 0, 0), Vector3(0, 0, -5), Vector3(7, 0, 0)]
	const NOISE_POINT := Vector3(-9.2, 0, -7.6)
	# 对讲机:制造声响引开老周(追/巡都会被打断,转为查噪)
	var talk_cb := func() -> void:
		if m.G.flags.get("keysTaken", false):
			m.H.show_msg("对讲机只剩沙沙的电流声。值班亭空了。")
			return
		state["mode"] = "invest"
		state["invest_t"] = 10.0
		m.S.play_buf("ding", 1.2, 0.7)
		m.H.show_msg("你按下对讲机的警报键——西角的卷帘门\"哗啦\"响了一声。\n钥匙串的声音,朝那边去了。", 4.6)
	m.add_inter(Vector3(8.6, 1.1, 4.8), "值班亭对讲机", talk_cb, 2.0)
	# 老周腰间的钥匙串:仅\"查噪背身\"窗口可取
	var key_cond := func() -> bool:
		return state["mode"] == "invest" and not m.G.flags.get("keysTaken", false)
	var keys_cb := func() -> void:
		m.G.flags["keysTaken"] = true
		m.G.flags["hasExitKey"] = true
		m.add_game_minutes(10)
		m.gain_relic("一大串钥匙")
		m.S.click()
		m.after(2.6, func(): m.gain_card("B2"))
		m.after(5.6, func() -> void:
			m.change_sanity(2.0)
			m.H.show_msg("老周没有回头,只是站定了,像卸下千斤重担:\n\"拿去吧……这差事,我早就想卸了。\"\n\"那把旧的,是 1304 的门。我找了一辈子,没能打开它。\"理智 +2", 7.0))
		m.H.set_objective("出口钥匙到手。乘电梯下行 B2 锅炉房 —— 结束这一切")
	m.add_inter(Vector3(-8.6, 1.0, -6.9), "老周腰间的钥匙串(背影)", keys_cb, 2.2, key_cond)
	# 住户须知(电梯口左侧)
	var paper_mat: StandardMaterial3D = m.tex_mat("paper", "d8cfb4", {"roughness": 0.9})
	m.add_quad(1.1, 1.4, paper_mat, -2.4, 1.7, 7.6, PI, 0.0)
	m.add_inter(Vector3(-2.4, 1.5, 7.3), "《住户须知》", func() -> void:
		m.open_modal({
			"title": "B1 停车场 · 住户须知",
			"body": "一、本区车位已满,无牌车辆请勿清点。\n\n二、听见钥匙声,请立即熄灯蹲于车后。\n\n三、管理员巡逻期间,请勿奔跑。",
			"choices": [{"text": "记住了", "fn": func() -> void: m.close_modal()}],
		}), 2.0)
	# 楼层逻辑:老周巡逻/查噪/追逐 AI + 车灯随机亮灭 + 钥匙串预警音
	m.floor_update = func(dt: float) -> void:
		state["light_t"] = state["light_t"] - dt
		if state["light_t"] <= 0.0:
			state["light_t"] = 5.0 + randf() * 5.0
			var li := randi() % car_lights.size()
			for i in car_lights.size():
				var cl: OmniLight3D = car_lights[i]
				if is_instance_valid(cl):
					cl.visible = (i == li)   # 明灭切换用整灯 visible,能量恒 1.4
			if randf() < 0.4:
				m.S.click()
		if not is_instance_valid(zhou):
			return
		if m.G.flags.get("keysTaken", false):
			zhou.position = zhou.position.lerp(Vector3(-9.2, 0, -7.6), clampf(dt * 2.0, 0.0, 1.0))
			zhou.look_at(Vector3(-11.5, 0, -9.0))
			return
		var to_p: Vector3 = m.player_pos - zhou.position
		to_p.y = 0.0
		var d := to_p.length()
		# 钥匙串预警音:越近越密
		state["jingle_t"] = state["jingle_t"] - dt
		if state["jingle_t"] <= 0.0 and d < 12.0:
			state["jingle_t"] = clampf(d / 6.0, 0.35, 1.6)
			m.S.play_buf("click", clampf(2.2 - d / 8.0, 0.5, 1.6), 1.5)
		match state["mode"]:
			"patrol":
				var wp: Vector3 = wps[state["wp"]]
				var dir: Vector3 = wp - zhou.position
				dir.y = 0.0
				if dir.length() < 0.3:
					state["wp"] = (state["wp"] + 1) % wps.size()
				else:
					zhou.position += dir.normalized() * 1.5 * dt
					zhou.look_at(Vector3(wp.x, 0, wp.z))
				var fwd := -zhou.global_transform.basis.z
				fwd.y = 0.0
				var seen: bool = d < 9.0 and m.G.running
				if not seen and d < 4.5 and not m.G.crouching:
					seen = true
				if seen and fwd.length() > 0.01 and fwd.normalized().dot(to_p.normalized()) > 0.2:
					state["mode"] = "chase"
					state["lost_t"] = 0.0
					m.S.sting()
					m.H.show_msg("钥匙串的声音停了——他看见你了。\n跑!", 3.4)
			"chase":
				if d > 0.1:
					zhou.position += to_p.normalized() * 4.5 * dt
					zhou.look_at(Vector3(m.player_pos.x, 0, m.player_pos.z))
				if m.G.crouching and d > 3.5:
					state["lost_t"] = state["lost_t"] + dt
				else:
					state["lost_t"] = 0.0
				if state["lost_t"] > 2.5:
					state["mode"] = "patrol"
					state["wp"] = 0
					m.H.show_msg("钥匙串的声音渐渐远了。他没找到你。", 3.4)
				elif d < 1.15:
					state["mode"] = "patrol"
					state["wp"] = 0
					zhou.position = wps[0]
					var caught_drain := 25.0   # 被抓一次性扣值(数值平衡表"接触性事件"档;文案同源)
					m.change_sanity(-caught_drain)
					m.H.red_flash()
					m.S.sting()
					m.shake = 2.4
					m.player_pos = Vector3(0, 0, 7.5)
					m.H.show_msg("冰凉的手攥住你的手腕,把你\"请\"回了电梯厅。\n\"楼里不许跑。\"理智 −%d" % int(caught_drain), 5.4)
			"invest":
				var dirn: Vector3 = NOISE_POINT - zhou.position
				dirn.y = 0.0
				if dirn.length() > 0.4:
					zhou.position += dirn.normalized() * 2.2 * dt
					zhou.look_at(Vector3(NOISE_POINT.x, 0, NOISE_POINT.z))
				else:
					zhou.look_at(Vector3(-11.5, 0, -9.5))
					state["invest_t"] = state["invest_t"] - dt
					if state["invest_t"] <= 0.0:
						state["mode"] = "patrol"
		# 巡逻/追逐时的步行起伏(其余状态站稳)
		if state["mode"] == "patrol" or state["mode"] == "chase":
			zhou.position.y = abs(sin(Time.get_ticks_msec() * 0.011)) * 0.02
		else:
			zhou.position.y = 0.0
	m.tp_list([
		{"x": 8.6, "z": 3.4, "yaw": PI},
		{"x": -8.6, "z": -5.4, "yaw": 0.0},
		{"x": -7.0, "z": 1.8, "yaw": 0.0},
		{"x": 0.0, "z": -6.5, "yaw": 0.0},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("B1 停车场。用值班亭的对讲机引开老周,取他腰间的钥匙串")
	m.H.show_msg("B1。空旷的车库里,钥匙串的哗啦声来回巡逻。\n他停在哪里,光就跟到哪里。", 5.6)
