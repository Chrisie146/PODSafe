import React, { useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useAuthStore } from '../../stores/useAuthStore';
import { colors } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import type { AuthStackParamList } from '../../navigation/AuthStack';

type Props = NativeStackScreenProps<AuthStackParamList, 'Login'>;

/**
 * Ported from lib/screens/auth/login_screen.dart. The hidden secret-tap trigger to
 * the developer dashboard in the Flutter version is intentionally NOT replicated here —
 * per the plan, the developer screen should be reached via a build-gated debug menu
 * instead (Phase 3/Developer screen), not a hidden gesture.
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
    <View style={styles.container}>
      <Text style={[textStyles.heading1, styles.title]}>PODSafe</Text>
      <Text style={[textStyles.bodyMedium, styles.subtitle]}>Sign in to continue</Text>

      <TextInput
        style={styles.input}
        placeholder="Email"
        autoCapitalize="none"
        keyboardType="email-address"
        value={email}
        onChangeText={setEmail}
      />
      <TextInput
        style={styles.input}
        placeholder="Password"
        secureTextEntry
        value={password}
        onChangeText={setPassword}
      />

      {errorMessage ? <Text style={styles.error}>{errorMessage}</Text> : null}

      <Pressable style={styles.button} onPress={handleSubmit} disabled={isLoading}>
        {isLoading ? <ActivityIndicator color={colors.white} /> : <Text style={textStyles.buttonText}>Sign In</Text>}
      </Pressable>

      <Pressable onPress={() => navigation.navigate('Signup')}>
        <Text style={[textStyles.bodyMedium, styles.link]}>Don&apos;t have an account? Sign up</Text>
      </Pressable>
      <Pressable onPress={() => navigation.navigate('InviteRegistration', { token: undefined })}>
        <Text style={[textStyles.bodyMedium, styles.link]}>Have an invite code?</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 24, backgroundColor: colors.background },
  title: { textAlign: 'center', color: colors.primary, marginBottom: 4 },
  subtitle: { textAlign: 'center', marginBottom: 32 },
  input: {
    backgroundColor: colors.card,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: colors.divider,
    padding: 14,
    marginBottom: 12,
  },
  button: {
    backgroundColor: colors.primary,
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 8,
  },
  error: { color: colors.error, marginBottom: 12, textAlign: 'center' },
  link: { color: colors.primary, textAlign: 'center', marginTop: 16 },
});
