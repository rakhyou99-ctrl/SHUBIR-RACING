extends SceneTree

func _initialize() -> void:
    call_deferred("_run_tests")


func _run_tests() -> void:
    var race_scene := load("res://Scenes/race.tscn") as PackedScene
    if race_scene == null:
        push_error("Gameplay logic test: race scene could not be loaded")
        quit(1)
        return

    var race := race_scene.instantiate()
    root.add_child(race)
    await process_frame

    race.car.position.z = 0.0
    _expect(race._swept_overlap(0.0, -5.0, 0.0, 5.0, 0.0, 0.0, 1.95, 3.6), "head-on longitudinal sweep is detected")
    _expect(not race._swept_overlap(3.0, -5.0, 3.0, 5.0, 0.0, 0.0, 1.95, 3.6), "parallel lane pass is not a collision")
    _expect(race._swept_overlap(1.0, -5.0, 1.0, 5.0, 0.0, 0.0, 1.95, 3.6), "close parallel pass is detected")
    _expect(not race._swept_overlap(3.0, -5.0, 3.0, 5.0, 0.0, 0.0, 1.45, 2.35), "cone clearance outside collision bounds is safe")
    _expect(race._swept_overlap(-3.0, -5.0, 3.0, 5.0, 0.0, 0.0, 1.95, 3.6), "diagonal crossing is detected")
    _expect(not race._swept_overlap(-3.0, -5.0, -3.0, 5.0, 0.0, 0.0, 1.95, 3.6), "diagonal-axis minima are not combined into a false hit")

    print("Gameplay logic tests passed: 6 swept-collision cases")
    race.queue_free()
    quit(0)


func _expect(condition: bool, description: String) -> void:
    if not condition:
        push_error("Gameplay logic test failed: " + description)
        quit(1)
