import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../models/pod_access_token.dart';
import '../utils/theme.dart';

/// Widget to display a QR code for POD access
class PODQRCode extends StatelessWidget {
  final PODAccessToken token;
  final double size;
  final bool showUrl;
  final String? baseUrl;
  
  const PODQRCode({
    super.key,
    required this.token,
    this.size = 200,
    this.showUrl = true,
    this.baseUrl,
  });
  
  @override
  Widget build(BuildContext context) {
    final url = token.getPublicUrl(baseUrl: baseUrl);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 26),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: QrImageView(
            data: url,
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            embeddedImage: null, // Can add logo here if desired
            embeddedImageStyle: const QrEmbeddedImageStyle(
              size: Size(40, 40),
            ),
          ),
        ),
        if (showUrl) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              url,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
  
  /// Generate QR code as image bytes (for printing/exporting)
  static Future<Uint8List?> generateQRImageBytes(
    PODAccessToken token, {
    double size = 512,
    String? baseUrl,
  }) async {
    try {
      final url = token.getPublicUrl(baseUrl: baseUrl);
      final qrCode = QrCode.fromData(
        data: url,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      
      final painter = QrPainter.withQr(
        qr: qrCode,
        gapless: true,
        dataModuleStyle: const QrDataModuleStyle(
          color: Color(0xFF000000),
        ),
        eyeStyle: const QrEyeStyle(
          color: Color(0xFF000000),
        ),
      );
      
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      
      painter.paint(canvas, Size(size, size));
      
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('❌ Failed to generate QR image: $e');
      return null;
    }
  }
}

/// Dialog to show QR code with options
class PODQRCodeDialog extends StatelessWidget {
  final PODAccessToken token;
  final String? baseUrl;
  
  const PODQRCodeDialog({
    super.key,
    required this.token,
    this.baseUrl,
  });
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Row(
              children: [
                const Icon(Icons.qr_code_2, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'POD QR Code',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Scan this QR code to view the POD online',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            PODQRCode(
              token: token,
              size: 250,
              showUrl: true,
              baseUrl: baseUrl,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    // Copy URL to clipboard
                    /* await Clipboard.setData(
                      ClipboardData(text: token.getPublicUrl(baseUrl: baseUrl)),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL copied to clipboard')),
                    ); */
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy URL'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Download QR code as image
                    final imageBytes = await PODQRCode.generateQRImageBytes(
                      token,
                      baseUrl: baseUrl,
                    );
                    if (imageBytes != null) {
                      // Save to downloads or share
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('QR code saved')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Valid until: ${token.expiresAt != null ? _formatDate(token.expiresAt!) : "No expiry"}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  static Future<void> show(
    BuildContext context, {
    required PODAccessToken token,
    String? baseUrl,
  }) {
    return showDialog(
      context: context,
      builder: (context) => PODQRCodeDialog(
        token: token,
        baseUrl: baseUrl,
      ),
    );
  }
}
