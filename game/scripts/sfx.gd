class_name Sfx
extends Node
## 音效:优先加载 res://sounds/ 下的外部 CC0 资源(来源与授权见 sounds/CREDITS.md),
## 缺失的键回退为启动时 22050Hz 16bit PCM 程序化合成 —— 删掉资源目录也能跑。
## 对外接口(play_buf/ding/click/flash/sting/whisper/thud/heart/drone/music_box 等)保持稳定,
## main.gd / floor_*.gd / qa_runner.gd 直接依赖,勿随意改名。

const SR := 22050

## 外部资源清单:键 → 单路径或变体路径数组(变体组播放时随机取一)
const EXT := {
	"ding": "res://sounds/ding.ogg",
	"ding2": "res://sounds/ding.ogg",
	"click": "res://sounds/click.ogg",
	"flash": "res://sounds/flash.ogg",
	"sting": "res://sounds/sting.wav",
	"thud": "res://sounds/thud.ogg",
	"music_box": "res://sounds/music_box.ogg",
	"drone": "res://sounds/drone.wav",
	"elevator_ride": "res://sounds/elevator_ride.wav",
	"drip": "res://sounds/drip.wav",
	"keys": [
		"res://sounds/keys_0.ogg", "res://sounds/keys_1.ogg", "res://sounds/keys_2.ogg",
		"res://sounds/keys_3.ogg", "res://sounds/keys_4.ogg",
	],
	"marble": [
		"res://sounds/marble_0.ogg", "res://sounds/marble_1.ogg", "res://sounds/marble_2.ogg",
	],
	"scratch": "res://sounds/scratch.wav",
	"ding_off": "res://sounds/ding_off.wav",
	"rumble": "res://sounds/rumble.wav",
	"heart_slow": "res://sounds/heart_slow.wav",
	"heart_fast": "res://sounds/heart_fast.wav",
	"whisper": [
		"res://sounds/whisper_0.wav", "res://sounds/whisper_1.wav", "res://sounds/whisper_2.wav",
		"res://sounds/whisper_3.wav", "res://sounds/whisper_4.wav", "res://sounds/whisper_5.wav",
	],
	"footstep": [
		"res://sounds/footstep_0.ogg", "res://sounds/footstep_1.ogg", "res://sounds/footstep_2.ogg",
		"res://sounds/footstep_3.ogg", "res://sounds/footstep_4.ogg",
	],
}

var ext_loaded := 0   # 外部资源成功加载的键数(QA 断言用)

var _muted := false
var _bufs := {}
var _pool: Array[AudioStreamPlayer] = []
var _drone: AudioStreamPlayer = null
var _drone_on := false
var _ride: AudioStreamPlayer = null
var _ride_on := false
var _heart_p: AudioStreamPlayer = null
var _heart_key := ""
var _h_rate := -1
var _h_acc := 0.0
# 第二心音 / 叮声二连音的延迟播放:统一在 _process 排程,免每次新建 SceneTreeTimer
var _delayed := []      # [剩余秒数, Callable]
# 动态音频状态机(音效指南 §四):理智驱动的效果器与低频轰鸣,值缓存变化才写 AudioServer
var _mood_sanity := -1.0
var _muffle_fx: AudioEffectLowPassFilter = null
var _dist_fx: AudioEffectDistortion = null
var _rumble: AudioStreamPlayer = null
var _rumble_on := false
var _rumble_db := -10.0
var _rumble_tw: Tween = null
var _hush_left := 0.0   # "突然安静"剩余秒数,归零后在 _process 恢复 Ambience 总线
# 空间音频:世界锚定音的 3D 播放器池(Godot 以 current Camera3D 为听者)
var _pool3d: Array[AudioStreamPlayer3D] = []

