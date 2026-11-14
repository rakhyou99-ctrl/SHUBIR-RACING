extends RefCounted
## Shared vehicle builder for Race and Garage. Car 0 is a Ferrari-inspired
## supercar; car 1 is a separate smooth-surface performance sedan.

const MODEL_PATH := "res://Assets/Cars/spectral_gt_rs_game_ready.glb"

static func create_car(paint: Color, owner_text: String, model_y_offset: float = 0.0, model_id: int = 0) -> Node3D:
    if model_id == 0:
        return _create_ferrari_style_supercar(paint, owner_text, model_y_offset)
    if model_id == 1:
        return _create_performance_sedan(paint, owner_text, model_y_offset)
    if not ResourceLoader.exists(MODEL_PATH):
        push_warning("SHUBIR RACING car model missing; using procedural sedan fallback: " + MODEL_PATH)
        return _create_performance_sedan(paint, owner_text, model_y_offset)
    var packed_model := load(MODEL_PATH) as PackedScene
    if packed_model == null:
        push_warning("SHUBIR RACING car model could not be imported: " + MODEL_PATH)
        return _create_performance_sedan(paint, owner_text, model_y_offset)

    var car_root := Node3D.new()
    car_root.name = "SHUBIR_Spectral_GT_RS"
    var imported_root := packed_model.instantiate() as Node3D
    if imported_root == null:
        car_root.free()
        return _create_performance_sedan(paint, owner_text, model_y_offset)

    # Source model is Z-up; convert to Godot Y-up and face the nose toward -Z.
    imported_root.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
    imported_root.scale = Vector3.ONE * 0.72
    imported_root.position.y = model_y_offset
    car_root.add_child(imported_root)
    _apply_body_paint(imported_root, paint)
    _build_imported_wheel_rig(imported_root)
    _add_owner_decals(car_root, owner_text)
    return car_root


