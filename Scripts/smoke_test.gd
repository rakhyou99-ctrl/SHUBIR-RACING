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

        # Exercise the race loop for several seconds, not just scene construction.
        var frames_to_run := 180 if scene_path.ends_with("/race.tscn") else 5
        for frame in range(frames_to_run):
            await process_frame
        print("Processed ", frames_to_run, " frames for ", scene_path)

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

            instance.call("_finish_race")
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
            print("Game Over navigation checks passed: Race Again and Main Menu buttons exist.")
            main_menu_button.pressed.emit()
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
            current_scene.queue_free()
            await process_frame

        root.remove_child(instance)
        instance.free()

        # AudioServer releases stopped playback streams asynchronously.
        # Give its mixer time to process the stop before shutting down.
        await create_timer(0.4).timeout

    print("All game screens passed runtime smoke tests.")
    quit()
