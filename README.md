# OpenHole

Open source (MIT) game in the spirit of hole.io: you are a hole in the ground
that swallows a procedurally generated city. Built with Godot 4.7 for Android.

## Modes
- **Classic** — 2 minutes vs 7 bots, biggest hole wins. Eaten holes respawn.
- **Solo** — alone, eat as much of the city as you can in 2 minutes.
- **Battle** — last hole standing; the safe zone shrinks.

- **Daily challenge** — Solo on a city that is the same for everyone that day.

Power-ups: magnet, speed, giant (+2 levels for a while), shield (cannot be eaten).
Eating things quickly in a row builds a combo (up to +50 % points).
Skins for your hole unlock with records. Settings: sound, vibration, camera shake,
FPS counter, bot skill and count, map theme and seed.

Buildings, buses, rocks and big trees break into chunks and collapse into the hole.
A hole too small for a skyscraper can still bite chunks off it.

## Download
Get the APK from [GitHub Releases](https://github.com/dsidxavekko/openhole/releases).
It is debug-signed, so Android asks to allow installing from unknown sources.

## Build
Requirements: Godot 4.7 (`~/.local/opt/godot/godot`), Android SDK build-tools,
JDK 17+, debug keystore (`~/.local/opt/debug.keystore`). Paths can be overridden
via `make GODOT=... ANDROID_HOME=... KEYSTORE=...`.

```sh
make test     # headless logic tests
make smoke    # full bot-driven match without graphics (MODE=classic|solo|battle|daily)
make apk      # build/openhole.apk
make install  # adb install + launch on a connected phone
make run-pc   # play on PC (WASD / arrows, mouse drag = joystick)
# screenshots: godot --path . --rendering-driver opengl3 -- --screenshot=menu.png [--shot-sheet=skins]
```

## How swallowing works
The ground is one solid collider; holes are drawn by cutting circles out in the
ground shader. When an object fits and overlaps a hole, its collision mask drops
the ground layer and it gets a push towards the middle, so it tips over and falls
through. Below the surface it is eaten and the hole gets points.

## How things fall apart
`Fracture` (`scripts/world/fracture.gd`) cuts a model into irregular chunks with
random planes and caps every cut; this runs on a worker thread when a match
starts. `Demolition` (`scripts/world/demolition.gd`) swaps a breakable object for
its chunks: all at once when it fits the hole, or frozen in place when only a
chunk fits. Each chunk knows which chunks rest on it, so when the hole takes the
ones underneath, the unsupported ones above come down.

## License
Code: MIT (see `LICENSE`). 3D models: Kenney, CC0. Font: Rubik, SIL OFL 1.1.
Details in `CREDITS.md`.
