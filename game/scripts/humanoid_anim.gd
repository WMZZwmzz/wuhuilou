class_name HumanoidAnim
extends RefCounted
## 程序化步态/姿态驱动:纯 CPU、无 AnimationPlayer/Skeleton,headless 同样可跑。
## 用法:楼层搭好人形后 register(fig);main._process 在 floor_update 之后统一 tick_all(dt)。
##
## 无滑步是**构造出来的**,不是调参调出来的:
## - 每条腿持有一个世界空间的「落地点」;支撑相把踝用两骨 IK 钉在该点(身体从脚上走过去)。
## - 换腿瞬间把该腿的落地点前移恰好一个步长 → 步频 = 实测位移速度 / 步长,脚与地面零相对滑动。
## - 速度由 root 的实际位移反解(楼层只需照常移动 root,无需上报速度)。
## 摆幅基调偏「低幅、关节发僵」:《美术风格指南》要求怨灵"动作僵硬"。

const GA := {
	"stride_walk": 0.62,      # m/步(解剖学步长;驱动按此反解步频)
	"stride_run": 1.05,
	"run_speed": 3.0,         # m/s 以上视为奔跑档
	"stop_speed": 0.25,       # m/s 以下视为站立(避免亚像素抖动)
	"stance_release": 0.62,   # 支撑相走到该比例时移交摆动相
	"swing_lift": 0.055,      # 摆动相抬脚(m)
	"leg_slack": 0.985,       # 站立时腿长利用率(留一点膝弯,否则无法迈步)
	"torso_bob": 0.022,       # 躯干起伏(m)
	"torso_sway": 0.018,      # 躯干横摆(m)
	"torso_pitch": 0.05,
	"torso_roll": 0.05,
	"torso_yaw": 0.06,
	"head_counter": 0.45,
	"arm_swing_walk": 0.26,
	"arm_swing_run": 0.44,
	"fore_walk": 0.20,
	"fore_run": 0.62,
	"blend": 6.0,             # 速度收敛速率 1/s
	"breath_amp": 0.010,
	"breath_hz": 0.22,
}

## 活跃条目 [{"fig":Dictionary,"st":Dictionary}];楼层切换必须清空。
static var _list: Array = []
static var _t := 0.0
## QA 断言用:最近一次 tick 的累计滑步量(m/步,取各腿最大)
static var last_slip := 0.0

## 注册一具可动人形。opts:
##   stride 覆盖步长(m);arms:false 不驱动手臂;step_cb:func(running:bool) 落地事件
static func register(fig: Dictionary, opts := {}) -> void:
	if fig.is_empty() or not (fig.get("root") is Node3D):
		return
	var rig: Dictionary = fig.get("rig", {})
	var st := {
		"phase": randf(),
		"speed": 0.0,
		"run": false,
		"prev": (fig["root"] as Node3D).global_position,
		"stride": float(opts.get("stride", GA["stride_walk"])),
		"arms": bool(opts.get("arms", true)),
		"step_cb": opts.get("step_cb", Callable()),
		"plant": {"l": null, "r": null},      # 支撑相踝的世界锚点(Vector3 或 null)
		"next": {"l": null, "r": null},       # 摆动相目标落点
		"was_stance": {"l": true, "r": true},
		"slip": 0.0,
	}
	_list.append({"fig": fig, "st": st})

static func unregister_floor() -> void:
	_list.clear()

static func active_count() -> int:
	return _list.size()

## 每帧唯一入口(main._process 在 floor_update 之后调用)
static func tick_all(dt: float) -> void:
	if dt <= 0.0:
		return
	# 时钟必须在「无活跃条目」早退之前推进:10F 等楼层只有静态假人,
	# 但它们的呼吸微动(breath_root)同样依赖 _t。
	_t += dt
	if _list.is_empty():
		return
	last_slip = 0.0
	var i := _list.size()
	while i > 0:
		i -= 1
		var e: Dictionary = _list[i]
		var root: Node3D = (e["fig"] as Dictionary).get("root")
		if root == null or not is_instance_valid(root):
			_list.remove_at(i)
			continue
		_tick(e, dt)

