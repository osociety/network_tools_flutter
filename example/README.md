samples, guidance on mobile development, and a full API reference.

# Example for network_tools_flutter

This example demonstrates how to use the `network_tools_flutter` package in a Flutter app.

```dart
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
	final appDocDirectory = await getApplicationDocumentsDirectory();
	await configureNetworkToolsFlutter(appDocDirectory.path, enableDebugging: true);
	// Now you can use the network_tools_flutter APIs
}
```

For a complete example, see the code in this directory.
