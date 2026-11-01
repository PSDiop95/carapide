class_name BoosterAccess
extends RefCounted
## Ce que le joueur peut obtenir : le core sait ainsi distinguer BLOCKED de LOST,
## sans connaître ni pièces ni publicité. Par défaut : aucun booster.

enum Kind { COXEUR, APPRENTI, DIOULE, GARAGE }

const UNLIMITED_GARAGE_USES: int = 2

var _unlimited: bool = false


func _init(unlimited: bool = false) -> void:
	_unlimited = unlimited


func can_obtain(_kind: Kind) -> bool:
	return _unlimited


## Utilisations du Garage permises par niveau.
func garage_max_uses() -> int:
	return UNLIMITED_GARAGE_USES if _unlimited else 0
