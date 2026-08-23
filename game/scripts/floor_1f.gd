extends RefCounted
## 1F 大堂(教学)

static func build(m) -> void:
	m.setup_env(0.32, Color.html("4a4a42"), Color.html("0c0d0a"), 0.03)
	FloorCommon.room_shell(m, 20.0, 16.0)
	FloorCommon.build_elevator(m)
	# 大堂主灯(声控日光灯,闪烁)
	m.add_light(Color.html("cfd8c0"), 0.85, 12.0, 0, 2.9, 0, 0.25)
	m.safe_spot(0, 0, 6.5)
	# 入口铁门(-Z),已变实墙
	var gate_mat: StandardMaterial3D = m.tex_mat("metal", "7c8084", {"metallic": 0.45, "roughness": 0.55})
	m.add_box(3.2, 2.8, 0.25, gate_mat, 0, 1.4, -7.85)
	for gy: float in [0.5, 1.4, 2.3]:
		m.add_box(3.0, 0.09, 0.06, gate_mat, 0, gy, -7.7, false)
	Props.floor_mat(m, 0, -6.4)
	var gate_cb := func() -> void:
		m.H.show_msg("你回过头——没有门。只有一堵墙,和墙上你自己的影子。", 4.5)
	m.add_inter(Vector3(0, 1.5, -7.6), "身后的铁门", gate_cb, 2.4)
	# 保安室(+X 后侧,门口宽 1.2m:x 7.4~8.6)
	m.add_wall(6.5, -6, 0.3, 4.2)
	m.add_wall(6.95, -4.05, 0.9, 0.3)
	m.add_wall(9.15, -4.05, 1.1, 0.3)
	# 保安室内:桌 + 监控
	Props.wood_desk(m, 8, -6.6, 0.0, 2.6, 1.1, 0.85)
	m.colliders.append(Rect2(8 - 1.3, -6.6 - 0.55, 2.6, 1.1))
	var mon_mat: StandardMaterial3D = m.pmat({
		"tex": m.T.tex.get("monitor"), "emission_tex": m.T.tex.get("monitor"),
		"emission": Color.html("5a7a5e"), "emission_energy": 1.5, "roughness": 0.35,
		"color": Color.html("0c1410") if m.T.tex.get("monitor") == null else Color.WHITE,
	})
	if m.T.tex.get("monitor") == null:
		mon_mat.emission_texture = null
	Props.monitor_rig(m, 8, 1.6, -7.2, PI, mon_mat)
	var mon_cb := func() -> void:
		if not m.G.flags.get("monSeen", false):
			m.G.flags["monSeen"] = true
			m.change_sanity(-10.0)
			m.H.red_flash()
			m.S.sting()
			m.H.show_msg("监控画面里,大楼铁门外站着一个人。\n那件外套……是你身上这件。理智 −10", 5.6)
		else:
			m.H.show_msg("监控雪花闪了闪。门外的人,还在。")
	m.add_inter(Vector3(8, 1.5, -6.6), "监控屏幕", mon_cb, 2.2)
	# 手电(保安室桌上)
	if not m.G.has_flash:
		var fl := Props.flashlight_prop(m)
		fl.position = Vector3(6.9, 0.92, -6.6)
		m.floor_root.add_child(fl)
		var fl_cb := func() -> void:
			if m.G.has_flash:
				return
			m.G.has_flash = true
			m.G.battery = 50.0
			m.G.flash_on = true
			m.H.show_msg("捡到手电筒。电量只剩一半——省着点用。[F] 开关手电", 5.0)
			m.H.set_objective("查看墙上的《住户须知》,然后去乘电梯(北侧)")
			if is_instance_valid(fl):
				fl.free()
		m.add_inter(Vector3(6.9, 1.0, -6.6), "手电筒", fl_cb, 2.2)
	# 保安室挂钟(指针随游戏时间走)
	var clock: Dictionary = Props.wall_clock(m, 6.7, 2.05, -6.0, PI / 2.0)
	m.floor_update = func(_dt: float) -> void:
		var t: float = m.G.time
		clock["mp"].rotation.z = -TAU * fmod(t, 60.0) / 60.0
		clock["hp"].rotation.z = -TAU * fmod(t, 720.0) / 720.0
	# 住户须知(保安室墙上)
	var paper_mat: StandardMaterial3D = m.tex_mat("paper", "d8cfb4", {"roughness": 0.9})
	m.add_quad(1.3, 1.7, paper_mat, 5.0, 1.7, -7.80, 0.0, 0.0)
	var notice_cb := func() -> void:
		m.open_modal({
			"title": "住 户 须 知",
			"body": "一、电梯限乘四人。若电梯内已有\"人\",请等下一班。\n\n二、若按钮13层亮起但无人按下,请立即退出。\n\n三、电梯内镜子不可直视超过三秒。\n\n四、若停靠后门迟迟不开,请闭眼、背对门站立。\n\n(纸的边角写着一行小字:规则有真有假。今晚——祝你好运。)",
			"choices": [{"text": "记住了", "fn": func() -> void:
				m.close_modal()
				m.G.flags["rulesRead"] = true
				m.H.show_msg("把规则记在心里。电梯就在北面。")}],
		})
	m.add_inter(Vector3(5.0, 1.6, -7.5), "《住户须知》", notice_cb, 2.2)
	# 倒塌的货架(蹲伏教学):斜板下压着一格电池,必须蹲下才摸得到
	var crash_mat: StandardMaterial3D = m.pmat({"color": Color.html("4a4438"), "roughness": 0.7})
	var board: MeshInstance3D = m.add_box(2.4, 0.1, 1.0, crash_mat, -4.2, 0.55, -4.6, false)
	board.rotation.z = 0.42
	m.add_box(0.12, 1.1, 0.12, crash_mat, -5.2, 0.55, -4.6, false)
	m.add_box(0.12, 0.7, 0.12, crash_mat, -3.2, 0.35, -4.6, false)
	m.colliders.append(Rect2(-5.3, -5.15, 2.2, 1.1))
	var crevice_cb := func() -> void:
		if not m.G.flags.get("bat1F", false):
			if m.G.crouching:
				m.G.flags["bat1F"] = true
				m.G.batteries += 1
				m.H.show_msg("蹲下身,从货架底下摸出一节电池。+1 电池\n(按住 [Ctrl] 蹲伏——3F 的矮柜、B1 的车后,都得这样躲)", 5.2)
			else:
				m.H.show_msg("货架塌了半边,底下压着什么。站姿够不到——按住 [Ctrl] 蹲下试试。", 4.6)
		else:
			m.H.show_msg("货架底下空了。")
	m.add_inter(Vector3(-4.2, 0.4, -4.3), "倒塌的货架", crevice_cb, 2.0)
	# 长椅等摆设
	Props.bench(m, -5, -2, 0.0)
	Props.bench(m, -5, 2, 0.0)
	m.colliders.append(Rect2(-5 - 1.7, -2 - 0.3, 3.4, 0.6))
	m.colliders.append(Rect2(-5 - 1.7, 2 - 0.3, 3.4, 0.6))
	# 信箱墙
	Props.mailbox_wall(m, -7.5, -7.8)
	m.colliders.append(Rect2(-7.5 - 2.1, -7.8 - 0.15, 4.2, 0.3))
	var mail_cb := func() -> void:
		m.H.show_msg("所有信箱都锈死了。只有一格塞着水电费催缴单——日期是三十年前。")
	m.add_inter(Vector3(-7.5, 1.2, -7.5), "信箱", mail_cb, 2.2)
	# 教学字幕
	# 教学字幕:挂在 SceneTree 上的计时器不随 Main 释放,
	# 场景重载后旧计时器仍可能回调 → 访问已释放的 m/H。先判活。
	m.get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if is_instance_valid(m): m.H.show_msg("午夜 0:00。铁门在身后合拢,消失了。", 4.2))
	m.get_tree().create_timer(5.4).timeout.connect(func() -> void:
		if is_instance_valid(m): m.H.show_msg("保安室(东侧)里有手电。用 [WASD] 走过去,[E] 互动。", 5.0))
	m.get_tree().create_timer(9.8).timeout.connect(func() -> void:
		if is_instance_valid(m): m.H.show_msg("按住 [Ctrl] 可以蹲下。有些东西,只有蹲下的人才拿得到、躲得过。", 5.2))
	m.tp_list([
		{"x": 6.9, "z": -5.2, "yaw": 0.0},
		{"x": 5.0, "z": -6.0, "yaw": 0.0},
		{"x": 8.0, "z": -5.2, "yaw": 0.0},
		{"x": -4.2, "z": -3.4, "yaw": 0.0},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("找到妹妹 —— 1304(先去保安室拿手电)")
	if m.G.has_flash and m.G.flags.get("rulesRead", false):
		m.H.set_objective("乘电梯上行(北侧面板)")
