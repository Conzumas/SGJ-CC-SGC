# SGJ-CC-SGC

Stargate Command-style ComputerCraft control system for **Stargate Journey** on Minecraft **1.21.1 NeoForge** with CC:Tweaked.

## Status

This is the Stargate Journey rewrite of the original [Conzumas/SGC-CC](https://github.com/Conzumas/SGC-CC) JSG project.

The rewrite keeps the SGC concepts—persistent address book, dialing, gate telemetry, iris security, GDO/IDC authentication, alarms, and event logging—but uses Stargate Journey's current ComputerCraft peripheral API instead of JSG APIs.

## Requirements

- Minecraft 1.21.1
- NeoForge
- Stargate Journey 0.6.x
- CC:Tweaked
- A Stargate Journey Basic/Crystal/Advanced Crystal Interface attached to the Stargate
- An iris-capable Stargate for iris controls

## Installation

Copy `src/sgc.lua` to the ComputerCraft computer and run it. The program stores its data in `sgc_data` and `sgc_events`.

The Stargate interface and optional Transceiver peripherals are discovered automatically. Crystal Interfaces expose the dialing API used by this program.

## Stargate Journey API

See `SGJ_API.md` for the API verified against the Stargate Journey source.

Important: Stargate Journey's iris controls are exposed directly by the Stargate interface. GDO/IDC authentication is supported by SGJourney through the separate `transceiver` peripheral; see `SGJ_API.md` for the verified interface and transceiver APIs.

## Source

- `src/sgc.lua` — main SGC control program
- `sgc_glyphs.lua` — monitor glyph/address reference
- `SGJ_API.md` — verified Stargate Journey CC API
- `REQUIREMENTS.md` — functional requirements

## Configuration

Edit the CONFIG table at the top of `src/sgc.lua` before installing it. Set `transceiver_frequency` and `idc_code` if you want incoming GDO/IDC authentication. The incoming iris remains fail-closed when no valid IDC has been received. Audio alarm drives can also be changed there.
