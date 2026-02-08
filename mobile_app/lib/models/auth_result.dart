class AuthResult {
  final bool success;
  final String? errorMessage;
  final String? userId;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.userId,
  });

  factory AuthResult.success(String userId) {
    return AuthResult(
      success: true,
      userId: userId,
    );
  }

  factory AuthResult.failure(String errorMessage) {
    return AuthResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}
