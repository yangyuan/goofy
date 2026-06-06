import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_litertlm/litertlm.dart';

import 'agent.dart';
import 'chat_store.dart';
import 'model_store.dart';

const _greeting =
    'Hi, I\u2019m Goofy. I run entirely on your device \u2014 nothing you say '
    'leaves this phone.';

/// The `flutter_litertlm`-backed [Agent].
///
/// One engine is loaded once and shared; each chat in the list is an
/// independent [Conversation] created from it. All engine + download calls live
/// here so individual chats — and the whole UI — stay free of engine details.
class GoofyAgent extends Agent {
  GoofyAgent({
    this.modelStore = const ModelStore(),
    this.chatStore = const ChatStore(),
  });

  final ModelStore modelStore;
  final ChatStore chatStore;

  Engine? _engine;
  AgentBackend _selectedBackend = AgentBackend.cpu;

  /// Chats, newest activity first.
  final List<GoofyChatSession> _sessions = [];

  @override
  List<ChatSession> get sessions => _sessions;

  /// Debounces history writes so streaming a reply doesn't hammer the disk.
  Timer? _saveTimer;
  int _sessionSeed = 0;

  AgentPhase _phase = AgentPhase.preparing;
  @override
  AgentPhase get phase => _phase;

  ModelDownloadProgress? _downloadProgress;
  @override
  ModelDownloadProgress? get downloadProgress => _downloadProgress;

  @override
  AgentBackend get selectedBackend => _selectedBackend;

  @override
  bool get isReady => _phase == AgentPhase.ready;

  @override
  bool get isBusy =>
      _phase == AgentPhase.preparing ||
      _phase == AgentPhase.downloading ||
      _phase == AgentPhase.loading;

  @override
  String get statusLabel => switch (_phase) {
    AgentPhase.preparing => 'Waking up\u2026',
    AgentPhase.needsDownload => 'Download needed',
    AgentPhase.downloading => _downloadLabel,
    AgentPhase.loading => 'Loading model\u2026',
    AgentPhase.ready =>
      'On-device \u2022 Gemma E2B \u2022 ${_selectedBackend.label}',
    AgentPhase.error => 'Something went wrong',
  };

  String get _downloadLabel {
    final fraction = _downloadProgress?.fraction;
    if (fraction == null) return 'Downloading\u2026';
    return 'Downloading ${(fraction * 100).clamp(0, 100).toStringAsFixed(0)}%';
  }

  // --- Lifecycle -----------------------------------------------------------

  @override
  Future<void> prepare() async {
    // Restore saved chats first, then ensure at least one chat is visible even
    // before the model is ready.
    await _restoreSessions();
    if (_sessions.isEmpty) _spawnSession();
    try {
      _setPhase(AgentPhase.preparing);
      final model = await modelStore.checkDefaultModel();
      if (!model.exists) {
        _setPhase(AgentPhase.needsDownload);
        return;
      }
      await _initializeEngine(model.path);
    } catch (error, stackTrace) {
      _fail('I couldn\u2019t prepare the local model.', error, stackTrace);
    }
  }

  @override
  Future<void> downloadModel() async {
    ModelFileStatus model;
    try {
      _downloadProgress = null;
      _setPhase(AgentPhase.downloading);
      model = await modelStore.downloadDefaultModel(
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );
      _downloadProgress = null;
    } catch (error, stackTrace) {
      _fail('The download didn\u2019t finish.', error, stackTrace);
      return;
    }

    try {
      await _initializeEngine(model.path);
    } catch (error, stackTrace) {
      _fail('I couldn\u2019t start the local model.', error, stackTrace);
    }
  }

  @override
  Future<void> loadModel() async {
    try {
      final model = await modelStore.checkDefaultModel();
      if (!model.exists) {
        _setPhase(AgentPhase.needsDownload);
        return;
      }
      await _initializeEngine(model.path);
    } catch (error, stackTrace) {
      _fail('I couldn\u2019t start the local model.', error, stackTrace);
    }
  }

