extends Node3D

var car: Node3D
var speed := 0.0
var distance := 0.0
var steer := 0.0
var nitro_left := 3.0
var road_segments: Array[Node3D] = []
var traffic_cars: Array[Node3D] = []
var ui_layer: CanvasLayer
var speed_label: Label
var distance_label: Label
var best_label: Label
var nitro_label: Label
var touch_left := false
var touch_right := false
var touch_accel := false
var touch_brake := false
var touch_nitro := false
var game_over := false
var game_paused := false
var best_distance := 0.0

func _ready() -> void:
    randomize()
    _load_best_distance()
    _make_world()
    _make_car()
    _make_traffic()
    _make_ui()

func _process(delta: float) -> void:
    if game_over or game_paused:
        return

    var accel := Input.is_action_pressed("ui_up") or touch_accel
    var braking := Input.is_action_pressed("ui_down") or touch_brake
    var left := Input.is_action_pressed("ui_left") or touch_left
    var right := Input.is_action_pressed("ui_right") or touch_right
    var boosting := touch_nitro and nitro_left > 0.0

    if braking:
        speed = move_toward(speed, 0.0, 150.0 * delta)
    elif accel:
        speed = move_toward(speed, 190.0 if boosting else 130.0, 65.0 * delta)
    else:
        speed = move_toward(speed, 55.0, 18.0 * delta)

    if boosting:
        nitro_left = maxf(0.0, nitro_left - delta)
    else:
        # Nitro slowly recharges while the player is not using the boost.
        nitro_left = minf(3.0, nitro_left + delta * 0.22)

    steer = (1.0 if right else 0.0) - (1.0 if left else 0.0)
    car.position.x = clampf(car.position.x + steer * GameState.steering_sensitivity * delta * (3.4 + speed / 55.0), -4.0, 4.0)
    car.rotation.z = lerpf(car.rotation.z, -steer * 0.075, minf(1.0, delta * 5.0))
    distance += speed * delta / 3600.0

    _move_road(delta)
    _move_traffic(delta)
    _check_traffic_collision()

    speed_label.text = "SPEED  %03d km/h" % int(speed)
    distance_label.text = "DISTANCE  %.2f km" % distance
    best_label.text = "BEST  %.2f km" % best_distance
    nitro_label.text = "NITRO  %.1f s" % nitro_left

func _make_world() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("#8CB7D8")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color.WHITE
    env.environment = e
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.2
    add_child(sun)

    for i in range(12):
        var segment := Node3D.new()
        segment.position.z = -float(i) * 22.0
        add_child(segment)
        _build_road_segment(segment)
        road_segments.append(segment)

func _build_road_segment(parent: Node3D) -> void:
    _box(parent, Vector3(0, -0.2, 0), Vector3(12, 0.4, 22), Color("#30343B"))
    _box(parent, Vector3(-6.4, -0.1, 0), Vector3(0.35, 0.2, 22), Color("#E8E8E8"))
    _box(parent, Vector3(6.4, -0.1, 0), Vector3(0.35, 0.2, 22), Color("#E8E8E8"))
    for z in [-7.0, 0.0, 7.0]:
        _box(parent, Vector3(0, 0.025, z), Vector3(0.16, 0.04, 3.0), Color("#F5F5F5"))
    _box(parent, Vector3(-10, -0.35, 0), Vector3(8, 0.2, 22), Color("#39764A"))
    _box(parent, Vector3(10, -0.35, 0), Vector3(8, 0.2, 22), Color("#39764A"))
    _make_tree(parent, Vector3(-9.0, 0.0, -7.0))
    _make_tree(parent, Vector3(9.0, 0.0, 4.0))

func _make_tree(parent: Node3D, tree_position: Vector3) -> void:
    var tree := Node3D.new()
    tree.position = tree_position
    parent.add_child(tree)

    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.16
    trunk_mesh.bottom_radius = 0.23
    trunk_mesh.height = 1.8
    trunk.mesh = trunk_mesh
    var trunk_material := StandardMaterial3D.new()
    trunk_material.albedo_color = Color("#76502E")
    trunk.material_override = trunk_material
    trunk.position.y = 0.9
    tree.add_child(trunk)

    var leaves := MeshInstance3D.new()
    var leaves_mesh := SphereMesh.new()
    leaves_mesh.radius = 0.9
    leaves_mesh.height = 1.8
    leaves.mesh = leaves_mesh
    var leaves_material := StandardMaterial3D.new()
    leaves_material.albedo_color = Color("#236B3A")
    leaves.material_override = leaves_material
    leaves.position.y = 2.2
    tree.add_child(leaves)

