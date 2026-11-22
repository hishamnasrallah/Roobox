class_name ScriptHost
extends GameMode
## Runs a creation's RooScript on the authority (solo device or host) and
## turns API calls into events: world changes go to everyone, player
## actions go to the targeted player. Late joiners get the current state.
##
## Script API:
##   on_start(fn)  on_touch(name, fn(player, part))  after(sec, fn)  every(sec, fn)
##   cancel(id)    time()                      print(...)
##   world.find(name) -> part   part:set_color(i) part:set_visible(b)
##       part:set_solid(b) part:move_to(x,y,z[,sec]) part:move_by(dx,dy,dz[,sec])
##       part:position() part:destroy()      (part.name)
##   player:teleport(x,y,z) player:kill() player:give_coins(n)
##       player:set_speed(v) player:set_jump(v) player:message(text)
##       player:position()                   (player.name, player.id)
##   ui.message(text[, sec])  ui.status(text)
##   score.add(n) score.set(n) score.get()

signal log_line(text: String)

var source: String = ""
## (peer_id) -> Vector3
var player_pos_provider: Callable = Callable()
## (peer_id) -> String
var player_name_provider: Callable = Callable()
## (name) -> Vector3 ; first part with that name
var part_pos_provider: Callable = Callable()
## Names of parts that exist in the level.
var part_names: Array = []
var last_error: String = ""

var vm: RooScript
var _touch: Dictionary = {}
var _start: Array = []
var _timers: Array = []
var _next_timer: int = 1
var _score: int = 0
var _status: String = ""
var _ops: Dictionary = {}
var _time: float = 0.0
## Leaderboard: peer_id -> {stat: value}
var _stats: Dictionary = {}


func _ready() -> void:
	if source.strip_edges() == "":
		return
	vm = RooScript.new()
	_install_api()
	var err := vm.compile(source)
	if err != "":
		_report(err)
		return
	err = vm.run()
	_drain()
	if err != "":
		_report(err)
		vm.clear_error()
	for fn in _start:
		_invoke(fn, [])


func _process(delta: float) -> void:
	if vm == null:
		return
	_time += delta
	for t: Dictionary in _timers.duplicate():
		if not _timers.has(t):
			continue
		t["left"] = float(t["left"]) - delta
		if float(t["left"]) <= 0.0:
			if t["every"]:
				t["left"] = float(t["left"]) + float(t["interval"])
			else:
				_timers.erase(t)
			_invoke(t["fn"], [])


## A player touched a named part (called by main on the authority).
## part_name is "name" or "name#index" (one specific part of that name);
## handlers get (player, part) where part is that exact part.
func fire_touch(part_name: String, peer_id: int) -> void:
	if vm == null:
		return
	var base := part_name.get_slice("#", 0)
	for fn in _touch.get(base, []):
		_invoke(fn, [_player_ref(peer_id), _part_ref(part_name)])


func snapshot() -> Dictionary:
	return {"t": "script_state", "score": _score, "status": _status, "ops": _ops.values(), "stats": _stats}


func _invoke(fn: Variant, args: Array) -> void:
	vm.clear_error()
	vm.call_function(fn, args)
	_drain()
	if vm.error != "":
		_report(vm.error)
		vm.clear_error()


func _drain() -> void:
	for line in vm.output:
		log_line.emit(line)
	vm.output.clear()


func _report(err: String) -> void:
	last_error = err
	log_line.emit("Script error: " + err)
	emit_event({"t": "script_error", "msg": err})


# ================================================================== API ===

func _install_api() -> void:
	vm.set_global("on_start", _api_on_start)
	vm.set_global("on_touch", _api_on_touch)
	vm.set_global("after", func(a: Array) -> Array: return [_add_timer(a, false)])
	vm.set_global("every", func(a: Array) -> Array: return [_add_timer(a, true)])
	vm.set_global("cancel", _api_cancel)
	vm.set_global("time", func(_a: Array) -> Array: return [_time])
	vm.set_global("world", vm.make_table({"find": _api_find}))
	vm.set_global("ui", vm.make_table({"message": _api_message, "status": _api_status}))
	vm.set_global("score", vm.make_table({"add": _score_add, "set": _score_set, "get": _score_get}))


func _score_add(a: Array) -> Array:
	return [_set_score(_score + int(RooScript._num(a, 0)))]