static func _create_ferrari_style_supercar(paint: Color, owner_text: String, y_offset: float) -> Node3D:
    # Original Ferrari-inspired mid-engine supercar silhouette; no copied badges
    # or manufacturer marks. Shared by the garage preview and race scene.
    var root := Node3D.new()
    root.name = "SHUBIR_Ferrari_Style_Supercar"
    root.position.y = y_offset

    var body := StandardMaterial3D.new()
    body.albedo_color = paint
    body.metallic = 0.72
    body.roughness = 0.16
    body.clearcoat_enabled = true
    body.clearcoat = 1.0
    body.clearcoat_roughness = 0.08

    # Low nose, broad front fenders, tight waist and muscular rear haunches.
    _add_loft_shell(root, "Supercar_Main_Body", [
        [-2.22, 0.52, 0.52, 0.16],
        [-2.08, 0.78, 0.53, 0.23],
        [-1.78, 0.91, 0.55, 0.27],
        [-1.35, 0.94, 0.57, 0.29],
        [-0.78, 0.88, 0.57, 0.28],
        [-0.10, 0.86, 0.56, 0.27],
        [0.62, 0.94, 0.57, 0.30],
        [1.25, 1.02, 0.58, 0.33],
        [1.78, 0.94, 0.56, 0.29],
        [2.08, 0.72, 0.52, 0.20],
        [2.18, 0.48, 0.49, 0.14]
    ], body, 56)

    var glass := StandardMaterial3D.new()
    glass.albedo_color = Color("#101E2B")
    glass.metallic = 0.62
    glass.roughness = 0.10
    glass.clearcoat_enabled = true
    glass.clearcoat = 1.0
    _add_loft_shell(root, "Panoramic_Cockpit_Glass", [
        [-1.28, 0.58, 0.72, 0.12],
        [-0.94, 0.67, 0.91, 0.25],
        [-0.48, 0.69, 1.08, 0.31],
        [0.18, 0.68, 1.10, 0.31],
        [0.78, 0.66, 0.98, 0.26],
        [1.18, 0.59, 0.76, 0.13]
    ], glass, 48)

    # Sculpted front splitter and rear diffuser.
    _add_box_part(root, "Front_Carbon_Splitter", Vector3(0, 0.22, -2.18), Vector3(1.88, 0.075, 0.28), Color("#090F16"), 0.76, 0.24)
    _add_box_part(root, "Rear_Diffuser", Vector3(0, 0.20, 2.08), Vector3(1.76, 0.13, 0.30), Color("#0B1118"), 0.72, 0.28)
    for fin_x in [-0.62, -0.22, 0.22, 0.62]:
        _add_box_part(root, "Diffuser_Fin", Vector3(fin_x, 0.16, 2.14), Vector3(0.045, 0.15, 0.24), Color("#687581"), 0.78, 0.30)

    # Side skirts, mirrors and deep mid-engine air intakes.
    for side in [-1.0, 1.0]:
        _add_box_part(root, "Carbon_Side_Skirt", Vector3(side * 0.91, 0.29, 0.05), Vector3(0.10, 0.15, 2.55), Color("#111820"), 0.72, 0.30)
        _add_box_part(root, "Side_Air_Intake", Vector3(side * 0.925, 0.58, 0.92), Vector3(0.045, 0.28, 0.62), Color("#080E15"), 0.38, 0.34)
        _add_box_part(root, "Intake_Upper_Lip", Vector3(side * 0.95, 0.74, 0.92), Vector3(0.06, 0.035, 0.66), paint.lightened(0.12), 0.72, 0.18)
        _add_box_part(root, "Mirror_Stem", Vector3(side * 0.82, 0.91, -0.73), Vector3(0.10, 0.12, 0.20), Color("#151D27"), 0.7, 0.2)
        _add_ellipsoid_part(root, "Mirror_Cap", Vector3(side * 0.94, 0.96, -0.73), Vector3(0.17, 0.075, 0.22), body)
        _add_emissive_bar(root, "Front_LED_Headlamp", Vector3(side * 0.65, 0.64, -2.04), Vector3(0.48, 0.045, 0.035), Color("#EAF5FF"), 2.0)
        _add_emissive_bar(root, "Rear_LED_Tail_Lamp", Vector3(side * 0.67, 0.62, 2.10), Vector3(0.42, 0.055, 0.035), Color("#FF263F"), 1.8)
        _add_box_part(root, "Front_Bumper_Intake", Vector3(side * 0.48, 0.39, -2.12), Vector3(0.48, 0.18, 0.035), Color("#090F16"), 0.25, 0.42)

    _add_box_part(root, "Front_Central_Intake", Vector3(0, 0.37, -2.13), Vector3(0.54, 0.18, 0.035), Color("#080D13"), 0.28, 0.42)
    _add_box_part(root, "Rear_Deck_Lip", Vector3(0, 0.76, 1.76), Vector3(1.32, 0.045, 0.13), paint.lightened(0.10), 0.68, 0.16)

    # Large staggered forged alloys with independent steering and spin pivots.
    for spec in [
        {"name": "Front_Left", "x": -0.94, "z": -1.30, "front": true},
        {"name": "Front_Right", "x": 0.94, "z": -1.30, "front": true},
        {"name": "Rear_Left", "x": -0.99, "z": 1.30, "front": false},
        {"name": "Rear_Right", "x": 0.99, "z": 1.30, "front": false}
    ]:
        _add_sedan_wheel(root, spec)

    var badge := Label3D.new()
    badge.name = "Owner_Decal"
    badge.text = owner_text
    badge.position = Vector3(0, 0.91, -1.40)
    badge.rotation_degrees.x = -90.0
    badge.font_size = 22
    badge.pixel_size = 0.0014
    badge.modulate = Color.WHITE
    badge.outline_size = 5
    badge.outline_modulate = Color("#101820")
    root.add_child(badge)
    return root


static func _add_ellipsoid_part(parent: Node3D, part_name: String, position: Vector3, radii: Vector3, material: Material) -> void:
    var instance := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    sphere.radial_segments = 32
    sphere.rings = 16
    instance.name = part_name
    instance.mesh = sphere
    instance.position = position
    instance.scale = radii
    instance.material_override = material
    parent.add_child(instance)


