# Network Tools Flutter

[![pub package](https://img.shields.io/pub/v/network_tools_flutter.svg)](https://pub.dev/packages/network_tools_flutter) [![Dart](https://github.com/osociety/network_tools_flutter/actions/workflows/flutter.yml/badge.svg)](https://github.com/osociety/network_tools_flutter/actions/workflows/flutter.yml) [![codecov](https://codecov.io/gh/osociety/network_tools_flutter/graph/badge.svg?token=X8UVO7RUA4)](https://codecov.io/gh/osociety/network_tools_flutter)

## Features

This package will add support for flutter features which is out of the scope of [network_tools](https://github.com/osociety/network_tools) because of platform limitations.

## Getting started

## Usage
Add dependency in pubspec.yml, path_provider dependency is also needed

```yml
dependencies:
  flutter:
    sdk: flutter
    
  network_tools_flutter: ^1.0.4
  path_provider: ^2.1.2
```



And initialize the pacakge in the main function

```dart
 await configureNetworkToolsFlutter((await getApplicationDocumentsDirectory()).path);
```

From here please follow the documentation of [network_tools](https://pub.dev/packages/network_tools) as they are the same. 