import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
// ignore: implementation_imports
import 'package:network_tools/src/repository/repository.dart';
import 'package:network_tools_flutter/src/network_tools_flutter_util.dart';
import 'fake_http_overrides.dart';
import 'package:universal_io/io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = FakeResponseHttpOverrides();
  });

  group('configureNetworkToolsFlutter configuration', () {
    test('concurrent calls share the in-flight configuration', () async {
      final first = configureNetworkToolsFlutter(
        'build/network_tools_config',
        enableDebugging: true,
      );
      final second = configureNetworkToolsFlutter(
        'build/network_tools_config',
        enableDebugging: true,
      );

      await Future.wait(<Future<void>>[first, second]);
      await vendorTableBuildFuture;

      expect(vendorTableBuildFuture, isNull);
    });

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
      await vendorTableBuildFuture;

      logger.fine('Test debugging fine message');
      subscription.cancel();

      expect(Logger.root.level, equals(Level.FINE));
      expect(logs, contains('Test debugging fine message'));
    });

    test('logs a warning when the vendor table build fails', () async {
      final warnings = <String>[];
      final subscription = Logger.root.onRecord.listen((LogRecord record) {
        if (record.loggerName == logger.name && record.level >= Level.WARNING) {
          warnings.add(record.message);
        }
      });

      final getIt = GetIt.instance;
      final Repository<Vendor> original = getIt<Repository<Vendor>>();
      await getIt.unregister<Repository<Vendor>>();
      getIt.registerSingleton<Repository<Vendor>>(_ThrowingVendorRepository());

      try {
        await configureNetworkToolsFlutter(
          'build/network_tools_config',
          enableDebugging: true,
          rebuildData: true,
        );
        await vendorTableBuildFuture;
      } finally {
        await getIt.unregister<Repository<Vendor>>();
        getIt.registerSingleton<Repository<Vendor>>(original);
        await subscription.cancel();
      }

      expect(warnings.join('\n'), contains('Failed to build the MAC vendor'));
    });

    test(
      'warns when called with different arguments without rebuildData',
      () async {
        await configureNetworkToolsFlutter(
          'build/network_tools_config',
          enableDebugging: true,
        );
        await vendorTableBuildFuture;

        final warnings = <String>[];
        final subscription = Logger.root.onRecord.listen((LogRecord record) {
          if (record.loggerName == logger.name &&
              record.level >= Level.WARNING) {
            warnings.add(record.message);
          }
        });

        await configureNetworkToolsFlutter(
          'build/network_tools_other',
          enableDebugging: true,
        );
        await subscription.cancel();

        expect(warnings.join('\n'), contains('different arguments'));
      },
    );
  });
}

class _ThrowingVendorRepository with Repository<Vendor> {
  @override
  Future<void> build() async => throw StateError('vendor build failed');

  @override
  Future<bool> clear() async => false;

  @override
  Future<void> close() async {}

  @override
  Future<List<String?>?> entries() async => const <String?>[];

  @override
  Future<Vendor?> entryFor(String address) async => null;
}