static func _create_performance_sedan(paint: Color, owner_text: String, y_offset: float) -> Node3D:
    var root := Node3D.new()
    root.name = "SHUBIR_Performance_Sedan"
    root.position.y = y_offset

    var body_material := StandardMaterial3D.new()
    body_material.albedo_color = paint
    body_material.metallic = 0.78
    body_material.roughness = 0.19
    body_material.clearcoat_enabled = true
    body_material.clearcoat = 0.92
    body_material.clearcoat_roughness = 0.10
    _add_loft_shell(root, "Sedan_Body", [
        [-2.18, 0.55, 0.57, 0.18],
        [-1.98, 0.79, 0.59, 0.27],
        [-1.62, 0.91, 0.59, 0.31],
        [-1.05, 0.96, 0.59, 0.32],
        [-0.25, 0.98, 0.58, 0.31],
        [0.62, 0.97, 0.57, 0.30],
        [1.30, 0.92, 0.56, 0.29],
        [1.82, 0.83, 0.55, 0.25],
        [2.08, 0.64, 0.54, 0.18]
    ], body_material, 40)

    # A separate fastback four-door glasshouse creates a true sedan silhouette.
    var glass_material := StandardMaterial3D.new()
    glass_material.albedo_color = Color("#152838")
    glass_material.metallic = 0.52
    glass_material.roughness = 0.13
    glass_material.clearcoat_enabled = true
    glass_material.clearcoat = 1.0
    _add_loft_shell(root, "Sedan_Glasshouse", [
        [-1.34, 0.68, 0.82, 0.17],
        [-0.96, 0.72, 1.02, 0.34],
        [-0.48, 0.70, 1.13, 0.40],
        [0.48, 0.69, 1.13, 0.40],
        [0.98, 0.68, 1.00, 0.32],
        [1.34, 0.61, 0.79, 0.17]
    ], glass_material, 36)

    # Lower carbon-fibre side skirts, front splitter and rear diffuser.
    _add_box_part(root, "Front_Splitter", Vector3(0, 0.25, -2.12), Vector3(1.82, 0.09, 0.24), Color("#111820"), 0.72, 0.3)
    _add_box_part(root, "Rear_Diffuser", Vector3(0, 0.22, 2.04), Vector3(1.70, 0.13, 0.28), Color("#101820"), 0.65, 0.34)
    for side in [-1.0, 1.0]:
        _add_box_part(root, "Side_Skirt", Vector3(side * 0.94, 0.31, 0.0), Vector3(0.09, 0.16, 2.85), Color("#151D26"), 0.55, 0.35)
        _add_box_part(root, "Mirror_Housing", Vector3(side * 0.91, 0.92, -0.62), Vector3(0.22, 0.12, 0.20), paint.darkened(0.16), 0.65, 0.2)
        # Fine door shut-lines and flush handles, not oversized decorative blocks.
        for seam_z in [-0.34, 0.78]:
            _add_box_part(root, "Door_Seam", Vector3(side * 0.966, 0.61, seam_z), Vector3(0.012, 0.24, 0.012), Color("#18212A"), 0.15, 0.7)
        _add_box_part(root, "Door_Handle", Vector3(side * 0.975, 0.69, 0.38), Vector3(0.018, 0.035, 0.20), Color("#AEBBC7"), 0.9, 0.22)

    # Continuous dark front intake, fine grille bars and sculpted lamp housings.
    _add_box_part(root, "Front_Grille", Vector3(0, 0.43, -2.13), Vector3(0.92, 0.22, 0.035), Color("#090F16"), 0.25, 0.42)
    for grille_y in [0.37, 0.42, 0.47]:
        _add_box_part(root, "Grille_Slat", Vector3(0, grille_y, -2.155), Vector3(0.78, 0.012, 0.012), Color("#71808C"), 0.82, 0.3)
    for side in [-1.0, 1.0]:
        _add_emissive_bar(root, "Front_LED", Vector3(side * 0.66, 0.65, -2.08), Vector3(0.48, 0.065, 0.035), Color("#DCEEFF"), 1.7)
        _add_emissive_bar(root, "Rear_Lamp", Vector3(side * 0.62, 0.63, 2.08), Vector3(0.54, 0.075, 0.035), Color("#FF263D"), 1.5)
        _add_box_part(root, "Rear_Vent", Vector3(side * 0.72, 0.47, 1.92), Vector3(0.20, 0.13, 0.035), Color("#111820"), 0.4, 0.5)

    # Four independent wheel assemblies with steering and spin pivots.
    for spec in [
        {"name": "Front_Left", "x": -0.94, "z": -1.28, "front": true},
        {"name": "Front_Right", "x": 0.94, "z": -1.28, "front": true},
        {"name": "Rear_Left", "x": -0.94, "z": 1.28, "front": false},
        {"name": "Rear_Right", "x": 0.94, "z": 1.28, "front": false}
    ]:
        _add_sedan_wheel(root, spec)

    # Subtle roof trim, windshield base and rear deck lip.
    for side in [-1.0, 1.0]:
        _add_box_part(root, "Roof_Trim", Vector3(side * 0.68, 1.31, 0.0), Vector3(0.025, 0.025, 1.25), Color("#AAB8C5"), 0.82, 0.22)
    _add_box_part(root, "Rear_Deck_Lip", Vector3(0, 0.82, 1.78), Vector3(1.35, 0.045, 0.12), paint.lightened(0.10), 0.72, 0.18)

    var owner_label := Label3D.new()
    owner_label.name = "Owner_Decal"
    owner_label.text = owner_text
    owner_label.position = Vector3(0, 0.92, -1.52)
    owner_label.rotation_degrees.x = -90.0
    owner_label.font_size = 24
    owner_label.pixel_size = 0.0015
    owner_label.modulate = Color.WHITE
    root.add_child(owner_label)
    return root


