# SGJ-CC-SGC Requirements

## Target environment

- Minecraft 1.21.1 NeoForge
- Stargate Journey 0.6.x
- CC:Tweaked
- Stargate Journey interface peripheral

## Core goals

Build an SGC-style ComputerCraft control program that operates a Stargate Journey gate without depending on JSG-only APIs.

## Functional requirements

### Address book

- Persist named numeric Stargate addresses.
- Add, edit, remove, select, and dial saved addresses.
- Display address symbols.
- Preserve data across computer restarts.

### Dialing

- Dial saved addresses through Stargate Journey's `engageSymbol` API.
- Show chevron progress.
- Stop cleanly on API errors.
- Support resuming a partially engaged address when the gate reports engaged chevrons.
- Support Milky Way, Classic, Pegasus, Universe, and other interfaces where the installed interface exposes the required method.

### Gate monitoring

Display:

- Stargate type and generation.
- Connected/disconnected state.
- Outgoing/incoming state.
- Wormhole state.
- Stored energy.
- Energy target/capacity from the interface.
- Engaged chevrons.
- Open time.
- Local address where the interface exposes it.
- Connected/dialed address where the interface exposes it.

### Iris

Use only verified Stargate Journey iris methods:

- `getIris`
- `closeIris`
- `openIris`
- `stopIris`
- `getIrisProgress`
- `getIrisProgressPercentage`
- `getIrisDurability`
- `getIrisMaxDurability`

The default security policy is fail-closed when an incoming connection is detected.

### Incoming activation

Handle:

- `stargate_incoming_connection`
- `stargate_incoming_wormhole`
- `stargate_outgoing_wormhole`
- `stargate_disconnected`
- `stargate_chevron_engaged`
- `stargate_rotation_started`
- `stargate_rotation_stopped`

Incoming activation should never block the main UI.

### Event log

Persist useful operational events.

Do not log secrets. Stargate Journey's current CC API does not expose the old JSG iris/GDO-code mechanism, so no plaintext GDO code is collected.

### Reliability

1. Never invent a Stargate Journey method.
2. Catch Lua/API errors around peripheral calls.
3. Treat unknown iris state as unsafe for incoming connections.
4. Do not let a missing peripheral crash the entire program.
5. Keep event/security processing separate from the UI.
6. Persist the address book.
7. Keep Stargate Journey-specific API calls isolated in helper functions.
