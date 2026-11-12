import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  // Ultra-fast latency-sensitive model with no thinking delay
  static const String _modelName = 'gemini-3.5-flash-lite';
  static const String _storageKey = 'ai_chat_history_v10';
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  late final GenerativeModel _model;
  ChatSession? _chatSession;

  ChatService() {
    _model = GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        maxOutputTokens: 150, // Short, snappy responses
        temperature: 0.2,     // Fastest greedy token sampling
      ),
      systemInstruction: Content.system(
        'You are an expert AI Financial Advisor and Expense Assistant. '
        'Provide ultra-fast, direct, and concise financial advice in 1 to 2 brief sentences.',
      ),
    );
  }

  /// Load persistent chat history safely
  Future<List> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey);
      if (rawList == null || rawList.isEmpty) return [];

      final List results = [];
      for (final item in rawList) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map) {
            results.add({
              'role': decoded['role']?.toString() ?? 'user',
              'text': decoded['text']?.toString() ?? '',
              'image': decoded['image']?.toString() ?? '',
            });
          }
        } catch (_) {}
      }
      return results;
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      return [];
    }
  }

  /// Initialize Gemini multi-turn session with only the last 2 turns
  Future<List> initChatSession() async {
    final history = await loadHistory();

    // Only send the last 2 messages to minimize network prefill time
    final recentHistory = history.length > 2 
        ? history.sublist(history.length - 2) 
        : history;

    final List<Content> sessionHistory = [];
    for (final msg in recentHistory) {
      if (msg is Map) {
        final role = (msg['role'] ?? 'user').toString();
        final text = (msg['text'] ?? '').toString();
        if (text.trim().isNotEmpty) {
          if (role == 'user') {
            sessionHistory.add(Content.text(text));
          } else {
            sessionHistory.add(Content.model([TextPart(text)]));
          }
        }
      }
    }

    _chatSession = _model.startChat(history: sessionHistory);
    return history;
  }

  /// Stream tokens chunk-by-chunk
  Stream<String> sendMessageStream(String prompt, {String? imagePath}) async* {
    if (_apiKey.trim().isEmpty) {
      yield 'Error: Gemini API key is not configured. Provide GEMINI_API_KEY with --dart-define.';
      return;
    }

    if (_chatSession == null) {
      await initChatSession();
    }

    try {
      final Content content;
      if (imagePath != null && imagePath.trim().isNotEmpty) {
        final file = File(imagePath.trim());
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          content = Content.multi([
            TextPart(prompt.isEmpty ? 'Analyze this receipt and extract expense details.' : prompt),
            DataPart('image/jpeg', bytes),
          ]);
        } else {
          content = Content.text(prompt);
        }
      } else {
        content = Content.text(prompt);
      }

      final responseStream = _chatSession!.sendMessageStream(content);

      await for (final chunk in responseStream) {
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      debugPrint('Gemini Stream Error: $e');
      yield 'Error: $e';
    }
  }

  /// Save current conversation state
  Future<void> saveHistory(List messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> encoded = messages.map((m) {
        if (m is Map) {
          return jsonEncode({
            'role': m['role']?.toString() ?? 'user',
            'text': m['text']?.toString() ?? '',
            'image': m['image']?.toString() ?? '',
          });
        }
        return jsonEncode({'role': 'user', 'text': '', 'image': ''});
      }).toList();
      await prefs.setStringList(_storageKey, encoded);
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  /// Clear all saved history
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      _chatSession = _model.startChat();
    } catch (e) {
      debugPrint('Error clearing history: $e');
    }
  }
}