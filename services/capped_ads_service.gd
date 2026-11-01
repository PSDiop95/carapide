class_name CappedAdsService
extends AdsService
## Plafond quotidien global de pubs récompensées, sauvegardé, sur l'heure protégée.

const DAY_KEY: String = "ads_day"
const COUNT_KEY: String = "ads_count"

## Heure système, remplaçable par les tests.
var now_provider: Callable = _system_now

var _save: SaveService
var _clock: SafeClock
var _daily_cap: int


func _init(save: SaveService, daily_cap: int) -> void:
	_save = save
	_clock = SafeClock.new(save)
	_daily_cap = daily_cap


func is_rewarded_available() -> bool:
	return super.is_rewarded_available() and watched_today() < _daily_cap


func watched_today() -> int:
	var now: int = now_provider.call()
	return _save.get_int(COUNT_KEY, 0) if _save.get_int(DAY_KEY, -1) == _clock.day(now) else 0


## Le plafond compte les pubs lancées : les pubs abandonnées coûtent aussi à la régie.
func show_rewarded() -> bool:
	if not is_rewarded_available():
		return false
	var now: int = now_provider.call()
	var watched: int = watched_today()
	_clock.commit(now)
	_save.set_int(DAY_KEY, _clock.day(now))
	_save.set_int(COUNT_KEY, watched + 1)
	return await super.show_rewarded()


func _system_now() -> int:
	return int(Time.get_unix_time_from_system())
