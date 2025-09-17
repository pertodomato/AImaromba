import 'package:flutter/foundation.dart';
import 'package:seu_app/core/models/user_profile.dart';
import 'package:seu_app/core/services/hive_service.dart';

class UserProfileProvider with ChangeNotifier {
  final HiveService _hiveService;
  late UserProfile _userProfile;

  UserProfileProvider(this._hiveService) {
    _loadUserProfile();
  }

  UserProfile get userProfile => _userProfile;

  void _loadUserProfile() {
    _userProfile = _hiveService.getUserProfile();
    notifyListeners();
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    _userProfile = profile;
    _hiveService.saveUserProfile(_userProfile);
    notifyListeners();
  }
}