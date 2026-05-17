import 'package:flutter/material.dart';
import 'package:meetra_app/spark_screen.dart';
import 'package:flutter_test/flutter_test.dart';
void main() { testWidgets('Spark Screen test', (WidgetTester tester) async { await tester.pumpWidget(MaterialApp(home: SparkScreen(onBack: () {}))); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle(); }); }
