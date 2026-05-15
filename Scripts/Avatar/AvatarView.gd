extends Control

const AVATAR_SPRITESHEET_PATH := "res://Assets/Avatar/Body/character_spritesheet.png"
const DEFAULT_BACKGROUND_PATH := "res://Assets/Avatar/Backgrounds/forest_default.png"
const DEFAULT_TORSO_PATH := "res://Assets/Avatar/Equipment/Default/Torso/chemise_delavee.png"
const DEFAULT_LEGS_PATH := "res://Assets/Avatar/Equipment/Default/Legs/default_bottom.png"
const DEFAULT_FEET_PATH := "res://Assets/Avatar/Equipment/Default/Feet/default_shoes.png"
const DEFAULT_HAIR_PATH := "res://Assets/Avatar/Hair/Style_01/blond.png"
const AVATAR_FRAME_SIZE := Vector2(64, 64)
const AVATAR_DIRECTION_FRAMES := [
	Vector2(0, 2),
	Vector2(0, 1),
	Vector2(0, 0),
	Vector2(0, 3),
]
const ARROW_SIZE := Vector2(44, 44)
var _level: int = 1
var _rank: String = "F"
var _equipment: Dictionary = {}
var _direction_index: int = 0
var _background_texture: Texture2D = null
var _avatar_spritesheet: Texture2D = null
var _default_torso_texture: Texture2D = null
var _default_legs_texture: Texture2D = null
var _default_feet_texture: Texture2D = null
var _default_hair_texture: Texture2D = null
var _left_arrow_rect := Rect2()
var _right_arrow_rect := Rect2()

func _ready() -> void:
	custom_minimum_size = Vector2(180, 250)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_background()
	_load_avatar_spritesheet()
	_load_default_equipment()
	_load_default_hair()

func set_avatar_state(level: int, rank: String, _equipment: Dictionary) -> void:
	_level = level
	_rank = rank
	self._equipment = _equipment
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var center := Vector2(w * 0.5, h * 0.61)
	var scale := minf(w / 210.0, h / 270.0)
	var avatar_rect := _get_avatar_rect(center, scale)
	var source_rect := _get_source_rect()

	_draw_background()
	_draw_base_avatar(avatar_rect, source_rect)
	_draw_base_skin(avatar_rect, source_rect)
	_draw_default_hair(avatar_rect, source_rect)
	_draw_rotation_arrows(center, scale)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_handle_rotation_input(event.position)
		accept_event()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_rotation_input(event.position)
		accept_event()

func _handle_rotation_input(position: Vector2) -> void:
	if _left_arrow_rect.has_point(position):
		_rotate_avatar(-1)
	elif _right_arrow_rect.has_point(position):
		_rotate_avatar(1)

func _draw_base_avatar(rect: Rect2, source_rect: Rect2) -> void:
	if _avatar_spritesheet == null:
		return

	draw_texture_rect_region(_avatar_spritesheet, rect, source_rect)

func _draw_background() -> void:
	if _background_texture == null:
		return

	var texture_size := _background_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var target_rect := Rect2(Vector2.ZERO, size)
	var target_ratio := size.x / size.y
	var source_ratio := texture_size.x / texture_size.y
	var source_size := texture_size
	var source_pos := Vector2.ZERO

	if source_ratio > target_ratio:
		source_size.x = texture_size.y * target_ratio
		source_pos.x = (texture_size.x - source_size.x) * 0.5
	else:
		source_size.y = texture_size.x / target_ratio
		source_pos.y = (texture_size.y - source_size.y) * 0.5

	draw_texture_rect_region(_background_texture, target_rect, Rect2(source_pos, source_size))

func _draw_base_skin(rect: Rect2, source_rect: Rect2) -> void:
	_draw_equipment_texture(_default_torso_texture, rect, source_rect)
	_draw_equipment_texture(_default_legs_texture, rect, source_rect)
	_draw_equipment_texture(_default_feet_texture, rect, source_rect)

func _draw_equipment_texture(texture: Texture2D, rect: Rect2, source_rect: Rect2) -> void:
	if texture == null:
		return

	draw_texture_rect_region(texture, rect, source_rect)

func _draw_default_hair(rect: Rect2, source_rect: Rect2) -> void:
	if _default_hair_texture == null:
		return

	draw_texture_rect_region(_default_hair_texture, rect, source_rect)

func _get_avatar_rect(center: Vector2, scale: float) -> Rect2:
	var target_size := Vector2(184, 184) * scale
	return Rect2(
		center + Vector2(-target_size.x * 0.5, -116.0 * scale),
		target_size
	)

func _get_source_rect() -> Rect2:
	var source_frame: Vector2 = AVATAR_DIRECTION_FRAMES[_direction_index]
	return Rect2(source_frame * AVATAR_FRAME_SIZE, AVATAR_FRAME_SIZE)

func _draw_rotation_arrows(center: Vector2, scale: float) -> void:
	var button_size := ARROW_SIZE * scale
	_left_arrow_rect = Rect2(center + Vector2(-116, -34) * scale, button_size)
	_right_arrow_rect = Rect2(center + Vector2(72, -34) * scale, button_size)

	_draw_arrow_button(_left_arrow_rect, true, scale)
	_draw_arrow_button(_right_arrow_rect, false, scale)

func _draw_arrow_button(rect: Rect2, points_left: bool, scale: float) -> void:
	draw_rect(rect, Color(0.03, 0.07, 0.11, 0.86), true)
	draw_rect(rect, Color(0.0, 0.67, 1.0, 0.95), false, 2.0 * scale)

	var mid := rect.get_center()
	var arrow_width := 12.0 * scale
	var arrow_height := 17.0 * scale
	var arrow := PackedVector2Array()
	if points_left:
		arrow = PackedVector2Array([
			mid + Vector2(-arrow_width * 0.55, 0),
			mid + Vector2(arrow_width * 0.45, -arrow_height * 0.5),
			mid + Vector2(arrow_width * 0.45, arrow_height * 0.5),
		])
	else:
		arrow = PackedVector2Array([
			mid + Vector2(arrow_width * 0.55, 0),
			mid + Vector2(-arrow_width * 0.45, -arrow_height * 0.5),
			mid + Vector2(-arrow_width * 0.45, arrow_height * 0.5),
		])
	draw_colored_polygon(arrow, Color("#d8f4ff"))

func _rotate_avatar(step: int) -> void:
	_direction_index = posmod(_direction_index + step, AVATAR_DIRECTION_FRAMES.size())
	queue_redraw()

func _load_avatar_spritesheet() -> void:
	_avatar_spritesheet = _load_texture_from_path(AVATAR_SPRITESHEET_PATH)

func _load_background() -> void:
	_background_texture = _load_texture_from_path(DEFAULT_BACKGROUND_PATH)

func _load_default_equipment() -> void:
	_default_torso_texture = _load_texture_from_path(DEFAULT_TORSO_PATH)
	_default_legs_texture = _load_texture_from_path(DEFAULT_LEGS_PATH)
	_default_feet_texture = _load_texture_from_path(DEFAULT_FEET_PATH)

func _load_default_hair() -> void:
	_default_hair_texture = _load_texture_from_path(DEFAULT_HAIR_PATH)

func _load_texture_from_path(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		push_warning("Texture avatar introuvable: %s" % path)
		return null

	return ImageTexture.create_from_image(image)
