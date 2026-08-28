extends RefCounted
## 8F 档案室

static func build(m) -> void:
	m.setup_env(0.11, Color.html("3a3a2c"), Color.html("080805"), 0.05)
	FloorCommon.room_shell(m, 20.0, 16.0)
	FloorCommon.build_elevator(m)
	m.add_light(Color.html("d8d0a0"), 0.4, 12.0, 0, 2.9, -2.0, 0.18)
	m.add_light(Color.html("c8c098"), 0.3, 8.0, 6.5, 2.4, 4.0, 0.22, false)
	# 铁皮柜两排(迷宫式掩体):北排朝南,中排朝北
	var cab_poses: Array = [
		[-6.0, -4.5, 0.0], [-2.0, -4.5, 0.0], [2.0, -4.5, 0.0], [6.0, -4.5, 0.0],
		[-6.0, 0.5, PI], [-2.0, 0.5, PI], [2.0, 0.5, PI], [6.0, 0.5, PI],
	]
	for p: Array in cab_poses:
		Props.file_cabinet(m, p[0], p[1], p[2])
		m.colliders.append(Rect2(p[0] - 0.45, p[1] - 0.25, 0.9, 0.5))
	# 阅读区(+X 前角):长桌 + 台灯 + 暗格
	Props.wood_desk(m, 7.5, 4.5, -PI / 2.0, 2.2, 1.0, 0.85, "5a4e3a")
	m.colliders.append(Rect2(7.5 - 0.5, 4.5 - 1.1, 1.0, 2.2))
	m.safe_spot(7.5, 4.5, 1.8)
	m.add_light(Color.html("e8c890"), 0.5, 5.0, 6.6, 1.5, 4.5, 0.06, false)
	# 档案柜甲:住户档案(氛围)
	m.add_inter(Vector3(-6.0, 1.2, -3.9), "住户档案柜", func() -> void:
		m.open_modal({
			"title": "住 户 档 案",
			"body": "一格一格的档案卡,按户号排着。\n陈守财,2F,殁于大火。\n苏梅,3F,殁于大火。\n赵大河、赵二河、赵小河,7F,殁于大火。\n……\n每一张卡的死亡日期,都是 2008-06-13。",
			"choices": [{"text": "合上抽屉", "fn": func() -> void: m.close_modal()}],
		}), 2.2)
	# 档案柜乙:林砚与林音的档案(转折三:死亡日期"明天")
	var files_cb := func() -> void:
		if not m.G.flags.get("files8F", false):
			m.G.flags["files8F"] = true
			m.change_sanity(-12.0)
			m.H.red_flash()
			m.S.sting()
			m.shake = 1.8
			m.open_modal({
				"title": "档 案 卡 · 终",
				"body": "最里层,两张并排的档案卡:\n\n【林砚】户号:1304(借)|入住日期:今夜|死亡日期:明天\n备注:保险。悔恨浓度:培育中。回收方式:自愿。\n\n【林音】户号:1304|入住日期:七日前|死亡日期:明天(待定)\n备注:容器候选。肉身封存于 B2。\n\n理智 −12",
				"choices": [{"text": "把卡片攥进手心", "fn": func() -> void:
					m.close_modal()
					m.H.show_msg("档案室的温度骤降,灯管闪了起来。身后传来一个女声:\n\"我早就想把真相报上去……可他们把我的死亡日期,改成了明天。\"", 6.4)
					m.S.whisper()}],
			})
		else:
			m.H.show_msg("两张档案卡还插在原处。\"明天\"两个字,像刚写上去的。")
	m.add_inter(Vector3(-2.0, 1.2, -3.9), "写着\"林\"的档案柜", files_cb, 2.2)
	# 档案柜丙:药典(辨别 4F 真假药)
	var codex_cb := func() -> void:
		if not m.G.knows_pills:
			m.G.knows_pills = true
			m.open_modal({
				"title": "药 典(宗 08)",
				"body": "\"本院镇静片批号尾数为奇数者,皆为大火后收回之物。\n服之非但不能安神,反令人见影。切记,切记。\"\n\n(批号尾数:药瓶A=2048,偶数,真药;药瓶B=2051,奇数,假药。)\n\n背包里的两瓶药,标签忽然清楚了。",
				"choices": [{"text": "记牢批号", "fn": func() -> void:
					m.close_modal()
					m.H.show_msg("批号尾数是奇数的 B 瓶,是假药。A 瓶是真的。", 5.0)}],
			})
		else:
			m.H.show_msg("药典还是那一页:尾数奇数为假。")
	m.add_inter(Vector3(2.0, 1.2, -3.9), "药典柜", codex_cb, 2.2)
	# 阅读区暗格:调查报告(需先读到"林"档案)→ 遗物 + 权限卡9F
	var report_cb := func() -> void:
		if not m.G.flags.get("files8F", false):
			m.H.show_msg("桌板下有个暗格,锁着。得先找到属于\"林\"的那两份档案,才知道钥匙的形状。", 4.6)
			return
		if m.G.flags.get("relic8F", false):
			m.H.show_msg("暗格空了。红笔改过的那行字,还在脑子里。")
			return
		m.G.flags["relic8F"] = true
		m.add_game_minutes(10)
		m.open_modal({
			"title": "封 存 调 查 报 告",
			"body": "暗格里滑出一份牛皮纸袋装的报告(沈如梅,2008-05):\n\"永宁大楼自 1992 年投用以来,电气事故、夜间失踪、非正常死亡记录均远超同类楼宇,物业一律以'线路老化''自行搬离'结案……建议上级部门介入彻查。\"\n\n报告末行被红笔改写:\n\"报告人沈如梅,死亡日期:明天。此件封存,永不呈报。\"",
			"choices": [{"text": "收下档案袋", "fn": func() -> void:
				m.close_modal()
				m.gain_relic("牛皮档案袋")
				m.after(2.6, func(): m.gain_card("9F"))
				m.after(5.6, func() -> void:
					m.change_sanity(2.0)
					m.H.show_msg("\"档案能改,日期能改,唯独事实改不了。这楼吃人,是真的。\"\n沈如梅的身影在柜间一闪,散成纸屑一样的光。理智 +2", 6.2))
				m.H.set_objective("权限卡9F到手。乘电梯前往 9F 镜像层")}],
		})
	m.add_inter(Vector3(7.5, 0.8, 4.5), "阅读桌下的暗格", report_cb, 2.2)
	# 管理员手册残条(北墙,出口钥匙线索)
	var paper_mat: StandardMaterial3D = m.tex_mat("paper", "d8cfb4", {"roughness": 0.9})
	m.add_quad(1.0, 1.3, paper_mat, 0, 1.7, -7.78, 0.0, 0.0)
	m.add_inter(Vector3(0, 1.5, -7.5), "《管理员手册》残条", func() -> void:
		m.open_modal({
			"title": "管 理 员 手 册(残)",
			"body": "一、楼内一切告示,以本手册为准;其余告示真伪,自行甄别。\n二、13 层非必要不停靠。停靠申请一律驳回。\n三、回收对象:违规者、窥视者、记住名字的人。\n四、守楼人交接:旧钥匙不外借。1304 的门,不许开。\n五、(字迹潦草,似后人添写)要是有人能念完那些名字……就让他念吧。\n\n——落款:周。",
			"choices": [{"text": "放回原处", "fn": func() -> void: m.close_modal()}],
		}), 2.2)
	# 住户须知(电梯口)
	m.add_quad(1.1, 1.4, paper_mat, -2.4, 1.7, 7.6, PI, 0.0)
	m.add_inter(Vector3(-2.4, 1.5, 7.3), "《住户须知》", func() -> void:
		m.open_modal({
			"title": "8F 档案室 · 住户须知",
			"body": "一、档案只可查阅,不可带出。\n\n二、死亡日期为\"明天\"的档案,请放回原处,勿念出声。\n\n三、闭馆后请沿灯亮的柜间行走。",
			"choices": [{"text": "记住了", "fn": func() -> void: m.close_modal()}],
		}), 2.0)
	# 楼层逻辑:柜门弹开声(随机一列柜) + 灯管闪烁靠 lights flicker 自带
	var cab_x: Array = [-6.0, -2.0, 2.0]
	var state := {"thud_t": 6.0}
	m.floor_update = func(dt: float) -> void:
		state["thud_t"] = state["thud_t"] - dt
		if state["thud_t"] <= 0.0:
			state["thud_t"] = 7.0 + randf() * 9.0
			m.S.play_at("thud", Vector3(cab_x[randi() % cab_x.size()], 1.2, -3.9), 1.3)
			if randf() < 0.3:
				m.H.show_msg("哪个柜门\"咣\"地弹开一条缝,又自己合上了。", 3.2)
	m.tp_list([
		{"x": -6.0, "z": -3.4, "yaw": 0.0},
		{"x": -2.0, "z": -3.4, "yaw": 0.0},
		{"x": 2.0, "z": -3.4, "yaw": 0.0},
		{"x": -2.0, "z": 1.6, "yaw": PI},
		{"x": 7.5, "z": 3.0, "yaw": PI},
		{"x": 0.0, "z": -6.4, "yaw": 0.0},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("8F 档案室。找到\"林\"的档案、药典、暗格里的调查报告")
	m.H.show_msg("8F。铁皮柜排成沉默的队列。灰尘里有翻动纸页的声音。", 5.2)
