class NetworkError implements Exception {
  final String message;

  const NetworkError(this.message);
}

class ServerError implements Exception {
  final String message;

  const ServerError(this.message);
}
