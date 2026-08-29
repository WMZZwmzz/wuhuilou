extends Node3D
## 《无回楼》垂直切片 · 总控
## 场景搭建、玩家控制、交互、电梯与异常、理智/电量/时间结算、结局与死亡。
## 贴图/字体程序化生成;音效为外部 CC0 资源 + 程序化回退(sounds/CREDITS.md)。

const FloorCommon = preload("res://scripts/floor_common.gd")
const Floor1F = preload("res://scripts/floor_1f.gd")
const Floor2F = preload("res://scripts/floor_2f.gd")
const Floor3F = preload("res://scripts/floor_3f.gd")
const Floor4F = preload("res://scripts/floor_4f.gd")
const Floor5F = preload("res://scripts/floor_5f.gd")
const Floor6F = preload("res://scripts/floor_6f.gd")
const Floor7F = preload("res://scripts/floor_7f.gd")
const Floor8F = preload("res://scripts/floor_8f.gd")
const Floor9F = preload("res://scripts/floor_9f.gd")
const Floor10F = preload("res://scripts/floor_10f.gd")
const Floor11F = preload("res://scripts/floor_11f.gd")
const Floor12F = preload("res://scripts/floor_12f.gd")
const Floor13F = preload("res://scripts/floor_13f.gd")
const FloorB1 = preload("res://scripts/floor_b1.gd")
const FloorB2 = preload("res://scripts/floor_b2.gd")

const WALL_H := 3.2
const FLOOR_ORDER := ["1F", "2F", "3F", "4F", "5F", "6F", "7F", "8F", "9F", "10F", "11F", "12F", "13F", "B1", "B2"]
const FLOOR_NAMES := {
	"1F": "1F 大堂", "2F": "2F 麻将馆", "3F": "3F 幼儿园", "4F": "4F 诊所",
	"5F": "5F 网吧", "6F": "6F 酒店公寓", "7F": "7F 灵堂", "8F": "8F 档案室",
	"9F": "9F 镜像层", "10F": "10F 宴会厅", "11F": "11F 祭坛", "12F": "12F 天台",
	"13F": "13F 住宅层", "B1": "B1 停车场", "B2": "B2 锅炉房",
}
var DYN_TINT := {
	"1F": [Color.html("ffb077"), Color.html("7a92c8")],
	"2F": [Color.html("d8b078"), Color.html("5a8a8c")],
	"3F": [Color.html("e8b8a0"), Color.html("8a9ac0")],
	"4F": [Color.html("c8dcc0"), Color.html("6a8ab8")],
	"5F": [Color.html("8ab0d8"), Color.html("5a6aa8")],
	"6F": [Color.html("d8c098"), Color.html("7a8298")],
	"7F": [Color.html("ffa060"), Color.html("9a7aa8")],
	"8F": [Color.html("c0bc98"), Color.html("8a9078")],
	"9F": [Color.html("b8c2cc"), Color.html("7c88a8")],
	"10F": [Color.html("e0a888"), Color.html("a05a68")],
	"11F": [Color.html("b89878"), Color.html("6a5a88")],
	"12F": [Color.html("a8bcc8"), Color.html("5a6a80")],
	"13F": [Color.html("ffc890"), Color.html("7a86b8")],
	"B1": [Color.html("9aa8b0"), Color.html("4a5a68")],
	"B2": [Color.html("c05848"), Color.html("5a2830")],
}
# 乘往这些楼层必定触发电梯异常(剧情节拍:13F 情感高点 / B2 终局下行)
const FORCED_ANOMALY_FLOORS := ["13F", "B2"]
# 每程乘梯消耗的游戏分钟:15 层全链 14 程 ×10 = 140 分钟,加各层解谜奖励与停留,
# 在 360 分钟(6:00)时限内可达 B2 真结局(数值对齐《06-玩法机制/数值平衡表》"每层 10–20 分钟")
const RIDE_MINUTES := 10.0
const WHISPERS := [
	"楼上传来弹珠落地的声音。嗒。嗒。嗒。",
	"远处有麻将牌碰撞的声音,洗牌一般密集。",
	"\"叮——\"电梯到了。可电梯明明在你身后。",
	"墙里传来压抑的哭声,顺着水管爬上来。",
	"楼上有人在拖动桌椅。一下,又一下。",
]
const ANOMALIES := [
	{"title": "多出的\"乘客\"",
		"body": "电梯门合上的瞬间,你察觉角落里多了一个身影。\n它背对着你,一动不动。\n\n(住户须知一:电梯限乘四人。若电梯内已有\"人\",请等下一班。)",
		"choices": [
			{"text": "凑近,看清它的脸", "wrong": true},
			{"text": "不去看它,按住开门键等下一班", "correct": true},
			{"text": "开口问它:\"你去几层?\"", "wrong": true}],
		"wrongText": "它缓缓转过头来——那里没有脸。等下一班电梯到时,角落空空如也。",
		"correctText": "你盯着楼层数字,呼吸放平。下一班到了,门开,角落里什么都没有。"},
	{"title": "13层的按钮亮了",
		"body": "没有人碰面板,按钮\"13\"却自己亮了起来。\n红光一闪一闪。\n\n(住户须知二:若按钮13层亮起但无人按下,请立即退出。)",
		"choices": [
			{"text": "立即退出电梯", "correct": true},
			{"text": "假装没看见,继续乘坐", "wrong": true},
			{"text": "连按\"关门\"键", "wrong": true}],
		"wrongText": "电梯开始向上,又向上,又向上。开门时外面是浓得化不开的黑。你退回电梯,冷汗湿透。",
		"correctText": "你退了出去。电梯空着升了上去,像吞掉了什么。下一班,干干净净。"},
	{"title": "镜子里的你",
		"body": "轿厢镜面里,你的倒像抬手比你慢了半拍。\n它似乎意识到了什么,缓缓转向你。\n\n(住户须知三:电梯内镜子不可直视超过三秒。)",
		"choices": [
			{"text": "直视镜子,看个清楚", "wrong": true},
			{"text": "立刻移开视线,不再看它", "correct": true},
			{"text": "一拳砸碎镜子", "wrong": true}],
		"wrongText": "镜中的你先笑了。碎裂的镜面里,每一块碎片都有一只眼睛。",
		"correctText": "你低下头数着自己的呼吸。再看时,镜子里只剩你自己,动作分毫不差。"},
	{"title": "门迟迟不开",
		"body": "\"叮——\"电梯已经停靠,门却迟迟不开。\n门缝外一片死寂。\n\n(住户须知四:若停靠后门迟迟不开,请闭眼、背对门站立。)",
		"choices": [
			{"text": "强行扒门", "wrong": true},
			{"text": "闭上眼,背对门站立", "correct": true},
			{"text": "疯狂连按\"开门\"键", "wrong": true}],
		"wrongText": "指尖刚触到门缝,门\"哗\"地开了——门外的黑暗里挤满了人形的轮廓。",
		"correctText": "你背对门闭眼站着。不知过了多久,身后的门轻轻开了,灯光正常,走廊正常。"},
	{"title": "无限下坠",
		"body": "电梯在下降。一直下降。\n楼层显示屏跳成了负数:-4……-9……-13……\n(老住户说:闭眼数到七。)",
		"choices": [
			{"text": "死死抓住扶手", "wrong": true},
			{"text": "闭上眼,数到七", "correct": true},
			{"text": "把所有楼层按钮全部按亮", "wrong": true}],
		"wrongText": "下坠声变成了耳语,耳语变成了名字——你的名字。电梯\"停\"住了,却不知在几层。",
		"correctText": "一、二、三……七。下坠感消失了。睁眼,电梯正平稳地亮着你要去的楼层。"},
	{"title": "楼层错乱",
		"body": "你按的是7层,电梯却停在了9层。\n门缓缓打开,门外一片漆黑,什么都没有。\n(管理员手册残页:保持冷静,重新刷卡。)",
		"choices": [
			{"text": "保持冷静,重新刷卡", "correct": true},
			{"text": "惊慌地跑出电梯", "wrong": true},
			{"text": "连按当前楼层按钮", "wrong": true}],
		"wrongText": "你一脚迈进黑暗——再回头,电梯已经不在了。不知走了多久,它才又亮起,像什么都没发生。",
		"correctText": "你退出刷卡,再按一次。这次,数字稳稳地停在了正确的楼层。"},
]
# 四结局演出文本(判定规格对齐《07-结局/多结局设计》;完整演出脚本见《04-剧情/结局演绎》)
const ENDINGS := {
	"escape": {
		"title": "逃离结局",
		"line": "离开,但永远失去她。",
		"steps": [
			"你用出口钥匙撞开一层的铁门,冲进夜色。\n身后,永宁大楼在晨光中缓缓隐去。",
			"你回头——妹妹的脸贴在玻璃门内,\n眼神绝望,缓缓消失。",
			"你跪在空地上,攥着那串钥匙:\n\"对不起,音音。哥没能带你出来。\"",
		],
	},
	"replace": {
		"title": "替代结局",
		"line": "你成了新的管理员。",
		"steps": [
			"核心化作林音,伸出双手:\n\"哥,只要你愿意留下,我就放她走。\"",
			"你说:\"我愿意。\"\n它的笑声里,一股寒意没入你的身体。",
			"妹妹的身影被推出大楼,跌坐在晨光里;\n你的意识沉入黑暗。",
			"你再\"醒来\"时,穿着破旧的保安服,\n腰间挂着一串钥匙。镜子里的你,没有影子。",
			"你听见自己沙哑地说:\n\"从今天起,这楼由你守。\"——而老周,早已不知所踪。",
		],
	},
	"sacrifice": {
		"title": "牺牲结局",
		"line": "她活了下来,但你永远留在灰烬中。",
		"steps": [
			"你识破了它,转身砸向锅炉与管道的节点。\n核心暴怒,火焰与怨念席卷整层。",
			"老周在最后一刻替你挡下致命一击:\n\"守楼的,这次守住你了。\"他化作灰烬。",
			"大楼开始坍塌。你用尽全力把妹妹推向出口。",
			"她回头,撕心裂肺地喊:\"砚哥——\"\n你在火光中对她笑:\"跑。别回头。\"",
			"晨光洒在废墟上。她跪在那里,\n手里攥着你最后塞给她的家门钥匙。",
		],
	},
	"true": {
		"title": "真结局 —— 熄灯仪式",
		"line": "十三件遗物,十三层楼,十三个人,终于都回家了。",
		"steps": [
			"十三件遗物在锅炉房摆成一个圈,逐件亮起。",
			"你依次念出十二位亡者的名字——\n每念一个,圈内就亮起一点微光,有人向你微微鞠躬。",
			"你取出那把旧钥匙,插进肉壁中央的锁孔。\n\"咔哒。\"——2008 年那晚没能打开的 1304 的门,开了。",
			"你念出最后的名字:\"林音。\"\n黑暗中,一个轻轻的声音回答:\"砚哥。\"",
			"你熄灭了楼内所有的灯。黑暗静默了三秒。",
			"清晨 6:00,第一缕阳光刺破黑暗。\n肉壁褪去,大楼在阳光中透明、崩塌、消失。",
			"废墟之上,你和妹妹站在晨光里。\n身后,无数透明的人影微微鞠躬,化作光点,散在风里。",
			"她牵起你的手,轻声说:\n\"他们都回家了。\"",
		],
	},
}

