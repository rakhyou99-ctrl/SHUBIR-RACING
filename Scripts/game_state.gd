extends Node

var selected_car: int = 0 # 0 = blue SUBHOJIT car; 1 = red BIRAJ car
var best_distance: float = 0.0
var steering_sensitivity: float = 1.0

func _ready() -> void:
    load_settings()

func load_settings() -> void:
    var config := ConfigFile.new()
    if config.load("user://shubir_racing.cfg") == OK:
        steering_sensitivity = clampf(float(config.get_value("settings", "steering_sensitivity", 1.0)), 0.5, 1.8)

func save_settings() -> void:
    var config := ConfigFile.new()
    config.load("user://shubir_racing.cfg")
    config.set_value("settings", "steering_sensitivity", steering_sensitivity)
    config.save("user://shubir_racing.cfg")
