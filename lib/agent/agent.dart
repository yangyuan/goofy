import 'package:flutter/foundation.dart';

import 'chat_message.dart';
import 'model_store.dart' show ModelDownloadProgress;

export 'chat_message.dart';
export 'goofy_agent.dart';
export 'goofy_chat_session.dart';
export 'model_store.dart' show ModelDownloadProgress;

/// Lifecycle of the on-device model, surfaced to the UI as a friendly status.
enum AgentPhase { preparing, needsDownload, downloading, loading, ready, error }

enum AgentBackend {
  cpu('CPU'),
  gpu('GPU');

  const AgentBackend(this.label);

  final String label;
}

/// The app-facing assistant.
///
/// Owns the on-device model lifecycle and the list of chat sessions, hiding the
/// inference engine entirely. The UI depends only on this interface — never on
/// `flutter_litertlm`.
abstract class Agent extends ChangeNotifier {
  /// Chats, newest first.
  List<ChatSession> get sessions;

  AgentPhase get phase;
  ModelDownloadProgress? get downloadProgress;
  AgentBackend get selectedBackend;

  bool get isReady;
  bool get isBusy;

  /// Short engine status shown while a chat has no live conversation yet.
  String get statusLabel;

  /// Restores saved chats and brings the model online.
  Future<void> prepare();

  /// Downloads the model on first run.
  Future<void> downloadModel();

  /// Loads an already-downloaded model.
  Future<void> loadModel();

  /// Chooses the backend and reloads the model when it is already local.
  Future<void> selectBackend(AgentBackend backend);

  /// Starts a fresh chat and returns it.
  ChatSession newChat();

  /// Removes a chat permanently and forgets its saved history.
  void deleteChat(ChatSession session);
}

/// A single conversation.
///
/// The UI reads its state and calls its intents; it never sees the engine's
/// native messages.
abstract class ChatSession extends ChangeNotifier {
  String get title;
  List<ChatMessage> get messages;

  bool get isReady;
  bool get isResponding;
  bool get canCompose;

  String? get attachedImagePath;
  DateTime get lastActivity;

  /// Last assistant text, used as the conversation-list preview.
  String get previewText;

  /// Short status shown under the chat title.
  String get statusLabel;

  void attachImage(String path);
  void removeAttachedImage();

  /// Records an error bubble in the chat (e.g. a failed attachment).
  void addErrorMessage(String text);

  Future<void> send(String text);
}
