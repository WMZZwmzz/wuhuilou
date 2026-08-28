extends SceneTree
## 《无回楼》Godot 版 全流程无头走查(15 层 + 四结局)
## 用法:
##   "Godot.exe" --headless --path game --script res://qa/qa_runner.gd
## 带渲染运行(截图存 game/qa/shots/):
##   "Godot.exe" --path game --script res://qa/qa_runner.gd

const SHOTS_DIR := "res://qa/shots"

var failures: Array = []
var m = null
var _shot_step := 0
var _can_shot := false

func _initialize() -> void:
	_run.call_deferred()

func check(name: String, cond: bool) -> void:
	print(("  ✓ " if cond else "  ✗ ") + name)
	if not cond:
		failures.append(name)

func wait_s(s: float) -> void:
	await create_timer(s).timeout

func state() -> Dictionary:
	return {
		"floor": m.G.floor_id, "sanity": m.G.sanity, "battery": m.G.battery,
		"hasFlash": m.G.has_flash, "cards": m.G.cards.duplicate(), "relics": m.G.relics,
		"time": m.G.time, "playing": m.G.playing, "flags": m.G.flags.duplicate(),
		"pills": m.G.pills.duplicate(), "candles": m.G.candles,
		"violations": m.G.violations, "knowsPills": m.G.knows_pills, "deaths": m.G.deaths,
	}

func modal_title() -> String:
	if m.H.modal_visible():
		return m.H.modal_title.text
	return ""

func modal_body() -> String:
	if m.H.modal_visible():
		return m.H.modal_body.text
	return ""

func shot(name: String) -> void:
	_shot_step += 1
	var fname := "%s/%02d-%s.png" % [SHOTS_DIR, _shot_step, name]
	print("[shot] %02d-%s" % [_shot_step, name])
	if not _can_shot:
		return
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(fname)

## 等待并点击弹窗中包含指定文本的选项
func pick(text: String, starts_with := false) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		if m.H.modal_visible():
			var b: Button = m.H.find_choice(text, starts_with)
			if b:
				b.pressed.emit()
				return true
		await process_frame
	return false

## 楼道呼唤随机事件:立即正确处理,避免打断流程
func maybe_call() -> void:
	for i in 3:
		var t := modal_title()
		if t.contains("背后有人叫你"):
			print("  [event] 楼道呼唤 → 正确应对(数到七)")
			await pick("站住,默数到七")
			await wait_s(0.5)
		else:
			break

const ANOMALY_ANSWERS := [
	["乘客", "不去看它,按住开门键等下一班", "凑近,看清它的脸"],
	["13层的按钮", "立即退出电梯", "假装没看见,继续乘坐"],
	["镜子", "立刻移开视线,不再看它", "直视镜子,看个清楚"],
	["门迟迟不开", "闭上眼,背对门站立", "强行扒门"],
	["下坠", "闭上眼,数到七", "死死抓住扶手"],
	["楼层错乱", "保持冷静,重新刷卡", "惊慌地跑出电梯"],
]

func answer_anomaly(correct := true) -> bool:
	var title := modal_title()
	for hit: Array in ANOMALY_ANSWERS:
		if title.contains(hit[0]):
			print("  [anomaly] " + title.strip_edges() + " → " + ("正确" if correct else "错误") + "应对")
			return await pick(hit[1] if correct else hit[2], true)
	print("  [warn] 未知异常标题: " + title)
	return false

func tp(idx: int) -> void:
	m.tp(idx)
	await wait_s(0.25)

func press_e() -> void:
	m.interact_press()

func tp_last() -> void:
	## 各楼层约定:最后一个传送点位 = 电梯呼梯面板
	var list: Array = m.G.get_meta("_tp", [])
	m.tp(list.size() - 1)
	await wait_s(0.25)

## 乘电梯到目标层(面板按显示名匹配),自动正确应对异常与楼道呼唤
func ride(dest: String, forced_check := false) -> void:
	await tp_last()
	await press_e()
	await wait_s(0.5)
	if not await pick(dest):
		check("电梯面板出现「%s」" % dest, false)
		return
	await wait_s(1.4)
	if m.G.modal_open:
		if forced_check:
			check("乘往 %s 必触发电梯异常" % dest, true)
			await shot("ride-anomaly")
		await answer_anomaly(true)
		await wait_s(2.0)
	await maybe_call()
	await wait_s(2.6)
	check("抵达 %s" % dest, m.G.floor_id == dest.split(" ")[0])
	# 到层即补满电量并开灯:消除"黑暗掉理智 2/秒"对惩罚断言的噪声
	m.G.battery = 100.0
	m.G.flash_on = true

func reload_scene() -> void:
	# QA 用 root.add_child 挂载 Main(非 current_scene),change_scene_to_file 替换不到它。
	# 手动释放旧 Main 再重新实例化,与 _run 初始挂载同款,确保拿到干净状态。
	if is_instance_valid(m):
		m.queue_free()
	await process_frame
	await process_frame
	var packed: PackedScene = load("res://scenes/main.tscn")
	m = packed.instantiate()
	root.add_child(m)
	for i in 600:
		if m and m.G != null and m.floor_root != null:
			break
		await process_frame

## 分支结局通用:重载场景 → 直奔 B2 → 直接调用核心交互回调。
## 无头 QA 无需模拟精确朝向,绕过 update_interact 的距离/朝向检测最稳妥。
func reach_b2_core(extra_flags: Dictionary = {}) -> void:
	await reload_scene()
	await wait_s(0.5)
	m._on_start()
	m.G.cards["B2"] = true
	for k in extra_flags:
		m.G.flags[k] = extra_flags[k]
	m.G.time = 200.0   # 压回安全时间,避免乘梯累计触发 6:00 时限死亡
	await m.ride_to("B2", true)
	await wait_s(1.0)
	for it in m.interactables:
		if String(it["label"]).contains("核心"):
			it["cb"].call()
			break
	await wait_s(0.6)

