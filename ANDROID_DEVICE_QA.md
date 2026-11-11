# Android Device QA — SHUBIR RACING

This checklist is intentionally separate from the automated Godot smoke tests. A passing headless CI run does not verify physical sensors, touch mapping, audio hardware, frame rate, or thermal behavior.

## Test device record

- Device / model:
- Android version:
- Screen resolution:
- Test date:
- Build / commit:
- Tester:

## Required checks

- [ ] App opens in landscape and stays in landscape after screen rotation.
- [ ] Main Menu opens without a black/white screen or missing UI.
- [ ] Garage opens; both SUBHOJIT (blue) and BIRAJ (red) cars can be selected.
- [ ] Selected car remains selected after leaving and reopening Garage / restarting the app.
- [ ] Settings open; tilt sensitivity and master volume sliders move smoothly and persist after restart.
- [ ] Start a race with the phone held level; car stays approximately centered without unwanted drift.
- [ ] Tilt phone left: car steers left.
- [ ] Tilt phone right: car steers right.
- [ ] Return phone to level: steering settles back to straight.
- [ ] Hold Accelerator: speed increases; release it: car coasts down.
- [ ] Hold Brake: speed decreases and rear brake lights brighten.
- [ ] Hold Accelerator and Boost with two separate fingers: Boost activates and exhaust flames appear.
- [ ] Release either finger: Boost deactivates correctly; no pedal remains stuck.
- [ ] Press Brake while Boost is active: Boost cancels and does not reactivate until the Boost control is released.
- [ ] Let Boost empty: it recharges after release and can be used again.
- [ ] Traffic and cone collisions end the race and show the results screen.
- [ ] Race Again starts a clean race with reset speed, distance, stage, Boost charge, and pedals.
- [ ] Main Menu from Game Over returns to the menu.
- [ ] Pause button opens Pause; Resume continues; Restart resets; Main Menu returns.
- [ ] Android system Back opens Pause during a race.
- [ ] Background the app during a race and return: race remains safely paused.
- [ ] Engine, brake, Boost, near-miss, and crash audio behave correctly at low, medium, and high volume.
- [ ] No severe stutter, overheating, unexpected exit, or progressive slowdown during a 10-minute race.
- [ ] Best distance and score persist after closing and reopening the app.

## Release acceptance

- [ ] Every required check above passes on at least one physical Android phone.
- [ ] Tilt direction and multi-touch are confirmed on the target landscape device.
- [ ] No blocker remains open.
- [ ] Release keystore is safely backed up and the three GitHub Actions signing secrets are configured.
- [ ] Final signed APK export succeeds and the resulting APK installs and launches on the test phone.

Record failures with device model, Android version, exact reproduction steps, and a screenshot or screen recording where possible. Do not mark a check as passed based only on the headless CI workflow.
