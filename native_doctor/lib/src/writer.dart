import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:native_doctor/src/toolchain_checker.dart';

enum TextColor {
  red,
  green,
  blue,
  cyan,
  yellow,
  magenta,
  grey,
}

abstract class TextStyler {
  String bolden(String message);
  String color(String message, TextColor color);
}

abstract class Writer implements TextStyler, ActionLogger {
  void printMessage(
    String message, {
    String prefix = '',
    TextColor? prefixColor,
  });
  void emptyLine();
  bool get hasTerminal;
  bool get supportsEmoji;
}

class AnsiWriter implements Writer, ActionLogger {
  AnsiWriter() {
    if (hasTerminal) {
      wrapWidth = math.min(io.stdout.terminalColumns, 120);
    } else {
      wrapWidth = 120;
    }
  }

  late int wrapWidth;

  @override
  bool get hasTerminal => io.stdout.hasTerminal;

  bool get supportsAnsi => io.stdout.supportsAnsiEscapes;

  // Assume unicode emojis are supported when not on Windows.
  // If we are on Windows, unicode emojis are supported in Windows Terminal,
  // which sets the WT_SESSION environment variable. See:
  // https://learn.microsoft.com/en-us/windows/terminal/tips-and-tricks
  @override
  bool get supportsEmoji =>
      !io.Platform.isWindows ||
      io.Platform.environment.containsKey('WT_SESSION');

  static const String bold = '\u001B[1m';
  static const String resetBold = '\u001B[22m';

  static const String red = '\u001b[31m';
  static const String green = '\u001b[32m';
  static const String blue = '\u001b[34m';
  static const String cyan = '\u001b[36m';
  static const String magenta = '\u001b[35m';
  static const String yellow = '\u001b[33m';
  static const String grey = '\u001b[90m';
  static const String resetColor = '\u001B[39m';

  @override
  String bolden(String message) {
    if (supportsAnsi) {
      return '$bold$message$resetBold';
    } else {
      return message;
    }
  }

  @override
  String color(String message, TextColor color) {
    if (supportsAnsi) {
      final colorAnsi = switch (color) {
        TextColor.red => red,
        TextColor.green => green,
        TextColor.blue => blue,
        TextColor.cyan => cyan,
        TextColor.magenta => magenta,
        TextColor.yellow => yellow,
        TextColor.grey => grey,
      };
      return '$colorAnsi$message$resetColor';
    } else {
      return message;
    }
  }

  @override
  void printMessage(
    String message, {
    String prefix = '',
    TextColor? prefixColor,
  }) {
    final words = message.split(' ');
    final buffer = StringBuffer();

    buffer.write(prefixColor == null ? prefix : color(prefix, prefixColor));

    var firstWord = true;
    for (final word in words) {
      if (buffer.length + word.length + 1 > wrapWidth) {
        print(buffer.toString());
        buffer.clear();
        buffer.write(' ' * prefix.length);
        firstWord = true;
      }
      if (buffer.isNotEmpty && !firstWord) {
        buffer.write(' ');
      }
      buffer.write(word);
      firstWord = false;
    }
    if (buffer.isNotEmpty) {
      print(buffer.toString());
    }
  }

  @override
  void emptyLine() {
    print('');
  }

  void _writeToStdOut(String message) => io.stdout.write(message);

  Timer? _spinerTimmer;

  late String _animation;
  int _animationFrame = 0;

  void _timerCallback(Timer timer) {
    _writeToStdOut('\b${_animation[_animationFrame]}');
    _animationFrame = (_animationFrame + 1) % _animation.length;
  }

  void _beginSpinner() {
    _spinerTimmer?.cancel();
    if (hasTerminal) {
      _animation = supportsEmoji ? '⠙⠚⠖⠦⢤⣠⣄⡤⠴⠲⠓⠋' : r'-\|/';
      _animationFrame = 0;
      _writeToStdOut(' ');
      _spinerTimmer = Timer.periodic(
        const Duration(milliseconds: 100),
        _timerCallback,
      );
    }
  }

  void _endSpinner() {
    if (_spinerTimmer != null) {
      _spinerTimmer?.cancel();
      _writeToStdOut('\b');
    }
  }

  @override
  Future<void> logAction(String message, Future<void> Function() action) async {
    _writeToStdOut(color(' • ', TextColor.yellow));
    _writeToStdOut(message);
    _writeToStdOut(' ');
    _beginSpinner();
    try {
      await action();
      _endSpinner();
      _writeToStdOut(color('[done]', TextColor.green));
      _writeToStdOut('\n');
    } catch (e) {
      _endSpinner();
      _writeToStdOut(color('[failed]', TextColor.red));
      _writeToStdOut('\n');
      rethrow;
    }
  }
}
