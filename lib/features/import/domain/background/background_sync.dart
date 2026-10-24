Future<T> runInBackground<T>(T Function() computation) async {
  // Let the UI paint its progress indicator first.
  await Future<void>.delayed(Duration.zero);
  return computation();
}
