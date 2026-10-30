// ignore: implementation_imports
import 'package:network_tools/src/services/impls/port_scanner_service_impl.dart';

/// Flutter flavor of PortScannerService.instance, only use if your project is based of flutter.
///
/// Inherits every scan operation from the core implementation; instantiating
/// it only registers this class as the platform implementation.
class PortScannerServiceFlutterImpl extends PortScannerServiceImpl {}
