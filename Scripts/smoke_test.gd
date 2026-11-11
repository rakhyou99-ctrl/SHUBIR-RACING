extends SceneTree

const SMOKE_SCENES := [
    "res://Scenes/main_menu.tscn",
    "res://Scenes/garage.tscn",
    "res://Scenes/settings.tscn",
    "res://Scenes/race.tscn",
]

func _initialize() -> void:
    call_deferred("_run_smoke_tests")


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
            if instance.get("traffic_cars").size() < 3 or instance.get("road_segments").size() < 3:
                push_error("Race scene did not create enough traffic or road segments.")
                root.remove_child(instance)
                instance.free()
                quit(1)
                return

        if scene_path.ends_with("/garage.tscn"):
            var game_state: Node = root.get_node("GameState")
            var original_car := int(game_state.get("selected_car"))
            var garage_instance: Control = instance
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

        # Exercise the race loop for several seconds, not just scene construction.
        var frames_to_run := 180 if scene_path.ends_with("/race.tscn") else 5
        for frame in range(frames_to_run):
            await process_frame
        print("Processed ", frames_to_run, " frames for ", scene_path)

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

            instance.set("touch_brake", false)
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
            # Pause must clear held pedals and BOOST; Resume must restore active play.
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
            print("Pause and Resume navigation/control checks passed.")
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
            fresh_race.call("_check_traffic_collision")
            if not fresh_race.get("game_over"):
                push_error("Traffic collision did not trigger Game Over.")
                fresh_race.queue_free()
                await process_frame
                quit(1)
                return
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