func _ready() -> void:
	_setup_buses()
	for i in 9:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_drone = _make_loop_player("Ambience")
	_ride = _make_loop_player("Ambience")
	_heart_p = _make_loop_player("SFX")
	_rumble = _make_loop_player("Ambience")
	for i in 6:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 14.0        # 衰减参考距离,45m 外归零
		p3.max_distance = 45.0
		add_child(p3)
		_pool3d.append(p3)
	_load_external()
	var ext_rumble: bool = _bufs.has("rumble")
	_synth_fallbacks()
	# 外部流不自带循环:靠 finished 重播(合成 drone 自带 LOOP_FORWARD,重复 play 无害)
	_drone.finished.connect(func() -> void:
		if _drone_on and not _muted:
			_drone.play())
	_ride.finished.connect(func() -> void:
		if _ride_on and not _muted:
			_ride.play())
	_rumble.finished.connect(func() -> void:
		if _rumble_on and not _muted:
			_rumble.play())
	if _bufs.has("drone"):
		_drone.stream = _bufs["drone"]
		_drone.volume_db = -6.0
	else:
		_drone.stream = _make_drone()
		_drone.volume_db = linear_to_db(0.05)
	if not _bufs.has("rumble"):
		_bufs.rumble = _make_rumble()
	_rumble.stream = _bufs["rumble"]
	_rumble_db = -10.0 if ext_rumble else -8.0
	_rumble.volume_db = _rumble_db

func _make_loop_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func _setup_buses() -> void:
	for bus: String in ["SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)  # send 默认 Master
	var mi := AudioServer.get_bus_index("Master")
	var has_lim := false
	for i in AudioServer.get_bus_effect_count(mi):
		if AudioServer.get_bus_effect(mi, i) is AudioEffectLimiter:
			has_lim = true
	if not has_lim:
		# 多个 sting/心跳叠加时防止 Master 削波爆音
		AudioServer.add_bus_effect(mi, AudioEffectLimiter.new())
	# 动态状态机效果器:Master 低通插在 Limiter 之前(低理智"变闷"),SFX 失真默认关。
	# 场景重载会再进一次 _ready,按类型找已有效果器复用,避免重复堆叠
	_muffle_fx = null
	for i in AudioServer.get_bus_effect_count(mi):
		var e: AudioEffect = AudioServer.get_bus_effect(mi, i)
		if e is AudioEffectLowPassFilter:
			_muffle_fx = e
			break
	if _muffle_fx == null:
		_muffle_fx = AudioEffectLowPassFilter.new()
		_muffle_fx.cutoff_hz = 20500.0
		AudioServer.add_bus_effect(mi, _muffle_fx, 0)
	var si := AudioServer.get_bus_index("SFX")
	for i in AudioServer.get_bus_effect_count(si):
		var e2: AudioEffect = AudioServer.get_bus_effect(si, i)
		if e2 is AudioEffectDistortion:
			_dist_fx = e2
			break
	if _dist_fx == null:
		_dist_fx = AudioEffectDistortion.new()
		AudioServer.add_bus_effect(si, _dist_fx)
	AudioServer.set_bus_effect_enabled(si, AudioServer.get_bus_effect_count(si) - 1, false)

func _load_external() -> void:
	for key: String in EXT:
		var paths: Array = EXT[key] if EXT[key] is Array else [EXT[key]]
		var loaded: Array = []
		for p: String in paths:
			if ResourceLoader.exists(p):
				var s: AudioStream = load(p)
				if s != null:
					loaded.append(s)
		if not loaded.is_empty():
			_bufs[key] = loaded if loaded.size() > 1 else loaded[0]
			ext_loaded += 1

func _process(delta: float) -> void:
	# 延迟回调排程(第二心音 0.18s / 叮声二连音 0.16s):不逐次建 SceneTreeTimer
	for i in range(_delayed.size() - 1, -1, -1):
		var d: Array = _delayed[i]
		d[0] -= delta
		if float(d[0]) <= 0.0:
			_delayed.remove_at(i)
			(d[1] as Callable).call()
	# 心跳节拍(合成回退模式;外部资源走 heart() 内的循环流切换)
	if _h_rate > 0:
		_h_acc += delta
		if _h_acc >= _h_rate / 1000.0:
			_h_acc = 0.0
			play_buf("heart1", 0.28)
			_delay(0.18, func(): play_buf("heart2", 0.2))
	# "突然安静"到期恢复 Ambience 总线
	if _hush_left > 0.0:
		_hush_left -= delta
		if _hush_left <= 0.0:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), 0.0)

