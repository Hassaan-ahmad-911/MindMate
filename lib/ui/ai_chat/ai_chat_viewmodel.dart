import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/rag_api_service.dart';

class AiChatViewModel extends GetxController {
  final TextEditingController inputController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final RxBool isTyping = false.obs;
  final RxString systemStatus = 'Online'.obs;

  final List<String> quickSuggestions = const <String>[
    'I feel stressed',
    'Talk about my day',
    'I need motivation',
    'Help me relax',
  ];

  final RxList<ChatMessage> messages = <ChatMessage>[].obs;

  String get statusLabel => isTyping.value ? 'Thinking...' : 'Online';

  void useSuggestion(String text) {
    inputController.text = text;

    inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }

  Future<void> sendCurrentMessage() async {
    final String text = inputController.text.trim();

    if (text.isEmpty) {
      return;
    }

    // Prevent sending another message while AI is responding.
    if (isTyping.value) {
      return;
    }

    // Earlier messages, collected before the new one is added.
    final List<Map<String, String>> history = _recentHistory();

    // Add user's message to the chat.
    messages.add(
      ChatMessage(text: text, sentByUser: true, timestamp: _currentTimeLabel()),
    );

    // Clear text field.
    inputController.clear();

    _scrollToBottom();

    // Show AI typing state.
    isTyping.value = true;
    systemStatus.value = 'Analyzing your thoughts...';

    try {
      // Send message to the Python RAG API.
      final String answer = await RagApiService.sendMessage(
        text,
        history: history,
      );

      systemStatus.value = 'AI is typing...';

      // Small delay for natural typing experience.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Add RAG response to chat.
      messages.add(
        ChatMessage(
          text: answer,
          sentByUser: false,
          timestamp: _currentTimeLabel(),
        ),
      );
    } catch (e) {
      // Show friendly error inside chat.
      messages.add(
        ChatMessage(
          text: _connectionErrorText,
          sentByUser: false,
          timestamp: _currentTimeLabel(),
        ),
      );
    } finally {
      isTyping.value = false;
      systemStatus.value = 'Online';

      _scrollToBottom();
    }
  }

  static const String _connectionErrorText =
      'Sorry, I could not connect to MindMate AI right now. Please try again.';

  /// The last few chat messages for the server, oldest first, without
  /// error messages. Each is cut to [RagApiService.historyMaxChars].
  List<Map<String, String>> _recentHistory() {
    final List<ChatMessage> usable = messages
        .where(
          (ChatMessage message) =>
              message.sentByUser ||
              (message.text != _connectionErrorText &&
                  !RagApiService.isErrorReply(message.text)),
        )
        .toList();

    final int start = usable.length > RagApiService.historyMaxMessages
        ? usable.length - RagApiService.historyMaxMessages
        : 0;

    return usable
        .sublist(start)
        .map(
          (ChatMessage message) => <String, String>{
            'role': message.sentByUser ? 'user' : 'assistant',
            'content': message.text.characters
                .take(RagApiService.historyMaxChars)
                .toString(),
          },
        )
        .toList();
  }

  void _scrollToBottom() {
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (!scrollController.hasClients) {
        return;
      }

      scrollController.animateTo(
        scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String _currentTimeLabel() {
    final DateTime now = DateTime.now();

    final int hour = now.hour == 0
        ? 12
        : (now.hour > 12 ? now.hour - 12 : now.hour);

    final String minute = now.minute.toString().padLeft(2, '0');

    final String period = now.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  @override
  void onClose() {
    inputController.dispose();
    scrollController.dispose();

    super.onClose();
  }
}

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.sentByUser,
    required this.timestamp,
  });

  final String text;
  final bool sentByUser;
  final String timestamp;
}
