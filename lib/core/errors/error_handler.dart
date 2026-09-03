abstract final class ErrorHandler {
  static String message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}