## 秒级延迟回调(_process 排程;Sfx 常驻节点,生命周期与场景一致)
func _delay(sec: float, fn: Callable) -> void:
	_delayed.append([sec, fn])

# ---------- 合成原语 ----------

static func _clamp01(x: float) -> float:
	return clampf(x, -1.0, 1.0)

func _tone(freq: float, type: String, attack: float, decay: float, peak: float, slide_to: float = 0.0) -> AudioStreamWAV:
	var total := attack + decay
	var n := int(total * SR)
	var b := PackedByteArray()
	b.resize(n * 2)
	var phase := 0.0
	var f_cur := freq
	for i in n:
		var t := i / float(SR)
		if slide_to > 0.0:
			f_cur = freq * pow(slide_to / freq, clampf(t / total, 0.0, 1.0))
		phase += TAU * f_cur / SR
		var s := 0.0
		match type:
			"sine": s = sin(phase)
			"square": s = 1.0 if fmod(phase, TAU) < PI else -1.0
			"saw": s = fmod(phase, TAU) / PI - 1.0
		var env := 0.0
		if t < attack:
			env = t / attack
		else:
			env = pow(0.0001, (t - attack) / decay)
		var v := int(_clamp01(s * env * peak) * 32767.0)
		b.encode_s16(i * 2, v)
	return _wav(b)

func _noise(dur: float, peak: float, band_lo: float, band_hi: float) -> AudioStreamWAV:
	var n := int(dur * SR)
	var b := PackedByteArray()
	b.resize(n * 2)
	var lp1 := 0.0
	var lp2 := 0.0
	var a1 := 1.0 - exp(-TAU * band_hi / SR)
	var a2 := 1.0 - exp(-TAU * band_lo / SR)
	for i in n:
		var t := i / float(SR)
		var x := randf() * 2.0 - 1.0
		lp1 += a1 * (x - lp1)
		lp2 += a2 * (lp1 - lp2)
		var s := lp1 - lp2          # 带通 ≈ [lo, hi]
		var env := minf(t / 0.05, 1.0) * pow(0.0001, maxf(t - 0.05, 0.0) / dur)
		var v := int(_clamp01(s * env * peak) * 32767.0)
		b.encode_s16(i * 2, v)
	return _wav(b)

func _synth_mahjong() -> AudioStreamWAV:
	# 麻将/骨牌碰撞:一串短带通噪声脉冲(合成一次固定时序,播放时再叠音高随机)
	var pulses: Array = []
	var t := 0.0
	for i in 5 + randi() % 4:
		var d := 0.012 + randf() * 0.016
		pulses.append([t, d, 0.22 + randf() * 0.18])
		t += d + 0.022 + randf() * 0.045
	var n := int((t + 0.05) * SR)
	var b := PackedByteArray()
	b.resize(n * 2)
	var lp1 := 0.0
	var lp2 := 0.0
	var a1 := 1.0 - exp(-TAU * 3800.0 / SR)
	var a2 := 1.0 - exp(-TAU * 900.0 / SR)
	for i in n:
		var time := i / float(SR)
		var x := randf() * 2.0 - 1.0
		lp1 += a1 * (x - lp1)
		lp2 += a2 * (lp1 - lp2)
		var s: float = lp1 - lp2
		var env := 0.0
		for pu: Array in pulses:
			var dt: float = time - pu[0]
			if dt >= 0.0 and dt < pu[1]:
				env = maxf(env, (dt / pu[1]) * pow(0.001, dt / pu[1]) * pu[2])
		var v := int(_clamp01(s * env) * 32767.0)
		b.encode_s16(i * 2, v)
	return _wav(b)

