extends Node3D

var car: Node3D
var speed := 0.0
var distance := 0.0
var steer := 0.0
var nitro_left := 3.0
var road_segments: Array[Node3D] = []
var ui_layer: CanvasLayer
var speed_label: Label
var distance_label: Label
var touch_left := false
var touch_right := false
var touch_accel := false
var touch_brake := false
var touch_nitro := false

func _ready() -> void:
    _make_world()
    _make_car()
    _make_ui()

func _process(delta: float) -> void:
    var accel := Input.is_action_pressed("ui_up") or touch_accel
    var braking := Input.is_action_pressed("ui_down") or touch_brake
    var left := Input.is_action_pressed("ui_left") or touch_left
    var right := Input.is_action_pressed("ui_right") or touch_right
    var boosting := touch_nitro and nitro_left > 0.0

    if accel:
        speed = move_toward(speed, 190.0 if boosting else 130.0, 65.0 * delta)
    elif braking:
        speed = move_toward(speed, 0.0, 150.0 * delta)
    else:
        speed = move_toward(speed, 55.0, 18.0 * delta)

    if boosting:
        nitro_left = maxf(0.0, nitro_left - delta)

    steer = (1.0 if right else 0.0) - (1.0 if left else 0.0)
    car.position.x = clampf(car.position.x + steer * delta * (3.4 + speed / 55.0), -4.0, 4.0)
    distance += speed * delta / 3600.0
    _move_road(delta)
    speed_label.text = "SPEED  %03d km/h" % int(speed)
    distance_label.text = "DISTANCE  %.2f km" % distance

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
    var camera := Camera3D.new()
    camera.position = Vector3(0, 5.2, 10.5)
    camera.rotation_degrees = Vector3(-20, 0, 0)
    camera.current = true
    car.add_child(camera)

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

    _add_hold_button("LEFT", Vector2(25, 560), Vector2(120, 90), "left")
    _add_hold_button("RIGHT", Vector2(155, 560), Vector2(120, 90), "right")
    _add_hold_button("BRAKE", Vector2(295, 560), Vector2(120, 90), "brake")
    _add_hold_button("NITRO", Vector2(1000, 560), Vector2(120, 90), "nitro")
    _add_hold_button("ACCEL", Vector2(1130, 560), Vector2(125, 90), "accel")

    var menu := Button.new()
    menu.text = "MENU"
    menu.position = Vector2(1110, 20)
    menu.size = Vector2(140, 48)
    menu.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/main_menu.tscn"))
    ui_layer.add_child(menu)

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
