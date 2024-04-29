import 'package:flutter_package/flutter_package.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    test('FFI call works', () {
      final result = sum(10, 15);
      expect(result, 25);
    });
  });
}
