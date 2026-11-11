extends SceneTree

const SMOKE_SCENES := [
    "res://Scenes/main_menu.tscn",
    "res://Scenes/garage.tscn",
    "res://Scenes/settings.tscn",
    "res://Scenes/race.tscn",
]

func _initialize() -> void:
    call_deferred("_run_smoke_tests")


func _count_scene_nodes(node: Node, meshes_only: bool = false) -> int:
    var count := 1 if (not meshes_only or node is MeshInstance3D) else 0
    for child in node.get_children():
        count += _count_scene_nodes(child, meshes_only)
    return count


func _run_smoke_tests() -> void:
    for scene_path in SMOKE_SCENES:
        print("Smoke-testing ", scene_path)
        var packed_scene := load(scene_path) as PackedScene
        if packed_scene == null:
            push_error("Could not load smoke-test scene: " + scene_path)
            quit(1)
            return

        var instance := packed_scene.instantiate()
        root.add_child(instance)
        if scene_path.ends_with("/race.tscn"):
            current_scene = instance
        # Verify the live race scene has its core gameplay nodes and controls.
        if scene_path.ends_with("/race.tscn"):
            for property_name in ["car", "chase_camera", "engine_player", "brake_button", "boost_button", "accel_button"]:
                if instance.get(property_name) == null:
                    push_error("Race scene is missing required runtime node: " + property_name)
                    root.remove_child(instance)
                    instance.free()
                    quit(1)
                    return
            var race_sun: DirectionalLight3D = null
            for child in instance.get_children():
                if child is DirectionalLight3D:
                    race_sun = child
                    break
            if race_sun == null or race_sun.shadow_enabled:
                push_error("Race mobile lighting must use a directional sun without a real-time shadow map.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            print("Race render efficiency passed: directional sun shadow map is disabled.")
            if instance.get("traffic_cars").size() < 3 or instance.get("road_segments").size() < 3:
                push_error("Race scene did not create enough traffic or road segments.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            var race_node_count := _count_scene_nodes(instance)
            var race_mesh_count := _count_scene_nodes(instance, true)
            print("Race scene resource baseline: %d nodes, %d MeshInstance3D nodes, %d traffic cars, %d road segments, %d road hazards." % [
                race_node_count,
                race_mesh_count,
                instance.get("traffic_cars").size(),
                instance.get("road_segments").size(),
                instance.get("road_obstacles").size()
            ])
            if race_node_count > 2400 or race_mesh_count > 1800:
                push_error("Race scene exceeds the mobile scene complexity budget: %d nodes / %d meshes." % [race_node_count, race_mesh_count])
                root.remove_child(instance)
                instance.free()
                quit(1)
                return

        if scene_path.ends_with("/garage.tscn"):
            var game_state: Node = root.get_node("GameState")
            var original_car := int(game_state.get("selected_car"))
            var garage_instance: Control = instance
            var preview_viewport: SubViewport = garage_instance.get("preview_viewport")
            if preview_viewport == null or preview_viewport.render_target_update_mode != SubViewport.UPDATE_WHEN_VISIBLE:
                push_error("Garage showroom must render only while its preview is visible.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            print("Garage render efficiency passed: showroom SubViewport uses UPDATE_WHEN_VISIBLE.")
            var showroom_root: Node3D = garage_instance.get("preview_root")
            var showroom_key_light: DirectionalLight3D = null
            if showroom_root != null:
                for preview_child in showroom_root.get_children():
                    if preview_child is DirectionalLight3D:
                        showroom_key_light = preview_child
                        break
            if showroom_key_light == null or showroom_key_light.shadow_enabled:
                push_error("Garage mobile lighting must disable the realtime directional shadow map.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            print("Garage render efficiency passed: showroom directional shadow map is disabled.")
            var red_card: Control = garage_instance.get("red_card")
            var red_select: Button = null
            if red_card != null:
                for child in red_card.get_children():
                    if child is Button:
                        red_select = child
                        break
            if red_select == null:
                push_error("Garage red-car selection button is missing.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            red_select.pressed.emit()
            var garage_config := ConfigFile.new()
            if int(game_state.get("selected_car")) != 1 or garage_config.load("user://shubir_racing.cfg") != OK or int(garage_config.get_value("garage", "selected_car", -1)) != 1:
                push_error("Selecting the BIRAJ car did not persist the garage choice.")
                game_state.set("selected_car", original_car)
                game_state.call("save_settings")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            game_state.call("load_settings")
            if int(game_state.get("selected_car")) != 1:
                push_error("The BIRAJ garage selection did not reload from persistent settings.")
                game_state.set("selected_car", original_car)
                game_state.call("save_settings")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            game_state.set("selected_car", original_car)
            game_state.call("save_settings")
            print("Garage car selection persistence passed: BIRAJ selection saved and reloaded.")

            for test_size in [Vector2(640, 360), Vector2(800, 360), Vector2(2340, 1080)]:
                garage_instance.call("_layout_garage_for_size", test_size)
                await process_frame
                var garage_controls: Array = [
                    garage_instance.get("header_label"),
                    garage_instance.get("preview_frame"),
                    garage_instance.get("side_title"),
                    garage_instance.get("blue_card"),
                    garage_instance.get("red_card"),
                    garage_instance.get("selected_label"),
                    garage_instance.get("back_button"),
                    garage_instance.get("start_button")
                ]
                for control in garage_controls:
                    var bounds: Rect2 = control.get_global_rect()
                    if bounds.position.x < -1.0 or bounds.position.y < -1.0 or bounds.end.x > test_size.x + 1.0 or bounds.end.y > test_size.y + 1.0:
                        push_error("Garage element is outside %s: %s rect=%s" % [test_size, control.name, bounds])
                        garage_instance.call("_layout_garage")
                        game_state.set("selected_car", original_car)
                        game_state.call("save_settings")
                        root.remove_child(instance)
                        instance.free()
                        quit(1)
                        return
            garage_instance.call("_layout_garage")
            await process_frame
            print("Garage responsive bounds passed: 640x360, 800x360, and 2340x1080.")

        # Exercise the race loop for several seconds, not just scene construction.
        var frames_to_run := 180 if scene_path.ends_with("/race.tscn") else 5
        for frame in range(frames_to_run):
            await process_frame
        print("Processed ", frames_to_run, " frames for ", scene_path)

        if scene_path.ends_with("/main_menu.tscn"):
            var menu_instance: Control = instance
            for test_size in [Vector2(640, 360), Vector2(800, 360), Vector2(2340, 1080)]:
                menu_instance.call("_layout_menu_for_size", test_size)
                await process_frame
                var menu_controls: Array = [
                    menu_instance.get("title_label"),
                    menu_instance.get("subtitle_label"),
                    menu_instance.get("play_button"),
                    menu_instance.get("garage_button"),
                    menu_instance.get("settings_button"),
                    menu_instance.get("exit_button"),
                    menu_instance.get("best_distance_label"),
                    menu_instance.get("note_label")
                ]
                for control in menu_controls:
                    var bounds: Rect2 = control.get_global_rect()
                    if bounds.position.x < -1.0 or bounds.position.y < -1.0 or bounds.end.x > test_size.x + 1.0 or bounds.end.y > test_size.y + 1.0:
                        push_error("Main Menu element is outside %s: %s rect=%s" % [test_size, control.name, bounds])
                        menu_instance.call("_layout_menu")
                        root.remove_child(instance)
                        instance.free()
                        quit(1)
                        return
            menu_instance.call("_layout_menu")
            await process_frame
            print("Main Menu responsive bounds passed: 640x360, 800x360, and 2340x1080.")

        if scene_path.ends_with("/settings.tscn"):
            var game_state: Node = root.get_node("GameState")
            var original_sensitivity := float(game_state.get("steering_sensitivity"))
            var original_volume := float(game_state.get("master_volume"))
            var settings_instance: Control = instance
            var sensitivity_slider: HSlider = settings_instance.get("steering_slider")
            var volume_slider: HSlider = settings_instance.get("volume_slider")
            if sensitivity_slider == null or volume_slider == null:
                push_error("Settings scene is missing a steering or volume slider.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            sensitivity_slider.value = 1.4
            volume_slider.value = 0.4
            game_state.call("load_settings")
            if absf(float(game_state.get("steering_sensitivity")) - 1.4) > 0.01 or absf(float(game_state.get("master_volume")) - 0.4) > 0.01:
                push_error("Settings sliders did not persist steering sensitivity and master volume.")
                game_state.set("steering_sensitivity", original_sensitivity)
                game_state.set("master_volume", original_volume)
                game_state.call("save_settings")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            game_state.set("steering_sensitivity", original_sensitivity)
            game_state.set("master_volume", original_volume)
            game_state.call("save_settings")
            print("Settings slider persistence checks passed: tilt sensitivity and master volume.")

            for test_size in [Vector2(640, 360), Vector2(800, 360), Vector2(2340, 1080)]:
                settings_instance.call("_layout_settings_for_size", test_size)
                await process_frame
                var settings_controls: Array = [
                    settings_instance.get("settings_title"),
                    settings_instance.get("steering_heading"),
                    sensitivity_slider,
                    settings_instance.get("sensitivity_label"),
                    settings_instance.get("volume_heading"),
                    volume_slider,
                    settings_instance.get("volume_label"),
                    settings_instance.get("tilt_hint"),
                    settings_instance.get("save_button")
                ]
                for control in settings_controls:
                    var bounds: Rect2 = control.get_global_rect()
                    if bounds.position.x < -1.0 or bounds.position.y < -1.0 or bounds.end.x > test_size.x + 1.0 or bounds.end.y > test_size.y + 1.0:
                        push_error("Settings element is outside %s: %s rect=%s" % [test_size, control.name, bounds])
                        settings_instance.call("_layout_settings")
                        root.remove_child(instance)
                        instance.free()
                        quit(1)
                        return
            settings_instance.call("_layout_settings")
            await process_frame
            print("Settings responsive bounds passed: 640x360, 800x360, and 2340x1080.")

        if scene_path.ends_with("/race.tscn"):
            instance.set("touch_accel", true)
            for frame in range(30):
                await process_frame
            var accelerated_speed: float = instance.get("speed")
            if accelerated_speed <= 0.0:
                push_error("Accelerator input did not increase race speed.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return

            instance.set("touch_brake", true)
            for frame in range(30):
                await process_frame
            var braked_speed: float = instance.get("speed")
            if braked_speed >= accelerated_speed:
                push_error("Brake input did not reduce race speed.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            var test_brake_lights: Array = instance.get("brake_lights")
            if test_brake_lights.size() < 2:
                push_error("Player car is missing its paired brake lamps.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            for brake_lamp in test_brake_lights:
                var active_brake_material := brake_lamp.material_override as StandardMaterial3D
                if active_brake_material == null or active_brake_material.emission_energy_multiplier < 2.7 or active_brake_material.albedo_color.r < 0.9:
                    push_error("Both brake lamps must brighten red while braking.")
                    root.remove_child(instance)
                    instance.free()
                    quit(1)
                    return

            instance.set("touch_brake", false)
            await process_frame
            for brake_lamp in test_brake_lights:
                var released_brake_material := brake_lamp.material_override as StandardMaterial3D
                if released_brake_material == null or released_brake_material.emission_energy_multiplier > 1.1:
                    push_error("Both brake lamps must return to normal glow after release.")
                    root.remove_child(instance)
                    instance.free()
                    quit(1)
                    return
            print("Brake lamp response passed: bright red under braking and normal glow after release.")

            # Brake intentionally locks Boost until the Boost control is released.
            instance.set("touch_nitro", false)
            await process_frame
            instance.set("touch_nitro", true)
            for frame in range(3):
                await process_frame
            if not instance.get("was_boosting"):
                push_error("Boost did not activate with accelerator and boost input.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            print("Race input checks passed: accelerator, brake, boost.")

            # Simulate Android-style independent finger IDs against the live pedal rectangles.
            # This exercises the raw ScreenTouch/ScreenDrag path, not only the Button callbacks.
            instance.set("touch_accel", false)
            instance.set("touch_brake", false)
            instance.set("touch_nitro", false)
            var accel_control: Control = instance.get("accel_button")
            var boost_control: Control = instance.get("boost_button")
            var brake_control: Control = instance.get("brake_button")
            var accel_center := accel_control.get_global_rect().get_center()
            var boost_center := boost_control.get_global_rect().get_center()
            var brake_center := brake_control.get_global_rect().get_center()
            var accel_finger := InputEventScreenTouch.new()
            accel_finger.index = 0
            accel_finger.position = accel_center
            accel_finger.pressed = true
            instance.call("_input", accel_finger)
            var boost_finger := InputEventScreenTouch.new()
            boost_finger.index = 1
            boost_finger.position = boost_center
            boost_finger.pressed = true
            instance.call("_input", boost_finger)
            if not instance.get("touch_accel") or not instance.get("touch_nitro"):
                push_error("Two-finger Accelerator + Boost touch input was not detected.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            # Releasing one finger must not cancel the other finger's held control.
            var first_accel_release := InputEventScreenTouch.new()
            first_accel_release.index = 0
            first_accel_release.position = accel_center
            first_accel_release.pressed = false
            instance.call("_input", first_accel_release)
            if instance.get("touch_accel") or not instance.get("touch_nitro"):
                push_error("Releasing the Accelerator finger incorrectly cancelled the independent Boost finger.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            accel_finger.pressed = true
            instance.call("_input", accel_finger)
            if not instance.get("touch_accel") or not instance.get("touch_nitro"):
                push_error("Re-pressing Accelerator did not preserve the independent Boost finger.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            var second_boost_release := InputEventScreenTouch.new()
            second_boost_release.index = 1
            second_boost_release.position = boost_center
            second_boost_release.pressed = false
            instance.call("_input", second_boost_release)
            if not instance.get("touch_accel") or instance.get("touch_nitro"):
                push_error("Releasing the Boost finger incorrectly cancelled the independent Accelerator finger.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            boost_finger.pressed = true
            instance.call("_input", boost_finger)
            if not instance.get("touch_accel") or not instance.get("touch_nitro"):
                push_error("Re-pressing Boost did not preserve the independent Accelerator finger.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            var boost_drag := InputEventScreenDrag.new()
            boost_drag.index = 1
            boost_drag.position = brake_center
            instance.call("_input", boost_drag)
            if not instance.get("touch_accel") or not instance.get("touch_brake") or instance.get("touch_nitro"):
                push_error("Multi-touch drag did not transfer the second finger to the Brake pedal.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            var accel_release := InputEventScreenTouch.new()
            accel_release.index = 0
            accel_release.position = accel_center
            accel_release.pressed = false
            instance.call("_input", accel_release)
            var brake_release := InputEventScreenTouch.new()
            brake_release.index = 1
            brake_release.position = brake_center
            brake_release.pressed = false
            instance.call("_input", brake_release)
            if instance.get("touch_accel") or instance.get("touch_brake") or instance.get("touch_nitro"):
                push_error("Multi-touch release left a pedal or Boost control stuck.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            print("Raw multi-touch checks passed: two fingers, drag between pedals, and independent release.")

            # Deterministic accelerometer tests validate calibration, dead zone,
            # opposite steering responses, and sensor-loss recentering.
            instance.set("tilt_calibrated", false)
            instance.set("tilt_steer", 0.0)
            instance.call("_update_tilt_steering", Vector3(0.0, 9.8, 0.0), 0.1)
            if not instance.get("tilt_calibrated") or absf(float(instance.get("tilt_center_x")) - 9.8) > 0.01:
                push_error("Tilt steering did not calibrate its neutral accelerometer baseline.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            instance.call("_update_tilt_steering", Vector3(0.0, 10.2, 0.0), 0.1)
            if absf(float(instance.get("tilt_steer"))) > 0.01:
                push_error("Tilt steering dead zone allowed unwanted drift.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            instance.call("_update_tilt_steering", Vector3(0.0, 12.0, 0.0), 0.5)
            var positive_tilt := float(instance.get("tilt_steer"))
            if positive_tilt <= 0.0:
                push_error("Positive relative phone tilt did not produce positive steering.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            instance.set("tilt_steer", 0.0)
            instance.set("tilt_filtered_x", 9.8)
            instance.call("_update_tilt_steering", Vector3(0.0, 7.6, 0.0), 0.5)
            var negative_tilt := float(instance.get("tilt_steer"))
            if negative_tilt >= 0.0:
                push_error("Negative relative phone tilt did not produce opposite steering.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            instance.set("tilt_steer", 1.0)
            instance.call("_update_tilt_steering", Vector3.ZERO, 0.1)
            if float(instance.get("tilt_steer")) >= 1.0:
                push_error("Unavailable accelerometer sample did not recenter steering.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            print("Tilt steering logic checks passed: calibration, dead zone, left/right response, and sensor fallback.")

            # Confirm the Settings sensitivity multiplier changes actual car movement.
            var steering_game_state: Node = root.get_node("GameState")
            var saved_sensitivity := float(steering_game_state.get("steering_sensitivity"))
            instance.set("tilt_steer", 0.5)
            instance.set("speed", 55.0)
            var steering_car: Node3D = instance.get("car")
            steering_car.position.x = 0.0
            steering_game_state.set("steering_sensitivity", 0.5)
            instance.call("_apply_player_steering", 0.1)
            var low_sensitivity_delta := steering_car.position.x
            steering_car.position.x = 0.0
            steering_game_state.set("steering_sensitivity", 1.8)
            instance.call("_apply_player_steering", 0.1)
            var high_sensitivity_delta := steering_car.position.x
            steering_game_state.set("steering_sensitivity", saved_sensitivity)
            if high_sensitivity_delta <= low_sensitivity_delta * 3.0:
                push_error("Steering sensitivity setting did not scale actual player movement.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            steering_car.position.x = 0.0
            print("Steering sensitivity checks passed: low and high settings change car movement.")

            # Exercise the same layout function with compact, wide-short, and large
            # landscape sizes without changing the CI window's actual viewport.
            for test_size in [Vector2(640, 360), Vector2(800, 360), Vector2(2340, 1080)]:
                instance.call("_layout_race_ui_for_size", test_size)
                await process_frame
                for control in [brake_control, accel_control, boost_control, instance.get("pause_button")]:
                    var control_rect: Rect2 = control.get_global_rect()
                    if control_rect.position.x < -1.0 or control_rect.position.y < -1.0 or control_rect.end.x > test_size.x + 1.0 or control_rect.end.y > test_size.y + 1.0:
                        push_error("Race HUD control is outside the viewport at %s: %s rect=%s" % [test_size, control.name, control_rect])
                        instance.call("_layout_race_ui")
                        root.remove_child(instance)
                        instance.free()
                        quit(1)
                        return
            instance.call("_layout_race_ui")
            await process_frame
            print("Landscape HUD layout checks passed: 640x360, 800x360, and 2340x1080.")

            # Confirm the two driving pedals retain a broad metal-plate style,
            # while BOOST remains a separate rounded control.
            for pedal in [brake_control, accel_control]:
                var pedal_style := pedal.get_theme_stylebox("normal") as StyleBoxFlat
                if pedal_style == null or pedal.size.x < 140.0 or pedal.size.y < 120.0 or pedal_style.get_corner_radius(0) > 8:
                    push_error("Brake and Accelerator must remain large rectangular metal pedals.")
                    instance.call("_layout_race_ui")
                    root.remove_child(instance)
                    instance.free()
                    quit(1)
                    return
            for pedal in [brake_control, accel_control]:
                var grip_ribs := 0
                var metal_fasteners := 0
                for detail in pedal.get_children():
                    if detail is ColorRect and detail.size.x > 20.0 and detail.size.y <= 6.0:
                        grip_ribs += 1
                    elif detail is ColorRect and detail.size.x <= 8.0 and detail.size.y <= 8.0:
                        metal_fasteners += 1
                if grip_ribs != 5 or metal_fasteners != 4:
                    push_error("Each metal pedal must show five rubber grip ribs and four metal fasteners.")
                    instance.call("_layout_race_ui")
                    root.remove_child(instance)
                    instance.free()
                    quit(1)
                    return
            var boost_style := boost_control.get_theme_stylebox("normal") as StyleBoxFlat
            if boost_style == null or boost_style.get_corner_radius(0) < 15:
                push_error("BOOST must remain visually separate from the rectangular pedals.")
                instance.call("_layout_race_ui")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            print("Pedal design checks passed: rectangular metal plates, five grip ribs, four fasteners, and separate rounded BOOST.")

            var obstacles: Array = instance.get("road_obstacles")
            if obstacles.is_empty():
                push_error("Race scene did not create road collision hazards.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            var test_obstacle: Node3D = obstacles[0]
            var player_car: Node3D = instance.get("car")
            test_obstacle.position = Vector3(player_car.position.x, 0.0, player_car.position.z)
            test_obstacle.set_meta("previous_frame_x", player_car.position.x)
            test_obstacle.set_meta("previous_frame_z", player_car.position.z)
            instance.set("previous_car_frame_x", player_car.position.x)
            instance.call("_check_obstacle_collision")
            await process_frame
            if not instance.get("game_over") or instance.get("speed") != 0.0:
                push_error("Game Over did not stop the race correctly.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            if instance.find_child("GameOverOverlay", true, false) == null:
                push_error("Game Over results overlay was not created.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            var results_overlay := instance.find_child("GameOverOverlay", true, false)
            var race_again_button := results_overlay.find_child("RaceAgainButton", true, false)
            var main_menu_button := results_overlay.find_child("MainMenuButton", true, false)
            if race_again_button == null or main_menu_button == null:
                push_error("Game Over navigation buttons are missing.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return
            print("Obstacle collision triggered Game Over and stopped the race.")
            print("Game Over navigation checks passed: Race Again and Main Menu buttons exist.")
            race_again_button.pressed.emit()
            await process_frame
            await process_frame
            if current_scene == null or current_scene.scene_file_path != "res://Scenes/race.tscn":
                push_error("Game Over Race Again button did not reload the race.")
                quit(1)
                return
            print("Game Over Race Again navigation passed.")
            current_scene.call("_finish_race")
            await process_frame
            var restarted_overlay := current_scene.find_child("GameOverOverlay", true, false)
            var restarted_menu_button := restarted_overlay.find_child("MainMenuButton", true, false)
            if restarted_menu_button == null:
                push_error("Restarted race did not recreate the Game Over Main Menu button.")
                quit(1)
                return
            restarted_menu_button.pressed.emit()
            await process_frame
            if current_scene == null or current_scene.scene_file_path != "res://Scenes/main_menu.tscn":
                push_error("Game Over Main Menu button did not open the main menu.")
                quit(1)
                return
            print("Game Over Main Menu navigation passed.")
            var menu_play_button: Button = current_scene.get("play_button")
            if menu_play_button == null:
                push_error("Main Menu Play button is missing after Game Over navigation.")
                quit(1)
                return
            menu_play_button.pressed.emit()
            await process_frame
            if current_scene == null or current_scene.scene_file_path != "res://Scenes/race.tscn":
                push_error("Main Menu Play button did not start a new race.")
                quit(1)
                return
            print("Main Menu Play navigation passed: a fresh race scene opened.")
            var fresh_race: Node3D = current_scene
            var fresh_traffic: Array = fresh_race.get("traffic_cars")
            if fresh_traffic.is_empty():
                push_error("Fresh race did not create traffic for collision testing.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            var test_traffic: Node3D = fresh_traffic[0]
            var fresh_car: Node3D = fresh_race.get("car")

            # Verify swept collision catches a high-speed pass through the player,
            # but does not report a path that stays outside the lateral hitbox.
            if not bool(fresh_race.call("_swept_overlap", 0.0, -8.0, 0.0, 8.0, 0.0, 0.0, 1.95, 3.6)):
                push_error("Swept collision missed a high-speed traffic path through the player.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            if bool(fresh_race.call("_swept_overlap", 4.0, -8.0, 4.0, 8.0, 0.0, 0.0, 1.95, 3.6)):
                push_error("Swept collision reported a false hit outside the lateral collision width.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            if not bool(fresh_race.call("_swept_overlap", 0.0, -6.0, 0.0, 6.0, 0.0, 0.0, 1.45, 2.35)):
                push_error("Swept collision missed a high-speed road-cone path through the player.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            if bool(fresh_race.call("_swept_overlap", 2.5, -6.0, 2.5, 6.0, 0.0, 0.0, 1.45, 2.35)):
                push_error("Swept collision reported a road-cone hit outside its lateral width.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Swept collision checks passed: high-speed traffic and cone hits detected; lateral false hits rejected.")

            # Fill two lanes at the same spawn distance; the spawn helper must choose
            # the remaining clear lane instead of placing a car/cone into traffic.
            var saved_traffic_positions: Array[Vector3] = []
            for other in fresh_traffic:
                saved_traffic_positions.append(other.position)
                other.position = Vector3(-3.5, other.position.y, -200.0)
            var saved_obstacle_positions: Array[Vector3] = []
            var fresh_obstacles: Array = fresh_race.get("road_obstacles")
            for other in fresh_obstacles:
                saved_obstacle_positions.append(other.position)
                other.position = Vector3(0.0, other.position.y, -200.0)
            var safest_spawn_lane := float(fresh_race.call("_spawn_lane_for", -200.0))
            for i in range(fresh_traffic.size()):
                fresh_traffic[i].position = saved_traffic_positions[i]
            for i in range(fresh_obstacles.size()):
                fresh_obstacles[i].position = saved_obstacle_positions[i]
            if absf(safest_spawn_lane - 3.5) > 0.01:
                push_error("Spawn lane safety did not select the only clear lane; selected %s." % safest_spawn_lane)
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Spawn lane safety check passed: occupied lanes avoided.")

            # Recycled objects must reset their swept-history metadata to their new
            # spawn position, otherwise a teleport can create a phantom collision.
            fresh_race.set("speed", 100.0)
            test_traffic.position = Vector3(3.5, test_traffic.position.y, 17.0)
            test_traffic.set_meta("previous_frame_x", 3.5)
            test_traffic.set_meta("previous_frame_z", 17.0)
            fresh_race.call("_move_traffic", 0.016)
            if absf(float(test_traffic.get_meta("previous_frame_z")) - test_traffic.position.z) > 0.001 or test_traffic.position.z > -180.0:
                push_error("Traffic recycle did not reset swept collision history at the new spawn point.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            var recycle_obstacle: Node3D = fresh_obstacles[0]
            recycle_obstacle.position = Vector3(3.5, recycle_obstacle.position.y, 17.0)
            recycle_obstacle.set_meta("previous_frame_x", 3.5)
            recycle_obstacle.set_meta("previous_frame_z", 17.0)
            fresh_race.call("_move_obstacles", 0.016)
            if absf(float(recycle_obstacle.get_meta("previous_frame_z")) - recycle_obstacle.position.z) > 0.001 or recycle_obstacle.position.z > -200.0:
                push_error("Obstacle recycle did not reset swept collision history at the new spawn point.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            fresh_race.call("_check_traffic_collision")
            fresh_race.call("_check_obstacle_collision")
            if fresh_race.get("game_over"):
                push_error("Recycled traffic or obstacle caused a phantom collision at its new spawn point.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Recycle checks passed: traffic and cones reset swept history without phantom hits.")

            # Cones must move with the road at the exact same speed, while
            # retaining their true previous-frame position for swept collision.
            var moving_obstacle: Node3D = fresh_obstacles[1]
            moving_obstacle.position = Vector3(1.5, moving_obstacle.position.y, -50.0)
            fresh_race.set("race_stage", 1)
            fresh_race.set("speed", 100.0)
            fresh_race.call("_move_obstacles", 0.25)
            if absf(moving_obstacle.position.z - (-47.0)) > 0.001:
                push_error("Road cone did not scroll at the exact road movement speed.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            if absf(float(moving_obstacle.get_meta("previous_frame_z")) - (-50.0)) > 0.001 or absf(float(moving_obstacle.get_meta("previous_frame_x")) - 1.5) > 0.001:
                push_error("Road cone did not preserve its previous-frame position before scrolling.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Road hazard motion passed: cones match road speed and preserve swept-collision history.")

            # Long-run recycle stress: traffic, cones and road segments must reuse
            # their existing nodes instead of allocating an ever-growing scene.
            var recycle_node_baseline := _count_scene_nodes(fresh_race)
            var traffic_count_baseline := fresh_traffic.size()
            var obstacle_count_baseline := fresh_obstacles.size()
            var road_count_baseline: int = fresh_race.get("road_segments").size()
            var box_mesh_cache_baseline: int = fresh_race.get("box_mesh_cache").size()
            var cylinder_mesh_cache_baseline: int = fresh_race.get("cylinder_mesh_cache").size()
            var box_material_cache_baseline: int = fresh_race.get("box_material_cache").size()
            var environment_mesh_cache_baseline: int = fresh_race.get("environment_mesh_cache").size()
            var environment_material_cache_baseline: int = fresh_race.get("environment_material_cache").size()
            for cycle in range(250):
                for traffic in fresh_traffic:
                    traffic.position.z = 17.0
                for obstacle in fresh_obstacles:
                    obstacle.position.z = 17.0
                fresh_race.call("_move_traffic", 0.016)
                fresh_race.call("_move_obstacles", 0.016)
                fresh_race.call("_move_road", 0.016)
            var recycle_node_final := _count_scene_nodes(fresh_race)
            if recycle_node_final != recycle_node_baseline or fresh_traffic.size() != traffic_count_baseline or fresh_obstacles.size() != obstacle_count_baseline or fresh_race.get("road_segments").size() != road_count_baseline:
                push_error("Long-run recycling changed scene/object counts: nodes %d -> %d." % [recycle_node_baseline, recycle_node_final])
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Long-run recycle stress passed: 250 cycles kept node, traffic, cone and road-segment counts constant.")
            if int(fresh_race.get("box_mesh_cache").size()) != box_mesh_cache_baseline or int(fresh_race.get("cylinder_mesh_cache").size()) != cylinder_mesh_cache_baseline or int(fresh_race.get("box_material_cache").size()) != box_material_cache_baseline or int(fresh_race.get("environment_mesh_cache").size()) != environment_mesh_cache_baseline or int(fresh_race.get("environment_material_cache").size()) != environment_material_cache_baseline:
                push_error("Long-run recycle unexpectedly grew a geometry or material cache.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Resource cache stability passed: mesh/material cache sizes stayed fixed through 250 recycle cycles.")

            # A safe lateral pass across the player's Z must award exactly one near-miss reward.
            fresh_race.set("speed", 100.0)
            fresh_race.set("previous_car_frame_x", fresh_car.position.x)
            test_traffic.position = Vector3(fresh_car.position.x + 2.5, test_traffic.position.y, fresh_car.position.z - 0.01)
            test_traffic.set_meta("lane_center_x", fresh_car.position.x + 2.5)
            test_traffic.set_meta("sway_phase", 0.0)
            test_traffic.set_meta("sway_rate", 0.0)
            test_traffic.set_meta("cruise_speed", 99.0)
            test_traffic.set_meta("near_miss_awarded", false)
            test_traffic.set_meta("previous_frame_x", test_traffic.position.x)
            test_traffic.set_meta("previous_frame_z", test_traffic.position.z)
            fresh_race.call("_move_traffic", 0.2)
            if fresh_race.get("near_miss_count") != 1 or fresh_race.get("near_miss_bonus_score") != 250:
                push_error("A safe traffic pass did not award the expected near-miss bonus.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Near-miss pass awarded one +250 bonus.")
            # Drain part of the tank under Boost, then verify release-based recharge.
            fresh_race.set("nitro_left", 1.0)
            fresh_race.set("touch_accel", true)
            fresh_race.set("touch_nitro", true)
            fresh_race.set("boost_locked", false)
            fresh_race.call("_process", 0.5)
            if absf(float(fresh_race.get("nitro_left")) - 0.5) > 0.01:
                push_error("Boost tank did not drain at the expected rate.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            fresh_race.set("touch_nitro", false)
            fresh_race.set("touch_accel", false)
            fresh_race.call("_process", 1.0)
            if absf(float(fresh_race.get("nitro_left")) - 1.1) > 0.02:
                push_error("Boost tank did not recharge at 0.60 seconds per second.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Boost drain and recharge rate checks passed.")

            # Braking must cancel BOOST and require the BOOST finger to be
            # released before another activation can drain the tank.
            fresh_race.set("nitro_left", 2.0)
            fresh_race.set("touch_accel", true)
            fresh_race.set("touch_nitro", true)
            fresh_race.set("touch_brake", true)
            fresh_race.set("boost_locked", false)
            fresh_race.call("_process", 0.25)
            if not bool(fresh_race.get("boost_locked")) or absf(float(fresh_race.get("nitro_left")) - 2.15) > 0.02:
                push_error("Brake did not cancel BOOST and lock the held BOOST control.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            fresh_race.set("touch_brake", false)
            fresh_race.call("_process", 0.25)
            if not bool(fresh_race.get("boost_locked")) or absf(float(fresh_race.get("nitro_left")) - 2.30) > 0.02:
                push_error("BOOST reactivated without releasing the BOOST control after braking.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            fresh_race.set("touch_nitro", false)
            fresh_race.call("_process", 0.01)
            fresh_race.set("touch_nitro", true)
            var tank_before_reactivation := float(fresh_race.get("nitro_left"))
            fresh_race.call("_process", 0.25)
            if bool(fresh_race.get("boost_locked")) or absf(float(fresh_race.get("nitro_left")) - (tank_before_reactivation - 0.25)) > 0.02:
                push_error("BOOST did not reactivate after a deliberate release and re-press.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Brake/BOOST interlock passed: brake cancels boost until the BOOST control is released.")
            # Pause must clear held pedals and BOOST; Resume must restore active play.
            var engine_audio: AudioStreamPlayer = fresh_race.get("engine_player")
            var boost_audio: AudioStreamPlayer = fresh_race.get("nitro_player")
            var brake_audio: AudioStreamPlayer = fresh_race.get("brake_player")
            var near_miss_audio: AudioStreamPlayer = fresh_race.get("near_miss_player")
            if engine_audio == null or boost_audio == null or brake_audio == null or near_miss_audio == null or not engine_audio.playing:
                push_error("Race audio players were not initialized or the engine loop was not started.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            # Keep the one-shot brake effect active so Pause tests an in-flight effect,
            # not only idle AudioStreamPlayer instances.
            brake_audio.play()
            fresh_race.set("touch_accel", true)
            fresh_race.set("touch_brake", true)
            fresh_race.set("touch_nitro", true)
            fresh_race.call("_show_pause_menu")
            if not fresh_race.get("game_paused") or fresh_race.get("touch_accel") or fresh_race.get("touch_brake") or fresh_race.get("touch_nitro"):
                push_error("Pause did not stop gameplay and clear held controls.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            if not engine_audio.stream_paused or not boost_audio.stream_paused or not brake_audio.stream_paused or not near_miss_audio.stream_paused:
                push_error("Pause audio state mismatch: engine=%s boost=%s brake=%s near_miss=%s" % [engine_audio.stream_paused, boost_audio.stream_paused, brake_audio.stream_paused, near_miss_audio.stream_paused])
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            var pause_overlay := fresh_race.find_child("PauseOverlay", true, false)
            var resume_button := pause_overlay.find_child("ResumeButton", true, false) if pause_overlay != null else null
            if resume_button == null:
                push_error("Pause overlay did not create a Resume button.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            resume_button.pressed.emit()
            await process_frame
            if fresh_race.get("game_paused") or fresh_race.get("touch_accel") or fresh_race.get("touch_brake") or fresh_race.get("touch_nitro"):
                push_error("Resume did not restore play with controls safely released.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            if engine_audio.stream_paused or boost_audio.stream_paused or brake_audio.stream_paused or near_miss_audio.stream_paused:
                push_error("Resume did not restore gameplay audio playback.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Pause/Resume audio checks passed: all gameplay streams suspend and resume.")
            print("Pause and Resume navigation/control checks passed.")

            # Godot Node notifications: 201 = application paused, 1007 = Android Back request.
            # Exercise the same lifecycle entry points Android sends while the race is active.
            fresh_race.set("touch_accel", true)
            fresh_race.set("touch_nitro", true)
            fresh_race.call("_notification", 2015)
            if not fresh_race.get("game_paused") or fresh_race.get("touch_accel") or fresh_race.get("touch_nitro"):
                push_error("Application-paused notification did not safely pause the race.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            var background_overlay := fresh_race.find_child("PauseOverlay", true, false)
            var background_resume := background_overlay.find_child("ResumeButton", true, false) if background_overlay != null else null
            if background_resume == null:
                push_error("Background pause did not provide a Resume action.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            background_resume.pressed.emit()
            await process_frame
            if fresh_race.get("game_paused"):
                push_error("Race remained paused after resuming from application background.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            fresh_race.call("_notification", 1007)
            if not fresh_race.get("game_paused"):
                push_error("Android Back notification did not open the race pause menu.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Android lifecycle checks passed: background pause/resume and system Back.")
            var back_overlay := fresh_race.find_child("PauseOverlay", true, false)
            var back_resume := back_overlay.find_child("ResumeButton", true, false) if back_overlay != null else null
            if back_resume != null:
                back_resume.pressed.emit()
                await process_frame
            # Crossing 0.50 km must award the stage-two bonus exactly once.
            fresh_race.set("distance", 0.5)
            fresh_race.set("speed", 0.0)
            fresh_race.call("_process", 0.01)
            if fresh_race.get("race_stage") != 2 or fresh_race.get("stage_bonus_score") != 500:
                push_error("Crossing the first stage threshold did not award +500.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Stage progression awarded the expected +500 bonus.")
            test_traffic.position = Vector3(fresh_car.position.x, test_traffic.position.y, fresh_car.position.z)
            test_traffic.set_meta("previous_frame_x", fresh_car.position.x)
            test_traffic.set_meta("previous_frame_z", fresh_car.position.z)
            fresh_race.set("previous_car_frame_x", fresh_car.position.x)
            # Overlapping traffic and hazards must not end a race while its pause
            # overlay is active; the same collision must still count after resume.
            fresh_race.set("game_paused", true)
            fresh_race.call("_check_traffic_collision")
            fresh_race.call("_check_obstacle_collision")
            if fresh_race.get("game_over"):
                push_error("A traffic or road-hazard overlap ended the race while paused.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            fresh_race.set("game_paused", false)
            print("Paused collision suppression passed for traffic and road hazards.")
            fresh_race.call("_check_traffic_collision")
            if not fresh_race.get("game_over"):
                push_error("Traffic collision did not trigger Game Over.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            var stopped_engine: AudioStreamPlayer = fresh_race.get("engine_player")
            var crash_effect: AudioStreamPlayer = fresh_race.get("crash_player")
            if stopped_engine.playing or crash_effect == null or not crash_effect.playing:
                push_error("Game Over did not stop the engine loop and play the crash effect.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Game Over audio checks passed: engine stopped and crash effect triggered.")
            print("Traffic collision triggered Game Over and stopped the race.")
            if absf(float(fresh_race.get("best_distance")) - float(fresh_race.get("distance"))) > 0.001 or int(fresh_race.get("best_score")) <= 0:
                push_error("Game Over did not update the best distance and score records.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            var saved_config := ConfigFile.new()
            if saved_config.load("user://shubir_racing.cfg") != OK or absf(float(saved_config.get_value("score", "best_distance", 0.0)) - float(fresh_race.get("best_distance"))) > 0.001 or int(saved_config.get_value("score", "best_score", 0)) != int(fresh_race.get("best_score")):
                push_error("Best distance and score were not written to the persistent config.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Best distance and score were saved after Game Over.")
            fresh_race.queue_free()
            await process_frame
            var reload_scene := load("res://Scenes/race.tscn") as PackedScene
            var reloaded_race: Node3D = reload_scene.instantiate()
            root.add_child(reloaded_race)
            current_scene = reloaded_race
            await process_frame
            if absf(float(reloaded_race.get("best_distance")) - float(saved_config.get_value("score", "best_distance"))) > 0.001 or int(reloaded_race.get("best_score")) != int(saved_config.get_value("score", "best_score")):
                push_error("A new race scene did not reload the saved best records.")
                reloaded_race.queue_free()
                await process_frame
                quit(1)
                return
            print("Best distance and score reload correctly in a fresh race.")
            # A shorter subsequent run must never overwrite an existing record.
            reloaded_race.set("distance", 0.01)
            reloaded_race.set("bonus_score", 0)
            reloaded_race.call("_finish_race")
            var after_short_run := ConfigFile.new()
            if after_short_run.load("user://shubir_racing.cfg") != OK or absf(float(after_short_run.get_value("score", "best_distance", 0.0)) - float(saved_config.get_value("score", "best_distance"))) > 0.001 or int(after_short_run.get_value("score", "best_score", 0)) != int(saved_config.get_value("score", "best_score")):
                push_error("A shorter subsequent race overwrote the existing best records.")
                reloaded_race.queue_free()
                await process_frame
                quit(1)
                return
            print("A shorter subsequent race preserved both existing records.")
            reloaded_race.queue_free()
            await process_frame

        if is_instance_valid(instance) and instance.get_parent() != null:
            root.remove_child(instance)
            instance.free()

        # AudioServer releases stopped playback streams asynchronously.
        # Give its mixer time to process the stop before shutting down.
        await create_timer(0.4).timeout

    print("All game screens passed runtime smoke tests.")
    quit()