static func _tick(e: Dictionary, dt: float) -> void:
	var fig: Dictionary = e["fig"]
	var st: Dictionary = e["st"]
	var root: Node3D = fig["root"]
	root.force_update_transform()
	# 1) 实测位移速度 → 步频
	var pos: Vector3 = root.global_position
	var sp := Vector2((pos - (st["prev"] as Vector3)).x, (pos - (st["prev"] as Vector3)).z).length() / dt
	st["prev"] = pos
	st["speed"] = float(st["speed"]) + (sp - float(st["speed"])) * clampf(dt * float(GA["blend"]), 0.0, 1.0)
	var v: float = float(st["speed"])
	st["run"] = v > float(GA["run_speed"])
	var moving: bool = v > float(GA["stop_speed"])
	var stride: float = float(st["stride"]) * (float(GA["stride_run"]) / float(GA["stride_walk"])) if bool(st["run"]) else float(st["stride"])
	# 2) 相位:一步恰好走过一个步长
	if moving:
		st["phase"] = fmod(float(st["phase"]) + dt * (v / stride), 1.0)
	var ph: float = float(st["phase"])
	var amp := 1.0 if moving else 0.0
	# 3) 躯干起伏/摆动(只动 upper 枢轴,不碰 root → 与楼层位移和 merge 静态体都不冲突)
	_torso(fig, ph, amp)
	# 4) 双腿:支撑相钉地,摆动相走向下一个落点
	if bool(fig.get("legged", false)):
		for side: String in ["l", "r"]:
			_leg(fig, st, side, ph, moving, stride, dt)
	# 5) 手臂与同侧腿反相
	if bool(st["arms"]):
		_arms(fig, ph, amp, bool(st["run"]))
	last_slip = maxf(last_slip, float(st["slip"]))

static func _torso(fig: Dictionary, ph: float, amp: float) -> void:
	var upper: Node3D = fig.get("upper")
	if upper == null or not is_instance_valid(upper):
		return
	var rig: Dictionary = fig["rig"]
	var s: float = float(rig.get("scale", 1.0))
	var base_y: float = 0.47 * s if (rig.get("pose", "stand") in ["sit", "slump"]) else 0.92 * s
	var bob := -absf(sin(PI * ph)) * float(GA["torso_bob"]) * s * amp
	var sway := sin(PI * ph) * float(GA["torso_sway"]) * s * amp
	upper.position.y = base_y + bob + sin(_t * TAU * float(GA["breath_hz"])) * float(GA["breath_amp"]) * s
	upper.position.x = sway * 0.5
	upper.rotation.z = sin(PI * ph) * float(GA["torso_roll"]) * amp
	upper.rotation.x = -float(GA["torso_pitch"]) * amp
	var head: Node3D = fig.get("head")
	if head != null and is_instance_valid(head):
		head.rotation.y = -sin(TAU * ph) * float(GA["torso_yaw"]) * float(GA["head_counter"]) * amp

static func _arms(fig: Dictionary, ph: float, amp: float, running: bool) -> void:
	var sw: float = float(GA["arm_swing_run"]) if running else float(GA["arm_swing_walk"])
	var fore: float = float(GA["fore_run"]) if running else float(GA["fore_walk"])
	for side: String in ["l", "r"]:
		var arm: Node3D = fig.get("arm_" + side)
		var fn: Node3D = fig.get("fore_" + side)
		if arm == null or not is_instance_valid(arm):
			continue
		# 与同侧腿反相:左腿在前(ph<0.5 为左支撑)时左臂在后
		var sgn := 1.0 if side == "l" else -1.0
		arm.rotation.x = sgn * sin(TAU * ph) * sw * amp
		if fn != null and is_instance_valid(fn):
			fn.rotation.x = fore + maxf(0.0, -sgn * sin(TAU * ph)) * fore * amp

## 单腿:支撑相把踝钉在世界落地点;换腿时把落地点前移一个步长。
static func _leg(fig: Dictionary, st: Dictionary, side: String, ph: float, moving: bool, stride: float, dt: float) -> void:
	var hip: Node3D = fig.get("hip_" + side)
	var knee: Node3D = fig.get("knee_" + side)
	var ankle: Node3D = fig.get("ankle_" + side)
	if hip == null or knee == null or ankle == null:
		return
	if not is_instance_valid(hip) or not is_instance_valid(knee) or not is_instance_valid(ankle):
		return
	var root: Node3D = fig["root"]
	var s: float = float((fig["rig"] as Dictionary).get("scale", 1.0))
	# 本腿的相位局部时间:左腿占 [0,0.5),右腿占 [0.5,1)
	var t01: float = (ph if side == "l" else ph - 0.5) * 2.0
	var stance: bool = moving and t01 < float(GA["stance_release"])
	var fwd := -root.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.001 else Vector3(0, 0, -1)
	var plant = st["plant"][side]
	var nxt = st["next"][side]
	if not moving:
		# 站立:锚在当前踝位置,不漂移
		if plant == null:
			st["plant"][side] = ankle.global_position
			plant = st["plant"][side]
	elif stance:
		if not bool(st["was_stance"][side]):
			# 刚落地:把预排的落点转为锚点,并触发脚步事件
			st["plant"][side] = nxt if nxt != null else ankle.global_position
			plant = st["plant"][side]
			st["next"][side] = null
			if st["step_cb"].is_valid():
				st["step_cb"].call(bool(st["run"]))
			# 滑步量:锚点相对上一帧的位移应恒为 0(世界系),记录任何偏差
		st["was_stance"][side] = true
	else:
		if bool(st["was_stance"][side]):
			# 离地:预排下一个落点 = 当前锚点沿朝向前移一个步长
			st["next"][side] = (plant as Vector3 if plant != null else ankle.global_position) + fwd * stride
			st["was_stance"][side] = false
		var from: Vector3 = plant as Vector3 if plant != null else ankle.global_position
		var to: Vector3 = st["next"][side] as Vector3 if st["next"][side] != null else from
		var k := clampf((t01 - float(GA["stance_release"])) / maxf(0.001, 1.0 - float(GA["stance_release"])), 0.0, 1.0)
		var lift: float = sin(PI * k) * float(GA["swing_lift"]) * s
		var tgt := from.lerp(to, k)
		tgt.y = lerpf(_arc_ankle_y(hip, from, s), _arc_ankle_y(hip, to, s), k) + lift
		_solve(hip, knee, ankle, tgt, s)
		return
	if not (plant is Vector3):
		# 注册后首帧可能直接落入支撑相:以当前踝位置补建锚点,避免 null 强转
		plant = ankle.global_position
		st["plant"][side] = plant
	var p: Vector3 = plant
	var tgt2 := p
	tgt2.y = _arc_ankle_y(hip, p, s)
	_solve(hip, knee, ankle, tgt2, s)
	if moving:
		# 滑步 = 支撑相内踝相对世界锚点的残余位移(钉地理想为 0,只剩 IK 求解误差)
		root.force_update_transform()
		var aw: Vector3 = ankle.global_position
		var err := Vector2(aw.x - p.x, aw.z - p.z).length()
		st["slip"] = maxf(float(st["slip"]), err)