# 全局对象(QA 直接访问)
var G
var T: TexGen
var S: Sfx
var H: Hud
var camera: Camera3D
var flash: SpotLight3D
var body_glow: OmniLight3D
var viewmodel: Node3D            # 第一人称右手(手持手电)
var vm_lens: StandardMaterial3D  # 手电透镜(开关同步发光)
var vm_fingers: Array = []       # 视图模型 4 个指根枢轴(屈指)
var vm_thumb: Node3D = null      # 视图模型拇指枢轴
var _vm_t := 0.0                # 摆动相位
var player_cadence := 0.0       # 实际步频(步/秒),由位移速度导出;手持物与脚步声共用
const PLAYER_STRIDE_SOUND := 1.45   # 虚拟步长(m):2.8m/s ÷ 1.45 ≈ 1.92 步/秒,即旧版 0.52s/步的节奏
var _vm_sway := Vector2.ZERO    # 转向惯性
var _vm_dip := 0.0              # 开关手电抬落脉冲
var _vm_flash_prev := false
var _vm_prev_yaw := 0.0
var _vm_prev_pitch := 0.0

var floor_root: Node3D
var colliders: Array = []          # Rect2 列表(x0,z0,w,d)
var interactables: Array = []      # {pos, label, cb, radius, cond}
var floor_update: Callable = Callable()
var lights: Array = []             # {l, base, flicker}
var flicker_lights: Array = []     # 仅带闪烁的灯(大多数楼层只有 0-3 盏,避免每帧遍历全部)
var dyn_lights := {}
var safe_spots: Array = []
var elevator_doors := {}
var fake_exit_obj: MeshInstance3D = null
var current_inter = null
var _prompt_label := ""            # 交互目标标签缓存:变化才拼 "[E] …" 字符串
var _shadow_mat: StandardMaterial3D  # 低理智影子剪影共用材质(无状态差异,建一次复用)
var _shadow_fig_mesh: ArrayMesh = null   # 影子人形的共享合并网格(惰性构建一次)

## 体积化黑影网格:一具 silhouette 人形 → merge_static 收成单 surface,之后每次显形仅 1 个实例
func _shadow_figure_mesh() -> ArrayMesh:
	if _shadow_fig_mesh != null:
		return _shadow_fig_mesh
	var fig := Props.human_figure(self, {"pose": "stand", "face": "none", "hair": "bald",
		"silhouette": true, "sil_alpha": 0.85})
	var body: Node3D = fig["root"]
	Humanoid.merge_static(body, "shadowfig:v1")   # 剪影材质与楼层无关 → 键不含 instance_id
	var mis: Array = body.find_children("*", "MeshInstance3D", true, false)
	if not mis.is_empty():
		_shadow_fig_mesh = mis[0].mesh   # ArrayMesh 是资源,被引用即随材质存活
	body.free()
	return _shadow_fig_mesh

