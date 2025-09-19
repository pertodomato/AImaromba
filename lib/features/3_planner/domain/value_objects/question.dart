// lib/features/3_planner/domain/value_objects/question.dart
class Question {
  final String key;
  final String text;
  final String? domain; // "workout" | "diet" | "both"
  const Question({required this.key, required this.text, this.domain});

  factory Question.fromMap(Map<String, dynamic> m) =>
      Question(key: m['id']?.toString() ?? m['key']?.toString() ?? '',
               text: m['text']?.toString() ?? '',
               domain: m['domain']?.toString());

  Map<String, dynamic> toMap() => {'id': key, 'text': text, 'domain': domain};
}
