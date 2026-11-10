extends Control

func _ready() -> void:
    _build_ui()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color("#101827")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var title := Label.new()
    title.text = "SELECT YOUR CAR"
    title.position = Vector2(0, 55)
    title.size = Vector2(1280, 75)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 48)
    title.add_theme_color_override("font_color", Color("#FF7518"))
    add_child(title)

    add_child(_car_card("BLUE SUPERCAR", "SUBHOJIT", Color("#1677E8"), Vector2(190, 220), 0))
    add_child(_car_card("RED SPORT SEDAN", "BIRAJ", Color("#D83232"), Vector2(690, 220), 1))

    var selected := Label.new()
    selected.name = "SelectedLabel"
    selected.text = "SELECTED: " + ("BLUE / SUBHOJIT" if GameState.selected_car == 0 else "RED / BIRAJ")
    selected.position = Vector2(0, 570)
    selected.size = Vector2(1280, 35)
    selected.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    selected.add_theme_color_override("font_color", Color.WHITE)
    add_child(selected)

    var back := Button.new()
    back.text = "BACK"
    back.position = Vector2(40, 620)
    back.size = Vector2(180, 60)
    back.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/main_menu.tscn"))
    add_child(back)

    var play := Button.new()
    play.text = "PLAY"
    play.position = Vector2(1000, 620)
    play.size = Vector2(220, 60)
    play.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/race.tscn"))
    add_child(play)

func _car_card(heading: String, decal: String, paint: Color, pos: Vector2, car_id: int) -> Control:
    var panel := Panel.new()
    panel.position = pos
    panel.size = Vector2(400, 330)
    panel.add_theme_stylebox_override("panel", _style(Color("#1D2A3D")))

    var h := Label.new()
    h.text = heading
    h.position = Vector2(0, 18)
    h.size = Vector2(400, 40)
    h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    h.add_theme_font_size_override("font_size", 24)
    panel.add_child(h)

    # Build a simple top-down car preview instead of a flat color tile.
    var shadow := ColorRect.new()
    shadow.color = Color("#0B111B")
    shadow.position = Vector2(75, 125)
    shadow.size = Vector2(250, 92)
    panel.add_child(shadow)

    var body := ColorRect.new()
    body.color = paint
    body.position = Vector2(88, 116)
    body.size = Vector2(224, 82)
    panel.add_child(body)

    var cabin := ColorRect.new()
    cabin.color = Color("#172B40")
    cabin.position = Vector2(145, 124)
    cabin.size = Vector2(110, 65)
    panel.add_child(cabin)

    var windshield := ColorRect.new()
    windshield.color = Color("#6D879C")
    windshield.position = Vector2(153, 130)
    windshield.size = Vector2(94, 18)
    panel.add_child(windshield)

    for wheel_x in [78, 292]:
        for wheel_y in [130, 178]:
            var wheel := ColorRect.new()
            wheel.color = Color("#080B10")
            wheel.position = Vector2(wheel_x, wheel_y)
            wheel.size = Vector2(18, 28)
            panel.add_child(wheel)

    for lamp_x in [96, 286]:
        var lamp := ColorRect.new()
        lamp.color = Color("#FFF1B8")
        lamp.position = Vector2(lamp_x, 112)
        lamp.size = Vector2(16, 7)
        panel.add_child(lamp)

    var label := Label.new()
    label.text = decal
    label.position = Vector2(90, 205)
    label.size = Vector2(220, 40)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 26)
    label.add_theme_color_override("font_color", Color.WHITE)
    panel.add_child(label)

    var choose := Button.new()
    choose.text = "SELECT"
    choose.position = Vector2(100, 265)
    choose.size = Vector2(200, 48)
    choose.pressed.connect(func():
        GameState.selected_car = car_id
        var selected_label := get_node_or_null("SelectedLabel")
        if selected_label:
            selected_label.text = "SELECTED: " + ("BLUE / SUBHOJIT" if car_id == 0 else "RED / BIRAJ")
    )
    panel.add_child(choose)
    return panel

func _style(color: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.corner_radius_top_left = 10
    s.corner_radius_top_right = 10
    s.corner_radius_bottom_left = 10
    s.corner_radius_bottom_right = 10
    return s
