extends Node
## Unit tests for the RooScript interpreter (CI):
##   godot --headless --path game -- --scripttest

const CASES: Array = [
	["print(1+2*3, 2^10, 7 % 3, 10/4)", "7\t1024\t1\t2.5"],
	["local s = 'ab' .. 1 .. \"c\"\nprint(s, #s, s:upper(), string.sub('hello', 2, 4))", "ab1c\t4\tAB1C\tell"],
	["local t = {10,20,30}\nlocal sum = 0\nfor i, v in ipairs(t) do sum = sum + v end\nprint(sum, #t)", "60\t3"],
	["local d = {a = 1, b = 2}\nlocal n = 0\nfor k, v in pairs(d) do n = n + v end\nprint(n)", "3"],
	["local function counter()\n local c = 0\n return function() c = c + 1 return c end\nend\nlocal f = counter()\nf() f()\nprint(f())", "3"],
	["local function fib(n) if n < 2 then return n end return fib(n-1) + fib(n-2) end\nprint(fib(15))", "610"],
	["local function mr() return 1, 2, 3 end\nlocal a, b, c = mr()\nprint(a + b + c)\nlocal t = {mr()}\nprint(#t)", "6\n3"],
	["local i = 0\nwhile true do i = i + 1 if i >= 5 then break end end\nlocal j = 0\nrepeat j = j + 2 until j > 7\nprint(i, j)", "5\t8"],
	["local s = ''\nfor i = 10, 1, -3 do s = s .. i .. ',' end\nprint(s)", "10,7,4,1,"],
	["local obj = {n = 2}\nfunction obj:double() self.n = self.n * 2 return self end\nobj:double():double()\nprint(obj.n)", "8"],
	["local t = {}\ntable.insert(t, 'a') table.insert(t, 'c') table.insert(t, 2, 'b')\nlocal r = table.remove(t, 1)\nprint(r, t[1], t[2], #t)", "a\tb\tc\t2"],
	["print(nil or 'x', false and 1, not nil, 1 == 1.0, 'a' < 'b')", "x\tfalse\ttrue\ttrue\ttrue"],
	["print(math.floor(3.7), math.max(1, 5, 3), math.abs(-2))", "3\t5\t2"],
	["print(type({}), type(print), tonumber('12') + 1, tostring(nil))", "table\tfunction\t13\tnil"],
	["function g(x) return x * 2 end\nprint(g(21))", "42"],
	["-- hi\n--[[ block\n comment ]] print('ok')", "ok"],
	["print([[a b]])", "a b"],
	["local t = {x = {y = {z = 5}}}\nt.x.y.z = t.x.y.z + 1\nprint(t.x.y.z, t['x'].y['z'])", "6\t6"],
	["local a = {}\na[1] = 'one'\na.two = 2\nlocal keys = 0\nfor _ in pairs(a) do keys = keys + 1 end\nprint(keys, a[1])", "2\tone"],
	["if 5 > 3 then print('a') elseif true then print('b') else print('c') end\nif nil then print('x') else print('y') end", "a\ny"],
]

const ERRORS: Array = [
	["local x = nil\nx.y = 1", "attempt to index a nil value"],
	["while true do end", "took too long"],
	["local function f() return f() end\nf()", "stack overflow"],
	["print(1 + {})", "attempt to do math"],
	["undefined_fn()", "attempt to call a nil value"],
]

const SYNTAX: Array = [
	["if x then", "'end' expected"],
	["local = 5", "name expected"],
	["print('unclosed)", "unfinished string"],
]

var _fails: Array[String] = []


func _ready() -> void:
	for c in CASES:
		var vm := RooScript.new()
		var err := vm.compile(c[0])
		if err == "":
			err = vm.run()
		var out := "\n".join(vm.output)
		var ok: bool = err == "" and out == c[1]
		print("SCRIPTTEST %s %s" % ["ok  " if ok else "FAIL", str(c[0]).replace("\n", " | ")])
		if not ok:
			print("   expected: %s\n   got: %s %s" % [str(c[1]).c_escape(), out.c_escape(), err])
			_fails.append(c[0])
	for c in ERRORS:
		var vm := RooScript.new()
		vm.step_budget = 50000
		var err := vm.compile(c[0])
		if err == "":
			err = vm.run()
		var ok: bool = err.contains(c[1])
		print("SCRIPTTEST %s runtime error '%s' -> %s" % ["ok  " if ok else "FAIL", c[1], err])
		if not ok:
			_fails.append(c[0])
	for c in SYNTAX:
		var vm := RooScript.new()
		var err := vm.compile(c[0])
		var ok: bool = err.contains(c[1]) and err.begins_with("line ")
		print("SCRIPTTEST %s syntax error '%s' -> %s" % ["ok  " if ok else "FAIL", c[1], err])
		if not ok:
			_fails.append(c[0])
	if _fails.is_empty():
		print("SCRIPTTEST PASS")
	else:
		print("SCRIPTTEST FAIL: %d case(s)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)
