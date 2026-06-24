import React, { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useAuthStore } from '../../stores/useAuthStore';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { Screen, Card, FormField, PrimaryButton, SecondaryButton, AppIcon } from '../../components/ui';
import type { AuthStackParamList } from '../../navigation/AuthStack';

type Props = NativeStackScreenProps<AuthStackParamList, 'Login'>;

/**
 * Ported from lib/screens/auth/login_screen.dart. The hidden secret-tap trigger to
 * the developer dashboard in the Flutter version is intentionally NOT replicated here —
 * per the plan, the developer screen should be reached via a build-gated debug menu
 * instead (Phase 3/Developer screen), not a hidden gesture.
 *
 * UI/UX Refresh Phase 5: rebuilt on the shared Operations Precision primitives
 * (Screen/Card/FormField/PrimaryButton) — behaviour and store calls unchanged.
 */
export default function LoginScreen({ navigation }: Props) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const signIn = useAuthStore(s => s.signIn);
  const isLoading = useAuthStore(s => s.isLoading);
  const errorMessage = useAuthStore(s => s.errorMessage);
  const clearError = useAuthStore(s => s.clearError);

  const handleSubmit = async () => {
    clearError();
    try {
      await signIn(email.trim(), password);
    } catch {
      // error surfaced via errorMessage in the store
    }
  };

  return (
    <Screen scroll keyboardAvoiding contentContainerStyle={styles.content}>
      <View style={styles.brand}>
        <View style={styles.logoBadge}>
          <AppIcon name="shield" size={32} color={colors.onPrimary} />
        </View>
        <Text style={[textStyles.heading1, styles.title]}>PODSafe</Text>
        <Text style={[textStyles.bodyMedium, styles.subtitle]}>Sign in to continue</Text>
      </View>

      <Card padding="spacious" style={styles.card}>
        <FormField
          label="Email"
          placeholder="you@company.com"
          autoCapitalize="none"
          autoComplete="email"
          keyboardType="email-address"
          value={email}
          onChangeText={setEmail}
        />
        <FormField
          label="Password"
          placeholder="Your password"
          secureTextEntry
          autoComplete="password"
          value={password}
          onChangeText={setPassword}
        />

        {errorMessage ? (
          <View accessibilityLiveRegion="polite" style={styles.errorBanner}>
            <AppIcon name="alert" size={20} color={colors.critical} />
            <Text style={styles.errorText}>{errorMessage}</Text>
          </View>
        ) : null}

        <PrimaryButton label="Sign in" onPress={handleSubmit} loading={isLoading} style={styles.submit} />
      </Card>

      <View style={styles.links}>
        <SecondaryButton
          label="Create an account"
          icon="user"
          onPress={() => navigation.navigate('Signup')}
        />
        <SecondaryButton
          label="Have an invite code?"
          icon="key"
          onPress={() => navigation.navigate('InviteRegistration', { token: undefined })}
        />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: { flexGrow: 1, justifyContent: 'center', gap: spacing.large, maxWidth: 440, width: '100%', alignSelf: 'center' },
  brand: { alignItems: 'center', gap: spacing.small },
  logoBadge: {
    alignItems: 'center',
    backgroundColor: colors.shell,
    borderRadius: 20,
    height: 64,
    justifyContent: 'center',
    marginBottom: spacing.small,
    width: 64,
  },
  title: { textAlign: 'center', color: colors.shell },
  subtitle: { textAlign: 'center', color: colors.contentSecondary },
  card: { gap: spacing.medium },
  errorBanner: {
    alignItems: 'center',
    backgroundColor: colors.criticalMuted,
    borderRadius: 8,
    flexDirection: 'row',
    gap: spacing.small,
    padding: spacing.small,
  },
  errorText: { ...textStyles.bodySmall, color: colors.critical, flex: 1 },
  submit: { marginTop: spacing.xs },
  links: { gap: spacing.small },
});
