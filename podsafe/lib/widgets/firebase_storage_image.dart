import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/theme.dart';

/// Widget for loading images from Firebase Storage with better error handling
class FirebaseStorageImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final bool showErrorDetails;

  const FirebaseStorageImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.placeholder,
    this.showErrorDetails = true,
  });

  @override
  State<FirebaseStorageImage> createState() => _FirebaseStorageImageState();
}

class _FirebaseStorageImageState extends State<FirebaseStorageImage> {
  String? _resolvedUrl;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resolveImageUrl();
  }

  Future<void> _resolveImageUrl() async {
    try {
      String url = widget.imageUrl;
      print('🖼️ Resolving image URL: $url');

      // If it's a gs:// URL, convert to download URL
      if (url.startsWith('gs://')) {
        print('🖼️ Converting gs:// URL to download URL');
        final ref = FirebaseStorage.instance.refFromURL(url);
        url = await ref.getDownloadURL();
        print('🖼️ Download URL: $url');
      }

      setState(() {
        _resolvedUrl = url;
        _isLoading = false;
      });
      print('✅ Image URL resolved successfully');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('❌ Error resolving image URL: $e');
      debugPrint('Error resolving image URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  'Loading image...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
    }

    if (_error != null || _resolvedUrl == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image,
              size: 48,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 12),
            const Text(
              'Failed to load image',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.showErrorDetails && _error != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                  _resolvedUrl = null;
                });
                _resolveImageUrl();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Try using Image.network directly with custom headers
    return Image.network(
      _resolvedUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return widget.placeholder ??
            Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Image.network error: $error for URL: $_resolvedUrl');
        debugPrint('Stack trace: $stackTrace');
        
        // Check if it's an encoding error (corrupted image)
        final isEncodingError = error.toString().contains('EncodingError') || 
                                 error.toString().contains('cannot be decoded');
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isEncodingError ? Icons.broken_image : Icons.image_not_supported,
                size: 48,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 12),
              Text(
                isEncodingError ? 'Image file corrupted' : 'Image failed to load',
                style: const TextStyle(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isEncodingError) ...[
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'This image was uploaded incorrectly.\nPlease re-capture the POD.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (widget.showErrorDetails && !isEncodingError) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'URL: ${_resolvedUrl!.substring(0, _resolvedUrl!.length > 50 ? 50 : _resolvedUrl!.length)}...',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error.toString(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                    _resolvedUrl = null;
                  });
                  _resolveImageUrl();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
