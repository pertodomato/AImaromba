# FitApp (Flutter) – Offline-first + IA (gpt-4o-mini)

## Como rodar
1) Instale Flutter e Android Studio (ou use `flutter config --enable-web` para rodar no navegador).
2) Crie o projeto:  
   ```bash
   flutter create fitapp
   ```
3) Substitua o conteúdo do projeto pelos arquivos deste ZIP (pubspec.yaml, pasta lib/, assets/).
4) Rode:
   ```bash
   flutter pub get
   flutter run
   ```

## Teste rápido (roteiro)
- **Primeira execução**: preencha o Onboarding.
- **Dashboard**: veja Treino de hoje (descanso no início) e calorias do dia.
- **Construtor**: toque no ícone ✨ para gerar um plano via IA (configure sua **OpenAI API key** em Perfil).
- **Planejador**: atribua blocos aos dias. Volte ao Dashboard e inicie o treino.
- **Sessão de Treino**: preencha peso/reps, finalize → será salvo em Histórico, atualiza XP, calorias e melhores marcas (1RM/reps).
- **Mapa Muscular & Percentis**: após registrar marcas, veja seus percentis estimados.
- **Nutrição**: lance alimentos (100g por padrão), observe totais.
- **Perfil & Backup**: edite dados, defina **OpenAI API key**, exporte/import ZIP.
- **Configurações**: tema escuro, refazer onboarding, limpar dados.

## Notas
- Hive usa `Map` simples para facilitar (sem adapters).
- Benchmarks/Exercícios/TACO são **mínimos** (funcionais). Amplie quando quiser.
- A IA é **opcional** – o app roda offline sem ela.
