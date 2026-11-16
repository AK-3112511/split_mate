/// A user-facing error whose [message] is already friendly and safe to show.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}