# 玩家(QA 直接访问)
var player_pos := Vector3(0, 0, 6.2)
var player_yaw := 0.0
var player_pitch := 0.0
var keys := {}
const PLAYER_R := 0.35
var shake := 0.0
var time_acc := 0.0
var whisper_t := 8.0
var hall_t := 12.0      # 幻听音轨计时(弹珠/失谐铃/麻将)
var shadow_t := 14.0
var call_done := false
var ending_idx := 0
var ending_id := "true"
var es_clickable := true
var cam_h := 1.62        # 相机高度(蹲伏时缓动到 0.95)
var DEBUG := false
var _step_acc := 0.0   # 脚步声节奏累加器

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if "debug" in a:
			DEBUG = true
	G = GameState.new()
	T = TexGen.new()
	await T.prepare()
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_mat.albedo_color = Color(0, 0, 0, 0.85)
	S = Sfx.new()
	add_child(S)
	H = Hud.new()
	add_child(H)
	_build_camera()
	H.start_requested.connect(func(): _on_start())
	H.ending_advanced.connect(func(): ending_next())
	H.restart_requested.connect(func(): get_tree().reload_current_scene())
	H.retry_requested.connect(func(): _on_retry())
	H.to_title_requested.connect(func(): get_tree().reload_current_scene())
	H.pause_resumed.connect(func(): resume_game())
	build_floor("1F")
	if DEBUG:
		_build_debug_bar()
	H.show_title(true)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.1
	camera.far = 60.0
	add_child(camera)
	camera.current = true
	# 第一人称视图模型:右手持手电(程序化雕刻),手电灯挂筒头随手动
	var vm := Humanoid.build_viewmodel(self)
	viewmodel = vm["root"]
	vm_lens = vm["lens"]
	vm_fingers = vm["fingers"]
	vm_thumb = vm["thumb"]
	viewmodel.position = Vector3(0.24, -0.26, -0.42)
	viewmodel.rotation = Vector3(0.04, -0.06, 0.0)
	viewmodel.visible = false
	camera.add_child(viewmodel)
	flash = SpotLight3D.new()
	flash.light_color = Color.html("fff2d0")
	flash.spot_range = 32.0
	flash.spot_angle = 34.0
	flash.light_energy = 15.0
	flash.shadow_enabled = true
	flash.position = Vector3(0, 0.02, -0.16)
	viewmodel.add_child(flash)
	flash.visible = false
	body_glow = OmniLight3D.new()
	body_glow.light_color = Color.html("8090a0")
	body_glow.light_energy = 0.28
	body_glow.omni_range = 2.6
	camera.add_child(body_glow)

# ---------- 主循环 ----------

func _process(delta: float) -> void:
	var dt := minf(0.05, delta)
	if floor_root:
		if G.playing and not G.paused and not G.modal_open:
			update_player(dt)
			update_interact()
			update_atmosphere(dt)
			if floor_update.is_valid():
				floor_update.call(dt)
			# 步态/姿态驱动:必须在楼层逻辑之后叠加(楼层已更新 NPC root 位移与 look_at)
			HumanoidAnim.tick_all(dt)
			var now := Time.get_ticks_msec()
			for L: Dictionary in flicker_lights:
				var n := sin(now * 0.013 + (L["l"] as Node3D).position.x * 7.0) * sin(now * 0.007)
				L["l"].light_energy = L["base"] * (1.0 - L["flicker"] * maxf(0.0, n))
			if not dyn_lights.is_empty():
				var ts := now * 0.001
				dyn_lights["warm"].position = Vector3(sin(ts * 0.13) * 4.5, 2.5 + sin(ts * 0.21) * 0.3, cos(ts * 0.17) * 4.0)
				dyn_lights["cool"].position = Vector3(cos(ts * 0.11 + 2.1) * 5.5, 2.6 + cos(ts * 0.16) * 0.25, sin(ts * 0.09 + 0.7) * 4.5)
				dyn_lights["warm"].light_energy = 0.68 * (0.88 + 0.12 * sin(ts * 0.7))
				dyn_lights["cool"].light_energy = 0.54 * (0.9 + 0.1 * sin(ts * 0.5 + 1.7))
			_settle(dt)
		H.render_hud(G)
	_update_viewmodel(dt)

# ---------- 第一人称视图模型 ----------

func _update_viewmodel(dt: float) -> void:
	if viewmodel == null:
		return
	viewmodel.visible = G.playing and G.has_flash
	if vm_lens != null:
		vm_lens.emission_energy_multiplier = 5.0 if (G.flash_on and G.battery > 0.0) else 0.0
	# 开关手电 → 抬落手脉冲(QA 直改 G.flash_on 同样覆盖)
	if G.flash_on != _vm_flash_prev:
		_vm_flash_prev = G.flash_on
		_vm_dip = 1.0
	_vm_dip = maxf(0.0, _vm_dip - dt * 6.0)
	# 屈指:按开关的瞬间握紧(与整体抬落共用 _vm_dip 相位),点亮后保持略紧握持
	var curl := sin(_vm_dip * PI) * 0.42 + (0.06 if G.flash_on else 0.0)
	for i in vm_fingers.size():
		var f: Node3D = vm_fingers[i]
		if f != null and is_instance_valid(f):
			f.rotation.x = curl * (1.0 - 0.12 * float(i))   # 食指/中指更明显
	if vm_thumb != null and is_instance_valid(vm_thumb):
		vm_thumb.rotation.x = curl * 0.5

func _update_viewmodel_motion(dt: float, moving: bool, running: bool, crouching: bool) -> void:
	if viewmodel == null or not viewmodel.visible:
		return
	# 摆动锁相:一个 bob 周期 = 两步(旧版写死 7.5/11.0 与脚步声脱拍)
	var bob_speed := 2.0 if player_cadence <= 0.05 else player_cadence * PI
	_vm_t += dt * bob_speed
	var amp := 0.004
	if moving:
		amp = 0.018 if running else 0.012
	# 转向惯性:视角角速度反向缓动
	var dy := player_yaw - _vm_prev_yaw
	var dp := player_pitch - _vm_prev_pitch
	_vm_prev_yaw = player_yaw
	_vm_prev_pitch = player_pitch
	_vm_sway = _vm_sway.lerp(Vector2(clampf(-dy * 2.0, -0.03, 0.03), clampf(dp * 2.0, -0.03, 0.03)), clampf(dt * 8.0, 0.0, 1.0))
	var base := Vector3(0.24, -0.26, -0.42)
	if crouching:
		base.y -= 0.03
	var dip := sin(_vm_dip * PI) * 0.05 * _vm_dip
	viewmodel.position = base + Vector3(cos(_vm_t * 0.5) * amp * 0.6, sin(_vm_t) * amp - dip, 0.0)
	viewmodel.rotation = Vector3(0.04 - _vm_sway.y, -0.06 + _vm_sway.x, -_vm_sway.x * 0.5)

