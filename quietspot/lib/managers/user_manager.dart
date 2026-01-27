import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserManager {
  static final UserManager _instance = UserManager._internal();
  static UserManager get instance => _instance;

  UserManager._internal();

  Map<String, dynamic>? _currentUser;
  static const String _userKey = 'auth_user_data';

  bool get isLoggedIn => _currentUser != null;

  int? get userId => _currentUser?['id'];
  String? get name => _currentUser?['name'];
  String? get email => _currentUser?['email'];

  Future<void> login(Map<String, dynamic> userData) async {
    _currentUser = userData;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userData));
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  void update(Map<String, dynamic> userData) {
    _currentUser = {...?_currentUser, ...userData};
    // Update persistence
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_userKey, jsonEncode(_currentUser));
    });
  }

  Future<bool> tryAutoLogin() async {
    if (_currentUser != null) return true;
    
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userKey);
    
    if (jsonStr != null) {
      try {
        _currentUser = jsonDecode(jsonStr);
        return true;
      } catch (e) {
        // Corrupt data
        await prefs.remove(_userKey);
      }
    }
    return false;
  }
}
