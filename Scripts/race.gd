extends Node3D

var car: Node3D
var nitro_fx: Node3D
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
var boost_meter_bg: ColorRect
var boost_meter_fill: ColorRect
var brake_button: Button
var boost_button: Button
var accel_button: Button
var pause_button: Button
var touch_accel := false
var touch_brake := false
var touch_nitro := false
var game_over := false
var game_paused := false
var best_distance := 0.0
var engine_player: AudioStreamPlayer
var nitro_player: AudioStreamPlayer
var crash_player: AudioStreamPlayer
var brake_player: AudioStreamPlayer
var was_boosting := false
var boost_locked := false
var was_braking := false
var tilt_center_x := 0.0
var tilt_steer := 0.0

func _ready() -> void:
    randomize()
    _load_best_distance()
    _make_world()
    _make_car()
    _make_traffic()
    _make_ui()
    _make_engine_audio()
    _make_effect_audio()
    # Calibrate the neutral angle when the race starts.
    tilt_center_x = Input.get_accelerometer().y

func _process(delta: float) -> void:
    if game_over or game_paused:
        return

    var accel := Input.is_action_pressed("ui_up") or touch_accel
    var braking := Input.is_action_pressed("ui_down") or touch_brake
    # A brake press or an empty boost tank cancels the current hold.
    # The player must release BOOST before it can activate again.
    if not touch_nitro:
        boost_locked = false
    if braking:
        boost_locked = true
    var boosting := touch_nitro and accel and not braking and not boost_locked and nitro_left > 0.0

    # Landscape phone tilt steering. Ignore tiny sensor movement to prevent drift.
    var accel_reading := Input.get_accelerometer()
    if accel_reading.length() > 1.0:
        var tilt_delta := accel_reading.y - tilt_center_x
        if absf(tilt_delta) < 0.65:
            tilt_delta = 0.0
        tilt_steer = move_toward(tilt_steer, clampf(tilt_delta / 4.0, -1.0, 1.0), delta * 5.0)
    else:
        tilt_steer = move_toward(tilt_steer, 0.0, delta * 4.0)

    if braking:
        speed = move_toward(speed, 0.0, 150.0 * delta)
    elif accel:
        speed = move_toward(speed, 190.0 if boosting else 130.0, 65.0 * delta)
    else:
        speed = move_toward(speed, 55.0, 18.0 * delta)

    if boosting:
        nitro_left = maxf(0.0, nitro_left - delta)
        if not was_boosting and is_instance_valid(nitro_player):
            nitro_player.play()
        if nitro_left <= 0.0:
            boost_locked = true
    else:
        # A fully empty 3-second tank recharges in 5 seconds while BOOST is released.
        nitro_left = minf(3.0, nitro_left + delta * 0.60)
    if braking and not was_braking and is_instance_valid(brake_player):
        brake_player.play()
    was_braking = braking
    was_boosting = boosting
    if is_instance_valid(nitro_fx):
        nitro_fx.visible = boosting
        nitro_fx.scale.z = 0.85 + 0.25 * sin(Time.get_ticks_msec() * 0.035) if boosting else 1.0

    steer = tilt_steer
    car.position.x = clampf(car.position.x + steer * GameState.steering_sensitivity * delta * (3.4 + speed / 55.0), -4.0, 4.0)
    car.rotation.z = lerpf(car.rotation.z, -steer * 0.075, minf(1.0, delta * 5.0))
    distance += speed * delta / 3600.0

    _move_road(delta)
    _move_traffic(delta)
    _check_traffic_collision()

    speed_label.text = "SPEED  %03d km/h" % int(speed)
    distance_label.text = "DISTANCE  %.2f km" % distance
    best_label.text = "BEST  %.2f km" % best_distance
    if boosting:
        nitro_label.text = "BOOST ACTIVE  %.1f s" % nitro_left
        boost_meter_fill.color = Color("#19CFFF")
    elif nitro_left >= 2.99:
        nitro_label.text = "BOOST READY"
        boost_meter_fill.color = Color("#43E38B")
    else:
        nitro_label.text = "BOOST RECHARGING  %d%%" % int((nitro_left / 3.0) * 100.0)
        boost_meter_fill.color = Color("#FFB347")
    boost_meter_fill.size.x = 190.0 * (nitro_left / 3.0)
    if is_instance_valid(engine_player):
        engine_player.pitch_scale = 0.75 + (speed / 190.0) * 0.75


