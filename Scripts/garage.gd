extends Control

var preview_root: Node3D
var preview_car: Node3D
var drag_active := false
var last_drag_x := 0.0
var selected_label: Label
var blue_card: Panel
var red_card: Panel
var blue_button: Button
var red_button: Button

func _ready() -> void:
    _build_garage()

func _build_garage() -> void:
    var bg := ColorRect.new()
    bg.color = Color("#0B1220")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var header := Label.new()
    header.text = "GARAGE  /  360° SHOWROOM"
    header.position = Vector2(42, 24)
    header.size = Vector2(800, 56)
    header.add_theme_font_size_override("font_size", 34)
    header.add_theme_color_override("font_color", Color("#FF7518"))
    add_child(header)

    var preview_frame := Panel.new()
    preview_frame.position = Vector2(38, 100)
    preview_frame.size = Vector2(820, 540)
    preview_frame.add_theme_stylebox_override("panel", _panel_style(Color("#111D2E"), false))
    add_child(preview_frame)

    var viewport_box := SubViewportContainer.new()
    viewport_box.position = Vector2(10, 10)
    viewport_box.size = Vector2(800, 500)
    viewport_box.stretch = true
    viewport_box.mouse_filter = Control.MOUSE_FILTER_STOP
    preview_frame.add_child(viewport_box)
    viewport_box.gui_input.connect(_on_preview_input)

    var viewport := SubViewport.new()
    viewport.size = Vector2i(800, 500)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport_box.add_child(viewport)

    preview_root = Node3D.new()
    viewport.add_child(preview_root)
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#111D2E")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#A9C3E8")
    environment.ambient_light_energy = 0.65
    world.environment = environment
    preview_root.add_child(world)

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-48, -32, 0)
    key_light.light_energy = 1.6
    preview_root.add_child(key_light)
    var fill_light := OmniLight3D.new()
    fill_light.position = Vector3(-3, 3, 2)
    fill_light.light_energy = 1.0
    fill_light.omni_range = 12.0
    preview_root.add_child(fill_light)

    var camera := Camera3D.new()
    camera.position = Vector3(0, 2.45, 6.4)
    camera.look_at(Vector3(0, 0.55, 0), Vector3.UP)
    camera.current = true
    preview_root.add_child(camera)

    var floor := MeshInstance3D.new()
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(18, 18)
    floor.mesh = floor_mesh
    floor.position.y = -0.04
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color("#17263A")
    floor_mat.roughness = 0.72
    floor.material_override = floor_mat
    preview_root.add_child(floor)

    preview_car = _create_preview_car()
    preview_root.add_child(preview_car)

    var swipe_hint := Label.new()
    swipe_hint.text = "DRAG LEFT / RIGHT TO ROTATE  •  360° VIEW"
    swipe_hint.position = Vector2(0, 510)
    swipe_hint.size = Vector2(820, 24)
    swipe_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    swipe_hint.add_theme_font_size_override("font_size", 16)
    swipe_hint.add_theme_color_override("font_color", Color("#AFC0D4"))
    preview_frame.add_child(swipe_hint)

    var side_title := Label.new()
    side_title.text = "CHOOSE YOUR CAR"
    side_title.position = Vector2(895, 105)
    side_title.size = Vector2(340, 42)
    side_title.add_theme_font_size_override("font_size", 25)
    side_title.add_theme_color_override("font_color", Color.WHITE)
    add_child(side_title)

    blue_card = _make_car_option("BLUE SUPERCAR", "SUBHOJIT", Color("#1677E8"), 0, 165)
    add_child(blue_card)
    red_card = _make_car_option("RED SPORT SEDAN", "BIRAJ", Color("#D83232"), 1, 365)
    add_child(red_card)

    selected_label = Label.new()
    selected_label.position = Vector2(895, 575)
    selected_label.size = Vector2(340, 34)
    selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    selected_label.add_theme_font_size_override("font_size", 18)
    selected_label.add_theme_color_override("font_color", Color("#FF7518"))
    add_child(selected_label)
    _refresh_selection()

    var back := Button.new()
    back.text = "‹  BACK"
    back.position = Vector2(42, 660)
    back.size = Vector2(170, 46)
    _style_button(back, false)
    back.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/main_menu.tscn"))
    add_child(back)

    var play := Button.new()
    play.text = "START RACE  ›"
    play.position = Vector2(1030, 650)
    play.size = Vector2(205, 54)
    _style_button(play, true)
    play.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/race.tscn"))
    add_child(play)

