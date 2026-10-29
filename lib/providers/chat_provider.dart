import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/chat_message.dart';
import 'package:tpmentorship/models/conversation.dart';
// the chat data types
import 'package:tpmentorship/providers/auth_provider.dart';
// gives us the logged in user
import 'package:tpmentorship/services/chat_service.dart';
// the messaging firestore service

// one shared instance of the chat service for the whole app
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

// every conversation the logged in user is part of, streamed live and
// sorted newest-first - powers the Messages tab
final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const <Conversation>[]);
  return ref.watch(chatServiceProvider).streamConversations(user.uid);
});

// the messages inside one conversation, streamed live
// .family lets each chat screen pass in which conversation it wants
// watches auth state so a stale/errored listener never survives a
// logout+login cycle - see the comment on mentorsProvider for why
final messagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  conversationId,
) {
  ref.watch(authStateProvider);
  return ref.watch(chatServiceProvider).streamMessages(conversationId);
});
