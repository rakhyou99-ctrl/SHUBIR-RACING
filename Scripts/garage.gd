extends Control

var preview_root: Node3D
var preview_car: Node3D
var drag_active := false
var mouse_drag_active := false
var preview_touch_index := -1
var last_drag_x := 0.0
var preview_spin_velocity := 0.0
var selected_label: Label
var blue_card: Panel
var red_card: Panel
var blue_button: Button
var red_button: Button
var preview_frame: Panel
var viewport_box: SubViewportContainer
var preview_viewport: SubViewport
var swipe_hint: Label
var side_title: Label
var header_label: Label
var back_button: Button
var start_button: Button
var preview_material_cache: Dictionary = {}
var preview_mesh_cache: Dictionary = {}
var preview_cylinder_mesh_cache: Dictionary = {}
var preview_sphere_mesh_cache: Dictionary = {}

func _notification(what: int) -> void:
    # Android system Back returns from the showroom to the main menu.
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _ready() -> void:
    _build_garage()
    get_viewport().size_changed.connect(_layout_garage)
    _layout_garage()

func _process(delta: float) -> void:
    if not is_instance_valid(preview_car) or drag_active:
        return
    if absf(preview_spin_velocity) > 0.035:
        preview_car.rotation.y += preview_spin_velocity * delta
        preview_spin_velocity = move_toward(preview_spin_velocity, 0.0, delta * 1.35)
    else:
        preview_spin_velocity = 0.0
        preview_car.rotation.y += delta * 0.16

