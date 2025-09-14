// lib/external/ai/ai_provider.dart
import '../../domain/entities/message.dart';

// Contrato para provedores de IA
abstract interface class AiProvider {
  Future<String> getResponse(List<Message> conversation);
}