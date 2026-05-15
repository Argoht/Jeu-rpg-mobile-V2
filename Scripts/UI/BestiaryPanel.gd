extends ScrollContainer

const MONSTERS = [
	{"name": "Chauve-souris", "path": "res://Assets/Monsters/Bestiary/bat_fly.png", "frames": 11},
	{"name": "Mimic", "path": "res://Assets/Monsters/Bestiary/mimic_idle.png", "frames": 9},
	{"name": "Rat", "path": "res://Assets/Monsters/Bestiary/rat_idle.png", "frames": 10},
	{"name": "Slime", "path": "res://Assets/Monsters/Bestiary/slime_idle.png", "frames": 14},
	{"name": "Oeil volant", "path": "res://Assets/Monsters/Bestiary/flying_eye_flight.png", "frames": 8},
	{"name": "Gobelin", "path": "res://Assets/Monsters/Bestiary/goblin_idle.png", "frames": 4},
	{"name": "Champignon", "path": "res://Assets/Monsters/Bestiary/mushroom_idle.png", "frames": 4},
	{"name": "Squelette", "path": "res://Assets/Monsters/Bestiary/skeleton_idle.png", "frames": 4},
	{"name": "Rat sauvage", "path": "res://Assets/Monsters/Bestiary/rat_savage_idle.png", "frames": 6},
	{"name": "Golem bleu", "path": "res://Assets/Monsters/Bestiary/golem_blue_idle.png", "frames": 9, "frame_width": 80, "frame_height": 64},
	{"name": "Golem orange", "path": "res://Assets/Monsters/Bestiary/golem_orange_idle.png", "frames": 9, "frame_width": 80, "frame_height": 64},
	{"name": "Epee demoniaque", "path": "res://Assets/Monsters/Bestiary/demon_sword_idle.png", "frames": 7, "frame_width": 256, "frame_height": 512},
	{"name": "Minotaure", "path": "res://Assets/Monsters/Bestiary/minotaur_idle.png", "frames": 16, "frame_width": 288, "frame_height": 160},
	{"name": "Demon slime", "path": "res://Assets/Monsters/Bestiary/demon_slime_idle.png", "frames": 6, "frame_width": 288, "frame_height": 160},
	{"name": "Chevalier", "path": "res://Assets/Monsters/Bestiary/knight_idle.png", "frames": 15},
]

var _monster_dialog: AcceptDialog = null
var _monster_preview: TextureRect = null
var _monster_title: Label = null
var _animation_timer: Timer = null
var _current_monster: Dictionary = {}
var _current_frame := 0

func _ready() -> void:
	name = "Bestiaire"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_build()
	_build_monster_dialog()

func _build() -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	margin.add_child(grid)

	for monster in MONSTERS:
		grid.add_child(_make_monster_card(monster))

func _make_monster_card(monster: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 124)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_monster_card_input.bind(monster))
	card.tooltip_text = "Voir en grand"
	card.add_theme_stylebox_override("panel", _card_style())

	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(92, 74)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = _make_frame_texture(monster, 0)
	box.add_child(icon)

	var label = Label.new()
	label.text = String(monster.get("name", "Monstre")).to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("#d9f7ff"))
	box.add_child(label)

	return card

func _on_monster_card_input(event: InputEvent, monster: Dictionary) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_monster(monster)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_show_monster(monster)
		accept_event()

func _build_monster_dialog() -> void:
	_monster_dialog = AcceptDialog.new()
	_monster_dialog.title = "Bestiaire"
	_monster_dialog.min_size = Vector2i(330, 300)
	_monster_dialog.close_requested.connect(_stop_monster_animation)
	_monster_dialog.canceled.connect(_stop_monster_animation)
	_monster_dialog.confirmed.connect(_stop_monster_animation)
	add_child(_monster_dialog)

	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	_monster_dialog.add_child(box)

	_monster_title = Label.new()
	_monster_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monster_title.add_theme_font_size_override("font_size", 18)
	_monster_title.add_theme_color_override("font_color", Color("#00f2ff"))
	box.add_child(_monster_title)

	_monster_preview = TextureRect.new()
	_monster_preview.custom_minimum_size = Vector2(260, 190)
	_monster_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_monster_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_monster_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(_monster_preview)

	_animation_timer = Timer.new()
	_animation_timer.wait_time = 0.12
	_animation_timer.timeout.connect(_advance_monster_animation)
	add_child(_animation_timer)

func _show_monster(monster: Dictionary) -> void:
	if _monster_dialog == null:
		return

	var monster_name = String(monster.get("name", "Monstre"))
	_current_monster = monster
	_current_frame = 0
	_monster_dialog.title = monster_name
	_monster_title.text = monster_name.to_upper()
	_monster_preview.texture = _make_frame_texture(monster, _current_frame)
	_monster_dialog.popup_centered(Vector2i(340, 320))

	if _get_frame_count(monster) > 1:
		_animation_timer.start()
	else:
		_animation_timer.stop()

func _advance_monster_animation() -> void:
	if _current_monster.is_empty():
		_animation_timer.stop()
		return

	var frame_count = _get_frame_count(_current_monster)
	if frame_count <= 1:
		_animation_timer.stop()
		return

	_current_frame = (_current_frame + 1) % frame_count
	_monster_preview.texture = _make_frame_texture(_current_monster, _current_frame)

func _stop_monster_animation() -> void:
	if _animation_timer != null:
		_animation_timer.stop()
	_current_monster = {}
	_current_frame = 0

func _make_first_frame_texture(path: String) -> Texture2D:
	var atlas = load(path)
	if atlas is Texture2D:
		return _make_atlas_first_frame(atlas)

	var image = Image.new()
	var error = image.load(path)
	if error == OK:
		return _make_atlas_first_frame(ImageTexture.create_from_image(image))
	return null

func _make_atlas_first_frame(atlas: Texture2D) -> AtlasTexture:
	var frame_size = minf(atlas.get_width(), atlas.get_height())
	var texture = AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(0, 0, frame_size, atlas.get_height())
	return texture

func _make_frame_texture(monster: Dictionary, frame: int) -> Texture2D:
	var path = String(monster.get("path", ""))
	var atlas = load(path)
	if not atlas is Texture2D:
		var image = Image.new()
		var error = image.load(path)
		if error != OK:
			return null
		atlas = ImageTexture.create_from_image(image)

	var texture = AtlasTexture.new()
	var frame_size = _get_frame_size(monster, atlas)
	texture.atlas = atlas
	texture.region = Rect2(frame_size.x * frame, 0, frame_size.x, frame_size.y)
	return texture

func _get_frame_count(monster: Dictionary) -> int:
	return maxi(1, int(monster.get("frames", 1)))

func _get_frame_size(monster: Dictionary, atlas: Texture2D) -> Vector2:
	if monster.has("frame_width") and monster.has("frame_height"):
		return Vector2(float(monster["frame_width"]), float(monster["frame_height"]))

	var frame_count = _get_frame_count(monster)
	if frame_count > 1:
		return Vector2(atlas.get_width() / float(frame_count), atlas.get_height())

	return Vector2(atlas.get_width(), atlas.get_height())

func _card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.033, 0.045, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.63, 1.0, 0.42)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style
