extends RefCounted
## 12F 天台(浓雾,开放空间)

static func build(m) -> void:
	m.setup_env(0.08, Color.html("3a444c"), Color.html("0c1014"), 0.16)
	# 开放天台:无房间外壳,混凝土地面 + 1.1m 矮女儿墙 + 楼梯间小屋
	var fmat: StandardMaterial3D = m.pmat({
		"tex": m.T.tex.get("floor"), "normal": m.T.tex.get("floor_n"),
		"uv1": Vector3(5.0, 4.0, 1.0), "roughness": 0.9, "normal_scale": 0.7,
		"color": Color.html("565a58") if m.T.tex.get("floor") == null else Color(0.85, 0.85, 0.86),
	})
	m.add_floor_plane(20.0, 16.0, fmat, 0, 0, 0, true)
	var parapet_mat: StandardMaterial3D = m.pmat({
		"tex": m.T.tex.get("wall"), "normal": m.T.tex.get("wall_n"),
		"uv1": Vector3(6.0, 0.4, 1.0), "roughness": 0.92, "normal_scale": 0.5,
		"color": Color.html("5c5e5a") if m.T.tex.get("wall") == null else Color(0.9, 0.9, 0.9),
	})
	# 女儿墙(东、西、北;南侧留给楼梯间与电梯)
	for w: Array in [[-9.85, 0.0, 0.3, 16.0], [9.85, 0.0, 0.3, 16.0], [0.0, -7.85, 20.0, 0.3]]:
		m.add_box(w[2], 1.1, w[3], parapet_mat, w[0], 0.55, w[1])
		m.colliders.append(Rect2(w[0] - w[2] / 2.0, w[1] - w[3] / 2.0, w[2], w[3]))
	# 南侧实墙(梯间背后,中央留电梯口,与标准外壳一致)
	for seg: Array in [[-5.6, 8.8], [5.6, 8.8]]:
		m.add_box(seg[1], 3.2, 0.3, parapet_mat, seg[0], 1.6, 7.85)
		m.colliders.append(Rect2(seg[0] - seg[1] / 2.0, 7.7, seg[1], 0.3))
	# 楼梯间小屋(-X 前角)+ 电梯(复用电梯间,贴 +Z 中央)
	m.add_wall(-6.5, 4.4, 0.3, 3.4)
	m.add_wall(-4.6, 6.0, 4.0, 0.3)
	FloorCommon.build_elevator(m)
	# 小屋:配电箱(电池)+ 住户须知
	var box_mat: StandardMaterial3D = m.pmat({"color": Color.html("5a5e58"), "metallic": 0.4, "roughness": 0.5})
	var fuse: MeshInstance3D = m.add_box(0.6, 0.9, 0.3, box_mat, -5.6, 1.3, 5.7)
	m.colliders.append(Rect2(-5.95, 5.5, 0.7, 0.4))
	var fuse_light: OmniLight3D = m.add_light(Color.html("8ab0c8"), 0.3, 3.0, -5.6, 1.8, 5.4, 0.1, false)
	var bat12 := Props.battery_prop(m)
	bat12.rotation.z = PI / 2.0
	bat12.position = Vector3(-5.2, 0.045, 5.4)
	m.floor_root.add_child(bat12)
	var bat_cb := func() -> void:
		m.G.flags["bat12F"] = true
		m.G.batteries += 1
		if is_instance_valid(bat12):
			bat12.free()
		m.H.show_msg("配电箱下面,电工作业垫上搁着一节电池。+1 电池", 4.2)
	var bat_cond := func() -> bool: return not m.G.flags.get("bat12F", false)
	m.add_inter(Vector3(-5.2, 0.4, 5.4), "配电箱下的电池", bat_cb, 1.8, bat_cond)
	var paper_mat: StandardMaterial3D = m.tex_mat("paper", "d8cfb4", {"roughness": 0.9})
	m.add_quad(1.1, 1.4, paper_mat, -6.35, 1.7, 3.4, PI / 2.0, 0.0)
	m.add_inter(Vector3(-6.0, 1.5, 3.4), "《住户须知》", func() -> void:
		m.open_modal({
			"title": "12F 天台 · 住户须知",
			"body": "一、天台风大,请勿靠近边缘。楼下的灯不是给人看的。\n\n二、雾中呼唤您的人,请勿回应。\n\n三、本层限停留一炷香。",
			"choices": [{"text": "记住了", "fn": func() -> void: m.close_modal()}],
		}), 2.0)
	# 远处"整栋楼灯火通明"(女儿墙外的自发光楼体)
	var city_mat: StandardMaterial3D = m.tex_mat("mural", "241a1e", {
		"emission": Color.html("6a5a30"), "emission_energy": 1.1, "roughness": 0.9,
	})
	var city: MeshInstance3D = m.add_quad(9.0, 12.0, city_mat, 0, 6.0, -18.0, 0.0, 0.0)
	city.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_light(Color.html("8a7a48"), 0.4, 20.0, 0, 5.0, -12.0, 0.0)
	var city_cb := func() -> void:
		if not m.G.flags.get("city12F", false):
			m.G.flags["city12F"] = true
			m.change_sanity(-8.0)
			m.H.red_flash()
			m.S.thud()
			m.H.show_msg("雾散开一角——对面立着的就是这栋楼,十三层,灯火通明。\n你所在的这层,黑着。理智 −8", 5.6)
		else:
			m.H.show_msg("对面那栋楼还亮着。它一直在看。")
	m.add_inter(Vector3(0, 1.4, -7.2), "雾中的大楼", city_cb, 2.4)
	# 半张全家福(雾边,循哭声)
	var photo_quad := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(0.34, 0.26)
	photo_quad.mesh = pq
	photo_quad.material_override = m.tex_mat("photo", "c8b48e", {"roughness": 0.85})
	photo_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	photo_quad.position = Vector3(-8.2, 0.02, -6.2)
	photo_quad.rotation = Vector3(-PI / 2.0, 0.0, 0.4)
	m.floor_root.add_child(photo_quad)
	var photo_cb := func() -> void:
		if m.G.flags.get("relic12F", false):
			m.H.show_msg("照片曾躺着的地方,雾散了一个角。")
			return
		m.G.flags["relic12F"] = true
		m.add_game_minutes(10)
		m.open_modal({
			"title": "半 张 全 家 福",
			"body": "烧焦的半张全家福:父亲搂着孩子,另外半边只剩焦黑的轮廓。\n\n雾里,一个孩子的哭声由远及近,喊着\"爸爸\"。\n两个身影在雾中一次次擦肩而过,像被永远隔开。\n你举起照片——照片的\"光线\"里,他们终于看见了彼此。\n\n\"爸爸,我看见你了。\"/\"手,一直没松。\"",
			"choices": [{"text": "收好照片", "fn": func() -> void:
				m.close_modal()
				m.gain_relic("半张全家福")
				m.change_sanity(2.0)
				m.after(2.8, func(): m.gain_card("13F"))
				m.after(5.6, func() -> void:
					m.H.show_msg("父子相拥的身影淡去。照片背面写着:\n\"一家三口,少了妈妈,也少了我们。\"\n雾,散了一角。", 6.0))
				m.H.set_objective("权限卡13F到手。乘电梯前往 13F —— 妹妹在 1304")}],
		})
	m.add_inter(Vector3(-8.2, 0.3, -6.2), "雾边的东西(哭声的源头)", photo_cb, 2.2)
	# 天台边缘(东侧缺口):跳下 → 回 1F(循环机制)
	var edge_cb := func() -> void:
		m.open_modal({
			"title": "边 缘",
			"body": "女儿墙在这里塌了一段。雾在脚下翻涌,深不见底。\n(雾里传来风声,和很远的、像是从楼下大堂传来的门铃。)",
			"choices": [
				{"text": "跳下去", "fn": func() -> void:
					m.close_modal()
					m.G.flags["looped12F"] = true
					m.H.show_msg("你跃入雾中。下坠,下坠——\n\"叮——\"电梯到了。大堂的灯,还亮着。", 5.0)
					m.after(2.0, func(): m.ride_to("1F", true))},
				{"text": "退回来", "fn": func() -> void: m.close_modal()},
			],
		})
	m.add_inter(Vector3(9.2, 1.0, -3.0), "塌掉的女儿墙(边缘)", edge_cb, 2.2)
	# 楼层逻辑:哭声方位提示 + 停留过久时间加速 + 风声
	var state := {"cry_t": 5.0, "stay_t": 0.0, "speed_msg": false, "speed_t": 0.0, "wind_t": 3.0}
	m.floor_update = func(dt: float) -> void:
		state["wind_t"] = state["wind_t"] - dt
		if state["wind_t"] <= 0.0:
			state["wind_t"] = 6.0 + randf() * 5.0
			m.S.whisper()
		if not m.G.flags.get("relic12F", false):
			state["cry_t"] = state["cry_t"] - dt
			if state["cry_t"] <= 0.0:
				state["cry_t"] = 8.0 + randf() * 6.0
				var dx: float = -8.2 - m.player_pos.x
				var dz: float = -6.2 - m.player_pos.z
				var dirx := "西" if dx < -0.5 else ("东" if dx > 0.5 else "")
				var dirz := "北" if dz < -0.5 else ("南" if dz > 0.5 else "")
				m.H.show_msg("雾里传来孩子的哭声……在%s%s方向。" % [dirz, dirx], 3.6)
		state["stay_t"] = state["stay_t"] + dt
		if state["stay_t"] > 45.0:
			if not state["speed_msg"]:
				state["speed_msg"] = true
				m.H.show_msg("你抬头看天——星星没动,手表却走了很久。\n这层的雾里,时间走得更快。", 5.0)
			state["speed_t"] = state["speed_t"] + dt
			if state["speed_t"] >= 4.0:
				state["speed_t"] = 0.0
				m.add_game_minutes(1)
	m.tp_list([
		{"x": -8.2, "z": -5.0, "yaw": 0.0},
		{"x": 0.0, "z": -5.5, "yaw": 0.0},
		{"x": -5.2, "z": 4.5, "yaw": PI},
		{"x": 9.2, "z": -3.0, "yaw": -PI / 2.0},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("12F 天台。循着哭声,找到雾边的那样东西")
	m.H.show_msg("12F。浓雾压着天台。对面——整栋楼,灯火通明。", 5.6)
