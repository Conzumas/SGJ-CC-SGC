# Verified Stargate Journey ComputerCraft API

Target: Stargate Journey ComputerCraft integration for the 1.21.1 NeoForge line.

Official documentation: https://povstalec.github.io/StargateJourney/computercraft/

## Interface peripherals

Stargate Journey provides three interface peripheral types:

- `basic_interface`
- `crystal_interface`
- `advanced_crystal_interface`

A computer must be directly adjacent to the interface or connected with an activated wired modem. Wireless modems are not supported for connecting the interface.

## Common interface methods

Verified:

- `addressToString(address)`
- `getEnergy()`
- `getEnergyCapacity()`
- `getEnergyTarget()`
- `setEnergyTarget(energyTarget)`

The interface energy methods report Forge Energy (FE) stored in the interface. `getStargateEnergy()` is separate and reports Stargate energy.

## Stargate methods

Verified:

- `disconnectStargate()`
- `engageStargate()`
- `getChevronsEngaged()`
- `getOpenTime()`
- `getPointOfOrigin()`
- `getRecentFeedback()`
- `getStargateEnergy()`
- `getStargateGeneration()`
- `getStargateType()`
- `getStargateVariant()`
- `getSymbols()`
- `isStargateConnected()`
- `isStargateDialingOut()`
- `isWormholeOpen()`
- `sendStargateMessage(message)`
- `engageSymbol(symbol, engageDirectly, canEngageStargate)`
- `getDialedAddress()`
- `getMappedSymbol(symbol)`
- `hasDHD()`
- `remapSymbol(originalSymbol, newSymbol)`
- `setChevronConfiguration(configuration)`

`getSymbols()` returns a **string resource location**, such as `sgjourney:terra`; it does not return an array of numeric glyphs. `engageSymbol()` accepts numeric symbol IDs.

### Dialing behavior

The official example encodes an address with:

`interface.engageSymbol(symbol)`

and then waits for `getDialedAddress()` to contain the complete address before calling:

`interface.engageStargate()`

The Point of Origin must be included in the address. The example explicitly uses `canEngageStargate = false` when encoding so the final engagement is controlled separately. SGJ-CC-SGC follows that model.

## Address methods

- `getDialedAddress()` — Crystal/Advanced Crystal; returns the outgoing dialed address.
- `getConnectedAddress()` — Advanced Crystal; returns the connected address.
- `getLocalAddress()` — Advanced Crystal; returns the local 9-chevron address.
- `addressToString(address)` — formats an address as `-26-6-14-31-11-29-`.

An empty/non-applicable address is represented by an empty table.

## Iris methods

Verified:

- `getIris()`
- `closeIris()`
- `openIris()`
- `stopIris()`
- `getIrisProgress()`
- `getIrisProgressPercentage()`
- `getIrisDurability()`
- `getIrisMaxDurability()`

`getIris()` returns the installed iris resource identifier or `nil`. Iris progress percentage is 0 when fully open/not installed and 100 when fully closed. The iris methods are not available for Tollan because Tollan cannot have an iris.

## Rotation

For Classic, Universe, and Milky Way Stargates:

- `getCurrentSymbol()`
- `isCurrentSymbol(symbol)`
- `getRotation()`
- `getRotationDegrees()`
- `rotateClockwise(symbol)`
- `rotateAntiClockwise(symbol)`
- `endRotation()`
- `encodeChevron()`

Milky Way additionally has:

- `openChevron()`
- `closeChevron()`
- `isChevronOpen()`

Pegasus additionally has:

- `dynamicSymbols(enabled)`
- `overrideSymbols(symbols)`
- `overridePointOfOrigin(pointOfOrigin)`

These are documented by the official Stargate Interface API.

## Networks and filtering

Advanced Crystal exposes network/filter controls including:

- `getNetworks()`
- `addNetwork(network)`
- `removeNetwork(network)`
- `restrictNetwork(restrict)`
- `isNetworkRestricted()`
- `getFilterType()`
- `setFilterType(type)`
- `getPublicBlacklist()`
- `getPublicWhitelist()`
- `addToBlacklist(address)`
- `removeFromBlacklist(address)`
- `addToWhitelist(address)`
- `removeFromWhitelist(address)`

Filter types are 0 for none, 1 for whitelist, and -1 for blacklist.

## Events

Verified Stargate interface events:

- `stargate_chevron_engaged`
- `stargate_incoming_connection`
- `stargate_incoming_wormhole`
- `stargate_outgoing_wormhole`
- `stargate_disconnected`
- `stargate_reset`
- `stargate_deconstructing_entity`
- `stargate_reconstructing_entity`
- `stargate_message_received`

The first argument after the event name is the peripheral name. For an Advanced Crystal Interface, incoming-wormhole events include the connected address; outgoing-wormhole events include the dialed address; chevron events include the engaged count, chevron identifier, incoming/outgoing flag, and symbol where supported.

## Transceiver / GDO / IDC

Stargate Journey **does support GDO-style identification codes**, but this is exposed through the separate `transceiver` peripheral rather than the Stargate interface.

Verified transceiver methods:

- `setFrequency(frequency)`
- `setCurrentCode(idc)`
- `sendTransmission()`
- `checkConnectedShielding()`
- `getCurrentCode()`
- `getFrequency()`

The transceiver raises `transceiver_transmission_received`, containing the frequency, received IDC, and whether the received code matches the transceiver's configured IDC. This is the correct SGJ mechanism for IDC/GDO authentication.

## JSG compatibility warning

Do **not** use JSG-only calls such as `sendIrisCode()` or `getIrisState()`. SGJourney has its own direct iris API and a separate Transceiver/IDC system.

SGJ-CC-SGC is intended to use only the documented Stargate Journey ComputerCraft API.
