# Changelog

## 2026-10-21 overnight pass

Ports the browser version's asset remaster to Godot, fixes the Godot bugs from the review and closes design-language gaps.
Rules, numbers and balance are unchanged.

### Assets (shared with the browser version)

- 12 generated GLB models in `assets/models` replace the procedural enemies, tower bases, turrets, fortress and boats.
  Same transforms as the browser build (`MODEL_YAW`, `TOWER_FIT`, `HEAD_SIZE`, enemy height rule, fortress x14 on the
  gate line, boat 3.6 tall), rebuilt flat-shaded with a textured material that keeps the MultiMesh hit / slow tints.
  Level 2 towers get a pennant and level 3 a gold band, fitted to the model. Procedural builders stay as the fallback
  (`--noassets`). Import: no LODs, no tangents, no animation.
- Turrets sit on the measured platform height (visual only; the sim keeps `TowerData.pivot`). Pad picking uses the new,
  taller tower height.
- The generated fortress replaces the procedural one (with its courtyard props); one banner flies over the keep.
- 16 painted PNG icons replace the vector drawings where a picture exists (HUD, build cards, tower panel, wave preview,
  boss bar, title, end screen). New icons on the Upgrade and Target buttons; the defeat card shows the fortress icon.
- Crest logo on the title card and in the HUD; it is also the project / web export icon.

### Bugs fixed (review section 4)

- G1: the best wave is saved after every cleared wave, not only at game end; a mid-run record shows a "New best!" toast once.
- G2: P (and Start) always pauses; Esc (and B) goes back: settings, then the pad panel, then pause.
- G3: buttons are at least 44 px on screen on touch devices (HUD, wave button, build cards, tower panel, close, menus).
- G4: the tower panel's kill count updates live.
- G5: the sound button restores the volume from before the mute; new keys M (music) and X (sound effects), saved.
- G6: volume sliders apply live and save when the drag ends (or when leaving settings), with one sample sound.
- G7: changing a setting no longer replays the card animation or moves keyboard / gamepad focus.
- G8: first run uses the OS language and Low quality on phones / tablets.
- G9: the music loop is rendered in 6 ms slices per frame, so the title never freezes (the web build has no threads).
- G10: continuing a run shows "Wave n ahead · run restored" instead of the button label.
- G11: Play / Restart clears the abandoned run, so Continue cannot bring it back.
- G13: a pinch or twist no longer selects a pad when the first finger lifts.
- G15: credits and README licence text mention the generated assets.
- G16: icon buttons use an icon + label box instead of padding the text with spaces.
- G18: on narrow landscape windows the tower panel no longer overlaps the wave box.
- Dead code removed: `TowerData.icon_color`, `Loc.has_key()`, `AutoBot.auto_endless`, `Sound.music_ready`,
  `MapLayout.GATE`, `Ui.speed`, `CameraRig.input_enabled`, `GameState.games_played`, string key `level`.

### UI / design language

- Title footer "Claude Game Arena · built by Claude Opus 5.5"; window title "Hisar · <subtitle>".
- Toast kinds: good (green edge), bad (red edge), info.
- The wave button reads "Wave n running…" instead of "-" while the last enemies of a wave are still on the field.
- New command-line flags: `--noassets`, `--touch`.

### Not changed on purpose

- G12 ("First" targeting by road fraction) and G14 (the bot's cannon mode switch): kept so the bot result stays
  comparable with earlier runs; the browser version still uses the same targeting rule.

### Checks

- Headless import: no errors or warnings. `TESTS PASSED 469/469` (was 276; new tests for the asset transforms, fallback,
  icons, input map, mute restore and per-wave best).
- `--auto` bot, full run: `LOSS at wave 15/15, lives 0, kills 522, towers built 13` (same as before).
- Movie Maker frames checked: title, busy battle (overview and close), build panel, tower panel, pause, settings,
  victory, defeat, Low quality, and 390x780 portrait (title, build, tower panel with `--touch`). README images replaced.
