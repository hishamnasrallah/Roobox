extends Node
## Procedural sound effects: every sound is synthesized at startup,
## so there are no audio files and no licensing concerns.
## Registered as the `Sfx` autoload. Usage: Sfx.play("coin")

const RATE := 22050
const VOICES := 10

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# No audio on the dedicated server / headless runs.
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		_enabled = false
		return
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build_all()


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _enabled or not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound] as AudioStream
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.play()


# --------------------------------------------------------------- synth ---

## Renders `gen(t) -> float` (t in seconds, output -1..1) into a WAV stream.
func _synth(duration: float, gen: Callable) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s: float = gen.call(t)
		# Short fade in/out to avoid clicks.
		var edge := minf(minf(t / 0.004, (duration - t) / 0.01), 1.0)
		data.encode_s16(i * 2, int(clampf(s * edge, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Oscillator with continuous phase. `freq` is a Callable(t) -> Hz.
func _osc(freq: Callable, shape: String = "sine") -> Callable:
	var st := [0.0]
	return func(t: float) -> float:
		var f: float = freq.call(t)
		st[0] = fmod(st[0] + f / RATE, 1.0)
		var ph: float = st[0]
		match shape:
			"square":
				return 0.6 if ph < 0.5 else -0.6
			"tri":
				return 4.0 * absf(ph - 0.5) - 1.0
			"soft":
				return sin(ph * TAU) * 0.8 + sin(ph * TAU * 2.0) * 0.25
			_:
				return sin(ph * TAU)


func _const(hz: float) -> Callable:
	return func(_t: float) -> float:
		return hz


func _notes(freqs: Array, step: float, decay: float, shape: String = "soft",
		hold_last: float = 0.0) -> Callable:
	var oscs: Array = []
	for f: float in freqs:
		oscs.append(_osc(_const(f), shape))
	var count := freqs.size()
	return func(t: float) -> float:
		var s := 0.0
		for i in count:
			var start := step * i
			if t < start:
				break
			var d := decay
			if i == count - 1 and hold_last > 0.0:
				d = decay * 0.4
			var o: Callable = oscs[i]
			s += o.call(t) * exp(-(t - start) * d) * 0.45
		return s


func _build_all() -> void:
	var jump_f := func(t: float) -> float:
		return lerpf(300.0, 760.0, minf(t / 0.16, 1.0))
	var jump_osc := _osc(jump_f, "soft")
	var jump_gen := func(t: float) -> float:
		return jump_osc.call(t) * exp(-t * 14.0) * 0.45
	_streams["jump"] = _synth(0.17, jump_gen)

	var land_f := func(t: float) -> float:
		return lerpf(140.0, 60.0, t / 0.12)
	var land_osc := _osc(land_f)
	var land_gen := func(t: float) -> float:
		return (land_osc.call(t) * 0.6 + randf_range(-1.0, 1.0) * 0.35) * exp(-t * 35.0) * 0.6
	_streams["land"] = _synth(0.12, land_gen)

	_streams["coin"] = _synth(0.38, _notes([988.0, 1319.0], 0.075, 9.0, "soft"))
	_streams["checkpoint"] = _synth(0.55, _notes([523.25, 659.25, 783.99, 1046.5], 0.08, 7.0, "tri"))
	_streams["win"] = _synth(1.3, _notes(
			[523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5], 0.13, 4.0, "soft", 0.6))
	_streams["join"] = _synth(0.4, _notes([659.25, 987.77], 0.09, 8.0, "tri"))

	var die_f := func(t: float) -> float:
		return lerpf(520.0, 110.0, minf(t / 0.45, 1.0)) + sin(t * 40.0) * 18.0
	var die_osc := _osc(die_f, "square")
	var die_gen := func(t: float) -> float:
		return die_osc.call(t) * (1.0 - t / 0.5) * 0.35
	_streams["die"] = _synth(0.5, die_gen)

	var boing_f := func(t: float) -> float:
		return 170.0 + 420.0 * minf(t / 0.35, 1.0) + sin(t * TAU * 16.0) * 45.0
	var boing_osc := _osc(boing_f)
	var boing_gen := func(t: float) -> float:
		return boing_osc.call(t) * exp(-t * 5.0) * 0.6
	_streams["boing"] = _synth(0.42, boing_gen)

	var hit_osc := _osc(_const(95.0))
	var hit_gen := func(t: float) -> float:
		return (hit_osc.call(t) * 0.7 + randf_range(-1.0, 1.0) * 0.5) * exp(-t * 18.0) * 0.6
	_streams["hit"] = _synth(0.2, hit_gen)

	var click_osc := _osc(_const(1400.0))
	var click_gen := func(t: float) -> float:
		return click_osc.call(t) * exp(-t * 80.0) * 0.4
	_streams["click"] = _synth(0.05, click_gen)

	var pop_f := func(t: float) -> float:
		return lerpf(700.0, 1300.0, minf(t / 0.06, 1.0))
	var pop_osc := _osc(pop_f)
	var pop_gen := func(t: float) -> float:
		return pop_osc.call(t) * exp(-t * 30.0) * 0.4
	_streams["pop"] = _synth(0.09, pop_gen)

	var tp_f := func(t: float) -> float:
		return lerpf(220.0, 1600.0, minf(t / 0.55, 1.0))
	var tp_osc := _osc(tp_f, "tri")
	var tp_gen := func(t: float) -> float:
		return tp_osc.call(t) * (0.6 + 0.4 * sin(t * TAU * 22.0)) * exp(-t * 2.5) * 0.4
	_streams["teleport"] = _synth(0.6, tp_gen)
