extends SceneTree

func _initialize() -> void:
    var race_script = load("res://Scripts/race.gd")
    if race_script == null:
        push_error("Gameplay logic test: race script could not be loaded")
        quit(1)
        return

    # Instantiate the script without adding it to the tree. This isolates the
    # pure swept-collision helper from audio, rendering and gameplay timers.
    var race = race_script.new()
    race.car = Node3D.new()
    race.car.position.z = 0.0

    if not _expect(race._swept_overlap(0.0, -5.0, 0.0, 5.0, 0.0, 0.0, 1.95, 3.6), "head-on longitudinal sweep is detected"):
        quit(1)
        return
    if not _expect(not race._swept_overlap(3.0, -5.0, 3.0, 5.0, 0.0, 0.0, 1.95, 3.6), "parallel lane pass is not a collision"):
        quit(1)
        return
    if not _expect(race._swept_overlap(1.0, -5.0, 1.0, 5.0, 0.0, 0.0, 1.95, 3.6), "close parallel pass is detected"):
        quit(1)
        return
    if not _expect(not race._swept_overlap(3.0, -5.0, 3.0, 5.0, 0.0, 0.0, 1.45, 2.35), "cone clearance outside collision bounds is safe"):
        quit(1)
        return
    if not _expect(race._swept_overlap(-3.0, -5.0, 3.0, 5.0, 0.0, 0.0, 1.95, 3.6), "diagonal crossing is detected"):
        quit(1)
        return
    if not _expect(not race._swept_overlap(-3.0, -5.0, -3.0, 5.0, 0.0, 0.0, 1.95, 3.6), "diagonal-axis minima do not create a false hit"):
        quit(1)
        return

    print("Gameplay logic tests passed: 6 swept-collision cases")
    quit(0)


func _expect(condition: bool, description: String) -> bool:
    if not condition:
        push_error("Gameplay logic test failed: " + description)
        return false
    return true
