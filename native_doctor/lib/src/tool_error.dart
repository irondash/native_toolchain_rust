class ToolError extends Error {
  final String message;

  ToolError(this.message);

  @override
  String toString() => message;
}
