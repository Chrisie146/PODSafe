import 'package:flutter_test/flutter_test.dart';
import 'package:podsafe/utils/vehicle_utils.dart';

void main() {
  group('normalizeRegistration', () {
    test('removes spaces and special characters and uppercases', () {
      expect(normalizeRegistration('abc 123'), 'ABC123');
      expect(normalizeRegistration('ab-c 123'), 'ABC123');
      expect(normalizeRegistration(' ab c123 '), 'ABC123');
      expect(normalizeRegistration('aBc123'), 'ABC123');
      expect(normalizeRegistration(''), '');
    });
  });
}
