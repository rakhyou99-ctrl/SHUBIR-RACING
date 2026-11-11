extends Control

var sensitivity_value: float = 1.0
var volume_value: float = 0.75
var volume_label: Label
var sensitivity_label: Label
var settings_title: Label
var steering_heading: Label
var steering_slider: HSlider
var volume_heading: Label
var volume_slider: HSlider
var save_button: Button
var tilt_hint: Label

func _notification(what: int) -> void:
    # Save changed preferences and return when Android system Back is pressed.
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _save_and_back()

func _ready() -> void:
    sensitivity_value = GameState.steering_sensitivity
    volume_value = GameState.master_volume
    _build_ui()
    get_viewport().size_changed.connect(_layout_settings)
    _layout_settings()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color("#101827")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    settings_title = Label.new()
    var title := settings_title
    title.text = "SETTINGS"
    title.position = Vector2(0, 65)
    title.size = Vector2(1280, 75)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 54)
    title.add_theme_color_override("font_color", Color("#FF7518"))
    add_child(title)

    steering_heading = _make_heading("PHONE TILT STEERING SENSITIVITY", 210)
    add_child(steering_heading)

    steering_slider = HSlider.new()
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

    volume_heading = _make_heading("MASTER VOLUME", 395)
    add_child(volume_heading)

    volume_slider = HSlider.new()
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

    tilt_hint = Label.new()
    tilt_hint.text = "Hold phone level at race start  •  Tilt LEFT / RIGHT to steer"
    tilt_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tilt_hint.add_theme_font_size_override("font_size", 15)
    tilt_hint.add_theme_color_override("font_color", Color("#AFC0D4"))
    add_child(tilt_hint)

    save_button = Button.new()
    var back := save_button
    back.text = "SAVE & BACK"
    back.position = Vector2(440, 590)
    back.size = Vector2(400, 65)
    back.add_theme_font_size_override("font_size", 24)
    back.pressed.connect(_save_and_back)
    add_child(back)

func _layout_settings() -> void:
    _layout_settings_for_size(get_viewport().get_visible_rect().size)


func _layout_settings_for_size(viewport_size: Vector2) -> void:
    var scale_factor := clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.55, 1.15)
    var center_x := viewport_size.x * 0.5

    # Anchor each control to the available landscape height so short phones do not
    # overlap the volume controls or push SAVE & BACK off-screen.
    settings_title.scale = Vector2.ONE * scale_factor
    settings_title.position = Vector2(0, viewport_size.y * 0.055)
    settings_title.size = Vector2(viewport_size.x, 75)
    steering_heading.scale = Vector2.ONE * scale_factor
    steering_heading.position = Vector2(center_x - 340.0 * scale_factor, viewport_size.y * 0.245)
    steering_heading.size = Vector2(680, 40)
    steering_slider.scale = Vector2.ONE * scale_factor
    steering_slider.position = Vector2(center_x - 290.0 * scale_factor, viewport_size.y * 0.345)
    steering_slider.size = Vector2(580, 45)
    sensitivity_label.scale = Vector2.ONE * scale_factor
    sensitivity_label.position = Vector2(0, viewport_size.y * 0.435)
    sensitivity_label.size = Vector2(viewport_size.x, 35)
    volume_heading.scale = Vector2.ONE * scale_factor
    volume_heading.position = Vector2(center_x - 340.0 * scale_factor, viewport_size.y * 0.525)
    volume_heading.size = Vector2(680, 40)
    volume_slider.scale = Vector2.ONE * scale_factor
    volume_slider.position = Vector2(center_x - 290.0 * scale_factor, viewport_size.y * 0.625)
    volume_slider.size = Vector2(580, 45)
    volume_label.scale = Vector2.ONE * scale_factor
    volume_label.position = Vector2(0, viewport_size.y * 0.715)
    volume_label.size = Vector2(viewport_size.x, 35)
    tilt_hint.scale = Vector2.ONE * scale_factor
    tilt_hint.position = Vector2(0, viewport_size.y * 0.795)
    tilt_hint.size = Vector2(viewport_size.x, 28)
    save_button.scale = Vector2.ONE * scale_factor
    save_button.position = Vector2(center_x - 200.0 * scale_factor, viewport_size.y - 82.0 * scale_factor)
    save_button.size = Vector2(400, 65)

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
    GameState.steering_sensitivity = sensitivity_value
    GameState.save_settings()
    _update_sensitivity_label()

func _on_volume_changed(value: float) -> void:
    volume_value = value
    GameState.master_volume = volume_value
    GameState.save_settings()
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