func _build_garage() -> void:
    var bg := ColorRect.new()
    bg.color = Color("#0B1220")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    header_label = Label.new()
    header_label.text = "GARAGE  /  360° SHOWROOM"
    header_label.position = Vector2(42, 24)
    header_label.size = Vector2(800, 56)
    header_label.add_theme_font_size_override("font_size", 34)
    header_label.add_theme_color_override("font_color", Color("#FF7518"))
    add_child(header_label)

    preview_frame = Panel.new()
    preview_frame.position = Vector2(38, 100)
    preview_frame.size = Vector2(820, 540)
    preview_frame.add_theme_stylebox_override("panel", _panel_style(Color("#111D2E"), false))
    add_child(preview_frame)

    viewport_box = SubViewportContainer.new()
    viewport_box.position = Vector2(10, 10)
    viewport_box.size = Vector2(800, 500)
    viewport_box.stretch = true
    viewport_box.mouse_filter = Control.MOUSE_FILTER_STOP
    preview_frame.add_child(viewport_box)
    viewport_box.gui_input.connect(_on_preview_input)

    preview_viewport = SubViewport.new()
    preview_viewport.size = Vector2i(800, 500)
    preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport_box.add_child(preview_viewport)

    preview_root = Node3D.new()
    preview_viewport.add_child(preview_root)
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
    key_light.light_energy = 1.75
    key_light.shadow_enabled = true
    key_light.directional_shadow_max_distance = 18.0
    preview_root.add_child(key_light)
    var fill_light := OmniLight3D.new()
    fill_light.position = Vector3(-3, 3, 2)
    fill_light.light_energy = 1.0
    fill_light.omni_range = 12.0
    # Keep the key light's shadows; the fill light is only for soft visibility.
    # Disabling its shadow map reduces the 3D showroom cost on Android GPUs.
    fill_light.shadow_enabled = false
    preview_root.add_child(fill_light)

    # Soft front and overhead fills keep the grille, bonnet and roof readable
    # as the player rotates the car through the full 360-degree view.
    var front_fill := OmniLight3D.new()
    front_fill.position = Vector3(0.0, 2.0, -5.0)
    front_fill.light_color = Color("#DCEBFF")
    front_fill.light_energy = 1.05
    front_fill.omni_range = 10.0
    preview_root.add_child(front_fill)
    var overhead_fill := OmniLight3D.new()
    overhead_fill.position = Vector3(0.0, 5.0, 0.0)
    overhead_fill.light_color = Color("#FFFFFF")
    overhead_fill.light_energy = 0.75
    overhead_fill.omni_range = 11.0
    preview_root.add_child(overhead_fill)

    # Colored showroom rim lights separate the body from the dark backdrop.
    var blue_rim := OmniLight3D.new()
    blue_rim.position = Vector3(4.0, 2.1, -1.8)
    blue_rim.light_color = Color("#398DFF")
    blue_rim.light_energy = 1.15
    blue_rim.omni_range = 8.0
    preview_root.add_child(blue_rim)
    var warm_rim := OmniLight3D.new()
    warm_rim.position = Vector3(-3.6, 1.7, -2.8)
    warm_rim.light_color = Color("#FF9A55")
    warm_rim.light_energy = 0.8
    warm_rim.omni_range = 7.0
    preview_root.add_child(warm_rim)

    var camera := Camera3D.new()
    # A slightly wider, higher three-quarter framing keeps the complete car
    # in view while giving the roof, wheels and front/rear bodywork clear depth.
    camera.position = Vector3(4.8, 3.15, -8.0)
    camera.fov = 66.0
    camera.near = 0.1
    camera.far = 100.0
    camera.look_at(Vector3(0, 0.68, 0), Vector3.UP)
    camera.current = true
    preview_root.add_child(camera)

    var floor := MeshInstance3D.new()
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(18, 18)
    floor.mesh = floor_mesh
    floor.position.y = -0.04
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color("#17263A")
    floor_mat.metallic = 0.22
    floor_mat.roughness = 0.38
    floor.material_override = floor_mat
    preview_root.add_child(floor)

    # Low circular display plinth with a thin orange illuminated edge.
    var plinth := MeshInstance3D.new()
    var plinth_mesh := _cached_preview_cylinder(3.15, 3.15, 0.12)
    plinth.mesh = plinth_mesh
    plinth.position.y = 0.015
    var plinth_mat := StandardMaterial3D.new()
    plinth_mat.albedo_color = Color("#202E42")
    plinth_mat.metallic = 0.72
    plinth_mat.roughness = 0.28
    plinth.material_override = plinth_mat
    preview_root.add_child(plinth)
    var plinth_edge := MeshInstance3D.new()
    var edge_mesh := _cached_preview_cylinder(3.17, 3.17, 0.035)
    plinth_edge.mesh = edge_mesh
    plinth_edge.position.y = -0.045
    var edge_mat := StandardMaterial3D.new()
    edge_mat.albedo_color = Color("#FF7518")
    edge_mat.emission_enabled = true
    edge_mat.emission = Color("#FF5A12")
    edge_mat.emission_energy_multiplier = 0.65
    plinth_edge.material_override = edge_mat
    preview_root.add_child(plinth_edge)

    preview_car = _create_preview_car()
    preview_root.add_child(preview_car)

    swipe_hint = Label.new()
    swipe_hint.text = "DRAG LEFT / RIGHT TO ROTATE  •  360° VIEW"
    swipe_hint.position = Vector2(0, 510)
    swipe_hint.size = Vector2(820, 24)
    swipe_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    swipe_hint.add_theme_font_size_override("font_size", 16)
    swipe_hint.add_theme_color_override("font_color", Color("#AFC0D4"))
    preview_frame.add_child(swipe_hint)

    side_title = Label.new()
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

    back_button = Button.new()
    var back := back_button
    back.text = "‹  BACK"
    back.position = Vector2(42, 660)
    back.size = Vector2(170, 46)
    _style_button(back, false)
    back.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/main_menu.tscn"))
    add_child(back)

    start_button = Button.new()
    var play := start_button
    play.text = "START RACE  ›"
    play.position = Vector2(1030, 650)
    play.size = Vector2(205, 54)
    _style_button(play, true)
    play.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/race.tscn"))
    add_child(play)

