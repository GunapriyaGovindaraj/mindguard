import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'voice_chat_screen.dart';
import 'firebase_service.dart';

class ALIChatScreen extends StatefulWidget {
  @override
  _ALIChatScreenState createState() => _ALIChatScreenState();
}

class _ALIChatScreenState extends State<ALIChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  int _questionIndex = 0;
  bool _assessmentDone = false;
  bool _chatStarted = false;
  Map<String, String> _assessmentAnswers = {};

  // Settings
  bool _soundEnabled = true;
  bool _autoScroll = true;
  String _responseLength = 'Medium';
  bool _showTimestamps = true;
  bool _proactiveCheckIn = true;

  // Chat sessions
  List<Map<String, dynamic>> _allSessions = [];
  String _currentSessionId = '';

  final String apiKey = 'AIzaSyC7uLxOhQ-sqxFqsZDXCwrpkaNSN2pC1o0';

  // 5 suggestion starters
  final List<Map<String, String>> _conversationStarters = [
    {'emoji': '😰', 'text': 'I\'ve been feeling really stressed lately'},
    {'emoji': '😴', 'text': 'My sleep has been really bad recently'},
    {'emoji': '📚', 'text': 'I\'m struggling with exam pressure'},
    {'emoji': '💼', 'text': 'Work is overwhelming me'},
    {'emoji': '💬', 'text': 'I just want someone to talk to'},
  ];

  final List<Map<String, dynamic>> _assessmentQuestions = [
    {
      'question': '💚 Thank you for sharing! Before we dive in, I\'d love to understand you better.\n\nHow have you been feeling overall this past week?',
      'key': 'overall_feeling',
      'options': ['😊 Really good!', '😐 It\'s been okay', '😔 Not great honestly', '😞 Quite difficult'],
    },
    {
      'question': '😴 How has your sleep been lately?',
      'key': 'sleep_quality',
      'options': ['😴 Sleeping well (7-9hrs)', '🌙 A little less than usual', '😵 Struggling to sleep', '💤 Sleeping too much'],
    },
    {
      'question': '⚡ How are your energy levels during the day?',
      'key': 'energy_level',
      'options': ['🔋 Full of energy!', '🔆 Moderate energy', '😓 Often tired', '😩 Exhausted all day'],
    },
    {
      'question': '🧠 How is your ability to focus or concentrate recently?',
      'key': 'focus_level',
      'options': ['🎯 Sharp and focused', '📖 Mostly okay', '😶 Mind keeps wandering', '🌀 Very hard to focus'],
    },
    {
      'question': '🎯 What brings you here today?',
      'key': 'purpose',
      'options': ['📚 Exam / study stress', '💼 Work pressure', '💔 Relationship issues', '🌱 Just want to feel better'],
    },
  ];

  final List<Map<String, String>> _messages = [];
  final List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _loadAllSessions();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled     = prefs.getBool('sound_enabled')     ?? true;
      _autoScroll       = prefs.getBool('auto_scroll')       ?? true;
      _responseLength   = prefs.getString('response_length') ?? 'Medium';
      _showTimestamps   = prefs.getBool('show_timestamps')   ?? true;
      _proactiveCheckIn = prefs.getBool('proactive_checkin') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled',     _soundEnabled);
    await prefs.setBool('auto_scroll',       _autoScroll);
    await prefs.setString('response_length', _responseLength);
    await prefs.setBool('show_timestamps',   _showTimestamps);
    await prefs.setBool('proactive_checkin', _proactiveCheckIn);
  }

  Future<void> _loadAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_sessions') ?? '[]';
    setState(() {
      _allSessions = List<Map<String, dynamic>>.from(jsonDecode(raw));
    });
  }

  Future<void> _saveCurrentSession() async {
    if (_messages.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final firstUser = _messages.firstWhere(
      (m) => m['role'] == 'user',
      orElse: () => {'text': 'New chat'},
    );
    final title = (firstUser['text'] ?? 'New chat').toString();
    final preview = title.length > 40 ? title.substring(0, 40) + '...' : title;
    final session = {
      'id': _currentSessionId,
      'title': preview,
      'messages': _messages,
      'timestamp': DateTime.now().toIso8601String(),
      'messageCount': _messages.length,
    };
    final idx = _allSessions.indexWhere((s) => s['id'] == _currentSessionId);
    if (idx >= 0) {
      _allSessions[idx] = session;
    } else {
      _allSessions.insert(0, session);
    }
    if (_allSessions.length > 20) _allSessions = _allSessions.sublist(0, 20);
    await prefs.setString('chat_sessions', jsonEncode(_allSessions));
    setState(() {});
  }

  void _loadSession(Map<String, dynamic> session) {
    setState(() {
      _messages.clear();
      _messages.addAll(
        List<Map<String, String>>.from(
          (session['messages'] as List).map((m) => Map<String, String>.from(m)),
        ),
      );
      _currentSessionId = session['id'];
      _assessmentDone = true;
      _chatStarted = true;
    });
    Navigator.pop(context);
    _scrollToBottom();
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _chatHistory.clear();
      _assessmentAnswers.clear();
      _questionIndex = 0;
      _assessmentDone = false;
      _chatStarted = false;
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    });
    Navigator.pop(context);
  }

  Future<void> _deleteSession(String id) async {
    setState(() => _allSessions.removeWhere((s) => s['id'] == id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_sessions', jsonEncode(_allSessions));
  }

  String _timeNow() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  void _addAliMessage(String text) {
    setState(() {
      _messages.add({'role': 'assistant', 'text': text, 'time': _timeNow()});
    });
    if (_autoScroll) _scrollToBottom();
    _saveCurrentSession();
  }

  // Called when user taps a suggestion starter
  void _onStarterTapped(String text) {
    setState(() => _chatStarted = true);
    _sendMessageText(text);
  }

  // Called when user types and sends directly
  void _onDirectSend() {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _chatStarted = true);
    _sendMessage();
  }

  void _handleOptionTap(String option) async {
    if (_assessmentDone) return;
    setState(() {
      _messages.add({'role': 'user', 'text': option, 'time': _timeNow()});
    });
    if (_autoScroll) _scrollToBottom();
    final currentQ = _assessmentQuestions[_questionIndex];
    _assessmentAnswers[currentQ['key']] = option;
    await Future.delayed(Duration(milliseconds: 600));
    _questionIndex++;
    if (_questionIndex < _assessmentQuestions.length) {
      _addAliMessage(_assessmentQuestions[_questionIndex]['question']);
    } else {
      setState(() => _assessmentDone = true);
      await _generateAssessmentSummary();
    }
  }

  Future<void> _generateAssessmentSummary() async {
    setState(() => _isLoading = true);
    final answersText = _assessmentAnswers.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    await FirebaseService.saveChat('assessment', answersText);

    final lengthInstruction = _responseLength == 'Short'
        ? 'Keep response to 2-3 sentences.'
        : _responseLength == 'Long'
            ? 'Up to 6-7 sentences.'
            : 'Keep response to 4-5 sentences.';

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': '''You are ALI, a warm mental health companion in MindGuard app.
User completed a wellness assessment:
$answersText

1. Acknowledge their feelings warmly
2. Give a gentle insight about their current mental state (no diagnosis)
3. Tell them you are here to support them
4. Ask one open-ended follow-up question
$lengthInstruction
Use gentle emojis. Be like a caring friend.'''}]}],
          'generationConfig': {'temperature': 0.85, 'maxOutputTokens': 300},
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['candidates'][0]['content']['parts'][0]['text'];
        await FirebaseService.saveChat('assistant', reply);
        _chatHistory.add({'role': 'model', 'content': reply});
        _addAliMessage(reply);
      } else {
        _fallbackSummary();
      }
    } catch (e) {
      _fallbackSummary();
    }
    setState(() => _isLoading = false);
  }

  void _fallbackSummary() {
    _addAliMessage('💚 Thank you for sharing that with me. I hear you, and I\'m truly here for you 🌿\n\nWhat would you like to talk about?');
  }

  Future<void> _sendMessageText(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text, 'time': _timeNow()});
      _isLoading = true;
    });
    if (_autoScroll) _scrollToBottom();
    await FirebaseService.saveChat('user', text);
    _chatHistory.add({'role': 'user', 'content': text});

    // First message — start assessment
    if (!_assessmentDone && _questionIndex == 0) {
      await Future.delayed(Duration(milliseconds: 600));
      _addAliMessage(_assessmentQuestions[0]['question']);
      setState(() => _isLoading = false);
      return;
    }

    await _callGemini(text);
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final userMessage = _controller.text.trim();
    _controller.clear();
    await _sendMessageText(userMessage);
  }

  Future<void> _callGemini(String userMessage) async {
    final answersContext = _assessmentAnswers.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    final lengthInstruction = _responseLength == 'Short'
        ? 'Keep response to 2 sentences.'
        : _responseLength == 'Long'
            ? 'Give detailed helpful response up to 8 sentences.'
            : 'Keep response to 3-5 sentences.';

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': '''You are ALI, a warm AI mental health companion in MindGuard.
${answersContext.isNotEmpty ? 'User background: $answersContext' : ''}

Capabilities:
- Use CBT techniques naturally
- If student with exam stress: give study timetables, focus techniques, Pomodoro method
- If work pressure: give time management, boundary setting, stress relief tips
- If relationship issues: give empathy, communication advice
- Suggest breathing/grounding exercises when distressed
- If severely distressed: suggest professional help kindly
- Be smart, helpful and conversational like Claude or Gemini
$lengthInstruction
Use gentle emojis occasionally.

Conversation:
${_chatHistory.map((m) => '${m['role']}: ${m['content']}').join('\n')}

User: $userMessage
ALI:'''}]}],
          'generationConfig': {'temperature': 0.9, 'maxOutputTokens': 500},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['candidates'][0]['content']['parts'][0]['text'];
        await FirebaseService.saveChat('assistant', aiResponse);
        _chatHistory.add({'role': 'model', 'content': aiResponse});
        _addAliMessage(aiResponse);
      } else {
        _addErrorMessage();
      }
    } catch (e) {
      _addErrorMessage();
    }
    setState(() => _isLoading = false);
  }

  void _addErrorMessage() {
    _addAliMessage('💚 I\'m having a little trouble connecting. Please try again!');
    setState(() => _isLoading = false);
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF0D1F35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 20),
          _menuTile(Icons.add_comment_outlined, 'New Chat', Color(0xFF00D4AA), () { _saveCurrentSession(); _startNewChat(); }),
          _menuTile(Icons.history, 'Chat History', Color(0xFF4A9EFF), () { Navigator.pop(context); _showChatHistory(); }),
          _menuTile(Icons.settings_outlined, 'Settings', Color(0xFF8B6FF0), () { Navigator.pop(context); _showSettings(); }),
          _menuTile(Icons.delete_outline, 'Clear This Chat', Color(0xFFFF6B6B), () {
            setState(() { _messages.clear(); _chatHistory.clear(); _chatStarted = false; });
            Navigator.pop(context);
          }),
        ]),
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
      title: Text(label, style: TextStyle(color: Colors.white, fontSize: 15)),
      onTap: onTap,
    );
  }

  void _showChatHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF0D1F35),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4, expand: false,
        builder: (_, sc) => Column(children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(children: [
              Spacer(),
              Text('Chat History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Spacer(),
            ]),
          ),
          Expanded(
            child: _allSessions.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 48),
                    SizedBox(height: 12),
                    Text('No saved chats yet', style: TextStyle(color: Colors.white38)),
                  ]))
                : ListView.builder(
                    controller: sc,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _allSessions.length,
                    itemBuilder: (_, i) {
                      final s = _allSessions[i];
                      final date = DateTime.tryParse(s['timestamp'] ?? '') ?? DateTime.now();
                      return Dismissible(
                        key: Key(s['id']),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteSession(s['id']),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(color: Color(0xFFFF6B6B).withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                          child: Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
                        ),
                        child: GestureDetector(
                          onTap: () => _loadSession(s),
                          child: Container(
                            margin: EdgeInsets.only(bottom: 10),
                            padding: EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: s['id'] == _currentSessionId ? Color(0xFF00D4AA).withOpacity(0.5) : Colors.white12),
                            ),
                            child: Row(children: [
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF00D4AA).withOpacity(0.3), Color(0xFF0066FF).withOpacity(0.3)])),
                                child: Icon(Icons.psychology, color: Color(0xFF00D4AA), size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s['title'] ?? 'Chat', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                SizedBox(height: 3),
                                Text('${date.day}/${date.month}/${date.year} · ${s['messageCount']} messages', style: TextStyle(color: Colors.white38, fontSize: 11)),
                              ])),
                              if (s['id'] == _currentSessionId)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: Color(0xFF00D4AA).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                  child: Text('Active', style: TextStyle(color: Color(0xFF00D4AA), fontSize: 10)),
                                ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF0D1F35),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4, expand: false,
          builder: (_, sc) => SingleChildScrollView(
            controller: sc,
            padding: EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 16),
              Center(child: Text('ALI Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
              SizedBox(height: 20),
              _settingSection('💬 Chat Preferences'),
              _settingToggle('Auto-scroll to new messages', _autoScroll, (v) { setModalState(() => _autoScroll = v); setState(() => _autoScroll = v); _saveSettings(); }),
              _settingToggle('Show message timestamps', _showTimestamps, (v) { setModalState(() => _showTimestamps = v); setState(() => _showTimestamps = v); _saveSettings(); }),
              _settingToggle('Proactive check-ins from ALI', _proactiveCheckIn, (v) { setModalState(() => _proactiveCheckIn = v); setState(() => _proactiveCheckIn = v); _saveSettings(); }),
              SizedBox(height: 16),
              _settingSection('📏 Response Length'),
              ...['Short', 'Medium', 'Long'].map((len) => RadioListTile<String>(
                value: len, groupValue: _responseLength,
                onChanged: (v) { setModalState(() => _responseLength = v!); setState(() => _responseLength = v!); _saveSettings(); },
                title: Text(
                  len == 'Short' ? '⚡ Short — Quick replies' : len == 'Medium' ? '💬 Medium — Balanced (recommended)' : '📖 Long — Detailed responses',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                activeColor: Color(0xFF00D4AA),
              )),
              SizedBox(height: 16),
              _settingSection('🔔 Notifications'),
              _settingToggle('Sound effects', _soundEnabled, (v) { setModalState(() => _soundEnabled = v); setState(() => _soundEnabled = v); _saveSettings(); }),
              SizedBox(height: 16),
              _settingSection('ℹ️ About ALI'),
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _aboutRow('Model', 'Gemini Pro (Google AI)'),
                  _aboutRow('Purpose', 'Mental wellness support'),
                  _aboutRow('Version', 'ALI v1.0 · MindGuard'),
                  _aboutRow('Privacy', 'Chats saved on Firebase'),
                ]),
              ),
              SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _settingSection(String title) => Padding(padding: EdgeInsets.only(bottom: 8), child: Text(title, style: TextStyle(color: Color(0xFF00D4AA), fontSize: 13, fontWeight: FontWeight.bold)));
  Widget _settingToggle(String label, bool value, Function(bool) onChanged) => Container(
    margin: EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
    child: SwitchListTile(title: Text(label, style: TextStyle(color: Colors.white, fontSize: 13)), value: value, onChanged: onChanged, activeColor: Color(0xFF00D4AA), dense: true),
  );
  Widget _aboutRow(String label, String value) => Padding(
    padding: EdgeInsets.only(bottom: 6),
    child: Row(children: [Text('$label: ', style: TextStyle(color: Colors.white54, fontSize: 12)), Text(value, style: TextStyle(color: Colors.white, fontSize: 12))]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: Color(0xFF0A1628),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () { _saveCurrentSession(); Navigator.pop(context); },
        ),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF0066FF)])),
            child: Icon(Icons.psychology, color: Colors.white, size: 22),
          ),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ALI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(_chatStarted ? '● Here for you 💚' : '● Ready to listen', style: TextStyle(color: Color(0xFF00D4AA), fontSize: 11)),
          ]),
        ]),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceChatScreen())),
            child: Container(
              margin: EdgeInsets.only(right: 4),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(color: Color(0xFF00D4AA).withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFF00D4AA).withOpacity(0.3))),
              child: Icon(Icons.mic, color: Color(0xFF00D4AA), size: 22),
            ),
          ),
          IconButton(icon: Icon(Icons.more_vert, color: Colors.white), onPressed: _showMenu),
        ],
      ),
      body: Column(children: [
        // Messages area OR welcome screen
        Expanded(
          child: !_chatStarted && _messages.isEmpty
              ? _buildWelcomeScreen()
              : Column(children: [
                  if (!_assessmentDone && _chatStarted) _buildProgressBar(),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) return _typingIndicator();
                        final msg = _messages[index];
                        final isAli = msg['role'] == 'assistant';
                        return Column(children: [
                          _messageBubble(msg['text']!, isAli, msg['time'] ?? ''),
                          if (isAli && !_assessmentDone && _chatStarted &&
                              index == _messages.length - 1 &&
                              _questionIndex < _assessmentQuestions.length &&
                              !_isLoading)
                            _buildOptions(_assessmentQuestions[_questionIndex]['options']),
                        ]);
                      },
                    ),
                  ),
                ]),
        ),

        // Always-visible bottom input bar
        _buildBottomBar(),
      ]),
    );
  }

  // ── WELCOME SCREEN ──────────────────────────────────────
  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(children: [
        SizedBox(height: 30),
        // ALI Avatar
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF0066FF)]),
            boxShadow: [BoxShadow(color: Color(0xFF00D4AA).withOpacity(0.4), blurRadius: 25, spreadRadius: 5)],
          ),
          child: Icon(Icons.psychology, color: Colors.white, size: 46),
        ),
        SizedBox(height: 20),
        Text('Hi, I\'m ALI 💚', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Your personal wellness companion.\nI\'m here to listen, support and guide you 🌿',
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6),
            textAlign: TextAlign.center),
        SizedBox(height: 32),
        // Suggestion starters
        Align(
          alignment: Alignment.centerLeft,
          child: Text('✨ Choose a topic to start, or type below:',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        SizedBox(height: 12),
        ..._conversationStarters.map((starter) => GestureDetector(
          onTap: () => _onStarterTapped(starter['text']!),
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF00D4AA).withOpacity(0.3)),
            ),
            child: Row(children: [
              Text(starter['emoji']!, style: TextStyle(fontSize: 22)),
              SizedBox(width: 12),
              Expanded(child: Text(starter['text']!, style: TextStyle(color: Colors.white, fontSize: 14))),
              Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
            ]),
          ),
        )).toList(),
        SizedBox(height: 12),
        Row(children: [
          Expanded(child: Divider(color: Colors.white12)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or type anything below', style: TextStyle(color: Colors.white38, fontSize: 12))),
          Expanded(child: Divider(color: Colors.white12)),
        ]),
        SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Quick check-in 💚', style: TextStyle(color: Colors.white54, fontSize: 11)),
          Text('${_questionIndex}/${_assessmentQuestions.length}', style: TextStyle(color: Color(0xFF00D4AA), fontSize: 11)),
        ]),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _questionIndex / _assessmentQuestions.length,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4AA)),
            minHeight: 4,
          ),
        ),
      ]),
    );
  }

  Widget _buildOptions(List<dynamic> options) {
    return Container(
      margin: EdgeInsets.only(top: 8, bottom: 12),
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: options.map((option) => GestureDetector(
          onTap: () => _handleOptionTap(option),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFF00D4AA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFF00D4AA).withOpacity(0.4)),
            ),
            child: Text(option, style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        )).toList(),
      ),
    );
  }

  // ── ALWAYS AT BOTTOM ────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF0A1628),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Quick replies (only after chat started)
        if (_chatStarted && _assessmentDone)
          Container(
            height: 42,
            margin: EdgeInsets.only(top: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              children: [
                _quickChip('😰 Stressed'),
                _quickChip('😔 Sad'),
                _quickChip('😴 Tired'),
                _quickChip('📚 Study help'),
                _quickChip('💼 Work stress'),
                _quickChip('💔 Relationship'),
              ],
            ),
          ),

        // Input field
        Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: TextStyle(color: Colors.white),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: _chatStarted ? 'Tell ALI how you feel...' : 'Or type directly to start...',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Color(0xFF1A2640),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _onDirectSend(),
              ),
            ),
            SizedBox(width: 8),
            GestureDetector(
              onTap: _onDirectSend,
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF0066FF)]),
                  boxShadow: [BoxShadow(color: Color(0xFF00D4AA).withOpacity(0.4), blurRadius: 10)],
                ),
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _quickChip(String label) {
    return GestureDetector(
      onTap: () { _controller.text = label; _onDirectSend(); },
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFF1A2640),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFF00D4AA).withOpacity(0.4)),
        ),
        child: Text(label, style: TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }

  Widget _messageBubble(String text, bool isAli, String time) {
    return Align(
      alignment: isAli ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: isAli ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.all(14),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              gradient: isAli
                  ? LinearGradient(colors: [Color(0xFF00D4AA).withOpacity(0.2), Color(0xFF0066FF).withOpacity(0.1)])
                  : LinearGradient(colors: [Color(0xFF0066FF).withOpacity(0.4), Color(0xFF0066FF).withOpacity(0.2)]),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16),
                bottomLeft: isAli ? Radius.circular(4) : Radius.circular(16),
                bottomRight: isAli ? Radius.circular(16) : Radius.circular(4),
              ),
              border: Border.all(color: isAli ? Color(0xFF00D4AA).withOpacity(0.3) : Color(0xFF0066FF).withOpacity(0.3)),
            ),
            child: Text(text, style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
          ),
          if (_showTimestamps && time.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 4, left: 4, right: 4),
              child: Text(time, style: TextStyle(color: Colors.white24, fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _typingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(color: Color(0xFF00D4AA).withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('ALI is typing', style: TextStyle(color: Colors.white60, fontSize: 13)),
          SizedBox(width: 8),
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D4AA))),
        ]),
      ),
    );
  }
}