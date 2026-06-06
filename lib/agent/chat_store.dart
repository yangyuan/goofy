import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_litertlm/litertlm.dart';
import 'package:path_provider/path_provider.dart';

/// One persisted conversation: its identity, title, last activity and the full
/// transcript stored as native `flutter_litertlm` [Message]s — the exact shape
/// (role + content) that is sent to the model, so nothing is translated.
class ChatRecord {
  ChatRecord({
    required this.id,
    required this.title,
    required this.lastActivity,
    required this.messages,
  });

  final String id;
  final String title;
  final DateTime lastActivity;
  final List<Message> messages;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'lastActivity': lastActivity.toIso8601String(),
    'messages': messages.map((message) => message.toJson()).toList(),
  };

  factory ChatRecord.fromJson(Map<String, Object?> json) {
    final rawMessages = json['messages'];
    return ChatRecord(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Goofy',
      lastActivity:
          DateTime.tryParse(json['lastActivity'] as String? ?? '') ??
          DateTime.now(),
      messages: rawMessages is List
          ? rawMessages
                .whereType<Map<String, Object?>>()
                .map(Message.fromJson)
                .toList()
          : <Message>[],
    );
  }
}

/// Reads and writes the full chat history to a single JSON file under the app
/// support directory. The directory is located with `path_provider` so it
/// lands in the right place on every platform.
class ChatStore {
  const ChatStore({this.fileName = 'conversations.json'});

  final String fileName;

  static const _version = 1;

  Future<List<ChatRecord>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return const [];
      final sessions = decoded['sessions'];
      if (sessions is! List) return const [];
      return sessions
          .whereType<Map<String, Object?>>()
          .map(ChatRecord.fromJson)
          .toList();
    } catch (error, stackTrace) {
      _log('Failed to load conversations', error, stackTrace);
      return const [];
    }
  }

  Future<void> save(List<ChatRecord> records) async {
    try {
      final file = await _file();
      final payload = jsonEncode({
        'version': _version,
        'sessions': records.map((record) => record.toJson()).toList(),
      });
      // Write to a temp file then rename so a crash mid-write can't corrupt the
      // existing history.
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(payload, flush: true);
      await temp.rename(file.path);
    } catch (error, stackTrace) {
      _log('Failed to save conversations', error, stackTrace);
    }
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    final chatsDir = Directory('${dir.path}/chats');
    if (!await chatsDir.exists()) {
      await chatsDir.create(recursive: true);
    }
    return File('${chatsDir.path}/$fileName');
  }

  void _log(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: 'goofy.chat_store',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
