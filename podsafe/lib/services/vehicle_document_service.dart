import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

/// Service responsible for uploading and deleting vehicle documents in Firebase Storage.
class VehicleDocumentService {
  final FirebaseStorage _storage;

  VehicleDocumentService({FirebaseStorage? storage}) : _storage = storage ?? FirebaseStorage.instance;

  /// Upload a file for a given company/vehicle. Calls [onProgress] with values 0..1.
  /// Returns the download URL on success.
  Future<String> uploadFile({
    required String companyId,
    required String vehicleId,
    required PlatformFile file,
    void Function(double progress)? onProgress,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final storagePath = 'companies/$companyId/vehicles/$vehicleId/documents/$fileName';
    final ref = _storage.ref().child(storagePath);

    UploadTask uploadTask;
    if (file.path != null && file.path!.isNotEmpty) {
      uploadTask = ref.putFile(File(file.path!));
    } else if (file.bytes != null) {
      uploadTask = ref.putData(file.bytes!);
    } else {
      throw Exception('File has no data');
    }

    final completer = Completer<TaskSnapshot>();

    final sub = uploadTask.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes > 0 ? snapshot.totalBytes : 1;
      final prog = snapshot.bytesTransferred / total;
      if (onProgress != null) onProgress(prog.clamp(0.0, 1.0));
    }, onError: (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }, onDone: () async {
      try {
        final s = await uploadTask;
        if (!completer.isCompleted) completer.complete(s);
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    });

    try {
      final snapshot = await completer.future;
      await sub.cancel();
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      await sub.cancel();
      rethrow;
    }
  }

  /// Delete a storage object by its download URL.
  Future<void> deleteByUrl(String url) async {
    final ref = _storage.refFromURL(url);
    await ref.delete();
  }
}