func _settle(dt: float) -> void:
	var in_safe := false
	for s: Dictionary in safe_spots:
		if Vector2(player_pos.x - s["x"], player_pos.z - s["z"]).length() < s["r"]:
			in_safe = true
			break
	var lit: bool = G.flash_on and G.battery > 0.0
	if in_safe:
		# 11F 献出妹妹照片后,情感锚点消失:安全区回复减半(见《06-玩法机制/道具与收集》)
		var heal_mult := 0.5 if G.flags.get("photoGiven", false) else 1.0
		change_sanity(G.NUM["safeHeal"] * heal_mult * dt, true)
	elif lit:
		change_sanity(-G.NUM["flashDrain"] * dt, true)
	elif G.candle_timer > 0.0:
		change_sanity(-0.6 * dt, true)
	else:
		change_sanity(-G.NUM["darkDrain"] * dt, true)
	if lit:
		G.battery = maxf(0.0, G.battery - G.NUM["batteryDrain"] * dt)
		if G.battery <= 0.0:
			G.flash_on = false
			H.show_msg("手电闪了两下,灭了。黑暗涌了上来。")
			S.click()
	if G.candle_timer > 0.0:
		G.candle_timer -= dt
	flash.visible = lit
	time_acc += dt
	if time_acc >= 6.0:
		time_acc -= 6.0
		add_game_minutes(1)
	S.heart(G.sanity < 50.0 and not G.modal_open, 700 if G.sanity < 25.0 else 1000)
	S.update_mood(G.sanity)

# ---------- 玩家 ----------

func _key(k: Key) -> bool:
	return keys.get(k, false)

func _free_at(nx: float, nz: float) -> bool:
	for r: Rect2 in colliders:
		if nx > r.position.x - PLAYER_R and nx < r.position.x + r.size.x + PLAYER_R \
				and nz > r.position.y - PLAYER_R and nz < r.position.y + r.size.y + PLAYER_R:
			return false
	return true

func try_move(dx: float, dz: float) -> void:
	if _free_at(player_pos.x + dx, player_pos.z):
		player_pos.x += dx
	if _free_at(player_pos.x, player_pos.z + dz):
		player_pos.z += dz

func cam_forward() -> Vector3:
	return Vector3(-sin(player_yaw), 0.0, -cos(player_yaw))

func update_player(dt: float) -> void:
	var crouching := _key(KEY_CTRL)
	G.crouching = crouching
	var mx := 0
	var mz := 0
	if _key(KEY_W) or _key(KEY_UP): mz -= 1
	if _key(KEY_S) or _key(KEY_DOWN): mz += 1
	if _key(KEY_A) or _key(KEY_LEFT): mx -= 1
	if _key(KEY_D) or _key(KEY_RIGHT): mx += 1
	var moving := (mx != 0 or mz != 0)
	var running := false
	if moving and (_key(KEY_SHIFT)) and not G.stamina_lock and not crouching:
		running = true
		G.stamina -= G.NUM["runCost"] * dt
		if G.stamina <= 0.0:
			G.stamina = 0.0
			G.stamina_lock = true
	else:
		G.stamina = minf(100.0, G.stamina + G.NUM["staminaRegen"] * dt)
		if G.stamina_lock and G.stamina >= 20.0:
			G.stamina_lock = false
	player_cadence = 0.0
	if moving:
		var l := float(Vector2(mx, mz).length())
		var speed_mult := 0.45 if crouching else 1.0
		var sp: float = ((G.NUM["runSpeed"] if running else G.NUM["walkSpeed"]) * speed_mult) * dt
		var s := sin(player_yaw)
		var c := cos(player_yaw)
		var dx: float = (c * mx + s * mz) / l * sp
		var dz: float = (c * mz - s * mx) / l * sp
		try_move(dx, dz)
		# 按位移计步(旧写法累加秒却与距离样常量比较 → 走/跑同频,与速度脱钩)
		_step_acc += sp
		if _step_acc >= PLAYER_STRIDE_SOUND:
			_step_acc -= PLAYER_STRIDE_SOUND
			S.play_step(running and not crouching)
		player_cadence = sp / dt / PLAYER_STRIDE_SOUND
	G.running = running and moving
	var shake_y := 0.0
	var roll := 0.0
	if shake > 0.0:
		shake_y = (randf() - 0.5) * shake * 0.06
		roll = (randf() - 0.5) * shake * 0.02
		shake = maxf(0.0, shake - dt * 2.0)
	cam_h = lerpf(cam_h, 0.95 if crouching else 1.62, clampf(dt * 10.0, 0.0, 1.0))
	camera.position = Vector3(player_pos.x, cam_h + shake_y, player_pos.z)
	camera.rotation = Vector3(player_pitch, player_yaw, roll)
	_update_viewmodel_motion(dt, moving, running, crouching)

func keys_reset() -> void:
	keys.clear()

## 失焦兜底:切走窗口后收不到松键事件,按住的键会永久卡住(角色自动前行)
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		keys_reset()

# ---------- 交互 ----------

func add_inter(pos: Vector3, label: String, cb: Callable, radius := 2.4, cond: Callable = Callable()) -> void:
	interactables.append({"pos": pos, "label": label, "cb": cb, "radius": radius, "cond": cond})

func update_interact() -> void:
	current_inter = null
	if G.riding:
		if _prompt_label != "":
			_prompt_label = ""
			H.set_prompt("")
		return
	var fwd := -camera.global_transform.basis.z
	var best = null
	var best_d := 1e9
	for it: Dictionary in interactables:
		if it["cond"].is_valid() and not it["cond"].call():
			continue
		var to: Vector3 = it["pos"] - camera.global_position
		var dist := to.length()
		if dist > it["radius"]:
			continue
		to = to.normalized()
		if to.dot(fwd) < 0.45:
			continue
		if dist < best_d:
			best_d = dist
			best = it
	current_inter = best
	var lbl: String = best["label"] if best else ""
	if lbl != _prompt_label:
		_prompt_label = lbl
		H.set_prompt("[E] " + lbl if lbl != "" else "")

func interact_press() -> void:
	if G.riding:
		return
	if current_inter:
		S.click()
		current_inter["cb"].call()

# ---------- 输入 ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k: Key = event.physical_keycode
		if event.pressed and not event.echo:
			match k:
				KEY_M:
					var m := S.toggle_mute()
					H.show_msg("已静音" if m else "声音开启", 1.5)
					return
			if not G.playing or G.paused:
				return
			keys[k] = true
			match k:
				KEY_E:
					if not G.modal_open and not G.riding and current_inter:
						interact_press()
				KEY_F:
					if not G.modal_open:
						if not G.has_flash:
							H.show_msg("你没有手电。")
						elif G.battery <= 0.0 and not G.flash_on:
							H.show_msg("没电了。需要换电池(按1)。")
						else:
							G.flash_on = not G.flash_on
							S.flash()
				KEY_1: use_battery()
				KEY_2: use_pill("a")
				KEY_3: use_pill("b")
				KEY_4: use_candle()
				KEY_ESCAPE:
					if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and G.playing and not G.modal_open and not G.paused:
						pause_game()
		elif not event.pressed:
			keys[k] = false
	elif event is InputEventMouseMotion:
		if G.playing and not G.modal_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			player_yaw -= event.relative.x * 0.0022
			player_pitch -= event.relative.y * 0.0022
			player_pitch = clampf(player_pitch, -1.35, 1.35)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if G.playing and not G.modal_open and not G.paused:
				_capture_mouse()

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## 暂停/恢复:主循环以 G.paused 把玩家移动、时间与理智结算一起冻结;
## 两侧都清空按键,避免暂停前长按的方向键在恢复瞬间继续驱动。
func pause_game() -> void:
	G.paused = true
	keys_reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	H.show_pause(true)

