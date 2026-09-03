import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pinaka_pos_customer_display/providers/display_provider.dart';
import 'package:pinaka_pos_customer_display/services/mqtt_customer_display_service.dart';
import 'package:pinaka_pos_customer_display/screens/customer_display_screen.dart';

void main() {
  testWidgets('Customer Display screen loads', (WidgetTester tester) async {
    final service = MqttCustomerDisplayService(
      brokerPort: 1883,
      displayId: 'CFD01',
      username: 'pinaka_cfd',
      token: 'generated-device-token',
      topicPrefix: 'pinaka/M1001/S001/POS01/cfd',
    );

    final provider = DisplayProvider(service);

    await tester.pumpWidget(
      ChangeNotifierProvider<DisplayProvider>.value(
        value: provider,
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CustomerDisplayScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(CustomerDisplayScreen), findsOneWidget);
  });
}
