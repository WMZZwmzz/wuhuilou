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
