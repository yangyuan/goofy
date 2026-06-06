import 'package:flutter/material.dart';

import '../agent/chat_message.dart';
import '../theme/app_theme.dart';
import 'typing_indicator.dart';

/// A WeChat-style bubble with a tail. Springs in the first time it appears.
class MessageBubble extends StatefulWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.isUser;
    final intro = CurvedAnimation(parent: _intro, curve: Curves.easeOutBack);

    final bubbleColor = message.isError
        ? const Color(0xFFFDECEC)
        : isUser
            ? AppColors.bubbleOut
            : AppColors.bubbleIn;
    final textColor = message.isError ? AppColors.error : AppColors.textPrimary;

    final content = message.isPending
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: TypingIndicator(),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 220,
                      maxHeight: 220,
                    ),
                    child: Image.memory(
                      message.imageBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 120,
                        height: 120,
                        color: Colors.black12,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
                if (message.text.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.imageBytes == null || message.text.isNotEmpty)
                Text(
                  message.text,
                  style: TextStyle(
                    height: 1.38,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
            ],
          );

    final bubble = CustomPaint(
      painter: _TailPainter(color: bubbleColor, isUser: isUser),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        child: content,
      ),
    );

    final row = Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isUser) ...[const _Avatar(isUser: false), const SizedBox(width: 8)],
        Flexible(child: bubble),
        if (isUser) ...[const SizedBox(width: 8), const _Avatar(isUser: true)],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: FadeTransition(
        opacity: _intro,
        child: ScaleTransition(
          scale: intro,
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: row,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.isUser});

  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: isUser
            ? const LinearGradient(
                colors: [Color(0xFFBFC4CC), Color(0xFF9AA1AB)],
              )
            : const LinearGradient(
                colors: [Color(0xFF22D87A), AppColors.brand],
              ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isUser ? Icons.person : Icons.bolt_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

/// Paints the rounded bubble plus a small triangle tail toward the avatar.
class _TailPainter extends CustomPainter {
  _TailPainter({required this.color, required this.isUser});

  final Color color;
  final bool isUser;

  static const _radius = 10.0;
  static const _tail = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    canvas.drawRRect(rect, paint);

    final path = Path();
    const tailTop = 14.0;
    if (isUser) {
      path
        ..moveTo(size.width, tailTop)
        ..lineTo(size.width + _tail, tailTop + 4)
        ..lineTo(size.width, tailTop + 9);
    } else {
      path
        ..moveTo(0, tailTop)
        ..lineTo(-_tail, tailTop + 4)
        ..lineTo(0, tailTop + 9);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isUser != isUser;
}
