extends RefCounted
## 9F 镜像层

static func build(m) -> void:
	m.setup_env(0.15, Color.html("3c4248"), Color.html("0a0d10"), 0.06)
	FloorCommon.room_shell(m, 20.0, 16.0)
	FloorCommon.build_elevator(m)
	m.add_light(Color.html("c8d4e0"), 0.5, 12.0, 0, 2.9, 0, 0.1)
	# 走廊立镜 ×5(北墙)+ 镜厅(-Z 端,同步谜题)
	for x: float in [-7.5, -4.5, -1.5, 1.5, 4.5]:
		Props.mirror_stand(m, x, -6.0, 0.0)
		m.colliders.append(Rect2(x - 0.45, -6.3, 0.9, 0.6))
	# 镜像复制体:黑色人形,镜像 x、延迟 0.5s 跟随玩家
	var replica := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(0.8, 1.8)
	replica.mesh = rq
	var rmat := StandardMaterial3D.new()
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(0.02, 0.02, 0.04, 0.9)
	replica.material_override = rmat
	replica.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.floor_root.add_child(replica)
	# 影子(黑暗实体化)
	var shadow := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(0.9, 2.0)
	shadow.mesh = sq
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0, 0, 0, 0.92)
	shadow.material_override = smat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.visible = false
	m.floor_root.add_child(shadow)
	# 同步谜题(镜厅中央标记点)
	var mark := MeshInstance3D.new()
	var mq := CylinderMesh.new()
	mq.top_radius = 0.6
	mq.bottom_radius = 0.6
	mq.height = 0.02
	mark.mesh = mq
	mark.material_override = m.pmat({"color": Color.html("8a929c"), "emission": Color.html("6a7484"), "emission_energy": 0.7, "roughness": 0.4})
	mark.position = Vector3(0, 0.012, -4.0)
	m.floor_root.add_child(mark)
	m.add_light(Color.html("b8c8dc"), 0.4, 6.0, 0, 2.4, -4.0, 0.08)
	var solve_mirror := func() -> void:
		m.G.flags["mirror9F"] = true
		m.add_game_minutes(10)
		if is_instance_valid(replica):
			replica.visible = false
		if is_instance_valid(shadow):
			shadow.visible = false
		m.S.sting()
		m.shake = 2.4
		m.H.show_msg("整面镜墙\"哗啦\"碎裂。碎片在地面拼出一个人形,缓缓站起——\n一半是你,一半是别的什么。", 6.0)
		m.get_tree().create_timer(4.2).timeout.connect(func() -> void:
			m.gain_relic("裂成两半的镜子")
			m.change_sanity(2.0))
		m.get_tree().create_timer(7.2).timeout.connect(func() -> void:
			m.H.show_msg("\"火灾毁了我的脸。镜子里那个人,一半是我,一半是我害怕的样子。\"\n\"谢谢你,让我看清楚。\"——她合拢两半镜子,裂纹消失了。理智 +2", 6.4))
		m.get_tree().create_timer(10.6).timeout.connect(func(): m.gain_card("10F"))
		m.H.set_objective("权限卡10F到手。乘电梯前往 10F 宴会厅")
	var sync_cb := func() -> void:
		if m.G.flags.get("mirror9F", false):
			m.H.show_msg("碎镜还躺在地上,拼出半个人形。已经安静了。")
			return
		m.open_modal({
			"title": "镜 中 同 步",
			"body": "你站上标记。镜中的\"你\"比你慢半拍——\n此刻,它却先抬起了手,静静等你跟上。\n\n(要在它放下去之前,做完同样的三个动作。)",
			"choices": [
				{"text": "抬手 → 转身 → 下蹲,与镜中同步", "fn": func() -> void:
					m.close_modal()
					solve_mirror.call()},
				{"text": "抬手 → 下蹲 → 转身(顺序乱了)", "fn": func() -> void:
					m.close_modal()
					m.change_sanity(-m.G.NUM["violation"])
					m.H.red_flash()
					m.S.sting()
					m.H.show_msg("镜中的你停住了。它先转身,背对你——\n你背后有什么东西贴了上来,冰的。理智 −15", 5.4)},
				{"text": "不等了,一拳砸碎镜子", "fn": func() -> void:
					m.close_modal()
					m.change_sanity(-10.0)
					solve_mirror.call()},
			],
		})
	m.add_inter(Vector3(0, 1.0, -4.0), "镜厅标记(同步)", sync_cb, 2.2)
	# 镜厅角落的电池(数值平衡表:9F–10F ×2 之第一枚)
	var bat9 := Props.battery_prop(m)
	bat9.rotation.z = PI / 2.0
	bat9.position = Vector3(-8.6, 0.045, -6.0)
	m.floor_root.add_child(bat9)
	var bat_cb := func() -> void:
		m.G.flags["bat9F"] = true
		m.G.batteries += 1
		if is_instance_valid(bat9):
			bat9.free()
		m.H.show_msg("立镜的夹缝里掉出一节电池。+1 电池", 4.2)
	var bat_cond := func() -> bool: return not m.G.flags.get("bat9F", false)
	m.add_inter(Vector3(-8.6, 0.4, -6.0), "立镜夹缝的电池", bat_cb, 1.8, bat_cond)
	# 住户须知(电梯口左侧,避开呼梯面板交互)
	var paper_mat: StandardMaterial3D = m.tex_mat("paper", "d8cfb4", {"roughness": 0.9})
	m.add_quad(1.1, 1.4, paper_mat, -2.4, 1.7, 7.6, PI, 0.0)
	m.add_inter(Vector3(-2.4, 1.5, 7.3), "《住户须知》", func() -> void:
		m.open_modal({
			"title": "9F 镜像层 · 住户须知",
			"body": "一、请勿与您的镜像同时抬手。\n\n二、若镜中人先动,请立刻闭眼数到三。\n\n三、打破镜子者,自负其责。",
			"choices": [{"text": "记住了", "fn": func() -> void: m.close_modal()}],
		}), 2.0)
	# 楼层逻辑:镜像延迟复制 + 影子黑暗实体化(解谜后两者皆退场)
	var state := {"hist": [], "dark_t": 0.0, "shadow_msg": false}
	m.floor_update = func(dt: float) -> void:
		if m.G.flags.get("mirror9F", false):
			return
		# 镜像:记录 0.5s 前的位置,镜像 x 呈现
		state["hist"].append({"x": m.player_pos.x, "z": m.player_pos.z, "t": Time.get_ticks_msec() / 1000.0})
		var now: float = Time.get_ticks_msec() / 1000.0
		while state["hist"].size() > 2 and state["hist"][0]["t"] < now - 0.5:
			state["hist"].pop_front()
		if is_instance_valid(replica) and state["hist"].size() > 0:
			var old: Dictionary = state["hist"][0]
			replica.position = Vector3(-float(old["x"]), 1.0, float(old["z"]))
			replica.look_at(Vector3(m.player_pos.x, 1.0, m.player_pos.z))
		# 影子:连续黑暗 5s 实体化,光照立即消散
		var lit: bool = m.G.flash_on and m.G.battery > 0.0
		if lit:
			state["dark_t"] = 0.0
			if is_instance_valid(shadow) and shadow.visible:
				shadow.visible = false
				m.H.show_msg("手电的光扫过去,那团更深的黑\"嘶\"地散了。", 3.2)
		else:
			state["dark_t"] += dt
			if state["dark_t"] > 5.0 and is_instance_valid(shadow):
				if not shadow.visible:
					shadow.visible = true
					shadow.position = m.player_pos + m.cam_forward() * 5.0 + Vector3(0, 1.0, 0)
					if not state["shadow_msg"]:
						state["shadow_msg"] = true
						m.S.thud()
						m.H.show_msg("镜中的影子脱离了你,站在光的边界之外。\n黑暗里,它开始走来。", 4.6)
				var dir: Vector3 = m.player_pos - shadow.position
				dir.y = 0.0
				if dir.length() > 0.05:
					shadow.position += dir.normalized() * 1.0 * dt
					shadow.look_at(Vector3(m.player_pos.x, shadow.position.y, m.player_pos.z))
				if dir.length() < 1.2:
					state["dark_t"] = 0.0
					shadow.visible = false
					m.change_sanity(-10.0)
					m.H.red_flash()
					m.S.sting()
					m.H.show_msg("冰冷的指尖掐上你的后颈,又化作烟。理智 −10\n(开手电[F]——光,是它的边界。)", 5.0)
	m.tp_list([
		{"x": 0.0, "z": -2.8, "yaw": 0.0},
		{"x": -4.5, "z": -4.6, "yaw": 0.0},
		{"x": 5.0, "z": 2.0, "yaw": PI},
		{"x": 1.55, "z": 6.2, "yaw": PI},
	])
	m.H.set_objective("9F 镜像层。站上标记,与镜中的\"你\"同步(小心黑暗)")
	m.H.show_msg("9F。整层的镜子里,都是你——慢半拍的你。", 5.2)
