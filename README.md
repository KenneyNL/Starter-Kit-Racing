<p align="center">
  <img src="icon.png" width="160" alt="Deja Vu Racing">
</p>

<h1 align="center">Deja Vu Racing</h1>

<p align="center">
  An arcade drift game in Godot, freely inspired by <em>Initial D</em> and JDM culture.<br>
  A fork of Kenney's <a href="https://github.com/KenneyNL/Starter-Kit-Racing">Starter Kit Racing</a> — no longer just the template.
</p>

<p align="center">
  <img src="screenshots/ss_mountan.png" alt="Daytime mountain descent">
</p>

> Work in progress · **Godot 4.7** (Forward+) · **Jolt** physics

## Play

1. Install [Godot 4.7](https://godotengine.org/download).
2. Clone the repository and open `project.godot`.
3. Press F5. The boot scene is `scenes/menu.tscn`.

From the menu: **Single Player**, choose a car, then choose a track. **Option** is still a placeholder.

## Controls

Keyboard, arrow keys, and a gamepad (left stick and triggers).

| Input | Action |
| --- | --- |
| <kbd>W</kbd> / <kbd>↑</kbd> / right trigger | Accelerate |
| <kbd>S</kbd> / <kbd>↓</kbd> / left trigger | Brake and reverse |
| <kbd>A</kbd> <kbd>D</kbd> / <kbd>←</kbd> <kbd>→</kbd> / left stick | Steer |
| <kbd>R</kbd> | Restart the descent. On the results screen: **Retry** |
| <kbd>Esc</kbd> | From the results screen, return to the menu |

The **Drift Bar** at the top fills with slip angle: six segments, from about 10° to 42°. It rises immediately and steps down one segment at a time.

## Tracks

<p align="center">
  <img src="screenshots/ss_track%20select.png" alt="Track select menu">
</p>

That menu screenshot is from before the latest entry. **Mountain Night** is in the menu now.

### Circuit

`scenes/main.tscn`. The kit's tile circuit, still a `GridMap`, with parked trucks as scenery. Free roam, no finish line. Selectable AE86 or RX-7, smoke, skid marks, and *Dejavu Kaze*.

<p align="center">
  <img src="screenshots/screenshot.png" alt="AE86 on the tile circuit">
</p>

### Mountain

`scenes/test_mountain.tscn`. A descent built at runtime from a `Path3D`: the first point is the start, the last point is the finish. The car runs at 1.5× the circuit speed.

- Terrain, asphalt, concrete lots, start and finish arches
- W-beam guardrails, posts, and reflectors. The collider is still the wall
- Hood and tail collide with walls, not only the physics sphere under the car
- The original kit trees, plus the **Kenney Nature Kit**: pines, bushes, grass, flowers, logs, and rocks on the inside of hairpins. Props near the road have colliders
- Pixel-art spectators at the start, raising their arms
- At the finish the game pauses: lap time, and for each Drift Bar level the share of the run spent at that angle. **Retry** reloads the scene, **Menu** goes back

### Mountain Night

`scenes/test_mountain_night.tscn`. The same road at night: moon, fog, glow, street lamps that fade out past a set distance, headlights and taillights on the AE86, and brighter guardrail reflectors.

<p align="center">
  <img src="screenshots/ss_night.png" alt="Mountain at night, headlights on">
</p>

## In the car

- **Toyota AE86** or **Mazda RX-7**, selectable before the track. The vehicle adapter binds each model to the same arcade physics and effects
- Rear-wheel smoke while drifting, and a screech that rises with intensity
- **Skid marks** on the asphalt, including on slopes. They last about a minute and fade over the last few seconds

<p align="center">
  <img src="screenshots/ss_skid_maarks.png" alt="Skid marks through a hairpin">
</p>

- Engine volume and pitch follow speed and throttle, plus an impact sound on collisions
- A chase camera that pulls back as you pick up speed
- A *Now Playing* banner when a scene starts, then it fades out
- A *Dejavu* edit in the menu; *Dejavu Kaze* during a race

## What the old README didn't cover

The previous text still described the template: basic controls, tiles, and how to swap the Kenney model. Since then this has become a game, not a kit to start from.

| Added | Where |
| --- | --- |
| Menu, splash, icon, track select | `scenes/menu.tscn` |
| Selectable AE86 / RX-7 with wheel roll and steering | `scenes/vehicle_selectable.tscn` |
| Six-segment Drift Bar | `scripts/drift_bar.gd` |
| Smoke, screech, engine, impact | `scripts/vehicle.gd` |
| Fading skid marks | `scripts/skid_marks.gd` |
| Mountain from a `Path3D`, with elevation and hairpins | `scripts/mountain_road.gd` |
| Guardrails, lots, arches, body collision | same scene, November 2026 |
| Recolored Nature Kit, rocks in hairpins | `assets/kenney_nature-kit/` |
| Billboard spectators | `scripts/spectators.gd` |
| Night: lamps, headlights, taillights, fog | `scripts/test_mountain_night.gd` |
| Race results (time and drift %) | `scripts/race_summary.gd` |
| Soundtrack and *Now Playing* banner | `ost/` |

## Customize

### Tile circuit

In `scenes/main.tscn`, select `GridMap` and place tiles from `models/Library` (including the tofu shop).

### Descent

In `scenes/test_mountain.tscn`, edit the `RoadPath` curve. On startup, `scripts/mountain_road.gd` rebuilds terrain, road, guardrails, and vegetation. Night mode reuses the same curve and the same logic.

### Car model

The selectable cars are `models/vehicle-toyota-ae86.glb` and `models/vehicle-toyota-mazdarx7.glb`, loaded by `scenes/vehicle_selectable.tscn`. The AE86 keeps its known `RootNode/Car/Wheel1` … `Wheel4` mapping; the RX-7 adapter discovers wheel nodes from the imported model and normalizes its visual scale.

The trucks and `scenes/vehicle-motorcycle.tscn` are still in the project, but not in the menu. Kenney models still expect the children `body`, `wheel-front-left`, `wheel-front-right`, `wheel-back-left`, and `wheel-back-right`.

## License

The code is [MIT](LICENSE), copyright Kenney / LemoniceIT.

Models, UI, and audio have their own licenses. The list is in [CREDITS.md](CREDITS.md).

**The Suno-generated music is non-commercial only.** The rest of the project does not make it freely redistributable.