func _synth_keys() -> AudioStreamWAV:
	# 钥匙串碰撞:比麻将更密、更高频的金属脉冲簇
	var pulses: Array = []
	var t := 0.0
	for i in 6 + randi() % 4:
		var d := 0.008 + randf() * 0.01
		pulses.append([t, d, 0.16 + randf() * 0.14])
		t += d + 0.015 + randf() * 0.05
	var n := int((t + 0.06) * SR)
	var b := PackedByteArray()
	b.resize(n * 2)
	var lp1 := 0.0
	var lp2 := 0.0
	var a1 := 1.0 - exp(-TAU * 7600.0 / SR)
	var a2 := 1.0 - exp(-TAU * 2600.0 / SR)
	for i in n:
		var time := i / float(SR)
		var x := randf() * 2.0 - 1.0
		lp1 += a1 * (x - lp1)
		lp2 += a2 * (lp1 - lp2)
		var s: float = lp1 - lp2
		var env := 0.0
		for pu: Array in pulses:
			var dt: float = time - pu[0]
			if dt >= 0.0 and dt < pu[1]:
				env = maxf(env, (dt / pu[1]) * pow(0.001, dt / pu[1]) * pu[2])
		var v := int(_clamp01(s * env) * 32767.0)
		b.encode_s16(i * 2, v)
	return _wav(b)

func _synth_scratch() -> AudioStreamWAV:
	# 金属刮擦:高频带通噪声 + ~14Hz 幅度颤动(刮擦的涩感),1.2s 渐弱
	var dur := 1.2
	var n := int(dur * SR)
	var b := PackedByteArray()
	b.resize(n * 2)
	var lp1 := 0.0
	var lp2 := 0.0
	var a1 := 1.0 - exp(-TAU * 5200.0 / SR)
	var a2 := 1.0 - exp(-TAU * 1800.0 / SR)
	for i in n:
		var t := i / float(SR)
		var x := randf() * 2.0 - 1.0
		lp1 += a1 * (x - lp1)
		lp2 += a2 * (lp1 - lp2)
		var s: float = lp1 - lp2
		var trem := 0.55 + 0.45 * sin(TAU * 14.0 * t + sin(TAU * 3.1 * t) * 1.5)
		var env: float = minf(t / 0.06, 1.0) * trem * pow(0.0002, t / dur)
		var v := int(_clamp01(s * env * 0.5) * 32767.0)
		b.encode_s16(i * 2, v)
	return _wav(b)

func _synth_marble() -> AudioStreamWAV:
	# 弹珠落地:硬质初击 + 2 次递减反弹(间隔渐大、音量渐小)
	var bounces := [[0.0, 0.5], [0.11, 0.28], [0.24, 0.15]]
	var n := int(0.5 * SR)
	var b := PackedByteArray()
	b.resize(n * 2)
	for bo: Array in bounces:
		var start := int(bo[0] * SR)
		var peak: float = bo[1]
		var f := 2000.0 + randf() * 600.0
		var dur := 0.045
		for i in int(dur * SR):
			var idx := start + i
			if idx >= n:
				break
			var t := i / float(SR)
			var s := sin(TAU * f * t) * pow(0.0005, t / dur) * peak
			var cur := b.decode_s16(idx * 2) / 32767.0
			b.encode_s16(idx * 2, int(_clamp01(cur + s) * 32767.0))
	return _wav(b)

func _synth_ding_off() -> AudioStreamWAV:
	# 失谐铃:655/661Hz 差拍 + 缓慢下滑 + 八度泛音,电梯铃"发不对"的错觉
	var dur := 1.1
	var n := int(dur * SR)
	var b := PackedByteArray()
	b.resize(n * 2)
	for i in n:
		var t := i / float(SR)
		var env := pow(0.0004, t / dur)
		var f1 := 655.0 + t * 6.0
		var s := (sin(TAU * f1 * t) + sin(TAU * 661.0 * t)) * 0.4 * env
		s += sin(TAU * f1 * 2.01 * t) * 0.12 * env
		var v := int(_clamp01(s * 0.35) * 32767.0)
		b.encode_s16(i * 2, v)
	return _wav(b)

func _make_drone() -> AudioStreamWAV:
	var dur := 8.0
	var n := int(dur * SR)
	var b := PackedByteArray()
	b.resize(n * 2)
	var p1 := 0.0
	var p2 := 0.0
	var lp := 0.0
	var a := 1.0 - exp(-TAU * 200.0 / SR)
	var xf := int(0.05 * SR)       # 环接交叉淡化,消除循环咔哒
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		p1 += TAU * 48.0 / SR
		p2 += TAU * 48.7 / SR
		lp += a * ((sin(p1) + sin(p2)) * 0.5 - lp)
		samples[i] = lp * 0.05
	for i in n:
		var s := samples[i]
		if i < xf:
			var tail := samples[n - xf + i]
			var k := i / float(xf)
			s = s * k + tail * (1.0 - k)
		var v := int(_clamp01(s * 4.0) * 32767.0)
		b.encode_s16(i * 2, v)
	var w := _wav(b)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

