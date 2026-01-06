class IdGenerator {
  static int _counter = 0;

  static String documentId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    _counter += 1;
    final suffix = _counter.toRadixString(16).padLeft(4, '0');
    return 'document-$timestamp-$suffix';
  }
}
