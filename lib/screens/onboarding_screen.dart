import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import '../widgets/app_drawer.dart'; // + import

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  String gender = 'M'; int age = 25; double weight = 75; double height = 175; int kcal = 2200;

  void _save() {
    if(!_form.currentState!.validate()) return;
    _form.currentState!.save();
    final p = Hive.box('profile');
    p.putAll({
      'gender': gender,
      'age': age,
      'weight': weight,
      'height': height,
      'calorieTarget': kcal,
      'unitWeight': 'kg',
      'unitDistance': 'km'
    });
    Hive.box('settings').put('firstRun', false);
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding')),
      drawer: const AppNavDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: gender,
                items: const [DropdownMenuItem(value: 'M', child: Text('Masculino')), DropdownMenuItem(value: 'F', child: Text('Feminino'))],
                onChanged: (v)=> setState(()=> gender = v!),
                decoration: const InputDecoration(labelText: 'Sexo'),
              ),
              TextFormField(initialValue: '$age', decoration: const InputDecoration(labelText: 'Idade'), keyboardType: TextInputType.number, onSaved: (v)=> age = int.tryParse(v??'$age')??age),
              TextFormField(initialValue: '$weight', decoration: const InputDecoration(labelText: 'Peso (kg)'), keyboardType: TextInputType.number, onSaved: (v)=> weight = double.tryParse(v??'$weight')??weight),
              TextFormField(initialValue: '$height', decoration: const InputDecoration(labelText: 'Altura (cm)'), keyboardType: TextInputType.number, onSaved: (v)=> height = double.tryParse(v??'$height')??height),
              TextFormField(initialValue: '$kcal', decoration: const InputDecoration(labelText: 'Meta calórica (kcal/dia)'), keyboardType: TextInputType.number, onSaved: (v)=> kcal = int.tryParse(v??'$kcal')??kcal),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _save, child: const Text('Começar'))
            ],
          ),
        ),
      ),
    );
  }
}
