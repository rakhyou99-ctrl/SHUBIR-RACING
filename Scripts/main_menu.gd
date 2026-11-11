extends Control

var title_label: Label
var subtitle_label: Label
var note_label: Label
var best_distance_label: Label
var play_button: Button
var garage_button: Button
var settings_button: Button
var exit_button: Button

func _ready() -> void:
    _build_ui()
    get_viewport().size_changed.connect(_layout_menu)
    _layout_menu()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color("#101827")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    title_label = Label.new()
    var title := title_label
    title.text = "SHUBIR RACING"
    title.add_theme_font_size_override("font_size", 64)
    title.add_theme_color_override("font_color", Color("#FF7518"))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.set_anchors_preset(Control.PRESET_TOP_LEFT)
    title.position = Vector2(-400, 90)
    title.size = Vector2(800, 90)
    add_child(title)

    subtitle_label = Label.new()
    var subtitle := subtitle_label
    subtitle.text = "OFFLINE  •  ENDLESS HIGHWAY"
    subtitle.add_theme_font_size_override("font_size", 22)
    subtitle.add_theme_color_override("font_color", Color("#D7E0EA"))
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.position = Vector2(0, 190)
    subtitle.size = Vector2(1280, 45)
    add_child(subtitle)

    play_button = _make_button("PLAY", Vector2.ZERO, Vector2(400, 76))
    var play := play_button
    play.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/race.tscn"))
    add_child(play)

    garage_button = _make_button("GARAGE / SELECT CAR", Vector2.ZERO, Vector2(400, 76))
    var garage := garage_button
    garage.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/garage.tscn"))
    add_child(garage)

    settings_button = _make_button("SETTINGS", Vector2.ZERO, Vector2(400, 64))
    var settings := settings_button
    settings.add_theme_stylebox_override("normal", _button_style(Color("#35445A")))
    settings.add_theme_stylebox_override("hover", _button_style(Color("#52647D")))
    settings.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/settings.tscn"))
    add_child(settings)

    exit_button = _make_button("EXIT GAME", Vector2.ZERO, Vector2(400, 58))
    var exit := exit_button
    exit.add_theme_stylebox_override("normal", _button_style(Color("#35445A")))
    exit.add_theme_stylebox_override("hover", _button_style(Color("#52647D")))
    exit.pressed.connect(func(): get_tree().quit())
    add_child(exit)

    best_distance_label = Label.new()
    var best_record := ConfigFile.new()
    best_record.load("user://shubir_racing.cfg")
    var best_distance := float(best_record.get_value("score", "best_distance", 0.0))
    var best_score := int(best_record.get_value("score", "best_score", 0))
    best_distance_label.text = "PERSONAL BEST  %.2f KM   •   SCORE  %06d" % [best_distance, best_score]
    best_distance_label.add_theme_font_size_override("font_size", 19)
    best_distance_label.add_theme_color_override("font_color", Color("#FFCCAA"))
    best_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(best_distance_label)

    note_label = Label.new()
    var note := note_label
    note.text = "TILT TO STEER  •  BRAKE  •  ACCELERATOR  •  BOOST"
    note.add_theme_font_size_override("font_size", 16)
    note.add_theme_color_override("font_color", Color("#94A3B8"))
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.position = Vector2(0, 675)
    note.size = Vector2(1280, 35)
    add_child(note)

func _layout_menu() -> void:
    _layout_menu_for_size(get_viewport().get_visible_rect().size)


func _layout_menu_for_size(viewport_size: Vector2) -> void:
    var scale_factor := clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.55, 1.15)
    var center_x := viewport_size.x * 0.5
    title_label.scale = Vector2.ONE * scale_factor
    title_label.position = Vector2(center_x - 400.0 * scale_factor, viewport_size.y * 0.10)
    title_label.size = Vector2(800, 90)
    subtitle_label.scale = Vector2.ONE * scale_factor
    subtitle_label.position = Vector2(0, viewport_size.y * 0.255)
    subtitle_label.size = Vector2(viewport_size.x, 45 * scale_factor)

    var button_gap := 14.0 * scale_factor
    var heights := [76.0, 76.0, 64.0, 58.0]
    var total_height: float = (heights[0] + heights[1] + heights[2] + heights[3]) * scale_factor + button_gap * 3.0
    var start_y := maxf(viewport_size.y * 0.39, (viewport_size.y - total_height) * 0.53)
    var buttons := [play_button, garage_button, settings_button, exit_button]
    var y := start_y
    for i in range(buttons.size()):
        var button: Button = buttons[i]
        button.scale = Vector2.ONE * scale_factor
        button.position = Vector2(center_x - 200.0 * scale_factor, y)
        button.size = Vector2(400, heights[i])
        y += heights[i] * scale_factor + button_gap
    best_distance_label.scale = Vector2.ONE * scale_factor
    best_distance_label.position = Vector2(0, viewport_size.y - 82.0 * scale_factor)
    best_distance_label.size = Vector2(viewport_size.x, 30)
    note_label.scale = Vector2.ONE * scale_factor
    note_label.position = Vector2(0, viewport_size.y - 42.0 * scale_factor)
    note_label.size = Vector2(viewport_size.x, 35)

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
