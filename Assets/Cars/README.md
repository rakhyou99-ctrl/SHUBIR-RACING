# Realistic car model asset

The shared car loader expects the CC0 Spectral GT RS glTF binary at:

`Assets/Cars/spectral_gt_rs_game_ready.glb`

Both the Garage showroom and Race scene load this exact asset through
`Scripts/car_model_factory.gd`. Keep the filename and path unchanged.
The loader rotates the source model to Godot's -Z driving direction, scales it
for the game, applies the selected blue/red body paint and adds the selected
owner decal. The previous procedural car remains as a fallback if the asset
has not yet been copied into this folder.
