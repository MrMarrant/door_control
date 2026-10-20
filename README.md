# Control Door

Garry's Mod addon (DarkRP / Sandbox) that adds **control doors**, heavily inspired by the doors in the game Control Resonant.

## How it works in game

1. **Unstable door** (default state when spawned): ghost doors scroll endlessly through the frame, with an ambient sound.
2. **Stabilization**: a player uses the frame (`E` key). The door becomes **stable**: the ghosts disappear and a fixed door appears in the frame.
3. **Travel**: using a stable door opens a full-screen menu:
   - on the left, the list of the other stable doors (with their distance);
   - on the right, a top-down view of the map showing the doors and the player.

   Clicking a door selects it: the screen fades to white, the player is teleported in front of the chosen door, then the flash fades out.

## Installation

1. Put the `door_control` folder in `garrysmod/addons/`.
2. Restart the server.
3. That's it.

## Usage

| Action | How |
| --- | --- |
| Spawn a door | Sandbox menu → Entities → **Control Door**, or the `control_door_spawn` command (superadmins only) while aiming at the ground |
| Stabilize a door | Use (`E`) an unstable door |
| Travel | Use (`E`) a stable door, then click a destination |
| Close the menu | "◀ Quit" button or `Esc` |

## Configuration

All settings are in [`lua/control_door/sh_config.lua`](lua/control_door/sh_config.lua):

| Group | Variables | Purpose |
| --- | --- | --- |
| Models | `FrameModel`, `DoorModels`, `ExitSignModel`, `ExitSignAngles`, `ExitSignOffset` | Frame, possible ghost door models, sign placed on top of the frame |
| Ghost doors | `ScrollInterval`, `ScrollDuration`, `GhostFallSpeed`, `DistanceScroll`, `GhostColor`, `GhostModelScale`, `GhostRenderDistance` | Spawn rate, lifetime, fall speed and direction, appearance, render distance |
| Door position | `PortalOffset`, `PortalStableOffset`, `PortalOffsetMinDiff`, `PortalOffsetMaxDiff` | Position of the doors (ghost and stable) inside the frame, and random offset of the ghosts |
| Stable door camera | `PortalCamera` (`Distance`, `Height`, `Fov`, `Resolution`, `RenderDistance`, `FrameRate`) | Camera placement, render quality and cost |
| Screen effects | `PortalTint` (`Color`, `Strength`), `PortalWave` (`Amplitude`, `Frequency`, `Speed`, `Subdivisions`) | Image tint and wave effect |
| Teleportation | `TeleportFlashDuration`, `TeleportFlashColor` | Flash duration and color |
| Map menu | `MapListWidth`, `MapViewCeilingClip` | List width, skybox ceiling clipping in the top-down view |
| Sounds | `Sounds` (`UnstableLoop`, `StableOpen`, `Click`) | Sounds played (paths relative to `sound/`) |

## GameModes

- All gamemodes

## Dependencies

- None

## License

Released under the [MIT License](LICENSE): you may use, modify and redistribute this addon, as long as the copyright notice crediting **MrMarrant** is kept.
