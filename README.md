# Orbit Collector

Orbit Collector is a 2D arcade game for Godot 4.7. Collect gold orbs, dodge pink drones, and clear five sectors with three lives.

## Run the project

Extract the ZIP. In Godot Project Manager, import `OrbitCollector/project.godot`, open the project, and press F5. Select **Start Game** or **How to Play** on the main menu.

| Control | Action |
| --- | --- |
| WASD or arrow keys | Move |
| Space | Dash in the last movement direction, or right at the start of a sector |
| M or the Sound button | Toggle music and sound effects |
| R | Restart from Sector 1 during a run or on a results screen |
| Esc | Return to the main menu and end the current run |

Each orb adds one point and respawns elsewhere. A drone collision costs one life and gives you 1.3 seconds of protection. Choose an upgrade after each of the first four sectors. Your choice starts the next sector. Lives and total score carry forward. Clear Sector 5 to win with 100 points. Losing all three lives ends the run.

| Sector | Orb target | Drones | Drone speed (pixels/sec) |
| --- | ---: | ---: | ---: |
| 1 | 10 | 3 | 90–145 |
| 2 | 15 | 4 | 108–163 |
| 3 | 20 | 5 | 126–181 |
| 4 | 25 | 6 | 144–199 |
| 5 | 30 | 8 | 162–217 |

## Sector upgrades

- **Quick Recharge** reduces the 2-second dash cooldown by 0.3 seconds per pick. Dash briefly protects you from drone damage.
- **Orb Magnet** adds 12 pixels of pickup range per pick. The gold ring shows the new range.
- **Shield** adds one charge that absorbs a drone hit. Unused charges carry between sectors.

Upgrade picks stack and reset when you start a new run. The HUD shows dash readiness and remaining shield charges.

## Project structure

- `scenes/main.tscn` is the entry scene.
- `scripts/game.gd` draws the arena with Node2D, handles movement and distance-based collisions, and builds the menu and HUD with Godot Control nodes.
- `scripts/orbit_audio.gd` generates an original looping melody and six cues from synthesized notes. It uses AudioStreamWAV and AudioStreamPlayer. ConfigFile stores the mute preference between launches.

## Verification

Godot 4.7.2 on Windows loaded the project in headless mode. A scripted check exercised menu actions, arrow movement, mute and preference storage, orb collection across all five sectors, victory, dash movement and cooldown, all three upgrades, damage cooldown, defeat, and restart. Desktop rendering, audible playback, and hands-on gameplay remain untested.


