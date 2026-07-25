import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:network_tools_flutter/src/network_tools_flutter_util.dart';
import 'fake_http_overrides.dart';
import 'package:universal_io/io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = FakeResponseHttpOverrides();
  });

  group('configureNetworkToolsFlutter configuration', () {
    test('enabling debugging configures root logger and logs output', () async {
      final logs = <String>[];
      final subscription = Logger.root.onRecord.listen((record) {
        if (record.loggerName == logger.name) {
          logs.add(record.message);
        }
      });

      await configureNetworkToolsFlutter(
        'build/network_tools_config',
        enableDebugging: true,
      );

      logger.fine('Test debugging fine message');
      subscription.cancel();

      expect(Logger.root.level, equals(Level.FINE));
      expect(logs, contains('Test debugging fine message'));
    });
  });
}
