extends Control

var sensitivity_value: float = 1.0
var value_label: Label

func _ready() -> void:
    sensitivity_value = GameState.steering_sensitivity
    _build_ui()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color("#101827")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var title := Label.new()
    title.text = "SETTINGS"
    title.position = Vector2(0, 100)
    title.size = Vector2(1280, 80)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 56)
    title.add_theme_color_override("font_color", Color("#FF7518"))
    add_child(title)

    var heading := Label.new()
    heading.text = "STEERING SENSITIVITY"
    heading.position = Vector2(300, 290)
    heading.size = Vector2(680, 45)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 25)
    heading.add_theme_color_override("font_color", Color.WHITE)
    add_child(heading)

    var slider := HSlider.new()
    slider.position = Vector2(350, 365)
    slider.size = Vector2(580, 50)
    slider.min_value = 0.5
    slider.max_value = 1.8
    slider.step = 0.1
    slider.value = sensitivity_value
    slider.value_changed.connect(_on_sensitivity_changed)
    add_child(slider)

    value_label = Label.new()
    value_label.position = Vector2(0, 430)
    value_label.size = Vector2(1280, 40)
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    value_label.add_theme_font_size_override("font_size", 22)
    value_label.add_theme_color_override("font_color", Color("#FFCCAA"))
    add_child(value_label)
    _update_value_label()

    var back := Button.new()
    back.text = "SAVE & BACK"
    back.position = Vector2(440, 535)
    back.size = Vector2(400, 70)
    back.add_theme_font_size_override("font_size", 25)
    back.pressed.connect(_save_and_back)
    add_child(back)

func _on_sensitivity_changed(value: float) -> void:
    sensitivity_value = value
    _update_value_label()

func _update_value_label() -> void:
    value_label.text = "Sensitivity: %.1fx" % sensitivity_value

func _save_and_back() -> void:
    GameState.steering_sensitivity = sensitivity_value
    GameState.save_settings()
    get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
