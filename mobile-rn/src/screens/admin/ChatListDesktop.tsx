import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, FlatList, Image, Modal, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import firestore from '@react-native-firebase/firestore';
import { useAuthStore } from '../../stores/useAuthStore';
import { useChatStore } from '../../stores/useChatStore';
import { ChatConversation } from '../../models/chat';
import { userFromFirestore } from '../../models/user.converters';
import { AppUser } from '../../models/user';
import ChatDetailDesktop from './ChatDetailDesktop';
import { colors, radii, shadows, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/chat_list_screen_desktop.dart (verified against source on
 * 2026-06-23). Desktop-only, zero admin mobile equivalent (confirmed via vault Inventory).
 * Registered in AdminStack.tsx rather than a separate AdminWebRoutes.tsx — that file and the
 * RNW web entry point (index.web.js) don't exist yet (Phase 1 remaining work); revisit once
 * they do.
 *
 * Split-pane layout mirrors the Dart source: 350px conversation list + divider + detail pane,
 * not two separate routes. The Dart source's `_DriverSelectionDialog` becomes a Modal here.
 * `ChatListItem` (lib/widgets/message_bubble.dart) is ported as a local component, screen-only
 * (still not used anywhere else, same as message_bubble.dart's `TypingIndicator`, which stays
 * unported — unused in both the Dart desktop chat screens and the RN driver Chat.tsx).
 */
export default function ChatListDesktop() {
  const currentUser = useAuthStore((s) => s.currentUser);
  const conversations = useChatStore((s) => s.conversations);
  const subscribeToConversations = useChatStore((s) => s.subscribeToConversations);
  const searchConversations = useChatStore((s) => s.searchConversations);
  const getOrCreateConversation = useChatStore((s) => s.getOrCreateConversation);

  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<ChatConversation[]>([]);
  const [selectedConversationId, setSelectedConversationId] = useState<string | null>(null);
  const [showDriverPicker, setShowDriverPicker] = useState(false);

  useEffect(() => {
    if (!currentUser) return;
    const unsubscribe = subscribeToConversations(currentUser.companyId, currentUser.id);
    return unsubscribe;
  }, [currentUser, subscribeToConversations]);

  useEffect(() => {
    if (!currentUser || searchQuery.trim().length === 0) {
      setSearchResults([]);
      return;
    }
    let isMounted = true;
    searchConversations(currentUser.companyId, searchQuery).then((results) => {
      if (isMounted) setSearchResults(results);
    });
    return () => {
      isMounted = false;
    };
  }, [currentUser, searchQuery, searchConversations]);

  if (!currentUser) {
    return (
      <View style={styles.centered}>
        <Text style={textStyles.bodyMedium}>Please log in</Text>
      </View>
    );
  }

  const isSearching = searchQuery.trim().length > 0;
  const listData = isSearching ? searchResults : conversations;
  const selectedConversation = conversations.find((c) => c.id === selectedConversationId) ?? null;

  const handleDriverSelected = async (driver: AppUser) => {
    setShowDriverPicker(false);
    try {
      const conversationId = await getOrCreateConversation({
        companyId: currentUser.companyId,
        driverId: driver.id,
        driverName: driver.fullName,
        driverImageUrl: driver.profileImageUrl,
        adminId: currentUser.id,
        adminName: currentUser.fullName,
        adminImageUrl: currentUser.profileImageUrl,
      });
      if (conversationId) setSelectedConversationId(conversationId);
    } catch (e) {
      Alert.alert('Error', (e as Error).message);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={[textStyles.heading3, { color: colors.onPrimary }]}>💬 Messages</Text>
        <Pressable style={styles.headerBarAction} onPress={() => setShowDriverPicker(true)}>
          <Text style={styles.headerBarActionText}>+ New</Text>
        </Pressable>
      </View>

      <View style={styles.body}>
        <View style={styles.sidebar}>
          <View style={styles.searchBox}>
            <TextInput
              style={styles.searchInput}
              placeholder="Search conversations..."
              value={searchQuery}
              onChangeText={setSearchQuery}
            />
          </View>

          {listData.length === 0 ? (
            <View style={styles.centered}>
              <Text style={styles.emptyIcon}>{isSearching ? '🔍' : '📥'}</Text>
              <Text style={textStyles.bodyMedium}>{isSearching ? 'No conversations found' : 'No conversations yet'}</Text>
            </View>
          ) : (
            <FlatList
              data={listData}
              keyExtractor={(item) => item.id}
              renderItem={({ item }) => (
                <ChatListItem
                  conversation={item}
                  unreadCount={item.unreadCount[currentUser.id] ?? 0}
                  isSelected={selectedConversationId === item.id}
                  onPress={() => setSelectedConversationId(item.id)}
                />
              )}
            />
          )}
        </View>

        <View style={styles.divider} />

        <View style={styles.detailPane}>
          {selectedConversation ? (
            <ChatDetailDesktop conversation={selectedConversation} onClose={() => setSelectedConversationId(null)} />
          ) : (
            <View style={styles.centered}>
              <Text style={styles.emptyIconLarge}>💬</Text>
              <Text style={textStyles.bodyMedium}>Select a conversation to start messaging</Text>
            </View>
          )}
        </View>
      </View>

      <DriverPickerModal visible={showDriverPicker} companyId={currentUser.companyId} onClose={() => setShowDriverPicker(false)} onSelect={handleDriverSelected} />
    </View>
  );
}

function formatConversationTime(date: Date): string {
  const isWithinLastDay = Date.now() - date.getTime() < 24 * 60 * 60 * 1000;
  if (isWithinLastDay) {
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
  }
  return date.toLocaleDateString(undefined, { month: 'short', day: '2-digit' });
}

function ChatListItem({
  conversation,
  unreadCount,
  isSelected,
  onPress,
}: {
  conversation: ChatConversation;
  unreadCount: number;
  isSelected: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable style={[styles.listItem, isSelected && styles.listItemSelected]} onPress={onPress}>
      {conversation.driverImageUrl ? (
        <Image source={{ uri: conversation.driverImageUrl }} style={styles.avatar} />
      ) : (
        <View style={[styles.avatar, styles.avatarFallback]}>
          <Text style={styles.avatarInitial}>{conversation.driverName.charAt(0).toUpperCase()}</Text>
        </View>
      )}
      <View style={styles.listItemText}>
        <Text style={styles.listItemName} numberOfLines={1}>
          {conversation.driverName}
        </Text>
        <Text style={styles.listItemMessage} numberOfLines={1}>
          {conversation.lastMessage}
        </Text>
      </View>
      <View style={styles.listItemTrailing}>
        <Text style={styles.listItemTime}>{formatConversationTime(conversation.lastMessageAt)}</Text>
        {unreadCount > 0 ? (
          <View style={styles.unreadBadge}>
            <Text style={styles.unreadBadgeText}>{unreadCount > 99 ? '99+' : unreadCount}</Text>
          </View>
        ) : null}
      </View>
    </Pressable>
  );
}

function DriverPickerModal({
  visible,
  companyId,
  onClose,
  onSelect,
}: {
  visible: boolean;
  companyId: string;
  onClose: () => void;
  onSelect: (driver: AppUser) => void;
}) {
  const [drivers, setDrivers] = useState<AppUser[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [query, setQuery] = useState('');

  useEffect(() => {
    if (!visible) return;
    setIsLoading(true);
    firestore()
      .collection('users')
      .where('companyId', '==', companyId)
      .where('role', '==', 'driver')
      .where('isActive', '==', true)
      .get()
      .then((snapshot) => setDrivers(snapshot.docs.map(userFromFirestore)))
      .finally(() => setIsLoading(false));
  }, [visible, companyId]);

  const filtered = drivers.filter((d) => {
    const q = query.toLowerCase();
    return d.fullName.toLowerCase().includes(q) || d.email.toLowerCase().includes(q);
  });

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.pickerBackdrop}>
        <View style={[styles.pickerCard, shadows.card]}>
          <View style={styles.pickerHeader}>
            <Text style={textStyles.heading3}>Select Driver</Text>
            <Pressable onPress={onClose}>
              <Text style={styles.pickerCloseGlyph}>✕</Text>
            </Pressable>
          </View>
          <TextInput style={styles.searchInput} placeholder="Search drivers..." value={query} onChangeText={setQuery} />
          {isLoading ? (
            <ActivityIndicator color={colors.primary} style={styles.pickerLoading} />
          ) : filtered.length === 0 ? (
            <View style={styles.centered}>
              <Text style={textStyles.bodyMedium}>{drivers.length === 0 ? 'No active drivers found' : 'No drivers match your search'}</Text>
            </View>
          ) : (
            <FlatList
              data={filtered}
              keyExtractor={(item) => item.id}
              renderItem={({ item }) => (
                <Pressable style={styles.pickerRow} onPress={() => onSelect(item)}>
                  {item.profileImageUrl ? (
                    <Image source={{ uri: item.profileImageUrl }} style={styles.avatar} />
                  ) : (
                    <View style={[styles.avatar, styles.avatarFallback]}>
                      <Text style={styles.avatarInitial}>{item.fullName.charAt(0).toUpperCase()}</Text>
                    </View>
                  )}
                  <View>
                    <Text style={styles.pickerRowName}>{item.fullName}</Text>
                    <Text style={styles.pickerRowEmail}>{item.email}</Text>
                  </View>
                </Pressable>
              )}
            />
          )}
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  emptyIcon: { fontSize: 32, opacity: 0.4, marginBottom: spacing.small },
  emptyIconLarge: { fontSize: 56, opacity: 0.3, marginBottom: spacing.medium },
  headerBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.medium,
  },
  headerBarAction: { paddingHorizontal: spacing.medium, paddingVertical: spacing.small, borderRadius: radii.buttonRadius, backgroundColor: 'rgba(255,255,255,0.18)' },
  headerBarActionText: { color: colors.white, fontWeight: '600' },
  body: { flex: 1, flexDirection: 'row' },
  sidebar: { width: 350 },
  searchBox: { padding: spacing.small + 4 },
  searchInput: {
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small + 2,
    backgroundColor: colors.card,
  },
  divider: { width: 1, backgroundColor: colors.divider },
  detailPane: { flex: 1 },
  listItem: { flexDirection: 'row', alignItems: 'center', padding: spacing.small + 4 },
  listItemSelected: { backgroundColor: colors.background },
  avatar: { width: 40, height: 40, borderRadius: 20, marginRight: spacing.small },
  avatarFallback: { backgroundColor: colors.divider, alignItems: 'center', justifyContent: 'center' },
  avatarInitial: { color: colors.textPrimary, fontWeight: '600' },
  listItemText: { flex: 1, marginRight: spacing.small },
  listItemName: { fontWeight: '600', color: colors.textPrimary },
  listItemMessage: { color: colors.textSecondary, fontSize: 13, marginTop: 2 },
  listItemTrailing: { alignItems: 'flex-end' },
  listItemTime: { fontSize: 12, color: colors.textSecondary },
  unreadBadge: { marginTop: 4, backgroundColor: colors.primary, borderRadius: 10, paddingHorizontal: 6, paddingVertical: 2 },
  unreadBadgeText: { color: colors.white, fontSize: 10, fontWeight: 'bold' },
  pickerBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  pickerCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: 500, maxHeight: 600 },
  pickerHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.medium },
  pickerCloseGlyph: { fontSize: 20, color: colors.textSecondary },
  pickerLoading: { marginTop: spacing.large },
  pickerRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4 },
  pickerRowName: { fontWeight: '600', color: colors.textPrimary },
  pickerRowEmail: { color: colors.textSecondary, fontSize: 13 },
});
