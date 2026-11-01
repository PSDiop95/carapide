class_name BoosterButton
extends Button
## Bouton de la barre : nom du booster, badge de stock, de prix ou de pub.

const SIZE: Vector2 = Vector2(200.0, 112.0)
const NAME_FONT_SIZE: int = 30
const BADGE_FONT_SIZE: int = 22
const BADGE_MARGIN: float = 6.0
const AD_ICON_SIZE: float = 16.0
const AD_ICON_GAP: float = 6.0
const LOCKED_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.75)
const ACTIVE_MODULATE: Color = Color(1.0, 0.9, 0.45)
const LOCKED_TEXT_COLOR: Color = Color(0.92, 0.92, 0.92)

var badge: Label = Label.new()

var _ad_icon: bool = false


func _ready() -> void:
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_NONE
	add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	add_theme_color_override("font_disabled_color", LOCKED_TEXT_COLOR)
	badge.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, int(BADGE_MARGIN))
	badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(badge)


func show_state(title: String, badge_text: String, is_enabled: bool, ad_icon: bool) -> void:
	text = title
	badge.text = badge_text
	disabled = not is_enabled
	modulate = Color.WHITE if is_enabled else LOCKED_MODULATE
	_ad_icon = ad_icon
	queue_redraw()


func set_active(active: bool) -> void:
	modulate = ACTIVE_MODULATE if active else Color.WHITE


## Triangle « lecture » à gauche du badge : l'icône de pub.
func _draw() -> void:
	if not _ad_icon:
		return
	var badge_rect: Rect2 = badge.get_rect()
	var right: float = badge_rect.position.x - AD_ICON_GAP + (badge_rect.size.x - badge.get_minimum_size().x) * 0.5
	var middle: float = badge_rect.get_center().y
	var half: float = AD_ICON_SIZE * 0.5
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(right - AD_ICON_SIZE, middle - half), Vector2(right, middle), Vector2(right - AD_ICON_SIZE, middle + half),
	])
	draw_colored_polygon(points, Color.WHITE)
