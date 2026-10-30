# network_tools_flutter example

A small app that exercises every public API of `network_tools_flutter` (and,
through it, `network_tools`). It works as a manual test harness: each screen
exposes all parameters of the underlying method, shows progress, supports
cancellation where the API allows it, and prints full result objects.

## Running

```sh
flutter pub get
flutter run            # pick a connected device or desktop target
```

The app configures the package on startup:

```dart
await configureNetworkToolsFlutter(appDocDirectory.path, enableDebugging: true);
```

Android and iOS need local-network permission for mDNS; see the package
[README](../README.md#mdns-search) for the manifest/plist entries.

On macOS, the Runner builds with App Sandbox disabled (see
`macos/Runner/*.entitlements`) and declares `NSLocalNetworkUsageDescription` /
`NSBonjourServices` in `macos/Runner/Info.plist`, because the sandbox returns an
empty ARP table. On macOS 27 and later, ARP reads additionally require Apple's
restricted `com.apple.developer.networking.topology-observation` entitlement;
without it the MAC address field shows `<not available>` even though host
discovery works. See the package [README](../README.md#macos-mac-addresses-and-local-network).

## What each screen covers

| Screen | API |
| --- | --- |
| Pingable devices | `HostScannerService.getAllPingableDevices()` |
| Pingable devices (isolate) | `HostScannerService.getAllPingableDevicesAsync()` |
| Sendable devices | `HostScannerService.getAllSendablePingableDevices()` |
| Subnet sweep for one port | `HostScannerService.scanDevicesForSinglePort()` |
| Port range scan | `PortScannerService.scanPortsForSingleDevice()` |
| Custom port list scan | `PortScannerService.customDiscover()` |
| Single port check | `PortScannerService.isOpen()` |
| Connect to a port | `PortScannerService.connectToPort()` (with `activeHostsController`) |
| Discover mDNS devices | `MdnsScannerService.searchMdnsDevices()` |
| Find by service type | `MdnsScannerService.findingMdnsWithAddress()` |
| Raw mDNS records | `MdnsScannerService.findAllActiveHostForSrv()` + `convertSrvToHostName()` |
| Host details lookup | `ActiveHost.resolveInfo()`, `hostName`, `weirdHostName`, `deviceName`, `getMacAddress()`, `arpData`, `vendor`, `mdnsInfo`, `pingData`, `getPingData()`, `toStringFull()` |
| Reconfigure network tools | `configureNetworkToolsFlutter(rebuildData: true)` |
| Home header | `NetInterface.localInterface()` and `HostScannerService.validateAndGetLastValidSubnet()` (shown while editing the host range) |

Tapping any discovered host opens the details screen, which resolves and prints
every `ActiveHost` getter, including ARP, vendor and mDNS data.

## Testing against a local checkout of network_tools

`example/pubspec.yaml` references the package by path:

```yaml
network_tools_flutter:
  path: ..
```

To also test an unpublished `network_tools`, add an override in
`example/pubspec.yaml`:

```yaml
dependency_overrides:
  network_tools:
    path: ../../../network_tools
```