func _layout_garage() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    var scale_factor := clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.55, 1.15)
    var w := viewport_size.x
    var h := viewport_size.y

    header_label.scale = Vector2.ONE * scale_factor
    header_label.position = Vector2(42.0, 24.0) * scale_factor
    header_label.size = Vector2(maxf(400.0, w - 84.0) / scale_factor, 56)

    preview_frame.scale = Vector2.ONE * scale_factor
    preview_frame.position = Vector2(38.0, 100.0) * scale_factor

    # Keep the showroom preview and the selection column side-by-side on
    # compact landscape phones instead of letting the cards run off-screen.
    # Work in the garage's unscaled design coordinates so the showroom
    # and car cards keep their gap on narrow landscape screens.
    var side_x := maxf(24.0, w / scale_factor - 380.0 - 28.0)
    var preview_width := clampf(side_x - 38.0 - 20.0 - 28.0, 400.0, 800.0)
    # Preserve a widescreen showroom viewport on compact landscape phones.
    # A fixed 500px height made the car preview too narrow on smaller devices.
    var preview_height := preview_width * 0.625
    viewport_box.size = Vector2(preview_width, preview_height)
    if is_instance_valid(preview_viewport):
        preview_viewport.size = Vector2i(maxi(1, roundi(preview_width)), maxi(1, roundi(preview_height)))
    preview_frame.size = Vector2(preview_width + 20.0, preview_height + 40.0)
    swipe_hint.scale = Vector2.ONE
    swipe_hint.position = Vector2(0, preview_height + 10.0)
    swipe_hint.size = Vector2(preview_width + 20.0, 24)


    # On short landscape displays, compress the selection column vertically
    # so the selected-car status never collides with the bottom action buttons.
    var compact_layout := h / scale_factor < 680.0
    var card_compact_scale := 0.82 if compact_layout else 1.0
    var blue_card_y := 150.0 if compact_layout else 165.0
    var red_card_y := 325.0 if compact_layout else 365.0
    var selected_label_y := 510.0 if compact_layout else 575.0
    side_title.scale = Vector2.ONE * scale_factor
    side_title.position = Vector2(side_x, 105.0 * scale_factor)
    side_title.size = Vector2(340, 42)
    blue_card.scale = Vector2.ONE * scale_factor * card_compact_scale
    blue_card.position = Vector2(side_x, blue_card_y * scale_factor)
    red_card.scale = Vector2.ONE * scale_factor * card_compact_scale
    red_card.position = Vector2(side_x, red_card_y * scale_factor)
    selected_label.scale = Vector2.ONE * scale_factor
    selected_label.position = Vector2(side_x, selected_label_y * scale_factor)
    selected_label.size = Vector2(350, 34)

    back_button.scale = Vector2.ONE * scale_factor
    back_button.position = Vector2(42.0 * scale_factor, h - 60.0 * scale_factor)
    start_button.scale = Vector2.ONE * scale_factor
    start_button.position = Vector2(w - 250.0 * scale_factor, h - 70.0 * scale_factor)

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
        GameState.save_settings()
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
    # Twin subtle hood creases catch the showroom key light.
    for crease_x in [-0.52, 0.52]:
        _add_box(root, Vector3(crease_x, 0.944, -1.23), Vector3(0.035, 0.018, 0.78), paint.lightened(0.28))
    # Twin functional-style hood vents with metallic slats, matching the race model.
    for vent_x in [-0.48, 0.48]:
        _add_box(root, Vector3(vent_x, 0.958, -1.23), Vector3(0.22, 0.018, 0.44), Color("#17212B"))
        for vent_line in [-0.13, 0.0, 0.13]:
            _add_box(root, Vector3(vent_x, 0.972, -1.23 + vent_line), Vector3(0.17, 0.012, 0.022), Color("#AEBBC7"))
    # Orange lower-body pinstripe ties both selected cars to the game identity.
    for stripe_side in [-1.0, 1.0]:
        _add_box(root, Vector3(stripe_side * 1.025, 0.43, 0.05), Vector3(0.025, 0.035, 2.30), Color("#FF7518"))
    _add_box(root, Vector3(0, 1.30, -0.18), Vector3(1.30, 0.045, 1.35), Color("#101A27"))
    _add_box(root, Vector3(0, 0.32, 1.92), Vector3(2.12, 0.14, 0.24), Color("#202832"))
    for side in [-1.0, 1.0]:
        _add_box(root, Vector3(side * 1.01, 0.32, 0), Vector3(0.13, 0.18, 2.9), Color("#202832"))
        for z in [-1.18, 1.18]:
            var wheel := MeshInstance3D.new()
            var wheel_mesh := _cached_preview_cylinder(0.43, 0.43, 0.24)
            wheel.mesh = wheel_mesh
            wheel.rotation_degrees.z = 90
            wheel.position = Vector3(side * 1.02, 0.36, z)
            var rubber := StandardMaterial3D.new()
            rubber.albedo_color = Color("#080C12")
            wheel.material_override = rubber
            root.add_child(wheel)
            _add_box(root, Vector3(side * 1.15, 0.36, z), Vector3(0.035, 0.24, 0.24), Color("#AEB9C3"))
            # Metallic alloy rim, center cap and five visible lug details.
            var rim := MeshInstance3D.new()
            var rim_mesh := _cached_preview_cylinder(0.285, 0.285, 0.055)
            rim.mesh = rim_mesh
            rim.rotation_degrees.z = 90
            rim.position = Vector3(side * 1.17, 0.36, z)
            var rim_mat := StandardMaterial3D.new()
            rim_mat.albedo_color = Color("#B9C5D0")
            rim_mat.metallic = 0.92
            rim_mat.roughness = 0.2
            rim.material_override = rim_mat
            root.add_child(rim)
            var hub := MeshInstance3D.new()
            var hub_mesh := _cached_preview_cylinder(0.105, 0.105, 0.07)
            hub.mesh = hub_mesh
            hub.rotation_degrees.z = 90
            hub.position = Vector3(side * 1.215, 0.36, z)
            hub.material_override = rim_mat
            root.add_child(hub)
            for lug_index in range(5):
                var angle := TAU * float(lug_index) / 5.0
                # Five slim alloy spokes make the wheel face read as a real rim.
                var spoke := MeshInstance3D.new()
                var spoke_mesh := _cached_preview_box_mesh(Vector3(0.045, 0.055, 0.205))
                spoke.mesh = spoke_mesh
                spoke.rotation.x = angle
                spoke.position = Vector3(side * 1.225, 0.36 + cos(angle) * 0.135, z + sin(angle) * 0.135)
                spoke.material_override = rim_mat
                root.add_child(spoke)

                var lug := MeshInstance3D.new()
                var lug_mesh := _cached_preview_sphere(0.027, 0.054)
                lug.mesh = lug_mesh
                lug.position = Vector3(side * 1.245, 0.36 + cos(angle) * 0.17, z + sin(angle) * 0.17)
                lug.material_override = rim_mat
                root.add_child(lug)
    for x in [-0.68, 0.68]:
        _add_box(root, Vector3(x, 0.62, -1.94), Vector3(0.42, 0.16, 0.07), Color("#FFF1B8"))
        _add_box(root, Vector3(x, 0.62, 1.94), Vector3(0.42, 0.15, 0.07), Color("#E53935"))
    _add_box(root, Vector3(0, 0.65, 1.96), Vector3(1.0, 0.08, 0.06), Color("#FF3344"))
    _add_emissive_box(root, Vector3(-0.68, 0.62, -1.985), Vector3(0.42, 0.13, 0.045), Color("#FFF1B8"))
    _add_emissive_box(root, Vector3(0.68, 0.62, -1.985), Vector3(0.42, 0.13, 0.045), Color("#FFF1B8"))
    _add_emissive_box(root, Vector3(0, 0.65, 1.995), Vector3(1.35, 0.09, 0.045), Color("#FF263F"))

    # Twin polished exhaust tips are visible at the rear of the showroom car.
    for exhaust_side in [-0.48, 0.48]:
        var exhaust_tip := MeshInstance3D.new()
        var exhaust_mesh := _cached_preview_cylinder(0.13, 0.15, 0.38)
        exhaust_tip.mesh = exhaust_mesh
        exhaust_tip.rotation_degrees.x = 90
        exhaust_tip.position = Vector3(exhaust_side, 0.31, 2.08)
        var exhaust_mat := StandardMaterial3D.new()
        exhaust_mat.albedo_color = Color("#B9C4CE")
        exhaust_mat.metallic = 0.9
        exhaust_mat.roughness = 0.18
        exhaust_tip.material_override = exhaust_mat
        root.add_child(exhaust_tip)

    # Glasshouse, sloped windscreens and side windows for a more finished showroom model.
    _add_box(root, Vector3(0, 1.08, -1.02), Vector3(1.34, 0.045, 0.62), Color("#7895AA"))
    _add_box(root, Vector3(0, 1.08, 0.58), Vector3(1.30, 0.045, 0.48), Color("#58748B"))
    for side in [-1.0, 1.0]:
        _add_box(root, Vector3(side * 0.755, 1.08, -0.28), Vector3(0.045, 0.34, 0.82), Color("#52738D"))
        _add_box(root, Vector3(side * 0.82, 0.83, -0.12), Vector3(0.10, 0.09, 0.20), paint.darkened(0.18))
        _add_box(root, Vector3(side * 0.92, 0.91, -0.12), Vector3(0.24, 0.10, 0.22), Color("#17212B"))
        # Door handles and lower side accent.
        _add_box(root, Vector3(side * 1.012, 0.70, 0.28), Vector3(0.025, 0.035, 0.30), Color("#D6E0E8"))
        _add_box(root, Vector3(side * 1.015, 0.39, 0.0), Vector3(0.025, 0.055, 2.35), paint.lightened(0.22))

    # Front grille, rear diffuser and a subtle raised rear wing.
    _add_box(root, Vector3(0, 0.43, -1.965), Vector3(0.78, 0.22, 0.045), Color("#101820"))
    _add_box(root, Vector3(0, 0.28, 1.98), Vector3(1.55, 0.12, 0.10), Color("#101820"))
    for wing_x in [-0.58, 0.58]:
        _add_box(root, Vector3(wing_x, 1.00, 1.42), Vector3(0.07, 0.32, 0.08), Color("#242B35"))
    _add_box(root, Vector3(0, 1.17, 1.43), Vector3(1.95, 0.10, 0.34), Color("#171E29"))

    # Rear-quarter cooling vents with slim metallic louvers, matching the race car.
    for side in [-1.0, 1.0]:
        _add_box(root, Vector3(side * 1.018, 0.61, 1.05), Vector3(0.035, 0.19, 0.48), Color("#111B27"))
        for vent_index in range(3):
            _add_box(root, Vector3(side * 1.043, 0.56 + float(vent_index) * 0.055, 1.05), Vector3(0.025, 0.018, 0.39), Color("#AEBBC7"))

    # Rear diffuser and separated fins are visible from the rear three-quarter angle.
    _add_box(root, Vector3(0, 0.245, 2.015), Vector3(1.62, 0.13, 0.22), Color("#101820"))
    for diffuser_x in [-0.62, -0.21, 0.21, 0.62]:
        _add_box(root, Vector3(diffuser_x, 0.19, 2.08), Vector3(0.055, 0.16, 0.28), Color("#687581"))

    # Small front bumper canards finish both front corners.
    for side in [-1.0, 1.0]:
        _add_box(root, Vector3(side * 0.91, 0.38, -1.91), Vector3(0.32, 0.055, 0.18), Color("#202832"))
        _add_box(root, Vector3(side * 1.055, 0.39, -1.82), Vector3(0.10, 0.045, 0.22), paint.darkened(0.12))

    # Custom owner decal on both doors and bonnet.
    var brand_text := "SUBHOJIT" if GameState.selected_car == 0 else "BIRAJ"
    for side in [-1.0, 1.0]:
        var door_mark := Label3D.new()
        door_mark.text = brand_text
        door_mark.position = Vector3(side * 1.035, 0.66, 0.28)
        door_mark.rotation_degrees = Vector3(0, 90.0 if side > 0.0 else -90.0, 0)
        door_mark.font_size =  thirty_two()
        door_mark.pixel_size = 0.004
        door_mark.modulate = Color.WHITE
        door_mark.outline_size = 6
        root.add_child(door_mark)
    var bonnet_mark := Label3D.new()
    bonnet_mark.text = brand_text
    bonnet_mark.position = Vector3(0, 0.945, -1.25)
    bonnet_mark.rotation_degrees = Vector3(-90, 0, 0)
    bonnet_mark.font_size =  forty()
    bonnet_mark.pixel_size = 0.004
    bonnet_mark.modulate = Color.WHITE
    bonnet_mark.outline_size = 6
    root.add_child(bonnet_mark)
    return root

