import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrackingService {
  static final _db = FirebaseDatabase.instance;
  static const _userId = 'user_001';

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  // ── SCREEN UNLOCKS ──────────────────────────────────────
  static Future<void> incrementUnlockCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final key = 'unlocks_$today';
    final count = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, count);
    await _db.ref('users/$_userId/tracking/$today/unlocks').set(count);
  }

  static Future<int> getTodayUnlocks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('unlocks_${_today()}') ?? 0;
  }

  // ── SCREEN TIME ─────────────────────────────────────────
  static Future<void> saveScreenTime(double hours) async {
    final today = _today();
    await _db.ref('users/$_userId/tracking/$today/screentime').set(hours);
  }

  // ── SLEEP ────────────────────────────────────────────────
  static Future<void> saveSleepHours(double hours) async {
    final today = _today();
    await _db.ref('users/$_userId/tracking/$today/sleep').set(hours);
  }

  // ── MOOD ─────────────────────────────────────────────────
  static Future<void> saveMood(String mood) async {
    final today = _today();
    await _db.ref('users/$_userId/tracking/$today/mood').set(mood);
  }

  // ── EMOJI USAGE ──────────────────────────────────────────
  static Future<void> saveEmojiUsage(Map<String, int> emojiCounts) async {
    final today = _today();
    await _db.ref('users/$_userId/tracking/$today/emojis').set(emojiCounts);
  }

  // ── TYPING SPEED ─────────────────────────────────────────
  static Future<void> saveTypingSpeed(double wpm) async {
    final today = _today();
    await _db.ref('users/$_userId/tracking/$today/typingSpeed').set(wpm);
  }

  // ── VOICE SENTIMENT ──────────────────────────────────────
  static Future<void> saveVoiceSentiment(String sentiment, double confidence) async {
    final today = _today();
    await _db.ref('users/$_userId/tracking/$today/voiceSentiment').set({
      'sentiment': sentiment,
      'confidence': confidence,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ── GET 14-DAY DATA ──────────────────────────────────────
  static Future<Map<String, dynamic>> get14DayData() async {
    final snap = await _db.ref('users/$_userId/tracking').get();
    if (snap.exists) {
      final all = Map<String, dynamic>.from(snap.value as Map);
      // Sort by date, take last 14 days
      final sorted = all.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final last14 = sorted.length > 14
          ? sorted.sublist(sorted.length - 14)
          : sorted;
      return Map.fromEntries(last14);
    }
    return {};
  }

  // ── COMPUTE BASELINE (avg of 14 days) ───────────────────
  static Future<Map<String, double>> computeBaseline() async {
    final data = await get14DayData();
    if (data.isEmpty) return {};

    double totalSleep = 0, totalScreen = 0, totalUnlocks = 0;
    int count = 0;

    for (final entry in data.entries) {
      final day = Map<String, dynamic>.from(entry.value as Map);
      totalSleep   += (day['sleep']      as num?)?.toDouble() ?? 0;
      totalScreen  += (day['screentime'] as num?)?.toDouble() ?? 0;
      totalUnlocks += (day['unlocks']    as num?)?.toDouble() ?? 0;
      count++;
    }

    if (count == 0) return {};
    return {
      'avgSleep':    totalSleep   / count,
      'avgScreen':   totalScreen  / count,
      'avgUnlocks':  totalUnlocks / count,
    };
  }

  // ── ANALYZE RISK ─────────────────────────────────────────
  static Future<List<String>> analyzeRisk() async {
    final baseline = await computeBaseline();
    if (baseline.isEmpty) return [];

    final today = _today();
    final snap = await _db.ref('users/$_userId/tracking/$today').get();
    if (!snap.exists) return [];

    final todayData = Map<String, dynamic>.from(snap.value as Map);
    final List<String> warnings = [];

    final todaySleep   = (todayData['sleep']      as num?)?.toDouble() ?? 0;
    final todayScreen  = (todayData['screentime'] as num?)?.toDouble() ?? 0;
    final todayUnlocks = (todayData['unlocks']    as num?)?.toDouble() ?? 0;

    final avgSleep   = baseline['avgSleep']   ?? 0;
    final avgScreen  = baseline['avgScreen']  ?? 0;
    final avgUnlocks = baseline['avgUnlocks'] ?? 0;

    // Sleep dropped more than 1.5 hours below average
    if (avgSleep > 0 && todaySleep < avgSleep - 1.5) {
      warnings.add('😴 Your sleep is ${(avgSleep - todaySleep).toStringAsFixed(1)} hours below your usual. Rest matters for your mental health!');
    }

    // Screen time increased more than 2 hours above average
    if (avgScreen > 0 && todayScreen > avgScreen + 2) {
      warnings.add('📱 Screen time is higher than usual. Taking breaks helps your mind stay fresh!');
    }

    // Unlock count increased by 30% above average
    if (avgUnlocks > 0 && todayUnlocks > avgUnlocks * 1.3) {
      warnings.add('🔓 You\'ve been checking your phone more than usual. A little mindful break could help!');
    }

    return warnings;
  }
}