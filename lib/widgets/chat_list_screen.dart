import 'package:flutter/material.dart';

import '../agent/agent.dart';
import '../theme/app_theme.dart';
import 'chat_detail_screen.dart';

/// The Chats tab: a WeChat-style conversation list. Each chat is an independent
/// local Gemma conversation; the `+` button starts a new one.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key, required this.hub});

  final Agent hub;

  void _openChat(BuildContext context, ChatSession session) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) =>
            ChatDetailScreen(hub: hub, controller: session),
        transitionsBuilder: (_, animation, _, child) {
          final slide = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return SlideTransition(position: slide, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.bar,
        surfaceTintColor: AppColors.bar,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          'Chats',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: () => _openChat(context, hub.newChat()),
            icon: const Icon(Icons.add_circle_outline,
                color: AppColors.textPrimary),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: hub,
        builder: (context, _) {
          final sessions = [...hub.sessions]
            ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              const _SearchBar(),
              for (final session in sessions)
                Dismissible(
                  key: ValueKey(session),
                  direction: DismissDirection.endToStart,
                  background: const _DeleteBackground(),
                  onDismissed: (_) => hub.deleteChat(session),
                  child: _ConversationTile(
                    hub: hub,
                    session: session,
                    onTap: () => _openChat(context, session),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bar,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 18, color: AppColors.textSecondary),
            SizedBox(width: 6),
            Text(
              'Search',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// The red panel revealed when swiping a chat left to delete it.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, color: Colors.white, size: 24),
          SizedBox(width: 6),
          Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.hub,
    required this.session,
    required this.onTap,
  });

  final Agent hub;
  final ChatSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The engine is shared, so "busy" (downloading/loading) is a hub-level
    // state shown on every chat until a conversation is bound.
    final busy = hub.isBusy && !session.isReady;
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.canvas,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _GoofyAvatar(size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _relativeTime(session.lastActivity),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (busy) ...[
                          const SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: AppColors.brand,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            busy ? hub.statusLabel : session.previewText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final delta = DateTime.now().difference(time);
  if (delta.inMinutes < 1) return 'now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m';
  if (delta.inHours < 24) return '${delta.inHours}h';
  return '${delta.inDays}d';
}

/// Goofy's avatar: a rounded-square WeChat-style tile with a friendly mark.
class _GoofyAvatar extends StatelessWidget {
  const _GoofyAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF22D87A), AppColors.brand],
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.bolt_rounded,
        color: Colors.white,
        size: size * 0.56,
      ),
    );
  }
}
