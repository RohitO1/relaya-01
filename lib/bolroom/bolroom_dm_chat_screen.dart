// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:meetra_app/image_upload_service.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../chatroom_live_screen.dart';

class BolroomDmChatScreen extends StatefulWidget {
  final String conversationId;
  final String partnerId;
  final String partnerName;
  final String partnerAvatarKey;

  const BolroomDmChatScreen({
    super.key,
    required this.conversationId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerAvatarKey,
  });

  @override
  State<BolroomDmChatScreen> createState() => _BolroomDmChatScreenState();
}

class _BolroomDmChatScreenState extends State<BolroomDmChatScreen> {
  final _sb = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _isTyping = false;
  bool _showEmojiPicker = false;

  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;
  bool _isRecording = false;
  bool _isAudioPreview = false;
  String? _recordedFilePath;
  Timer? _recordTimer;
  Duration _recordDuration = Duration.zero;
  String? _playingAudioUrl;
  bool _isPlayingAudio = false;

  String get _myId => _sb.auth.currentUser?.id ?? '';
  RealtimeChannel? _channel;

  static const Color bgColor = Color(0xFF090710);
  static const Color cardColor = Color(0xFF13101E);
  static const Color borderColor = Color(0xFF231D38);
  static const Color purplePrimary = Color(0xFFB983FF);
  static const Color purpleDark = Color(0xFF7B2CBF);
  static const Color textMuted = Color(0xFF8E8B99);

