import 'package:flutter_test/flutter_test.dart';
import 'package:podsafe/screens/admin/admin_dashboard_desktop_temp.dart';

void main() {
  group('Admin Dashboard helpers', () {
    test('calculateDeliveryCounts returns correct counts', () {
      final docs = [
        {'status': 'delivered'},
        {'status': 'delivered'},
        {'status': 'inTransit'},
        {'status': 'pending'},
        {'status': 'pending'},
      ];

      final counts = calculateDeliveryCounts(docs);

      expect(counts['total'], 5);
      expect(counts['delivered'], 2);
      expect(counts['inTransit'], 1);
      expect(counts['pending'], 2);
    });

    test('calculateDriverApprovalCounts returns correct counts', () {
      final docs = <Map<String, dynamic>>[
        {'approvalStatus': 'approved'},
        {'approvalStatus': 'approved'},
        {'approvalStatus': 'pending'},
        <String, dynamic>{},
      ];

      final counts = calculateDriverApprovalCounts(docs);

      expect(counts['approved'], 2);
      expect(counts['pending'], 2);
    });
  });
}
