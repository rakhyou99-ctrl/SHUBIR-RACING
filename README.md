# SHUBIR RACING

SHUBIR RACING is an offline, landscape-oriented endless highway racing game built with Godot 4.

## Implemented
- Main menu with Play, Garage / Select Car, Settings, Exit Game, and personal-best distance.
- 3D garage showroom with two original selectable cars, 360-degree drag rotation, and idle display rotation.
- Blue SUBHOJIT and red BIRAJ car liveries, with custom body details and no third-party brand logos.
- Endless multi-lane highway with lane markings, guardrails, roadside scenery, lights, speed signs, and overhead gantries.
- Traffic vehicles with varied paint, speeds, and subtle lane movement.
- Cone hazards, collision detection, race-over screen, restart, and personal-best distance/score saving.
- Near-miss detection with animated feedback, reward sound, and bonus score.
- Progressive 10-stage difficulty with a +500 score reward for each 0.5 km stage milestone (including multiple milestones crossed in one update).
- Phone-tilt steering; touch accelerator, brake, and separate Boost controls.
- Multi-touch input handling for simultaneous driving controls.
- Boost charge, recharge, exhaust flame effects, speed-responsive chase camera, and braking lights.
- Engine, brake, boost, and crash sound effects.
- Settings for steering sensitivity and master volume; selected car and settings persist locally.
- Pause/resume handling, including app-background and Android Back requests.
- Responsive landscape UI and orange accent theme: `#FF7518`.

## Controls
- Tilt the phone left or right to steer.
- Hold the accelerator to increase speed.
- Hold the brake to slow down.
- Hold Accelerator and Boost together to activate Boost.
- Use Pause or the Android Back action to open the pause menu.

## Build and verification status
The repository includes a Godot project validation workflow and a manually gated Android export workflow. Recent repository validation runs have passed. A passing repository workflow does not replace a full Godot editor import, Android export, or real-device gameplay test.

The physical direction/calibration of tilt steering, touch-coordinate mapping for multi-touch, performance, and complete gameplay flow still require testing on Android devices. No release APK is being published until the game is fully finished and those checks have been completed.

## Project structure
- `Scenes/`: main menu, garage, race, and settings scenes.
- `Scripts/`: game state and screen/gameplay scripts.
- `.github/workflows/`: project validation and manually gated Android export workflows.


## Final Android release signing

The final APK workflow uses a permanent, developer-owned release keystore; it does not use the temporary Android debug key. Never commit the keystore or share its passwords in chat.

1. Generate and securely back up a release keystore on a trusted computer. Keep the keystore password and key password identical for Godot Android export:
   `keytool -genkeypair -v -keystore shubir-racing-release.keystore -storetype JKS -alias shubir-racing -keyalg RSA -keysize 2048 -validity 10000`
2. Encode the keystore file as one Base64 line (Linux/macOS: `base64 -w 0 shubir-racing-release.keystore`; on macOS use `base64 shubir-racing-release.keystore | tr -d '\\n'`).
3. In the GitHub repository, add these **Actions repository secrets**:
   - `SHUBIR_RELEASE_KEYSTORE_BASE64`: the Base64 keystore contents.
   - `SHUBIR_RELEASE_KEYSTORE_PASSWORD`: the keystore/key password.
   - `SHUBIR_RELEASE_KEY_ALIAS`: the alias (default command above: `shubir-racing`).
4. Only after the game is complete and tested, manually run the Android workflow with `release_ready=true`.

The workflow validates the keystore and exports with Godot's release signing environment variables. Do not lose the keystore: future updates to the same Android package must use the same signing identity.
