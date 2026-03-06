import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static final _db = FirebaseDatabase.instance;
  static const _userId = 'user_001';

  static Future<void> saveChat(String role, String message) async {
    await _db.ref('users/$_userId/chats').push().set({
      'role': role,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> saveMood(String mood) async {
    final today = _today();
    await _db.ref('users/$_userId/moods/$today').set({
      'mood': mood,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> saveSleep(double hours) async {
    await _db.ref('users/$_userId/sleep/${_today()}').set({
      'hours': hours,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> saveScreenTime(Map<String, double> appHours) async {
    final total = appHours.values.fold(0.0, (a, b) => a + b);
    await _db.ref('users/$_userId/screentime/${_today()}').set({
      'apps': appHours,
      'total': total,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }
}