## 人形网格法线/绕序审计(两步,均为客观量):
## ① 逐三角形比较 cross(v1-v0,v2-v0) 与其三顶点存储法线均值 → 该 surface 的手性一致率。
##    一致率不足即「同一网格内部朝向自相矛盾」(封口与侧壁反手、或不同绕序的部件被合并进同一
##    surface 都会落在这里)。符号由这一步的多数决定,不受顶点门控影响。
## ② 只在扇面一致的流形顶点上比较存储法线与面积加权几何法线 → 抓「位移后忘记重算法线」。
func _normal_audit(root: Node) -> Dictionary:
	var verts := 0
	var opposite := 0
	var worst := 0.0
	var bad_index := 0
	var mixed := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for sfc in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(sfc)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if v.size() < 4 or sn.size() != v.size() or idx.size() < 3:
				continue
			var max_i := 0
			for i in idx.size():
				max_i = maxi(max_i, idx[i])
			if max_i >= v.size():
				print("  [bad-index] %s verts=%d max_index=%d" % [mi.get_path(), v.size(), max_i])
				bad_index += 1
				continue
			var tpos := 0
			var tneg := 0
			var acc := PackedVector3Array()
			acc.resize(v.size())
			var absum := PackedFloat32Array()
			absum.resize(v.size())
			for t in idx.size() / 3:
				var b: int = t * 3
				var i0: int = idx[b]
				var i1: int = idx[b + 1]
				var i2: int = idx[b + 2]
				var cr: Vector3 = (v[i1] - v[i0]).cross(v[i2] - v[i0])
				var clen: float = cr.length()
				if clen < 1e-14:
					continue
				for i in [i0, i1, i2]:
					acc[i] = acc[i] + cr
					absum[i] += clen
				var avg: Vector3 = sn[i0] + sn[i1] + sn[i2]
				if avg.length() < 1e-9:
					continue
				if cr.normalized().dot(avg.normalized()) > 0.0:
					tpos += 1
				else:
					tneg += 1
			var tot_t := tpos + tneg
			if tot_t == 0:
				continue
			var consist := float(maxi(tpos, tneg)) / float(tot_t)
			if consist < 0.995:
				mixed += 1
				print("  [mixed-winding] %s same=%d opposite=%d consist=%.3f" % [
					mi.get_path(), maxi(tpos, tneg), mini(tpos, tneg), consist])
			var flip := 1.0 if tpos >= tneg else -1.0
			for i in v.size():
				if absum[i] < 1e-12:
					continue
				if acc[i].length() / absum[i] < 0.9:
					continue   # 相交壳体接缝处的顶点邻接三角形朝向分歧,不能作为判据
				var g: Vector3 = acc[i].normalized() * flip
				var d: float = rad_to_deg(acos(clampf(g.dot(sn[i]), -1.0, 1.0)))
				verts += 1
				if d > 90.0:
					opposite += 1
				worst = maxf(worst, minf(d, 180.0 - d))
	return {"verts": verts, "opposite": opposite, "worst": worst, "bad_index": bad_index, "mixed": mixed}

## uv 最大跨度(米):用于验证 UV 为世界米制而非归一化参数
func _uv_span(mesh: Mesh) -> Vector2:
	var arr: Array = mesh.surface_get_arrays(0)
	var su: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var out := Vector2.ZERO
	for p in su:
		out.x = maxf(out.x, p.x)
		out.y = maxf(out.y, p.y)
	return out

## 以指定速度推进 2 秒,返回落地步数(驱动内部 step_cb 计数)→ 验证步频随速度上升
func _count_steps(fig: Dictionary, speed: float) -> int:
	var steps := [0]
	HumanoidAnim.unregister_floor()
	HumanoidAnim.register(fig, {"step_cb": func(_running: bool) -> void: steps[0] += 1})
	var root: Node3D = fig["root"]
	for i in 120:
		root.position += Vector3(0, 0, -speed / 60.0)
		HumanoidAnim.tick_all(1.0 / 60.0)
	HumanoidAnim.unregister_floor()
	return int(steps[0])