func _make_rumble() -> AudioStreamWAV:
	# 低频轰鸣:38/39.2Hz 拍频 + 0.4Hz 起伏(比 drone 更低、更"压胸"),8s 环接
	var dur := 8.0
	var n := int(dur * SR)
	var b := PackedByteArray()
	b.resize(n * 2)
	var p1 := 0.0
	var p2 := 0.0
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := i / float(SR)
		p1 += TAU * 38.0 / SR
		p2 += TAU * 39.2 / SR
		var swell := 0.7 + 0.3 * sin(TAU * 0.4 * t)
		samples[i] = (sin(p1) + sin(p2)) * 0.5 * swell * 0.35
	var xf := int(0.05 * SR)       # 环接交叉淡化,消除循环咔哒
	for i in n:
		var s := samples[i]
		if i < xf:
			var tail := samples[n - xf + i]
			var k := i / float(xf)
			s = s * k + tail * (1.0 - k)
		var v := int(_clamp01(s) * 32767.0)
		b.encode_s16(i * 2, v)
	var w := _wav(b)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

func _make_hum() -> AudioStreamWAV:
	# 乘梯嗡鸣回退:110/220Hz 电机哼声 + 轻噪声,4s 环接
	var dur := 4.0
	var n := int(dur * SR)
	var b := PackedByteArray()
	b.resize(n * 2)
	var lp := 0.0
	var a := 1.0 - exp(-TAU * 300.0 / SR)
	var xf := int(0.05 * SR)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := i / float(SR)
		lp += a * ((randf() * 2.0 - 1.0) - lp)
		var wob := 1.0 + 0.02 * sin(TAU * 0.6 * t)
		samples[i] = (sin(TAU * 110.0 * t) * 0.4 + sin(TAU * 220.0 * t) * 0.18) * wob + lp * 0.03
	for i in n:
		var s := samples[i]
		if i < xf:
			var tail := samples[n - xf + i]
			var k := i / float(xf)
			s = s * k + tail * (1.0 - k)
		var v := int(_clamp01(s * 0.5) * 32767.0)
		b.encode_s16(i * 2, v)
	var w := _wav(b)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