func resume_game() -> void:
	G.paused = false
	H.show_pause(false)
	keys_reset()
	if G.playing:
		_capture_mouse()

# ---------- 理智 / 时间 / 道具 ----------

func change_sanity(v: float, silent := false) -> void:
	G.sanity = clampf(G.sanity + v, 0.0, 100.0)
	if v < 0.0 and not silent:
		shake = minf(2.0, shake + 0.7)
	if G.sanity <= 0.0 and G.playing:
		game_over("sanity")

func use_battery() -> void:
	if not G.playing or G.modal_open:
		return
	if G.batteries <= 0:
		H.show_msg("没有电池了。")
		return
	if G.battery >= 99.0:
		H.show_msg("电量是满的。")
		return
	G.batteries -= 1
	G.battery = minf(100.0, G.battery + G.NUM["batteryGain"])
	H.show_msg("换上新电池。电量 +50")
	S.click()

func use_pill(which: String) -> void:
	if not G.playing or G.modal_open:
		return
	if G.pills[which] <= 0:
		H.show_msg("没有这瓶药了。")
		return
	G.pills[which] -= 1
	if which == "a":
		change_sanity(25.0)
		H.show_msg("镇静片(批号2048)……世界安静了下来。理智 +25")
	else:
		var bad_drain := 10.0   # 假药一次性扣值(文案同源)
		change_sanity(-bad_drain)
		shake = 1.6
		H.show_msg("药片(批号2051)……墙上爬满了影子。这是假药。理智 −%d" % int(bad_drain))
		S.sting()

func use_candle() -> void:
	if not G.playing or G.modal_open:
		return
	if G.candles <= 0:
		H.show_msg("没有香烛。")
		return
	G.candles -= 1
	G.candle_timer = 40.0
	change_sanity(10.0)
	H.show_msg("点燃香烛。暖光暂时驱散了黑暗。(40秒内黑暗不再侵蚀理智)")

func gain_relic(name: String) -> void:
	G.relics += 1
	G.relic_names.append(name)
	H.show_msg("遗物(%d/13):%s" % [G.relics, name], 5.0)

func gain_card(floor: String) -> void:
	G.cards[floor] = true
	H.show_msg("获得电梯权限卡 %s" % floor, 4.5)

func add_game_minutes(m: float) -> void:
	G.time += m
	if G.time >= 360.0 and G.playing:
		game_over("time")

# ---------- 弹窗封装(开/关时处理鼠标与按键) ----------

func open_modal(cfg: Dictionary) -> void:
	G.modal_open = true
	keys_reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	H.open_modal(cfg)

func close_modal() -> void:
	G.modal_open = false
	H.close_modal()
	if G.playing:
		_capture_mouse()

# ---------- 幻听 / 低理智事件 ----------

func update_atmosphere(dt: float) -> void:
	if G.sanity < 75.0:
		whisper_t -= dt
		if whisper_t <= 0.0:
			# 50 以下"耳语加密加剧":间隔缩短
			whisper_t = (6.0 + randf() * 4.0) if G.sanity < 50.0 else (9.0 + randf() * 8.0)
			H.show_msg(WHISPERS[randi() % WHISPERS.size()], 3.5)
			S.whisper()
	# 幻听音轨(音效指南 §四 51–75 档):远处弹珠落地/失谐电梯铃/麻将碰撞,
	# 50 以下幻听也随耳语一并加密
	if G.sanity < 75.0:
		hall_t -= dt
		if hall_t <= 0.0:
			hall_t = (8.0 + randf() * 6.0) if G.sanity < 50.0 else (12.0 + randf() * 8.0)
			match randi() % 3:
				0: S.play_buf("marble", randf_range(0.6, 0.9), randf_range(0.9, 1.1))
				1: S.play_buf("ding_off", 0.6, randf_range(0.95, 1.05))
				2: S.mahjong()
	if G.sanity < 50.0 and not G.modal_open:
		shadow_t -= dt
		if shadow_t <= 0.0:
			shadow_t = 16.0 + randf() * 10.0
			var p := player_pos + cam_forward() * 4.5
			p.x += (randf() - 0.5) * 3.0
			var m := MeshInstance3D.new()
			# 体积化人形(旧版 QuadMesh 薄片在点光下明显是"一张纸");单网格复用,每次显形仅 1 个实例
			m.mesh = _shadow_figure_mesh()
			m.material_override = _shadow_mat   # 实例级覆盖合并网格内的 surface 材质
			m.position = Vector3(p.x, 0.0, p.z)
			m.scale = Vector3.ONE * 0.62
			floor_root.add_child(m)
			m.look_at(Vector3(camera.global_position.x, 0.0, camera.global_position.z))
			var life := 0.9 + randf() * 0.6
			# 清理回调绑在影子自身的 tween 上:影子被楼层切换释放时 tween 一并失效,
			# 不会像 SceneTree 计时器那样回调已释放实例并打印 "Lambda capture was freed"。
			var fade_tw := m.create_tween()
			fade_tw.tween_property(m, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_SINE)   # 黑暗凝聚成形
			fade_tw.tween_interval(life)
			fade_tw.tween_callback(func() -> void: m.free())
			S.scratch()   # 影子实体化:金属刮擦(音效指南威胁预警音);thud 留给门/重物
	if not call_done and (G.floor_id == "4F" or G.floor_id == "7F") and G.sanity < 85.0 and not G.modal_open:
		if randf() < dt * 0.02:
			call_done = true
			S.hush(1.5)   # 高潮前突然安静:呼唤贴上后颈前,楼里先静下来
			open_modal({
				"title": "背后有人叫你",
				"body": "声音贴着你的后颈:\n\"……小砚……回头看看……\"\n\n(楼道规则一:听见背后有人叫你名字,不要回头,直到你数到七。)",
				"countdown": 8,
				"choices": [
					{"text": "回头", "fn": func() -> void:
						close_modal()
						G.violations += 1
						change_sanity(-G.NUM["violation"])
						H.red_flash()
						S.sting()
						H.show_msg("叫你的不是人。它没有脸。理智 −%d" % int(G.NUM["violation"]))},
					{"text": "站住,默数到七,不回头", "fn": func() -> void:
						close_modal()
						change_sanity(2.0)
						H.show_msg("一、二、三……七。声音消失了。理智 +2")},
				],
				"on_timeout": func() -> void:
					close_modal()
					G.violations += 1
					change_sanity(-G.NUM["violation"])
					H.red_flash()
					S.sting()
					H.show_msg("你僵在原地。那个声音贴得更近了……理智 −%d" % int(G.NUM["violation"])),
			})
	if G.sanity < 25.0 and fake_exit_obj == null and floor_root:
		var m := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.1, 0.45)
		m.mesh = qm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color.html("2a5533")
		mat.emission_enabled = true
		mat.emission = Color.html("2a5533")
		mat.emission_energy_multiplier = 1.0
		m.material_override = mat
		m.position = Vector3(-6.5, 2.6, -7.8)
		floor_root.add_child(m)
		fake_exit_obj = m
		add_inter(Vector3(-6.5, 1.6, -7.6), "绿色的\"出口\"标志", func() -> void:
			var fake_drain := 5.0   # 假出口一次性扣值(文案同源)
			change_sanity(-fake_drain)
			H.show_msg("绿色的光不是出口。这里什么都没有。理智 −%d" % int(fake_drain)), 2.2)
		H.show_msg("墙角亮起了一块绿色的\"出口\"标志……")

