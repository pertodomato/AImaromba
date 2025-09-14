// lib/core/errors/failures.dart
abstract class Failure {
  final String message;
  Failure(this.message);
}

class AiFailure extends Failure {
  AiFailure(super.message);
}

class NetworkFailure extends Failure {
  NetworkFailure(super.message);
}

class DatabaseFailure extends Failure {
  DatabaseFailure(super.message);
}