func _wav(b: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = b
	return w

func _synth_fallbacks() -> void:
	# 外部资源未覆盖的键,逐个回退合成
	if not _bufs.has("ding"): _bufs.ding = _tone(880.0, "sine", 0.005, 0.6, 0.18)
	if not _bufs.has("ding2"): _bufs.ding2 = _tone(660.0, "sine", 0.005, 0.8, 0.14)
	if not _bufs.has("click"): _bufs.click = _tone(500.0, "square", 0.005, 0.06, 0.06)
	if not _bufs.has("flash"): _bufs.flash = _tone(700.0, "square", 0.003, 0.04, 0.05)
	if not _bufs.has("sting"): _bufs.sting = _tone(220.0, "saw", 0.01, 0.9, 0.22, 60.0)
	_bufs.sting_n = _noise(0.5, 0.1, 120.0, 500.0)   # 刺音噪声层始终合成(与外部 stab 叠加)
	if not _bufs.has("whisper"): _bufs.whisper = _noise(1.4, 0.05, 900.0, 2600.0)
	if not _bufs.has("thud"): _bufs.thud = _tone(70.0, "sine", 0.01, 0.4, 0.3)
	if not _bufs.has("heart1"): _bufs.heart1 = _tone(55.0, "sine", 0.01, 0.16, 0.28)
	if not _bufs.has("heart2"): _bufs.heart2 = _tone(50.0, "sine", 0.01, 0.14, 0.2)
	if not _bufs.has("footstep"): _bufs.footstep = _noise(0.09, 0.05, 50.0, 220.0)
	if not _bufs.has("mahjong"): _bufs.mahjong = _synth_mahjong()
	if not _bufs.has("keys"): _bufs.keys = _synth_keys()
	if not _bufs.has("scratch"): _bufs.scratch = _synth_scratch()
	if not _bufs.has("marble"): _bufs.marble = _synth_marble()
	if not _bufs.has("ding_off"): _bufs.ding_off = _synth_ding_off()
	if not _bufs.has("drip"): _bufs.drip = _tone(2600.0, "sine", 0.002, 0.12, 0.14, 1400.0)
	if not _bufs.has("elevator_ride"): _bufs.elevator_ride = _make_hum()
	for f in [660.0, 587.0, 523.0, 587.0, 660.0, 880.0]:
		var k := "mb_%d" % int(f)
		if not _bufs.has(k):
			_bufs[k] = _tone(f, "sine", 0.01, 0.9, 0.1)

# ---------- 对外接口 ----------

func init_audio() -> void:
	pass  # Godot 无需用户手势激活,保留接口以对齐调用方

func toggle_mute() -> bool:
	_muted = not _muted
	for p in _pool:
		p.stop()
	if _muted:
		_drone.stop()
		_ride.stop()
		_heart_p.stop()
		_rumble.stop()
	else:
		if _drone_on:
			_drone.play()
		if _ride_on:
			_ride.play()
		if _heart_key != "":
			_heart_p.play()
		if _rumble_on:
			_rumble.volume_db = _rumble_db
			_rumble.play()
	return _muted

func _pick(key: String) -> AudioStream:
	var entry: Variant = _bufs[key]
	if entry is Array:
		return entry[randi() % entry.size()]
	return entry

func play_buf(name: String, vol: float = 1.0, pitch: float = 1.0) -> void:
	if _muted or not _bufs.has(name):
		return
	var stream := _pick(name)
	for p in _pool:
		if not p.playing:
			_start(p, stream, vol, pitch)
			return
	_start(_pool[0], stream, vol, pitch)

## 世界锚定音:3D 空间播放(相机为听者,距离/方位自动衰减);事件惊吓音与 UI 音仍走 play_buf
func play_at(key: String, pos: Vector3, vol: float = 1.0, pitch: float = 1.0) -> void:
	if _muted or not _bufs.has(key):
		return
	var stream := _pick(key)
	for p in _pool3d:
		if not p.playing:
			_start_at(p, stream, pos, vol, pitch)
			return
	_start_at(_pool3d[0], stream, pos, vol, pitch)

func _start_at(p: AudioStreamPlayer3D, stream: AudioStream, pos: Vector3, vol: float, pitch: float) -> void:
	p.stream = stream
	p.global_position = pos
	p.volume_db = linear_to_db(maxf(vol, 0.0002))
	p.pitch_scale = pitch
	p.play()

func _start(p: AudioStreamPlayer, stream: AudioStream, vol: float, pitch: float) -> void:
	p.stream = stream
	p.volume_db = linear_to_db(maxf(vol, 0.0002))
	p.pitch_scale = pitch
	p.play()

func ding() -> void:
	play_buf("ding", 0.9)
	_delay(0.16, func(): play_buf("ding2", 0.75, 0.82))

func click() -> void:
	play_buf("click", 0.9)

func flash() -> void:
	play_buf("flash", 1.0)

func sting() -> void:
	play_buf("sting", 2.8)
	play_buf("sting_n", 1.0)

func whisper() -> void:
	play_buf("whisper", 1.0, randf_range(0.94, 1.06))

func thud() -> void:
	play_buf("thud", 1.3)

func play_step(running: bool) -> void:
	play_buf("footstep", 0.55 if running else 0.42, randf_range(0.93, 1.07))

func mahjong() -> void:
	play_buf("mahjong", randf_range(0.5, 0.85), randf_range(0.88, 1.12))

func scratch() -> void:
	play_buf("scratch", 1.1, randf_range(0.92, 1.08))

## 素材键是否可用(QA 断言用;play_buf 缺键是静默失败)
func has(name: String) -> bool:
	return _bufs.has(name)

## ---------- 动态音频状态机(音效指南 §四) ----------
## 理智驱动:>60 干净;50–26 SFX 轻失真;25 以下失真保留 + 低频轰鸣渐入;
## 60 以下声音渐"闷"(Master 低通),≤10 约剩 700Hz —— 理智 0 时"全部声音拉远变闷"。
## 值缓存:理智变化 ≥0.5 才写 AudioServer,连续掉理智时写参数频率有上限。
func update_mood(sanity: float) -> void:
	sanity = clampf(sanity, 0.0, 100.0)
	if _mood_sanity >= 0.0 and absf(sanity - _mood_sanity) < 0.5:
		return
	_mood_sanity = sanity
	var muffle := clampf((60.0 - sanity) / 50.0, 0.0, 1.0)
	_muffle_fx.cutoff_hz = lerpf(20500.0, 700.0, muffle)
	# SFX 失真:50–26 轻度,25 以下加深(4.7 的 drive 为 0..1 线性值)
	var want_drive := 0.5 if sanity < 25.0 else (0.3 if sanity < 50.0 else 0.0)
	if not is_equal_approx(_dist_fx.drive, want_drive):
		_dist_fx.drive = want_drive
	var si := AudioServer.get_bus_index("SFX")
	var want_on: bool = want_drive > 0.0
	if AudioServer.is_bus_effect_enabled(si, 0) != want_on:
		AudioServer.set_bus_effect_enabled(si, 0, want_on)
	_set_rumble(sanity < 25.0)

func _set_rumble(on: bool) -> void:
	if _rumble_on == on:
		return
	_rumble_on = on
	if _rumble_tw != null and _rumble_tw.is_valid():
		_rumble_tw.kill()
	_rumble_tw = null
	if on:
		if not _muted and not _rumble.playing:
			_rumble.volume_db = -40.0
			_rumble.play()
		_rumble_tw = create_tween()
		_rumble_tw.tween_property(_rumble, "volume_db", _rumble_db, 1.5)
	elif _rumble.playing:
		_rumble_tw = create_tween()
		_rumble_tw.tween_property(_rumble, "volume_db", -40.0, 0.8)
		_rumble_tw.tween_callback(func() -> void:
			if not _rumble_on:
				_rumble.stop())

## "高潮前突然安静":压低 Ambience 总线,_hush_left 到期后在 _process 恢复
func hush(sec: float = 1.2) -> void:
	_hush_left = maxf(_hush_left, sec)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), -20.0)

