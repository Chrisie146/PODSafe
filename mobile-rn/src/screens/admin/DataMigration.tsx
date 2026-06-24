import React, { useState } from 'react';
import { Alert, FlatList, StyleSheet, Text, View } from 'react-native';
import firestore from '@react-native-firebase/firestore';
import { colors, spacing, radii } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { Screen, Card, PrimaryButton, EmptyState, AppIcon } from '../../components/ui';

/**
 * Ported from lib/screens/admin/data_migration_screen.dart (verified against source on
 * 2026-06-22) — a one-off admin tool that migrates legacy single-company data into the
 * multi-company structure (creates a "Default Company", backfills companyId onto
 * existing users/deliveries, auto-approves existing drivers).
 *
 * This is pure client-side Firestore logic in the Dart source too (no service/Cloud
 * Function involved despite being a migration tool) — kept inline here rather than
 * adding a repository for a script that's explicitly meant to run once.
 *
 * UI/UX Refresh Phase 5: chrome rebuilt on the shared primitives; UI glyphs replaced
 * with SVG icons and emoji removed from log text — migration logic unchanged.
 */
interface DataMigrationProps {
  navigation: { goBack: () => void };
}

export default function DataMigration({ navigation }: DataMigrationProps) {
  const [isRunning, setIsRunning] = useState(false);
  const [logs, setLogs] = useState<string[]>([]);

  const addLog = (message: string) => {
    const timestamp = new Date().toTimeString().substring(0, 8);
    setLogs((prev) => [...prev, `[${timestamp}] ${message}`]);
  };

  const runMigration = async () => {
    setIsRunning(true);
    setLogs([]);

    try {
      addLog('Starting data migration...');

      addLog('Step 1: Creating default company...');
      const companyRef = await firestore().collection('companies').add({
        name: 'Default Company',
        email: 'admin@podsafe.com',
        phone: '+1234567890',
        address: '123 Main Street, City, Country',
        plan: 'free',
        isActive: true,
        createdAt: firestore.FieldValue.serverTimestamp(),
        settings: { autoApproveDrivers: false, requireDriverApproval: true },
      });
      const defaultCompanyId = companyRef.id;
      addLog(`Default company created with ID: ${defaultCompanyId}`);

      addLog('Step 2: Updating existing users...');
      const usersSnapshot = await firestore().collection('users').get();
      let usersUpdated = 0;
      for (const doc of usersSnapshot.docs) {
        const data = doc.data();
        if (!data.companyId) {
          await doc.ref.update({
            companyId: defaultCompanyId,
            approvalStatus: 'approved',
            updatedAt: firestore.FieldValue.serverTimestamp(),
          });
          usersUpdated += 1;
          addLog(`  Updated user: ${data.email} (${data.role ?? 'driver'})`);
        }
      }
      addLog(`Updated ${usersUpdated} users`);

      addLog('Step 3: Updating existing deliveries...');
      const deliveriesSnapshot = await firestore().collection('deliveries').get();
      let deliveriesUpdated = 0;
      for (const doc of deliveriesSnapshot.docs) {
        const data = doc.data();
        if (!data.companyId) {
          await doc.ref.update({ companyId: defaultCompanyId });
          deliveriesUpdated += 1;
          addLog(`  Updated delivery: ${doc.id}`);
        }
      }
      addLog(`Updated ${deliveriesUpdated} deliveries`);

      addLog('');
      addLog('Migration completed successfully.');
      addLog('');
      addLog('Summary:');
      addLog(`  Company ID: ${defaultCompanyId}`);
      addLog(`  Users updated: ${usersUpdated}`);
      addLog(`  Deliveries updated: ${deliveriesUpdated}`);
      addLog('');
      addLog('All existing users are now part of "Default Company".');
      addLog('All existing drivers are approved and active.');

      Alert.alert(
        'Migration Complete',
        `Your data has been successfully migrated to the multi-company system.\n\nCompany Code: ${defaultCompanyId}\n\n${usersUpdated} users updated\n${deliveriesUpdated} deliveries updated\nAll drivers approved`,
        [{ text: 'Done', onPress: () => navigation.goBack() }],
      );
    } catch (e) {
      addLog('');
      addLog(`ERROR: ${(e as Error).message}`);
      addLog('');
      addLog('Migration failed. Please try again or contact support.');
      Alert.alert('Migration Failed', `Error: ${(e as Error).message}`);
    } finally {
      setIsRunning(false);
    }
  };

  return (
    <Screen contentContainerStyle={styles.content}>
      <Card padding="spacious" style={styles.infoCard}>
        <View style={styles.infoHeader}>
          <AppIcon name="info" size={20} color={colors.active} />
          <Text style={textStyles.heading3}>Multi-Company Migration</Text>
        </View>
        <Text style={[textStyles.label, styles.infoLabel]}>This migration will:</Text>
        <Text style={[textStyles.bodyMedium, styles.infoText]}>
          {'• Create a "Default Company" for existing data\n'}
          {'• Add companyId to all existing users\n'}
          {'• Add companyId to all existing deliveries\n'}
          {'• Approve all existing drivers automatically'}
        </Text>
        <View style={styles.warningBox}>
          <AppIcon name="alert" size={18} color={colors.attention} />
          <Text style={styles.warningText}>This is a one-time migration. Run it only once.</Text>
        </View>
      </Card>

      <PrimaryButton
        label={isRunning ? 'Running migration...' : 'Run migration'}
        icon={isRunning ? undefined : 'arrowRight'}
        loading={isRunning}
        disabled={isRunning}
        onPress={runMigration}
        style={styles.runButton}
      />

      {logs.length > 0 ? (
        <View style={styles.logsSection}>
          <Text style={[textStyles.heading3, styles.logsTitle]}>Migration Log</Text>
          <FlatList
            style={styles.logsBox}
            data={logs}
            keyExtractor={(_, index) => index.toString()}
            renderItem={({ item }) => <Text style={styles.logLine}>{item}</Text>}
          />
        </View>
      ) : (
        <View style={styles.emptyWrap}>
          <EmptyState
            title="Ready to migrate"
            message="Run the one-time migration above to move existing data into the multi-company structure."
            icon="upload"
          />
        </View>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: { flex: 1, paddingVertical: spacing.medium },
  infoCard: { gap: spacing.small },
  infoHeader: { alignItems: 'center', flexDirection: 'row', gap: spacing.small },
  infoLabel: { marginTop: spacing.small },
  infoText: { color: colors.contentSecondary, lineHeight: 20 },
  warningBox: {
    alignItems: 'center',
    backgroundColor: colors.attentionMuted,
    borderRadius: radii.borderRadius,
    flexDirection: 'row',
    gap: spacing.small,
    marginTop: spacing.small,
    padding: spacing.small + 4,
  },
  warningText: { ...textStyles.bodySmall, color: colors.contentPrimary, flex: 1 },
  runButton: { marginTop: spacing.large },
  logsSection: { flex: 1, marginTop: spacing.large },
  logsTitle: { marginBottom: spacing.small },
  logsBox: {
    backgroundColor: colors.surfaceMuted,
    borderColor: colors.border,
    borderRadius: radii.borderRadius,
    borderWidth: 1,
    padding: spacing.medium,
  },
  logLine: { color: colors.contentPrimary, fontFamily: 'monospace', fontSize: 12, marginBottom: 4 },
  emptyWrap: { flex: 1, justifyContent: 'center' },
});
