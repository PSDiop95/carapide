class_name StationRewards
extends RefCounted
## Station : un palier gratuit, puis des paliers par pub, l'un après l'autre.
## Le premier palier ramassé lance la recharge ; à son terme, tout repart du premier.

const NEXT_KEY: String = "station_next_tier"
const START_KEY: String = "station_cycle_start"
const FREE_TIER: int = 0
const SECONDS_PER_HOUR: int = 3600

var _config: EconomyConfig
var _save: SaveService
var _wallet: WalletService
var _clock: SafeClock


func _init(config: EconomyConfig, save: SaveService, wallet: WalletService, clock: SafeClock) -> void:
	_config = config
	_save = save
	_wallet = wallet
	_clock = clock


## Palier à ramasser maintenant ; égal au nombre de paliers quand tout est pris.
func next_tier(system_now: int) -> int:
	return FREE_TIER if seconds_until_recharge(system_now) == 0 else _save.get_int(NEXT_KEY, FREE_TIER)


func is_exhausted(system_now: int) -> bool:
	return next_tier(system_now) >= tier_count()


func tier_count() -> int:
	return _config.station_tiers.size()


func coins(tier: int) -> int:
	return _config.station_tiers[tier]


func needs_ad(tier: int) -> bool:
	return tier != FREE_TIER


## Un palier par pub n'est disponible que si une pub peut être vue.
func has_available(system_now: int, ad_available: bool) -> bool:
	if is_exhausted(system_now):
		return false
	return ad_available or not needs_ad(next_tier(system_now))


## Zéro quand aucune recharge n'est en cours.
func seconds_until_recharge(system_now: int) -> int:
	if _save.get_int(NEXT_KEY, FREE_TIER) == FREE_TIER:
		return 0
	var end: int = _save.get_int(START_KEY, 0) + _config.station_recharge_hours * SECONDS_PER_HOUR
	return maxi(end - _clock.read(system_now), 0)


## Crédite le palier courant et renvoie son montant. La pub éventuelle a déjà été vue.
func claim(system_now: int) -> int:
	var tier: int = next_tier(system_now)
	if tier >= tier_count():
		return 0
	var now: int = _clock.commit(system_now)
	if tier == FREE_TIER:
		_save.set_int(START_KEY, now)
	_save.set_int(NEXT_KEY, tier + 1)
	_wallet.add(coins(tier), WalletService.SOURCE_STATION)
	return coins(tier)


func reset() -> void:
	_save.set_int(NEXT_KEY, FREE_TIER)
	_save.set_int(START_KEY, 0)
