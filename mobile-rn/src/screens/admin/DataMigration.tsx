import React, { useState } from 'react';
import { ActivityIndicator, Alert, FlatList, Pressable, StyleSheet, Text, View } from 'react-native';
import firestore from '@react-native-firebase/firestore';
import { colors, spacing, radii } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/data_migration_screen.dart (verified against source on
 * 2026-06-22) — a one-off admin tool that migrates legacy single-company data into the
 * multi-company structure (creates a "Default Company", backfills companyId onto
 * existing users/deliveries, auto-approves existing drivers).
 *
 * This is pure client-side Firestore logic in the Dart source too (no service/Cloud
 * Function involved despite being a migration tool) — kept inline here rather than
 * adding a repository for a script that's explicitly meant to run once.
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
      addLog('🚀 Starting data migration...');

      addLog('📝 Step 1: Creating default company...');
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
      addLog(`✅ Default company created with ID: ${defaultCompanyId}`);

      addLog('📝 Step 2: Updating existing users...');
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
          addLog(`  ✓ Updated user: ${data.email} (${data.role ?? 'driver'})`);
        }
      }
      addLog(`✅ Updated ${usersUpdated} users`);

      addLog('📝 Step 3: Updating existing deliveries...');
      const deliveriesSnapshot = await firestore().collection('deliveries').get();
      let deliveriesUpdated = 0;
      for (const doc of deliveriesSnapshot.docs) {
        const data = doc.data();
        if (!data.companyId) {
          await doc.ref.update({ companyId: defaultCompanyId });
          deliveriesUpdated += 1;
          addLog(`  ✓ Updated delivery: ${doc.id}`);
        }
      }
      addLog(`✅ Updated ${deliveriesUpdated} deliveries`);

      addLog('');
      addLog('🎉 Migration completed successfully!');
      addLog('');
      addLog('Summary:');
      addLog(`  • Company ID: ${defaultCompanyId}`);
      addLog(`  • Users updated: ${usersUpdated}`);
      addLog(`  • Deliveries updated: ${deliveriesUpdated}`);
      addLog('');
      addLog('ℹ️  All existing users are now part of "Default Company"');
      addLog('ℹ️  All existing drivers are approved and active');

      Alert.alert(
        'Migration Complete',
        `Your data has been successfully migrated to the multi-company system.\n\nCompany Code: ${defaultCompanyId}\n\n${usersUpdated} users updated\n${deliveriesUpdated} deliveries updated\nAll drivers approved`,
        [{ text: 'Done', onPress: () => navigation.goBack() }],
      );
    } catch (e) {
      addLog('');
      addLog(`❌ ERROR: ${(e as Error).message}`);
      addLog('');
      addLog('Migration failed. Please try again or contact support.');
      Alert.alert('Migration Failed', `Error: ${(e as Error).message}`);
    } finally {
      setIsRunning(false);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.infoBox}>
        <Text style={textStyles.heading3}>ℹ️ Multi-Company Migration</Text>
        <Text style={styles.infoBoxLabel}>This migration will:</Text>
        <Text style={styles.infoBoxText}>
          {'• Create a "Default Company" for existing data\n'}
          {'• Add companyId to all existing users\n'}
          {'• Add companyId to all existing deliveries\n'}
          {'• Approve all existing drivers automatically'}
        </Text>
        <View style={styles.warningBox}>
          <Text style={styles.warningText}>⚠ This is a one-time migration. Run it only once.</Text>
        </View>
      </View>

      <Pressable style={[styles.runButton, isRunning && styles.runButtonDisabled]} disabled={isRunning} onPress={runMigration}>
        {isRunning ? <ActivityIndicator color={colors.white} /> : null}
        <Text style={textStyles.buttonText}>{isRunning ? 'Running Migration...' : '▶ Run Migration'}</Text>
      </Pressable>

      {logs.length > 0 ? (
        <View style={styles.logsSection}>
          <Text style={textStyles.heading3}>Migration Log</Text>
          <FlatList
            style={styles.logsBox}
            data={logs}
            keyExtractor={(_, index) => index.toString()}
            renderItem={({ item }) => <Text style={styles.logLine}>{item}</Text>}
          />
        </View>
      ) : (
        <View style={styles.emptyState}>
          <Text style={styles.emptyStateTitle}>Ready to migrate</Text>
          <Text style={styles.emptyStateSubtitle}>Tap the button above to start</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background, padding: spacing.large },
  infoBox: {
    backgroundColor: `${colors.info}14`,
    borderRadius: radii.borderRadius,
    borderWidth: 1,
    borderColor: `${colors.info}66`,
    padding: spacing.medium,
  },
  infoBoxLabel: { fontWeight: 'bold', color: colors.info, marginTop: spacing.medium },
  infoBoxText: { color: colors.info, marginTop: spacing.small, lineHeight: 20 },
  warningBox: {
    flexDirection: 'row',
    backgroundColor: `${colors.warning}14`,
    borderRadius: radii.borderRadius,
    borderWidth: 1,
    borderColor: `${colors.warning}80`,
    padding: spacing.small + 4,
    marginTop: spacing.medium,
  },
  warningText: { color: colors.warning, fontWeight: '500', fontSize: 13, flex: 1 },
  runButton: {
    flexDirection: 'row',
    gap: spacing.small,
    backgroundColor: colors.primary,
    borderRadius: radii.buttonRadius,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: spacing.medium,
    marginTop: spacing.large,
  },
  runButtonDisabled: { opacity: 0.6 },
  logsSection: { flex: 1, marginTop: spacing.large },
  logsBox: { backgroundColor: '#1A1A1A', borderRadius: radii.borderRadius, padding: spacing.medium, marginTop: spacing.small + 4 },
  logLine: { color: colors.white, fontFamily: 'monospace', fontSize: 12, marginBottom: 4 },
  emptyState: { flex: 1, alignItems: 'center', justifyContent: 'center', marginTop: spacing.large },
  emptyStateTitle: { color: colors.textSecondary, fontSize: 16 },
  emptyStateSubtitle: { color: colors.textSecondary, fontSize: 12, marginTop: spacing.small },
});
