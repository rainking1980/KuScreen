import 'package:flutter_test/flutter_test.dart';
import 'package:kucoin_screener/main.dart';

void main() {
  testWidgets('app si avvia', (tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('KuCoin futures'), findsOneWidget);
  });
}
