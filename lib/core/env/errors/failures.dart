class Failure implements Exception {
  final String message;
  const Failure(this.message);
  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure(String msg) : super(msg);
}

class AiFailure extends Failure {
  const AiFailure(String msg) : super(msg);
}
