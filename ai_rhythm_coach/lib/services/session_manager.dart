import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';

class SessionManager {
  static const String _sessionsKey = 'sessions';
  static const int _maxSessions = 10;

  final SharedPreferences _prefs;

  SessionManager(this._prefs);

  // Save new session
  Future<void> saveSession(Session session) async {
    // Load existing sessions
    final sessions = await getSessions();

    // Add new session at front
    sessions.insert(0, session);

    // Trim to max sessions
    if (sessions.length > _maxSessions) {
      final removed = sessions.removeLast();
      await _deleteAudioFile(removed.audioFilePath);
    }

    // Save to SharedPreferences
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await _prefs.setString(_sessionsKey, jsonEncode(jsonList));
  }

  // Get all sessions (most recent first)
  Future<List<Session>> getSessions() async {
    final jsonString = _prefs.getString(_sessionsKey);
    if (jsonString == null) return [];

    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => Session.fromJson(json)).toList();
  }

  // Get session by ID
  Future<Session?> getSession(String id) async {
    final sessions = await getSessions();
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  // Delete audio file
  Future<void> _deleteAudioFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Silently fail if file doesn't exist or can't be deleted
    }
  }

  // Clear all sessions (for testing/debugging)
  Future<void> clearAllSessions() async {
    final sessions = await getSessions();
    for (final session in sessions) {
      await _deleteAudioFile(session.audioFilePath);
    }
    await _prefs.remove(_sessionsKey);
  }
}
