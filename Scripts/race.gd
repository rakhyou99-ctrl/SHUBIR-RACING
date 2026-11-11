extends Node3D

var car: Node3D
var nitro_fx: Node3D
var speed := 0.0
var distance := 0.0
var bonus_score := 0
var near_miss_bonus_score := 0
var stage_bonus_score := 0
var score_label: Label
var near_miss_total_label: Label
var steer := 0.0
var nitro_left := 3.0
var road_segments: Array[Node3D] = []
var traffic_cars: Array[Node3D] = []
var road_obstacles: Array[Node3D] = []
var ui_layer: CanvasLayer
var speed_label: Label
var car_identity_label: Label
var distance_label: Label
var best_label: Label
var race_stage_label: Label
var race_stage := 1
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
var touch_points: Dictionary = {}
var game_over := false
var game_paused := false
var best_distance := 0.0
var best_score := 0
var engine_player: AudioStreamPlayer
var nitro_player: AudioStreamPlayer
var crash_player: AudioStreamPlayer
var brake_player: AudioStreamPlayer
var near_miss_player: AudioStreamPlayer
var chase_camera: Camera3D
var brake_lights: Array[MeshInstance3D] = []
var near_miss_label: Label
var near_miss_count := 0
var near_miss_feedback_timer := 0.0
var near_miss_tween: Tween
var stage_feedback_label: Label
var stage_feedback_tween: Tween
var was_boosting := false
var boost_locked := false
var was_braking := false
var tilt_center_x := 0.0
var tilt_filtered_x := 0.0
var tilt_steer := 0.0
var tilt_calibrated := false

func _notification(what: int) -> void:
    # Android Back is delivered as a window notification on mobile.
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and not game_over and not game_paused:
        _show_pause_menu()
    # Freeze the race and require an explicit RESUME after Android backgrounds the app.
    elif what == NOTIFICATION_APPLICATION_PAUSED and not game_over and not game_paused:
        _show_pause_menu()


func _input(event: InputEvent) -> void:
    # Ignore raw gameplay touches while an overlay is active. This prevents a
    # pause-menu tap from being carried into the race as a held pedal/BOOST.
    if game_paused or game_over:
        touch_points.clear()
        return
    # Track raw touch indices so accelerator + BOOST can be held with two fingers.
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_points[event.index] = event.position
        else:
            touch_points.erase(event.index)
        _refresh_multitouch_controls()
    elif event is InputEventScreenDrag:
        touch_points[event.index] = event.position
        _refresh_multitouch_controls()


func _refresh_multitouch_controls() -> void:
    if not is_instance_valid(accel_button) or not is_instance_valid(brake_button) or not is_instance_valid(boost_button):
        touch_accel = false
        touch_brake = false
        touch_nitro = false
        return
    if touch_points.is_empty():
        touch_accel = false
        touch_brake = false
        touch_nitro = false
        return
    var accel_held := false
    var brake_held := false
    var boost_held := false
    for point in touch_points.values():
        if accel_button.get_global_rect().has_point(point):
            accel_held = true
        if brake_button.get_global_rect().has_point(point):
            brake_held = true
        if boost_button.get_global_rect().has_point(point):
            boost_held = true
    touch_accel = accel_held
    touch_brake = brake_held
    touch_nitro = boost_held


func _ready() -> void:
    randomize()
    _load_best_distance()
    _make_world()
    _make_car()
    _make_traffic()
    _make_obstacles()
    _make_ui()
    _make_engine_audio()
    _make_effect_audio()
    # Wait for a valid live sensor sample before calibrating neutral tilt.
    tilt_calibrated = false

