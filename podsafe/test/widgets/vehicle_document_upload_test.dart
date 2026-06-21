import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import 'package:podsafe/screens/admin/vehicle_management_screen.dart';
import 'package:podsafe/services/vehicle_document_service.dart';

// A tiny fake service used by the widget test to avoid real Firebase calls.
class FakeVehicleDocumentService implements VehicleDocumentService {
  // No-op constructor
  FakeVehicleDocumentService();

  @override
  Future<String> uploadFile({required String companyId, required String vehicleId, required PlatformFile file, void Function(double progress)? onProgress}) async {
    // simulate progress
    if (onProgress != null) {
      onProgress(0.1);
      await Future.delayed(const Duration(milliseconds: 10));
      onProgress(0.5);
      await Future.delayed(const Duration(milliseconds: 10));
      onProgress(1.0);
    }
    return 'https://example.com/${file.name}';
  }

  @override
  Future<void> deleteByUrl(String url) async {
    // simulate delete
    await Future.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  testWidgets('selected files show thumbnail and uploaded url', skip: true, (WidgetTester tester) async {
    final fakeService = FakeVehicleDocumentService();

    await tester.pumpWidget(
      MaterialApp(
        home: Provider<VehicleDocumentService>.value(
          value: fakeService,
          child: const CreateVehicleScreen(),
        ),
      ),
    );

    // Access private state to simulate selected files and a completed upload.
    final state = tester.state(find.byType(CreateVehicleScreen)) as dynamic;

    final pf = PlatformFile(name: 'test.png', size: 123, bytes: Uint8List.fromList([0, 1, 2]));
    state.setSelectedFilesForTesting([pf]);
    final id = '${pf.name}_${pf.size}';
    state.setUploadedUrlForTesting(id, 'https://example.com/test.png');

    // Rebuild
    await tester.pumpAndSettle();

    expect(find.text('https://example.com/test.png'), findsOneWidget);
    expect(find.textContaining('example.com'), findsOneWidget);
  });
}
