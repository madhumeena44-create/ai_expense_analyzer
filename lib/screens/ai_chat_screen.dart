import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
//import 'profile_screen.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final ChatService _chatService = ChatService();
  final List _messages = [];
  List _chatSessions = [];
  String? _currentSessionId;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _pendingImagePath;


  final ImagePicker _picker = ImagePicker();
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
  try {
    final history = await _chatService.initChatSession();
    final prefs = await SharedPreferences.getInstance();
    final savedSessionsJson = prefs.getString('ai_saved_sessions_list');

    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(history.map((m) => Map<String, dynamic>.from(m)));

        if (savedSessionsJson != null && savedSessionsJson.isNotEmpty) {
          final List decoded = jsonDecode(savedSessionsJson);
          _chatSessions = decoded.map((s) => Map<String, dynamic>.from(s as Map)).toList();
          
        }
      });
      _scrollToBottom();
    }
  } catch (e) {
    debugPrint('Init history error: $e');
  }
}

Future<void> _clearChat() async {
    await _chatService.clearHistory();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_saved_sessions_list');
    if (mounted) {
      setState(() {
        _messages.clear();
        _chatSessions.clear();
      });
    }
  }
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _listenVoice() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() {
            _textController.text = val.recognizedWords;
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _pickMedia(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source);
    if (file != null) {
      setState(() {
        _pendingImagePath = file.path;
        _messages.add({
          'role': 'user',
          'image': file.path,
          'text': 'Receipt image uploaded',
        });
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if ((text.isEmpty && _pendingImagePath == null) || _isLoading) return;

    _textController.clear();
    setState(() {
      _messages.add({
  'role': 'user',
  'text': text,
  'image': _pendingImagePath,
});
_messages.add({'role': 'model', 'text': ''});
_isLoading = true;

    });
    _scrollToBottom();

    // Create unique session ID if this is a new conversation
    _currentSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

    final String sessionTitle = text.isNotEmpty
        ? (text.length > 22 ? '${text.substring(0, 22)}...' : text)
        : 'Receipt Analysis';

    final int existingIndex = _chatSessions.indexWhere((s) => s['id'] == _currentSessionId);
    
    // IMPORTANT: Use List.from(_messages.map((m) => Map.from(m))) to create a deep independent copy!
    final clonedMessages = List.from(_messages.map((m) => Map.from(m)));

    if (existingIndex == -1) {
      _chatSessions.insert(0, {
        'id': _currentSessionId,
        'title': sessionTitle,
        'messages': clonedMessages,
      });
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_saved_sessions_list', jsonEncode(_chatSessions)); 

    try {
      final imageToSend = _pendingImagePath;
      _pendingImagePath = null;
      final stream = _chatService.sendMessageStream(
        text.isEmpty ? 'Analyze this receipt and extract expense details.' : text,
        imagePath: imageToSend,
      );
      await for (final chunk in stream) {
        setState(() {
          final lastIdx = _messages.length - 1;
          _messages[lastIdx]['text'] = (_messages[lastIdx]['text'] ?? '') + chunk;
        });
        _scrollToBottom();
      }

      try {
      final safeHistory = _messages.map((m) => {
        'role': m['role']?.toString() ?? '',
        'text': m['text']?.toString() ?? '',
        'image': m['image']?.toString() ?? '',
      }).toList();
      await _chatService.saveHistory(safeHistory);
    } catch (e) {
      debugPrint('History save error: $e');
    }

    final sIdx = _chatSessions.indexWhere((s) => s['id'] == _currentSessionId);
    if (sIdx != -1) {
      _chatSessions[sIdx]['messages'] = List.from(_messages.map((m) => Map.from(m)));
    }
  } catch (e) {
      setState(() {
        final lastIdx = _messages.length - 1;
        _messages[lastIdx]['text'] = 'Error: $e';
      });
      final sIdx = _chatSessions.indexWhere((s) => s['id'] == _currentSessionId);
      if (sIdx != -1) {
        _chatSessions[sIdx]['messages'] = List.from(_messages.map((m) => Map.from(m)));
      }
  }
    
     finally {
      setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF121212),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Financial Advisor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.white),
                title: const Text('New chat', style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    _messages.clear();
                    _pendingImagePath = null;
                    _currentSessionId = null;
                  });
                  Navigator.of(context).pop();
                },
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Recent Analysis',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                if (_chatSessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'No previous chats yet',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  )
                else
                  ..._chatSessions.map((session) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 18),
                      title: Text(
                        session['title'] ?? 'Chat',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                  setState(() {
                    _currentSessionId = session['id'];
                    _messages.clear();
                    if (session['messages'] != null) {
                      _messages.addAll((session['messages'] as List).map((m) => Map<String, dynamic>.from(m as Map)).toList(),
                      );
                    }
                  });
                  Navigator.of(context).pop();
                },
                    );
                  }),
              ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Builder(
                builder: (context) {
                  final user = FirebaseAuth.instance.currentUser;
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: InkWell(
                onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF1E222A),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Account Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: Colors.white70),
                    title: Text(
                      user?.email ?? 'No email',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF006D5B),
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? const Icon(Icons.person, size: 18, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user?.displayName ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
                onPressed: () {
                  Navigator.of(context).pop();
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF1E222A),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Account Settings',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(Icons.email_outlined, color: Colors.white70),
                            title: Text(
                              FirebaseAuth.instance.currentUser?.email ?? 'madhumeena44@gmail.com',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.logout, color: Colors.redAccent),
                            title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                            onTap: () async {
                              await FirebaseAuth.instance.signOut();
                              if (context.mounted) {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
                  ],
                ),
              ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Financial Advisor AI'),
        backgroundColor: const Color(0xFF006D5B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF006D5B) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (msg['image'] != null &&
                      msg['image'].toString().trim().isNotEmpty &&
                      File(msg['image'].toString()).existsSync()) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(msg['image'].toString()),
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                    
                  if (msg['text'] != null && (msg['text'] as String).isNotEmpty)
                    Text(
                      msg['text'] as String,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                ],
              ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.only(left: 16, right: 76, top: 8,bottom: 8),
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_pendingImagePath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_pendingImagePath!),
                        height: 70,
                        width: 70,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _pendingImagePath = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Ask or scan receipts...',
                      hintStyle: const TextStyle(color: Colors.black54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      prefixIcon: IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : const Color(0xFF006D5B),
                        ),
                        onPressed: _listenVoice,
                      ),
                      suffixIcon: SizedBox(
                        width: 72,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () => _pickMedia(ImageSource.camera),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  color: Color(0xFF006D5B),
                                  size: 22,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _pickMedia(ImageSource.gallery),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  Icons.photo_library_outlined,
                                  color: Color(0xFF006D5B),
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ], // closes Row children
            ),   // closes Row
          ],     // closes Column children
        ),       // closes Column
      ),         // closes Container
    ],
            ), // closes Scaffold body Column
          );   // closes Scaffold
        }      // closes build()
      }        // closes _AiChatScreenState