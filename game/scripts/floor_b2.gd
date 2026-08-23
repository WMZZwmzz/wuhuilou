extends RefCounted
## B2 锅炉房("母亲"核心,四结局)

static func build(m) -> void:
	m.setup_env(0.1, Color.html("381a18"), Color.html("160608"), 0.07)
	FloorCommon.room_shell(m, 20.0, 16.0)
	FloorCommon.build_elevator(m)
	# 肉壁(北/西/东三面内衬)
	var flesh_mat: StandardMaterial3D = m.tex_mat("flesh", "6e3230", {
		"normal": m.T.tex.get("flesh_n"), "normal_scale": 0.8,
		"roughness": 0.75, "emission": Color.html("401418"), "emission_energy": 0.35,
	})
	m.add_quad(19.0, 3.0, flesh_mat, 0, 1.6, -7.79, 0.0, 0.0)
	m.add_quad(15.0, 3.0, flesh_mat, -9.79, 1.6, 0, PI / 2.0, 0.0)
	m.add_quad(15.0, 3.0, flesh_mat, 9.79, 1.6, 0, -PI / 2.0, 0.0)
	# 锅炉 ×3 + 管道
	for p: Array in [[-6.0, -5.0], [6.0, -5.0], [-6.5, 4.5]]:
		Props.boiler_unit(m, p[0], p[1], 0.0)
		m.colliders.append(Rect2(p[0] - 0.8, p[1] - 0.8, 1.6, 1.6))
		m.add_light(Color.html("e05a3a"), 0.4, 5.5, p[0], 2.4, p[1], 0.3)
	# 核心("母亲"):球簇 + 脉动红光
	var core := Node3D.new()
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color.html("7a2c28")
	core_mat.roughness = 0.55
	core_mat.emission_enabled = true
	core_mat.emission = Color.html("a8282a")
	core_mat.emission_energy_multiplier = 0.8
	var big := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.85
	bs.height = 1.7
	big.mesh = bs
	big.material_override = core_mat
	big.position = Vector3(0, 1.5, 0)
	core.add_child(big)
	for p: Array in [[0.7, 0.9, 0.3], [-0.6, 2.1, -0.2], [0.3, 2.2, 0.5], [-0.75, 0.8, -0.4]]:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.3
		sm.height = 0.6
		s.mesh = sm
		s.material_override = core_mat
		s.position = Vector3(p[0], p[1], p[2])
		core.add_child(s)
	core.position = Vector3(0, 0, -5.6)
	m.floor_root.add_child(core)
	m.colliders.append(Rect2(-1.0, -6.6, 2.0, 2.0))
	var core_light: OmniLight3D = m.add_light(Color.html("c83a30"), 0.9, 9.0, 0, 2.0, -5.6, 0.0)
	# 锁孔(肉壁中央,旧钥匙归还点)
	var lock: MeshInstance3D = m.add_box(0.16, 0.3, 0.1, m.pmat({"color": Color.html("1a1012"), "metallic": 0.5, "roughness": 0.4}), 0, 1.4, -7.72, false)
	lock.rotation.z = 0.12
	# 熄灯仪式圈:13 座小台(环阵)
	var ring_mat: StandardMaterial3D = m.pmat({"color": Color.html("5a4038"), "roughness": 0.8})
	for i in 13:
		var ang := i * TAU / 13.0
		var ped := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.12
		pc.bottom_radius = 0.15
		pc.height = 0.34
		ped.mesh = pc
		ped.material_override = ring_mat
		ped.position = Vector3(cos(ang) * 3.4, 0.17, 1.5 + sin(ang) * 3.4)
		m.floor_root.add_child(ped)
	# ---------- 对质与四结局 ----------
	var final_choice := func() -> void:
		var ch: Array = []
		if m.G.relics >= 13:
			ch.append({"text": "举行熄灯仪式(13 件遗物)", "fn": func() -> void:
				m.close_modal()
				m.open_modal({
					"title": "熄 灯 仪 式(一)· 布 阵",
					"body": "十三件遗物在锅炉房摆成一个圈,逐件亮起。\n你依次念出名字——\n\"陈守财。\"……胡了。替我把赢回来的钱,给她上坟烧了吧。\n\"苏梅。\"……孩子们都出去了。老师现在,真的下课了。\n\"韩立群。\"……听诊器给你。这一次,听见的是活人的心跳。\n\"李杰。\"……删掉了。这次,我记住门在哪了。\n\"周雨。\"……门牌给你。这回,我认得回家的门了。\n\"赵守一。\"……这炷香,我自己收到了。",
					"choices": [{"text": "继续念名", "fn": func() -> void:
						m.close_modal()
						m.open_modal({
							"title": "熄 灯 仪 式(二)· 归 还",
							"body": "\"沈如梅。\"……日期改回来了。真相,报上去了。\n\"顾影。\"……镜子合上了。原来完整的我,一直都在。\n\"许文远。\"……她到了。我们拜过堂了。谢谢你的那个座。\n\"王桂枝。\"……封印完成了。剩下的名字,你替我念完了。\n\"陆国栋、陆小虎。\"……爸爸,我看见你了。/手,一直没松。\n\"周守正。\"……钥匙交出去了。这差事,总算卸了。\n\n你取出那把旧钥匙,插进肉壁中央的锁孔。\n\"咔哒。\"——2008 年那晚没能打开的 1304 的门,开了。\n你念出最后的名字:\"林音。\"\n黑暗中,一个轻轻的声音回答:\"砚哥。\"\n你熄灭了楼内所有的灯。",
							"choices": [{"text": "熄灯", "fn": func() -> void:
								m.close_modal()
								m.S.sting()
								m.shake = 2.6
								m.get_tree().create_timer(1.6).timeout.connect(func(): m.start_ending("true"))}],
						})}],
				})})
		else:
			ch.append({"text": "举行熄灯仪式", "disabled": true, "reason": "遗物不足(%d/13)" % m.G.relics})
		ch.append({"text": "摧毁核心(以命换命)", "fn": func() -> void:
			m.close_modal()
			m.open_modal({
				"title": "摧 毁",
				"body": "你抄起断裂的管道,砸向锅炉与肉壁的节点。\n核心暴怒,火焰与怨念席卷整层——\n就在冲击迎面而来的瞬间,一个穿着保安服的身影挡在你身前。\n\"守楼的,这次守住你了。\"老周化作灰烬。\n你用尽全力,把闻声赶来的妹妹推向出口。",
				"choices": [{"text": "\"跑。别回头。\"", "fn": func() -> void:
					m.close_modal()
					m.S.sting()
					m.shake = 2.6
					m.get_tree().create_timer(1.6).timeout.connect(func(): m.start_ending("sacrifice"))}],
			})})
		if m.G.flags.get("knowsTrueVoice", false):
			ch.append({"text": "换回妹妹——我留下", "disabled": true, "reason": "你已识破它的伪装"})
		else:
			ch.append({"text": "换回妹妹——我留下", "fn": func() -> void:
				m.close_modal()
				m.S.sting()
				m.shake = 2.0
				m.get_tree().create_timer(1.4).timeout.connect(func(): m.start_ending("replace"))})
		if m.G.flags.get("hasExitKey", false):
			ch.append({"text": "转身,用出口钥匙逃出大门", "fn": func() -> void:
				m.close_modal()
				m.S.ding()
				m.get_tree().create_timer(1.4).timeout.connect(func(): m.start_ending("escape"))})
		else:
			ch.append({"text": "转身逃出大门", "disabled": true, "reason": "没有出口钥匙"})
		m.open_modal({
			"title": "抉 择",
			"body": "核心仍在切换声线,一会儿是妹妹,一会儿是你早已离世的母亲。\n肉壁上无数张脸浮起又沉没,像溺在水里的人。\n\n你贴身收着 %d 件遗物。天,快亮了。" % m.G.relics,
			"choices": ch,
		})
	var hug_modal := func() -> void:
		m.open_modal({
			"title": "拟 声",
			"body": "\"哥,只要你愿意留下,我就放她走。\"\n核心的轮廓隆起,快要变成妹妹的形状——永远差一点。\n它的声音干净得没有一丝呼吸。",
			"choices": [
				{"text": "我愿意,换她走(留下)", "fn": func() -> void:
					m.close_modal()
					m.S.sting()
					m.shake = 2.0
					m.get_tree().create_timer(1.4).timeout.connect(func(): m.start_ending("replace"))},
				{"text": "推开她——不对劲", "fn": func() -> void:
					m.close_modal()
					m.G.flags["knowsTrueVoice"] = true
					m.H.show_msg("你猛地退开。它学得再像,也只会叫你\"哥\"。", 4.2)
					m.get_tree().create_timer(1.6).timeout.connect(func(): final_choice.call())},
			],
		})
	var core_cb := func() -> void:
		if m.G.flags.get("ended", false):
			return
		m.open_modal({
			"title": "核 心 · \"母 亲\"",
			"body": "锅炉房的最深处,怨念聚成一颗缓慢搏动的\"心脏\"。\n它开口了,是妹妹的声音:\n\"哥,我好冷,你过来抱抱我……\"",
			"choices": [
				{"text": "试探:\"音,你叫我什么?\"", "fn": func() -> void:
					m.close_modal()
					m.open_modal({
						"title": "拟 声",
						"body": "它顿了顿:\n\"哥?……哥,你怎么了,我是音音啊。\"\n音色完美。称呼——它只会叫\"哥\"。\n(日记里写得很清楚:真正的林音,只叫你\"砚哥\"。)",
						"choices": [
							{"text": "你不是她——她只叫我\"砚哥\"", "fn": func() -> void:
								m.close_modal()
								m.G.flags["knowsTrueVoice"] = true
								m.change_sanity(4.0)
								m.H.show_msg("\"哥——哥——哥——\"\n声音碎了,一层层剥落成许多人的哭喊。\n它骗不过你。理智 +4", 5.0)
								m.get_tree().create_timer(2.4).timeout.connect(func(): final_choice.call())},
							{"text": "过去,抱住她", "fn": func() -> void:
								m.close_modal()
								hug_modal.call()},
						],
					})},
				{"text": "直接走近", "fn": func() -> void:
					m.close_modal()
					hug_modal.call()},
			],
		})
	m.add_inter(Vector3(0, 1.4, -4.6), "核心(\"母亲\")", core_cb, 2.4)
	# 锁孔(氛围交互)
	m.add_inter(Vector3(0, 1.4, -7.4), "肉壁上的锁孔", func() -> void:
		if m.G.flags.get("hasExitKey", false):
			m.H.show_msg("锁孔的形状,正对着钥匙串里那把打不开任何门的旧钥匙。\n——等十三件遗物都到齐,再回来。", 4.6)
		else:
			m.H.show_msg("肉壁上嵌着一把老式的锁孔,像一扇门被活活长死在墙里。", 4.2), 1.8)
	# 楼层逻辑:核心脉动 + 低鸣 + 心跳声压
	var state := {"pulse": 0.0}
	m.floor_update = func(dt: float) -> void:
		state["pulse"] = state["pulse"] + dt
		var p: float = 0.75 + 0.35 * sin(state["pulse"] * 2.2)
		if is_instance_valid(core_light):
			core_light.light_energy = 1.8 * p
		if is_instance_valid(core):
			core.scale = Vector3.ONE * (0.96 + 0.06 * p)
	m.tp_list([
		{"x": 0.0, "z": -3.4, "yaw": 0.0},
		{"x": 0.0, "z": -6.4, "yaw": 0.0},
		{"x": 0.0, "z": 4.6, "yaw": 0.0},
		{"x": 1.55, "z": 7.2, "yaw": PI},
	])
	m.H.set_objective("B2 锅炉房。面对\"母亲\"——辨出真声,做出最后的抉择")
	m.H.show_msg("B2。墙在呼吸。整栋楼的心跳,在你面前搏动。\n它在用妹妹的声音,叫你。", 6.0)
