# Verified Stargate Journey ComputerCraft API

Target: Stargate Journey source for the current 1.21.1 NeoForge line.

## Peripheral

Stargate Journey exposes Stargate control through an interface peripheral. Common interface types include:

- `basic_interface`
- `crystal_interface`
- `advanced_crystal_interface`

The Stargate peripheral inherits the interface's energy methods.

## Stargate methods

Verified on `StargatePeripheral`:

- `getStargateGeneration()`
- `getStargateType()`
- `isStargateConnected()`
- `isStargateDialingOut()`
- `isWormholeOpen()`
- `getStargateEnergy()`
- `getChevronsEngaged()`
- `getOpenTime()`
- `disconnectStargate()`

## Interface energy methods

Verified on `InterfacePeripheral`:

- `getEnergy()`
- `getEnergyCapacity()`
- `getEnergyTarget()`
- `setEnergyTarget(target)`
- `addressToString(table)`

## Generic Stargate methods

Depending on Stargate type/interface:

- `getRecentFeedback()`
- `sendStargateMessage(message)`
- `getStargateVariant()`
- `getPointOfOrigin()`
- `getSymbols()`
- `engageStargate()`
- `engageSymbol(symbol, engageDirectly, canEngageStargate)`
- `getDialedAddress()`
- `setChevronConfiguration(table)`
- `remapSymbol(originalSymbol, newSymbol)`
- `getMappedSymbol(symbol)`
- `hasDHD()`
- `getNetworks()`
- `addNetwork(network)`
- `removeNetwork(network)`
- `restrictNetwork(value)`
- `isNetworkRestricted()`
- `getConnectedAddress()`
- `getLocalAddress()`

## Rotation methods

For rotating Stargates:

- `getCurrentSymbol()`
- `isCurrentSymbol(symbol)`
- `encodeChevron()`
- `getRotation()`
- `getRotationDegrees()`
- `rotateClockwise(symbol)`
- `rotateAntiClockwise(symbol)`
- `endRotation()`

Milky Way Stargates additionally expose:

- `openChevron()`
- `closeChevron()`
- `isChevronOpen()`

## Iris methods

For iris-capable Stargates:

- `getIris()`
- `closeIris()`
- `openIris()`
- `stopIris()`
- `getIrisProgress()`
- `getIrisProgressPercentage()`
- `getIrisDurability()`
- `getIrisMaxDurability()`

## Events

Verified Stargate Journey event names include:

- `stargate_incoming_connection`
- `stargate_incoming_wormhole`
- `stargate_outgoing_wormhole`
- `stargate_disconnected`
- `stargate_rotation_started`
- `stargate_rotation_stopped`
- `stargate_chevron_engaged`

Interface events prepend the computer's peripheral attachment name to the event payload. The SGC program therefore strips the first payload value when processing these events.

## Important difference from JSG

The old SGC-CC project depended on JSG's iris/GDO methods such as `sendIrisCode` and `getIrisState`. Stargate Journey's current CC implementation exposes direct iris controls and telemetry instead, but no equivalent GDO-code method was found in the verified API. SGJ-CC-SGC does not invent one.

## Source verification

Verified against Stargate Journey source files including:

- `StargatePeripheral.java`
- `InterfacePeripheral.java`
- `CCTweakedCompatibility.java`
- `StargateMethods.java`
- `IrisMethods.java`
- `RotationMethods.java`
- `MilkyWayStargateMethods.java`
- `GenericStargateFunctions.java`
- `StargateConnection.java`
