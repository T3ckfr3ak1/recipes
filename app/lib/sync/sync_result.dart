final class SyncResult {
  const SyncResult({
    required this.advanced,
    required this.lastPullAtRaw,
    required this.upserted,
    required this.removed,
    required this.fetched,
    required this.errors,
    this.alreadyRunning = false,
  });

  final bool advanced;
  final String? lastPullAtRaw;
  final int upserted;
  final int removed;
  final int fetched;
  final List<String> errors;
  final bool alreadyRunning;

  bool get ok => advanced && errors.isEmpty;
}
