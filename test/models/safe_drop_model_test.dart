import 'package:flutter_test/flutter_test.dart';
import 'package:pinaka_pos/Models/Auth/safe_drop_model.dart';

void main() {
  test('serializes create-safe payload using the API field names', () {
    final request = SafeDropRequest(
      safeDenominations: [
        SafeDropDenomination(
          denom: 10,
          tubeCount: 1,
          cellCount: 0,
          total: 10,
        ),
      ],
      coinsTotal: 0,
      totalAmount: 10,
      shiftId: 'SHIFT-123',
    );

    expect(request.toJson(), {
      'shift_id': 'SHIFT-123',
      'safe_denom': [
        {
          'denom': 10,
          'tube_count': 1,
          'cell_count': 0,
          'total': 10,
        },
      ],
      'coins_total': 0,
      'total_amount': 10,
    });
  });
}
