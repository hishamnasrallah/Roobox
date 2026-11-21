class_name RooScript
extends RefCounted
## RooScript: a small, sandboxed interpreter for a Lua 5.1 subset, written
## in GDScript so it runs everywhere (Android, desktop, server) with no
## native code. Supports: local/global variables, numbers, strings,
## booleans, nil, tables, closures, method calls (a:b()), if/elseif/else,
## while, repeat/until, numeric and generic for (pairs/ipairs), break,
## multiple return values, and the usual operators.
## Every run has a step budget, so infinite loops stop with an error.

const KEYWORDS := ["and", "break", "do", "else", "elseif", "end", "false", "for", "function",
	"if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"]
const BIN_PRI := {
	"or": [1, 1], "and": [2, 2],
	"<": [3, 3], ">": [3, 3], "<=": [3, 3], ">=": [3, 3], "~=": [3, 3], "==": [3, 3],
	"..": [9, 8], "+": [10, 10], "-": [10, 10], "*": [11, 11], "/": [11, 11], "%": [11, 11],
	"^": [14, 13],
}
const UNARY_PRI := 12
const MAX_DEPTH := 120

## A Lua table. Number keys are normalized to float.
class LuaTable:
	extends RefCounted
	var d: Dictionary = {}

	static func key(k: Variant) -> Variant:
		return float(k) if k is int else k

	func get_v(k: Variant) -> Variant:
		return d.get(key(k))

	func set_v(k: Variant, v: Variant) -> void:
		if v == null:
			d.erase(key(k))
		else:
			d[key(k)] = v

	func length() -> int:
		var n := 0
		while d.has(float(n + 1)):
			n += 1
		return n


class LuaFunction:
	extends RefCounted
	var params: Array = []
	var body: Array = []
	var scope: Scope
	var fname: String = "function"


class Scope:
	extends RefCounted
	var vars: Dictionary = {}
	var parent: Scope = null

	func find(n: String) -> Scope:
		var s: Scope = self
		while s != null:
			if s.vars.has(n):
				return s
			s = s.parent
		return null


var error: String = ""
var output: Array[String] = []
var step_budget: int = 200000
var globals := Scope.new()

var _tokens: Array = []
var _pos: int = 0
var _chunk: Array = []
var _steps: int = 0
var _depth: int = 0
var _line: int = 0
var _ret: Array = []


func _init() -> void:
	_install_stdlib()


# =============================================================== public ===

## Parses source. Returns "" or an error message with a line number.
func compile(src: String) -> String:
	error = ""
	_tokens = _lex(src)
	if error != "":
		return error
	_pos = 0
	_chunk = _parse_block(["eof"])
	if error == "" and _peek()["t"] != "eof":
		_fail("unexpected '%s'" % _peek()["v"], _peek()["line"])
	return error


## Runs the compiled main chunk.
func run() -> String:
	if error != "":
		return error
	_begin()
	_exec_block(_chunk, _child(globals))
	return error


## Calls a script function (from host callbacks). Returns its results.
func call_function(fn: Variant, args: Array = []) -> Array:
	_begin()
	var r := _call(fn, args)
	return r if error == "" else []


func set_global(n: String, v: Variant) -> void:
	globals.vars[n] = v


func get_global(n: String) -> Variant:
	return globals.vars.get(n)


## Helper for hosts: a table from a Dictionary (values may be Callables).
func make_table(entries: Dictionary) -> LuaTable:
	var t := LuaTable.new()
	for k in entries:
		t.set_v(k, entries[k])
	return t


func clear_error() -> void:
	error = ""


static func type_name(v: Variant) -> String:
	if v == null:
		return "nil"
	if v is bool:
		return "boolean"
	if v is float or v is int:
		return "number"
	if v is String:
		return "string"
	if v is LuaTable:
		return "table"
	if v is LuaFunction or v is Callable:
		return "function"
	return "userdata"


static func to_str(v: Variant) -> String:
	if v == null:
		return "nil"
	if v is bool:
		return "true" if v else "false"
	if v is float or v is int:
		var f := float(v)
		if is_equal_approx(f, roundf(f)) and absf(f) < 1e15:
			return str(int(f))
		return str(f)
	if v is String:
		return v
	if v is LuaTable:
		return "table"
	return "function"


