class ToolError implements Exception {
  final String message;

  ToolError(this.message);

  @override
  String toString() => message;
}