func _process(delta: float) -> void:
    if game_over or game_paused:
        return
    if not touch_points.is_empty():
        _refresh_multitouch_controls()
    if near_miss_feedback_timer > 0.0:
        near_miss_feedback_timer = maxf(0.0, near_miss_feedback_timer - delta)
        if near_miss_feedback_timer <= 0.0 and is_instance_valid(near_miss_label):
            near_miss_label.visible = false
    # Keyboard ESC / Android Back (when mapped to ui_cancel) opens the pause menu.
    if Input.is_action_just_pressed("ui_cancel"):
        _show_pause_menu()
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
    if accel_reading.length() > 6.0:
        if not tilt_calibrated:
            tilt_center_x = accel_reading.y
            tilt_filtered_x = accel_reading.y
            tilt_calibrated = true
        # Low-pass filter reduces sensor jitter before converting tilt to steering.
        tilt_filtered_x = lerpf(tilt_filtered_x, accel_reading.y, minf(1.0, delta * 10.0))
        var tilt_delta := tilt_filtered_x - tilt_center_x
        # A small dead zone prevents unwanted lane drift while held nearly level.
        if absf(tilt_delta) < 0.75:
            tilt_delta = 0.0
        var target_tilt := clampf(tilt_delta / 3.5, -1.0, 1.0)
        tilt_steer = move_toward(tilt_steer, target_tilt, delta * 4.5)
    else:
        tilt_steer = move_toward(tilt_steer, 0.0, delta * 3.5)

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
    # Rear brake lamps brighten while the brake pedal is held.
    for brake_light in brake_lights:
        if is_instance_valid(brake_light) and brake_light.material_override is StandardMaterial3D:
            var brake_material := brake_light.material_override as StandardMaterial3D
            brake_material.emission_energy_multiplier = 2.8 if braking else 1.0
            brake_material.albedo_color = Color("#FF1728") if braking else Color("#E53935")
            brake_material.emission = Color("#FF1728") if braking else Color("#E53935")
    was_braking = braking
    was_boosting = boosting
    if is_instance_valid(nitro_fx):
        nitro_fx.visible = boosting
        nitro_fx.scale.z = 0.85 + 0.25 * sin(Time.get_ticks_msec() * 0.035) if boosting else 1.0

    steer = tilt_steer
    car.position.x = clampf(car.position.x + steer * GameState.steering_sensitivity * delta * (3.4 + speed / 55.0), -4.0, 4.0)
    car.rotation.z = lerpf(car.rotation.z, -steer * 0.075, minf(1.0, delta * 5.0))
    distance += speed * delta / 3600.0
    var next_stage := clampi(1 + int(distance / 0.5), 1, 10)
    if next_stage > race_stage:
        var stages_gained := next_stage - race_stage
        race_stage = next_stage
        bonus_score += stages_gained * 500
        stage_bonus_score += stages_gained * 500
        _show_stage_feedback(stages_gained)
    else:
        race_stage = next_stage

    _move_road(delta)
    _move_traffic(delta)
    _move_obstacles(delta)
    _check_traffic_collision()
    if game_over:
        return
    _check_obstacle_collision()
    if game_over:
        return

    score_label.text = "SCORE  %06d" % int(distance * 1000.0 + bonus_score)
    near_miss_total_label.text = "NEAR MISSES  %02d  •  TOTAL BONUS  +%d" % [near_miss_count, bonus_score]
    speed_label.text = "SPEED  %03d km/h" % int(speed)
    distance_label.text = "DISTANCE  %.2f km" % distance
    best_label.text = "BEST  %.2f km  •  %06d" % [best_distance, best_score]
    race_stage_label.text = "STAGE  %02d" % race_stage
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
    var speed_ratio := clampf(speed / 190.0, 0.0, 1.0)
    # Engine tone and loudness rise naturally with road speed and Boost.
    if is_instance_valid(engine_player):
        engine_player.pitch_scale = 0.72 + speed_ratio * 0.82 + (0.08 if boosting else 0.0)
        engine_player.volume_db = lerpf(-16.0, -4.5, speed_ratio) + (1.0 if boosting else 0.0)

    # Smooth chase-camera response: widen the view and pull back slightly at speed.
    if is_instance_valid(chase_camera):
        chase_camera.fov = lerpf(chase_camera.fov, 70.0 + speed_ratio * 12.0, minf(1.0, delta * 2.4))
        chase_camera.position.y = lerpf(chase_camera.position.y, 5.2 + speed_ratio * 0.45, minf(1.0, delta * 2.0))
        chase_camera.position.z = lerpf(chase_camera.position.z, 10.5 + speed_ratio * 1.15, minf(1.0, delta * 2.0))
        chase_camera.rotation_degrees.z = lerpf(chase_camera.rotation_degrees.z, -steer * 1.4, minf(1.0, delta * 3.0))


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

    near_miss_player = AudioStreamPlayer.new()
    near_miss_player.stream = _create_near_miss_stream()
    near_miss_player.volume_db = -8.0
    add_child(near_miss_player)

func _create_near_miss_stream() -> AudioStreamWAV:
    # A short, soft two-note reward chime keeps near-miss feedback distinct from Boost and crash audio.
    var sample_rate := 16000
    var sample_count := 4800
    var samples := PackedByteArray()
    samples.resize(sample_count * 2)
    for i in range(sample_count):
        var progress := float(i) / float(sample_count)
        var t := float(i) / float(sample_rate)
        var frequency := 880.0 if progress < 0.48 else 1174.0
        var envelope := sin(PI * progress) * (1.0 - progress * 0.22)
        var wave := sin(TAU * frequency * t) * 0.62
        wave += sin(TAU * frequency * 2.0 * t) * 0.12
        var sample := int(clampf(wave * envelope, -1.0, 1.0) * 6800.0)
        samples.encode_s16(i * 2, sample)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = samples
    return stream

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
    # Dashed lane dividers mark three clear driving lanes.
    for lane_edge_x in [-2.0, 2.0]:
        for z in [-7.0, 0.0, 7.0]:
            _box(parent, Vector3(lane_edge_x, 0.025, z), Vector3(0.13, 0.04, 3.0), Color("#F5F5F5"))
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
    # Short orange rumble strips add a visual edge cue without narrowing the road.
    for side in [-1.0, 1.0]:
        for rumble_z in [-8.0, 3.0]:
            _box(parent, Vector3(side * 5.82, 0.035, rumble_z), Vector3(0.22, 0.06, 2.2), Color("#D9A33A"))
    _box(parent, Vector3(-6.05, 0.025, 0), Vector3(0.10, 0.035, 22), Color("#FFCF55"))
    _box(parent, Vector3(6.05, 0.025, 0), Vector3(0.10, 0.035, 22), Color("#FFCF55"))
    # More varied roadside scenery makes the endless highway feel less repetitive.
    _make_tree(parent, Vector3(-9.0, 0.0, -7.0))
    _make_tree(parent, Vector3(9.0, 0.0, 4.0))
    _make_tree(parent, Vector3(-10.0, 0.0, 7.0))
    _make_tree(parent, Vector3(10.0, 0.0, -8.0))
    _make_bush(parent, Vector3(-7.9, 0.0, 2.0), Color("#2D8245"))
    _make_bush(parent, Vector3(8.0, 0.0, -3.0), Color("#347D3E"))
    _make_bush(parent, Vector3(-8.1, 0.0, -10.0), Color("#286F3A"))
    _make_bush(parent, Vector3(8.2, 0.0, 9.0), Color("#3A914B"))

    # Occasional roadside speed boards; alternate sides to create a believable highway rhythm.
    var segment_index := int(round(absf(parent.position.z) / 22.0))
    if segment_index % 3 == 0:
        var sign_side := -1.0 if segment_index % 2 == 0 else 1.0
        _box(parent, Vector3(sign_side * 9.15, 1.95, 5.5), Vector3(0.14, 1.25, 1.55), Color("#12243A"))
        _box(parent, Vector3(sign_side * 9.23, 2.48, 5.5), Vector3(0.035, 0.10, 1.42), Color("#FF7518"))
        var speed_sign := Label3D.new()
        speed_sign.text = "80\nKM/H"
        speed_sign.position = Vector3(sign_side * 9.24, 1.94, 5.5)
        speed_sign.rotation_degrees.y = -sign_side * 90.0
        speed_sign.font_size = 42
        speed_sign.pixel_size = 0.012
        speed_sign.modulate = Color.WHITE
        speed_sign.outline_size = 8
        parent.add_child(speed_sign)

    # Large overhead highway gantry appears periodically as a distant landmark.
    if segment_index % 9 == 0:
        for gantry_side in [-1.0, 1.0]:
            _box(parent, Vector3(gantry_side * 5.72, 3.0, -9.0), Vector3(0.18, 6.0, 0.22), Color("#68737D"))
        _box(parent, Vector3(0, 5.85, -9.0), Vector3(11.6, 0.24, 0.30), Color("#AEB8C2"))
        _box(parent, Vector3(0, 5.55, -9.0), Vector3(5.8, 0.72, 0.16), Color("#12243A"))
        _box(parent, Vector3(0, 5.94, -9.0), Vector3(5.8, 0.08, 0.19), Color("#FF7518"))
        var gantry_label := Label3D.new()
        gantry_label.text = "SHUBIR  •  DRIVE SAFE"
        gantry_label.position = Vector3(0, 5.54, -8.88)
        gantry_label.font_size = 34
        gantry_label.pixel_size = 0.012
        gantry_label.modulate = Color.WHITE
        gantry_label.outline_size = 7
        parent.add_child(gantry_label)

    # Tall reflective roadside lamps, repeated with each road segment.
    for lamp_side in [-1.0, 1.0]:
        var lamp := Node3D.new()
        lamp.position = Vector3(lamp_side * 8.1, 0.0, -5.0)
        parent.add_child(lamp)
        _box(lamp, Vector3(0, 2.5, 0), Vector3(0.12, 5.0, 0.12), Color("#68737D"))
        _box(lamp, Vector3(-lamp_side * 0.48, 4.9, 0), Vector3(1.05, 0.10, 0.12), Color("#68737D"))
        _box(lamp, Vector3(-lamp_side * 0.92, 4.82, 0), Vector3(0.42, 0.16, 0.34), Color("#FFF0B0"))