func _make_car() -> void:
    car = Node3D.new()
    car.position = Vector3(0, 0.45, 3)
    add_child(car)
    var body_color := Color("#1677E8") if GameState.selected_car == 0 else Color("#D83232")
    _box(car, Vector3(0, 0.45, 0), Vector3(1.8, 0.55, 3.4), body_color)
    _box(car, Vector3(0, 0.9, -0.25), Vector3(1.35, 0.55, 1.55), Color("#17212E"))
    for x in [-0.95, 0.95]:
        for z in [-1.05, 1.05]:
            _box(car, Vector3(x, 0.2, z), Vector3(0.28, 0.55, 0.72), Color("#111111"))

    # Visible headlights and rear lights make the placeholder car easier to read.
    for x in [-0.62, 0.62]:
        _box(car, Vector3(x, 0.49, -1.73), Vector3(0.34, 0.12, 0.06), Color("#FFF1B8"))
        _box(car, Vector3(x, 0.49, 1.73), Vector3(0.34, 0.12, 0.06), Color("#E53935"))

    var brand_text := "SUBHOJIT" if GameState.selected_car == 0 else "BIRAJ"
    _add_car_decal(car, brand_text, Vector3(-0.91, 0.62, 0.0), Vector3(0, 90, 0))
    _add_car_decal(car, brand_text, Vector3(0.91, 0.62, 0.0), Vector3(0, -90, 0))
    _add_car_decal(car, brand_text, Vector3(0, 0.76, -1.12), Vector3(-90, 0, 0))

    var camera := Camera3D.new()
    camera.position = Vector3(0, 5.2, 10.5)
    camera.rotation_degrees = Vector3(-20, 0, 0)
    camera.current = true
    car.add_child(camera)


func _add_car_decal(parent: Node3D, decal_text: String, decal_position: Vector3, decal_rotation: Vector3) -> void:
    var decal := Label3D.new()
    decal.text = decal_text
    decal.position = decal_position
    decal.rotation_degrees = decal_rotation
    decal.font_size = 48
    decal.pixel_size = 0.004
    decal.modulate = Color.WHITE
    decal.outline_size = 8
    decal.no_depth_test = false
    parent.add_child(decal)

func _make_traffic() -> void:
    for i in range(5):
        var traffic := Node3D.new()
        traffic.position = Vector3(_random_lane(), 0.45, -45.0 - float(i) * 42.0)
        add_child(traffic)
        var paint := [Color("#F2C230"), Color("#E84A5F"), Color("#36A889"), Color("#D7DCE2")][i % 4]
        _box(traffic, Vector3(0, 0.45, 0), Vector3(1.8, 0.55, 3.3), paint)
        _box(traffic, Vector3(0, 0.9, -0.2), Vector3(1.3, 0.5, 1.45), Color("#26384A"))
        for wheel_x in [-0.95, 0.95]:
            for wheel_z in [-1.05, 1.05]:
                _box(traffic, Vector3(wheel_x, 0.2, wheel_z), Vector3(0.28, 0.55, 0.68), Color("#101010"))
        for light_x in [-0.62, 0.62]:
            _box(traffic, Vector3(light_x, 0.48, -1.68), Vector3(0.3, 0.12, 0.06), Color("#FFF1B8"))
            _box(traffic, Vector3(light_x, 0.48, 1.68), Vector3(0.3, 0.12, 0.06), Color("#E53935"))
        traffic_cars.append(traffic)

func _random_lane() -> float:
    var lanes := [-3.5, 0.0, 3.5]
    return lanes[randi_range(0, lanes.size() - 1)]

func _move_traffic(delta: float) -> void:
    var movement := speed * delta * 0.12
    for traffic in traffic_cars:
        traffic.position.z += movement
        if traffic.position.z > 16.0:
            traffic.position.z = -190.0 - randf_range(0.0, 65.0)
            traffic.position.x = _random_lane()

func _check_traffic_collision() -> void:
    for traffic in traffic_cars:
        if absf(traffic.position.z - car.position.z) < 2.4 and absf(traffic.position.x - car.position.x) < 1.65:
            _finish_race()
            return


func _show_pause_menu() -> void:
    if game_over or game_paused:
        return
    game_paused = true

    var panel := ColorRect.new()
    panel.name = "PauseOverlay"
    panel.color = Color(0.02, 0.03, 0.05, 0.88)
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_layer.add_child(panel)

    var title := Label.new()
    title.text = "PAUSED"
    title.position = Vector2(0, 190)
    title.size = Vector2(1280, 80)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 58)
    title.add_theme_color_override("font_color", Color("#FF7518"))
    panel.add_child(title)

    var resume := Button.new()
    resume.text = "RESUME"
    resume.position = Vector2(440, 330)
    resume.size = Vector2(190, 65)
    resume.pressed.connect(func():
        game_paused = false
        panel.queue_free()
    )
    panel.add_child(resume)

    var restart := Button.new()
    restart.text = "RESTART"
    restart.position = Vector2(650, 330)
    restart.size = Vector2(190, 65)
    restart.pressed.connect(func(): get_tree().reload_current_scene())
    panel.add_child(restart)

    var menu := Button.new()
    menu.text = "MAIN MENU"
    menu.position = Vector2(545, 420)
    menu.size = Vector2(190, 60)
    menu.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/main_menu.tscn"))
    panel.add_child(menu)

