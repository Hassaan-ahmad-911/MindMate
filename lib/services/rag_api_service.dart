import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RagApiService {
  /// The chat server. By default the one running on the development
  /// computer, reached as localhost: over USB (VS Code's "MindMate" launch
  /// forwards the port with `adb reverse tcp:8001 tcp:8001`), or directly on
  /// web and desktop. Another address can be given with
  /// `--dart-define=RAG_BASE_URL=...` (for example http://10.0.2.2:8001 on
  /// the emulator).
  static const String baseUrl = String.fromEnvironment(
    'RAG_BASE_URL',
    defaultValue: 'http://localhost:8001',
  );

  static const Duration timeout = Duration(seconds: 20);

  /// How much of the conversation is sent with each message, so MindMate
  /// can follow it (e.g. remember the user's name).
  static const int historyMaxMessages = 6;
  static const int historyMaxChars = 500;

  static const String noAnswerMessage =
      'Sorry, I could not generate a response.';
  static const String serverErrorMessage =
      'MindMate could not process your request.';
  static const String connectionErrorMessage =
      'Unable to connect to MindMate AI. Please try again.';

  static const List<String> _errorMessages = <String>[
    noAnswerMessage,
    serverErrorMessage,
    connectionErrorMessage,
  ];

  /// True for error texts, which are left out of the history. Includes the
  /// server's "temporarily unavailable" reply.
  static bool isErrorReply(String text) =>
      _errorMessages.contains(text) || text.contains('temporarily unavailable');

  /// [history] holds the earlier messages, oldest first, as
  /// {"role": "user" | "assistant", "content": "..."}.
  static Future<String> sendMessage(
    String message, {
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/chat'),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'message': message,
              'history': history,
            }),
          )
          .timeout(timeout);

      // Never log the message or the answer: both are private.
      debugPrint('RAG status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        return data['answer']?.toString() ?? noAnswerMessage;
      }

      return serverErrorMessage;
    } catch (e) {
      debugPrint('RAG connection error (${e.runtimeType}).');

      return connectionErrorMessage;
    }
  }
}
