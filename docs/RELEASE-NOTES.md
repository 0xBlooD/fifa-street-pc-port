# ReStreet - FIFA Street 2012 Recompiled v1.2

Smoother frame rate in the whole game, sharp Vulkan replays, and an update that removes the online patch. This version is offline only.

## Improved in v1.2

- **Cutscenes and goal replays are no longer capped at 40 FPS.** The game has its own frame limiter that held them at 40 FPS. It now follows the refresh rate chosen in the launcher.
- **Goals and match setup no longer drop to 30-40 FPS.** A forced wait for the graphics card on every frame was removed.
- **Menus run at 60 FPS** instead of 30.

## Fixed

- **Vulkan: goal replays were blurred.** They are now as sharp as in Direct3D 12.
- **Direct3D 12 with VSync on could fall to 1 FPS** on some laptops. Measured on an RTX 4060 Laptop: 0.6 FPS to a steady 60 FPS in the same scene.
- **Updating works over v1.1 with or without the online patch.** If the online patch is installed, the update removes it (online.json, online-patch.json, the OnlinePatch folder, tools\ReStreetAssetExplorer.exe and the stadium pictures). A copy of the replaced files is kept in `.updates`. Saves, game data and launcher settings are kept.

## Known limitations

- With VSync on above 60 Hz, some scenes can run at half the refresh rate (for example 50 FPS at 100 Hz). Turn VSync off (ideally with VRR) for an unlocked frame rate.
- With VSync on in Direct3D 12 you may see tearing in fullscreen.
- Vulkan still runs at 30 FPS outside menus on some PCs. Direct3D 12 is recommended.

## How to install

1. Download `FifaStreetSetup.exe` and check its SHA-256 against the value on the release page.
2. Run it, choose your own FIFA Street (2012) Xbox 360 ISO and an empty folder, and press **INSTALL ReStreet**.
3. Press **OPEN LAUNCHER**, then **PLAY**.

To update, select the folder that contains `Game` and `GameData`. No ISO is needed.

## Requirements (estimates)

Windows 10 or 11 (64-bit), a CPU with SSSE3, a Direct3D 12 or Vulkan GPU (about GTX 900 / RX 400 or newer), 8 GB RAM and 12 GB of free disk space. On a weaker PC use the Performance profile. See [STATUS.md](STATUS.md) for what was and was not tested.

## Notes

- Performance depends on your hardware and drivers; the profiles are starting points, not guarantees.
- The installer includes generated game binaries. The project's MIT licence does not establish the right to redistribute them, and no legal clearance is claimed.
- The Mods logo patch is derived from the game's own art.
- This is an unofficial community project, with no affiliation to EA, Microsoft or Xbox.