func _make_engine_audio() -> void:
    # Generate a small seamless engine hum locally so the game needs no network audio assets.
    var sample_rate := 16000
    var sample_count := 8000
    var samples := PackedByteArray()
    samples.resize(sample_count * 2)
    for i in range(sample_count):
        var t := float(i) / float(sample_rate)
        var wave := sin(TAU * 72.0 * t) * 0.52 + sin(TAU * 144.0 * t) * 0.20 + sin(TAU * 216.0 * t) * 0.08
        var envelope := 0.72 + 0.12 * sin(TAU * 2.0 * t)
        var sample := int(clampf(wave * envelope, -1.0, 1.0) * 5200.0)
        samples.encode_s16(i * 2, sample)

    var engine_stream := AudioStreamWAV.new()
    engine_stream.format = AudioStreamWAV.FORMAT_16_BITS
    engine_stream.mix_rate = sample_rate
    engine_stream.stereo = false
    engine_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    engine_stream.loop_begin = 0
    engine_stream.loop_end = sample_count
    engine_stream.data = samples

    engine_player = AudioStreamPlayer.new()
    engine_player.stream = engine_stream
    engine_player.volume_db = -5.0
    add_child(engine_player)
    engine_player.play()


func _make_effect_audio() -> void:
    nitro_player = AudioStreamPlayer.new()
    nitro_player.stream = _create_effect_stream(true)
    nitro_player.volume_db = -3.0
    add_child(nitro_player)

    crash_player = AudioStreamPlayer.new()
    crash_player.stream = _create_effect_stream(false)
    crash_player.volume_db = -1.0
    add_child(crash_player)

    brake_player = AudioStreamPlayer.new()
    brake_player.stream = _create_brake_stream()
    brake_player.volume_db = -7.0
    add_child(brake_player)

func _create_brake_stream() -> AudioStreamWAV:
    var sample_rate := 16000
    var sample_count := 5600
    var samples := PackedByteArray()
    samples.resize(sample_count * 2)
    for i in range(sample_count):
        var t := float(i) / float(sample_rate)
        var progress := float(i) / float(sample_count)
        var frequency := lerpf(620.0, 210.0, progress)
        var envelope := sin(PI * progress) * (1.0 - progress * 0.35)
        var wave := (sin(TAU * frequency * t) * 0.58 + sin(TAU * frequency * 2.03 * t) * 0.18) * envelope
        var sample := int(clampf(wave, -1.0, 1.0) * 7200.0)
        samples.encode_s16(i * 2, sample)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = samples
    return stream