  static LinearGradient neonGradient = const LinearGradient(
    colors: [Color(0xFFD433FF), Color(0xFF7B2CBF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient userAvatarAura = const LinearGradient(
    colors: [Color(0xFFD433FF), Color(0xFF7B2CBF), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlayingAudio = state == PlayerState.playing);
    });

    _messageController.addListener(() {
      setState(() {
        _isTyping = _messageController.text.trim().isNotEmpty;
      });
    });
    _loadMessages();
    _subscribeRealtime();
    _markRead();
  }

  @override
  void dispose() {
    if (_channel != null) _sb.removeChannel(_channel!);
    _messageController.dispose();
    _scrollCtrl.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final res = await _sb.from('bolroom_dm_messages')
          .select('*')
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true)
          .limit(200);
      if (mounted) {
        setState(() { _messages = List<Map<String, dynamic>>.from(res); _loading = false; });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Load DM messages: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = _sb.channel('dm_chat_${widget.conversationId}').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'bolroom_dm_messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.conversationId),
      callback: (payload) {
        if (payload.newRecord.isNotEmpty && mounted) {
          setState(() => _messages.add(payload.newRecord));
          _scrollToBottom();
          _markRead();
        }
      },
    );
    _channel!.subscribe();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _markRead() async {
    try {
      await _sb.from('bolroom_dm_messages')
          .update({'is_read': true})
          .eq('conversation_id', widget.conversationId)
          .neq('sender_id', _myId)
          .eq('is_read', false);
    } catch (_) {}
  }

  Future<void> _sendMessage({String? attachmentText}) async {
    final text = attachmentText ?? _messageController.text.trim();
    if (text.isEmpty) return;
    if (attachmentText == null) _messageController.clear();
    HapticFeedback.lightImpact();

    try {
      await _sb.from('bolroom_dm_messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': _myId,
        'text': text,
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      String previewMessage = text;
      if (text.startsWith('[IMAGE]')) {
        previewMessage = '📷 Image';
      } else if (text.startsWith('[AUDIO]')) previewMessage = '🎤 Voice Message';

      // Update conversation last_message
      await _sb.from('bolroom_dm_conversations').update({
        'last_message': previewMessage,
        'last_message_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.conversationId);
      
      setState(() {
        _isAudioPreview = false;
        _recordedFilePath = null;
      });
    } catch (e) {
      debugPrint('Send DM: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: purplePrimary, strokeWidth: 2))
                  : _buildMessageList(),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CUSTOM APP BAR
  // ==========================================
  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(bottom: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          
          // User Avatar & Online Status
          Stack(
            children: [
              _buildGlowingAvatar(44),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF00), // Online Green
                    shape: BoxShape.circle,
                    border: Border.all(color: bgColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          
          // User Name & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.partnerName,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "Online now",
                  style: TextStyle(color: purplePrimary.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          
          // Action Buttons
          _buildAppBarAction(Icons.videocam_outlined),
          const SizedBox(width: 12),
          _buildAppBarAction(Icons.call_outlined),
        ],
      ),
    );
  }

  Widget _buildAppBarAction(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cardColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
      child: Icon(icon, color: purplePrimary, size: 20),
    );
  }

  // ==========================================
  // MESSAGE LIST
  // ==========================================
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final showDate = index == 0 || _shouldShowDate(_messages[index - 1], msg);
        
        return Column(
          children: [
            if (showDate) _buildDateSeparator(msg['created_at']),
            _buildChatBubble(msg, index),
          ],
        );
      },
    );
  }

  bool _shouldShowDate(Map<String, dynamic> prev, Map<String, dynamic> curr) {
    try {
      final prevDt = DateTime.parse(prev['created_at'].toString()).toLocal();
      final currDt = DateTime.parse(curr['created_at'].toString()).toLocal();
      return prevDt.day != currDt.day || prevDt.month != currDt.month;
    } catch (_) { return false; }
  }

  Widget _buildDateSeparator(dynamic ts) {
    String label = 'Today';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) {
        label = 'Today';
      } else if (diff.inDays == 1) label = 'Yesterday';
      else label = '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            label,
            style: const TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg, int index) {
    bool isMe = msg['sender_id'] == _myId;
    String text = msg['text'] ?? '';
    String time = _formatTime(msg['created_at']);
    bool isRead = msg['is_read'] == true;

    // To mimic the UI logic exactly: determine if the NEXT message is from the same user.
    // Because ListView builds top-down (index 0 is oldest), the "bottom" spacing 
    // should be larger if the next message (index + 1) is from someone else.
    bool isLastInSequence = true;
    if (index < _messages.length - 1) {
      isLastInSequence = _messages[index + 1]['sender_id'] != msg['sender_id'];
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLastInSequence ? 16.0 : 4.0,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildGlowingAvatar(28),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? null : cardColor,
                gradient: isMe ? neonGradient : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                border: isMe ? null : Border.all(color: borderColor),
                boxShadow: isMe
                    ? [
                        BoxShadow(
                          color: purpleDark.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      if (text.startsWith('[IMAGE]')) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(text.substring(7), width: 220, fit: BoxFit.cover),
                        );
                      } else if (text.startsWith('[AUDIO]')) {
                        final audioUrl = text.substring(7);
                        return _buildAudioPlayerMessage(audioUrl, isMe);
                      } else if (text.startsWith('[VOICEROOM_INVITE]')) {
                        final data = text.substring(18).split('::');
                        if (data.length == 5) {
                          return _buildInviteCard(
                            roomId: data[0],
                            roomName: data[1],
                            topic: data[2],
                            hostId: data[3],
                            hostName: data[4],
                            isMe: isMe,
                          );
                        }
                        return const Text("Invalid Invite");
                      } else {
                        return Text(
                          text,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.white.withValues(alpha: 0.9),
                            fontSize: 15,
                            height: 1.3,
                          ),
                        );
                      }
                    }
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: isMe ? Colors.white.withValues(alpha: 0.7) : textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: isRead ? const Color(0xFF00FFFF) : Colors.white.withValues(alpha: 0.5),
                        ),
                      ]
                    ],
                  )
                ],
              ),
            ),
          ),
          
          if (isMe) const SizedBox(width: 28), // Spacer to balance the avatar on the left
        ],
      ),
    );
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) { return ''; }
  }

  // ==========================================
  // INPUT AREA (BOTTOM)
  // ==========================================

  Widget _buildAudioPlayerMessage(String url, bool isMe) {
    bool isPlaying = _playingAudioUrl == url && _isPlayingAudio;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () async {
            if (isPlaying) {
              await _audioPlayer.pause();
            } else {
              setState(() => _playingAudioUrl = url);
              await _audioPlayer.play(UrlSource(url));
            }
          },
          child: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: isMe ? Colors.white : purplePrimary, size: 36),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100, height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(10, (i) => Container(
              width: 3, height: isPlaying ? (10 + (i % 3) * 5).toDouble() : 4,
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withValues(alpha: 0.7) : textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteCard({
    required String roomId,
    required String roomName,
    required String topic,
    required String hostId,
    required String hostName,
    required bool isMe,
  }) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.1) : cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMe ? Colors.white30 : purplePrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: purplePrimary.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.graphic_eq, color: purplePrimary, size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text("Private VoiceRoom", style: TextStyle(color: purplePrimary, fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 12),
          Text(roomName, style: TextStyle(color: isMe ? Colors.white : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("Host: $hostName", style: TextStyle(color: isMe ? Colors.white70 : textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: purplePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                BolRoomManager.openRoom(
                  context,
                  roomId: roomId,
                  roomName: roomName,
                  topic: topic,
                  hostId: hostId,
                  hostName: hostName,
                );
              },
              child: const Text("Join Space", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          )
        ],
      ),
    );
  }

  void _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      final path = await _audioRecorder.stop();
      _recordTimer?.cancel();
      setState(() {
        _isRecording = false;
        _isAudioPreview = true;
        _recordedFilePath = path;
      });
    } else {
      // Start recording
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        setState(() {
          _isRecording = true;
          _recordDuration = Duration.zero;
        });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _recordDuration = Duration(seconds: timer.tick));
        });
      }
    }
  }

  void _cancelAudioPreview() {
    setState(() {
      _isAudioPreview = false;
      _recordedFilePath = null;
    });
  }

  Future<void> _sendAudioMessage() async {
    if (_recordedFilePath == null) return;
    try {
      final file = File(_recordedFilePath!);
      final bytes = await file.readAsBytes();
      final fileName = 'dm_audio/${_myId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _sb.storage.from('avatars').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(contentType: 'audio/m4a', upsert: true),
      );
      final url = _sb.storage.from('avatars').getPublicUrl(fileName);
      _sendMessage(attachmentText: '[AUDIO]$url');
    } catch (e) {
      debugPrint('Audio upload failed: $e');
    }
  }

  Future<void> _pickImage() async {
    final url = await ImageUploadService.pickAndUpload(context: context, folder: 'dm_images');
    if (url != null) {
      _sendMessage(attachmentText: '[IMAGE]$url');
    }
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 20),
          decoration: const BoxDecoration(
            color: Color(0xFF0E0B16), // Darker nav background
            border: Border(top: BorderSide(color: borderColor, width: 1)),
          ),
          child: _isAudioPreview ? _buildAudioPreviewBar() : _buildNormalInputBar(),
        ),
        if (_showEmojiPicker)
          Container(
            height: 280,
            color: const Color(0xFF0E0B16),
            child: EmojiPicker(
              textEditingController: _messageController,
              config: Config(
                checkPlatformCompatibility: false, // Disables font checking to eliminate the 0.5s lag
                bottomActionBarConfig: const BottomActionBarConfig(
                  showBackspaceButton: false,
                  backgroundColor: Color(0xFF0E0B16),
                  buttonColor: Color(0xFF0E0B16),
                  buttonIconColor: textMuted,
                ),
                categoryViewConfig: const CategoryViewConfig(
                  backgroundColor: Color(0xFF0E0B16),
                  dividerColor: borderColor,
                  indicatorColor: purplePrimary,
                  iconColorSelected: purplePrimary,
                  iconColor: textMuted,
                ),
                emojiViewConfig: const EmojiViewConfig(
                  backgroundColor: Color(0xFF0E0B16),
                  columns: 8,
                  loadingIndicator: Center(
                    child: CircularProgressIndicator(color: purplePrimary, strokeWidth: 2),
                  ),
                ),
                searchViewConfig: const SearchViewConfig(
                  backgroundColor: Color(0xFF0E0B16),
                  buttonIconColor: textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAudioPreviewBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: _cancelAudioPreview,
          child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.multitrack_audio, color: purplePrimary),
                const SizedBox(width: 8),
                Text(
                  '${_recordDuration.inMinutes}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    if (_isPlayingAudio) {
                      await _audioPlayer.pause();
                    } else if (_recordedFilePath != null) {
                      await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
                    }
                  },
                  child: Icon(_isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_fill, color: purplePrimary, size: 28),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: _sendAudioMessage,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: neonGradient, boxShadow: [BoxShadow(color: purpleDark.withValues(alpha: 0.5), blurRadius: 12)]),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalInputBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Attachment Button
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: const Icon(Icons.add, color: textMuted, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // Text Field
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _messageController,
              maxLines: null,
              onTap: () { if (_showEmojiPicker) setState(() => _showEmojiPicker = false); },
              textInputAction: TextInputAction.newline,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: _isRecording ? "Recording..." : "Message ${widget.partnerName}...",
                hintStyle: TextStyle(color: _isRecording ? Colors.redAccent : textMuted, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                suffixIcon: GestureDetector(
                  onTap: () {
                    setState(() => _showEmojiPicker = !_showEmojiPicker);
                    if (_showEmojiPicker) FocusScope.of(context).unfocus();
                  },
                  child: Icon(
                    _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    color: textMuted.withValues(alpha: 0.7), size: 22
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // Mic / Send Button (Animated Transition)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: GestureDetector(
            onTap: _isTyping ? () => _sendMessage() : _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isTyping ? neonGradient : (_isRecording ? const LinearGradient(colors: [Colors.red, Colors.redAccent]) : null),
                color: (_isTyping || _isRecording) ? null : cardColor,
                border: (_isTyping || _isRecording) ? null : Border.all(color: borderColor),
                boxShadow: _isTyping || _isRecording
                    ? [
                        BoxShadow(
                          color: _isTyping ? purpleDark.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  _isTyping ? Icons.send_rounded : (_isRecording ? Icons.stop_rounded : Icons.mic_none_rounded),
                  key: ValueKey<bool>(_isTyping || _isRecording),
                  color: (_isTyping || _isRecording) ? Colors.white : purplePrimary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  Widget _buildGlowingAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: userAvatarAura,
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: bgColor),
          child: CircleAvatar(
            backgroundColor: cardColor,
            child: Icon(Icons.person, color: Colors.white30, size: size * 0.6),
          ),
        ),
      ),
    );
  }
}


