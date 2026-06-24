import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Image,
  ImageStyle,
  StyleProp,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import storage from '@react-native-firebase/storage';
import { AppIcon, SecondaryButton } from './ui';
import { colors, spacing } from '../theme/tokens';
import { textStyles } from '../theme/textStyles';

interface FirebaseStorageImageProps {
  imageUrl: string;
  style?: StyleProp<ImageStyle>;
  width?: number;
  height?: number;
  placeholder?: React.ReactNode;
  showErrorDetails?: boolean;
  resizeMode?: 'contain' | 'cover';
}

/** Resolves a Firebase Storage URL and renders explicit loading and retry states. */
export default function FirebaseStorageImage({
  imageUrl,
  style,
  width,
  height,
  placeholder,
  showErrorDetails = true,
  resizeMode = 'contain',
}: FirebaseStorageImageProps) {
  const [resolvedUrl, setResolvedUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [imageFailed, setImageFailed] = useState(false);

  const resolveImageUrl = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    setImageFailed(false);
    try {
      const resolved = imageUrl.startsWith('gs://')
        ? await storage().refFromURL(imageUrl).getDownloadURL()
        : imageUrl;
      setResolvedUrl(resolved);
    } catch (caught) {
      setError((caught as Error).message);
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
          <ActivityIndicator color={colors.active} />
          <Text style={textStyles.bodySmall}>Loading evidence</Text>
        </View>
      )
    );
  }

  if (error || !resolvedUrl || imageFailed) {
    return (
      <View style={styles.center}>
        <AppIcon name="image" size={32} color={colors.critical} />
        <Text style={textStyles.label}>Evidence image unavailable</Text>
        {showErrorDetails && error ? (
          <Text numberOfLines={3} style={[textStyles.bodySmall, styles.error]}>
            {error}
          </Text>
        ) : null}
        <SecondaryButton
          label="Try again"
          icon="activity"
          onPress={resolveImageUrl}
          style={styles.retry}
        />
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
  center: {
    alignItems: 'center',
    gap: spacing.small,
    justifyContent: 'center',
    padding: spacing.medium,
  },
  error: { textAlign: 'center' },
  retry: { marginTop: spacing.xs },
});
