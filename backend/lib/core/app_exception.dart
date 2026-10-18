/// Lỗi nghiệp vụ, được errorMiddleware chuyển thành response JSON.
class AppException implements Exception {
  final int statusCode;
  final String message;

  const AppException(this.statusCode, this.message);

  const AppException.badRequest(String message) : this(400, message);
  const AppException.notFound(String message) : this(404, message);

  @override
  String toString() => 'AppException($statusCode): $message';
}
