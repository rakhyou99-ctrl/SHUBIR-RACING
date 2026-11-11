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

        root.remove_child(instance)
        instance.free()

        # AudioServer releases stopped playback streams asynchronously.
        # Give its mixer time to process the stop before shutting down.
        await create_timer(0.4).timeout

    print("All game screens passed runtime smoke tests.")
    quit()
