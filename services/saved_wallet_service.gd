class_name SavedWalletService
extends WalletService
## Solde persisté dans la sauvegarde.

const KEY: String = "wallet_coins"

var _save: SaveService


func _init(save: SaveService, analytics_service: AnalyticsService = null) -> void:
	_save = save
	analytics = analytics_service
	_balance = save.get_int(KEY, 0)


func _set_balance(value: int) -> void:
	_save.set_int(KEY, value)
	super._set_balance(value)
