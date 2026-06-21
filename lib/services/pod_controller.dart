import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ocr_fields_model.dart';
import 'ocr_parser.dart';
import 'pod_repository.dart';

/// State for POD operations
enum PodState {
  idle,
  capturing,
  parsingOcr,
  ready,
  uploading,
  success,
  error,
}

/// Controller for POD document intake workflow
class PodController extends ChangeNotifier {
  final PodRepository _repository;
  final OcrParser _ocrParser;
  final ImagePicker _imagePicker;

  // State
  PodState _state = PodState.idle;
  String? _errorMessage;
  XFile? _capturedImage;
  OcrFields? _ocrFields;
  DetectionFlags? _detectionFlags;
  String? _podDocumentId;

  // Constructor
  PodController({
    required PodRepository repository,
    required OcrParser ocrParser,
    ImagePicker? imagePicker,
  })  : _repository = repository,
        _ocrParser = ocrParser,
        _imagePicker = imagePicker ?? ImagePicker();

  // Getters
  PodState get state => _state;
  String? get errorMessage => _errorMessage;
  XFile? get capturedImage => _capturedImage;
  OcrFields? get ocrFields => _ocrFields;
  DetectionFlags? get detectionFlags => _detectionFlags;
  String? get podDocumentId => _podDocumentId;
  bool get isLoading => _state == PodState.capturing ||
      _state == PodState.parsingOcr ||
      _state == PodState.uploading;

  /// Capture image from camera
  Future<void> captureFromCamera() async {
    try {
      _setState(PodState.capturing);
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        _capturedImage = image;
        _setState(PodState.ready);
      } else {
        _setState(PodState.idle);
      }
    } catch (e) {
      _handleError('Failed to capture image: $e');
    }
  }

  /// Pick image from gallery
  Future<void> pickFromGallery() async {
    try {
      _setState(PodState.capturing);
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        _capturedImage = image;
        _setState(PodState.ready);
      } else {
        _setState(PodState.idle);
      }
    } catch (e) {
      _handleError('Failed to pick image: $e');
    }
  }

  /// Parse OCR from captured image
  /// Expects raw OCR text - integrate with ML Kit or vision API
  Future<void> parseOcrText(String ocrText) async {
    try {
      _setState(PodState.parsingOcr);

      // Parse the OCR text
      _ocrFields = _ocrParser.parseText(ocrText, confidence: 0.75);

      // Create detection flags
      _detectionFlags = DetectionFlags(
        hasSignature: _detectSignature(ocrText),
        hasStamp: _detectStamp(ocrText),
        ocrConfident: ocrText.isNotEmpty,
        warnings: _validateOcr(_ocrFields!),
        ocrConfidenceScore: 0.75,
      );

      _setState(PodState.ready);
    } catch (e) {
      _handleError('Failed to parse OCR: $e');
    }
  }

  /// Upload and save POD document
  Future<void> uploadPod({
    required String companyId,
    required String driverId,
  }) async {
    try {
      if (_capturedImage == null || _ocrFields == null || _detectionFlags == null) {
        _handleError('Missing image or OCR data');
        return;
      }

      _setState(PodState.uploading);

      // Upload image
      final storagePath = await _repository.uploadImage(
        _capturedImage!,
        uid: driverId,
        companyId: companyId,
      );

      // Try to auto-match to delivery
      final matchedDeliveryId =
          await _repository.tryAutoMatchDelivery(
            companyId: companyId,
            fields: _ocrFields!,
          );

      // Save POD document
      _podDocumentId = await _repository.savePodDocument(
        companyId: companyId,
        driverId: driverId,
        storagePath: storagePath,
        fields: _ocrFields!,
        flags: _detectionFlags!,
        matchedDeliveryId: matchedDeliveryId,
      );

      // If matched, link to delivery
      if (matchedDeliveryId != null) {
        await _repository.linkPodToDelivery(
          companyId,
          _podDocumentId!,
          matchedDeliveryId,
        );
      }

      _setState(PodState.success);
    } catch (e) {
      _handleError('Failed to upload POD: $e');
    }
  }

  /// Reset controller state
  void reset() {
    _state = PodState.idle;
    _errorMessage = null;
    _capturedImage = null;
    _ocrFields = null;
    _detectionFlags = null;
    _podDocumentId = null;
    notifyListeners();
  }

  // Private helpers

  void _setState(PodState state) {
    _state = state;
    _errorMessage = null;
    notifyListeners();
  }

  void _handleError(String message) {
    _state = PodState.error;
    _errorMessage = message;
    notifyListeners();
  }

  bool _detectSignature(String text) {
    return text.toLowerCase().contains('signature') ||
        text.toLowerCase().contains('signed') ||
        text.toLowerCase().contains('signed by');
  }

  bool _detectStamp(String text) {
    final lowerText = text.toLowerCase();
    return lowerText.contains('stamp') ||
        lowerText.contains('received') ||
        lowerText.contains('approved');
  }

  List<String> _validateOcr(OcrFields fields) {
    final warnings = <String>[];

    if (fields.invoiceNo == null || fields.invoiceNo!.isEmpty) {
      warnings.add('Invoice number not found');
    }

    if (fields.totalIncl == null) {
      warnings.add('Total amount not found');
    }

    if (fields.documentDate == null) {
      warnings.add('Document date not found');
    } else {
      final now = DateTime.now();
      if (fields.documentDate!.isAfter(now.add(Duration(days: 1)))) {
        warnings.add('Document date is in the future');
      } else if (fields.documentDate!.isBefore(now.subtract(Duration(days: 365)))) {
        warnings.add('Document date is older than 1 year');
      }
    }

    if (fields.totalExcl != null && fields.totalVat != null && fields.totalIncl != null) {
      final calculated = fields.totalExcl! + fields.totalVat!;
      if ((calculated - fields.totalIncl!).abs() > 1.0) {
        warnings.add('Totals mismatch: Excl + VAT ≠ Incl');
      }
    }

    return warnings;
  }
}