func _create_effect_stream(is_nitro: bool) -> AudioStreamWAV:
    var sample_rate := 16000
    var sample_count := 8000
    var samples := PackedByteArray()
    samples.resize(sample_count * 2)
    var noise_state := 13579 if is_nitro else 24681
    for i in range(sample_count):
        var t := float(i) / float(sample_rate)
        var progress := float(i) / float(sample_count)
        var wave: float
        if is_nitro:
            var frequency := lerpf(260.0, 1050.0, progress)
            wave = sin(TAU * frequency * t) * (1.0 - progress) * 0.55
            wave += sin(TAU * frequency * 1.7 * t) * (1.0 - progress) * 0.16
        else:
            noise_state = int((noise_state * 1103515245 + 12345) & 0x7fffffff)
            var noise := (float(noise_state) / 1073741823.5) - 1.0
            wave = noise * exp(-progress * 8.0) * 0.72
            wave += sin(TAU * 68.0 * t) * exp(-progress * 12.0) * 0.3
        var sample := int(clampf(wave, -1.0, 1.0) * 10000.0)
        samples.encode_s16(i * 2, sample)

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = samples
    return stream

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

    # Continuous metallic highway guardrails with repeating support posts.
    for side in [-1.0, 1.0]:
        _box(parent, Vector3(side * 6.9, 0.62, 0), Vector3(0.16, 0.22, 22), Color("#AEB8C2"))
        for post_z in [-9.0, -3.0, 3.0, 9.0]:
            _box(parent, Vector3(side * 6.9, 0.22, post_z), Vector3(0.22, 0.48, 0.22), Color("#737E88"))
        for marker_z in [-8.0, 0.0, 8.0]:
            _box(parent, Vector3(side * 6.78, 0.72, marker_z), Vector3(0.035, 0.12, 0.72), Color("#FF7518"))

    # Bright shoulder edge strips improve lane readability at speed.
    _box(parent, Vector3(-6.05, 0.025, 0), Vector3(0.10, 0.035, 22), Color("#FFCF55"))
    _box(parent, Vector3(6.05, 0.025, 0), Vector3(0.10, 0.035, 22), Color("#FFCF55"))
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

    # Sport-car body details: hood, roof glass, side skirts and front splitter.
    _box(car, Vector3(0, 0.735, -1.05), Vector3(1.42, 0.045, 1.05), body_color.lightened(0.10))
    _box(car, Vector3(0, 1.185, -0.22), Vector3(1.18, 0.035, 1.12), Color("#101A27"))
    _box(car, Vector3(0, 0.22, -1.78), Vector3(1.95, 0.12, 0.22), Color("#202832"))
    for side in [-1.0, 1.0]:
        _box(car, Vector3(side * 0.91, 0.28, 0.05), Vector3(0.12, 0.18, 2.55), Color("#252B33"))
        _box(car, Vector3(side * 0.98, 0.93, -0.65), Vector3(0.30, 0.12, 0.22), Color("#171D25"))
        _box(car, Vector3(side * 1.08, 1.02, -0.65), Vector3(0.24, 0.10, 0.32), Color("#111820"))

    for x in [-0.95, 0.95]:
        for z in [-1.05, 1.05]:
            _box(car, Vector3(x, 0.2, z), Vector3(0.28, 0.55, 0.72), Color("#111111"))
            _box(car, Vector3(x * 1.012, 0.2, z), Vector3(0.035, 0.30, 0.34), Color("#B7C0C8"))

    # Raised rear wing and supports, visible above the trunk from the chase camera.
    for wing_x in [-0.62, 0.62]:
        _box(car, Vector3(wing_x, 1.02, 1.28), Vector3(0.08, 0.48, 0.10), Color("#252B33"))
    _box(car, Vector3(0, 1.28, 1.30), Vector3(2.0, 0.12, 0.42), Color("#171D25"))

    # Visible headlights and full-width rear light strip.
    for x in [-0.62, 0.62]:
        _box(car, Vector3(x, 0.49, -1.73), Vector3(0.40, 0.14, 0.07), Color("#FFF1B8"))
        _box(car, Vector3(x, 0.49, 1.73), Vector3(0.38, 0.14, 0.07), Color("#E53935"))
    _box(car, Vector3(0, 0.49, 1.75), Vector3(0.72, 0.07, 0.06), Color("#FF3344"))

    var brand_text := "SUBHOJIT" if GameState.selected_car == 0 else "BIRAJ"
    _add_car_decal(car, brand_text, Vector3(-0.91, 0.62, 0.0), Vector3(0, 90, 0))
    _add_car_decal(car, brand_text, Vector3(0.91, 0.62, 0.0), Vector3(0, -90, 0))
    _add_car_decal(car, brand_text, Vector3(0, 0.76, -1.12), Vector3(-90, 0, 0))

    var camera := Camera3D.new()
    camera.position = Vector3(0, 5.2, 10.5)
    camera.rotation_degrees = Vector3(-20, 0, 0)
    camera.current = true
    car.add_child(camera)

    # Twin metallic silencer outlets; Nitro flames emerge directly from their tips.
    for exhaust_x in [-0.48, 0.48]:
        var exhaust := MeshInstance3D.new()
        var exhaust_mesh := CylinderMesh.new()
        exhaust_mesh.top_radius = 0.13
        exhaust_mesh.bottom_radius = 0.16
        exhaust_mesh.height = 0.42
        exhaust.mesh = exhaust_mesh
        exhaust.rotation_degrees.x = 90
        exhaust.position = Vector3(exhaust_x, 0.30, 1.82)
        var exhaust_material := StandardMaterial3D.new()
        exhaust_material.albedo_color = Color("#AEB9C3")
        exhaust_material.metallic = 0.82
        exhaust_material.roughness = 0.24
        exhaust.material_override = exhaust_material
        car.add_child(exhaust)
        var exhaust_inner := MeshInstance3D.new()
        var inner_mesh := CylinderMesh.new()
        inner_mesh.top_radius = 0.075
        inner_mesh.bottom_radius = 0.075
        inner_mesh.height = 0.025
        exhaust_inner.mesh = inner_mesh
        exhaust_inner.rotation_degrees.x = 90
        exhaust_inner.position = Vector3(exhaust_x, 0.30, 2.035)
        var inner_material := StandardMaterial3D.new()
        inner_material.albedo_color = Color("#101820")
        exhaust_inner.material_override = inner_material
        car.add_child(exhaust_inner)

    # Twin blue Boost flames originate at the silencer outlets, not underneath the car.
    nitro_fx = Node3D.new()
    nitro_fx.position = Vector3(0, 0.30, 2.045)
    nitro_fx.visible = false
    car.add_child(nitro_fx)
    for flame_x in [-0.48, 0.48]:
        var flame := MeshInstance3D.new()
        var flame_mesh := CylinderMesh.new()
        flame_mesh.top_radius = 0.025
        flame_mesh.bottom_radius = 0.19
        flame_mesh.height = 0.82
        flame.mesh = flame_mesh
        flame.rotation_degrees.x = 90
        flame.position = Vector3(flame_x, 0.0, 0.34)
        var flame_material := StandardMaterial3D.new()
        flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        flame_material.albedo_color = Color("#36CFFF")
        flame_material.emission_enabled = true
        flame_material.emission = Color("#168DFF")
        flame_material.emission_energy_multiplier = 2.2
        flame.material_override = flame_material
        nitro_fx.add_child(flame)


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
        var paints := [Color("#F2C230"), Color("#E84A5F"), Color("#36A889"), Color("#D7DCE2")]
        var paint: Color = paints[i % paints.size()]

        # Sculpted-looking traffic body, cabin glass and front/rear bumpers.
        _box(traffic, Vector3(0, 0.45, 0), Vector3(1.82, 0.56, 3.35), paint)
        _box(traffic, Vector3(0, 0.79, -0.15), Vector3(1.48, 0.12, 2.25), paint.darkened(0.10))
        _box(traffic, Vector3(0, 0.94, -0.18), Vector3(1.34, 0.48, 1.52), Color("#172B3D"))
        _box(traffic, Vector3(0, 1.18, -0.18), Vector3(1.12, 0.035, 1.30), Color("#263F55"))
        _box(traffic, Vector3(0, 0.30, -1.72), Vector3(1.72, 0.20, 0.16), Color("#343A42"))
        _box(traffic, Vector3(0, 0.30, 1.72), Vector3(1.72, 0.20, 0.16), Color("#343A42"))

        # Side windows and subtle body-color accent strips.
        for side in [-1.0, 1.0]:
            _box(traffic, Vector3(side * 0.76, 0.92, -0.18), Vector3(0.035, 0.28, 1.18), Color("#9CC9E2"))
            _box(traffic, Vector3(side * 0.916, 0.55, 0.0), Vector3(0.025, 0.10, 1.65), paint.lightened(0.22))

        for wheel_x in [-0.96, 0.96]:
            for wheel_z in [-1.05, 1.05]:
                _box(traffic, Vector3(wheel_x, 0.2, wheel_z), Vector3(0.28, 0.55, 0.68), Color("#101010"))
                _box(traffic, Vector3(wheel_x * 1.012, 0.2, wheel_z), Vector3(0.035, 0.27, 0.30), Color("#AEB7C0"))

        for light_x in [-0.62, 0.62]:
            _box(traffic, Vector3(light_x, 0.49, -1.70), Vector3(0.34, 0.14, 0.07), Color("#FFF1B8"))
            _box(traffic, Vector3(light_x, 0.49, 1.70), Vector3(0.34, 0.14, 0.07), Color("#F32938"))
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
    if is_instance_valid(engine_player):
        engine_player.stream_paused = true
    if is_instance_valid(nitro_player):
        nitro_player.stream_paused = true
    if is_instance_valid(brake_player):
        brake_player.stream_paused = true

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
        if is_instance_valid(engine_player):
            engine_player.stream_paused = false
        if is_instance_valid(nitro_player):
            nitro_player.stream_paused = false
        if is_instance_valid(brake_player):
            brake_player.stream_paused = false
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
    if is_instance_valid(engine_player):
        engine_player.stop()
    if is_instance_valid(nitro_player):
        nitro_player.stop()
    if is_instance_valid(brake_player):
        brake_player.stop()
    if is_instance_valid(crash_player):
        crash_player.play()
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

    boost_meter_bg = ColorRect.new()
    boost_meter_bg.color = Color("#243746")
    boost_meter_bg.size = Vector2(190, 12)
    ui_layer.add_child(boost_meter_bg)
    boost_meter_fill = ColorRect.new()
    boost_meter_fill.color = Color("#19CFFF")
    boost_meter_fill.size = Vector2(190, 12)
    boost_meter_bg.add_child(boost_meter_fill)

    # Landscape controls are repositioned for the actual phone viewport.
    brake_button = _add_hold_button("BRAKE", Vector2(35, 535), Vector2(155, 145), "brake")
    boost_button = _add_hold_button("BOOST", Vector2(1100, 405), Vector2(145, 105), "nitro")
    accel_button = _add_hold_button("ACCELERATOR", Vector2(1070, 535), Vector2(180, 145), "accel")

    pause_button = Button.new()
    pause_button.text = "PAUSE"
    pause_button.size = Vector2(140, 48)
    pause_button.pressed.connect(_show_pause_menu)
    ui_layer.add_child(pause_button)
    get_viewport().size_changed.connect(_layout_race_ui)
    _layout_race_ui()

