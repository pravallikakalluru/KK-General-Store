import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grocery_store_app/main.dart';

void main() {
  testWidgets('App boots to the splash/auth gate without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const GroceryStoreApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
