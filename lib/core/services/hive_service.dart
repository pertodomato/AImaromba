import 'package:hive_flutter/hive_flutter.dart';
import 'package:seu_app/core/models/models.dart'; // Importe o arquivo que exporta todos os modelos

class HiveService {
  Future<void> init() async {
    await Hive.initFlutter();
    // Registrar todos os adaptadores
    Hive.registerAdapter(UserProfileAdapter());
    Hive.registerAdapter(ExerciseAdapter());
    // ... registre os outros adaptadores aqui

    // Abrir todas as boxes
    await Hive.openBox<UserProfile>('user_profile');
    await Hive.openBox<Exercise>('exercises');
    // ... abra as outras boxes aqui
  }

  Box<T> getBox<T>(String boxName) {
    return Hive.box<T>(boxName);
  }
  
  // Exemplo de função de acesso
  UserProfile getUserProfile() {
    final box = getBox<UserProfile>('user_profile');
    // Se não houver perfil, cria um vazio.
    if (box.isEmpty) {
      box.add(UserProfile());
    }
    return box.getAt(0)!;
  }

  void saveUserProfile(UserProfile profile) {
    final box = getBox<UserProfile>('user_profile');
    box.putAt(0, profile);
  }
}