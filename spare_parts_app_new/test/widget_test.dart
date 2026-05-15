// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify athat the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spare_parts_app/providers/auth_provider.dart';
import 'package:spare_parts_app/providers/cart_provider.dart';
import 'package:spare_parts_app/providers/language_provider.dart';
import 'package:spare_parts_app/providers/theme_provider.dart';
import 'package:spare_parts_app/providers/notification_provider.dart';

import 'package:spare_parts_app/main.dart';

void main() {
  testWidgets('App basic load test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // Basic verification that the app starts.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
