extends Control

var sensitivity_value: float = 1.0
var volume_value: float = 0.75
var sensitivity_label: Label
var volume_label: Label

func _ready() -> void:
    sensitivity_value = GameState.steering_sensitivity
    volume_value = GameState.master_volume
    _build_ui()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color("#101827")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var title := Label.new()
    title.text = "SETTINGS"
    title.position = Vector2(0, 65)
    title.size = Vector2(1280, 75)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 54)
    title.add_theme_color_override("font_color", Color("#FF7518"))
    add_child(title)

    var steering_heading := _make_heading("STEERING SENSITIVITY", 210)
    add_child(steering_heading)

    var steering_slider := HSlider.new()
    steering_slider.position = Vector2(350, 275)
    steering_slider.size = Vector2(580, 45)
    steering_slider.min_value = 0.5
    steering_slider.max_value = 1.8
    steering_slider.step = 0.1
    steering_slider.value = sensitivity_value
    steering_slider.value_changed.connect(_on_sensitivity_changed)
    add_child(steering_slider)

    sensitivity_label = _make_value_label(325)
    add_child(sensitivity_label)
    _update_sensitivity_label()

    var volume_heading := _make_heading("MASTER VOLUME", 395)
    add_child(volume_heading)

    var volume_slider := HSlider.new()
    volume_slider.position = Vector2(350, 460)
    volume_slider.size = Vector2(580, 45)
    volume_slider.min_value = 0.0
    volume_slider.max_value = 1.0
    volume_slider.step = 0.05
    volume_slider.value = volume_value
    volume_slider.value_changed.connect(_on_volume_changed)
    add_child(volume_slider)

    volume_label = _make_value_label(510)
    add_child(volume_label)
    _update_volume_label()

    var back := Button.new()
    back.text = "SAVE & BACK"
    back.position = Vector2(440, 590)
    back.size = Vector2(400, 65)
    back.add_theme_font_size_override("font_size", 24)
    back.pressed.connect(_save_and_back)
    add_child(back)

func _make_heading(text_value: String, y: float) -> Label:
    var label := Label.new()
    label.text = text_value
    label.position = Vector2(300, y)
    label.size = Vector2(680, 40)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 23)
    label.add_theme_color_override("font_color", Color.WHITE)
    return label

func _make_value_label(y: float) -> Label:
    var label := Label.new()
    label.position = Vector2(0, y)
    label.size = Vector2(1280, 35)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 20)
    label.add_theme_color_override("font_color", Color("#FFCCAA"))
    return label

func _on_sensitivity_changed(value: float) -> void:
    sensitivity_value = value
    _update_sensitivity_label()

func _on_volume_changed(value: float) -> void:
    volume_value = value
    AudioServer.set_bus_volume_linear(0, volume_value)
    _update_volume_label()

func _update_sensitivity_label() -> void:
    sensitivity_label.text = "Sensitivity: %.1fx" % sensitivity_value

func _update_volume_label() -> void:
    volume_label.text = "Volume: %d%%" % int(volume_value * 100.0)

func _save_and_back() -> void:
    GameState.steering_sensitivity = sensitivity_value
    GameState.master_volume = volume_value
    GameState.save_settings()
    get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
