import AsyncStorage from '@react-native-async-storage/async-storage';

/**
 * Ported from lib/services/onboarding_service.dart (verified against source on
 * 2026-06-23) — uses @react-native-async-storage/async-storage as the RN equivalent of
 * Dart's shared_preferences. Real call sites beyond admin_settings_screen.dart's debug
 * tools: splash_screen.dart (gate check) and onboarding/onboarding_screen.dart (neither
 * ported to RN yet — see vault [[00 Overview]] Phase 1), so this is ready ahead of those.
 * `OnboardingStep`/`OnboardingFlow` (Dart `IconData`/`Widget`-typed step content) are
 * presentation config for that not-yet-built screen, not data this service owns — left
 * for whoever ports onboarding_screen.dart to define directly in TSX.
 */
const ONBOARDING_COMPLETED_KEY = 'onboarding_completed';
const ONBOARDING_STEP_KEY = 'onboarding_step';
const USER_ROLE_KEY = 'user_role';

export async function isOnboardingCompleted(): Promise<boolean> {
  return (await AsyncStorage.getItem(ONBOARDING_COMPLETED_KEY)) === 'true';
}

export async function completeOnboarding(): Promise<void> {
  await AsyncStorage.setItem(ONBOARDING_COMPLETED_KEY, 'true');
}

export async function getCurrentOnboardingStep(): Promise<number> {
  const value = await AsyncStorage.getItem(ONBOARDING_STEP_KEY);
  return value ? Number(value) : 0;
}

export async function setCurrentOnboardingStep(step: number): Promise<void> {
  await AsyncStorage.setItem(ONBOARDING_STEP_KEY, String(step));
}

export async function setOnboardingUserRole(role: string): Promise<void> {
  await AsyncStorage.setItem(USER_ROLE_KEY, role);
}

export async function getOnboardingUserRole(): Promise<string | null> {
  return AsyncStorage.getItem(USER_ROLE_KEY);
}

/** Mirrors OnboardingService.resetOnboarding(). */
export async function resetOnboarding(): Promise<void> {
  await AsyncStorage.removeMany([ONBOARDING_COMPLETED_KEY, ONBOARDING_STEP_KEY, USER_ROLE_KEY]);
}

/** Mirrors OnboardingService.getDebugData(). */
export async function getOnboardingDebugData(): Promise<Record<string, string | number | boolean>> {
  const [completed, step, role] = await Promise.all([isOnboardingCompleted(), getCurrentOnboardingStep(), getOnboardingUserRole()]);
  return {
    onboarding_completed: completed,
    onboarding_step: step,
    user_role: role ?? 'unknown',
  };
}
