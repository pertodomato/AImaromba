import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool mine;
  const ChatBubble({super.key, required this.text, required this.mine});

  @override
  Widget build(BuildContext context) {
    final bg = mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceVariant;
    final tx = mine ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      constraints: const BoxConstraints(maxWidth: 700),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: tx)),
    );
  }
}
