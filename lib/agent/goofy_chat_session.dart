import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_litertlm/litertlm.dart';

import 'agent.dart';
import 'chat_store.dart';

/// One conversation in the Chats list — the `flutter_litertlm`-backed
/// implementation of [ChatSession].
///
/// Owns a single [Conversation] plus its message list and composing state. The
/// engine that creates the conversation is owned by the [GoofyAgent]; this
/// session only drives a single chat. Widgets stay dumb: they read this through
/// the [ChatSession] interface and call its intents.
class GoofyChatSession extends ChatSession {
  GoofyChatSession({
    required this.id,
    required this.title,
    String? greeting,
    List<ChatMessage>? messages,
    DateTime? lastActivity,
  }) : messages =
           messages ??
           [if (greeting != null) ChatMessage(text: greeting, isUser: false)],
       lastActivity = lastActivity ?? DateTime.now();

  /// Rebuilds a session from its persisted record.
  factory GoofyChatSession.fromRecord(ChatRecord record) {
    return GoofyChatSession(
      id: record.id,
      title: record.title,
      messages: record.messages.map(_chatFromMessage).toList(),
      lastActivity: record.lastActivity,
    );
  }

  /// Stable identity used to persist and re-bind this chat across restarts.
  final String id;

  @override
  final String title;

  @override
  final List<ChatMessage> messages;

  Conversation? _conversation;

  @override
  bool get isReady => _conversation != null;

  bool _isResponding = false;
  @override
  bool get isResponding => _isResponding;

  String? _attachedImagePath;
  @override
  String? get attachedImagePath => _attachedImagePath;

  @override
  DateTime lastActivity;

  @override
  bool get canCompose => isReady && !_isResponding;

  @override
  String get previewText {
    for (final message in messages.reversed) {
      if (!message.isUser && message.text.isNotEmpty) return message.text;
    }
    return 'Tap to chat locally';
  }

  @override
  String get statusLabel =>
      _isResponding ? 'Typing\u2026' : 'On-device \u2022 Gemma E2B';

  /// Called by the [GoofyAgent] once the engine is ready.
  void bindConversation(Conversation conversation) {
    final previous = _conversation;
    _conversation = conversation;
    unawaited(previous?.dispose());
    notifyListeners();
  }

  /// Snapshot of this chat for the on-disk history, stored as the same native
  /// [Message]s that are sent to the model (role + content). The canned
  /// greeting, errors and still-streaming bubbles are skipped.
  ChatRecord toRecord() {
    return ChatRecord(
      id: id,
      title: title,
      lastActivity: lastActivity,
      messages: toModelMessages(),
    );
  }

  /// True when there is real history worth replaying into a rebuilt engine
  /// conversation (anything beyond the canned greeting).
  bool get hasHistory =>
      messages.any((message) => message.isUser && !message.isError);

  /// The conversation as native [Message]s — the exact shape sent to the model.
  /// Used both to persist history and to rebuild engine context on resume.
  /// Errors and the canned greeting (assistant text before any user turn) are
  /// skipped; images travel as embedded bytes, never as a path reference.
  List<Message> toModelMessages() {
    final result = <Message>[];
    var sawUser = false;
    for (final message in messages) {
      if (message.isError || message.isPending) continue;
      if (message.isUser) {
        sawUser = true;
        final imageBytes = message.imageBytes;
        if (imageBytes != null) {
          result.add(
            Message.user(
              Contents.of([
                Content.imageData(imageBytes),
                if (message.text.isNotEmpty) Content.text(message.text),
              ]),
            ),
          );
        } else if (message.text.isNotEmpty) {
          result.add(Message.user(message.text));
        }
      } else {
        // Skip the leading greeting (assistant text before any user turn); it
        // was never produced by the model.
        if (!sawUser || message.text.isEmpty) continue;
        result.add(Message.model(contents: Contents.of(message.text)));
      }
    }
    return result;
  }

