# SGJ-CC-SGC Requirements

## Target environment

- Minecraft 1.21.1 NeoForge
- Stargate Journey 0.6.x
- CC:Tweaked
- Stargate Journey interface peripheral
- Optional Stargate Journey Transceiver peripheral for GDO/IDC authentication

## Core goals

Build an SGC-style ComputerCraft control program that operates a Stargate Journey gate without depending on JSG-only APIs.

## Functional requirements

### Address book

- Persist named numeric Stargate addresses.
- Add, edit, remove, select, and dial saved addresses.
- Display address symbols.
- Preserve data across computer restarts.

### Dialing

- Dial saved addresses through Stargate Journey engageSymbol.
- Show chevron progress.
- Stop cleanly on API errors.
- Resume a partially engaged address only when the existing encoded address matches the selected target.
- Support Milky Way, Classic, Pegasus, Universe, and other interfaces where the installed interface exposes the required method.
- Do not append to an unrelated active connection.

### Gate monitoring

Display:

- Stargate type and generation.
- Connected/disconnected state.
- Outgoing/incoming state.
- Wormhole state.
- Stored Stargate energy.
- Interface FE energy, target, and capacity.
- Engaged chevrons.
- Open time.
- Local address where the interface exposes it.
- Connected/dialed address where the interface exposes it.
- Iris telemetry where supported.
- Transceiver status/frequency where a transceiver is installed.

### Iris

Use only verified Stargate Journey iris methods:

- getIris
- closeIris
- openIris
- stopIris
- getIrisProgress
- getIrisProgressPercentage
- getIrisDurability
- getIrisMaxDurability

The default security policy is fail-closed when an incoming connection is detected. If no iris is installed, the program must report that the incoming connection cannot be secured rather than claiming the gate is protected.

### GDO / IDC / Transceiver

Use Stargate Journey's standalone transceiver peripheral for IDC/GDO handling:

- setFrequency
- setCurrentCode
- sendTransmission
- checkConnectedShielding
- getCurrentCode
- getFrequency
- transceiver_transmission_received

Incoming IDC authentication must require an active incoming Stargate connection plus the configured frequency and IDC. The received IDC itself must never be written to the persistent event log.

### Incoming activation

Handle:

- stargate_incoming_connection
- stargate_incoming_wormhole
- stargate_outgoing_wormhole
- stargate_disconnected
- stargate_reset
- stargate_chevron_engaged
- stargate_deconstructing_entity
- stargate_reconstructing_entity
- stargate_message_received
- transceiver_transmission_received

Incoming activation/security processing must never block the main UI.

### Event log

Persist useful operational events.

Do not log IDC secrets or received IDC values.

### Reliability

1. Never invent a Stargate Journey method.
2. Catch Lua/API errors around peripheral calls.
3. Treat unknown iris state as unsafe for incoming connections.
4. Do not let a missing peripheral crash the entire program.
5. Keep event/security processing separate from the UI.
6. Persist the address book.
7. Keep Stargate Journey-specific API calls isolated in helper functions.
