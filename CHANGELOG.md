# Change Log

## 3.0.6
* Host scans run in a single isolate, resolve details lazily and forward MAC/host name.
* Isolates and ports are always cleaned up; scan errors and cancellation no longer hang.
* Progress now reports per host and always reaches 100%.
* mDNS scans run with bounded concurrency, stop after a quiet period and deduplicate results.
* mDNS service-type enumeration is cached between calls for five minutes.
* mDNS TXT values are decoded as UTF-8; only a validated `mac` TXT entry is used, the Bluetooth `bt` entry is ignored.
* `configureNetworkToolsFlutter` accepts `buildVendorTable`, builds the table in the background, and no longer leaks log subscriptions.
* `HostScanException` reports isolate crashes and scan failures distinctly while remaining a `StateError`.
* Minimum Dart SDK raised to 3.10 and Flutter to 3.38; `network_tools` pinned to the 6.0 line and `nsd` to 4.x.
* Example app rebuilt around the current API; host rows and the details page show the MAC address, including when it is unavailable.
* Documented macOS sandbox, local-network and macOS 27 ARP entitlement requirements.

## 3.0.5
* Bug fixes and improvements.

## 3.0.4
* Improve test coverage and fix analysis warnings.
* Fix CI triggers for coverage tracking.

## 3.0.3
Upgrade to latest network_tools

## 3.0.2
Mac vendor improvements

## 3.0.1
ARP protocol improvements

## 3.0.0
Performance improvements

## 2.0.7
Scan fixed for android

## 2.0.6
Publish using setup-dart workflow

## 2.0.5
Bug fixes and improvements

## 2.0.4
1. Coverage fix for codecov

## 2.0.3
1. Dependencies updated.

## 2.0.2
1. Mdns search works on iOS now.

## 2.0.1
1. Bug fixes and improvements

## 2.0.0
1. Unified framework for network_tools and network_tools_flutter

**Breaking change** Replace these occurences in your project

    * HostScannerFlutter to HostScannerService.instance
    * PortScannerFlutter to PortScannerService.instance


## 1.0.5

1. scanPortsForSingleDevice and customDiscover supports async mode now.

## 1.0.4

1. Use network_tools v4.0.1 to fix path issue in flutter.

## 1.0.3 

1. Consume latest version of network_tools v4.0.0

## 1.0.2

* Added flutter example and updated pubspec with relevant sections.

## 1.0.1

* Bug fixes and improvements, add more tests for coverage

## 1.0.0

* Initial support added for ping_ios_dart in network_tools