func thirty_two() -> int:
    return 32

func forty() -> int:
    return 40

func _cached_preview_cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
    var key := "%.4f|%.4f|%.4f" % [top_radius, bottom_radius, height]
    if not preview_cylinder_mesh_cache.has(key):
        var mesh := CylinderMesh.new()
        mesh.top_radius = top_radius
        mesh.bottom_radius = bottom_radius
        mesh.height = height
        preview_cylinder_mesh_cache[key] = mesh
    return preview_cylinder_mesh_cache[key] as CylinderMesh


func _cached_preview_sphere(radius: float, height: float) -> SphereMesh:
    var key := "%.4f|%.4f" % [radius, height]
    if not preview_sphere_mesh_cache.has(key):
        var mesh := SphereMesh.new()
        mesh.radius = radius
        mesh.height = height
        preview_sphere_mesh_cache[key] = mesh
    return preview_sphere_mesh_cache[key] as SphereMesh


func _cached_preview_box_mesh(dimensions: Vector3) -> BoxMesh:
    if not preview_mesh_cache.has(dimensions):
        var mesh := BoxMesh.new()
        mesh.size = dimensions
        preview_mesh_cache[dimensions] = mesh
    return preview_mesh_cache[dimensions] as BoxMesh


func _add_emissive_box(parent: Node3D, pos: Vector3, dimensions: Vector3, tint: Color) -> void:
    var part := MeshInstance3D.new()
    part.mesh = _cached_preview_box_mesh(dimensions)
    part.position = pos
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = tint
    mat.emission_enabled = true
    mat.emission = tint
    mat.emission_energy_multiplier = 1.8
    part.material_override = mat
    parent.add_child(part)

