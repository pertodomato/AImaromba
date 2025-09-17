import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo do Dia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () { /* Navegar para a tela de perfil */ },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Card do Próximo Treino
            Card(
              child: ListTile(
                leading: const Icon(Icons.fitness_center, color: Colors.blueAccent),
                title: const Text('Próximo Treino: Treino A - Peito'),
                subtitle: const Text('Amanhã, 08:00'),
                trailing: ElevatedButton(
                  onPressed: () { /* Iniciar treino */ },
                  child: const Text('Começar'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Card da Próxima Refeição
            Card(
              child: ListTile(
                leading: const Icon(Icons.restaurant, color: Colors.orangeAccent),
                title: const Text('Próxima Refeição: Almoço'),
                subtitle: const Text('Frango grelhado, arroz integral e brócolis'),
                onTap: () { /* Ver detalhes da refeição */ },
              ),
            ),
            const SizedBox(height: 16),
            // Card de Progresso Calórico
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Metas Calóricas', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    // Aqui entraria um gráfico de pizza (ex: com fl_chart)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Consumido: 1200 kcal'),
                        Text('Meta: 2500 kcal'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(value: 1200 / 2500),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMealDialog(context),
        child: const Icon(Icons.add),
        tooltip: 'Adicionar Refeição/Peso',
      ),
    );
  }

  void _showAddMealDialog(BuildContext context) {
    // Implementar popup para adicionar refeição por texto/câmera ou adicionar peso
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Adicionar Refeição por Câmera/QR'),
              onTap: () { /* Lógica da câmera */ },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Adicionar Refeição por Texto'),
              onTap: () { /* Lógica de texto */ },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.monitor_weight),
              title: const Text('Registrar Peso Corporal'),
              onTap: () { /* Lógica de peso */ },
            ),
          ],
        ),
      ),
    );
  }
}