func _add_hold_button(label_text: String, pos: Vector2, btn_size: Vector2, action: String) -> Button:
    var b := Button.new()
    b.text = label_text
    b.position = pos
    b.size = btn_size
    b.add_theme_font_size_override("font_size", 19 if action != "nitro" else 18)
    var label_color := Color("#D83B35") if action == "brake" else (Color("#21B65B") if action == "accel" else Color.WHITE)
    b.add_theme_color_override("font_color", label_color)
    b.add_theme_color_override("font_hover_color", label_color.lightened(0.18))
    b.add_theme_color_override("font_pressed_color", Color.WHITE)
    b.focus_mode = Control.FOCUS_NONE

    var base_style := StyleBoxFlat.new()
    if action == "nitro":
        base_style.bg_color = Color("#102B3C")
        base_style.border_color = Color("#19CFFF")
        base_style.set_border_width_all(4)
        base_style.set_corner_radius_all(22)
        base_style.content_margin_top = 10.0
        base_style.content_margin_bottom = 10.0
    else:
        # Brushed-metal pedal plate with a dark raised rim.
        base_style.bg_color = Color("#B9C2CA")
        base_style.border_color = Color("#59636D")
        base_style.set_border_width_all(5)
        base_style.set_corner_radius_all(7)
        base_style.shadow_color = Color(0, 0, 0, 0.62)
        base_style.shadow_size = 9
        base_style.content_margin_left = 8.0
        base_style.content_margin_right = 8.0
        base_style.content_margin_top = 82.0
        base_style.content_margin_bottom = 8.0
    b.add_theme_stylebox_override("normal", base_style)

    if action != "nitro":
        # Five dark rubber grip ribs and small metal fasteners create a pedal-like face.
        for rib_index in range(5):
            var rib := ColorRect.new()
            rib.position = Vector2(20, 16 + rib_index * 12)
            rib.size = Vector2(btn_size.x - 40, 5)
            rib.color = Color("#303840")
            rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
            b.add_child(rib)
        for screw_pos in [Vector2(12, 10), Vector2(btn_size.x - 20, 10), Vector2(12, 62), Vector2(btn_size.x - 20, 62)]:
            var screw := ColorRect.new()
            screw.position = screw_pos
            screw.size = Vector2(7, 7)
            screw.color = Color("#E7EDF1")
            screw.mouse_filter = Control.MOUSE_FILTER_IGNORE
            b.add_child(screw)

    var hover_style := base_style.duplicate() as StyleBoxFlat
    hover_style.bg_color = hover_style.bg_color.lightened(0.12)
    b.add_theme_stylebox_override("hover", hover_style)
    var pressed_style := base_style.duplicate() as StyleBoxFlat
    pressed_style.bg_color = pressed_style.bg_color.darkened(0.18)
    b.add_theme_stylebox_override("pressed", pressed_style)
    b.button_down.connect(func(): _set_touch(action, true))
    b.button_up.connect(func(): _set_touch(action, false))
    ui_layer.add_child(b)
    return b

