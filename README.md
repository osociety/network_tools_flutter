# Network Tools Flutter

[![pub package](https://img.shields.io/pub/v/network_tools_flutter.svg)](https://pub.dev/packages/network_tools_flutter) [![Dart](https://github.com/osociety/network_tools_flutter/actions/workflows/flutter.yml/badge.svg)](https://github.com/osociety/network_tools_flutter/actions/workflows/flutter.yml) [![codecov](https://codecov.io/gh/osociety/network_tools_flutter/graph/badge.svg?token=X8UVO7RUA4)](https://codecov.io/gh/osociety/network_tools_flutter)

## Features

This package will add support for flutter features which is out of the scope of [network_tools](https://github.com/osociety/network_tools) because of platform limitations.

## Getting started

## Usage
Add dependency in pubspec.yml

```yml
dependencies:
  flutter:
    sdk: flutter
    
  network_tools_flutter: ^1.0.4
```

Import package in your project
```dart
import 'package:network_tools_flutter/network_tools_flutter.dart';
```

Use HostScannerFlutter and PortScannerFlutter for your flutter projects. See example directory for illustration.

## Additional information

You can use same APIs but need to import from network_tools_flutter. All APIs from network_tools are automatically imported by network_tools_flutter. So just network_tools_flutter in your flutter app. 