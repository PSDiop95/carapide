class_name HubScreen
extends CanvasLayer
## Écran d'accueil (GDD §5) : pièces, réglages, car rapide « NIVEAU N » et sa file, Jouer.
## Ne touche ni au niveau ni à l'état de jeu : il annonce les choix du joueur.

signal play_pressed
signal station_pressed
signal wheel_pressed

const BACKGROUND_COLOR: Color = Color(0.86, 0.86, 0.84)
const CAR_COLOR: Color = Color(0.62, 0.62, 0.6)
const PASSENGER_COLOR: Color = Color(0.3, 0.3, 0.32)
const TEXT_COLOR: Color = Color.BLACK
const MARGIN: float = 24.0
const FONT_SIZE: int = 36
const TITLE_FONT_SIZE: int = 44
const PLAY_FONT_SIZE: int = 56
const SIDE_BUTTON_SIZE: Vector2 = Vector2(150.0, 110.0)
const TOP_BUTTON_SIZE: Vector2 = Vector2(72.0, 72.0)
const PLAY_BUTTON_SIZE: Vector2 = Vector2(420.0, 150.0)
const CAR_SIZE: Vector2 = Vector2(400.0, 150.0)
const PASSENGER_SIZE: Vector2 = Vector2(30.0, 60.0)
const CENTER_RATIO: float = 0.42
const PLAY_BOTTOM: float = 120.0
const SIDE_TOP_RATIO: float = 0.2
const QUEUE_GAP: float = 90.0
const HINT_SECONDS: float = 1.5

var play_button: Button
var shop_button: Button
var plus_button: Button
var settings_button: Button
var station_button: Button
var wheel_button: Button
var settings_panel: SettingsPanel = SettingsPanel.new()
var coins_label: Label = Label.new()
var level_label: Label = Label.new()
var hint_label: Label = Label.new()
var station_dot: ColorRect = ColorRect.new()
var passengers: MultiMeshInstance2D = MultiMeshInstance2D.new()

var _config: PresentationConfig
var _time: float = 0.0
var _hint_left: float = 0.0
var _root: Control = Control.new()
var _car: ColorRect = ColorRect.new()


## À appeler avant d'entrer dans l'arbre.
func configure(config: PresentationConfig, save: SaveService) -> void:
	_config = config
	settings_panel.setup(save)


func _ready() -> void:
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)
	_build_top()
	_build_center()
	_build_sides()
	_build_hint()
	add_child(settings_panel)
	settings_panel.hide()
	get_viewport().size_changed.connect(_place_center)
	_place_center()


func show_level(level_number: int) -> void:
	level_label.text = tr("HUB_LEVEL") % level_number


func set_coins(balance: int) -> void:
	coins_label.text = tr("COINS_LABEL") % balance


func set_station_ready(ready_now: bool) -> void:
	station_dot.visible = ready_now


## Message court : ce qui n'est pas encore disponible.
func show_hint(text: String) -> void:
	hint_label.text = text
	hint_label.visible = true
	_hint_left = HINT_SECONDS


## La file piétine sur place : animée ici, un seul draw call.
func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_animate_passengers()
	if _hint_left > 0.0:
		_hint_left -= delta
		hint_label.visible = _hint_left > 0.0


func _animate_passengers() -> void:
	for index: int in passengers.multimesh.instance_count:
		passengers.multimesh.set_instance_transform_2d(index, Transform2D(0.0, passenger_position(index)))


func passenger_position(index: int) -> Vector2:
	var count: int = passengers.multimesh.instance_count
	var pitch: float = PASSENGER_SIZE.x * _config.hub_queue_pitch
	var phase: float = _time * _config.hub_queue_speed + float(index) * _config.hub_queue_phase
	return Vector2((float(index) - float(count - 1) * 0.5) * pitch, sin(phase) * _config.hub_queue_bob)


