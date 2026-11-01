class_name WheelCell
extends RefCounted
## Une case de la Roue : récompense, quantité, poids du tirage.

const COINS: String = "coins"

var reward: String = COINS
var amount: int = 0
var weight: int = 0


func is_coins() -> bool:
	return reward == COINS