func _make_bush(parent: Node3D, bush_position: Vector3, bush_color: Color) -> void:
    var bush := MeshInstance3D.new()
    var bush_mesh := SphereMesh.new()
    bush_mesh.radius = 0.72
    bush_mesh.height = 0.95
    bush.mesh = bush_mesh
    var bush_material := StandardMaterial3D.new()
    bush_material.albedo_color = bush_color
    bush_material.roughness = 0.92
    bush.material_override = bush_material
    bush.position = bush_position + Vector3(0, 0.42, 0)
    parent.add_child(bush)

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

    # Layered foliage clusters give roadside trees a fuller silhouette.
    var foliage_colors := [Color("#236B3A"), Color("#2D7A42"), Color("#1D6035"), Color("#34864A")]
    for cluster in range(3):
        var leaves := MeshInstance3D.new()
        var leaves_mesh := SphereMesh.new()
        leaves_mesh.radius = 0.72 if cluster == 0 else 0.58
        leaves_mesh.height = leaves_mesh.radius * 2.0
        leaves.mesh = leaves_mesh
        var leaves_material := StandardMaterial3D.new()
        leaves_material.albedo_color = foliage_colors[randi_range(0, foliage_colors.size() - 1)]
        leaves_material.roughness = 0.95
        leaves.material_override = leaves_material
        if cluster == 0:
            leaves.position = Vector3(0, 2.25, 0)
        elif cluster == 1:
            leaves.position = Vector3(-0.42, 2.45, 0.12)
        else:
            leaves.position = Vector3(0.40, 2.42, -0.10)
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
    for crease_x in [-0.48, 0.48]:
        _box(car, Vector3(crease_x, 0.762, -1.08), Vector3(0.035, 0.018, 0.78), body_color.lightened(0.28))
    for stripe_side in [-1.0, 1.0]:
        _box(car, Vector3(stripe_side * 0.925, 0.34, 0.05), Vector3(0.025, 0.035, 2.25), Color("#FF7518"))
    _box(car, Vector3(0, 1.185, -0.22), Vector3(1.18, 0.035, 1.12), Color("#101A27"))
    _box(car, Vector3(0, 0.22, -1.78), Vector3(1.95, 0.12, 0.22), Color("#202832"))
    for side in [-1.0, 1.0]:
        _box(car, Vector3(side * 0.91, 0.28, 0.05), Vector3(0.12, 0.18, 2.55), Color("#252B33"))
        _box(car, Vector3(side * 0.98, 0.93, -0.65), Vector3(0.30, 0.12, 0.22), Color("#171D25"))
        _box(car, Vector3(side * 1.08, 1.02, -0.65), Vector3(0.24, 0.10, 0.32), Color("#111820"))
        # Flush door handles and rear-quarter cooling vents on both sides.
        _box(car, Vector3(side * 0.918, 0.72, -0.18), Vector3(0.035, 0.055, 0.30), Color("#AEB9C3"))
        _box(car, Vector3(side * 0.928, 0.53, 0.88), Vector3(0.035, 0.22, 0.42), Color("#17212B"))
        for vent_slot in [-0.12, 0.0, 0.12]:
            _box(car, Vector3(side * 0.951, 0.53, 0.88 + vent_slot), Vector3(0.018, 0.025, 0.055), Color("#AEB9C3"))

    # Hood vents and a low front grille add recognizable sports-car detailing.
    for vent_x in [-0.48, 0.48]:
        _box(car, Vector3(vent_x, 0.765, -1.12), Vector3(0.24, 0.018, 0.48), Color("#17212B"))
        for vent_line in [-0.14, 0.0, 0.14]:
            _box(car, Vector3(vent_x, 0.779, -1.12 + vent_line), Vector3(0.18, 0.012, 0.025), Color("#8795A2"))
    _box(car, Vector3(0, 0.43, -1.755), Vector3(0.78, 0.18, 0.035), Color("#101820"))
    _box(car, Vector3(0, 0.31, -1.79), Vector3(1.72, 0.055, 0.12), Color("#AEB9C3"))
    # Rear diffuser with separated fins gives the lower bumper more depth.
    _box(car, Vector3(0, 0.20, 1.76), Vector3(1.72, 0.10, 0.20), Color("#151B22"))
    for diffuser_x in [-0.62, -0.22, 0.22, 0.62]:
        _box(car, Vector3(diffuser_x, 0.16, 1.82), Vector3(0.055, 0.18, 0.30), Color("#8795A2"))
    # Small front corner canards finish the lower front bumper.
    for canard_side in [-1.0, 1.0]:
        _box(car, Vector3(canard_side * 0.83, 0.28, -1.76), Vector3(0.30, 0.055, 0.24), Color("#202832"))

    # Rounded rubber tyres with metallic multi-layer alloy rims.
    for x in [-0.96, 0.96]:
        for z in [-1.05, 1.05]:
            var tyre := MeshInstance3D.new()
            var tyre_mesh := CylinderMesh.new()
            tyre_mesh.top_radius = 0.37
            tyre_mesh.bottom_radius = 0.37
            tyre_mesh.height = 0.27
            tyre.mesh = tyre_mesh
            tyre.rotation.z = PI / 2.0
            tyre.position = Vector3(x, 0.22, z)
            var tyre_material := StandardMaterial3D.new()
            tyre_material.albedo_color = Color("#101216")
            tyre_material.roughness = 0.98
            tyre.material_override = tyre_material
            car.add_child(tyre)

            var rim := MeshInstance3D.new()
            var rim_mesh := CylinderMesh.new()
            rim_mesh.top_radius = 0.235
            rim_mesh.bottom_radius = 0.235
            rim_mesh.height = 0.285
            rim.mesh = rim_mesh
            rim.rotation.z = PI / 2.0
            rim.position = Vector3(x * 1.012, 0.22, z)
            var rim_material := StandardMaterial3D.new()
            rim_material.albedo_color = Color("#B8C4CE")
            rim_material.metallic = 0.9
            rim_material.roughness = 0.2
            rim.material_override = rim_material
            car.add_child(rim)

            var hub := MeshInstance3D.new()
            var hub_mesh := CylinderMesh.new()
            hub_mesh.top_radius = 0.075
            hub_mesh.bottom_radius = 0.075
            hub_mesh.height = 0.30
            hub.mesh = hub_mesh
            hub.rotation.z = PI / 2.0
            hub.position = Vector3(x * 1.02, 0.22, z)
            var hub_material := StandardMaterial3D.new()
            hub_material.albedo_color = Color("#FF7518")
            hub_material.metallic = 0.75
            hub.material_override = hub_material
            car.add_child(hub)

            for spoke_index in range(5):
                var spoke_angle := TAU * float(spoke_index) / 5.0
                var spoke := MeshInstance3D.new()
                var spoke_mesh := BoxMesh.new()
                spoke_mesh.size = Vector3(0.035, 0.045, 0.18)
                spoke.mesh = spoke_mesh
                spoke.rotation.x = spoke_angle
                spoke.position = Vector3(x * 1.025, 0.22 + cos(spoke_angle) * 0.13, z + sin(spoke_angle) * 0.13)
                var spoke_material := StandardMaterial3D.new()
                spoke_material.albedo_color = Color("#D2DCE4")
                spoke_material.metallic = 0.88
                spoke_material.roughness = 0.22
                spoke.material_override = spoke_material
                car.add_child(spoke)

    # Raised rear wing and supports, visible above the trunk from the chase camera.
    for wing_x in [-0.62, 0.62]:
        _box(car, Vector3(wing_x, 1.02, 1.28), Vector3(0.08, 0.48, 0.10), Color("#252B33"))
    _box(car, Vector3(0, 1.28, 1.30), Vector3(2.0, 0.12, 0.42), Color("#171D25"))

    # Visible headlights and full-width rear light strip.
    for x in [-0.62, 0.62]:
        _glow_box(car, Vector3(x, 0.49, -1.73), Vector3(0.40, 0.14, 0.07), Color("#FFF1B8"), 1.4)
        var rear_brake_light := _glow_box(car, Vector3(x, 0.49, 1.73), Vector3(0.38, 0.14, 0.07), Color("#E53935"), 1.0)
        brake_lights.append(rear_brake_light)
    _glow_box(car, Vector3(0, 0.49, 1.75), Vector3(0.72, 0.07, 0.06), Color("#FF3344"), 1.2)

    var brand_text := "SUBHOJIT" if GameState.selected_car == 0 else "BIRAJ"
    _add_car_decal(car, brand_text, Vector3(-0.91, 0.62, 0.0), Vector3(0, 90, 0))
    _add_car_decal(car, brand_text, Vector3(0.91, 0.62, 0.0), Vector3(0, -90, 0))
    _add_car_decal(car, brand_text, Vector3(0, 0.76, -1.12), Vector3(-90, 0, 0))

    chase_camera = Camera3D.new()
    chase_camera.position = Vector3(0, 5.2, 10.5)
    chase_camera.rotation_degrees = Vector3(-20, 0, 0)
    chase_camera.fov = 70.0
    chase_camera.current = true
    car.add_child(chase_camera)

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


