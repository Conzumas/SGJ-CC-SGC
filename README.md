# SGJ-CC-SGC

Stargate Command-style ComputerCraft control system for **Stargate Journey** on Minecraft **1.21.1 NeoForge** with CC:Tweaked.

## Status

This is the Stargate Journey rewrite of the original [Conzumas/SGC-CC](https://github.com/Conzumas/SGC-CC) JSG project.

The rewrite keeps the SGC concepts—persistent address book, dialing, gate telemetry, iris security, alarms, and event logging—but uses Stargate Journey's current ComputerCraft peripheral API instead of JSG APIs.

## Requirements

- Minecraft 1.21.1
- NeoForge
- Stargate Journey 0.6.x
- CC:Tweaked
- A Stargate Journey Basic/Crystal/Advanced Crystal Interface attached to the Stargate
- An iris-capable Stargate for iris controls

## Installation

Copy `src/sgc.lua` to the ComputerCraft computer and run it. The program stores its data in `sgc_data` and `sgc_events`.

The peripheral is discovered automatically. Crystal Interfaces expose the dialing API used by this program.

## Stargate Journey API

See `SGJ_API.md` for the API verified against the Stargate Journey source.

Important: Stargate Journey does **not** expose the old JSG GDO/iris-code API used by the original project. This version therefore does not pretend that GDO authentication exists. Iris security is implemented with the APIs Stargate Journey actually exposes.

## Source

- `src/sgc.lua` — main SGC control program
- `sgc_glyphs.lua` — monitor glyph/address reference
- `SGJ_API.md` — verified Stargate Journey CC API
- `REQUIREMENTS.md` — functional requirements
