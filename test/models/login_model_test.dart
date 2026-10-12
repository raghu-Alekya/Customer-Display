import 'package:flutter_test/flutter_test.dart';
import 'package:pinaka_pos/Models/Auth/login_model.dart';

void main() {
  group('LoginResponse safe feature flags', () {
    test('reads string flags from the employee returned inside data', () {
      final response = LoginResponse.fromJson({
        'data': {
          'token': 'access-token',
          'employee': {
            'safe_enable': '0',
            'safe_enable_drop': '1',
          },
        },
      });

      expect(response.safeEnable, '0');
      expect(response.safeEnableDrop, '1');
    });

    test('normalizes boolean flags', () {
      final response = LoginResponse.fromJson({
        'data': {
          'token': 'access-token',
          'safe_enable': false,
          'safe_enable_drop': true,
        },
      });

      expect(response.safeEnable, '0');
      expect(response.safeEnableDrop, '1');
    });

    test('accepts string true for the Safe Drop flag', () {
      final response = LoginResponse.fromJson({
        'token': 'access-token',
        'safeEnableDrop': 'true',
      });

      expect(response.safeEnableDrop, '1');
    });

    test('reads Safe Drop permission from the store object', () {
      final response = LoginResponse.fromJson({
        'accessToken': 'access-token',
        'store': {
          'safe_enable_drop': true,
        },
      });

      expect(response.safeEnableDrop, '1');
    });
  });
}