func _glow_box(parent: Node3D, pos: Vector3, size: Vector3, glow_color: Color, energy: float) -> MeshInstance3D:
    var light_mesh := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = size
    light_mesh.mesh = box_mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = glow_color
    material.emission_enabled = true
    material.emission = glow_color
    material.emission_energy_multiplier = energy
    material.roughness = 0.22
    light_mesh.material_override = material
    light_mesh.position = pos
    parent.add_child(light_mesh)
    return light_mesh


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
        var spawn_z := -45.0 - float(i) * 42.0
        # Pick a clear lane using the vehicles already registered in this pool.
        traffic.position = Vector3(_spawn_lane_for(spawn_z), 0.45, spawn_z)
        traffic_cars.append(traffic)
        # Each vehicle has its own cruising speed, so traffic does not move as one block.
        traffic.set_meta("cruise_speed", randf_range(62.0, 108.0))
        traffic.set_meta("lane_center_x", traffic.position.x)
        traffic.set_meta("sway_phase", randf_range(0.0, TAU))
        traffic.set_meta("sway_rate", randf_range(0.65, 1.15))
        add_child(traffic)
        var paints := [Color("#F2C230"), Color("#E84A5F"), Color("#36A889"), Color("#D7DCE2"), Color("#3979C6"), Color("#E87532")]
        var paint: Color = paints[randi_range(0, paints.size() - 1)]

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

