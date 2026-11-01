class_name EconomyConfig
extends RefCounted
## Gains, prix et plafonds de data/config/economy.json.

const PATH: String = "res://data/config/economy.json"

var garage_max_uses: int = 0
var victory_coins: int = 0
var victory_ad_multiplier: int = 1
var station_tiers: PackedInt32Array = PackedInt32Array()
var station_recharge_hours: int = 0
var wheel_wins_per_free_spin: int = 0
var wheel_ad_spins_per_day: int = 0
var wheel_cells: Array[WheelCell] = []
var rewarded_ads_per_day: int = 0

var _boosters: Dictionary = {}


static func load_default() -> EconomyConfig:
	var config: EconomyConfig = EconomyConfig.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("Configuration illisible : %s" % PATH)
		return config
	var raw: Dictionary = parsed
	config._boosters = raw["boosters"]
	config.garage_max_uses = _read_int(raw, "garage_max_uses")
	config.victory_coins = _read_int(raw, "victory_coins")
	config.victory_ad_multiplier = _read_int(raw, "victory_ad_multiplier")
	config.rewarded_ads_per_day = _read_int(raw, "rewarded_ads_per_day")
	var station: Dictionary = raw["station"]
	var wheel: Dictionary = raw["wheel"]
	config._read_station(station)
	config._read_wheel(wheel)
	return config


func booster_price(key: String) -> int:
	return _read_int(_booster(key), "price")


func booster_gift(key: String) -> int:
	return _read_int(_booster(key), "gift")


func _booster(key: String) -> Dictionary:
	var entry: Dictionary = _boosters[key]
	return entry


func _read_station(raw: Dictionary) -> void:
	station_recharge_hours = _read_int(raw, "recharge_hours")
	var tiers: Array = raw["tiers"]
	for tier: Variant in tiers:
		var coins: float = tier
		station_tiers.append(int(coins))


func _read_wheel(raw: Dictionary) -> void:
	wheel_wins_per_free_spin = _read_int(raw, "wins_per_free_spin")
	wheel_ad_spins_per_day = _read_int(raw, "ad_spins_per_day")
	var cells: Array = raw["cells"]
	for entry: Variant in cells:
		var cell_raw: Dictionary = entry
		var cell: WheelCell = WheelCell.new()
		cell.reward = cell_raw["reward"]
		cell.amount = _read_int(cell_raw, "amount")
		cell.weight = _read_int(cell_raw, "weight")
		wheel_cells.append(cell)


static func _read_int(raw: Dictionary, key: String) -> int:
	var value: float = raw[key]
	return int(value)
