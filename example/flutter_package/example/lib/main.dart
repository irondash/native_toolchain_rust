import 'package:flutter/material.dart';
import 'package:flutter_package/flutter_package.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Sum value: ${sum(10, 15)}'),
        ),
      ),
    );
  }
}