func _random_lane() -> float:
    var lanes := [-3.5, 0.0, 3.5]
    return lanes[randi_range(0, lanes.size() - 1)]

func _spawn_lane_for(spawn_z: float, excluded: Node3D = null) -> float:
    # Avoid nearby traffic and cones, but never score the respawning object against itself.
    var lanes := [-3.5, 0.0, 3.5]
    var safest_lane := lanes[0]
    var best_clearance := -1.0
    lanes.shuffle()
    for lane in lanes:
        var clearance := 999.0
        for other in traffic_cars:
            if other != excluded and is_instance_valid(other) and absf(other.position.z - spawn_z) < 50.0:
                if absf(other.position.x - lane) < 1.0:
                    clearance = minf(clearance, absf(other.position.z - spawn_z))
        for other in road_obstacles:
            if other != excluded and is_instance_valid(other) and absf(other.position.z - spawn_z) < 50.0:
                if absf(other.position.x - lane) < 1.0:
                    clearance = minf(clearance, absf(other.position.z - spawn_z))
        if clearance > best_clearance:
            best_clearance = clearance
            safest_lane = lane
    return safest_lane

func _make_obstacles() -> void:
    # Lightweight road cones add occasional hazards without requiring external assets.
    for i in range(3):
        var obstacle := Node3D.new()
        obstacle.position = Vector3(_spawn_lane_for(-85.0 - float(i) * 105.0), 0.0, -85.0 - float(i) * 105.0)
        add_child(obstacle)

        var base := MeshInstance3D.new()
        var base_mesh := CylinderMesh.new()
        base_mesh.top_radius = 0.42
        base_mesh.bottom_radius = 0.42
        base_mesh.height = 0.12
        base.mesh = base_mesh
        var base_material := StandardMaterial3D.new()
        base_material.albedo_color = Color("#292F36")
        base.material_override = base_material
        base.position.y = 0.06
        obstacle.add_child(base)

        var cone := MeshInstance3D.new()
        var cone_mesh := CylinderMesh.new()
        cone_mesh.top_radius = 0.045
        cone_mesh.bottom_radius = 0.32
        cone_mesh.height = 0.88
        cone.mesh = cone_mesh
        var cone_material := StandardMaterial3D.new()
        cone_material.albedo_color = Color("#FF7518")
        cone_material.roughness = 0.72
        cone.material_override = cone_material
        cone.position.y = 0.54
        obstacle.add_child(cone)

        var stripe := MeshInstance3D.new()
        var stripe_mesh := CylinderMesh.new()
        stripe_mesh.top_radius = 0.19
        stripe_mesh.bottom_radius = 0.23
        stripe_mesh.height = 0.14
        stripe.mesh = stripe_mesh
        var stripe_material := StandardMaterial3D.new()
        stripe_material.albedo_color = Color.WHITE
        stripe.material_override = stripe_material
        stripe.position.y = 0.55
        obstacle.add_child(stripe)
        road_obstacles.append(obstacle)

func _move_obstacles(delta: float) -> void:
    # Cones are fixed to the road, so they must scroll at exactly the road speed.
    var road_movement := speed * delta * 0.12
    var stage_progress := float(race_stage - 1) / 9.0
    var spawn_distance := lerpf(360.0, 220.0, stage_progress)
    for obstacle in road_obstacles:
        obstacle.position.z += road_movement
        if obstacle.position.z > 16.0:
            obstacle.position.z = -spawn_distance - randf_range(0.0, 60.0)
            obstacle.position.x = _spawn_lane_for(obstacle.position.z, obstacle)

func _check_obstacle_collision() -> void:
    if game_over or game_paused:
        return
    for obstacle in road_obstacles:
        if absf(obstacle.position.z - car.position.z) < 1.75 and absf(obstacle.position.x - car.position.x) < 1.15:
            _finish_race()
            return

