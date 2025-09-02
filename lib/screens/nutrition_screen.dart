import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../providers/nutrition_logic.dart';
import '../widgets/app_drawer.dart'; // + import

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});
  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodsProvider).where((f){
      if (q.isEmpty) return true;
      return (f['name'] as String).toLowerCase().contains(q.toLowerCase());
    }).toList();

    final today = DateTime.now().toIso8601String().substring(0,10);
    final logs = Hive.box('foodlogs').values.where((e)=> e['date'] == today).toList();
    final sum = logs.fold<Map<String,double>>({'kcal':0,'protein':0,'carbs':0,'fat':0}, (acc, e){
      acc['kcal'] = acc['kcal']! + (e['kcal'] as num).toDouble();
      acc['protein'] = acc['protein']! + (e['protein'] as num).toDouble();
      acc['carbs'] = acc['carbs']! + (e['carbs'] as num).toDouble();
      acc['fat'] = acc['fat']! + (e['fat'] as num).toDouble();
      return acc;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrição')),
      drawer: const AppNavDrawer(),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar alimento'),
            onChanged: (v)=> setState(()=> q=v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Hoje: ${sum['kcal']!.toStringAsFixed(0)} kcal'),
              Text('P:${sum['protein']!.toStringAsFixed(1)} C:${sum['carbs']!.toStringAsFixed(1)} G:${sum['fat']!.toStringAsFixed(1)}'),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: foods.length,
            itemBuilder: (_, i){
              final f = foods[i];
              return ListTile(
                title: Text(f['name']),
                subtitle: Text('${f['kcal']} kcal/100g'),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    final grams = await _askGrams();
                    if (grams != null) {
                      addFoodLog(food: f, grams: grams);
                      if (mounted) setState((){});
                    }
                  },
                ),
              );
            },
          ),
        )
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          // limpar logs do dia
          final box = Hive.box('foodlogs');
          final toDelete = box.keys.where((k) => box.get(k)['date'] == today).toList();
          for (final k in toDelete) { box.delete(k); }
          setState((){});
        },
        child: const Icon(Icons.delete),
      ),
    );
  }

  Future<double?> _askGrams() async {
    final c = TextEditingController(text: '100');
    final res = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quantidade (g)'),
        content: TextField(controller: c, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: ()=> Navigator.pop(context, double.tryParse(c.text)), child: const Text('OK')),
        ],
      )
    );
    return res;
  }
}
