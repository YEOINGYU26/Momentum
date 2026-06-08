import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/price_provider.dart';
import 'package:mobile/providers/balance_provider.dart';
import 'package:mobile/providers/job_provider.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PriceProvider()),
          ChangeNotifierProvider(create: (_) => BalanceProvider()),
          ChangeNotifierProvider(create: (_) => JobProvider()),
        ],
        child: const TradingApp(),
      ),
    );
    expect(find.text('시세'), findsOneWidget);
  });
}
