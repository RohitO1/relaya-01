import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// The static Bot ID that we will use to identify bot messages
const String kBotUuid = '00000000-0000-0000-0000-000000000000';

class HfService {
  static Future<String> generate(String prompt) async {
    try {
      final res = await http.get(Uri.parse("https://text.pollinations.ai/${Uri.encodeComponent(prompt)}"));
      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        return res.body.trim();
      }
    } catch (_) {}
    
    // Fallback if APIs are completely offline
    await Future.delayed(const Duration(milliseconds: 1500));
    if (prompt.toLowerCase().contains("hello") || prompt.toLowerCase().contains("hi")) {
      return "Greetings, traveler! I am the Meetra AI Oracle. My neural link is currently sleeping. How can I assist you in this digital realm? 🌌";
    }
    return "Bzzt! I am processing your words. (External API Connection Error). ✨";
  }
}

class BotChatScreen extends StatefulWidget {
  const BotChatScreen({super.key});

  @override
  State<BotChatScreen> createState() => _BotChatScreenState();
}

class _BotChatScreenState extends State<BotChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late final String _myUid;
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isBotThinking = false;

  @override
  void initState() {
    super.initState();
    _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    _loadMessages();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? msgsStr = prefs.getString('bot_messages_$_myUid');
    if (msgsStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(msgsStr);
        if (mounted) {
          setState(() {
            _messages = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            _isLoading = false;
          });
          _scrollToBottom();
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bot_messages_$_myUid', jsonEncode(_messages));
  }
  
  Future<void> _clearMessages() async {
    setState(() {
      _messages.clear();
    });
    await _saveMessages();
  }

  Future<void> _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    
    final text = _msgController.text.trim();
    _msgController.clear();
    HapticFeedback.lightImpact();
    
    // 1. Optimistic Update (User)
    final userMsg = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'sender_id': _myUid,
      'receiver_id': kBotUuid,
      'text': text,
      'is_image': false,
      'created_at': DateTime.now().toIso8601String(),
    };
    
    setState(() {
      _messages.add(userMsg);
      _isBotThinking = true;
    });
    
    _saveMessages();
    _scrollToBottom();
    
    // 2. Call HF API
    final aiResponse = await HfService.generate(text);

    // 3. Insert Bot msg into List
    final botMsg = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'sender_id': kBotUuid,
      'receiver_id': _myUid,
      'text': aiResponse,
      'is_image': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (mounted) {
      setState(() {
        _messages.add(botMsg);
        _isBotThinking = false;
      });
      _saveMessages();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat History?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('This will delete your entire conversation with the AI Oracle. This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearMessages();
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF0055), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020205),
      body: Stack(
        children: [
          // Background ambient lights
          Positioned(
            top: -100, right: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFF0055).withValues(alpha: 0.15))),
            ),
          ),
          Positioned(
            bottom: -50, left: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(width: 350, height: 350, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF00E5FF).withValues(alpha: 0.15))),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // ── App Bar ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          gradient: const SweepGradient(colors: [Color(0xFF00E5FF), Color(0xFFFF0055), Color(0xFF8B5CF6), Color(0xFF00E5FF)]),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xFFFF0055).withValues(alpha: 0.3), blurRadius: 10)],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Container(
                            decoration: const BoxDecoration(color: Color(0xFF050508), shape: BoxShape.circle),
                            child: const Center(child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Meetra AI', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                            Text('Hugging Face Intelligence', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      // DELETE CHAT BOT BUTTON
                      GestureDetector(
                        onTap: _showClearDialog,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.delete_outline, color: Colors.white60, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1, color: Colors.white10),
                
                // ── Chat List ──
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF0055)))
                    : (_messages.isEmpty 
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.auto_awesome, color: Color(0xFFFF0055), size: 48),
                                const SizedBox(height: 16),
                                const Text('Initialize Oracle', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40),
                                  child: Text('Ask me anything. I run on deep neural networks.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(20),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isUser = msg['sender_id'] == _myUid;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Align(
                                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                  child: isUser ? _buildUserBubble(msg['text']) : _buildBotBubble(msg['text']),
                                ),
                              );
                            },
                          )
                      ),
                ),
                
                // Bot typing indicator
                if (_isBotThinking)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF0055)),
                          ),
                          const SizedBox(width: 8),
                          Text('AI is thinking...', style: TextStyle(color: const Color(0xFFFF0055).withValues(alpha: 0.8), fontSize: 11, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ),
                
                // ── Input Field ──
                Container(
                  margin: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Ask the oracle...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                            border: InputBorder.none,
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF0055), Color(0xFF8B5CF6)]),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: const Color(0xFFFF0055).withValues(alpha: 0.4), blurRadius: 8)],
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(String text) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D12),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24), bottomLeft: Radius.circular(24), bottomRight: Radius.circular(6)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
    );
  }

  Widget _buildBotBubble(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 24, height: 24,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFFFF0055)]),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.smart_toy, color: Colors.white, size: 12),
        ),
        const SizedBox(width: 8),
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFF00E5FF).withValues(alpha: 0.1), const Color(0xFFFF0055).withValues(alpha: 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24), bottomLeft: Radius.circular(6), bottomRight: Radius.circular(24)),
            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
          ),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
        ),
      ],
    );
  }
}