func _move_traffic(delta: float) -> void:
    for traffic in traffic_cars:
        var base_cruise_speed := float(traffic.get_meta("cruise_speed", 85.0))
        var cruise_speed := maxf(48.0, base_cruise_speed - float(race_stage - 1) * 1.8)
        # Subtle in-lane drift makes each AI car feel alive without crossing lane boundaries.
        var lane_center := float(traffic.get_meta("lane_center_x", traffic.position.x))
        var sway_phase := float(traffic.get_meta("sway_phase", 0.0))
        var sway_rate := float(traffic.get_meta("sway_rate", 0.85))
        var sway := sin(float(Time.get_ticks_msec()) * 0.001 * sway_rate + sway_phase) * 0.12
        traffic.position.x = lane_center + sway
        # Move traffic by its true speed difference: faster traffic pulls away,
        # while the player catches slower traffic naturally.
        var relative_speed := speed - cruise_speed
        var previous_z := traffic.position.z
        traffic.position.z += relative_speed * delta * 0.12
        # Award a near miss in either direction: the player may overtake
        # slower traffic, or faster traffic may pass the player.
        var crossed_player := (previous_z < car.position.z and traffic.position.z >= car.position.z) or (previous_z > car.position.z and traffic.position.z <= car.position.z)
        if crossed_player:
            var lateral_gap := absf(traffic.position.x - car.position.x)
            if lateral_gap >= 1.8 and lateral_gap < 3.25:
                _register_near_miss()
        if traffic.position.z > 16.0 or traffic.position.z < -360.0:
            traffic.position.z = -190.0 - randf_range(0.0, 65.0)
            traffic.position.x = _spawn_lane_for(traffic.position.z, traffic)
            traffic.set_meta("lane_center_x", traffic.position.x)
            traffic.set_meta("sway_phase", randf_range(0.0, TAU))
            traffic.set_meta("sway_rate", randf_range(0.65, 1.15))
            traffic.set_meta("cruise_speed", randf_range(62.0, 108.0))