  @override
  Future<void> selectBackend(AgentBackend backend) async {
    if (_selectedBackend == backend || isBusy) return;
    _selectedBackend = backend;
    notifyListeners();
    await loadModel();
  }

  Future<void> _initializeEngine(String modelPath) async {
    _setPhase(AgentPhase.loading);
    final backend = _liteRtBackend(_selectedBackend);
    final engine = Engine(
      engineConfig: EngineConfig(
        modelPath: modelPath,
        backend: backend,
        visionBackend: backend,
        maxNumTokens: 8192,
      ),
    );
    await engine.initialize();
    final previousEngine = _engine;
    _engine = engine;

    // Bind a live conversation to any chat opened before the engine was ready.
    // Resumed chats replay their saved transcript so the model has context.
    for (final session in _sessions) {
      session.bindConversation(await _createConversation(engine, session));
    }
    unawaited(previousEngine?.dispose());
    _setPhase(AgentPhase.ready);
  }

  Backend _liteRtBackend(AgentBackend backend) => switch (backend) {
    AgentBackend.cpu => Backend.cpu,
    AgentBackend.gpu => Backend.gpu,
  };

  Future<Conversation> _createConversation(
    Engine engine,
    GoofyChatSession session,
  ) {
    return engine.createConversation(
      ConversationConfig(
        systemMessage: Message.system(
          'You are Goofy, a warm, concise assistant running fully on-device '
          'with Gemma E2B.',
        ),
        initialMessages: session.hasHistory
            ? session.toModelMessages()
            : const [],
        samplerConfig: SamplerConfig(topK: 1, topP: 1, temperature: 0),
      ),
    );
  }

  // --- Sessions ------------------------------------------------------------

  /// Starts a fresh chat. If the engine is already loaded it gets a live
  /// conversation immediately; otherwise it binds once the engine is ready.
  @override
  ChatSession newChat() {
    final session = _spawnSession();
    final engine = _engine;
    if (engine != null) {
      unawaited(
        _createConversation(engine, session).then(session.bindConversation),
      );
    }
    _scheduleSave();
    return session;
  }

  /// Removes a chat permanently and forgets its saved history. Disposes the
  /// session's conversation and rewrites the on-disk history.
  @override
  void deleteChat(ChatSession session) {
    if (!_sessions.remove(session)) return;
    session.removeListener(_onSessionChanged);
    session.dispose();
    notifyListeners();
    _scheduleSave();
  }

  GoofyChatSession _spawnSession() {
    final number = _sessions.length + 1;
    final session = GoofyChatSession(
      id: _newSessionId(),
      title: number == 1 ? 'Goofy' : 'Goofy $number',
      greeting: _greeting,
    );
    session.addListener(_onSessionChanged);
    _sessions.insert(0, session);
    notifyListeners();
    return session;
  }

  String _newSessionId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_sessionSeed++}';

  void _onSessionChanged() {
    notifyListeners();
    _scheduleSave();
  }

  // --- Persistence ---------------------------------------------------------

  Future<void> _restoreSessions() async {
    final records = await chatStore.load();
    if (records.isEmpty) return;
    records.sort((a, b) => a.lastActivity.compareTo(b.lastActivity));
    for (final record in records) {
      final session = GoofyChatSession.fromRecord(record)
        ..addListener(_onSessionChanged);
      _sessions.insert(0, session);
    }
    notifyListeners();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  void _saveNow() {
    final records = _sessions.map((session) => session.toRecord()).toList();
    unawaited(chatStore.save(records));
  }

  // --- Helpers -------------------------------------------------------------

  void _setPhase(AgentPhase phase) {
    _phase = phase;
    notifyListeners();
  }

  void _fail(String friendly, Object error, StackTrace stackTrace) {
    debugPrint('$friendly $error\n$stackTrace');
    _downloadProgress = null;
    _phase = AgentPhase.error;
    for (final session in _sessions) {
      session.addErrorMessage('$friendly\n\n$error');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    for (final session in _sessions) {
      session.removeListener(_onSessionChanged);
      session.dispose();
    }
    unawaited(_engine?.dispose());
    super.dispose();
  }
}
