import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The bottom input bar: attach, multiline field, and a send button that
/// springs into view as soon as there is something to send.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.isResponding,
    required this.attachedImagePath,
    required this.hasText,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isResponding;
  final String? attachedImagePath;
  final bool hasText;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final attachedImagePath = this.attachedImagePath;
    final canSend = enabled && (hasText || attachedImagePath != null);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bar,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        10,
        8,
        10,
        8 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachedImagePath != null)
            _AttachmentPreview(
              path: attachedImagePath,
              onRemove: enabled ? onRemoveImage : null,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _CircleIcon(
                icon: Icons.add_photo_alternate_outlined,
                onTap: enabled ? onPickImage : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: canSend ? (_) => onSend() : null,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: InputBorder.none,
                      hintText: isResponding
                          ? 'Goofy is replying\u2026'
                          : 'Message',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(enabled: canSend, onSend: onSend),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onSend});

  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: enabled ? 1 : 0.6,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 160),
        child: GestureDetector(
          onTap: enabled ? onSend : null,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: enabled ? AppColors.brand : AppColors.tabIdle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_upward_rounded,
                color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: onTap == null ? AppColors.tabIdle : AppColors.brand,
          size: 24,
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.path, required this.onRemove});

  final String path;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 48, bottom: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(path),
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 72,
                  height: 72,
                  color: Colors.black12,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
            Positioned(
              top: -7,
              right: -7,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.close, size: 15, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
