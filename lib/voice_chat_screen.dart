import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firebase_service.dart';
import 'tracking_service.dart';

class VoiceChatScreen extends StatefulWidget {
  @override
  _VoiceChatScreenState createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with TickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _isResponding = false;
  bool _speechAvailable = false;
  String _spokenText = '';
  String _aliResponse = '';
  String _voiceType = 'female'; // 'female' or 'male'
  String _detectedEmotion = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ⚠️ REPLACE WITH YOUR GEMINI API KEY
  final String _apiKey = 'YOUR_GEMINI_API_KEY';

  final List<Map<String, String>> _conversation = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
    _initTTS();
    _speakWelcome();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    setState(() {});
  }

  Future<void> _initTTS() async {
    await _tts.setLanguage('en-US');
    await _setVoice();
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(_voiceType == 'female' ? 1.3 : 0.8);
  }

  Future<void> _setVoice() async {
    await _tts.setPitch(_voiceType == 'female' ? 1.3 : 0.8);
    await _tts.setSpeechRate(_voiceType == 'female' ? 0.45 : 0.4);
  }

  Future<void> _speakWelcome() async {
    await Future.delayed(Duration(milliseconds: 800));
    await _speak("Hi! I'm ALI, your wellness companion. How are you feeling today? Just tap the button and talk to me.");
  }

  Future<void> _speak(String text) async {
    setState(() => _isResponding = true);
    await _tts.speak(text);
    await Future.delayed(Duration(milliseconds: (text.length * 60).clamp(1000, 10000)));
    setState(() => _isResponding = false);
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;
    setState(() {
      _isListening = true;
      _spokenText = '';
    });
    await _speech.listen(
      onResult: (result) {
        setState(() => _spokenText = result.recognizedWords);
        if (result.finalResult && _spokenText.isNotEmpty) {
          _stopListening();
        }
      },
      listenFor: Duration(seconds: 15),
      pauseFor: Duration(seconds: 3),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    if (_spokenText.isNotEmpty) {
      _analyzeAndRespond(_spokenText);
    }
  }

  String _detectEmotionFromText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains(RegExp(r'sad|cry|depress|hopeless|lonely|empty|hurt'))) return 'sad';
    if (lower.contains(RegExp(r'anxi|worry|stress|panic|fear|nervous|overwhelm'))) return 'anxious';
    if (lower.contains(RegExp(r'angry|anger|frustrat|mad|furious|annoy'))) return 'angry';
    if (lower.contains(RegExp(r'happy|great|good|wonderful|joy|excit|love'))) return 'happy';
    if (lower.contains(RegExp(r'tired|exhaust|sleep|fatigue|drain'))) return 'tired';
    return 'neutral';
  }

  Future<void> _analyzeAndRespond(String userText) async {
    final emotion = _detectEmotionFromText(userText);
    setState(() {
      _detectedEmotion = emotion;
      _isResponding = true;
    });

    // Save voice sentiment to Firebase
    await TrackingService.saveVoiceSentiment(emotion, 0.85);
    await FirebaseService.saveChat('user', userText);

    _conversation.add({'role': 'user', 'content': userText});

    try {
      final history = _conversation.map((m) => {
        'role': m['role'] == 'assistant' ? 'model' : 'user',
        'parts': [{'text': m['content']}]
      }).toList();

      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [{'text': '''
You are ALI, a warm voice-based mental health companion.
The user seems to be feeling $emotion based on their words.
- Respond with empathy and warmth
- Keep response to 2-3 sentences maximum (this is voice!)
- No bullet points or lists - speak naturally
- Offer practical help based on their role (student/worker)
- Gently suggest breathing or grounding exercises if distressed
- Always end with a question to continue the conversation
'''}]
          },
          'contents': history,
          'generationConfig': {'temperature': 0.9, 'maxOutputTokens': 200},
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['candidates'][0]['content']['parts'][0]['text'];
        setState(() {
          _aliResponse = reply;
          _conversation.add({'role': 'assistant', 'content': reply});
        });
        await FirebaseService.saveChat('assistant', reply);
        await _speak(reply);
      } else {
        await _speak("I'm having a little trouble right now. But I'm here with you. Can you try again?");
      }
    } catch (e) {
      await _speak("Something went wrong, but I'm still here for you. Please try again.");
    }
    setState(() => _isResponding = false);
  }

  String _emotionEmoji(String emotion) {
    switch (emotion) {
      case 'sad': return '😔';
      case 'anxious': return '😰';
      case 'angry': return '😤';
      case 'happy': return '😊';
      case 'tired': return '😴';
      default: return '😐';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF060D1F),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(child: _buildMainArea()),
          _buildControls(),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07)))),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          ),
        ),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Voice Chat with ALI 🎙️', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          Text('AI-powered voice wellness support', style: TextStyle(color: Color(0xFF00D4AA), fontSize: 11)),
        ])),
        // Voice type toggle
        GestureDetector(
          onTap: () async {
            setState(() => _voiceType = _voiceType == 'female' ? 'male' : 'female');
            await _setVoice();
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Color(0xFF00D4AA).withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Color(0xFF00D4AA).withOpacity(0.3))),
            child: Text(_voiceType == 'female' ? '👩 Soft' : '👨 Calm', style: TextStyle(color: Color(0xFF00D4AA), fontSize: 12)),
          ),
        ),
      ]),
    );
  }

  Widget _buildMainArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ALI Avatar with pulse
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: (_isListening || _isResponding) ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF0066FF)]),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF00D4AA).withOpacity(_isListening ? 0.6 : 0.3),
                      blurRadius: _isListening ? 40 : 20,
                      spreadRadius: _isListening ? 10 : 5,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : _isResponding ? Icons.volume_up : Icons.psychology,
                  color: Colors.white,
                  size: 65,
                ),
              ),
            );
          },
        ),

        SizedBox(height: 24),

        // Status
        Text(
          _isListening ? 'Listening... 🎙️' : _isResponding ? 'ALI is speaking... 💬' : 'Tap mic to speak 💚',
          style: TextStyle(color: Color(0xFF00D4AA), fontSize: 16, fontWeight: FontWeight.w500),
        ),

        SizedBox(height: 16),

        // Emotion detected
        if (_detectedEmotion.isNotEmpty)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 40),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
            child: Text('Detected emotion: ${_emotionEmoji(_detectedEmotion)} $_detectedEmotion',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),

        SizedBox(height: 20),

        // What user said
        if (_spokenText.isNotEmpty)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 24),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF00D4AA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF00D4AA).withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('You said:', style: TextStyle(color: Colors.white54, fontSize: 11)),
              SizedBox(height: 4),
              Text(_spokenText, style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
            ]),
          ),

        SizedBox(height: 12),

        // ALI response
        if (_aliResponse.isNotEmpty)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 24),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ALI:', style: TextStyle(color: Color(0xFF00D4AA), fontSize: 11)),
              SizedBox(height: 4),
              Text(_aliResponse, style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
            ]),
          ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(children: [
        // Big mic button
        GestureDetector(
          onTap: _isListening ? _stopListening : _startListening,
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isListening
                    ? [Color(0xFFFF6B6B), Color(0xFFFF8E53)]
                    : [Color(0xFF00D4AA), Color(0xFF0066FF)],
              ),
              boxShadow: [BoxShadow(
                color: (_isListening ? Color(0xFFFF6B6B) : Color(0xFF00D4AA)).withOpacity(0.5),
                blurRadius: 20, spreadRadius: 4,
              )],
            ),
            child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white, size: 36),
          ),
        ),
        SizedBox(height: 12),
        Text(
          _isListening ? 'Tap to stop' : 'Tap to speak',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}