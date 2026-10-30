import 'package:example/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocDirectory = await getApplicationDocumentsDirectory();
  await configureNetworkToolsFlutter(
    appDocDirectory.path,
    enableDebugging: true,
  );
  runApp(NetworkToolsExampleApp(dbDirectory: appDocDirectory.path));
}

/// Example app that exercises every public API of `network_tools_flutter`
/// (and through it, `network_tools`).
///
/// It doubles as a manual test harness: every scan method has controls for all
/// of its parameters, progress reporting, cancellation and full result output.
class NetworkToolsExampleApp extends StatelessWidget {
  const NetworkToolsExampleApp({super.key, required this.dbDirectory});

  final String dbDirectory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'network_tools_flutter example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: HomePage(dbDirectory: dbDirectory),
    );
  }
}
