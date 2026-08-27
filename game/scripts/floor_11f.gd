extends RefCounted
## 11F 邪教祭坛

static func build(m) -> void:
	m.setup_env(0.09, Color.html("2c2434"), Color.html("070609"), 0.06)
	FloorCommon.room_shell(m, 20.0, 16.0)
	FloorCommon.build_elevator(m)
	# 壁画墙(-Z):整栋楼 + 红窗(世界观暗示)
	var mural_mat: StandardMaterial3D = m.tex_mat("mural", "241a1e", {
		"roughness": 0.9, "emission": Color.html("3a1c22"), "emission_energy": 0.5,
	})
	m.add_quad(4.4, 4.4, mural_mat, 0, 1.9, -7.82, 0.0, 0.0)
	m.add_inter(Vector3(0, 1.8, -7.5), "壁画(画着大楼)", func() -> void:
		m.open_modal({
			"title": "壁 画",
			"body": "炭笔画的正是这栋楼,十三层,一格一格的窗。\n只有一扇窗被反复描红——13 层,东数第四扇。\n1304。\n\n画的角落写着一行小字:\"每年今夜 · 无回。\"",
			"choices": [{"text": "退后一步", "fn": func() -> void: m.close_modal()}],
		}), 2.2)
	# 祭坛(中央偏北)+ 微光
	Props.altar_stone(m, 0, -5.0, 0.0)
	m.colliders.append(Rect2(-1.0, -5.55, 2.0, 1.15))
	var altar_light: OmniLight3D = m.add_light(Color.html("b898c8"), 0.6, 6.0, 0, 1.6, -5.0, 0.12)
	# 蒲团 ×2(祭坛前)
	for x: float in [-1.4, 1.4]:
		var cushion := MeshInstance3D.new()
		var cz := CylinderMesh.new()
		cz.top_radius = 0.32
		cz.bottom_radius = 0.34
		cz.height = 0.09
		cushion.mesh = cz
		cushion.material_override = m.pmat({"color": Color.html("4a3038"), "roughness": 0.95})
		cushion.position = Vector3(x, 0.045, -3.9)
		m.floor_root.add_child(cushion)
	# 献祭谜题
	var do_sacrifice := func(gift: String) -> void:
		m.G.flags["sacrifice11F"] = true
		m.add_game_minutes(10)
		m.open_modal({
			"title": "接 受 献 祭",
			"body": "你把" + gift + "放上祭坛。它无声地沉进石面。\n\n坛心浮起一串念珠,散着微光。一个身影在光里显现:\n\"那东西是怨念捏的,没有名字。要它散,就得有人记住每一个死者的名字,一个不落地念出来。\"\n\"我念到一半,火来了。\"",
			"choices": [{"text": "接过念珠", "fn": func() -> void:
				m.close_modal()
				m.gain_relic("一串念珠")
				m.after(2.8, func(): m.gain_card("12F"))
				m.after(5.8, func() -> void:
					m.change_sanity(2.0)
					m.H.show_msg("\"封印没完成,是我的债。现在,轮到你了。\"\n王桂枝的身影拜了一拜,散作点点微光。理智 +2", 6.2))
				m.H.set_objective("权限卡12F到手。乘电梯前往 12F 天台")}],
		})
	var altar_cb := func() -> void:
		if m.G.flags.get("sacrifice11F", false):
			m.H.show_msg("坛面已恢复了冰凉。掌心的念珠,还带着一点温度。")
			return
		var ch: Array = [
			{"text": "献上妹妹的照片(情感锚点,安全区回复减半)", "fn": func() -> void:
				m.close_modal()
				m.G.flags["photoGiven"] = true
				m.H.show_msg("照片离开手心的一瞬,胸口空了一块。", 4.2)
				m.after(2.2, func(): do_sacrifice.call("妹妹的照片"))},
		]
		if m.G.batteries >= 2:
			ch.append({"text": "献上电池 ×2", "fn": func() -> void:
				m.close_modal()
				m.G.batteries -= 2
				m.after(1.6, func(): do_sacrifice.call("两节电池"))})
		else:
			ch.append({"text": "献上电池 ×2", "disabled": true, "reason": "数量不足"})
		if m.G.candles >= 1:
			ch.append({"text": "献上香烛 ×1", "fn": func() -> void:
				m.close_modal()
				m.G.candles -= 1
				m.after(1.6, func(): do_sacrifice.call("一支香烛"))})
		else:
			ch.append({"text": "献上香烛 ×1", "disabled": true, "reason": "没有香烛"})
		ch.append({"text": "转身离开", "fn": func() -> void: m.close_modal()})
		m.open_modal({
			"title": "祭 坛",
			"body": "石坛中央刻着一个凹槽,形状……像是随手放什么进去都行。\n坛身刻着两行字:\n\"献祭自愿。空手上坛者,坛自取之。\"\n\"那东西怕的不是刀,是名字。\"\n\n(离开不献,整层会越来越冷。)",
			"choices": ch,
		})
	m.add_inter(Vector3(0, 1.0, -4.6), "祭坛", altar_cb, 2.2)
	# 住户须知(电梯口)
	var paper_mat: StandardMaterial3D = m.tex_mat("paper", "d8cfb4", {"roughness": 0.9})
	m.add_quad(1.1, 1.4, paper_mat, -2.4, 1.7, 7.6, PI, 0.0)
	m.add_inter(Vector3(-2.4, 1.5, 7.3), "《住户须知》", func() -> void:
		m.open_modal({
			"title": "11F 祭坛 · 住户须知",
			"body": "一、献祭自愿。空手上坛者,坛自取之。\n\n二、壁画上的楼是反的,请以您所在的楼为准。\n\n三、下坛请倒退三步,再转身。",
			"choices": [{"text": "记住了", "fn": func() -> void: m.close_modal()}],
		}), 2.0)
	# 楼层逻辑:未献祭 → 整层骤冷持续掉理智;献祭后祭坛微光脉动
	var state := {"cold_t": 0.0, "cold_msg_cd": 0.0, "pulse": 0.0}
	m.floor_update = func(dt: float) -> void:
		state["pulse"] = state["pulse"] + dt
		if is_instance_valid(altar_light):
			altar_light.light_energy = 1.2 * (0.85 + 0.15 * sin(state["pulse"] * 1.6))
		if m.G.flags.get("sacrifice11F", false):
			return
		state["cold_t"] = state["cold_t"] + dt
		state["cold_msg_cd"] = state["cold_msg_cd"] - dt
		if state["cold_t"] > 6.0:
			state["cold_t"] = 0.0
			m.change_sanity(-4.0)
			m.S.whisper()
			if state["cold_msg_cd"] <= 0.0:
				state["cold_msg_cd"] = 12.0
				m.H.show_msg("整层在变冷。呼吸凝成白雾——坛上刻着\"空手上坛者,坛自取之\"。理智 −4", 4.6)
	m.tp_list([
		{"x": 0.0, "z": -3.4, "yaw": 0.0},
		{"x": 0.0, "z": -6.4, "yaw": 0.0},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("11F 祭坛。献上一件随身之物(不献,寒意不会停)")
	m.H.show_msg("11F。整层的空气像贴着冰。墙上画着这栋楼——一扇窗,红得刺眼。", 5.6)