# ---------- 电梯 ----------

func floor_name(f: String) -> String:
	return FLOOR_NAMES.get(f, f)

func open_elevator_ui() -> void:
	S.ding()
	var ch: Array = []
	for f: String in FLOOR_ORDER:
		var cur: bool = (f == G.floor_id)
		var locked: bool = (not cur) and f != "1F" and f != "2F" and not G.cards[f]
		var entry := {"text": ("▶ " if cur else "") + floor_name(f), "disabled": cur or locked}
		if cur:
			entry["reason"] = "当前楼层"
		elif locked:
			entry["reason"] = "无权限卡"
		var ff := f
		entry["fn"] = func() -> void:
			close_modal()
			ride_to(ff)
		ch.append(entry)
	var body := "面板亮着。可去的楼层如下:"
	if G.relics > 0:
		body += "\n(你贴身收着 %d 件遗物,它们微微发凉。)" % G.relics
	open_modal({"title": "电 梯", "body": body, "choices": ch})

func ride_to(f: String, skip_anomaly := false) -> void:
	if f == G.floor_id:
		return
	if G.riding:
		# 乘梯尚未落地时的重复呼梯直接忽略:否则第二程协程与第一程竞态、楼层双建
		return
	G.riding = true
	G.modal_open = false
	H.close_modal()
	keys_reset()
	S.ding()
	H.fade_show(f, "电梯运行中……")
	S.elevator_ride(true)
	add_game_minutes(RIDE_MINUTES)
	await _wait(1.1)
	S.elevator_ride(false)   # 异常段落回到死寂,贴合"门缝外一片死寂"的文案
	if not skip_anomaly and (f in FORCED_ANOMALY_FLOORS or randf() < 0.6):
		H.fade_root.visible = false
		await run_anomaly(func(): _arrive(f))
	else:
		await _arrive(f)

func _arrive(f: String) -> void:
	H.fade_show(f, "电梯到达")
	S.ding()
	await _wait(0.5)
	G.floor_id = f
	build_floor(f)
	G.riding = false
	H.fade_out()
	H.show_msg(floor_name(f), 3.2)

func run_anomaly(cb: Callable) -> void:
	var a: Dictionary = ANOMALIES[randi() % ANOMALIES.size()]
	S.hush(0.9)   # 异常显形前先抽掉环境声
	S.thud()
	var choices: Array = []
	for c: Dictionary in a["choices"]:
		var is_correct: bool = c.has("correct")
		var ctext: String = a["correctText"] if is_correct else a["wrongText"]
		choices.append({"text": c["text"], "fn": func() -> void:
			close_modal()
			if is_correct:
				change_sanity(2.0)
				H.show_msg(ctext + "(理智 +2)", 5.2)
			else:
				G.violations += 1
				change_sanity(-G.NUM["violation"])
				H.red_flash()
				shake = 1.8
				S.sting()
				H.show_msg(ctext + "(理智 −%d)" % int(G.NUM["violation"]), 5.2)
			await _wait(1.4)
			if cb.is_valid():
				cb.call()})
	open_modal({
		"title": "电 梯 异 常 —— " + a["title"],
		"body": a["body"],
		"countdown": 8,
		"choices": choices,
		"on_timeout": func() -> void:
			close_modal()
			G.violations += 1
			change_sanity(-G.NUM["violation"])
			H.red_flash()
			S.sting()
			H.show_msg("你僵在原地,什么都没有做。" + a["wrongText"] + "(理智 −%d)" % int(G.NUM["violation"]), 5.2)
			await _wait(1.4)
			if cb.is_valid():
				cb.call(),
	})

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

## 统一延迟回调(楼层脚本用):tween 绑定 Main,场景重载(Main 释放)即自动失效;
## 替代散落各层的 get_tree().create_timer——SceneTreeTimer 不随节点释放,
## 重试/回标题后回调仍会打到旧实例。楼层搭建期的解谜节奏回调全部走这里。
func after(sec: float, fn: Callable) -> void:
	var tw := create_tween()
	tw.tween_interval(sec)
	tw.tween_callback(fn)

# ---------- 场景搭建工具 ----------

var _mat_cache := {}   # 材质实例缓存(键 = 选项字典签名)。每层几十份相同外观的材质收敛为一份;
                       # 会被楼层逻辑后续改动的材质传 "no_cache": true 跳过(pmat 不读该键)
var trim_mats := {}    # 墙体装饰线材质缓存(跨楼层复用)

static func _mat_sig(o: Dictionary) -> String:
	var keys := o.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		parts.append(str(k) + ":" + str(o[k]))
	return "&".join(parts)

func pmat(o: Dictionary = {}) -> StandardMaterial3D:
	if o.get("no_cache", false):
		return _pmat_build(o)
	var key := _mat_sig(o)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := _pmat_build(o)
	_mat_cache[key] = m
	return m

