extends RefCounted
## 5F 网吧

static func build(m) -> void:
	m.setup_env(0.1, Color.html("1a2432"), Color.html("05080e"), 0.06)
	FloorCommon.room_shell(m, 20.0, 16.0)
	FloorCommon.build_elevator(m)
	# 电脑排两列 ×3(大厅,屏幕大多熄灭)
	var dark_scr: StandardMaterial3D = m.pmat({"color": Color.html("0c1016"), "roughness": 0.4, "metallic": 0.2})
	var lit_scr: StandardMaterial3D = m.pmat({
		"tex": m.T.tex.get("monitor"), "emission_tex": m.T.tex.get("monitor"),
		"emission": Color.html("5a8a6e"), "emission_energy": 1.4, "roughness": 0.35,
		"color": Color.html("0c1410") if m.T.tex.get("monitor") == null else Color.WHITE,
	})
	if m.T.tex.get("monitor") == null:
		lit_scr.emission_texture = null
	var pc_poses: Array = [
		[-5.5, -3.0, 0.0, false], [-2.0, -3.0, 0.0, false], [1.5, -3.0, 0.0, false],
		[-5.5, 1.5, PI, true], [-2.0, 1.5, PI, false], [1.5, 1.5, PI, false],
	]
	for p: Array in pc_poses:
		var smat: StandardMaterial3D = lit_scr if p[3] else dark_scr
		Props.pc_terminal(m, p[0], p[1], p[2], smat)
		m.colliders.append(Rect2(p[0] - 0.6, p[1] - 0.35, 1.2, 0.7))
	# 自动开机的电脑:播放玩家刚经过楼层的"监控"
	var auto_cb := func() -> void:
		if not m.G.flags.get("pc5F", false):
			m.G.flags["pc5F"] = true
			m.change_sanity(-8.0)
			m.S.play_buf("drip", 1.0)
			m.open_modal({
				"title": "CAM 回 放",
				"body": "屏幕自己亮了。四分格的监控画面:\n1F 大堂——你捡手电的背影。\n2F 麻将馆——你在黑暗里摸索。\n4F 诊所——模型站在你身后半米。\n\n每一格的角落,时间戳都是\"刚刚\"。\n你一直被看着。理智 −8",
				"choices": [{"text": "关掉它", "fn": func() -> void:
					m.close_modal()
					m.H.show_msg("屏幕暗下去的瞬间,反光里映出身后一排坐姿整齐的人影。", 4.6)}],
			})
		else:
			m.H.show_msg("屏幕黑着。你不想再开第二次。")
	m.add_inter(Vector3(-5.5, 1.1, 2.0), "自动开机的电脑", auto_cb, 2.0)
	# 收费台/主机(东侧,+X 墙):监控删除谜题,密码=4F 处方批号(跨层线索)
	Props.wood_desk(m, 6.8, -2.0, -PI / 2.0, 2.2, 0.9, 0.9, "4a4438")
	m.colliders.append(Rect2(6.8 - 0.45, -2.0 - 1.1, 0.9, 2.2))
	var host_scr: StandardMaterial3D = m.pmat({
		"color": Color.html("18242e"), "emission": Color.html("3a6a8a"), "emission_energy": 1.1,
		"roughness": 0.4, "metallic": 0.2,
	})
	Props.pc_terminal(m, 7.0, -3.6, PI, host_scr)
	m.colliders.append(Rect2(7.0 - 0.6, -3.6 - 0.35, 1.2, 0.7))
	m.add_light(Color.html("6a9ac8"), 0.35, 6.0, 7.0, 2.4, -3.4, 0.1)
	var solve_pc := func() -> void:
		m.G.flags["del5F"] = true
		m.add_game_minutes(10)
		m.open_modal({
			"title": "删 除 完 成",
			"body": "进度条走完。屏幕滚出一行字:\n\"谢谢你帮我删掉它……原来我那天想删的,不是犯罪证据,是我自己没能开门的录像。\"\n\n网管室的尸体,缓缓\"坐\"了起来,盯着发蓝光的屏幕。\n\"门是我锁的。人是我害的。可我删得掉录像,删不掉那天的火。\"",
			"choices": [{"text": "取走键盘下的会员卡", "fn": func() -> void:
				m.close_modal()
				m.gain_relic("网吧会员卡")
				m.get_tree().create_timer(2.6).timeout.connect(func(): m.gain_card("6F"))
				m.get_tree().create_timer(5.4).timeout.connect(func() -> void:
					m.H.show_msg("尸体在蓝光里淡成一片薄影,散了。\n会员卡背面刻着四个字:\"再试一次\"。", 5.2))
				m.H.set_objective("权限卡6F到手。乘电梯前往 6F 酒店公寓")}],
		})
	var host_cb := func() -> void:
		if m.G.flags.get("del5F", false):
			m.H.show_msg("主机屏幕停在那行字:\"再试一次\"。")
			return
		m.open_modal({
			"title": "删 除 确 认",
			"body": "屏幕弹出一个老系统的对话框:\n\"是否删除 2008-06-13 的录像?此操作不可恢复。\"\n\n下方是验证栏:【请输入处方批号验证管理员身份】\n(4F 诊所的处方登记册上,好像印过这样的批号。)",
			"choices": [
				{"text": "输入 TX-2048", "fn": func() -> void:
					m.close_modal()
					solve_pc.call()},
				{"text": "输入 20080613", "fn": func() -> void:
					m.close_modal()
					m.change_sanity(-10.0)
					m.H.red_flash()
					m.S.sting()
					m.H.show_msg("\"密码错误。错误 3 次将锁定。\"\n屏幕闪了一下——监控画面里,你背后的走廊多了一个站着的影子。理智 −10", 5.4)},
				{"text": "暂时取消", "fn": func() -> void: m.close_modal()},
			],
		})
	m.add_inter(Vector3(7.0, 1.1, -3.0), "收费台主机", host_cb, 2.2)
	# 网管室(-X 后角):阿杰的尸体,偶尔转头
	m.add_wall(-6.5, -6.75, 0.3, 2.5)
	m.add_wall(-9.1, -5.5, 1.8, 0.3)
	Props.chair(m, -8.3, -6.2, 0.6)
	var jay := Node3D.new()
	var cloth: StandardMaterial3D = m.pmat({"color": Color.html("32404a"), "roughness": 0.9})
	var skin: StandardMaterial3D = m.pmat({"color": Color.html("9a8874"), "roughness": 0.85})
	var jb := MeshInstance3D.new()
	var jbc := CylinderMesh.new()
	jbc.top_radius = 0.18
	jbc.bottom_radius = 0.24
	jbc.height = 0.6
	jb.mesh = jbc
	jb.material_override = cloth
	jb.position = Vector3(0, 0.75, 0)
	jb.rotation.z = 0.28
	jay.add_child(jb)
	var jh := MeshInstance3D.new()
	var jhs := SphereMesh.new()
	jhs.radius = 0.13
	jhs.height = 0.26
	jh.mesh = jhs
	jh.material_override = skin
	jh.position = Vector3(0.06, 1.12, 0.06)
	jay.add_child(jh)
	jay.position = Vector3(-8.3, 0, -6.2)
	jay.rotation.y = 0.6
	m.floor_root.add_child(jay)
	m.add_light(Color.html("4a6a9a"), 0.3, 5.0, -8.3, 2.4, -6.2, 0.15)
	# 厕所(+X 前角):藏身点 + 电池
	m.add_wall(6.5, 4.4, 0.3, 3.4)
	m.add_wall(8.6, 6.0, 4.0, 0.3)
	m.safe_spot(8.2, 4.6, 1.6)
	var bat5 := Props.battery_prop(m)
	bat5.rotation.z = PI / 2.0
	bat5.position = Vector3(8.6, 0.045, 4.6)
	m.floor_root.add_child(bat5)
	var bat_cb := func() -> void:
		m.G.flags["bat5F"] = true
		m.G.batteries += 1
		if is_instance_valid(bat5):
			bat5.free()
		m.H.show_msg("厕所隔间的手纸架上,卡着一节电池。+1 电池", 4.2)
	var bat_cond := func() -> bool: return not m.G.flags.get("bat5F", false)
	m.add_inter(Vector3(8.6, 0.4, 4.6), "隔间里的电池", bat_cb, 2.0, bat_cond)
	# 柜台下电池(明面)
	var bat5b := Props.battery_prop(m)
	bat5b.rotation.z = PI / 2.0
	bat5b.position = Vector3(6.4, 0.045, -0.6)
	m.floor_root.add_child(bat5b)
	var batb_cb := func() -> void:
		m.G.flags["bat5Fb"] = true
		m.G.batteries += 1
		if is_instance_valid(bat5b):
			bat5b.free()
		m.H.show_msg("收费台底下的抽屉里有一节电池。+1 电池", 4.2)
	var batb_cond := func() -> bool: return not m.G.flags.get("bat5Fb", false)
	m.add_inter(Vector3(6.4, 0.4, -0.6), "收费台抽屉的电池", batb_cb, 2.0, batb_cond)
	# 住户须知
	var paper_mat: StandardMaterial3D = m.tex_mat("paper", "d8cfb4", {"roughness": 0.9})
	m.add_quad(1.1, 1.4, paper_mat, -2.4, 1.7, 7.6, PI, 0.0)
	m.add_inter(Vector3(-2.4, 1.5, 7.3), "《住户须知》", func() -> void:
		m.open_modal({
			"title": "5F 网吧 · 住户须知",
			"body": "一、上机请刷会员卡,无卡者请观战,请勿触碰键盘。\n\n二、屏幕自行亮起时,请勿直视超过十秒。\n\n三、删除记录前,请确认您真的想删除。",
			"choices": [{"text": "记住了", "fn": func() -> void: m.close_modal()}],
		}), 2.0)
	# 楼层逻辑:尸体偶尔转头 + 电流杂音
	var state := {"turn_t": 7.0, "facing": false, "face_t": 0.0, "hum_t": 5.0}
	m.floor_update = func(dt: float) -> void:
		state["hum_t"] = state["hum_t"] - dt
		if state["hum_t"] <= 0.0:
			state["hum_t"] = 11.0 + randf() * 9.0
			m.S.play_buf("drip", 0.8, randf_range(0.7, 0.9))
		if not is_instance_valid(jay):
			return
		state["turn_t"] = state["turn_t"] - dt
		if state["facing"]:
			state["face_t"] = state["face_t"] - dt
			if state["face_t"] <= 0.0:
				state["facing"] = false
				jay.rotation.y = 0.6
		elif state["turn_t"] <= 0.0:
			state["turn_t"] = 7.0 + randf() * 6.0
			if randf() < 0.55:
				state["facing"] = true
				state["face_t"] = 1.4
				jay.look_at(Vector3(m.player_pos.x, jay.position.y, m.player_pos.z))
				if not m.G.flags.get("jaySeen", false) and m.player_pos.distance_to(jay.position) < 9.0:
					m.G.flags["jaySeen"] = true
					m.change_sanity(-10.0)
					m.H.red_flash()
					m.S.sting()
					m.H.show_msg("尸体的头,正对着你。眼睛的位置,是两个干瘪的孔。理智 −10", 5.0)
	m.tp_list([
		{"x": 7.0, "z": -1.8, "yaw": 0.0},
		{"x": -5.5, "z": 3.0, "yaw": 0.0},
		{"x": -8.3, "z": -4.6, "yaw": 0.0},
		{"x": 8.6, "z": 3.4, "yaw": PI},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("5F 网吧。删除那段监控(验证批号在 4F)")
	m.H.show_msg("5F。一排排电脑蒙着灰。只有角落那台,还亮着。", 5.2)
