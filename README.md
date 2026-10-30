# Network Tools Flutter

[![pub package](https://img.shields.io/pub/v/network_tools_flutter.svg)](https://pub.dev/packages/network_tools_flutter) [![Dart](https://github.com/osociety/network_tools_flutter/actions/workflows/flutter.yml/badge.svg)](https://github.com/osociety/network_tools_flutter/actions/workflows/flutter.yml) [![codecov](https://codecov.io/gh/osociety/network_tools_flutter/graph/badge.svg?token=X8UVO7RUA4)](https://codecov.io/gh/osociety/network_tools_flutter)

## Features

This package will add support for flutter features which is out of the scope of [network_tools](https://github.com/osociety/network_tools) because of platform limitations.

## Getting started

## Usage
Add the dependency to `pubspec.yaml`. `path_provider` is needed by this example
to locate the application support directory:

```yml
dependencies:
  flutter:
    sdk: flutter
    
  network_tools_flutter: ^3.0.6
  path_provider: ^2.1.5
```



Initialize the package in `main`:

```dart
 await configureNetworkToolsFlutter((await getApplicationSupportDirectory()).path);
```

Prefer the application support directory (not documents) on iOS: the database
is internal state and should not be user-visible or backed up as a document.

The ARP table is ready when the future completes. The optional MAC vendor
table is built in the background, so the first-run download never delays
startup. Pass `buildVendorTable: false` to skip it entirely:

```dart
 await configureNetworkToolsFlutter(
   (await getApplicationSupportDirectory()).path,
   buildVendorTable: false,
 );
```

Changing `dbDirectory` or `enableDebugging` after the first call has no effect
unless you pass `rebuildData: true`; the package logs a warning when that
happens.


Host scans raise `HostScanException` (a `StateError` subtype) when the scan
isolate crashes or reports an error, so callers can tell the two apart through
`kind`:

```dart
try {
  await for (final host in HostScannerService.instance.getAllPingableDevices(subnet)) {
    // ...
  }
} on HostScanException catch (error) {
  // error.kind is HostScanFailureKind.isolateCrash or .scanError
}
```

## Example

See the [example](example/) directory for a complete Flutter app using this package. It showcases every public method of `network_tools_flutter` and `network_tools` (host discovery, port scanning, mDNS, `ActiveHost` resolution and reconfiguration) and doubles as a manual test harness, so you can run it on a device to exercise the packages standalone.

From here please follow the documentation of [network_tools](https://pub.dev/packages/network_tools) as they are the same.


## macOS: MAC addresses and local network

`ActiveHost.getMacAddress()` reads the system ARP table through `/usr/sbin/arp`. On macOS:

- **App Sandbox** must be disabled for direct/Developer ID builds. A sandboxed app receives an empty ARP table, so MAC addresses and vendor lookups are unavailable. Mac App Store builds cannot disable the sandbox.
- **macOS 27 and later** also require the restricted entitlement `com.apple.developer.networking.topology-observation` for any third-party process reading the ARP table. Without it, `arp` exits successfully but returns no entries. The entitlement must be granted by Apple, and an ad-hoc signed build carrying it is killed at launch.
- mDNS TXT records that advertise a `mac` key are still mapped to `ActiveHost.macAddress` when a device publishes one.

Add these keys to `macos/Runner/Info.plist` so macOS shows the local-network prompt and allows Bonjour lookups:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Required to discover devices on the local network.</string>
<key>NSBonjourServices</key>
<array>
    <string>_services._dns-sd._udp</string>
</array>
```

## mDNS search

For mDNS search on Android, make sure your minimum API level is 21 and add the following permissions to the manifest file:

```
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
```

And for iOS add permissions to the Info.plist (replace service type with your own):

```
<key>NSLocalNetworkUsageDescription</key>
<string>Required to discover local network devices</string>
<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
    <!-- Required for service-type enumeration (searchMdnsDevices). -->
    <string>_services._dns-sd._udp</string>
</array>

```

List every service type you browse. On iOS 14+, mDNS results are silently
empty when a browsed type is missing from `NSBonjourServices`.

