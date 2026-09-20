import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gifmaker/main.dart';

void main() {
  testWidgets('Home screen shows empty state with a disabled Create GIF button', (tester) async {
    await tester.pumpWidget(const GifMakerApp());

    expect(find.text('GifMaker'), findsOneWidget);
    expect(find.text('No photos selected'), findsOneWidget);
    expect(find.text('Choose Photos'), findsOneWidget);

    // "Create GIF" is always visible but disabled until 2+ photos are picked.
    final createButtonFinder = find.widgetWithText(CupertinoButton, 'Create GIF');
    expect(createButtonFinder, findsOneWidget);
    expect(tester.widget<CupertinoButton>(createButtonFinder).onPressed, isNull);
  });
}