func _finish_race() -> void:
    if game_over:
        return
    game_over = true
    speed = 0.0
    if distance > best_distance:
        best_distance = distance
        _save_best_distance()

    var panel := ColorRect.new()
    panel.color = Color(0.02, 0.03, 0.05, 0.88)
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_layer.add_child(panel)

    var title := Label.new()
    title.text = "GAME OVER"
    title.position = Vector2(0, 190)
    title.size = Vector2(1280, 80)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 58)
    title.add_theme_color_override("font_color", Color("#FF7518"))
    panel.add_child(title)

    var score := Label.new()
    score.text = "DISTANCE: %.2f km     BEST: %.2f km" % [distance, best_distance]
    score.position = Vector2(0, 285)
    score.size = Vector2(1280, 50)
    score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    score.add_theme_font_size_override("font_size", 26)
    score.add_theme_color_override("font_color", Color.WHITE)
    panel.add_child(score)

    var restart := Button.new()
    restart.text = "RESTART"
    restart.position = Vector2(440, 390)
    restart.size = Vector2(190, 65)
    restart.pressed.connect(func(): get_tree().reload_current_scene())
    panel.add_child(restart)

    var menu := Button.new()
    menu.text = "MAIN MENU"
    menu.position = Vector2(650, 390)
    menu.size = Vector2(190, 65)
    menu.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/main_menu.tscn"))
    panel.add_child(menu)

func _load_best_distance() -> void:
    var save := ConfigFile.new()
    if save.load("user://shubir_racing.cfg") == OK:
        best_distance = float(save.get_value("score", "best_distance", 0.0))

func _save_best_distance() -> void:
    var save := ConfigFile.new()
    save.set_value("score", "best_distance", best_distance)
    save.save("user://shubir_racing.cfg")

func _make_ui() -> void:
    ui_layer = CanvasLayer.new()
    add_child(ui_layer)

    speed_label = Label.new()
    speed_label.position = Vector2(25, 20)
    speed_label.add_theme_font_size_override("font_size", 28)
    speed_label.add_theme_color_override("font_color", Color.WHITE)
    ui_layer.add_child(speed_label)

    distance_label = Label.new()
    distance_label.position = Vector2(25, 60)
    distance_label.add_theme_font_size_override("font_size", 22)
    distance_label.add_theme_color_override("font_color", Color.WHITE)
    ui_layer.add_child(distance_label)

    best_label = Label.new()
    best_label.position = Vector2(25, 92)
    best_label.add_theme_font_size_override("font_size", 18)
    best_label.add_theme_color_override("font_color", Color("#FFCCAA"))
    ui_layer.add_child(best_label)

    nitro_label = Label.new()
    nitro_label.position = Vector2(25, 122)
    nitro_label.add_theme_font_size_override("font_size", 18)
    nitro_label.add_theme_color_override("font_color", Color("#70D7FF"))
    ui_layer.add_child(nitro_label)

    _add_hold_button("LEFT", Vector2(25, 560), Vector2(120, 90), "left")
    _add_hold_button("RIGHT", Vector2(155, 560), Vector2(120, 90), "right")
    _add_hold_button("BRAKE", Vector2(295, 560), Vector2(120, 90), "brake")
    _add_hold_button("NITRO", Vector2(1000, 560), Vector2(120, 90), "nitro")
    _add_hold_button("ACCEL", Vector2(1130, 560), Vector2(125, 90), "accel")

    var pause := Button.new()
    pause.text = "PAUSE"
    pause.position = Vector2(1110, 20)
    pause.size = Vector2(140, 48)
    pause.pressed.connect(_show_pause_menu)
    ui_layer.add_child(pause)

func _add_hold_button(label_text: String, pos: Vector2, btn_size: Vector2, action: String) -> void:
    var b := Button.new()
    b.text = label_text
    b.position = pos
    b.size = btn_size
    b.add_theme_font_size_override("font_size", 20)
    b.button_down.connect(func(): _set_touch(action, true))
    b.button_up.connect(func(): _set_touch(action, false))
    ui_layer.add_child(b)

func _set_touch(action: String, value: bool) -> void:
    match action:
        "left": touch_left = value
        "right": touch_right = value
        "brake": touch_brake = value
        "nitro": touch_nitro = value
        "accel": touch_accel = value

func _move_road(delta: float) -> void:
    var movement := speed * delta * 0.12
    for segment in road_segments:
        segment.position.z += movement
        if segment.position.z > 22.0:
            segment.position.z -= 264.0

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    mesh_instance.material_override = material
    mesh_instance.position = pos
    parent.add_child(mesh_instance)
