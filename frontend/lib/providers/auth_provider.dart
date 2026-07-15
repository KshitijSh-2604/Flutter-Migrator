import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _api = ApiService();
  
  User? _user;
  String? _userName;
  String? _geminiKey;
  String? _openaiKey;
  bool _isLoading = false;

  User? get user => _user;
  String? get userName => _userName;
  String? get geminiKey => _geminiKey;
  String? get openaiKey => _openaiKey;
  bool get isLoading => _isLoading;
  bool get hasValidKey => (_geminiKey != null && _geminiKey!.isNotEmpty) || (_openaiKey != null && _openaiKey!.isNotEmpty);

  AuthProvider() {
    _user = _supabase.auth.currentUser;
    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      if (_user != null) {
        _loadProfile();
      } else {
        _userName = null;
        _geminiKey = null;
        _openaiKey = null;
      }
      notifyListeners();
    });
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_user == null) return;
    
    // 1. Try to get name from Auth Metadata first (most reliable for logged-in user)
    final metaName = _user!.userMetadata?['full_name'] as String?;
    
    try {
      final res = await _supabase
          .from('profiles')
          .select('full_name, gemini_key, openai_key')
          .eq('id', _user!.id)
          .maybeSingle();
      
      if (res != null) {
        _userName = res['full_name'] ?? metaName;
        _geminiKey = res['gemini_key'];
        _openaiKey = res['openai_key'];
        notifyListeners();
      } else if (metaName != null) {
        _userName = metaName;
        notifyListeners();
        _syncProfileToDb(metaName);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _syncProfileToDb(String name) async {
    try {
      await _supabase.from('profiles').upsert({
        'id': _user!.id,
        'email': _user!.email!.toLowerCase(),
        'full_name': name,
      });
    } catch (e) {
      debugPrint('Profile sync failed: $e');
    }
  }

  /// Check if an email exists and return the user's name if it does
  Future<String?> checkEmailAndGetName(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      debugPrint('Checking email: $cleanEmail');
      
      final res = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('email', cleanEmail)
          .maybeSingle();
      
      debugPrint('Lookup result: $res');
      
      // If result is null, the user doesn't exist in our profiles table.
      if (res == null) return null;
      
      // If the row exists but full_name is null/empty, return "User" so we know they exist
      final name = res['full_name'] as String?;
      if (name == null || name.trim().isEmpty) return "User";
      
      return name;
    } catch (e) {
      debugPrint('Error in checkEmailAndGetName: $e');
      return null;
    }
  }

  Future<String?> signUp(String email, String password, String name) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _supabase.auth.signUp(
        email: email, 
        password: password,
        data: {'full_name': name},
      );
      
      // Set a flag that we just signed up so we can show the AI config once
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_config_after_login', true);

      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _supabase.auth.signInWithPassword(email: email, password: password);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<bool> updateKey(String key, String provider) async {
    if (_user == null) return false;
    try {
      _isLoading = true;
      notifyListeners();
      
      final isValid = await _api.validateKey(key, provider);
      if (isValid) {
        // Save to Supabase Cloud Profile
        await _supabase.from('profiles').update({
          provider == 'gemini' ? 'gemini_key' : 'openai_key': key,
        }).eq('id', _user!.id);

        if (provider == 'gemini') _geminiKey = key; else _openaiKey = key;

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
