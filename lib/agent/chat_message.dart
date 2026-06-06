import 'dart:typed_data';

/// A single chat turn rendered in the conversation.
///
/// Pure presentation data — it carries no knowledge of the inference engine.
/// The agent layer converts between these and the engine's native messages.
class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.imageBytes,
    int? id,
  }) : id = id ?? _nextId++;

  static int _nextId = 0;

  final int id;
  final String text;
  final bool isUser;
  final bool isError;

  /// The attached image's raw bytes, kept in-memory and persisted by the agent
  /// so the bubble renders and resumes without depending on the original file.
  final Uint8List? imageBytes;

  bool get hasImage => imageBytes != null;

  /// True while an assistant message is still empty (show typing indicator).
  bool get isPending => !isUser && text.isEmpty && !isError;

  ChatMessage copyWith({String? text, bool? isError}) {
    return ChatMessage(
      id: id,
      text: text ?? this.text,
      isUser: isUser,
      isError: isError ?? this.isError,
      imageBytes: imageBytes,
    );
  }
}