func _show_stage_feedback(stages_gained: int = 1) -> void:
    if not is_instance_valid(stage_feedback_label):
        return
    if is_instance_valid(stage_feedback_tween) and stage_feedback_tween.is_running():
        stage_feedback_tween.kill()
    var reward := stages_gained * 500
    stage_feedback_label.text = "STAGE %02d  •  +%d BONUS" % [race_stage, reward]
    stage_feedback_label.visible = true
    stage_feedback_label.modulate.a = 1.0
    var base_scale := Vector2.ONE * clampf(minf(get_viewport().get_visible_rect().size.x / 1280.0, get_viewport().get_visible_rect().size.y / 720.0), 0.55, 1.15)
    stage_feedback_label.scale = base_scale * 0.82
    stage_feedback_tween = create_tween()
    stage_feedback_tween.set_parallel(true)
    stage_feedback_tween.tween_property(stage_feedback_label, "scale", base_scale, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    stage_feedback_tween.set_parallel(false)
    stage_feedback_tween.tween_interval(1.15)
    stage_feedback_tween.tween_property(stage_feedback_label, "modulate:a", 0.0, 0.40)
    stage_feedback_tween.tween_callback(func(): stage_feedback_label.visible = false)


func _register_near_miss() -> void:
    near_miss_count += 1
    bonus_score += 250
    near_miss_bonus_score += 250
    near_miss_feedback_timer = 1.35
    if is_instance_valid(near_miss_player):
        near_miss_player.play()
    if is_instance_valid(score_label):
        score_label.text = "SCORE  %06d" % int(distance * 1000.0 + bonus_score)
    if is_instance_valid(near_miss_label):
        # Cancel an older popup animation so a fresh near miss never gets faded by stale timing.
        if is_instance_valid(near_miss_tween) and near_miss_tween.is_running():
            near_miss_tween.kill()
        near_miss_label.text = "NEAR MISS!  ×%02d" % near_miss_count
        near_miss_label.visible = true
        # A quick scale pop and fade makes the reward readable without blocking the road.
        var popup_scale := Vector2.ONE * clampf(minf(get_viewport().get_visible_rect().size.x / 1280.0, get_viewport().get_visible_rect().size.y / 720.0), 0.55, 1.15)
        near_miss_label.scale = popup_scale * 0.82
        near_miss_label.modulate.a = 1.0
        near_miss_tween = create_tween()
        near_miss_tween.set_parallel(true)
        near_miss_tween.tween_property(near_miss_label, "scale", popup_scale, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        near_miss_tween.set_parallel(false)
        near_miss_tween.tween_interval(0.85)
        near_miss_tween.tween_property(near_miss_label, "modulate:a", 0.0, 0.35)


func _check_traffic_collision() -> void:
    if game_over or game_paused:
        return
    for traffic in traffic_cars:
        # Match the collision window to the visible car body dimensions.
        if absf(traffic.position.z - car.position.z) < 3.2 and absf(traffic.position.x - car.position.x) < 1.8:
            _finish_race()
            return


func _show_pause_menu() -> void:
    if game_over or game_paused:
        return
    game_paused = true
    # Release every held driving control when the pause overlay takes focus.
    # This prevents a pedal/BOOST held during pause from remaining active on resume.
    touch_accel = false
    touch_brake = false
    touch_nitro = false
    touch_points.clear()
    was_boosting = false
    was_braking = false
    boost_locked = true
    if is_instance_valid(nitro_fx):
        nitro_fx.visible = false
    if is_instance_valid(engine_player):
        engine_player.stream_paused = true
    if is_instance_valid(nitro_player):
        nitro_player.stream_paused = true
    if is_instance_valid(brake_player):
        brake_player.stream_paused = true
    if is_instance_valid(near_miss_player):
        near_miss_player.stream_paused = true

    var panel := ColorRect.new()
    panel.name = "PauseOverlay"
    panel.color = Color(0.02, 0.03, 0.05, 0.88)
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_layer.add_child(panel)

    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.add_child(center)

    var screen_size := get_viewport().get_visible_rect().size
    var overlay_scale := clampf(minf(screen_size.x / 1280.0, screen_size.y / 720.0), 0.55, 1.15)
    var content := VBoxContainer.new()
    content.custom_minimum_size = Vector2(minf(430.0 * overlay_scale, screen_size.x - 32.0), minf(300.0 * overlay_scale, screen_size.y - 24.0))
    content.add_theme_constant_override("separation", clampi(int(screen_size.y * 0.045), 12, 22))
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    center.add_child(content)

    var title := Label.new()
    title.text = "PAUSED"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", roundi(58.0 * overlay_scale))
    title.add_theme_color_override("font_color", Color("#FF7518"))
    content.add_child(title)

    var resume := Button.new()
    var pause_button_width := minf(260.0, screen_size.x - 48.0)
    var pause_button_height := maxf(42.0, minf(62.0, screen_size.y * 0.15))
    resume.text = "RESUME"
    resume.custom_minimum_size = Vector2(pause_button_width, pause_button_height)
    _style_overlay_button(resume, true)
    resume.pressed.connect(func():
        # Require a fresh BOOST press after unpausing; no stale input is restored.
        touch_accel = false
        touch_brake = false
        touch_nitro = false
        was_boosting = false
        was_braking = false
        # Re-zero the phone tilt after pause/background so steering does not jump on resume.
        tilt_calibrated = false
        tilt_center_x = 0.0
        tilt_filtered_x = 0.0
        tilt_steer = 0.0
        game_paused = false
        if is_instance_valid(engine_player):
            engine_player.stream_paused = false
        if is_instance_valid(nitro_player):
            nitro_player.stream_paused = false
        if is_instance_valid(brake_player):
            brake_player.stream_paused = false
        if is_instance_valid(near_miss_player):
            near_miss_player.stream_paused = false
        panel.queue_free()
    )
    content.add_child(resume)

    var restart := Button.new()
    restart.text = "RESTART"
    restart.custom_minimum_size = Vector2(pause_button_width, pause_button_height)
    _style_overlay_button(restart, false)
    restart.pressed.connect(func(): get_tree().reload_current_scene())
    content.add_child(restart)

    var menu := Button.new()
    menu.text = "MAIN MENU"
    menu.custom_minimum_size = Vector2(pause_button_width, pause_button_height)
    _style_overlay_button(menu, false)
    menu.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/main_menu.tscn"))
    content.add_child(menu)

func _finish_race() -> void:
    if game_over:
        return
    game_over = true
    game_paused = false
    speed = 0.0
    touch_accel = false
    touch_brake = false
    touch_nitro = false
    touch_points.clear()
    was_boosting = false
    was_braking = false
    if is_instance_valid(nitro_fx):
        nitro_fx.visible = false
    if is_instance_valid(engine_player):
        engine_player.stop()
    if is_instance_valid(nitro_player):
        nitro_player.stop()
    if is_instance_valid(brake_player):
        brake_player.stop()
    if is_instance_valid(near_miss_player):
        near_miss_player.stop()
    if is_instance_valid(crash_player):
        crash_player.play()
    # Brief camera impact shake makes a collision feel immediate before the results overlay.
    if is_instance_valid(chase_camera):
        var camera_home := chase_camera.position
        var impact_tween := create_tween()
        impact_tween.tween_property(chase_camera, "position", camera_home + Vector3(0.20, 0.10, 0.0), 0.06)
        impact_tween.tween_property(chase_camera, "position", camera_home + Vector3(-0.16, -0.06, 0.0), 0.07)
        impact_tween.tween_property(chase_camera, "position", camera_home + Vector3(0.08, 0.03, 0.0), 0.07)
        impact_tween.tween_property(chase_camera, "position", camera_home, 0.10)

    var final_score := int(distance * 1000.0 + bonus_score)
    var new_record := distance > best_distance
    var new_score_record := final_score > best_score
    if new_record:
        best_distance = distance
    if new_score_record:
        best_score = final_score
    if new_record or new_score_record:
        _save_best_distance()

    # Full-screen dim layer with a centered layout that adapts to landscape sizes.
    var overlay := ColorRect.new()
    overlay.name = "GameOverOverlay"
    overlay.color = Color(0.02, 0.03, 0.05, 0.90)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    ui_layer.add_child(overlay)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)

    var screen_size := get_viewport().get_visible_rect().size
    var overlay_scale := clampf(minf(screen_size.x / 1280.0, screen_size.y / 720.0), 0.55, 1.15)
    var content := VBoxContainer.new()
    content.custom_minimum_size = Vector2(minf(540.0 * overlay_scale, screen_size.x - 32.0), minf(330.0 * overlay_scale, screen_size.y - 24.0))
    content.add_theme_constant_override("separation", clampi(int(screen_size.y * 0.025), 10, 18))
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    center.add_child(content)

    var title := Label.new()
    title.text = "RACE OVER"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", roundi(58.0 * overlay_scale))
    title.add_theme_color_override("font_color", Color("#FF7518"))
    content.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "NEW HIGH SCORE!" if new_score_record else ("NEW DISTANCE RECORD!" if new_record else "KEEP PUSHING. TRY AGAIN!")
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", roundi(23.0 * overlay_scale))
    subtitle.add_theme_color_override("font_color", Color("#FFD0AD"))
    content.add_child(subtitle)

    var score := Label.new()
    score.text = "DISTANCE  %.2f km   •   SCORE  %06d" % [distance, int(distance * 1000.0 + bonus_score)]
    score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    score.add_theme_font_size_override("font_size", roundi(30.0 * overlay_scale))
    score.add_theme_color_override("font_color", Color.WHITE)
    content.add_child(score)

    var run_stats := Label.new()
    run_stats.text = "NEAR MISSES  %02d  (+%d)   •   STAGE  %02d  (+%d)" % [near_miss_count, near_miss_bonus_score, race_stage, stage_bonus_score]
    run_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    run_stats.add_theme_font_size_override("font_size", roundi(20.0 * overlay_scale))
    run_stats.add_theme_color_override("font_color", Color("#FFD34E"))
    content.add_child(run_stats)

    var best := Label.new()
    best.text = "BEST DISTANCE  %.2f km   •   BEST SCORE  %06d" % [best_distance, best_score]
    best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    best.add_theme_font_size_override("font_size", roundi(22.0 * overlay_scale))
    best.add_theme_color_override("font_color", Color("#BFCAD4"))
    content.add_child(best)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 18)
    content.add_child(actions)

    var action_button_width := maxf(130.0, minf(190.0, (screen_size.x - 72.0) * 0.5))
    var action_button_height := maxf(44.0, minf(62.0, screen_size.y * 0.13))
    var restart := Button.new()
    restart.text = "RACE AGAIN"
    restart.custom_minimum_size = Vector2(action_button_width, action_button_height)
    _style_overlay_button(restart, true)
    restart.pressed.connect(func(): get_tree().reload_current_scene())
    actions.add_child(restart)

    var menu := Button.new()
    menu.text = "MAIN MENU"
    menu.custom_minimum_size = Vector2(action_button_width, action_button_height)
    _style_overlay_button(menu, false)
    menu.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/main_menu.tscn"))
    actions.add_child(menu)