func _score_set(a: Array) -> Array:
	return [_set_score(int(RooScript._num(a, 0)))]


func _score_get(_a: Array) -> Array:
	return [float(_score)]


func _api_on_start(a: Array) -> Array:
	_start.append(a[0] if a.size() > 0 else null)
	return []


func _api_on_touch(a: Array) -> Array:
	if a.size() < 2 or not (a[0] is String):
		vm._fail("on_touch(name, function) expected")
		return []
	var n: String = a[0]
	if not _touch.has(n):
		_touch[n] = []
	(_touch[n] as Array).append(a[1])
	if not (n in part_names):
		log_line.emit("Warning: no part is named \"%s\" (use SELECT > name in the editor)" % n)
	return []


func _add_timer(a: Array, repeat: bool) -> int:
	var sec := maxf(RooScript._num(a, 0), 0.05 if repeat else 0.0)
	if _timers.size() >= 200:
		vm._fail("too many timers")
		return 0
	var id := _next_timer
	_next_timer += 1
	_timers.append({"id": id, "left": sec, "interval": sec, "every": repeat, "fn": a[1] if a.size() > 1 else null})
	return id


func _api_cancel(a: Array) -> Array:
	var id := int(RooScript._num(a, 0))
	for t: Dictionary in _timers.duplicate():
		if int(t["id"]) == id:
			_timers.erase(t)
	return []


func _api_find(a: Array) -> Array:
	var n := RooScript.to_str(a[0] if a.size() > 0 else null)
	if not (n in part_names):
		return [null]
	return [_part_ref(n)]


func _api_message(a: Array) -> Array:
	emit_event({"t": "msg", "text": RooScript.to_str(a[0] if a.size() > 0 else ""),
		"sec": RooScript._num(a, 1) if a.size() > 1 else 2.0})
	return []


func _api_status(a: Array) -> Array:
	_status = RooScript.to_str(a[0] if a.size() > 0 else "")
	emit_event({"t": "status", "text": _status})
	return []


func _set_score(v: int) -> float:
	_score = v
	emit_event({"t": "score", "v": _score})
	return float(_score)


# ---------------------------------------------------------------- parts ---

func _part_ref(n: String) -> RooScript.LuaTable:
	return vm.make_table({
		"name": n,
		"set_color": _part_color.bind(n),
		"set_visible": _part_visible.bind(n),
		"set_solid": _part_solid.bind(n),
		"move_to": _part_move_to.bind(n),
		"move_by": _part_move_by.bind(n),
		"position": _part_position.bind(n),
		"destroy": _part_destroy.bind(n),
	})


func _part_color(a: Array, n: String) -> Array:
	_world_op(n, "color", [clampi(int(RooScript._num(a, 1)), 0, Level.COLORS.size() - 1)])
	return []


func _part_visible(a: Array, n: String) -> Array:
	_world_op(n, "visible", [RooScript.truthy(a[1] if a.size() > 1 else null)])
	return []


func _part_solid(a: Array, n: String) -> Array:
	_world_op(n, "solid", [RooScript.truthy(a[1] if a.size() > 1 else null)])
	return []


func _part_move_to(a: Array, n: String) -> Array:
	_world_op(n, "move", [RooScript._num(a, 1), RooScript._num(a, 2), RooScript._num(a, 3), RooScript._num(a, 4)])
	return []


func _part_move_by(a: Array, n: String) -> Array:
	var p := _part_pos(n)
	_world_op(n, "move", [p.x + RooScript._num(a, 1), p.y + RooScript._num(a, 2), p.z + RooScript._num(a, 3), RooScript._num(a, 4)])
	return []


func _part_position(_a: Array, n: String) -> Array:
	var p := _part_pos(n)
	return [p.x, p.y, p.z]


func _part_destroy(_a: Array, n: String) -> Array:
	_world_op(n, "destroy", [])
	return []


func _part_pos(n: String) -> Vector3:
	if _ops.has(n + "|move"):
		var ev: Dictionary = _ops[n + "|move"]
		var a: Array = ev["a"]
		return Vector3(a[0], a[1], a[2])
	if part_pos_provider.is_valid():
		return part_pos_provider.call(n)
	return Vector3.ZERO


