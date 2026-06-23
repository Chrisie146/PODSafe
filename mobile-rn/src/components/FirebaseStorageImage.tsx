import React, { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Image, ImageStyle, Pressable, StyleProp, StyleSheet, Text, View } from 'react-native';
import storage from '@react-native-firebase/storage';
import { colors, spacing } from '../theme/tokens';

/**
 * Ported from lib/widgets/firebase_storage_image.dart (verified against source on
 * 2026-06-23). Resolves gs:// Storage URLs to a download URL before rendering, with
 * loading/error/retry states.
 *
 * Deviation: RN's <Image> has no loadingBuilder/errorBuilder equivalent (no progress
 * fraction is exposed either), so loading is a plain ActivityIndicator and the
 * encoding-error-vs-generic-error distinction from Image.network's errorBuilder is
 * collapsed into one generic "failed to load" state — RN's onError doesn't expose a
 * typed error to distinguish them.
 */
interface FirebaseStorageImageProps {
  imageUrl: string;
  style?: StyleProp<ImageStyle>;
  width?: number;
  height?: number;
  placeholder?: React.ReactNode;
  showErrorDetails?: boolean;
  resizeMode?: 'contain' | 'cover';
}

export default function FirebaseStorageImage({ imageUrl, style, width, height, placeholder, showErrorDetails = true, resizeMode = 'contain' }: FirebaseStorageImageProps) {
  const [resolvedUrl, setResolvedUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [imageFailed, setImageFailed] = useState(false);

  const resolveImageUrl = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    setImageFailed(false);
    try {
      let url = imageUrl;
      if (url.startsWith('gs://')) {
        const ref = storage().refFromURL(url);
        url = await ref.getDownloadURL();
      }
      setResolvedUrl(url);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setIsLoading(false);
    }
  }, [imageUrl]);

  useEffect(() => {
    resolveImageUrl();
  }, [resolveImageUrl]);

  if (isLoading) {
    return (
      placeholder ?? (
        <View style={styles.center}>
          <ActivityIndicator />
          <Text style={styles.loadingText}>Loading image...</Text>
        </View>
      )
    ) as React.ReactElement;
  }

  if (error || !resolvedUrl || imageFailed) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorIcon}>🖼️</Text>
        <Text style={styles.errorTitle}>Failed to load image</Text>
        {showErrorDetails && error ? (
          <Text style={styles.errorDetail} numberOfLines={3}>
            {error}
          </Text>
        ) : null}
        <Pressable style={styles.retryButton} onPress={resolveImageUrl}>
          <Text style={styles.retryText}>↻ Retry</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <Image
      source={{ uri: resolvedUrl }}
      style={[width ? { width } : null, height ? { height } : null, style]}
      resizeMode={resizeMode}
      onError={() => setImageFailed(true)}
    />
  );
}

const styles = StyleSheet.create({
  center: { alignItems: 'center', justifyContent: 'center', padding: spacing.medium },
  loadingText: { color: colors.textSecondary, fontSize: 12, marginTop: spacing.small },
  errorIcon: { fontSize: 40 },
  errorTitle: { color: colors.error, fontWeight: '600', marginTop: spacing.small },
  errorDetail: { color: colors.textSecondary, fontSize: 11, marginTop: spacing.small, textAlign: 'center', paddingHorizontal: spacing.medium },
  retryButton: { marginTop: spacing.small + 4, paddingHorizontal: spacing.medium, paddingVertical: spacing.small },
  retryText: { color: colors.primary, fontWeight: '600' },
});
