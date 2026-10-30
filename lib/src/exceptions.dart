/// The kind of failure reported by [HostScanException].
enum HostScanFailureKind {
  /// The isolate running the scan terminated unexpectedly.
  isolateCrash,

  /// The scan itself reported an error.
  scanError,
}

/// Failure raised by the Flutter host scanner.
///
/// Extends [StateError] so callers that already catch [StateError] keep
/// working, while new callers can inspect [kind] and [cause].
class HostScanException extends StateError {
  HostScanException(super.message, {required this.kind, this.cause});

  final HostScanFailureKind kind;
  final Object? cause;
}