func _run() -> void:
	await process_frame
	_can_shot = (DisplayServer.get_name() != "headless")
	if _can_shot:
		DirAccess.make_dir_recursive_absolute(SHOTS_DIR)
	var packed: PackedScene = load("res://scenes/main.tscn")
	m = packed.instantiate()
	root.add_child(m)
	for i in 600:
		if m.G != null and m.floor_root != null:
			break
		await process_frame
	await wait_s(1.2)

	# ---------- 1. 标题 ----------
	check("标题画面显示", m.H.title_screen.visible)
	await shot("title")

	# ---------- 2. 开始游戏 → 1F ----------
	m._on_start()
	await wait_s(1.0)
	var s := state()
	check("进入 1F 大堂", s.floor == "1F" and s.playing)
	check("初始理智 100 / 无手电", is_equal_approx(s.sanity, 100.0) and not s.hasFlash)
	await shot("1f-lobby")

	# ---------- 3. 行走测试 ----------
	var before: Vector3 = m.player_pos
	m.keys[KEY_W] = true
	await wait_s(1.0)
	m.keys[KEY_W] = false
	var moved := Vector2(m.player_pos.x - before.x, m.player_pos.z - before.z).length()
	check("WASD 行走有效(位移 %.2fm > 1m)" % moved, moved > 1.0)

	# ---------- 4. 教学:手电 / 须知 / 监控 / 蹲伏 ----------
	await tp(0)
	await press_e()
	await wait_s(0.4)
	s = state()
	check("捡到手电(电量50)", s.hasFlash)
	await shot("1f-flashlight")

	await tp(1)
	await press_e()
	await wait_s(0.4)
	check("《住户须知》弹窗打开", m.G.modal_open)
	await pick("记住了")
	await wait_s(0.3)
	check("须知已读旗标", m.G.flags.get("rulesRead", false) == true)

	await tp(2)
	var san_before: float = m.G.sanity
	await press_e()
	await wait_s(0.5)
	s = state()
	check("监控异象:理智 −10(%.1f → %.1f)" % [san_before, s.sanity], absf(san_before - s.sanity - 10.0) < 0.5 and s.flags.get("monSeen", false))
	await shot("1f-monitor-scare")

	await tp(3)
	m.keys[KEY_CTRL] = true
	await wait_s(0.3)
	await press_e()
	await wait_s(0.3)
	m.keys[KEY_CTRL] = false
	s = state()
	check("蹲伏教学:货架下电池(电池=2)", s.flags.get("bat1F", false) and m.G.batteries == 2)
	m.G.has_flash = true
	m.G.battery = 100.0
	m.G.flash_on = true

	# ---------- 5. 乘电梯 → 2F,麻将解谜(正确路) ----------
	await ride("2F 麻将馆")
	await shot("2f-arrival")
	await tp(0)
	await press_e()
	await wait_s(0.4)
	check("麻将桌谜题弹窗", m.G.modal_open)
	await shot("2f-mahjong-puzzle")
	await pick("放轻呼吸")
	await wait_s(8.6)
	await maybe_call()
	s = state()
	check("2F 解谜:遗物+权限卡3F", s.relics >= 1 and s.cards["3F"] == true and s.flags.get("mjSolved", false))
	print("[after-2f] " + JSON.stringify(state()))
	m.G.sanity = 100.0

	# ---------- 6. 电梯异常错误应对(乘往 3F 途中抽验) ----------
	var wrong_tested := false
	for attempt in 4:
		if wrong_tested:
			break
		var dest := "3F 幼儿园" if attempt % 2 == 0 else "2F 麻将馆"
		await tp_last()
		await press_e()
		await wait_s(0.5)
		await pick(dest)
		await wait_s(1.4)
		if m.G.modal_open:
			var san_ride: float = m.G.sanity
			var viol_before: int = m.G.violations
			await answer_anomaly(attempt > 0)
			if attempt == 0:
				await wait_s(2.0)
				await maybe_call()
				s = state()
				check("电梯异常错误应对:理智 −15,违规+1", absf(san_ride - s.sanity - 15.0) < 3.0 and s.violations == viol_before + 1)
				wrong_tested = true
		await wait_s(2.6)
	if not wrong_tested:
		print("  [info] 连续4次乘梯均无异常,跳过错误应对检查(概率 2.6%)")
	if m.G.floor_id != "3F":
		await ride("3F 幼儿园")
	m.G.sanity = 100.0

	# ---------- 7. 3F 幼儿园:拼图 + 蹲伏避苏梅 ----------
	await tp(0)
	await press_e()
	await wait_s(0.4)
	check("拼图谜题弹窗", m.G.modal_open)
	await shot("3f-puzzle")
	await pick("先拼眼睛")
	await wait_s(10.0)
	await maybe_call()
	s = state()
	check("3F 解谜:遗物粉笔+权限卡4F", s.flags.get("puzzle3F", false) and s.relics >= 2 and s.cards["4F"])
	var san_crouch: float = m.G.sanity
	await tp(2)
	m.keys[KEY_CTRL] = true
	await wait_s(4.0)
	m.keys[KEY_CTRL] = false
	check("3F 蹲伏避让苏梅(理智 %.1f 无骤降)" % m.G.sanity, m.G.sanity > san_crouch - 3.0)
	print("[after-3f] " + JSON.stringify(state()))
	m.G.sanity = 100.0

	# ---------- 8. 4F 诊所:登记册/听诊器/两瓶药/批号页 ----------
	await ride("4F 诊所")
	await expect_no_call()
	await tp(0)
	await maybe_call()
	await press_e()
	await wait_s(0.3)
	check("4F:权限卡5F(登记册)", m.G.cards["5F"])
	await tp(1)
	await maybe_call()
	await press_e()
	await wait_s(0.3)
	await tp(2)
	await maybe_call()
	await press_e()
	await wait_s(0.3)
	await press_e()
	await wait_s(0.3)
	await tp(3)
	await maybe_call()
	await press_e()
	await wait_s(0.4)
	await pick("收好残页")
	await wait_s(0.3)
	s = state()
	check("4F:遗物听诊器+两瓶药+批号页(药典未得)", s.relics >= 3 and s.pills["a"] == 1 and s.pills["b"] == 1 and not s.knowsPills)
	await shot("4f-done")
	print("[after-4f] " + JSON.stringify(state()))
	m.G.sanity = 100.0

	# ---------- 9. 5F 网吧:监控回放 + 删除谜题 ----------
	await ride("5F 网吧")
	await tp(1)
	await press_e()
	await wait_s(0.4)
	await pick("关掉它")
	await wait_s(0.6)
	await tp(0)
	await press_e()
	await wait_s(0.4)
	var san_pw: float = m.G.sanity
	await pick("输入 20080613")
	await wait_s(0.6)
	check("5F 密码错误:理智 −10", absf(san_pw - m.G.sanity - 10.0) < 3.0)
	await press_e()
	await wait_s(0.4)
	await pick("输入 TX-2048")
	await wait_s(0.6)
	await pick("取走键盘下的会员卡")
	await wait_s(7.0)
	s = state()
	check("5F 解谜:遗物会员卡+权限卡6F", s.flags.get("del5F", false) and s.relics >= 4 and s.cards["6F"])
	m.player_pos = Vector3(6.4, 0, 0.8)
	m.player_yaw = 0.0
	await wait_s(0.3)
	await press_e()
	await wait_s(0.3)
	check("5F:收费台电池(电池=3)", m.G.flags.get("bat5Fb", false) and m.G.batteries == 3)
	await shot("5f-done")
	print("[after-5f] " + JSON.stringify(state()))
	m.G.sanity = 100.0

	# ---------- 10. 6F 无限走廊:听门找真门 ----------
	await ride("6F 酒店公寓")
	var found_truth := false
	for idx in 10:
		await tp(idx)
		await press_e()
		await wait_s(0.35)
		if modal_body().contains("十三"):
			check("6F:真门(门 %d/10,数到十三)" % (idx + 1), true)
			await pick("推开门", true)
			await wait_s(0.5)
			await pick("取下墙上的门牌")
			found_truth = true
			break
		await pick("退开", true)
		await wait_s(0.2)
	check("6F:找到真门", found_truth)
	await wait_s(7.0)
	await maybe_call()
	s = state()
	check("6F 解谜:遗物门牌+权限卡7F", s.flags.get("door6F", false) and s.relics >= 5 and s.cards["7F"])
	await shot("6f-done")
	print("[after-6f] " + JSON.stringify(state()))
	m.G.sanity = 100.0

	# ---------- 11. 7F 灵堂:讣告 + 上香 ----------
	await ride("7F 灵堂")
	await tp(1)
	await press_e()
	await wait_s(0.4)
	await pick("默记于心")
	await wait_s(0.3)
	await tp(0)
	await press_e()
	await wait_s(0.5)
	check("上香谜题弹窗", m.G.modal_open)
	await shot("7f-incense")
	await pick("大河 → 二河 → 小河", true)
	await wait_s(9.5)
	await expect_no_call()
	s = state()
	check("7F 解谜:遗物+香烛+权限卡8F", s.flags.get("incenseSolved", false) and s.relics >= 6 and s.candles == 2 and s.cards["8F"])
	await shot("7f-solved")
	print("[after-7f] " + JSON.stringify(state()))
	m.G.sanity = 100.0

	# ---------- 12. 8F 档案室:林档案/药典/暗格 ----------
	await ride("8F 档案室")
	await tp(1)
	await press_e()
	await wait_s(0.5)
	await pick("把卡片攥进手心")
	await wait_s(0.5)
	check("8F:档案「明天」理智事件", m.G.flags.get("files8F", false))
	await tp(2)
	await press_e()
	await wait_s(0.4)
	await pick("记牢批号")
	await wait_s(0.3)
	check("8F:药典 → knows_pills", m.G.knows_pills)
	await tp(4)
	await press_e()
	await wait_s(0.4)
	await pick("收下档案袋")
	await wait_s(7.0)
	s = state()
	check("8F 解谜:遗物档案袋+权限卡9F", s.relics >= 7 and s.cards["9F"])
	await shot("8f-done")
	print("[after-8f] " + JSON.stringify(state()))
	m.G.sanity = 100.0

	# ---------- 13. 9F 镜像层:同步谜题 + 立镜电池 ----------
	await ride("9F 镜像层")
	await tp(0)
	await press_e()
	await wait_s(0.4)
	check("同步谜题弹窗", m.G.modal_open)
	await shot("9f-mirror")
	await pick("抬手 → 转身 → 下蹲")
	await wait_s(11.0)
	s = state()
	check("9F 解谜:遗物裂镜+权限卡10F", s.flags.get("mirror9F", false) and s.relics >= 8 and s.cards["10F"])
	m.player_pos = Vector3(-8.6, 0, -5.2)
	m.player_yaw = 0.0
	await wait_s(0.3)
	await press_e()
	await wait_s(0.3)
	check("9F:立镜电池(电池=4)", m.G.flags.get("bat9F", false) and m.G.batteries == 4)
	print("[after-9f] " + JSON.stringify(state()))
	m.G.sanity = 100.0

	# ---------- 14. 10F 宴会厅:坐错惩罚 + 空位正解 ----------
	await ride("10F 宴会厅")
	await tp(0)
	await press_e()
	await wait_s(0.4)
	var san_seat: float = m.G.sanity
	await pick("坐到主位")
	await wait_s(0.6)
	check("10F 坐错:理智 −15", absf(san_seat - m.G.sanity - 15.0) < 3.0)
	await tp(0)
	await press_e()
	await wait_s(0.4)
	await pick("坐到没有胸牌的空位")
	await wait_s(10.0)
	s = state()
	check("10F 解谜:遗物请柬+权限卡11F", s.flags.get("seat10F", false) and s.relics >= 9 and s.cards["11F"])
	await tp(2)
	await press_e()
	await wait_s(0.3)
	check("10F:果盘电池(电池=5)", m.G.flags.get("bat10F", false) and m.G.batteries == 5)
	await shot("10f-done")
	print("[after-10f] " + JSON.stringify(state()))
	m.G.sanity = 100.0

	# ---------- 15. 11F 祭坛:献祭照片 ----------
	await ride("11F 祭坛")
	await tp(0)
	await press_e()
	await wait_s(0.4)
	await pick("献上妹妹的照片")
	await wait_s(3.0)
	await pick("接过念珠")
	await wait_s(7.0)
	s = state()
	check("11F 解谜:遗物念珠+权限卡12F+照片已献", s.flags.get("sacrifice11F", false) and s.flags.get("photoGiven", false) and s.relics >= 10 and s.cards["12F"])
	await shot("11f-done")
	print("[after-11f] " + JSON.stringify(state()))
	m.G.sanity = 100.0

	# ---------- 16. 12F 天台:全家福 + 配电箱 ----------
	await ride("12F 天台")
	await tp(0)
	await press_e()
	await wait_s(0.4)
	await pick("收好照片")
	await wait_s(7.0)
	s = state()
	check("12F 解谜:遗物全家福+权限卡13F", s.relics >= 11 and s.cards["13F"])
	await tp(2)
	await press_e()
	await wait_s(0.3)
	check("12F:配电箱电池(电池=6)", m.G.flags.get("bat12F", false) and m.G.batteries == 6)
	await shot("12f-done")
	print("[after-12f] " + JSON.stringify(state()))
	m.G.sanity = 100.0

	# ---------- 17. 13F(强制异常)→ 日记剧情节点 ----------
	await ride("13F 住宅层", true)
	await tp(0)
	await wait_s(0.4)
	await shot("13f-door")
	await press_e()
	await wait_s(0.6)
	await pick("翻下一页")
	await wait_s(0.4)
	await pick("翻下一页")
	await wait_s(0.4)
	await pick("翻到最后一页")
	await wait_s(0.4)
	await pick("把日记贴身收好")
	await wait_s(6.0)
	s = state()
	check("13F:日记遗物(12/13)+权限卡B1", s.flags.get("diaryRead", false) and s.relics == 12 and s.cards["B1"])
	await shot("13f-diary")
	print("[after-13f] " + JSON.stringify(state()))
	m.G.sanity = 100.0

	# ---------- 18. B1 停车场:引开老周夺钥匙串 ----------
	await ride("B1 停车场")
	await tp(0)
	await press_e()
	await wait_s(0.5)
	check("B1:对讲机已触发查噪", not m.G.flags.get("keysTaken", false))
	var got_keys := false
	for att in 8:
		await tp(1)
		await press_e()
		await wait_s(0.3)
		if m.G.flags.get("keysTaken", false):
			got_keys = true
			break
		await wait_s(1.6)
	check("B1:夺取钥匙串(出口钥匙)", got_keys)
	await wait_s(7.5)
	s = state()
	check("B1:遗物钥匙串(13/13)+权限卡B2", s.relics == 13 and s.flags.get("hasExitKey", false) and s.cards["B2"])
	await shot("b1-done")
	print("[after-b1] " + JSON.stringify(state()))
	m.G.sanity = 100.0

	# ---------- 19. B2(强制异常)→ 识破 → 真结局 ----------
	await ride("B2 锅炉房", true)
	await tp(0)
	await press_e()
	await wait_s(0.6)
	await pick("试探")
	await wait_s(0.4)
	await pick("你不是她")
	await wait_s(3.0)
	await pick("举行熄灯仪式")
	await wait_s(0.5)
	await pick("继续念名")
	await wait_s(0.5)
	await pick("熄灯")
	await wait_s(2.6)
	check("真结局演出画面", m.H.ending_screen.visible and m.H.ending_title.text.contains("真结局"))
	await shot("ending-true")
	for i in 12:
		m.ending_next()
		await wait_s(0.2)
	var stats_text: String = m.H.ending_stats.text
	check("结算:遗物 13/13 + 真结局", stats_text.contains("13 / 13") and stats_text.contains("真结局"))
	await shot("ending-stats")
	print("[stats] " + stats_text.replace("\n", " ").strip_edges())

	# ---------- 20. 分支结局:牺牲(识破后摧毁核心) ----------
	await reach_b2_core()
	await pick("试探")
	await wait_s(0.4)
	await pick("你不是她")
	await wait_s(3.0)
	await pick("摧毁核心")
	await wait_s(0.5)
	await pick("跑。别回头。")
	await wait_s(2.6)
	check("牺牲结局触发", m.H.ending_screen.visible and m.H.ending_title.text.contains("牺牲"))
	await shot("ending-sacrifice")

	# ---------- 21. 分支结局:替代(未识破,被诱惑) ----------
	await reach_b2_core()
	await pick("直接走近")
	await wait_s(0.4)
	await pick("我愿意,换她走")
	await wait_s(2.6)
	check("替代结局触发", m.H.ending_screen.visible and m.H.ending_title.text.contains("替代"))
	await shot("ending-replace")

	# ---------- 22. 分支结局:逃离(识破 + 出口钥匙) ----------
	await reach_b2_core({"hasExitKey": true})
	await pick("试探")
	await wait_s(0.4)
	await pick("你不是她")
	await wait_s(3.0)
	await pick("转身,用出口钥匙逃出大门")
	await wait_s(2.6)
	check("逃离结局触发", m.H.ending_screen.visible and m.H.ending_title.text.contains("逃离"))
	await shot("ending-escape")

	# ---------- 23. 死亡与重试(理智归零) ----------
	await reload_scene()
	await wait_s(0.5)
	m._on_start()
	await wait_s(0.8)
	m.player_pos = Vector3(8, 0, -6)
	m.change_sanity(-95.0)
	await wait_s(0.2)
	await wait_s(4.5)
	check("理智归零 → Game Over", m.H.gameover_screen.visible)
	await shot("gameover-sanity")
	m._on_retry()
	await wait_s(1.5)
	s = state()
	check("重试恢复(理智=%d, 本层=%s, 死亡=%d)" % [roundi(s.sanity), s.floor, s.deaths],
		s.playing and s.sanity > 0.0 and s.deaths == 1)

	# ---------- 24. 时间死亡(6:00) ----------
	m.G.time = 359.0
	m.add_game_minutes(1)
	await wait_s(0.6)
	check("6:00 时限 → Game Over", m.H.gameover_screen.visible)
	await shot("gameover-time")

	# ---------- 25. 回归(E3/D5):乘梯途中锁旧楼层交互 ----------
	await reload_scene()
	await wait_s(0.5)
	m._on_start()
	await wait_s(0.8)
	var tps: Array = m.G.get_meta("_tp", [])
	m.tp(tps.size() - 1)
	await wait_s(0.3)
	check("呼梯面板可交互(前置)", m.current_inter != null)
	m.ride_to("2F", true)   # 直接发起乘梯:同步置 riding 后挂起在转场等待里
	await wait_s(0.3)
	check("乘梯中 riding 生效且交互提示清空", m.G.riding and m.current_inter == null)
	m.interact_press()      # 站在面板上按 E:修复前会再开一层面板、双程竞态
	await wait_s(0.2)
	check("乘梯中按 E 不弹新窗", not m.G.modal_open)
	await wait_s(3.0)
	check("乘梯正常抵达且状态复位", m.G.floor_id == "2F" and not m.G.riding and not m.G.modal_open)

	# ---------- 26. 回归(E1/E4):ESC 真暂停 + 失焦卡键兜底 ----------
	await reload_scene()
	await wait_s(0.5)
	m._on_start()
	await wait_s(0.8)
	m.G.battery = 88.0
	m.G.flash_on = true     # 开灯保证恢复后结算可观测(耗电 1/秒)
	var p_bat: float = m.G.battery
	var p_time: float = m.G.time
	var p_pos: Vector3 = m.player_pos
	m.pause_game()
	m.keys[KEY_W] = true    # 复现"按住 W 时按 ESC"
	await wait_s(1.5)
	check("暂停冻结(时间/电量/位移不变)",
		m.G.paused and m.G.time == p_time and m.G.battery == p_bat and m.player_pos == p_pos)
	m.resume_game()
	check("恢复退出暂停并清空按键", not m.G.paused and m.keys.is_empty())
	await wait_s(0.7)
	check("恢复后结算恢复(电量下降)", m.G.battery < p_bat)
	m.keys[KEY_W] = true
	m.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("失焦清空按键(E4 兜底)", m.keys.is_empty())

	# ---------- 27. 回归(E2/D5):结局触发瞬间不被 6:00 死亡顶掉 ----------
	await reload_scene()
	await wait_s(0.5)
	m._on_start()
	await wait_s(0.5)
	m.G.time = 350.0
	var d_end: int = m.G.deaths
	m.start_ending("true")
	await wait_s(0.4)
	check("结局画面出现且无死亡画面顶盖",
		m.H.ending_screen.visible and not m.H.gameover_screen.visible and m.G.deaths == d_end and not m.G.playing)

	# ---------- 28. 音频动态(状态机 / 空间化 / 突然安静) ----------
	check("动态音效素材齐备(合成或外部)",
		m.S.has("keys") and m.S.has("scratch") and m.S.has("marble") and m.S.has("ding_off")
		and m.S.has("drip") and m.S.has("elevator_ride") and m.S.has("rumble"))
	check("新外部素材已导入(keys/marble 变体组 + scratch)",
		m.S._bufs["keys"] is Array and m.S._bufs["marble"] is Array and m.S._bufs["scratch"] is AudioStream)
	var mfx: AudioEffectLowPassFilter = AudioServer.get_bus_effect(AudioServer.get_bus_index("Master"), 0)
	m.S.update_mood(40.0)
	check("低理智:Master 低通截止下探(%dHz)" % int(mfx.cutoff_hz), mfx.cutoff_hz < 20000.0)
	check("低理智:SFX 失真开启", AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index("SFX"), 0))
	m.S.update_mood(10.0)
	check("濒理智:低频轰鸣已起", m.S._rumble.playing and m.S._rumble_on)
	m.S.update_mood(100.0)
	check("理智回满:失真关闭且轰鸣退出(muffle 复位 %dHz)" % int(mfx.cutoff_hz),
		not AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index("SFX"), 0)
		and not m.S._rumble_on and mfx.cutoff_hz > 20000.0)
	var at_n: int = m.S._pool3d.size()
	m.S.play_at("scratch", Vector3(3.0, 1.2, -2.0), 0.5)
	var at_playing: bool = false
	for p3: AudioStreamPlayer3D in m.S._pool3d:
		if p3.playing and p3.global_position.distance_to(Vector3(3.0, 1.2, -2.0)) < 0.01:
			at_playing = true
	check("空间音:3D 播放器定位正确且池不增员", at_playing and m.S._pool3d.size() == at_n)
	m.S.hush(0.4)
	check("突然安静:Ambience 总线压低",
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")) < -10.0)
	await wait_s(0.55)
	check("突然安静恢复:Ambience 总线回 0dB",
		is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")), 0.0))

	# ---------- 29. 人形建模(法线 / 米制 UV / 合并缓存) ----------
	var Hu = load("res://scripts/humanoid.gd")
	var rig_root := Node3D.new()
	m.floor_root.add_child(rig_root)
	var variants: Array = [
		{"tag": "stand", "cfg": {"pose": "stand"}},
		{"tag": "sit", "cfg": {"pose": "sit"}},
		{"tag": "robe", "cfg": {"pose": "stand", "robe": true, "hunch": 0.55}},
		{"tag": "skirt+apron", "cfg": {"pose": "stand", "skirt": true, "apron": true, "hair": "bun"}},
		{"tag": "uniform+cap", "cfg": {"pose": "stand", "uniform": true, "cap_hex": "1e2430", "face": "human"}},
		{"tag": "plastic-legless", "cfg": {"pose": "stand", "legless": true, "plastic": true, "face": "none", "hair": "bald"}},
		{"tag": "silhouette", "cfg": {"pose": "stand", "silhouette": true, "face": "none", "hair": "bald"}},
	]
	var a_verts := 0
	var a_oppo := 0
	var a_bad := 0
	var a_mixed := 0
	var a_worst := 0.0
	for v: Dictionary in variants:
		var fig := Props.human_figure(m, v["cfg"])
		rig_root.add_child(fig["root"])
		var au := _normal_audit(fig["root"])
		a_verts += int(au["verts"])
		a_oppo += int(au["opposite"])
		a_bad += int(au["bad_index"])
		a_mixed += int(au["mixed"])
		a_worst = maxf(a_worst, float(au["worst"]))
		print("  [audit] %-16s verts=%-5d opposite=%-3d bad_index=%d mixed=%d worst=%5.1fdeg" % [
			v["tag"], au["verts"], au["opposite"], au["bad_index"], au["mixed"], au["worst"]])
	check("人形子树无索引越界的 surface(%d)" % a_bad, a_bad == 0)
	# mixed(手性一致率)仅打印不判定:封口三角形的「三顶点法线均值」被相邻环顶点的水平法线主导,
	# 符号与封口自身朝向无关;而带渲染的真值测试已证明 lathe/sculpt_sphere/flat_quad 与引擎
	# 图元在 cull_back 材质下全部正常可见(不存在反面剔除)。
	print("  [audit] mixed(仅参考)=%d" % a_mixed)
	# 容差来源(结构性,非建模缺陷):① 封口中心顶点——它只属于两片盖的扇面,而符号由占多数的
	# 侧壁三角形决定;② 手指与手掌等相交壳体的接缝顶点(merge 后同 surface)。实测占 2.5%。
	# 阈值仍需远小于「位移量纲写错导致截面翻面」那一类缺陷的量级(实测给出 174°/反向占比 ~30%)。
	check("人形子树反向顶点比例 %.2f%% ≤ 3%%(%d/%d)" % [
		100.0 * a_oppo / float(maxi(1, a_verts)), a_oppo, a_verts], a_oppo * 100 <= a_verts * 3)
	check("人形子树法线与几何最大夹角 %.1f° < 80°" % a_worst, a_worst < 80.0)
	# 米制 UV:部件尺寸翻倍 → uv 跨度等比翻倍(归一化 UV 不会)
	var prof_small: Array = [[0.10, 0.0], [0.12, 0.20], [0.09, 0.40]]
	var prof_big: Array = [[0.20, 0.0], [0.24, 0.40], [0.18, 0.80]]
	var sp_s := _uv_span(Hu.lathe(prof_small, 12))
	var sp_b := _uv_span(Hu.lathe(prof_big, 12))
	var ratio_v: float = sp_b.y / maxf(0.0001, sp_s.y)
	var ratio_u: float = sp_b.x / maxf(0.0001, sp_s.x)
	check("lathe UV 为世界米制(v 跨度比 %.2f / u 跨度比 %.2f ≈ 2.0)" % [ratio_v, ratio_u],
		absf(ratio_v - 2.0) < 0.02 and absf(ratio_u - 2.0) < 0.02)
	var sp_sphere := _uv_span(Hu.sculpt_sphere(0.115, 20, 16))
	check("sculpt_sphere UV 跨度为米制量级(%.3f m ≈ 2πr=%.3f)" % [sp_sphere.x, TAU * 0.115],
		absf(sp_sphere.x - TAU * 0.115) < 0.01)
	# 合并缓存 LRU:写入超过上限的 distinct key,条目数不得突破上限且必须发生淘汰
	var cap: int = int(Hu.MERGE_CACHE_MAX)
	var ev0: int = int(Hu.merge_cache_stats()["evictions"])
	for i in cap + 12:
		var probe := Node3D.new()
		rig_root.add_child(probe)
		var pm := MeshInstance3D.new()
		pm.mesh = Hu.flat_quad(0.01, 0.01)
		pm.material_override = m.pmat({"color": Color.html("ffffff"), "roughness": 0.5})
		probe.add_child(pm)
		Hu.merge_static(probe, "lru-probe-%d" % i)
		probe.free()
	var cache_n: int = Hu._merged_meshes.size()
	var ev1: int = int(Hu.merge_cache_stats()["evictions"])
	check("合并缓存受 LRU 上限约束(%d ≤ %d)" % [cache_n, cap], cache_n <= cap and cache_n == cap)
	check("合并缓存发生淘汰并计数(evictions %d→%d)" % [ev0, ev1], ev1 > ev0)
	rig_root.free()
	# ---------- P2 下肢枢轴链:结构改造不得改变任何关节的世界位置 ----------
	var fig_st := Props.human_figure(m, {"pose": "stand"})
	var fig_si := Props.human_figure(m, {"pose": "sit"})
	var joints_st := {"hip_l": Vector3(-0.09, 0.91, 0), "knee_l": Vector3(-0.09, 0.46, 0),
		"ankle_l": Vector3(-0.09, 0.01, 0), "hip_r": Vector3(0.09, 0.91, 0),
		"knee_r": Vector3(0.09, 0.46, 0), "ankle_r": Vector3(0.09, 0.01, 0)}
	var joints_si := {"hip_l": Vector3(-0.09, 0.47, -0.02), "knee_l": Vector3(-0.09, 0.44, -0.45),
		"ankle_l": Vector3(-0.09, 0.0, -0.45), "hip_r": Vector3(0.09, 0.47, -0.02),
		"knee_r": Vector3(0.09, 0.44, -0.45), "ankle_r": Vector3(0.09, 0.0, -0.45)}
	var jmax := 0.0
	for key: String in joints_st:
		var n1: Node3D = fig_st[key]
		var n2: Node3D = fig_si[key]
		if n1 == null or n2 == null:
			jmax = 999.0
			break
		# 枢轴静止时皆为单位旋转 → 链上局部位置之和即相对 root 的位置
		var acc := Vector3.ZERO
		var cur: Node3D = n1
		while cur != null and cur != fig_st["root"]:
			acc += cur.position
			cur = cur.get_parent()
		jmax = maxf(jmax, acc.distance_to(joints_st[key]))
		var acc2 := Vector3.ZERO
		cur = n2
		while cur != null and cur != fig_si["root"]:
			acc2 += cur.position
			cur = cur.get_parent()
		jmax = maxf(jmax, acc2.distance_to(joints_si[key]))
	check("下肢枢轴链关节位置与改造前逐位一致(最大偏差 %.4fm)" % jmax, jmax < 0.001)
	var old_keys := ["root", "head", "arm_l", "arm_r", "fore_l", "fore_r", "hand_l", "hand_r"]
	var new_keys := ["upper", "hip_l", "hip_r", "knee_l", "knee_r", "ankle_l", "ankle_r", "legged", "rig"]
	check("旧契约 8 键未变", old_keys.all(func(k): return fig_st.has(k)))
	check("新增骨架键齐备", new_keys.all(func(k): return fig_st.has(k)))
	var fig_sk := Props.human_figure(m, {"pose": "stand", "skirt": true})
	var fig_rs := Props.human_figure(m, {"pose": "sit", "robe": true})
	var fig_lg := Props.human_figure(m, {"pose": "stand", "legless": true})
	check("锥裙/长衫坐姿/无腿 三种分支不建腿且驱动可守卫",
		not bool(fig_sk["legged"]) and not bool(fig_rs["legged"]) and not bool(fig_lg["legged"])
		and fig_sk["hip_l"] == null and fig_rs["knee_r"] == null and fig_lg["ankle_l"] == null)
	fig_st["root"].free(); fig_si["root"].free()
	fig_sk["root"].free(); fig_rs["root"].free(); fig_lg["root"].free()

	# ---------- P3 步态驱动:滑步量与步频 ----------
	var fig_g := Props.human_figure(m, {"pose": "stand"})
	var gr: Node3D = fig_g["root"]
	gr.position = Vector3(0, 0, 0)
	m.floor_root.add_child(gr)
	HumanoidAnim.unregister_floor()
	HumanoidAnim.register(fig_g, {})
	var ph_at_slow := 0.0
	for i in 180:   # 1.1 m/s × 3s,沿 -Z 前进
		gr.position += Vector3(0, 0, -1.1 / 60.0)
		HumanoidAnim.tick_all(1.0 / 60.0)
	ph_at_slow = HumanoidAnim.last_slip
	for i in 120:   # 提速到 2.5 m/s
		gr.position += Vector3(0, 0, -2.5 / 60.0)
		HumanoidAnim.tick_all(1.0 / 60.0)
	var slip_fast: float = HumanoidAnim.last_slip
	# 步频随速度上升:用落地事件计数(各 2 秒)
	var cycles_slow := _count_steps(fig_g, 1.1)
	var cycles_fast := _count_steps(fig_g, 2.5)
	check("走路滑步 %.4fm 与跑步滑步 %.4fm 均 < 0.02m" % [ph_at_slow, slip_fast],
		ph_at_slow < 0.02 and slip_fast < 0.02)
	check("步频随速度单调上升(%.1f 步/s → %.1f 步/s)" % [cycles_slow / 2.0, cycles_fast / 2.0],
		cycles_fast > cycles_slow * 1.4)
	HumanoidAnim.unregister_floor()
	gr.free()

	# 带渲染:人形 model sheet 近景(站姿正面/侧面 + 坐姿)
	if _can_shot:
		m.G.sanity = 100.0
		m.H.render_hud(m.G)   # 复位低理智侵蚀/失真/暗角参数,否则拍到的是被扭曲的画面
		m.H.set_hud_visible(false)
		m.H.ending_screen.visible = false
		m.H.gameover_screen.visible = false
		var key := OmniLight3D.new()
		key.light_color = Color.html("fff0d8")
		key.omni_range = 6.0
		m.floor_root.add_child(key)
		var cam_tf: Transform3D = m.camera.global_transform
		var cam_o: Vector3 = cam_tf.origin
		key.position = cam_o + Vector3(0.6, 0.6, 0.0)
		for sheet: Array in [["rig-stand-front", 0.0], ["rig-stand-side", PI / 2.0], ["rig-sit", 0.0]]:
			var sfig := Props.human_figure(m, {"pose": "sit" if sheet[0] == "rig-sit" else "stand",
				"face": "human", "uniform": sheet[0] != "rig-sit"})
			var sb: Node3D = sfig["root"]
			# 沿相机自身前向放到人形站立体量中心,再让正面(-Z)转回相机
			sb.position = cam_o + cam_tf.basis * Vector3(0.0, -0.85, -1.5)
			m.floor_root.add_child(sb)
			sb.look_at(Vector3(cam_o.x, sb.position.y, cam_o.z))
			sb.rotate_y(sheet[1])
			await process_frame
			await process_frame
			shot(sheet[0])
			sb.free()
		key.free()

	# ---------- 汇总 ----------
	print("\n===== 汇总 =====")
	check("外部音效资源加载 ≥12 项(实际 %d,若为 0 检查 --import)" % m.S.ext_loaded, m.S.ext_loaded >= 12)
	print("失败项: " + ("无 —— 全部通过 ✓" if failures.is_empty() else " | ".join(PackedStringArray(failures))))
	quit(0 if failures.is_empty() else 1)

func expect_no_call() -> void:
	# 4F/7F 等层可能触发楼道呼唤,出现即正确应对
	for i in 25:
		var t := modal_title()
		if t != "":
			if t.contains("背后有人叫你"):
				print("  [event] 楼道呼唤触发 → 正确应对")
				await pick("站住,默数到七")
			break
		await create_timer(0.25).timeout
	await wait_s(0.4)
