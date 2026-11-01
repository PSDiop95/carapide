class_name WalletService
extends RefCounted
## Interface du porte-monnaie : tout gain et toute dépense y passent, avec leur source.
## Implémentation par défaut : mémoire.

signal balance_changed(balance: int)

const SOURCE_VICTORY: String = "victory"
const SOURCE_VICTORY_AD: String = "victory_ad"
const SOURCE_BOOSTER: String = "booster_%s"
const SOURCE_STATION: String = "station"
const SOURCE_WHEEL: String = "wheel"

var analytics: AnalyticsService = null

var _balance: int = 0


func balance() -> int:
	return _balance


func add(amount: int, source: String) -> void:
	_set_balance(_balance + amount)
	_log("coins_earned", amount, source)


## Faux si le solde ne suffit pas ; rien n'est alors débité.
func try_spend(amount: int, source: String) -> bool:
	if amount > _balance:
		return false
	_set_balance(_balance - amount)
	_log("coins_spent", amount, source)
	return true


func reset() -> void:
	_set_balance(0)


func _set_balance(value: int) -> void:
	_balance = value
	balance_changed.emit(_balance)


func _log(event_name: String, amount: int, source: String) -> void:
	if analytics != null:
		analytics.log_event(event_name, {"source": source, "amount": amount, "balance": _balance})