func _make_car_option(heading: String, decal: String, paint: Color, car_id: int, y: float) -> Panel:
    var card := Panel.new()
    card.position = Vector2(890, y)
    card.size = Vector2(350, 185)
    card.set_meta("car_id", car_id)
    card.add_theme_stylebox_override("panel", _panel_style(Color("#17263A"), car_id == GameState.selected_car))

    var name := Label.new()
    name.text = heading
    name.position = Vector2(16, 12)
    name.size = Vector2(318, 32)
    name.add_theme_font_size_override("font_size", 19)
    name.add_theme_color_override("font_color", paint.lightened(0.35))
    card.add_child(name)

    var swatch := ColorRect.new()
    swatch.color = paint
    swatch.position = Vector2(18, 58)
    swatch.size = Vector2(8, 68)
    card.add_child(swatch)

    var model_name := Label.new()
    model_name.text = decal
    model_name.position = Vector2(38, 62)
    model_name.size = Vector2(290, 30)
    model_name.add_theme_font_size_override("font_size", 26)
    model_name.add_theme_color_override("font_color", Color.WHITE)
    card.add_child(model_name)

    var desc := Label.new()
    desc.text = "SPORTS CAR  •  360° PREVIEW"
    desc.position = Vector2(38, 96)
    desc.size = Vector2(290, 24)
    desc.add_theme_font_size_override("font_size", 13)
    desc.add_theme_color_override("font_color", Color("#AFC0D4"))
    card.add_child(desc)

    var choose := Button.new()
    choose.text = "SELECTED" if car_id == GameState.selected_car else "SELECT CAR"
    choose.position = Vector2(18, 137)
    choose.size = Vector2(314, 38)
    _style_button(choose, car_id == GameState.selected_car)
    choose.pressed.connect(func():
        GameState.selected_car = car_id
        _show_selected_car()
        _refresh_selection()
    )
    card.add_child(choose)
    return card

func _create_preview_car() -> Node3D:
    var root := Node3D.new()
    var paint := Color("#1677E8") if GameState.selected_car == 0 else Color("#D83232")
    _add_box(root, Vector3(0, 0.55, 0), Vector3(2.0, 0.58, 3.8), paint)
    _add_box(root, Vector3(0, 0.99, -0.22), Vector3(1.48, 0.62, 1.8), Color("#172638"))
    _add_box(root, Vector3(0, 0.88, -1.25), Vector3(1.55, 0.10, 1.0), paint.lightened(0.12))
    _add_box(root, Vector3(0, 1.30, -0.18), Vector3(1.30, 0.045, 1.35), Color("#101A27"))
    _add_box(root, Vector3(0, 0.32, 1.92), Vector3(2.12, 0.14, 0.24), Color("#202832"))
    for side in [-1.0, 1.0]:
        _add_box(root, Vector3(side * 1.01, 0.32, 0), Vector3(0.13, 0.18, 2.9), Color("#202832"))
        for z in [-1.18, 1.18]:
            var wheel := MeshInstance3D.new()
            var wheel_mesh := CylinderMesh.new()
            wheel_mesh.top_radius = 0.43
            wheel_mesh.bottom_radius = 0.43
            wheel_mesh.height = 0.24
            wheel.mesh = wheel_mesh
            wheel.rotation_degrees.z = 90
            wheel.position = Vector3(side * 1.02, 0.36, z)
            var rubber := StandardMaterial3D.new()
            rubber.albedo_color = Color("#080C12")
            wheel.material_override = rubber
            root.add_child(wheel)
            _add_box(root, Vector3(side * 1.15, 0.36, z), Vector3(0.035, 0.24, 0.24), Color("#AEB9C3"))
    for x in [-0.68, 0.68]:
        _add_box(root, Vector3(x, 0.62, -1.94), Vector3(0.42, 0.16, 0.07), Color("#FFF1B8"))
        _add_box(root, Vector3(x, 0.62, 1.94), Vector3(0.42, 0.15, 0.07), Color("#E53935"))
    _add_box(root, Vector3(0, 0.65, 1.96), Vector3(1.0, 0.08, 0.06), Color("#FF3344"))
    return root

func _add_box(parent: Node3D, pos: Vector3, dimensions: Vector3, tint: Color) -> void:
    var part := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    part.mesh = mesh
    part.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.42
    mat.roughness = 0.32
    part.material_override = mat
    parent.add_child(part)

func _on_preview_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        drag_active = event.pressed
        last_drag_x = event.position.x
    elif event is InputEventScreenTouch:
        drag_active = event.pressed
        last_drag_x = event.position.x
    elif event is InputEventMouseMotion and drag_active:
        preview_car.rotation.y += (event.position.x - last_drag_x) * 0.012
        last_drag_x = event.position.x
    elif event is InputEventScreenDrag:
        preview_car.rotation.y += event.relative.x * 0.012

func _show_selected_car() -> void:
    if is_instance_valid(preview_car):
        preview_root.remove_child(preview_car)
        preview_car.queue_free()
    preview_car = _create_preview_car()
    preview_root.add_child(preview_car)

func _refresh_selection() -> void:
    selected_label.text = "CURRENT CAR: " + ("SUBHOJIT" if GameState.selected_car == 0 else "BIRAJ")
    _refresh_card(blue_card, 0)
    _refresh_card(red_card, 1)

func _refresh_card(card: Panel, car_id: int) -> void:
    var is_selected := car_id == GameState.selected_car
    card.add_theme_stylebox_override("panel", _panel_style(Color("#17263A"), is_selected))
    for child in card.get_children():
        if child is Button:
            child.text = "SELECTED  ✓" if is_selected else "SELECT CAR"
            _style_button(child, is_selected)

func _panel_style(fill: Color, selected: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = Color("#FF7518") if selected else Color("#34445A")
    style.set_border_width_all(3 if selected else 1)
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    return style

func _style_button(button: Button, active: bool) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#FF7518") if active else Color("#263950")
    normal.corner_radius_top_left = 7
    normal.corner_radius_top_right = 7
    normal.corner_radius_bottom_left = 7
    normal.corner_radius_bottom_right = 7
    button.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate()
    hover.bg_color = Color("#FF8A36") if active else Color("#344B68")
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_color_override("font_color", Color("#FFFFFF"))
    button.add_theme_font_size_override("font_size", 17)
