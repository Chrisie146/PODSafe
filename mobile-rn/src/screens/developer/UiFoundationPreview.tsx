import React, { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import {
  AppHeader,
  AppModal,
  Card,
  EmptyState,
  ErrorState,
  FormField,
  LoadingState,
  PrimaryButton,
  Screen,
  SearchField,
  SecondaryButton,
  StatusChip,
} from '../../components/ui';

interface UiFoundationPreviewProps {
  onBack: () => void;
}

/** Development-only acceptance gallery for the shared UI foundation. */
export default function UiFoundationPreview({ onBack }: UiFoundationPreviewProps) {
  const [modalVisible, setModalVisible] = useState(false);
  return (
    <Screen scroll>
      <AppHeader title="UI foundation" subtitle="Phase 1 acceptance gallery" onBack={onBack} />

      <Section title="Buttons">
        <PrimaryButton label="Primary action" icon="check" onPress={() => undefined} />
        <SecondaryButton label="Secondary action" icon="edit" onPress={() => undefined} />
        <PrimaryButton label="Saving changes" loading onPress={() => undefined} />
        <PrimaryButton label="Unavailable action" disabled onPress={() => undefined} />
        <SecondaryButton label="A deliberately long action label that must remain legible" onPress={() => undefined} />
      </Section>

      <Section title="Fields and status">
        <FormField label="Delivery reference" placeholder="Enter a reference" helperText="Helper text remains available to assistive technology." />
        <FormField label="Receiver name" value="" placeholder="Required" error="Enter the receiver’s name before submitting." />
        <SearchField placeholder="Search deliveries" />
        <View style={styles.chips}>
          <StatusChip label="In transit" tone="info" icon="truck" />
          <StatusChip label="Verified" tone="success" icon="check" />
          <StatusChip label="Needs attention" tone="warning" icon="alert" />
          <StatusChip label="Upload failed" tone="error" icon="alert" />
        </View>
      </Section>

      <Section title="States">
        <LoadingState title="Loading deliveries" message="Shows progress without leaving the workspace blank." />
        <EmptyState title="No delivery matches" message="Try a different customer, address, or invoice number." actionLabel="Clear filters" onAction={() => undefined} icon="search" />
        <ErrorState title="Could not load deliveries" message="Check the connection and try again." onAction={() => undefined} />
      </Section>

      <Section title="Modal">
        <PrimaryButton label="Open confirmation dialog" onPress={() => setModalVisible(true)} />
      </Section>

      <AppModal
        visible={modalVisible}
        title="Confirm delivery action"
        onClose={() => setModalVisible(false)}
        footer={<View style={styles.modalActions}><SecondaryButton label="Cancel" onPress={() => setModalVisible(false)} style={styles.modalButton} /><PrimaryButton label="Confirm" onPress={() => setModalVisible(false)} style={styles.modalButton} /></View>}
      >
        <Text style={textStyles.bodyMedium}>The shared modal keeps focus, labels, action sizing, and the safe working surface consistent.</Text>
      </AppModal>
    </Screen>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <Card style={styles.section}>
      <Text style={textStyles.heading3}>{title}</Text>
      <View style={styles.sectionContent}>{children}</View>
    </Card>
  );
}

const styles = StyleSheet.create({
  section: { gap: spacing.medium, marginBottom: spacing.medium },
  sectionContent: { gap: spacing.medium },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  modalActions: { flexDirection: 'row', gap: spacing.small, justifyContent: 'flex-end' },
  modalButton: { flex: 1 },
});