func _style_overlay_button(button: Button, primary: bool) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#FF7518") if primary else Color("#263950")
    normal.border_color = Color("#FF9A55") if primary else Color("#52647D")
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(10)
    normal.content_margin_left = 14.0
    normal.content_margin_right = 14.0
    button.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color("#FF8B3D") if primary else Color("#354B66")
    button.add_theme_stylebox_override("hover", hover)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("#D95F0D") if primary else Color("#1B2B40")
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color("#FFF0E6"))
    button.add_theme_font_size_override("font_size", 21)

func _load_best_distance() -> void:
    var save := ConfigFile.new()
    if save.load("user://shubir_racing.cfg") == OK:
        best_distance = float(save.get_value("score", "best_distance", 0.0))
        best_score = int(save.get_value("score", "best_score", 0))

func _save_best_distance() -> void:
    # Preserve player settings stored in the same config file when saving a new record.
    var save := ConfigFile.new()
    save.load("user://shubir_racing.cfg")
    save.set_value("score", "best_distance", best_distance)
    save.set_value("score", "best_score", best_score)
    save.save("user://shubir_racing.cfg")

func _make_ui() -> void:
    ui_layer = CanvasLayer.new()
    add_child(ui_layer)

    car_identity_label = Label.new()
    car_identity_label.text = "SUBHOJIT  •  BLUE CAR" if GameState.selected_car == 0 else "BIRAJ  •  RED CAR"
    car_identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    car_identity_label.add_theme_font_size_override("font_size", 20)
    car_identity_label.add_theme_color_override("font_color", Color("#FFD0AD") if GameState.selected_car == 0 else Color("#FF9A9A"))
    ui_layer.add_child(car_identity_label)

    near_miss_label = Label.new()
    near_miss_label.text = ""
    near_miss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    near_miss_label.add_theme_font_size_override("font_size", 27)
    near_miss_label.add_theme_color_override("font_color", Color("#FFD34E"))
    near_miss_label.visible = false
    ui_layer.add_child(near_miss_label)

    score_label = Label.new()
    score_label.add_theme_font_size_override("font_size", 18)
    score_label.add_theme_color_override("font_color", Color("#FFD34E"))
    ui_layer.add_child(score_label)

    near_miss_total_label = Label.new()
    near_miss_total_label.add_theme_font_size_override("font_size", 15)
    near_miss_total_label.add_theme_color_override("font_color", Color("#FFD34E"))
    ui_layer.add_child(near_miss_total_label)

    stage_feedback_label = Label.new()
    stage_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stage_feedback_label.add_theme_font_size_override("font_size", 30)
    stage_feedback_label.add_theme_color_override("font_color", Color("#FFB347"))
    stage_feedback_label.visible = false
    ui_layer.add_child(stage_feedback_label)

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

    race_stage_label = Label.new()
    race_stage_label.position = Vector2(25, 118)
    race_stage_label.add_theme_font_size_override("font_size", 18)
    race_stage_label.add_theme_color_override("font_color", Color("#FF7518"))
    ui_layer.add_child(race_stage_label)

    nitro_label = Label.new()
    nitro_label.position = Vector2(25, 146)
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
    pause_button.focus_mode = Control.FOCUS_NONE
    _style_overlay_button(pause_button, false)
    pause_button.add_theme_font_size_override("font_size", 17)
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

    car_identity_label.scale = Vector2.ONE * scale_factor
    car_identity_label.position = Vector2((w - 320.0 * scale_factor) * 0.5, 18.0 * scale_factor)
    car_identity_label.size = Vector2(320, 32)
    near_miss_label.scale = Vector2.ONE * scale_factor
    near_miss_label.position = Vector2((w - 360.0 * scale_factor) * 0.5, 58.0 * scale_factor)
    near_miss_label.size = Vector2(360, 38)
    stage_feedback_label.scale = Vector2.ONE * scale_factor
    stage_feedback_label.position = Vector2((w - 460.0 * scale_factor) * 0.5, 104.0 * scale_factor)
    stage_feedback_label.size = Vector2(460, 44)
    score_label.position = Vector2(22, 198) * scale_factor
    score_label.scale = Vector2.ONE * scale_factor
    near_miss_total_label.position = Vector2(22, 224) * scale_factor
    near_miss_total_label.scale = Vector2.ONE * scale_factor
    speed_label.position = Vector2(22, 16) * scale_factor
    distance_label.position = Vector2(22, 54) * scale_factor
    best_label.position = Vector2(22, 86) * scale_factor
    race_stage_label.position = Vector2(22, 116) * scale_factor
    race_stage_label.scale = Vector2.ONE * scale_factor
    nitro_label.position = Vector2(22, 142) * scale_factor
    boost_meter_bg.position = Vector2(22, 171) * scale_factor
    boost_meter_bg.scale = Vector2.ONE * scale_factor
    for label in [speed_label, distance_label, best_label, race_stage_label, nitro_label]:
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
