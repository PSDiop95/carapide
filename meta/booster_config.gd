class_name BoosterConfig
extends RefCounted
## Prix, déblocages et gains de data/config/boosters.json.

const PATH: String = "res://data/config/boosters.json"
const KIND_KEYS: Dictionary[BoosterAccess.Kind, String] = {
	BoosterAccess.Kind.COXEUR: "coxeur",
	BoosterAccess.Kind.APPRENTI: "apprenti",
	BoosterAccess.Kind.DIOULE: "dioule",
	BoosterAccess.Kind.GARAGE: "garage",
}

var dioule_max_nodes: int = 0
var garage_max_uses: int = 0
var victory_coins: int = 0
var victory_ad_multiplier: int = 1

var _entries: Dictionary = {}


static func load_default() -> BoosterConfig:
	var config: BoosterConfig = BoosterConfig.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("Configuration illisible : %s" % PATH)
		return config
	var raw: Dictionary = parsed
	config._entries = raw["boosters"]
	config.dioule_max_nodes = _read_int(raw, "dioule_max_nodes")
	config.garage_max_uses = _read_int(raw, "garage_max_uses")
	config.victory_coins = _read_int(raw, "victory_coins")
	config.victory_ad_multiplier = _read_int(raw, "victory_ad_multiplier")
	return config


func price(kind: BoosterAccess.Kind) -> int:
	return _read_int(_entry(kind), "price")


func unlock_level(kind: BoosterAccess.Kind) -> int:
	return _read_int(_entry(kind), "unlock_level")


func gift(kind: BoosterAccess.Kind) -> int:
	return _read_int(_entry(kind), "gift")


func _entry(kind: BoosterAccess.Kind) -> Dictionary:
	var entry: Dictionary = _entries[KIND_KEYS[kind]]
	return entry


static func _read_int(raw: Dictionary, key: String) -> int:
	var value: float = raw[key]
	return int(value)