static func truthy(v: Variant) -> bool:
	return not (v == null or (v is bool and v == false))


# ================================================================ lexer ===

func _lex(src: String) -> Array:
	var toks: Array = []
	var i := 0
	var line := 1
	var n := src.length()
	while i < n:
		var c := src[i]
		if c == "\n":
			line += 1
			i += 1
		elif c == " " or c == "\t" or c == "\r":
			i += 1
		elif c == "-" and i + 1 < n and src[i + 1] == "-":
			if src.substr(i + 2, 2) == "[[":
				var close := src.find("]]", i + 4)
				if close < 0:
					close = n
				line += src.substr(i, close - i).count("\n")
				i = close + 2
			else:
				while i < n and src[i] != "\n":
					i += 1
		elif _is_alpha(c):
			var j := i
			while j < n and (_is_alpha(src[j]) or _is_digit(src[j])):
				j += 1
			var w := src.substr(i, j - i)
			toks.append({"t": "kw" if w in KEYWORDS else "name", "v": w, "line": line})
			i = j
		elif _is_digit(c) or (c == "." and i + 1 < n and _is_digit(src[i + 1])):
			var j := i
			if src.substr(i, 2).to_lower() == "0x":
				j = i + 2
				while j < n and src[j].to_lower() in "0123456789abcdef":
					j += 1
				toks.append({"t": "num", "v": float(src.substr(i + 2, j - i - 2).hex_to_int()), "line": line})
			else:
				while j < n and (_is_digit(src[j]) or src[j] == "."):
					j += 1
				if j < n and src[j].to_lower() == "e":
					j += 1
					if j < n and (src[j] == "-" or src[j] == "+"):
						j += 1
					while j < n and _is_digit(src[j]):
						j += 1
				toks.append({"t": "num", "v": src.substr(i, j - i).to_float(), "line": line})
			i = j
		elif c == "\"" or c == "'":
			var j := i + 1
			var s := ""
			while j < n and src[j] != c:
				if src[j] == "\n":
					_fail("unfinished string", line)
					return toks
				if src[j] == "\\" and j + 1 < n:
					j += 1
					match src[j]:
						"n":
							s += "\n"
						"t":
							s += "\t"
						_:
							s += src[j]
				else:
					s += src[j]
				j += 1
			if j >= n:
				_fail("unfinished string", line)
				return toks
			toks.append({"t": "str", "v": s, "line": line})
			i = j + 1
		elif c == "[" and src.substr(i, 2) == "[[":
			var close := src.find("]]", i + 2)
			if close < 0:
				_fail("unfinished long string", line)
				return toks
			var s := src.substr(i + 2, close - i - 2)
			toks.append({"t": "str", "v": s, "line": line})
			line += s.count("\n")
			i = close + 2
		else:
			var three := src.substr(i, 3)
			var two := src.substr(i, 2)
			if three == "...":
				toks.append({"t": "op", "v": "...", "line": line})
				i += 3
			elif two in ["..", "==", "~=", "<=", ">="]:
				toks.append({"t": "op", "v": two, "line": line})
				i += 2
			elif c in "+-*/%^#<>=(){}[];:,.":
				toks.append({"t": "op", "v": c, "line": line})
				i += 1
			else:
				_fail("unexpected character '%s'" % c, line)
				return toks
	toks.append({"t": "eof", "v": "<eof>", "line": line})
	return toks


