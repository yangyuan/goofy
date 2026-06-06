import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../agent/agent.dart';
import '../theme/app_theme.dart';
import 'chat_composer.dart';
import 'message_bubble.dart';

/// The live chat with local Gemma: bubbles, streaming, attachments, and the
/// first-run download flow.
class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.hub,
    required this.controller,
  });

  final Agent hub;
  final ChatSession controller;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;
  bool _hasText = false;

  Agent get _hub => widget.hub;
  ChatSession get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _lastCount = _controller.messages.length;
    _input.addListener(_onInputChanged);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _controller.removeListener(_onControllerChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final hasText = _input.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _onControllerChanged() {
    if (_controller.messages.length != _lastCount) {
      _lastCount = _controller.messages.length;
      _scrollToBottom();
    } else {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pickImage() async {
    const typeGroup = XTypeGroup(
      label: 'Images',
      extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
    );
    try {
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      _controller.attachImage(file.path);
    } catch (error) {
      _controller.addErrorMessage('Could not attach the image.\n\n$error');
    }
  }

  void _send() {
    final text = _input.text;
    _input.clear();
    _controller.send(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.bar,
        surfaceTintColor: AppColors.bar,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: AnimatedBuilder(
          animation: Listenable.merge([_hub, _controller]),
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _controller.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _controller.isReady
                    ? _controller.statusLabel
                    : _hub.statusLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<AgentBackend>(
            enabled: !_hub.isBusy,
            tooltip: 'Backend',
            icon: const Icon(Icons.more_horiz, color: AppColors.textPrimary),
            onSelected: _hub.selectBackend,
            itemBuilder: (context) => AgentBackend.values
                .map(
                  (backend) => PopupMenuItem<AgentBackend>(
                    value: backend,
                    child: Row(
                      children: [
                        Icon(
                          backend == _hub.selectedBackend
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: AppColors.brand,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text('${backend.label} backend'),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_hub, _controller]),
        builder: (context, _) {
          return Column(
            children: [
              if (_hub.phase == AgentPhase.needsDownload ||
                  _hub.phase == AgentPhase.downloading ||
                  _hub.phase == AgentPhase.loading ||
                  _hub.phase == AgentPhase.error)
                _DownloadBanner(hub: _hub),
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: _controller.messages.length,
                    itemBuilder: (context, index) => MessageBubble(
                      key: ValueKey(_controller.messages[index].id),
                      message: _controller.messages[index],
                    ),
                  ),
                ),
              ),
              ChatComposer(
                controller: _input,
                enabled: _controller.canCompose && !_hub.isBusy,
                isResponding: _controller.isResponding,
                attachedImagePath: _controller.attachedImagePath,
                hasText: _hasText,
                onPickImage: _pickImage,
                onRemoveImage: _controller.removeAttachedImage,
                onSend: _send,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DownloadBanner extends StatelessWidget {
  const _DownloadBanner({required this.hub});

  final Agent hub;

  @override
  Widget build(BuildContext context) {
    final downloading = hub.phase == AgentPhase.downloading;
    final loading = hub.phase == AgentPhase.loading;
    final failed = hub.phase == AgentPhase.error;
    final fraction = hub.downloadProgress?.fraction;
    final locked = downloading || loading;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.download_for_offline_outlined,
            color: AppColors.brand,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locked
                      ? hub.statusLabel
                      : failed
                      ? 'Try another backend'
                      : 'Get Gemma E2B',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  failed
                      ? 'Switch CPU/GPU, then load the local model again.'
                      : 'A one-time download, then everything stays on device.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<AgentBackend>(
                  segments: AgentBackend.values
                      .map(
                        (backend) => ButtonSegment<AgentBackend>(
                          value: backend,
                          label: Text(backend.label),
                        ),
                      )
                      .toList(),
                  selected: {hub.selectedBackend},
                  onSelectionChanged: locked
                      ? null
                      : (selected) =>
                            unawaited(hub.selectBackend(selected.single)),
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.brand,
                    selectedForegroundColor: Colors.white,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.divider),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (downloading || loading) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: downloading ? fraction : null,
                      minHeight: 5,
                      backgroundColor: AppColors.canvas,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!locked) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: failed ? hub.loadModel : hub.downloadModel,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(failed ? 'Load' : 'Download'),
            ),
          ],
        ],
      ),
    );
  }
}
