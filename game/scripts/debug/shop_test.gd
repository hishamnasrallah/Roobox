extends Node
## CI test for the coin economy and avatar shop:
##   godot --headless --path game -- --shoptest

var _fails: Array[String] = []


func _check(ok: bool, what: String, detail: Variant = "") -> void:
	print("SHOPTEST %s %s %s" % ["ok  " if ok else "FAIL", what, str(detail) if not ok else ""])
	if not ok:
		_fails.append(what)


func _meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children():
		c += _meshes(ch)
	return c


func _ready() -> void:
	var saved := [Game.lifetime_coins, Game.spent_coins, Game.owned_items.duplicate(), Game.equipped.duplicate(), Game.last_daily]
	Game.lifetime_coins = 500
	Game.spent_coins = 0
	Game.owned_items = []
	Game.equipped = {}

	_check(Game.buy("crown") != "", "can't buy what you can't afford")
	_check(Game.buy("cap") == "" and Game.wallet() == 400, "buy cap for 100", Game.wallet())
	_check(Game.equipped.get("hat", "") == "cap", "bought item is worn")
	_check(Game.buy("cap") != "", "can't buy twice")
	_check(Game.buy("cape") != "", "not enough coins for the cape")
	_check(Game.buy("sunglasses") == "" and Game.wallet() == 250, "buy sunglasses", Game.wallet())
	_check(Game.profile()["items"] == ["cap", "sunglasses"], "profile lists worn items", Game.profile()["items"])

	var plain := Avatar.new()
	add_child(plain)
	var fancy := Avatar.new()
	fancy.apply_profile(Game.profile())
	add_child(fancy)
	_check(_meshes(fancy) > _meshes(plain) + 2, "items appear on the avatar", [_meshes(plain), _meshes(fancy)])

	var clean := Network._sanitize({"name": "x", "items": ["cap", "beanie", "nope", "scarf"]})
	_check(clean["items"] == ["cap", "scarf"], "network keeps one valid item per slot", clean["items"])

	Game.toggle_equip("cap")
	_check(Game.profile()["items"] == ["sunglasses"], "take an item off", Game.profile()["items"])
	Game.toggle_equip("cap")
	_check(Game.equipped.get("hat", "") == "cap", "wear it again")

	Game.last_daily = ""
	var before := Game.wallet()
	_check(Game.claim_daily() == Game.DAILY_REWARD and Game.wallet() == before + Game.DAILY_REWARD, "daily reward")
	_check(Game.claim_daily() == 0, "daily reward only once per day")

	# --- Chat filter (safety) ---
	_check(ChatFilter.clean("hello friend") == "hello friend", "clean text is untouched")
	_check(not ChatFilter.clean("you fuck").contains("fuck"), "English bad word hidden", ChatFilter.clean("you fuck"))
	_check(not ChatFilter.clean("يا شرموط").contains("شرموط"), "Arabic bad word hidden", ChatFilter.clean("يا شرموط"))
	_check(ChatFilter.clean("go to www.example.com").contains("[link]"), "links hidden", ChatFilter.clean("go to www.example.com"))
	_check(ChatFilter.clean("call 0791234567").contains("[hidden]"), "phone numbers hidden", ChatFilter.clean("call 0791234567"))
	_check(Network._clean_text("fuck [b]", 120) == "**** (b)", "network chat is filtered", Network._clean_text("fuck [b]", 120))

	Game.lifetime_coins = saved[0]
	Game.spent_coins = saved[1]
	Game.owned_items = saved[2]
	Game.equipped = saved[3]
	Game.last_daily = saved[4]
	Game.save_profile()
	if _fails.is_empty():
		print("SHOPTEST PASS")
	else:
		print("SHOPTEST FAIL: " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)