static func _add_loft_shell(parent: Node3D, part_name: String, profile: Array, material: Material, ring_steps: int) -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for section_index in range(profile.size() - 1):
        var a: Array = profile[section_index]
        var b: Array = profile[section_index + 1]
        for ring_index in range(ring_steps):
            var angle0 := TAU * float(ring_index) / float(ring_steps)
            var angle1 := TAU * float(ring_index + 1) / float(ring_steps)
            var p00 := Vector3(cos(angle0) * a[1], a[2] + sin(angle0) * a[3], a[0])
            var p01 := Vector3(cos(angle1) * a[1], a[2] + sin(angle1) * a[3], a[0])
            var p10 := Vector3(cos(angle0) * b[1], b[2] + sin(angle0) * b[3], b[0])
            var p11 := Vector3(cos(angle1) * b[1], b[2] + sin(angle1) * b[3], b[0])
            surface.add_vertex(p00)
            surface.add_vertex(p11)
            surface.add_vertex(p10)
            surface.add_vertex(p00)
            surface.add_vertex(p01)
            surface.add_vertex(p11)
    surface.generate_normals()
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = part_name
    mesh_instance.mesh = surface.commit()
    mesh_instance.material_override = material
    parent.add_child(mesh_instance)


static func _add_sedan_wheel(parent: Node3D, spec: Dictionary) -> void:
    var pivot := Node3D.new()
    pivot.name = "WheelPivot_" + String(spec["name"])
    pivot.position = Vector3(float(spec["x"]), 0.43, float(spec["z"]))
    pivot.set_meta("front_axle", bool(spec["front"]))
    parent.add_child(pivot)
    var spin := Node3D.new()
    spin.name = "WheelSpin_" + String(spec["name"])
    pivot.add_child(spin)

    var tire := MeshInstance3D.new()
    tire.name = "Tire"
    var tire_mesh := CylinderMesh.new()
    tire_mesh.top_radius = 0.405
    tire_mesh.bottom_radius = 0.405
    tire_mesh.height = 0.235
    tire_mesh.radial_segments = 40
    tire.mesh = tire_mesh
    tire.rotation_degrees.z = 90.0
    var tire_mat := StandardMaterial3D.new()
    tire_mat.albedo_color = Color("#080B10")
    tire_mat.roughness = 0.94
    tire.material_override = tire_mat
    spin.add_child(tire)

    var rim := MeshInstance3D.new()
    rim.name = "Alloy_Rim"
    var rim_mesh := CylinderMesh.new()
    rim_mesh.top_radius = 0.285
    rim_mesh.bottom_radius = 0.285
    rim_mesh.height = 0.25
    rim_mesh.radial_segments = 40
    rim.mesh = rim_mesh
    rim.rotation_degrees.z = 90.0
    var rim_mat := StandardMaterial3D.new()
    rim_mat.albedo_color = Color("#AEBBC8")
    rim_mat.metallic = 0.94
    rim_mat.roughness = 0.19
    rim.material_override = rim_mat
    spin.add_child(rim)

    for spoke_index in range(10):
        var angle := TAU * float(spoke_index) / 10.0
        var spoke := MeshInstance3D.new()
        spoke.name = "Forged_Spoke"
        var spoke_mesh := BoxMesh.new()
        spoke_mesh.size = Vector3(0.035, 0.34, 0.055)
        spoke.mesh = spoke_mesh
        spoke.position = Vector3(0, cos(angle) * 0.13, sin(angle) * 0.13)
        spoke.rotation.x = angle
        spoke.material_override = rim_mat
        spin.add_child(spoke)

    var hub := MeshInstance3D.new()
    var hub_mesh := CylinderMesh.new()
    hub_mesh.top_radius = 0.085
    hub_mesh.bottom_radius = 0.085
    hub_mesh.height = 0.27
    hub.mesh = hub_mesh
    hub.rotation_degrees.z = 90.0
    hub.material_override = rim_mat
    spin.add_child(hub)