func _add_box(parent: Node3D, pos: Vector3, dimensions: Vector3, tint: Color) -> void:
    var part := MeshInstance3D.new()
    # Reuse same-size preview geometry across both selectable showroom cars.
    part.mesh = _cached_preview_box_mesh(dimensions)
    part.position = pos
    # Share identical showroom body materials instead of allocating one per
    # decorative box on the preview car.
    var material_key := tint.to_rgba32()
    var mat: StandardMaterial3D
    if preview_material_cache.has(material_key):
        mat = preview_material_cache[material_key]
    else:
        mat = StandardMaterial3D.new()
        mat.albedo_color = tint
        mat.metallic = 0.42
        mat.roughness = 0.32
        preview_material_cache[material_key] = mat
    part.material_override = mat
    parent.add_child(part)

func _on_preview_input(event: InputEvent) -> void:
    if not is_instance_valid(preview_car):
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        mouse_drag_active = event.pressed
        drag_active = mouse_drag_active or preview_touch_index >= 0
        last_drag_x = event.position.x
    elif event is InputEventMouseMotion and mouse_drag_active:
        var drag_delta := event.position.x - last_drag_x
        preview_car.rotation.y += drag_delta * 0.012
        preview_spin_velocity = clampf(drag_delta * 0.045, -5.0, 5.0)
        last_drag_x = event.position.x
    elif event is InputEventScreenTouch:
        if event.pressed and preview_touch_index < 0:
            preview_touch_index = event.index
            last_drag_x = event.position.x
        elif not event.pressed and event.index == preview_touch_index:
            preview_touch_index = -1
        drag_active = mouse_drag_active or preview_touch_index >= 0
    elif event is InputEventScreenDrag and event.index == preview_touch_index:
        preview_car.rotation.y += event.relative.x * 0.012
        preview_spin_velocity = clampf(event.relative.x * 0.045, -5.0, 5.0)

func _show_selected_car() -> void:
    # Keep the current showroom angle and swipe momentum when swapping paint
    # and owner decals, so selecting another car does not reset the 360 view.
    var saved_rotation := preview_car.rotation.y if is_instance_valid(preview_car) else 0.0
    if is_instance_valid(preview_car):
        preview_root.remove_child(preview_car)
        preview_car.queue_free()
    preview_car = _create_preview_car()
    preview_car.rotation.y = saved_rotation
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