func _build_top() -> void:
	coins_label.add_theme_font_size_override("font_size", FONT_SIZE)
	coins_label.add_theme_color_override("font_color", TEXT_COLOR)
	coins_label.position = Vector2(MARGIN, MARGIN)
	_root.add_child(coins_label)
	plus_button = _make_button("+", TOP_BUTTON_SIZE, FONT_SIZE)
	plus_button.position = Vector2(MARGIN + 240.0, MARGIN)
	plus_button.pressed.connect(_on_shop_pressed)
	settings_button = _make_button(tr("HUB_SETTINGS"), Vector2(170.0, TOP_BUTTON_SIZE.y), 28)
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, int(MARGIN))
	settings_button.pressed.connect(settings_panel.open)


func _build_center() -> void:
	_car.color = CAR_COLOR
	_car.size = CAR_SIZE
	_car.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_car)
	level_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	level_label.add_theme_color_override("font_color", TEXT_COLOR)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_car.add_child(level_label)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = PASSENGER_SIZE
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.mesh = quad
	multimesh.instance_count = _config.hub_queue_count
	passengers.multimesh = multimesh
	passengers.modulate = PASSENGER_COLOR
	_root.add_child(passengers)
	_animate_passengers()
	play_button = _make_button(tr("HUB_PLAY"), PLAY_BUTTON_SIZE, PLAY_FONT_SIZE)
	play_button.pressed.connect(play_pressed.emit)


func _build_sides() -> void:
	shop_button = _side_button("HUB_SHOP", Control.PRESET_TOP_LEFT)
	shop_button.pressed.connect(_on_shop_pressed)
	station_button = _side_button("HUB_STATION", Control.PRESET_TOP_RIGHT)
	station_button.pressed.connect(station_pressed.emit)
	wheel_button = _side_button("HUB_WHEEL", Control.PRESET_TOP_RIGHT)
	wheel_button.pressed.connect(wheel_pressed.emit)
	station_dot.color = Color.RED
	station_dot.size = Vector2(24.0, 24.0)
	station_dot.position = Vector2(SIDE_BUTTON_SIZE.x - 30.0, 6.0)
	station_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	station_dot.visible = false
	station_button.add_child(station_dot)


func _side_button(key: String, preset: Control.LayoutPreset) -> Button:
	var button: Button = _make_button(tr(key), SIDE_BUTTON_SIZE, 28)
	button.set_anchors_preset(preset)
	return button


func _make_button(text: String, button_size: Vector2, font_size: int) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = button_size
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	_root.add_child(button)
	return button


func _build_hint() -> void:
	hint_label.add_theme_font_size_override("font_size", FONT_SIZE)
	hint_label.add_theme_color_override("font_color", TEXT_COLOR)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_label.offset_top = 120.0
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.visible = false
	_root.add_child(hint_label)


## Le format de l'écran change la hauteur virtuelle : tout se place depuis la taille réelle.
func _place_center() -> void:
	var view_size: Vector2 = _root.get_viewport().get_visible_rect().size
	var center: Vector2 = Vector2(view_size.x * 0.5, view_size.y * CENTER_RATIO)
	_car.position = center - CAR_SIZE * 0.5
	passengers.position = center + Vector2(0.0, QUEUE_GAP + CAR_SIZE.y * 0.5)
	play_button.position = Vector2((view_size.x - PLAY_BUTTON_SIZE.x) * 0.5, view_size.y - PLAY_BOTTOM - PLAY_BUTTON_SIZE.y)
	var side_top: float = view_size.y * SIDE_TOP_RATIO
	shop_button.position = Vector2(MARGIN, side_top)
	station_button.position = Vector2(view_size.x - SIDE_BUTTON_SIZE.x - MARGIN, side_top)
	wheel_button.position = Vector2(view_size.x - SIDE_BUTTON_SIZE.x - MARGIN, side_top + SIDE_BUTTON_SIZE.y + MARGIN)


func _on_shop_pressed() -> void:
	show_hint(tr("HUB_SOON"))
