class_name BoosterBar
extends VBoxContainer
## Barre basse : Coxeur, Apprenti, Dioulé. Le Dioulé verrouillé reste anonyme pour donner envie.

signal booster_pressed(kind: BoosterAccess.Kind)

const BOTTOM_MARGIN: float = 16.0
const SEPARATION: int = 8
const HINT_FONT_SIZE: int = 26
const HINT_SECONDS: float = 2.0
const NAME_KEYS: Dictionary[BoosterAccess.Kind, String] = {
	BoosterAccess.Kind.COXEUR: "BOOSTER_COXEUR",
	BoosterAccess.Kind.APPRENTI: "BOOSTER_APPRENTI",
	BoosterAccess.Kind.DIOULE: "BOOSTER_DIOULE",
}

var _inventory: BoosterInventory
var _buttons: Dictionary[BoosterAccess.Kind, BoosterButton] = {}
var _hint: Label = Label.new()
var _hint_timer: Timer = Timer.new()


func setup(inventory: BoosterInventory) -> void:
	_inventory = inventory


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, int(BOTTOM_MARGIN))
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_theme_constant_override("separation", SEPARATION)
	_hint.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
	_hint.add_theme_color_override("font_color", Color.BLACK)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.0
	add_child(_hint)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", SEPARATION)
	add_child(row)
	for kind: BoosterAccess.Kind in NAME_KEYS:
		var button: BoosterButton = BoosterButton.new()
		button.pressed.connect(booster_pressed.emit.bind(kind))
		_buttons[kind] = button
		row.add_child(button)
	_hint_timer.one_shot = true
	_hint_timer.wait_time = HINT_SECONDS
	_hint_timer.timeout.connect(clear_hint)
	add_child(_hint_timer)
	refresh()


func refresh() -> void:
	for kind: BoosterAccess.Kind in _buttons:
		var offer: BoosterInventory.Offer = _inventory.offer(kind)
		var usable: bool = offer != BoosterInventory.Offer.LOCKED and offer != BoosterInventory.Offer.NONE
		var hidden_name: bool = kind == BoosterAccess.Kind.DIOULE and offer == BoosterInventory.Offer.LOCKED
		var title: String = tr("BOOSTER_TEASER") if hidden_name else tr(NAME_KEYS[kind])
		_buttons[kind].show_state(title, offer_text(_inventory, kind), usable, offer == BoosterInventory.Offer.AD)


func set_active(kind: BoosterAccess.Kind, active: bool) -> void:
	_buttons[kind].set_active(active)


func button_rect(kind: BoosterAccess.Kind) -> Rect2:
	return _buttons[kind].get_global_rect()


func badge_text(kind: BoosterAccess.Kind) -> String:
	return _buttons[kind].badge.text


## Message court au-dessus de la barre ; `lasting` : reste jusqu'à clear_hint().
func show_hint(text: String, lasting: bool = false) -> void:
	_hint.text = text
	_hint.modulate.a = 1.0
	_hint_timer.stop()
	if not lasting:
		_hint_timer.start()


func clear_hint() -> void:
	_hint.modulate.a = 0.0


static func offer_text(inventory: BoosterInventory, kind: BoosterAccess.Kind) -> String:
	match inventory.offer(kind):
		BoosterInventory.Offer.LOCKED:
			return TranslationServer.translate("BOOSTER_LOCKED") % inventory.config.unlock_level(kind)
		BoosterInventory.Offer.STOCK:
			return TranslationServer.translate("BOOSTER_STOCK") % inventory.stock(kind)
		BoosterInventory.Offer.COINS:
			return TranslationServer.translate("BOOSTER_PRICE") % inventory.config.price(kind)
		BoosterInventory.Offer.AD:
			return TranslationServer.translate("BOOSTER_AD")
	return TranslationServer.translate("BOOSTER_NONE")