func heart(on: bool, rate_ms: int) -> void:
	if not on:
		_h_rate = -1
		_h_acc = 0.0
		_heart_key = ""
		if _heart_p.playing:
			_heart_p.stop()
		return
	if _bufs.has("heart_slow"):
		# 外部资源:整段循环心跳,按理智节奏切快/慢档(与合成节拍器二选一)
		var key := "heart_fast" if rate_ms < 800 else "heart_slow"
		if _heart_key != key:
			_heart_key = key
			_heart_p.stream = _bufs[key]
			_heart_p.pitch_scale = 1.3 if key == "heart_fast" else 1.1
			_heart_p.volume_db = linear_to_db(0.8)
			if not _muted:
				_heart_p.play()
	else:
		if _h_rate == rate_ms:
			return
		_h_rate = rate_ms
		_h_acc = 0.0

func drone(on: bool) -> void:
	_drone_on = on
	if on:
		if not _drone.playing and not _muted:
			_drone.play()
	elif _drone.playing:
		_drone.stop()

func elevator_ride(on: bool) -> void:
	_ride_on = on
	if on:
		if _ride.playing or not _bufs.has("elevator_ride"):
			return
		_ride.stream = _bufs["elevator_ride"]
		_ride.volume_db = -4.0
		if not _muted:
			_ride.play()
	elif _ride.playing:
		_ride.stop()

func music_box() -> void:
	if _bufs.has("music_box"):
		play_buf("music_box", 0.7)
		return
	var seq := [660.0, 587.0, 523.0, 587.0, 660.0, 880.0]
	for i in seq.size():
		var f: float = seq[i]
		_delay(i * 0.45, func(): play_buf("mb_%d" % int(f), 1.0))