func _pmat_build(o: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if o.has("color"):
		m.albedo_color = o["color"]
	if o.has("tex") and o["tex"] != null:
		m.albedo_texture = o["tex"]
		# 走廊墙面全是掠射角,各向异性 + mipmap 是消除远处色块/像素闪感的必要条件
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = o.get("roughness", 0.82)
	m.metallic = o.get("metallic", 0.0)
	if o.has("normal") and o["normal"] != null:
		m.normal_enabled = true
		m.normal_texture = o["normal"]
		m.normal_scale = float(o.get("normal_scale", 0.5))
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if o.get("clearcoat", 0.0) > 0.0:
		m.clearcoat_enabled = true
		m.clearcoat = o["clearcoat"]
		m.clearcoat_roughness = o.get("cc_rough", 0.45)
	if o.has("emission"):
		m.emission_enabled = true
		m.emission = o["emission"]
		m.emission_energy_multiplier = o.get("emission_energy", 1.0)
	if o.has("emission_tex") and o["emission_tex"] != null:
		m.emission_enabled = true
		m.emission_texture = o["emission_tex"]
		m.emission_energy_multiplier = o.get("emission_energy", 1.0)
		m.emission = Color(1, 1, 1)
	if o.get("subsurf", 0.0) > 0.0:
		# Godot 4.7 的次表面散射属性名为 subsurf_scatter_*(无 sss_* 命名)
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = o["subsurf"]
		if o.get("subsurf_skin", false):
			m.subsurf_scatter_skin_mode = true
		if o.has("subsurf_trans"):
			m.subsurf_scatter_transmittance_enabled = true
			m.subsurf_scatter_transmittance_color = o["subsurf_trans"]
	if o.get("rim", 0.0) > 0.0:
		m.rim_enabled = true
		m.rim_tint = o["rim"]
	if o.get("vc_albedo", false):
		m.vertex_color_use_as_albedo = true
	if o.has("uv1"):
		m.uv1_scale = o["uv1"]
	if o.get("unshaded", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if o.get("transparent", false):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if o.get("double_sided", false):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func tex_mat(name: String, fallback_hex: String, o: Dictionary = {}) -> StandardMaterial3D:
	# 有程序化贴图用贴图,headless 无渲染时退回纯色
	if T.has(name):
		o["tex"] = T.tex[name]
	else:
		o["color"] = Color.html(fallback_hex)
	return pmat(o)

func add_box(w: float, h: float, d: float, material: Material, x: float, y: float, z: float, collide := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	m.mesh = bm
	m.material_override = material
	m.position = Vector3(x, y, z)
	floor_root.add_child(m)
	if collide:
		colliders.append(Rect2(x - w / 2.0, z - d / 2.0, w, d))
	return m

func _trim_mat(kind: String) -> StandardMaterial3D:
	if not trim_mats.has(kind):
		match kind:
			"base":
				trim_mats["base"] = pmat({"color": Color.html("33291e"), "roughness": 0.55, "clearcoat": 0.25, "cc_rough": 0.5})
			"dado":
				trim_mats["dado"] = pmat({"color": Color.html("453d2c"), "roughness": 0.72})
			"crown":
				trim_mats["crown"] = pmat({"color": Color.html("98917f"), "roughness": 0.85})
			_:
				# 壁柱:墙同源贴图,色调压暗约一成以区分墙面;
				# uv1 按壁柱实际尺寸 0.46m×3.1m 映射到贴图 3m×3.2m 定义域(v=1 会把墙裙/渐变重复 3 段,禁用)
				trim_mats[kind] = pmat({"tex": T.tex.get("wall"), "normal": T.tex.get("wall_n"),
					"uv1": Vector3(0.15, 0.97, 1), "roughness": 0.93, "normal_scale": 0.6,
					"color": Color.html("77725f") if T.tex.get("wall") == null else Color(0.9, 0.88, 0.84)})
	return trim_mats[kind]

func add_wall(x: float, z: float, w: float, d: float, material: Material = null, trim := true) -> MeshInstance3D:
	var mm = material
	if mm == null:
		var rep := maxi(1, roundi(maxf(w, d) / 3.0))
		mm = pmat({"tex": T.tex.get("wall"), "normal": T.tex.get("wall_n"), "uv1": Vector3(rep, 1, 1),
			"roughness": 0.93, "normal_scale": 0.6})
	var wall := add_box(w, WALL_H, d, mm, x, WALL_H / 2.0, z)
	if trim:
		# 线脚只在墙厚方向两侧凸出;长度两端各缩 3cm,端面藏入交叉墙(无交叉墙时止于门口),避免共面闪动
		var tl := maxf(w, d) - 0.06
		var tw := tl if w > d else w + 0.07
		var td := d + 0.07 if w > d else tl
		add_box(tw, 0.12, td, _trim_mat("base"), x, 0.065, z, false)
		add_box(tw, 0.09, td, _trim_mat("dado"), x, 1.12, z, false)
		add_box(tw, 0.09, td, _trim_mat("crown"), x, WALL_H - 0.045, z, false)
	return wall

func add_floor_plane(w: float, d: float, material: Material, x: float, y: float, z: float, face_up := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, d)
	m.mesh = pm
	m.material_override = material
	m.position = Vector3(x, y, z)
	if not face_up:
		m.rotation.x = PI
	floor_root.add_child(m)
	return m

func add_quad(w: float, h: float, material: Material, x: float, y: float, z: float, ry := 0.0, rx := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	m.mesh = qm
	m.material_override = material
	m.position = Vector3(x, y, z)
	m.rotation = Vector3(rx, ry, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor_root.add_child(m)
	return m

func setup_env(ambient_energy: float, ambient_color: Color, fog_color: Color, fog_density: float) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.008, 0.008, 0.016)
	sky_mat.sky_horizon_color = Color(0.045, 0.04, 0.032)
	sky_mat.ground_bottom_color = Color(0.02, 0.014, 0.01)
	sky_mat.ground_horizon_color = Color(0.045, 0.04, 0.032)
	sky_mat.sky_energy_multiplier = 0.35
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy * 1.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.05
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	we.environment = env
	floor_root.add_child(we)

## 点光源。shadow 默认 true,仅楼层主灯开(每盏阴影点光在 Forward+ 下占 6 面立方体阴影 pass);
## 闪烁装饰灯、轿厢小灯、车灯等氛围光传 false——它们是点状补光,关影观感几乎无损。
func add_light(color: Color, intensity: float, dist: float, x: float, y: float, z: float, flicker := 0.0, shadow := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = intensity * 2.0
	l.omni_range = dist
	l.position = Vector3(x, y, z)
	l.shadow_enabled = shadow
	floor_root.add_child(l)
	lights.append({"l": l, "base": l.light_energy, "flicker": flicker})
	if flicker > 0.0:
		flicker_lights.append(lights[-1])
	return l

func add_dyn_lights(f: String) -> void:
	var tint: Array = DYN_TINT.get(f, [Color.html("ffb077"), Color.html("7a92c8")])
	var warm := OmniLight3D.new()
	warm.light_color = tint[0]
	warm.light_energy = 0.68
	warm.omni_range = 16.0
	warm.position = Vector3(3, 2.5, -2)
	var cool := OmniLight3D.new()
	cool.light_color = tint[1]
	cool.light_energy = 0.54
	cool.omni_range = 18.0
	cool.position = Vector3(-4, 2.6, 3)
	for l: OmniLight3D in [warm, cool]:
		l.shadow_enabled = false   # 巡游补光每帧移动位置,开影等于每帧全场景重渲染;氛围叠加不开影
		floor_root.add_child(l)
	dyn_lights = {"warm": warm, "cool": cool}

func safe_spot(x: float, z: float, r: float) -> void:
	safe_spots.append({"x": x, "z": z, "r": r})

func clear_scene() -> void:
	if floor_root:
		floor_root.free()
	floor_root = Node3D.new()
	add_child(floor_root)
	colliders = []
	interactables = []
	lights = []
	flicker_lights = []
	dyn_lights = {}
	safe_spots = []
	floor_update = Callable()
	HumanoidAnim.unregister_floor()   # floor_root 是立即 free() 的,注册表必须同步清空
	fake_exit_obj = null
	elevator_doors = {}

func open_doors_anim() -> void:
	if elevator_doors.is_empty():
		return
	var dl: MeshInstance3D = elevator_doors["dl"]
	var dr: MeshInstance3D = elevator_doors["dr"]
	# tween 绑在 floor_root 上随楼层一起释放,避免快速连乘时跨层步进已释放的门体
	var tw := floor_root.create_tween()
	tw.tween_property(dl, "position:x", -1.65, 0.9)
	tw.parallel().tween_property(dr, "position:x", 1.65, 0.9)
	tw.tween_interval(2.6)
	tw.tween_property(dl, "position:x", -0.6, 0.9)
	tw.parallel().tween_property(dr, "position:x", 0.6, 0.9)

# ---------- 楼层搭建 ----------

func build_floor(f: String) -> void:
	clear_scene()
	keys_reset()
	player_pos = Vector3(0, 0, 6.4)
	player_yaw = 0.0
	player_pitch = 0.0
	match f:
		"1F": Floor1F.build(self)
		"2F": Floor2F.build(self)
		"3F": Floor3F.build(self)
		"4F": Floor4F.build(self)
		"5F": Floor5F.build(self)
		"6F": Floor6F.build(self)
		"7F": Floor7F.build(self)
		"8F": Floor8F.build(self)
		"9F": Floor9F.build(self)
		"10F": Floor10F.build(self)
		"11F": Floor11F.build(self)
		"12F": Floor12F.build(self)
		"13F": Floor13F.build(self)
		"B1": FloorB1.build(self)
		"B2": FloorB2.build(self)
	add_dyn_lights(f)
	open_doors_anim()
	H.render_hud(G)
	if G.sanity >= 50.0:
		H.set_distort(0.0)

func tp_list(pts: Array) -> void:
	G.set_meta("_tp", pts)
	G.set_meta("_tp_idx", -1)

func teleport_cycle() -> void:
	var list: Array = G.get_meta("_tp", [])
	if list.is_empty():
		return
	var idx: int = (G.get_meta("_tp_idx", -1) + 1) % list.size()
	G.set_meta("_tp_idx", idx)
	var p: Dictionary = list[idx]
	player_pos = Vector3(p["x"], 0, p["z"])
	player_yaw = p.get("yaw", 0.0)
	player_pitch = 0.0
	H.show_msg("[QA点位 %d/%d]" % [idx + 1, list.size()], 1.6)

func tp(idx: int) -> void:
	var list: Array = G.get_meta("_tp", [])
	if idx < 0 or idx >= list.size():
		return
	var p: Dictionary = list[idx]
	player_pos = Vector3(p["x"], 0, p["z"])
	player_yaw = p.get("yaw", 0.0)
	player_pitch = 0.0

# ---------- 开始 / 结局 / 死亡 ----------

func _on_start() -> void:
	S.init_audio()
	start_play(true)

func start_play(reset: bool) -> void:
	H.show_title(false)
	H.ending_screen.visible = false
	H.gameover_screen.visible = false
	H.set_hud_visible(true)
	G.playing = true
	G.modal_open = false
	G.riding = false
	if reset:
		build_floor("1F")
	else:
		build_floor(G.floor_id)
	_capture_mouse()
	S.drone(true)

func game_over(reason: String) -> void:
	if not G.playing:
		return
	G.playing = false
	G.deaths += 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	H.set_hud_visible(false)
	var txt := ""
	if reason == "sanity":
		txt = "脚步不受控制地转向楼梯间。\n钥匙串的哗啦声越来越近,越来越近。\n你想起妹妹的短信:\"别相信穿保安服的人。\"\n可你已经没有力气想了。"
	else:
		txt = "凌晨 6:00。\n晨光没有来。\n这栋楼,从不放走赖到天亮的客人。"
	if G.deaths > 1:
		txt += "\n\n(第 %d 次。遗物与权限卡还在你身上——大楼留得住你的人,留不住它们。)" % G.deaths
	H.show_gameover(txt)
	S.sting()
	S.heart(false, 0)
	S.drone(false)
	S.elevator_ride(false)
	S.update_mood(100.0)   # 复位动态状态机:死亡画面不再带低理智的闷/失真

func _on_retry() -> void:
	H.gameover_screen.visible = false
	G.sanity = 60.0
	G.battery = maxf(G.battery, 30.0)
	G.stamina = 100.0
	G.stamina_lock = false
	if G.has_flash:
		G.flash_on = true
	G.time = minf(G.time, 300.0)
	start_play(false)

func start_ending(id := "true") -> void:
	if G.flags.get("ended", false):
		return
	G.flags["ended"] = true
	ending_id = id
	G.playing = false
	add_game_minutes(15)   # 先退出 playing 再加时:时限判定不会抢跑成死亡,把结局画面顶掉
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	H.set_hud_visible(false)
	H.show_ending(ENDINGS[id]["title"], ENDINGS[id]["steps"][0])
	ending_idx = 0
	S.heart(false, 0)
	S.drone(false)
	S.update_mood(100.0)   # 结局配乐(八音盒)不被低理智的闷化/失真盖住
	if id == "true":
		S.music_box()

func ending_next() -> void:
	if not es_clickable:
		return
	ending_idx += 1
	var steps: Array = ENDINGS[ending_id]["steps"]
	if ending_idx < steps.size():
		H.ending_text.text = steps[ending_idx]
	elif ending_idx == steps.size():
		H.ending_text.text = ENDINGS[ending_id]["line"]
	else:
		H.ending_text.text = ""
		H.ending_hint.visible = false
		var t := int(minf(359.0, G.time))
		var stats := "[color=#a89f8d]—— %s ——[/color]\n\n" % ENDINGS[ending_id]["title"]
		stats += "游戏内时间:[color=#e0d6bc]%d:%02d[/color]　距离 6:00 的晨光还有 [color=#e0d6bc]%d[/color] 分钟\n" % [int(t / 60), t % 60, maxi(0, 360 - t)]
		stats += "剩余理智:[color=#e0d6bc]%d[/color] / 100\n" % ceil(G.sanity)
		stats += "遗物:[color=#e0d6bc]%d / 13[/color]%s\n" % [G.relics, ("(" + "、".join(PackedStringArray(G.relic_names)) + ")") if G.relic_names.size() > 0 else ""]
		stats += "违反规则:[color=#e0d6bc]%d[/color] 次　死亡:[color=#e0d6bc]%d[/color] 次\n\n" % [G.violations, G.deaths]
		stats += "[color=#6f6759]每年这一夜,大楼都会回来。\n集齐十三件遗物、念出所有名字,是让大家回家的唯一办法。[/color]"
		H.ending_stats.text = stats
		H.ending_stats.visible = true
		H.restart_btn.visible = true
		es_clickable = false

# ---------- 调试栏 ----------

func _build_debug_bar() -> void:
	var buttons: Array = []
	buttons.append(["传送点位", teleport_cycle])
	for f: String in FLOOR_ORDER:
		var ff := f
		buttons.append([f, func() -> void:
			H.show_title(false)
			H.set_hud_visible(true)
			G.playing = true
			if G.floor_id != ff:
				ride_to(ff, true)])
	buttons.append(["+理智", func() -> void: G.sanity = minf(100.0, G.sanity + 40.0)])
	buttons.append(["理智−60", func() -> void: change_sanity(-60.0)])
	buttons.append(["+电池", func() -> void:
		G.batteries += 2
		G.battery = 100.0])
	buttons.append(["时间→6:00", func() -> void:
		G.time = 359.0
		add_game_minutes(1)])
	buttons.append(["直通结局", func() -> void: start_ending()])
	H.build_debug(buttons)