func _world_op(n: String, op: String, args: Array) -> void:
	var ev := {"t": "sop", "n": n, "op": op, "a": args}
	if not n.contains("#"):
		# A whole-group change replaces earlier single-part changes.
		var suffix := "|" + op
		for k: String in _ops.keys():
			if k.begins_with(n + "#") and k.ends_with(suffix):
				_ops.erase(k)
	_ops[n + "|" + op] = ev
	emit_event(ev)


# -------------------------------------------------------------- players ---

func _player_ref(peer_id: int) -> RooScript.LuaTable:
	var pname := "Player"
	if player_name_provider.is_valid():
		pname = player_name_provider.call(peer_id)
	return vm.make_table({
		"id": float(peer_id),
		"name": pname,
		"teleport": _pl_teleport.bind(peer_id),
		"kill": _pl_simple.bind(peer_id, "kill"),
		"give_coins": _pl_coins.bind(peer_id),
		"set_speed": _pl_value.bind(peer_id, "speed", 1.0, 40.0),
		"set_jump": _pl_value.bind(peer_id, "jump", 2.0, 60.0),
		"message": _pl_message.bind(peer_id),
		"position": _pl_position.bind(peer_id),
		"set_stat": _pl_set_stat.bind(peer_id),
		"add_stat": _pl_add_stat.bind(peer_id),
		"get_stat": _pl_get_stat.bind(peer_id),
		"award_badge": _pl_badge.bind(peer_id),
	})


func _stat_name(a: Array) -> String:
	return RooScript.to_str(a[1] if a.size() > 1 else "Score").strip_edges().substr(0, 16)


func _pl_set_stat(a: Array, peer_id: int) -> Array:
	var v: Variant = a[2] if a.size() > 2 else 0.0
	if not (v is float or v is int):
		v = RooScript.to_str(v).substr(0, 24)
	_set_stat(peer_id, _stat_name(a), v)
	return []


func _pl_add_stat(a: Array, peer_id: int) -> Array:
	var n := _stat_name(a)
	var cur: Variant = (_stats.get(peer_id, {}) as Dictionary).get(n, 0.0)
	var base := float(cur) if (cur is float or cur is int) else 0.0
	_set_stat(peer_id, n, base + RooScript._num(a, 2))
	return []


func _pl_get_stat(a: Array, peer_id: int) -> Array:
	return [(_stats.get(peer_id, {}) as Dictionary).get(_stat_name(a), 0.0)]


func _set_stat(peer_id: int, n: String, v: Variant) -> void:
	if not _stats.has(peer_id):
		_stats[peer_id] = {}
	var row: Dictionary = _stats[peer_id]
	if not row.has(n) and row.size() >= 3:
		vm._fail("at most 3 leaderboard stats")
		return
	row[n] = v
	emit_event({"t": "stats", "s": _stats})


func _pl_badge(a: Array, peer_id: int) -> Array:
	_player_op(peer_id, "badge", [RooScript.to_str(a[1] if a.size() > 1 else "").strip_edges().substr(0, 32)])
	return []


func _pl_teleport(a: Array, peer_id: int) -> Array:
	_player_op(peer_id, "teleport", [RooScript._num(a, 1), RooScript._num(a, 2), RooScript._num(a, 3)])
	return []


func _pl_simple(_a: Array, peer_id: int, op: String) -> Array:
	_player_op(peer_id, op, [])
	return []


func _pl_coins(a: Array, peer_id: int) -> Array:
	_player_op(peer_id, "coins", [clampi(int(RooScript._num(a, 1)), -1000, 1000)])
	return []


func _pl_value(a: Array, peer_id: int, op: String, lo: float, hi: float) -> Array:
	_player_op(peer_id, op, [clampf(RooScript._num(a, 1), lo, hi)])
	return []


func _pl_message(a: Array, peer_id: int) -> Array:
	_player_op(peer_id, "message", [RooScript.to_str(a[1] if a.size() > 1 else "")])
	return []


func _pl_position(_a: Array, peer_id: int) -> Array:
	var p: Vector3 = player_pos_provider.call(peer_id) if player_pos_provider.is_valid() else Vector3.ZERO
	return [p.x, p.y, p.z]


func _player_op(peer_id: int, op: String, args: Array) -> void:
	emit_event({"t": "pop", "to": peer_id, "op": op, "a": args})
