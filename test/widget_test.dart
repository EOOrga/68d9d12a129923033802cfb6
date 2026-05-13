import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pelletier_roger_ops/main.dart';

void main() {
  testWidgets('dashboard navigation opens operations sections', (tester) async {
    await tester.pumpWidget(
      PelletierRogerApp(store: OperationsStore(screenshotMode: true)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Daily control for equipment, orders, compliance, and containers.',
      ),
      findsOneWidget,
    );
    expect(find.text('Active checkouts'), findsOneWidget);

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(find.text('Work orders'), findsOneWidget);
    expect(find.text('Repair dock leveler sensor'), findsOneWidget);
  });

  testWidgets('new work order is added locally', (tester) async {
    await tester.pumpWidget(
      PelletierRogerApp(store: OperationsStore(screenshotMode: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('newOrderFab')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('orderTitleField')),
      'Replace bay door cable',
    );
    await tester.enterText(find.byKey(const Key('orderAreaField')), 'Bay 6');
    await tester.enterText(
      find.byKey(const Key('orderNotesField')),
      'Cable frayed near lower bracket.',
    );
    await tester.tap(find.text('Save order'));
    await tester.pumpAndSettle();

    expect(find.text('Replace bay door cable'), findsOneWidget);
    expect(find.textContaining('Bay 6'), findsOneWidget);
  });
}
