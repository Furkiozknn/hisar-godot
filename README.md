# 🏰 Hisar · Fortress Defense (Godot 4)

**[▶ Play in your browser](https://furkiozknn.github.io/hisar-godot/)** · Türkçe & English · desktop & mobile · free, no install

🏟️ Part of **[Claude Game Arena](https://github.com/Furkiozknn/claude-game-arena)**, round 2: every model remakes its own
round-1 browser game in Godot 4. This one was rebuilt by **Claude Opus 5.5** from its Three.js original,
[Hisar (kale-savunmasi)](https://github.com/Furkiozknn/kale-savunmasi). [See all games and the scorecard →](https://furkiozknn.github.io/claude-game-arena/)

A low-poly 3D tower defense: an enemy army marches on a seaside fortress along two roads.
Build towers on the stone pads, upgrade them and hold the fortress for 15 waves.
Same rules, numbers, names and Turkish / English text as round 1, rebuilt with a real engine.

![Battle](docs/battle.png)

| | |
|---|---|
| ![Title screen](docs/title.png) | ![Battering ram siege](docs/siege.png) |
| ![Build panel](docs/build.png) | ![Pause menu](docs/menu.png) |
| ![Victory](docs/gameover.png) | ![Defeat](docs/defeat.png) |

<p align="center"><img src="docs/phone.png" width="260" alt="Portrait phone layout"></p>

## Features

- Generated 3D models for the enemies, towers (bases and turrets), fortress and boats, shared with the
  browser version (see [Assets](#assets)); flat-shaded terrain, animated sea shader, two roads, forest,
  enemy camps with smoke and a banner (AnimationPlayer) built in code.
- Painted icons and a crest logo (title, HUD, end screen, project / web icon).
- Three towers with three levels each (Archer Tower, Cannon Bastion, Tar Cauldron) and four
  enemies (Raider, Rider, Shieldbearer, Battering ram boss), all in `data/*.tres`.
- Target modes (first / strongest / nearest), early wave calls with bonus gold, endless mode.
- Wave-start banner with the enemy line-up (red on a battering-ram wave).
- Juice: particle bursts, falling enemies, floating gold text, camera shake, damage vignette,
  pop-in tweens, boss health bar, fireworks on victory.
- Menus with transitions: title, pause, settings (master / music / effects volume, language,
  graphics quality, fullscreen) and end screen. Responsive layout down to 390x780 portrait,
  44 px touch targets on touch screens. Toasts in three kinds (good / bad / info).
- Synthesised music (9/8 aksak rhythm in the Hicaz mode) and sound effects, no audio files.
- Save system in `user://`: best wave (recorded after every cleared wave), settings, and the run in
  progress (continue from the title). First run picks the language from the OS and Low quality on phones.
- Keyboard, mouse, touch (pan, pinch, twist) and gamepad, all through the Input Map.

## Controls

| Action | Keyboard / mouse | Gamepad |
| --- | --- | --- |
| Select / build | Left click | A (pad nearest the camera focus) |
| Pan / rotate / zoom | Drag, arrows / right-drag, Q E / wheel, + - | Left stick / right stick / triggers |
| Next / previous pad | Tab / Shift+Tab | RB / LB |
| Build tower 1 2 3 | 1 2 3 | D-pad left / up / right |
| Upgrade / sell / target mode | U / S / T | X / - / D-pad down |
| Start wave / speed | Space / F | Y / Back |
| Pause / resume | P | Start |
| Back (close settings, then the pad panel, then pause) | Esc | B |
| Music / sound effects on-off | M / X | |
| Language | L | |

## Running and testing

Godot 4.7 standard, Compatibility renderer. Main scene: `res://scenes/main.tscn`.

```sh
godot_console --headless --path . --import
godot_console --headless --path . --scene res://tests/run_tests.tscn   # prints TESTS PASSED n/n
godot_console --path . -- --auto                                        # the bot plays the game
```

User arguments (after `--`): `--auto` (bot plays), `--speed=N`, `--sim=SECONDS` (fast-forward the
battle), `--shot=title|settings|build|tower|wave|pause|win|lose`, `--cam=close|fort|camp|top`,
`--lang=en`, `--low`, `--quit-on-end`, `--no-save`, `--noassets` (procedural models and vector icons, as before
the asset port), `--touch` (touch-size buttons on a desktop, for screenshots).
`GameState.get_state_text()` returns the current state as JSON.

The Web export preset is named `Web` and writes `build/web/index.html` (no threads).

## How it was made

Round 2 of a series in which **every game is built by a different AI model**. Each model gets the same brief,
[`prompts/godot-remake.md`](https://github.com/Furkiozknn/claude-game-arena/blob/main/prompts/godot-remake.md):
remake your own round-1 game in Godot 4.7 (GDScript, Compatibility renderer) and make it better, not just equal.
This one was built by **Claude Opus 5.5** (`claude-opus-5-5`) with [Claude Code](https://claude.com/claude-code).
The orchestrating session re-ran the checks independently before release:

- `TESTS PASSED 276/276` at release (472/472 after the 2026-10-21 passes), clean headless import (no errors or warnings).
- The `--auto` bot plays all 15 waves: `LOSS at wave 15/15, lives 0, kills 522` (the balance is unchanged from round 1,
  and the simple bot cannot hold the last battering ram). Like the browser bot, it never changes target modes.
- 60 FPS at 1280x720 on High quality on an Intel UHD 620 laptop GPU.

The web build is exported on GitHub's servers by [`.github/workflows/pages.yml`](.github/workflows/pages.yml)
(pinned, checksum-verified Godot 4.7.2 and export templates) and published to GitHub Pages.

## Assets

Models generated with Higgsfield Tripo, shared with the browser version
([kale-savunmasi/docs/assets.md](https://github.com/Furkiozknn/kale-savunmasi/blob/main/docs/assets.md) lists the prompts):
12 GLB files in `assets/models` (raider, rider, shield, ram, fortress, boat, three tower bases, three turrets),
unit-sized with the pivot at the base and WebP textures, imported natively by Godot. The 16 icons and the crest logo in
`assets/ui` were made with Higgsfield GPT Image.

`Models` (`scripts/view/models.gd`) applies the same transforms as the browser version: a yaw per model so all face +Z,
enemies scaled to the procedural model's height (never more than 1.15x its length), tower bases fitted per level
(height 5 / 5.8 / 6.6 archer, 1.7 / 2.2 / 2.7 cannon, 2.4 / 3.1 / 3.8 tar, footprint +6 % per level) with a pennant from
level 2 and a gold band at level 3, turrets 1.3 / 1.5 / 1.2 wide (+7 % per level) mounted on the measured platform
(49 / 77 / 86 % of the tower height), fortress x14 with its gate wall on x = 25, boat 3.6 tall. Meshes are rebuilt
flat-shaded with a textured material that still takes the MultiMesh tints (hit flash, slow). Every procedural builder
stays as the fallback (`--noassets`). The turret mount is visual only: the simulation keeps `TowerData.pivot` for the
muzzle, so the tests and the balance are unchanged (the browser version moved its muzzle to the new mount, so arrows
start a little higher here).

Terrain, trees, rocks, tents, projectiles, effects, music and sound are still made in code.

## License

Code: [MIT](LICENSE). Models, icons and the logo were generated with Higgsfield (Tripo, GPT Image) for this project
and its browser version; everything else is generated in code. No third-party assets.
