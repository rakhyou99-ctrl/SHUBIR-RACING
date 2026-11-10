extends Control

func _ready() -> void:
    _build_ui()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color("#101827")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var title := Label.new()
    title.text = "SHUBIR RACING"
    title.add_theme_font_size_override("font_size", 64)
    title.add_theme_color_override("font_color", Color("#FF7518"))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.set_anchors_preset(Control.PRESET_CENTER_TOP)
    title.position = Vector2(-400, 90)
    title.size = Vector2(800, 90)
    add_child(title)

    var subtitle := Label.new()
    subtitle.text = "OFFLINE  •  ENDLESS HIGHWAY"
    subtitle.add_theme_font_size_override("font_size", 22)
    subtitle.add_theme_color_override("font_color", Color("#D7E0EA"))
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.position = Vector2(0, 190)
    subtitle.size = Vector2(1280, 45)
    add_child(subtitle)

    var play := _make_button("PLAY", Vector2(440, 330), Vector2(400, 76))
    play.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/race.tscn"))
    add_child(play)

    var garage := _make_button("GARAGE / SELECT CAR", Vector2(440, 425), Vector2(400, 76))
    garage.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/garage.tscn"))
    add_child(garage)

    var note := Label.new()
    note.text = "Prototype • Original placeholder 3D cars"
    note.add_theme_font_size_override("font_size", 16)
    note.add_theme_color_override("font_color", Color("#94A3B8"))
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.position = Vector2(0, 630)
    note.size = Vector2(1280, 35)
    add_child(note)

func _make_button(label_text: String, pos: Vector2, btn_size: Vector2) -> Button:
    var b := Button.new()
    b.text = label_text
    b.position = pos
    b.size = btn_size
    b.add_theme_font_size_override("font_size", 26)
    b.add_theme_color_override("font_color", Color.WHITE)
    b.add_theme_stylebox_override("normal", _button_style(Color("#FF7518")))
    b.add_theme_stylebox_override("hover", _button_style(Color("#FF8B3D")))
    return b

func _button_style(color: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.corner_radius_top_left = 12
    s.corner_radius_top_right = 12
    s.corner_radius_bottom_left = 12
    s.corner_radius_bottom_right = 12
    return s