static func _add_box_part(parent: Node3D, part_name: String, position: Vector3, size: Vector3, color: Color, metallic: float, roughness: float) -> void:
    var instance := MeshInstance3D.new()
    instance.name = part_name
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = roughness
    instance.material_override = material
    parent.add_child(instance)


static func _add_emissive_bar(parent: Node3D, part_name: String, position: Vector3, size: Vector3, color: Color, energy: float) -> void:
    var instance := MeshInstance3D.new()
    instance.name = part_name
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    instance.material_override = material
    parent.add_child(instance)


static func _build_imported_wheel_rig(imported_root: Node3D) -> void:
    var wheel_specs := [
        {"id": "Front_Left", "prefix": "part_030_", "center": Vector3(-1.42, 0.91, 0.48), "front": true},
        {"id": "Front_Right", "prefix": "part_015_", "center": Vector3(-1.42, -0.91, 0.48), "front": true},
        {"id": "Rear_Left", "prefix": "part_060_", "center": Vector3(1.38, 0.91, 0.48), "front": false},
        {"id": "Rear_Right", "prefix": "part_045_", "center": Vector3(1.38, -0.91, 0.48), "front": false}
    ]
    for spec in wheel_specs:
        var steering_pivot := Node3D.new()
        steering_pivot.name = "WheelPivot_" + String(spec["id"])
        steering_pivot.position = spec["center"]
        steering_pivot.set_meta("front_axle", bool(spec["front"]))
        imported_root.add_child(steering_pivot)
        var spin_pivot := Node3D.new()
        spin_pivot.name = "WheelSpin_" + String(spec["id"])
        steering_pivot.add_child(spin_pivot)
        var wheel_parts := imported_root.find_children("*", "MeshInstance3D", true, false)
        for candidate in wheel_parts:
            var part := candidate as MeshInstance3D
            if part == null or part.get_parent() != imported_root:
                continue
            var part_name := String(part.name).to_lower()
            if not part_name.begins_with(String(spec["prefix"])) or not _is_rotating_wheel_part(part_name):
                continue
            var relative_transform := steering_pivot.transform.affine_inverse() * part.transform
            part.reparent(spin_pivot, false)
            part.transform = relative_transform


static func _is_rotating_wheel_part(part_name: String) -> bool:
    return part_name.contains("tire") or part_name.contains("sidewall") or part_name.contains("brake_disc") or part_name.contains("brake_hat") or part_name.contains("rim") or part_name.contains("spoke") or part_name.contains("hub")


static func _apply_body_paint(node: Node, paint: Color) -> void:
    if node is MeshInstance3D:
        var part_name := String(node.name).to_lower()
        if part_name.begins_with("part_000_") or part_name.begins_with("part_008_"):
            var paint_material := StandardMaterial3D.new()
            paint_material.albedo_color = paint
            paint_material.metallic = 0.68
            paint_material.roughness = 0.22
            paint_material.clearcoat_enabled = true
            paint_material.clearcoat = 0.82
            paint_material.clearcoat_roughness = 0.12
            node.material_override = paint_material
    for child in node.get_children():
        _apply_body_paint(child, paint)


static func _add_owner_decals(car_root: Node3D, owner_text: String) -> void:
    for side in [-1.0, 1.0]:
        var door_label := Label3D.new()
        door_label.name = "Owner_Decal_" + ("Right" if side > 0.0 else "Left")
        door_label.text = owner_text
        door_label.position = Vector3(side * 0.79, 0.70, 0.0)
        door_label.rotation_degrees = Vector3(0.0, 90.0 if side > 0.0 else -90.0, 0.0)
        door_label.font_size = 40
        door_label.pixel_size = 0.002
        door_label.modulate = Color.WHITE
        door_label.outline_size = 7
        door_label.outline_modulate = Color("#101820")
        car_root.add_child(door_label)
