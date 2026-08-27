extends RefCounted
## 3F 幼儿园

static func build(m) -> void:
	m.setup_env(0.14, Color.html("4a3c34"), Color.html("0c0806"), 0.05)
	FloorCommon.room_shell(m, 20.0, 16.0)
	FloorCommon.build_elevator(m)
	m.add_light(Color.html("e8d8a8"), 0.4, 9.0, 0, 2.9, -4.5, 0.12)
	# 三间教室(-Z 侧),门口各 1.4m 宽
	m.add_wall(-4.2, -5.0, 0.3, 5.0)
	m.add_wall(4.2, -5.0, 0.3, 5.0)
	m.add_wall(-8.85, -2.5, 2.3, 0.3)
	m.add_wall(-3.5, -2.5, 5.6, 0.3)
	m.add_wall(3.5, -2.5, 5.6, 0.3)
	m.add_wall(8.85, -2.5, 2.3, 0.3)
	for room: Array in [[-7.1, 0], [0.0, 0], [7.1, 0]]:
		Props.child_desk(m, room[0] - 1.2, -6.2, 0.0)
		Props.child_desk(m, room[0] + 1.2, -6.2, 0.0)
		Props.child_chair(m, room[0] - 1.2, -5.2, 0.0)
		Props.child_chair(m, room[0] + 1.2, -5.2, 0.0)
	# 黑板(中教室)+ 儿童画(后墙,眼睛"会转"——整体轻摆 + 首幅正对门口)
	var chalk_mat: StandardMaterial3D = m.tex_mat("chalk", "28402e", {"roughness": 0.95})
	Props.chalkboard(m, 0, 1.6, -7.5, 0.0, chalk_mat)
	var paint_mat: StandardMaterial3D = m.tex_mat("crayon", "e8ddc4", {"roughness": 0.92})
	var paintings: Array = []
	for p: Array in [[-8.6, -7.78], [-5.6, -7.78], [-1.6, -7.78], [1.6, -7.78], [5.6, -7.78], [8.6, -7.78]]:
		paintings.append(m.add_quad(0.9, 0.9, paint_mat, p[0], 1.55, p[1], 0.0))
	var paint_cb := func() -> void:
		m.open_modal({
			"title": "儿 童 画",
			"body": "蜡笔画的太阳、小人和房子。画下面一行小字:\n\"先对上眼睛,才有笑脸。\"\n\n画里小人的眼睛,好像刚刚才转回来。",
			"choices": [{"text": "移开视线", "fn": func() -> void: m.close_modal()}],
		})
	m.add_inter(Vector3(-8.6, 1.4, -7.5), "儿童画", paint_cb, 1.8)
	# 走廊矮柜 ×2(蹲伏藏身点)+ 柜后电池(须蹲下)
	Props.low_cabinet(m, -3.5, 2.5, PI)
	m.colliders.append(Rect2(-3.5 - 0.8, 2.5 - 0.3, 1.6, 0.6))
	Props.low_cabinet(m, 3.5, 2.5, PI)
	m.colliders.append(Rect2(3.5 - 0.8, 2.5 - 0.3, 1.6, 0.6))
	var bat3 := Props.battery_prop(m)
	bat3.rotation.z = PI / 2.0
	bat3.position = Vector3(3.5, 0.045, 3.3)
	m.floor_root.add_child(bat3)
	var bat_cb := func() -> void:
		if m.G.crouching:
			m.G.flags["bat3F"] = true
			m.G.batteries += 1
			if is_instance_valid(bat3):
				bat3.free()
			m.H.show_msg("蹲在矮柜后面,摸到一节滚落的电池。+1 电池", 4.2)
		else:
			m.H.show_msg("矮柜后面好像有东西。站着看不见——按住 [Ctrl] 蹲下。", 4.2)
	var bat_cond := func() -> bool: return not m.G.flags.get("bat3F", false)
	m.add_inter(Vector3(3.5, 0.4, 3.3), "矮柜后的电池", bat_cb, 2.0, bat_cond)
	# 苏梅(老师):围裙 + 发髻 + 锥裙,沿固定路线巡视走廊
	var fig := Props.human_figure(m, {
		"pose": "stand", "scale": 0.94, "hair": "bun", "skirt": true, "apron": true,
		"top_hex": "4a6a72", "bottom_hex": "3a545c", "skin_hex": "c8b49a", "hair_hex": "2c262c",
	})
	var su: Node3D = fig["root"]
	su.position = Vector3(0, 0, 4.0)
	m.floor_root.add_child(su)
	var state := {"wp": 0, "caught_cd": 0.0, "giggle_t": 6.0}
	var wps: Array = [Vector3(0, 0, 4.0), Vector3(-6, 0, 1.0), Vector3(0, 0, -1.5), Vector3(6, 0, 1.0)]
	# 拼图谜题(右教室桌面)
	var solve_pz := func() -> void:
		m.G.flags["puzzle3F"] = true
		m.add_game_minutes(10)
		m.gain_relic("半盒彩色粉笔")
		m.after(2.8, func(): m.gain_card("4F"))
		m.after(5.6, func() -> void:
			m.H.show_msg("黑板上传来\"沙沙\"声,浮出一行字:\n\"火灾那天,我先让孩子们跑,自己最后一个走。\"\n一个穿围裙的身影站在黑板前,轻声问:\"他们……都跑出去了吗?\"", 7.0))
		m.after(9.2, func() -> void:
			if is_instance_valid(su):
				su.visible = false
			m.H.show_msg("\"那就好。老师终于能下课了。\"\n讲台上留下半盒彩色粉笔。", 5.6))
		m.H.set_objective("权限卡4F到手。乘电梯前往 4F 诊所")
	var pz_cb := func() -> void:
		if m.G.flags.get("puzzle3F", false):
			m.H.show_msg("拼好的笑脸安安静静。孩子们的笑声停了。")
			return
		m.open_modal({
			"title": "笑 脸 拼 图",
			"body": "桌上摊着一幅拼了一半的拼图——孩子们的笑脸。\n碎片分三堆:眼睛、脸庞、嘴巴。\n\n(教室门口那幅儿童画下面写着:\"先对上眼睛,才有笑脸。\")",
			"choices": [
				{"text": "先拼眼睛 → 再拼脸庞 → 最后拼嘴巴", "fn": func() -> void:
					m.close_modal()
					solve_pz.call()},
				{"text": "先拼嘴巴 → 再拼脸庞", "fn": func() -> void:
					m.close_modal()
					m.change_sanity(-m.G.NUM["violation"])
					m.H.red_flash()
					m.S.sting()
					m.shake = 1.8
					m.H.show_msg("嘴巴拼上去的瞬间,整幅画的孩子一起\"哭\"了出来。理智 −%d" % int(m.G.NUM["violation"]), 5.2)},
				{"text": "把碎片扫到一边,不拼了", "fn": func() -> void:
					m.close_modal()
					m.change_sanity(-m.G.NUM["violation"])
					m.H.red_flash()
					m.S.sting()
					m.H.show_msg("碎片散落一地。走廊尽头,脚步声停住了——她在看你。理智 −%d" % int(m.G.NUM["violation"]), 5.2)},
			],
		})
	m.add_inter(Vector3(7.1, 0.6, -5.6), "笑脸拼图", pz_cb, 2.0)
	# 住户须知(电梯口)
	var paper_mat: StandardMaterial3D = m.tex_mat("paper", "d8cfb4", {"roughness": 0.9})
	m.add_quad(1.1, 1.4, paper_mat, -2.4, 1.7, 7.6, PI, 0.0)
	m.add_inter(Vector3(-2.4, 1.5, 7.3), "《住户须知》", func() -> void:
		m.open_modal({
			"title": "3F 幼儿园 · 住户须知",
			"body": "一、孩子们在午睡,请勿奔跑,请勿喧哗。\n\n二、听见\"小朋友,出来吧\",请蹲下,不要出声。\n\n三、放学铃响前,老师不下班。",
			"choices": [{"text": "记住了", "fn": func() -> void: m.close_modal()}],
		}), 2.0)
	# 楼层逻辑:苏梅巡逻 + 视野判定(蹲伏可避)+ 儿童画轻摆 + 童声环境
	m.floor_update = func(dt: float) -> void:
		if m.G.flags.get("puzzle3F", false):
			return
		state["giggle_t"] = state["giggle_t"] - dt
		if state["giggle_t"] <= 0.0:
			state["giggle_t"] = 9.0 + randf() * 8.0
			m.S.play_buf("music_box", 0.25, randf_range(0.9, 1.1))
		var wp: Vector3 = wps[state["wp"]]
		var dir: Vector3 = wp - su.position
		dir.y = 0.0
		if dir.length() < 0.2:
			state["wp"] = (state["wp"] + 1) % wps.size()
		else:
			su.position += dir.normalized() * 1.1 * dt
			su.look_at(Vector3(wp.x, su.position.y, wp.z))
			su.position.y = abs(sin(Time.get_ticks_msec() * 0.008)) * 0.028
		state["caught_cd"] = maxf(0.0, state["caught_cd"] - dt)
		var to_p: Vector3 = m.player_pos - su.position
		to_p.y = 0.0
		var d := to_p.length()
		if d < 6.0 and m.player_pos.z > -2.5 and not m.G.crouching and state["caught_cd"] <= 0.0:
			var fwd := -su.global_transform.basis.z
			fwd.y = 0.0
			if fwd.length() > 0.01 and fwd.normalized().dot(to_p.normalized()) > 0.5:
				state["caught_cd"] = 6.0
				m.change_sanity(-m.G.NUM["violation"])
				m.H.red_flash()
				m.S.sting()
				m.shake = 2.0
				m.player_pos = Vector3(0, 0, 6.0)
				m.H.show_msg("\"小朋友,上课不许乱跑。\"\n她牵起你的手腕——指尖冰凉。你挣脱开,退回了电梯口。理智 −%d" % int(m.G.NUM["violation"]), 6.0)
		for i in paintings.size():
			var q: Node3D = paintings[i]
			if is_instance_valid(q):
				q.rotation.z = sin(Time.get_ticks_msec() * 0.0009 + i * 1.7) * 0.045
	m.tp_list([
		{"x": 7.1, "z": -4.4, "yaw": 0.0},
		{"x": -8.6, "z": -6.4, "yaw": 0.0},
		{"x": 0.0, "z": 1.0, "yaw": 0.0},
		{"x": 3.5, "z": 4.2, "yaw": PI},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("3F 幼儿园。完成拼图(线索:儿童画)·听见脚步就蹲下")
	m.H.show_msg("3F。褪色的幼儿园。墙上的儿童画……眼睛刚才动了吗?", 5.2)