func _layout_race_ui() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    var scale_factor := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
    scale_factor = clampf(scale_factor, 0.55, 1.15)
    var w := viewport_size.x
    var h := viewport_size.y

    speed_label.position = Vector2(22, 16) * scale_factor
    distance_label.position = Vector2(22, 54) * scale_factor
    best_label.position = Vector2(22, 86) * scale_factor
    nitro_label.position = Vector2(22, 116) * scale_factor
    boost_meter_bg.position = Vector2(22, 145) * scale_factor
    boost_meter_bg.scale = Vector2.ONE * scale_factor
    for label in [speed_label, distance_label, best_label, nitro_label]:
        label.scale = Vector2.ONE * scale_factor

    brake_button.scale = Vector2.ONE * scale_factor
    brake_button.position = Vector2(28.0 * scale_factor, h - 172.0 * scale_factor)
    boost_button.scale = Vector2.ONE * scale_factor
    boost_button.position = Vector2(w - 176.0 * scale_factor, h - 292.0 * scale_factor)
    accel_button.scale = Vector2.ONE * scale_factor
    accel_button.position = Vector2(w - 210.0 * scale_factor, h - 172.0 * scale_factor)
    pause_button.scale = Vector2.ONE * scale_factor
    pause_button.position = Vector2(w - 158.0 * scale_factor, 16.0 * scale_factor)

func _set_touch(action: String, value: bool) -> void:
    match action:
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