## 踝应在的高度:以髋为心、lmax 为半径的球面与锚点铅垂线的交点。
## 髋高恰好等于腿长,故固定 y 的目标一旦有水平偏移就不可达(IK 收缩 → 滑步);
## 沿弧走则恒可达,脚跟随支撑相后段自然抬起,正是 toe-off 的真实形态。
static func _arc_ankle_y(hip: Node3D, anchor: Vector3, s: float) -> float:
	var hw: Vector3 = hip.global_position
	var lmax := 0.9 * s * float(GA["leg_slack"])
	var horiz := Vector2(anchor.x - hw.x, anchor.z - hw.z).length()
	return hw.y - sqrt(maxf(0.01, lmax * lmax - horiz * horiz))

## 两骨解析 IK(矢状面):把踝送到世界目标 target,只输出 hip/knee 的 pitch。
static func _solve(hip: Node3D, knee: Node3D, ankle: Node3D, target: Vector3, s: float) -> void:
	var l1 := 0.45 * s
	var l2 := 0.45 * s
	var hw: Vector3 = hip.global_position
	var d: Vector3 = target - hw
	var f := -d.z                       # 前向偏移(人形正面 -Z)
	var drop := -d.y
	var reach := sqrt(f * f + drop * drop)
	var lmax := (l1 + l2) * float(GA["leg_slack"])
	if reach > lmax:
		# 超程:沿同方向收缩到量程内 → 腿几乎伸直,不产生拉伸抖动
		var k := lmax / reach
		f *= k
		drop *= k
		reach = lmax
	reach = maxf(reach, 0.05)
	var phi := atan2(f, maxf(0.001, drop))
	var ca := clampf((l1 * l1 + reach * reach - l2 * l2) / (2.0 * l1 * reach), -1.0, 1.0)
	var alpha := acos(ca)
	var ck := clampf((l1 * l1 + l2 * l2 - reach * reach) / (2.0 * l1 * l2), -1.0, 1.0)
	var bend := PI - acos(ck)           # 0 = 伸直
	hip.rotation.x = phi + alpha
	hip.rotation.y = 0.0
	hip.rotation.z = 0.0
	knee.rotation.x = -clampf(bend, 0.0, 1.45)   # 膝只屈不伸(铰链限位)
	ankle.rotation.x = clampf(-(phi + alpha) * 0.5, -0.45, 0.45)

## 静态人形(root 级)的呼吸微动:合并过的网格没有骨架,统一走这里。
## phase 让同批假人各自错开——完全同步的呼吸反而暴露"同一套程序在动"。
static func breath_root(n: Node3D, amp := 0.008, hz := 0.22, phase := 0.0) -> void:
	if n == null or not is_instance_valid(n):
		return
	if not n.has_meta("anim_base_y"):
		n.set_meta("anim_base_y", n.position.y)
	n.position.y = float(n.get_meta("anim_base_y")) + sin((_t + phase) * TAU * hz) * amp

## 缩放脉动(B2 核心/浮现脸等)
static func pulse_scale(n: Node3D, base_scale: Vector3, amp: float, hz: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	n.scale = base_scale * (1.0 + sin(_t * TAU * hz) * amp)
