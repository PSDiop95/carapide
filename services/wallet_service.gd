class_name WalletService
extends RefCounted
## Interface du porte-monnaie. Implémentation par défaut : mémoire.

signal balance_changed(balance: int)

var _balance: int = 0


func balance() -> int:
	return _balance


func add(amount: int) -> void:
	_set_balance(_balance + amount)


## Faux si le solde ne suffit pas ; rien n'est alors débité.
func try_spend(amount: int) -> bool:
	if amount > _balance:
		return false
	_set_balance(_balance - amount)
	return true


func reset() -> void:
	_set_balance(0)


func _set_balance(value: int) -> void:
	_balance = value
	balance_changed.emit(_balance)
