// lib/domain/entities/message.dart
enum MessageRole { system, user, assistant }

class Message {
  final MessageRole role;
  final String content;

  Message({required this.role, required this.content});

  Map<String, String> toMap() => {
        'role': role.name,
        'content': content,
      };
}