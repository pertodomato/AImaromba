// lib/external/ai/get_response.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/message.dart';
import 'ai_provider.dart';
import 'openai_provider.dart';

// Provider para o provedor de IA, fácil de trocar
final aiProvider = Provider<AiProvider>((ref) => OpenAIProvider());

// Fachada unificada
class AiService {
  final AiProvider _provider;
  AiService(this._provider);

  Future<Map<String, dynamic>> getResponse({
    required String promptFile,
    required String promptKey,
    required Map<String, String> placeholders,
  }) async {
    try {
      // 1. Carregar o template do prompt do arquivo JSON
      final jsonString = await rootBundle.loadString('assets/prompts/$promptFile');
      final prompts = jsonDecode(jsonString) as Map<String, dynamic>;
      final promptConfig = prompts[promptKey] as Map<String, dynamic>;
      
      if (promptConfig == null) {
        throw AiFailure('Chave de prompt "$promptKey" não encontrada em "$promptFile"');
      }

      // 2. Montar a conversa
      final systemPrompt = promptConfig['system_prompt'] as String;
      var userPrompt = promptConfig['user_prompt_template'] as String;

      // 3. Substituir placeholders
      placeholders.forEach((key, value) {
        userPrompt = userPrompt.replaceAll('\${$key}', value);
      });

      final conversation = [
        Message(role: MessageRole.system, content: systemPrompt),
        Message(role: MessageRole.user, content: userPrompt),
      ];

      // 4. Chamar o provedor
      final responseString = await _provider.getResponse(conversation);

      // 5. Validar e retornar JSON
      try {
        final jsonResponse = jsonDecode(responseString) as Map<String, dynamic>;
        return jsonResponse;
      } catch (e) {
        throw AiFailure('A resposta da IA não é um JSON válido: $e \n\nResposta recebida:\n$responseString');
      }
    } catch (e) {
      // Re-lança a falha para a camada de cima tratar (ex: use case ou provider)
      rethrow;
    }
  }
}

// Provider para o serviço (fachada)
final aiServiceProvider = Provider<AiService>((ref) {
  final provider = ref.watch(aiProvider);
  return AiService(provider);
});