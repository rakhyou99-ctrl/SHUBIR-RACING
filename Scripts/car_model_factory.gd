extends RefCounted
## Shared imported vehicle builder used by both the Race and Garage scenes.
## Place the licensed GLB at res://Assets/Cars/spectral_gt_rs_game_ready.glb.

const MODEL_PATH := "res://Assets/Cars/spectral_gt_rs_game_ready.glb"

static func create_car(paint: Color, owner_text: String, model_y_offset: float = 0.0) -> Node3D:
    # Avoid noisy ResourceLoader errors when the optional licensed GLB has not
    # yet been added to the repository; callers intentionally use the fallback.
    if not ResourceLoader.exists(MODEL_PATH):
        push_warning("SHUBIR RACING car model missing; using procedural fallback: " + MODEL_PATH)
        return null
    var packed_model := load(MODEL_PATH) as PackedScene
    if packed_model == null:
        push_warning("SHUBIR RACING car model could not be imported: " + MODEL_PATH)
        return null

    var car_root := Node3D.new()
    car_root.name = "SHUBIR_Realistic_Car"

    var imported_root := packed_model.instantiate() as Node3D
    if imported_root == null:
        push_warning("The imported GLB did not create a Node3D root.")
        car_root.free()
        return null

    # The source asset is Y-up with its nose facing +X. Rotate it so the
    # vehicle faces Godot's -Z driving direction and scale it to game units.
    imported_root.rotation.y = PI * 0.5
    imported_root.scale = Vector3.ONE * 0.72
    imported_root.position.y = model_y_offset
    car_root.add_child(imported_root)

    _apply_body_paint(imported_root, paint)
    _add_owner_decals(car_root, owner_text)
    return car_root


static func _apply_body_paint(node: Node, paint: Color) -> void:
    if node is MeshInstance3D:
        var part_name := String(node.name).to_lower()
        var is_painted_panel := (
            part_name == "body_shell_hero"
            or part_name == "cabin_roof_shell"
            or part_name.begins_with("front_fender_lip")
            or part_name.begins_with("rear_fender_lip")
            or part_name.begins_with("door_skin")
            or part_name == "hood_center_panel"
        )
        if is_painted_panel:
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
    # Door decals sit on the two outer door skins. The model is 0.72 scale.
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

    var hood_label := Label3D.new()
    hood_label.name = "Owner_Decal_Hood"
    hood_label.text = owner_text
    hood_label.position = Vector3(0.0, 0.91, -1.20)
    hood_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
    hood_label.font_size = 34
    hood_label.pixel_size = 0.0018
    hood_label.modulate = Color.WHITE
    hood_label.outline_size = 6
    hood_label.outline_modulate = Color("#101820")
    car_root.add_child(hood_label)
