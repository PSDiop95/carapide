class_name WheelRewards
extends RefCounted
## Roue : tours gratuits gagnés aux victoires, tours par pub plafonnés par jour.
## Le tirage et le gain ont lieu avant l'animation : quitter pendant qu'elle tourne ne perd rien.

const WINS_KEY: String = "wheel_wins"
const FREE_USED_KEY: String = "wheel_free_used"
const AD_DAY_KEY: String = "wheel_ad_day"
const AD_COUNT_KEY: String = "wheel_ad_count"
const SEED_KEY: String = "wheel_seed"
const DRAWS_KEY: String = "wheel_draws"
const NO_SPIN: int = -1
const SOURCE_FREE: String = "free"
const SOURCE_AD: String = "ad"

var _config: EconomyConfig
var _save: SaveService
var _wallet: WalletService
var _inventory: BoosterInventory
var _analytics: AnalyticsService
var _clock: SafeClock


func _init(config: EconomyConfig, save: SaveService, wallet: WalletService, inventory: BoosterInventory, analytics: AnalyticsService, clock: SafeClock) -> void:
	_config = config
	_save = save
	_wallet = wallet
	_inventory = inventory
	_analytics = analytics
	_clock = clock


func cells() -> Array[WheelCell]:
	return _config.wheel_cells


func record_win() -> void:
	_save.set_int(WINS_KEY, _save.get_int(WINS_KEY, 0) + 1)


## Victoires comptées vers le prochain tour gratuit ; plafonné quand un tour attend.
func progress() -> int:
	var used_wins: int = _save.get_int(FREE_USED_KEY, 0) * _config.wheel_wins_per_free_spin
	return mini(_save.get_int(WINS_KEY, 0) - used_wins, _config.wheel_wins_per_free_spin)


func progress_goal() -> int:
	return _config.wheel_wins_per_free_spin


func free_spins() -> int:
	var earned: int = int(float(_save.get_int(WINS_KEY, 0)) / float(_config.wheel_wins_per_free_spin))
	return earned - _save.get_int(FREE_USED_KEY, 0)


func ad_spins_left(system_now: int) -> int:
	var used: int = _save.get_int(AD_COUNT_KEY, 0) if _save.get_int(AD_DAY_KEY, -1) == _clock.day(system_now) else 0
	return _config.wheel_ad_spins_per_day - used


## Tire, crédite, journalise. Renvoie la case, ou NO_SPIN si ce tour n'est pas disponible.
func spin(system_now: int, by_ad: bool) -> int:
	if (by_ad and ad_spins_left(system_now) <= 0) or (not by_ad and free_spins() <= 0):
		return NO_SPIN
	_clock.commit(system_now)
	if by_ad:
		_count_ad_spin(system_now)
	else:
		_save.set_int(FREE_USED_KEY, _save.get_int(FREE_USED_KEY, 0) + 1)
	var index: int = WheelLogic.draw(cells(), _next_seed(system_now))
	_apply(cells()[index])
	_log(cells()[index], by_ad)
	return index


func reset() -> void:
	for key: String in [WINS_KEY, FREE_USED_KEY, AD_COUNT_KEY, DRAWS_KEY]:
		_save.set_int(key, 0)


func _count_ad_spin(system_now: int) -> void:
	var left: int = ad_spins_left(system_now)
	_save.set_int(AD_DAY_KEY, _clock.day(system_now))
	_save.set_int(AD_COUNT_KEY, _config.wheel_ad_spins_per_day - left + 1)


## Graine dérivée de la graine du joueur (posée au premier tour) et du nombre de tirages.
func _next_seed(system_now: int) -> int:
	if _save.get_int(SEED_KEY, 0) == 0:
		_save.set_int(SEED_KEY, _clock.read(system_now))
	var draws: int = _save.get_int(DRAWS_KEY, 0)
	_save.set_int(DRAWS_KEY, draws + 1)
	return hash([_save.get_int(SEED_KEY, 0), draws])


func _apply(cell: WheelCell) -> void:
	if cell.is_coins():
		_wallet.add(cell.amount, WalletService.SOURCE_WHEEL)
	else:
		var kind: BoosterAccess.Kind = BoosterConfig.KIND_KEYS.find_key(cell.reward)
		_inventory.grant(kind, cell.amount)


func _log(cell: WheelCell, by_ad: bool) -> void:
	_analytics.log_event("wheel_spin", {
		"reward": cell.reward,
		"amount": cell.amount,
		"source": SOURCE_AD if by_ad else SOURCE_FREE,
		"balance": _wallet.balance(),
	})
