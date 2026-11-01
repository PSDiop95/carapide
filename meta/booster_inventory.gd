class_name BoosterInventory
extends BoosterAccess
## Stock, déblocages et paiement des boosters : stock d'abord, puis pièces, puis pub.

enum Offer { LOCKED, STOCK, COINS, AD, NONE }

const STOCK_KEY: String = "booster_stock_%s"
const GRANTED_KEY: String = "booster_granted_%s"
const TUTORIAL_KEY: String = "booster_tutorial_%s"

var config: BoosterConfig

var _save: SaveService
var _wallet: WalletService
var _ads: AdsService
var _level: int = 0


func _init(booster_config: BoosterConfig, save: SaveService, wallet: WalletService, ads: AdsService) -> void:
	config = booster_config
	_save = save
	_wallet = wallet
	_ads = ads


## Entre dans ce niveau : offre le cadeau des boosters tout juste débloqués, une seule fois.
func enter_level(level_number: int) -> void:
	_level = level_number
	for kind: BoosterAccess.Kind in BoosterConfig.KIND_KEYS:
		if is_unlocked(kind) and _save.get_int(_key(GRANTED_KEY, kind), 0) == 0:
			_save.set_int(_key(GRANTED_KEY, kind), 1)
			_save.set_int(_key(STOCK_KEY, kind), stock(kind) + config.gift(kind))


func is_unlocked(kind: BoosterAccess.Kind) -> bool:
	return _level >= config.unlock_level(kind)


func stock(kind: BoosterAccess.Kind) -> int:
	return _save.get_int(_key(STOCK_KEY, kind), 0)


func offer(kind: BoosterAccess.Kind) -> Offer:
	if not is_unlocked(kind):
		return Offer.LOCKED
	if stock(kind) > 0:
		return Offer.STOCK
	if _wallet.balance() >= config.price(kind):
		return Offer.COINS
	return Offer.AD if _ads.is_rewarded_available() else Offer.NONE


func can_obtain(kind: BoosterAccess.Kind) -> bool:
	var current: Offer = offer(kind)
	return current != Offer.LOCKED and current != Offer.NONE


func garage_max_uses() -> int:
	return config.garage_max_uses


## Faux si le paiement échoue (pub non vue, plus rien à payer) ; rien n'est alors débité.
func pay(kind: BoosterAccess.Kind) -> bool:
	match offer(kind):
		Offer.STOCK:
			_save.set_int(_key(STOCK_KEY, kind), stock(kind) - 1)
			return true
		Offer.COINS:
			return _wallet.try_spend(config.price(kind))
		Offer.AD:
			return await _ads.show_rewarded()
	return false


func needs_tutorial(kind: BoosterAccess.Kind) -> bool:
	return is_unlocked(kind) and _save.get_int(_key(TUTORIAL_KEY, kind), 0) == 0


func mark_tutorial_done(kind: BoosterAccess.Kind) -> void:
	_save.set_int(_key(TUTORIAL_KEY, kind), 1)


## Un nouveau testeur repart de zéro.
func reset() -> void:
	_wallet.reset()
	_level = 0
	for kind: BoosterAccess.Kind in BoosterConfig.KIND_KEYS:
		_save.set_int(_key(STOCK_KEY, kind), 0)
		_save.set_int(_key(GRANTED_KEY, kind), 0)
		_save.set_int(_key(TUTORIAL_KEY, kind), 0)


func _key(pattern: String, kind: BoosterAccess.Kind) -> String:
	return pattern % BoosterConfig.KIND_KEYS[kind]