static func _is_alpha(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


# =============================================================== parser ===

func _peek() -> Dictionary:
	return _tokens[_pos]


func _next() -> Dictionary:
	var t: Dictionary = _tokens[_pos]
	if _pos < _tokens.size() - 1:
		_pos += 1
	return t


func _is(v: String) -> bool:
	var t := _peek()
	return (t["t"] == "op" or t["t"] == "kw") and t["v"] == v


func _accept(v: String) -> bool:
	if _is(v):
		_next()
		return true
	return false


func _expect(v: String) -> void:
	if not _accept(v):
		_fail("'%s' expected near '%s'" % [v, _peek()["v"]], _peek()["line"])


func _name() -> String:
	var t := _peek()
	if t["t"] != "name":
		_fail("name expected near '%s'" % t["v"], t["line"])
		return ""
	_next()
	return t["v"]


func _block_end(enders: Array) -> bool:
	var t := _peek()
	if t["t"] == "eof":
		return true
	return t["t"] == "kw" and t["v"] in enders


func _parse_block(enders: Array) -> Array:
	var stmts: Array = []
	while error == "" and not _block_end(enders):
		if _is("return"):
			var line: int = _next()["line"]
			var exprs: Array = []
			if not _block_end(enders) and not _is(";"):
				exprs = _parse_exprlist()
			_accept(";")
			stmts.append({"k": "return", "e": exprs, "line": line})
			break
		var s := _parse_statement()
		if not s.is_empty():
			stmts.append(s)
	return stmts


func _parse_statement() -> Dictionary:
	var t := _peek()
	var line: int = t["line"]
	if _accept(";"):
		return {}
	if t["t"] == "kw":
		match t["v"]:
			"local":
				_next()
				if _accept("function"):
					var n := _name()
					return {"k": "localfunc", "n": n, "f": _parse_funcbody(n), "line": line}
				var names: Array = [_name()]
				while _accept(","):
					names.append(_name())
				var exprs: Array = []
				if _accept("="):
					exprs = _parse_exprlist()
				return {"k": "local", "names": names, "e": exprs, "line": line}
			"function":
				_next()
				var target: Dictionary = {"k": "name", "n": _name(), "line": line}
				var fname: String = target["n"]
				var is_method := false
				while _is(".") or _is(":"):
					var colon := _is(":")
					_next()
					var key := _name()
					fname += (":" if colon else ".") + key
					target = {"k": "index", "o": target, "key": {"k": "str", "v": key}, "line": line}
					if colon:
						is_method = true
						break
				var f := _parse_funcbody(fname)
				if is_method:
					(f["params"] as Array).push_front("self")
				return {"k": "assign", "targets": [target], "e": [f], "line": line}
			"if":
				_next()
				var conds: Array = []
				var c := _parse_expr()
				_expect("then")
				conds.append([c, _parse_block(["elseif", "else", "end"])])
				var els: Array = []
				while true:
					if _accept("elseif"):
						var c2 := _parse_expr()
						_expect("then")
						conds.append([c2, _parse_block(["elseif", "else", "end"])])
					elif _accept("else"):
						els = _parse_block(["end"])
						_expect("end")
						break
					else:
						_expect("end")
						break
				return {"k": "if", "conds": conds, "els": els, "line": line}
			"while":
				_next()
				var c := _parse_expr()
				_expect("do")
				var body := _parse_block(["end"])
				_expect("end")
				return {"k": "while", "c": c, "body": body, "line": line}
			"repeat":
				_next()
				var body := _parse_block(["until"])
				_expect("until")
				return {"k": "repeat", "body": body, "c": _parse_expr(), "line": line}
			"do":
				_next()
				var body := _parse_block(["end"])
				_expect("end")
				return {"k": "do", "body": body, "line": line}
			"for":
				_next()
				var n1 := _name()
				if _accept("="):
					var a := _parse_expr()
					_expect(",")
					var b := _parse_expr()
					var step: Variant = null
					if _accept(","):
						step = _parse_expr()
					_expect("do")
					var body := _parse_block(["end"])
					_expect("end")
					return {"k": "fornum", "v": n1, "a": a, "b": b, "s": step, "body": body, "line": line}
				var names: Array = [n1]
				while _accept(","):
					names.append(_name())
				_expect("in")
				var exprs := _parse_exprlist()
				_expect("do")
				var body := _parse_block(["end"])
				_expect("end")
				return {"k": "forin", "names": names, "e": exprs, "body": body, "line": line}
			"break":
				_next()
				return {"k": "break", "line": line}
	# Assignment or call.
	var e := _parse_suffixed()
	if _is("=") or _is(","):
		var targets: Array = [e]
		while _accept(","):
			targets.append(_parse_suffixed())
		_expect("=")
		for tg: Dictionary in targets:
			if tg.get("k") != "name" and tg.get("k") != "index":
				_fail("cannot assign to this expression", line)
		return {"k": "assign", "targets": targets, "e": _parse_exprlist(), "line": line}
	if e.get("k") != "call" and e.get("k") != "method":
		if error == "":
			_fail("syntax error near '%s'" % _peek()["v"], _peek()["line"])
		_next()
		return {}
	return {"k": "callstat", "e": e, "line": line}


func _parse_funcbody(fname: String) -> Dictionary:
	_expect("(")
	var params: Array = []
	if not _is(")"):
		params.append(_name())
		while _accept(","):
			params.append(_name())
	_expect(")")
	var body := _parse_block(["end"])
	_expect("end")
	return {"k": "func", "params": params, "body": body, "name": fname}


func _parse_exprlist() -> Array:
	var list: Array = [_parse_expr()]
	while _accept(","):
		list.append(_parse_expr())
	return list


func _parse_expr(limit: int = 0) -> Dictionary:
	var left: Dictionary
	var t := _peek()
	if _is("not") or _is("-") or _is("#"):
		_next()
		left = {"k": "un", "op": t["v"], "e": _parse_expr(UNARY_PRI), "line": t["line"]}
	else:
		left = _parse_simple()
	while error == "":
		var op := _peek()
		if not ((op["t"] == "op" or op["t"] == "kw") and BIN_PRI.has(op["v"])):
			break
		var pri: Array = BIN_PRI[op["v"]]
		if int(pri[0]) <= limit:
			break
		_next()
		var right := _parse_expr(int(pri[1]))
		left = {"k": "bin", "op": op["v"], "a": left, "b": right, "line": op["line"]}
	return left


func _parse_simple() -> Dictionary:
	var t := _peek()
	match t["t"]:
		"num":
			_next()
			return {"k": "num", "v": t["v"]}
		"str":
			_next()
			return {"k": "str", "v": t["v"]}
	if _accept("nil"):
		return {"k": "nil"}
	if _accept("true"):
		return {"k": "true"}
	if _accept("false"):
		return {"k": "false"}
	if _accept("function"):
		return _parse_funcbody("function")
	if _is("{"):
		return _parse_table()
	return _parse_suffixed()


func _parse_table() -> Dictionary:
	var line: int = _peek()["line"]
	_expect("{")
	var items: Array = []
	while error == "" and not _is("}"):
		if _accept("["):
			var k := _parse_expr()
			_expect("]")
			_expect("=")
			items.append([k, _parse_expr()])
		elif _peek()["t"] == "name" and (_tokens[_pos + 1] as Dictionary)["v"] == "=":
			var k2 := _name()
			_next()
			items.append([{"k": "str", "v": k2}, _parse_expr()])
		else:
			items.append([null, _parse_expr()])
		if not _accept(",") and not _accept(";"):
			break
	_expect("}")
	return {"k": "table", "items": items, "line": line}


func _parse_suffixed() -> Dictionary:
	var t := _peek()
	var line: int = t["line"]
	var e: Dictionary
	if t["t"] == "name":
		_next()
		e = {"k": "name", "n": t["v"], "line": line}
	elif _accept("("):
		e = {"k": "paren", "e": _parse_expr(), "line": line}
		_expect(")")
	else:
		_fail("unexpected '%s'" % t["v"], line)
		_next()
		return {"k": "nil"}
	while error == "":
		if _accept("."):
			e = {"k": "index", "o": e, "key": {"k": "str", "v": _name()}, "line": line}
		elif _accept("["):
			var k := _parse_expr()
			_expect("]")
			e = {"k": "index", "o": e, "key": k, "line": line}
		elif _accept(":"):
			var m := _name()
			e = {"k": "method", "o": e, "name": m, "args": _parse_args(), "line": line}
		elif _is("(") or _is("{") or _peek()["t"] == "str":
			e = {"k": "call", "f": e, "args": _parse_args(), "line": line}
		else:
			break
	return e


func _parse_args() -> Array:
	if _peek()["t"] == "str":
		return [{"k": "str", "v": _next()["v"]}]
	if _is("{"):
		return [_parse_table()]
	_expect("(")
	var args: Array = []
	if not _is(")"):
		args = _parse_exprlist()
	_expect(")")
	return args


# ============================================================ evaluator ===

func _begin() -> void:
	_steps = 0
	_depth = 0


func _fail(msg: String, line: int = -1) -> void:
	if error == "":
		error = "line %d: %s" % [line if line >= 0 else _line, msg]


func _tick() -> bool:
	_steps += 1
	if _steps > step_budget:
		_fail("script took too long (infinite loop?)")
		return false
	return error == ""


func _child(parent: Scope) -> Scope:
	var s := Scope.new()
	s.parent = parent
	return s


## Returns 0 = normal, 1 = break, 2 = return (values in _ret).
func _exec_block(stmts: Array, scope: Scope) -> int:
	for st: Dictionary in stmts:
		if not _tick():
			return 2
		_line = int(st.get("line", _line))
		var code := _exec(st, scope)
		if code != 0 or error != "":
			return code if error == "" else 2
	return 0


func _exec(st: Dictionary, scope: Scope) -> int:
	match str(st["k"]):
		"local":
			var vals := _eval_list(st["e"], scope)
			var names: Array = st["names"]
			for i in names.size():
				scope.vars[names[i]] = vals[i] if i < vals.size() else null
		"localfunc":
			scope.vars[st["n"]] = null
			scope.vars[st["n"]] = _eval(st["f"], scope)
		"assign":
			var vals := _eval_list(st["e"], scope)
			var targets: Array = st["targets"]
			for i in targets.size():
				_assign(targets[i], vals[i] if i < vals.size() else null, scope)
		"callstat":
			_eval_multi(st["e"], scope)
		"do":
			return _exec_block(st["body"], _child(scope))
		"if":
			for pair: Array in st["conds"]:
				if truthy(_eval(pair[0], scope)):
					return _exec_block(pair[1], _child(scope))
				if error != "":
					return 2
			return _exec_block(st["els"], _child(scope))
		"while":
			while error == "" and truthy(_eval(st["c"], scope)):
				var code := _exec_block(st["body"], _child(scope))
				if code == 1:
					break
				if code == 2:
					return 2
		"repeat":
			while error == "":
				var inner := _child(scope)
				var code := _exec_block(st["body"], inner)
				if code == 1:
					break
				if code == 2:
					return 2
				if truthy(_eval(st["c"], inner)):
					break
		"fornum":
			var a: Variant = _eval(st["a"], scope)
			var b: Variant = _eval(st["b"], scope)
			var stp: Variant = 1.0 if st["s"] == null else _eval(st["s"], scope)
			if not (_isnum(a) and _isnum(b) and _isnum(stp)):
				_fail("'for' needs numbers", st["line"])
				return 2
			var v := float(a)
			var stop := float(b)
			var inc := float(stp)
			if inc == 0.0:
				_fail("'for' step is zero", st["line"])
				return 2
			while error == "" and ((inc > 0.0 and v <= stop) or (inc < 0.0 and v >= stop)):
				var inner := _child(scope)
				inner.vars[st["v"]] = v
				var code := _exec_block(st["body"], inner)
				if code == 1:
					break
				if code == 2:
					return 2
				v += inc
		"forin":
			var init := _eval_list(st["e"], scope)
			var f: Variant = init[0] if init.size() > 0 else null
			var s: Variant = init[1] if init.size() > 1 else null
			var ctrl: Variant = init[2] if init.size() > 2 else null
			var names: Array = st["names"]
			while error == "":
				var r := _call(f, [s, ctrl])
				if error != "" or r.is_empty() or r[0] == null:
					break
				ctrl = r[0]
				var inner := _child(scope)
				for i in names.size():
					inner.vars[names[i]] = r[i] if i < r.size() else null
				var code := _exec_block(st["body"], inner)
				if code == 1:
					break
				if code == 2:
					return 2
		"return":
			_ret = _eval_list(st["e"], scope)
			return 2
		"break":
			return 1
	return 0


func _assign(target: Dictionary, v: Variant, scope: Scope) -> void:
	if target["k"] == "name":
		var n: String = target["n"]
		var s := scope.find(n)
		if s == null:
			s = globals
		s.vars[n] = v
	else:
		var o: Variant = _eval(target["o"], scope)
		var k: Variant = _eval(target["key"], scope)
		if not (o is LuaTable):
			_fail("attempt to index a %s value" % type_name(o), target.get("line", -1))
			return
		if k == null:
			_fail("table index is nil", target.get("line", -1))
			return
		(o as LuaTable).set_v(k, v)


func _eval_list(exprs: Array, scope: Scope) -> Array:
	var out: Array = []
	for i in exprs.size():
		if i == exprs.size() - 1:
			out.append_array(_eval_multi(exprs[i], scope))
		else:
			out.append(_eval(exprs[i], scope))
	return out


## Evaluates an expression that may produce several values (calls).
func _eval_multi(e: Dictionary, scope: Scope) -> Array:
	match str(e["k"]):
		"call":
			var f: Variant = _eval(e["f"], scope)
			var args := _eval_list(e["args"], scope)
			if error != "":
				return []
			if f == null:
				_fail("attempt to call a nil value (%s)" % _describe(e["f"]), e.get("line", -1))
				return []
			return _call(f, args)
		"method":
			var o: Variant = _eval(e["o"], scope)
			var m: Variant = _index(o, e["name"], e.get("line", -1))
			var args := _eval_list(e["args"], scope)
			if error != "":
				return []
			if m == null:
				_fail("method '%s' not found" % e["name"], e.get("line", -1))
				return []
			args.push_front(o)
			return _call(m, args)
	return [_eval(e, scope)]


func _describe(e: Dictionary) -> String:
	match str(e.get("k", "")):
		"name":
			return "'%s'" % e["n"]
		"index":
			var key: Dictionary = e["key"]
			return "field '%s'" % key.get("v", "?")
	return "expression"


func _eval(e: Dictionary, scope: Scope) -> Variant:
	if not _tick():
		return null
	match str(e["k"]):
		"num", "str":
			return e["v"]
		"nil":
			return null
		"true":
			return true
		"false":
			return false
		"name":
			var s := scope.find(e["n"])
			return s.vars[e["n"]] if s != null else null
		"paren":
			return _eval(e["e"], scope)
		"index":
			var o: Variant = _eval(e["o"], scope)
			var k: Variant = _eval(e["key"], scope)
			return _index(o, k, e.get("line", -1))
		"call", "method":
			var r := _eval_multi(e, scope)
			return r[0] if r.size() > 0 else null
		"func":
			var f := LuaFunction.new()
			f.params = e["params"]
			f.body = e["body"]
			f.scope = scope
			f.fname = e.get("name", "function")
			return f
		"table":
			var t := LuaTable.new()
			var n := 1
			var items: Array = e["items"]
			for i in items.size():
				var it: Array = items[i]
				if it[0] == null:
					if i == items.size() - 1:
						for v in _eval_multi(it[1], scope):
							t.set_v(n, v)
							n += 1
					else:
						t.set_v(n, _eval(it[1], scope))
						n += 1
				else:
					var k: Variant = _eval(it[0], scope)
					if k == null:
						_fail("table index is nil", e.get("line", -1))
						return null
					t.set_v(k, _eval(it[1], scope))
			return t
		"un":
			var v: Variant = _eval(e["e"], scope)
			match str(e["op"]):
				"not":
					return not truthy(v)
				"-":
					if not _isnum(v):
						_fail("attempt to negate a %s value" % type_name(v), e.get("line", -1))
						return null
					return -float(v)
				"#":
					if v is String:
						return float((v as String).length())
					if v is LuaTable:
						return float((v as LuaTable).length())
					_fail("attempt to get length of a %s value" % type_name(v), e.get("line", -1))
					return null
		"bin":
			return _binary(e, scope)
	return null


func _binary(e: Dictionary, scope: Scope) -> Variant:
	var op: String = e["op"]
	if op == "and":
		var a: Variant = _eval(e["a"], scope)
		return _eval(e["b"], scope) if truthy(a) else a
	if op == "or":
		var a2: Variant = _eval(e["a"], scope)
		return a2 if truthy(a2) else _eval(e["b"], scope)
	var x: Variant = _eval(e["a"], scope)
	var y: Variant = _eval(e["b"], scope)
	if error != "":
		return null
	var line: int = e.get("line", -1)
	match op:
		"==":
			return _eq(x, y)
		"~=":
			return not _eq(x, y)
		"..":
			if (x is String or _isnum(x)) and (y is String or _isnum(y)):
				return to_str(x) + to_str(y)
			_fail("attempt to concatenate a %s value" % type_name(y if (x is String or _isnum(x)) else x), line)
			return null
		"<", ">", "<=", ">=":
			if (_isnum(x) and _isnum(y)) or (x is String and y is String):
				var a3: Variant = float(x) if _isnum(x) else x
				var b3: Variant = float(y) if _isnum(y) else y
				match op:
					"<":
						return a3 < b3
					">":
						return a3 > b3
					"<=":
						return a3 <= b3
					_:
						return a3 >= b3
			_fail("attempt to compare %s with %s" % [type_name(x), type_name(y)], line)
			return null
	if not (_isnum(x) and _isnum(y)):
		_fail("attempt to do math on a %s value" % type_name(y if _isnum(x) else x), line)
		return null
	var fx := float(x)
	var fy := float(y)
	match op:
		"+":
			return fx + fy
		"-":
			return fx - fy
		"*":
			return fx * fy
		"/":
			return fx / fy if fy != 0.0 else (INF if fx >= 0.0 else -INF)
		"%":
			return fx - floorf(fx / fy) * fy if fy != 0.0 else NAN
		"^":
			return pow(fx, fy)
	return null


static func _isnum(v: Variant) -> bool:
	return v is float or v is int


static func _eq(a: Variant, b: Variant) -> bool:
	if _isnum(a) and _isnum(b):
		return float(a) == float(b)
	if a is LuaTable or b is LuaTable or a is LuaFunction or b is LuaFunction:
		return is_same(a, b)
	if typeof(a) != typeof(b):
		return false
	return a == b


func _index(o: Variant, k: Variant, line: int) -> Variant:
	if o is LuaTable:
		return (o as LuaTable).get_v(k)
	if o is String:
		var lib: Variant = globals.vars.get("string")
		if lib is LuaTable:
			return (lib as LuaTable).get_v(k)
	_fail("attempt to index a %s value" % type_name(o), line)
	return null


func _call(f: Variant, args: Array) -> Array:
	if error != "":
		return []
	if f is Callable:
		var r: Variant = (f as Callable).call(args)
		if r is Array:
			return r
		return [r]
	if f is LuaFunction:
		var fn := f as LuaFunction
		_depth += 1
		if _depth > MAX_DEPTH:
			_fail("stack overflow (too much recursion)")
			_depth -= 1
			return []
		var scope := _child(fn.scope)
		for i in fn.params.size():
			scope.vars[fn.params[i]] = args[i] if i < args.size() else null
		var saved_line := _line
		var code := _exec_block(fn.body, scope)
		_line = saved_line
		_depth -= 1
		if code == 2 and error == "":
			var r2 := _ret
			_ret = []
			return r2
		return []
	_fail("attempt to call a %s value" % type_name(f))
	return []


# ============================================================== stdlib ===

func _install_stdlib() -> void:
	set_global("print", _lib_print)
	set_global("type", _lib_type)
	set_global("tostring", _lib_tostring)
	set_global("tonumber", _lib_tonumber)
	set_global("error", _lib_error)
	set_global("ipairs", _lib_ipairs)
	set_global("pairs", _lib_pairs)

	var m := LuaTable.new()
	m.set_v("pi", PI)
	m.set_v("huge", INF)
	m.set_v("floor", func(a: Array) -> Array: return [floorf(_num(a, 0))])
	m.set_v("ceil", func(a: Array) -> Array: return [ceilf(_num(a, 0))])
	m.set_v("abs", func(a: Array) -> Array: return [absf(_num(a, 0))])
	m.set_v("sqrt", func(a: Array) -> Array: return [sqrt(_num(a, 0))])
	m.set_v("sin", func(a: Array) -> Array: return [sin(_num(a, 0))])
	m.set_v("cos", func(a: Array) -> Array: return [cos(_num(a, 0))])
	m.set_v("min", _lib_min)
	m.set_v("max", _lib_max)
	m.set_v("random", _lib_random)
	set_global("math", m)

	var s := LuaTable.new()
	s.set_v("len", func(a: Array) -> Array: return [float(to_str(a[0]).length())])
	s.set_v("upper", func(a: Array) -> Array: return [to_str(a[0]).to_upper()])
	s.set_v("lower", func(a: Array) -> Array: return [to_str(a[0]).to_lower()])
	s.set_v("rep", func(a: Array) -> Array: return [to_str(a[0]).repeat(clampi(int(_num(a, 1)), 0, 10000))])
	s.set_v("sub", _lib_sub)
	set_global("string", s)

	var tb := LuaTable.new()
	tb.set_v("insert", _lib_insert)
	tb.set_v("remove", _lib_remove)
	set_global("table", tb)


func _lib_print(a: Array) -> Array:
	var parts: Array[String] = []
	for v in a:
		parts.append(to_str(v))
	output.append("\t".join(parts))
	return []


func _lib_type(a: Array) -> Array:
	return [type_name(a[0] if a.size() > 0 else null)]


func _lib_tostring(a: Array) -> Array:
	return [to_str(a[0] if a.size() > 0 else null)]


func _lib_tonumber(a: Array) -> Array:
	var v: Variant = a[0] if a.size() > 0 else null
	if _isnum(v):
		return [float(v)]
	if v is String and (v as String).strip_edges().is_valid_float():
		return [(v as String).strip_edges().to_float()]
	return [null]


func _lib_error(a: Array) -> Array:
	_fail(to_str(a[0] if a.size() > 0 else "error"))
	return []


func _lib_ipairs(a: Array) -> Array:
	var t: Variant = a[0] if a.size() > 0 else null
	return [_ipairs_iter, t, 0.0]


func _ipairs_iter(b: Array) -> Array:
	var i := 1.0
	if b.size() > 1 and _isnum(b[1]):
		i = float(b[1]) + 1.0
	var v: Variant = null
	if b.size() > 0 and b[0] is LuaTable:
		v = (b[0] as LuaTable).get_v(i)
	if v == null:
		return [null]
	return [i, v]


func _lib_pairs(a: Array) -> Array:
	var t: Variant = a[0] if a.size() > 0 else null
	if not (t is LuaTable):
		_fail("bad argument to 'pairs' (table expected)")
		return [null]
	var keys: Array = (t as LuaTable).d.keys()
	var state := {"i": 0, "t": t, "keys": keys}
	var iter := func(_b: Array) -> Array:
		var tt: LuaTable = state["t"]
		var ks: Array = state["keys"]
		while int(state["i"]) < ks.size():
			var k: Variant = ks[state["i"]]
			state["i"] = int(state["i"]) + 1
			if tt.d.has(k):
				return [k, tt.d[k]]
		return [null]
	return [iter, t, null]


func _lib_min(a: Array) -> Array:
	var r := INF
	for v in a:
		if _isnum(v):
			r = minf(r, float(v))
	return [r]


func _lib_max(a: Array) -> Array:
	var r := -INF
	for v in a:
		if _isnum(v):
			r = maxf(r, float(v))
	return [r]


func _lib_random(a: Array) -> Array:
	if a.size() == 0:
		return [randf()]
	if a.size() == 1:
		return [float(randi_range(1, maxi(1, int(_num(a, 0)))))]
	return [float(randi_range(int(_num(a, 0)), int(_num(a, 1))))]


func _lib_sub(a: Array) -> Array:
	var str_v := to_str(a[0] if a.size() > 0 else "")
	var n := str_v.length()
	var i := int(_num(a, 1)) if a.size() > 1 else 1
	var j := int(_num(a, 2)) if a.size() > 2 else n
	if i < 0:
		i = n + i + 1
	if j < 0:
		j = n + j + 1
	i = maxi(i, 1)
	j = mini(j, n)
	return [str_v.substr(i - 1, j - i + 1) if j >= i else ""]


func _lib_insert(a: Array) -> Array:
	if a.size() < 2 or not (a[0] is LuaTable):
		return []
	var t: LuaTable = a[0]
	var n := t.length()
	if a.size() == 2:
		t.set_v(n + 1, a[1])
	else:
		var pos := int(_num(a, 1))
		for i in range(n, pos - 1, -1):
			t.set_v(i + 1, t.get_v(i))
		t.set_v(pos, a[2])
	return []


func _lib_remove(a: Array) -> Array:
	if a.size() < 1 or not (a[0] is LuaTable):
		return [null]
	var t: LuaTable = a[0]
	var n := t.length()
	var pos := int(_num(a, 1)) if a.size() > 1 else n
	var v: Variant = t.get_v(pos)
	for i in range(pos, n):
		t.set_v(i, t.get_v(i + 1))
	t.set_v(n, null)
	return [v]


static func _num(a: Array, i: int) -> float:
	if i < a.size() and _isnum(a[i]):
		return float(a[i])
	return 0.0