  /// Converts a persisted native [Message] back into a display turn.
  static ChatMessage _chatFromMessage(Message message) {
    Uint8List? bytes;
    for (final content in message.contents.contents) {
      if (content is ImageDataContent) {
        bytes = content.data;
        break;
      }
    }
    return ChatMessage(
      text: message.text,
      isUser: message.role == Role.user,
      imageBytes: bytes,
    );
  }

  // --- Composing -----------------------------------------------------------

  @override
  void attachImage(String path) {
    _attachedImagePath = path;
    notifyListeners();
  }

  @override
  void removeAttachedImage() {
    _attachedImagePath = null;
    notifyListeners();
  }

  @override
  void addErrorMessage(String text) {
    messages.add(ChatMessage(text: text, isUser: false, isError: true));
    notifyListeners();
  }

  @override
  Future<void> send(String rawText) async {
    final prompt = rawText.trim();
    final pickedImagePath = _attachedImagePath;
    final conversation = _conversation;
    if ((prompt.isEmpty && pickedImagePath == null) ||
        conversation == null ||
        _isResponding) {
      return;
    }

    if (_wouldExceedContext(conversation, prompt, pickedImagePath != null)) {
      addErrorMessage(
        'This chat reached its on-device memory limit. Start a new chat to '
        'keep going.',
      );
      return;
    }

    // Read the picked image's bytes now, while the file picker's sandbox grant
    // is still valid, and send them embedded. The native runtime opens a path
    // reference lazily at inference time; sending the actual data means
    // generation never depends on filesystem permissions later.
    Uint8List? imageBytes;
    if (pickedImagePath != null) {
      try {
        imageBytes = await File(pickedImagePath).readAsBytes();
      } catch (error, stackTrace) {
        debugPrint('Failed to read attachment bytes: $error\n$stackTrace');
      }
    }

    final message = imageBytes == null
        ? Message.user(prompt)
        : Message.user(
            Contents.of([
              Content.imageData(imageBytes),
              if (prompt.isNotEmpty) Content.text(prompt),
            ]),
          );

    messages.add(
      ChatMessage(text: prompt, isUser: true, imageBytes: imageBytes),
    );
    final reply = ChatMessage(text: '', isUser: false);
    messages.add(reply);
    _isResponding = true;
    _attachedImagePath = null;
    lastActivity = DateTime.now();
    notifyListeners();

    final buffer = StringBuffer();
    try {
      await for (final chunk in conversation.sendMessageStream(message)) {
        buffer.write(chunk.text);
        _replaceMessage(reply.id, text: buffer.toString());
      }
      _replaceMessage(reply.id, text: buffer.toString().trim());
    } catch (error, stackTrace) {
      debugPrint('Local generation failed: $error\n$stackTrace');
      _replaceMessage(
        reply.id,
        text: 'Local generation failed.\n\n$error',
        isError: true,
      );
    } finally {
      _isResponding = false;
      lastActivity = DateTime.now();
      notifyListeners();
    }
  }

  void _replaceMessage(int id, {required String text, bool? isError}) {
    final index = messages.indexWhere((message) => message.id == id);
    if (index == -1) return;
    messages[index] = messages[index].copyWith(text: text, isError: isError);
    notifyListeners();
  }

  // Gemma encodes each image as ~256 KV-cache tokens and text at ~4 chars per
  // token. Refusing an over-budget turn turns a silent native hang on context
  // overflow into a clear, recoverable message.
  bool _wouldExceedContext(
    Conversation conversation,
    String prompt,
    bool hasImage,
  ) {
    final maxTokens = conversation.maxNumTokens;
    if (maxTokens == null) return false;
    final int used;
    try {
      used = conversation.getTokenCount();
    } on Object {
      return false;
    }
    if (used < 0) return false;
    const tokensPerImage = 256;
    const decodeReserve = 256;
    final incoming =
        (hasImage ? tokensPerImage : 0) + (prompt.length / 4).ceil();
    return used + incoming + decodeReserve > maxTokens;
  }

  @override
  void dispose() {
    unawaited(_conversation?.dispose());
    super.dispose();
  }
}
