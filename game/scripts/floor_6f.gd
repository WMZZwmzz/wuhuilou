extends RefCounted
## 6F 酒店公寓(无限走廊)

static func build(m) -> void:
	m.setup_env(0.13, Color.html("3a342c"), Color.html("090705"), 0.05)
	FloorCommon.room_shell(m, 20.0, 16.0)
	FloorCommon.build_elevator(m)
	m.add_light(Color.html("e8d0a0"), 0.45, 14.0, 0, 2.9, 0, 0.2)
	# 走廊(东西向):北墙整条 + 南墙两侧留 2m 入口(x=0 正对电梯)
	m.add_wall(0.0, -2.0, 20.0, 0.3)
	m.add_wall(-5.5, 2.0, 9.0, 0.3)
	m.add_wall(5.5, 2.0, 9.0, 0.3)
	var door_mat: StandardMaterial3D = m.tex_mat("door", "5d4530", {
		"normal": m.T.tex.get("door_n"), "normal_scale": 0.5,
		"roughness": 0.55, "clearcoat": 0.45, "cc_rough": 0.35,
	})
	var plq_mat: StandardMaterial3D = m.tex_mat("plaque", "2e2b26", {"roughness": 0.5})
	# 门位:北墙 6 扇(z=-1.85 朝南)、南墙 4 扇(z=1.85 朝北,避开 x=0 入口)
	var door_poses: Array = [
		[-7.5, -1.85, 0.0], [-4.5, -1.85, 0.0], [-1.5, -1.85, 0.0], [1.5, -1.85, 0.0], [4.5, -1.85, 0.0], [7.5, -1.85, 0.0],
		[-6.0, 1.85, PI], [-3.0, 1.85, PI], [3.0, 1.85, PI], [6.0, 1.85, PI],
	]
	var truth_idx := randi() % door_poses.size()
	var state := {"wraps": 0, "wrap_msg_cd": 0.0}
	for i in door_poses.size():
		var p: Array = door_poses[i]
		var x: float = p[0]
		var z: float = p[1]
		Props.door_set(m, x, z, p[2], door_mat)
		var pl := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.5, 0.3)
		pl.mesh = qm
		pl.material_override = plq_mat
		pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pl.position = Vector3(x + 0.75, 1.8, z + (0.06 if z < 0 else -0.06))
		if z > 0:
			pl.rotation.y = PI
		m.floor_root.add_child(pl)
		var is_truth: bool = (i == truth_idx)
		var listen_cb := func() -> void:
			if m.G.flags.get("door6F", false):
				m.H.show_msg("真门已经开过了。墙上留下一个门牌形状的浅印。")
				return
			if is_truth:
				m.open_modal({
					"title": "贴 门 倾 听",
					"body": "门内传来极轻的数数声——\n\"……十、十一、十二、十三。\"\n数到十三,停住,又从头开始。\n是她。就是这个声音。",
					"choices": [
						{"text": "推开门", "fn": func() -> void:
							m.close_modal()
							m.G.flags["door6F"] = true
							m.change_sanity(-5.0)
							m.add_game_minutes(10)
							m.open_modal({
								"title": "真 门 之 后",
								"body": "门后是个空荡荡的房间,墙上钉满了 1304 的门牌。\n床头一台旧录音机还在转,是妹妹的声音:\n\"……哥,这层楼的门牌,全都是1304。只有一扇门后面,有我的东西……\"\n\n一个身影在房间中央徘徊,喃喃:\"我的房间是1304……可这层楼,每一扇门都是1304。\"\n他愣住,看向录音机:\"原来……我早就死了。我找的不是门,是回去的路。\"",
								"choices": [{"text": "取下墙上的门牌", "fn": func() -> void:
									m.close_modal()
									m.gain_relic("1304 门牌")
									m.after(2.6, func(): m.gain_card("7F"))
									m.after(5.4, func() -> void:
										m.H.show_msg("\"替我留着。等这楼塌了,我就认得回家的门了。\"\n身影淡去。录音机里弹出一张卡片。", 5.6))
									m.H.set_objective("权限卡7F到手。乘电梯前往 7F 灵堂")}],
							})},
						{"text": "退开,再听听别的门", "fn": func() -> void: m.close_modal()},
					],
				})
			else:
				var flavor: String = [
					"门后死一般寂静。连你自己的呼吸都被吸走了。",
					"数数声——数到十二,停了。不是她。",
					"很轻的抽泣,数到七就停。然后是挪动椅子的声音。",
					"门后传来电视的杂音,像三十年前的春晚。",
				][i % 4]
				m.open_modal({
					"title": "贴 门 倾 听",
					"body": flavor + "\n\n(录音带里说过:数到十二就停的,不是我。千万别应声。)",
					"choices": [
						{"text": "推开门看看", "fn": func() -> void:
							m.close_modal()
							var door_drain := 10.0   # 1304 推门惊吓一次性扣值(文案同源)
							m.change_sanity(-door_drain)
							m.H.red_flash()
							m.S.play_at("thud", Vector3(x, 1.2, z), 1.3)   # 声从这扇门后来
							m.shake = 1.6
							m.H.show_msg("门推开了三寸,又被什么东西从里面死死顶住。\n门缝里,一只贴着门板的眼睛缓缓闭上。理智 −%d" % int(door_drain), 5.4)},
						{"text": "退开", "fn": func() -> void: m.close_modal()},
					],
				})
		m.add_inter(Vector3(x, 1.2, z + (-0.3 if z > 0 else 0.3)), "1304(听)", listen_cb, 1.8)
	# 住户须知(电梯口左侧,避开呼梯面板交互)
	var paper_mat: StandardMaterial3D = m.tex_mat("paper", "d8cfb4", {"roughness": 0.9})
	m.add_quad(1.1, 1.4, paper_mat, -2.4, 1.7, 7.6, PI, 0.0)
	m.add_inter(Vector3(-2.4, 1.5, 7.3), "《住户须知》", func() -> void:
		m.open_modal({
			"title": "6F 公寓层 · 住户须知",
			"body": "一、本层所有房间均为 1304,请认准自己的房间。\n\n二、听见门内数数,请听完;数到十二就停的,请走开。\n\n三、请勿在同一扇门前停留两次。",
			"choices": [{"text": "记住了", "fn": func() -> void: m.close_modal()}],
		}), 2.0)
	# 楼层逻辑:走廊首尾无缝回绕(x 越界即折返)+ 偶发"还是走廊"提示
	m.floor_update = func(_dt: float) -> void:
		if m.player_pos.x > 9.4:
			m.player_pos.x = -9.4
			state["wraps"] = state["wraps"] + 1
		elif m.player_pos.x < -9.4:
			m.player_pos.x = 9.4
			state["wraps"] = state["wraps"] + 1
		state["wrap_msg_cd"] = state["wrap_msg_cd"] - _dt
		if state["wraps"] >= 2 and state["wrap_msg_cd"] <= 0.0:
			state["wrap_msg_cd"] = 14.0
			m.H.show_msg("你又走回了走廊的中段。这层楼,没有尽头。", 4.0)
	m.tp_list([
		{"x": -7.5, "z": -0.7, "yaw": 0.0},
		{"x": -4.5, "z": -0.7, "yaw": 0.0},
		{"x": -1.5, "z": -0.7, "yaw": 0.0},
		{"x": 1.5, "z": -0.7, "yaw": 0.0},
		{"x": 4.5, "z": -0.7, "yaw": 0.0},
		{"x": 7.5, "z": -0.7, "yaw": 0.0},
		{"x": -6.0, "z": 0.7, "yaw": PI},
		{"x": -3.0, "z": 0.7, "yaw": PI},
		{"x": 3.0, "z": 0.7, "yaw": PI},
		{"x": 6.0, "z": 0.7, "yaw": PI},
		{"x": 0.0, "z": 4.0, "yaw": 0.0},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("6F 无限走廊。贴门听数数——数到十三的那扇,是真门")
	m.H.show_msg("6F。整层静得过分。所有的门牌,都写着 1304。", 5.2)
