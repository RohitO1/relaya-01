import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RushInChatRoomScreen extends StatefulWidget {
  final String activityId;
  final String activityTitle;
  final String hostId;

  const RushInChatRoomScreen({
    super.key,
    required this.activityId,
    required this.activityTitle,
    required this.hostId,
  });

  @override
  State<RushInChatRoomScreen> createState() => _RushInChatRoomScreenState();
}

class _RushInChatRoomScreenState extends State<RushInChatRoomScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, Map<String, dynamic>> _profileCache = {};
  
  List<Map<String, dynamic>> _messages = [];
  Map<String, String> _participantStatuses = {};
  Map<String, String> _chatStatuses = {};
  bool _isLoading = true;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _requestsChannel;
  RealtimeChannel? _chatStatusChannel;

  final Map<String, Map<String, dynamic>> _typingUsers = {};
  Timer? _typingTimer;
  Timer? _typingCleanupTimer;
  bool _isCurrentlyTyping = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _loadMessages();
    _subscribeToMessages();
    _subscribeToRequests();
    _subscribeToChatStatus();
    _textCtrl.addListener(_onTextChanged);
    _typingCleanupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      bool changed = false;
      _typingUsers.removeWhere((userId, info) {
        final lastActive = info['timestamp'] as DateTime;
        final isStale = now.difference(lastActive).inSeconds > 6;
        if (isStale) changed = true;
        return isStale;
      });
      if (changed && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    _requestsChannel?.unsubscribe();
    _chatStatusChannel?.unsubscribe();
    _typingTimer?.cancel();
    _typingCleanupTimer?.cancel();
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    _scrollController.dispose();
    _saveLastReadTime();
    super.dispose();
  }

  Future<void> _saveLastReadTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'rushin_chat_last_read_${widget.activityId}',
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error saving last read time: $e');
    }
  }

  Future<void> _loadRequests() async {
    try {
      final res = await Supabase.instance.client
          .from('requests')
          .select('sender_id, status')
          .eq('target_id', widget.activityId);
      
      final Map<String, String> statusMap = {};
      for (final row in (res as List)) {
        statusMap[row['sender_id'].toString()] = row['status'].toString();
      }
      if (mounted) {
        setState(() {
          _participantStatuses = statusMap;
        });
      }
    } catch (e) {
      debugPrint('Error loading requests: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final res = await Supabase.instance.client
          .from('rush_in_messages')
          .select()
          .eq('activity_id', widget.activityId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(res as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToMessages() {
    _messagesChannel = Supabase.instance.client
        .channel('rush_in_messages:${widget.activityId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rush_in_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'activity_id',
            value: widget.activityId,
          ),
          callback: (payload) {
            final event = payload.eventType;
            if (event == PostgresChangeEvent.insert) {
              final newRow = payload.newRecord;
              if (mounted && newRow.isNotEmpty) {
                final alreadyExists = _messages.any((m) => m['id'] == newRow['id']);
                if (!alreadyExists) {
                  setState(() {
                    _messages.insert(0, newRow);
                  });
                  _scrollToBottom();
                }
              }
            } else if (event == PostgresChangeEvent.delete) {
              final oldRow = payload.oldRecord;
              if (mounted && oldRow.isNotEmpty) {
                setState(() {
                  _messages.removeWhere((m) => m['id'] == oldRow['id']);
                });
              }
            }
          },
        )
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final senderId = payload['user_id'] as String?;
            final isTyping = payload['is_typing'] as bool? ?? false;
            final avatarUrl = payload['avatar_url'] as String?;
            final name = payload['name'] as String?;
            final myUid = Supabase.instance.client.auth.currentUser?.id;

            if (senderId != null && senderId != myUid) {
              if (mounted) {
                setState(() {
                  if (isTyping) {
                    _typingUsers[senderId] = {
                      'avatar_url': avatarUrl,
                      'name': name,
                      'timestamp': DateTime.now(),
                    };
                  } else {
                    _typingUsers.remove(senderId);
                  }
                });
              }
            }
          },
        )
        .subscribe();
  }

  void _subscribeToRequests() {
    _requestsChannel = Supabase.instance.client
        .channel('rush_in_requests:${widget.activityId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'target_id',
            value: widget.activityId,
          ),
          callback: (payload) {
            _loadRequests();
          },
        )
        .subscribe();
  }

  void _subscribeToChatStatus() {
    _chatStatusChannel = Supabase.instance.client
        .channel('rush_in_chat_status:${widget.activityId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rush_in_chat_status',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'activity_id',
            value: widget.activityId,
          ),
          callback: (payload) {
            _checkMyChatStatus();
            _loadChatStatuses();
          },
        )
        .subscribe();

    _checkMyChatStatus();
    _loadChatStatuses();
  }

  Future<void> _checkMyChatStatus() async {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    if (myUid == null) return;
    try {
      final res = await Supabase.instance.client
          .from('rush_in_chat_status')
          .select('status')
          .eq('activity_id', widget.activityId)
          .eq('user_id', myUid)
          .maybeSingle();

      if (res != null && res['status'] == 'removed') {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have been removed from this chat room by the host.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking chat status: $e');
    }
  }

  Future<void> _loadChatStatuses() async {
    try {
      final res = await Supabase.instance.client
          .from('rush_in_chat_status')
          .select('user_id, status')
          .eq('activity_id', widget.activityId);
      
      final Map<String, String> chatMap = {};
      for (final row in (res as List)) {
        chatMap[row['user_id'].toString()] = row['status'].toString();
      }
      if (mounted) {
        setState(() {
          _chatStatuses = chatMap;
        });
      }
    } catch (e) {
      debugPrint('Error loading chat statuses: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<Map<String, dynamic>> _getProfile(String uid) async {
    if (_profileCache.containsKey(uid)) return _profileCache[uid]!;
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('name, full_name, avatar_url')
          .eq('id', uid)
          .maybeSingle();
      if (res != null) {
        final profileMap = Map<String, dynamic>.from(res);
        _profileCache[uid] = profileMap;
        return profileMap;
      }
    } catch (_) {}
    return {'name': 'Unknown User', 'avatar_url': 'https://i.pravatar.cc/150'};
  }

  Color _getRoleColor(String userId) {
    if (userId == widget.hostId) {
      return const Color(0xFFEF4444); // Red for Host
    }
    final status = _participantStatuses[userId];
    if (status == 'approved') {
      return const Color(0xFF10B981); // Green for Approved
    } else if (status == 'pending') {
      return const Color(0xFFFBBF24); // Yellow for Pending/Interested
    }
    return const Color(0xFFFBBF24); // Fallback
  }

  String _getRoleLabel(String userId) {
    if (userId == widget.hostId) {
      return 'Host';
    }
    final status = _participantStatuses[userId];
    if (status == 'approved') {
      return 'Going';
    } else if (status == 'pending') {
      return 'Interested';
    }
    return 'Interested';
  }

  void _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _textCtrl.clear();

    _typingTimer?.cancel();
    if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      _sendTypingStatus(false);
    }

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id': tempId,
      'activity_id': widget.activityId,
      'user_id': uid,
      'text': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (mounted) {
      setState(() {
        _messages.insert(0, tempMsg);
      });
      _scrollToBottom();
    }

    try {
      final inserted = await Supabase.instance.client
          .from('rush_in_messages')
          .insert({
            'activity_id': widget.activityId,
            'user_id': uid,
            'text': text,
          })
          .select()
          .single();

      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == tempId);
          if (idx != -1) {
            _messages[idx] = inserted;
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to send message: $e');
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == tempId);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _onTextChanged() {
    final hasText = _textCtrl.text.isNotEmpty;
    if (hasText != _isCurrentlyTyping) {
      _isCurrentlyTyping = hasText;
      _sendTypingStatus(hasText);
    }

    _typingTimer?.cancel();
    if (hasText) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (_isCurrentlyTyping) {
          _isCurrentlyTyping = false;
          _sendTypingStatus(false);
        }
      });
    }
  }

  void _sendTypingStatus(bool isTyping) async {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    if (myUid == null || _messagesChannel == null) return;

    final myProfile = await _getProfile(myUid);
    try {
      await _messagesChannel!.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': myUid,
          'is_typing': isTyping,
          'avatar_url': myProfile['avatar_url'],
          'name': myProfile['name'] ?? myProfile['full_name'] ?? 'User',
        },
      );
    } catch (e) {
      debugPrint('Failed to send typing status: $e');
    }
  }

  void _deleteMessage(Map<String, dynamic> msg) async {
    final msgId = msg['id'] as String?;
    if (msgId == null || msgId.startsWith('temp_')) return;
    try {
      await Supabase.instance.client
          .from('rush_in_messages')
          .delete()
          .eq('id', msgId);
      
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == msgId);
        });
      }
    } catch (e) {
      debugPrint('Failed to delete message: $e');
    }
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    final isOwn = msg['user_id'] == myUid;
    final isHost = myUid == widget.hostId;
    final isTemp = msg['id'].toString().startsWith('temp_');
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0B14),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: Text('Copy Text', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: msg['text'] ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard!')),
                );
              },
            ),
            if ((isOwn || isHost) && !isTemp)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text('Delete Message', style: GoogleFonts.plusJakartaSans(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(msg);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showMembersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0B14),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final myUid = Supabase.instance.client.auth.currentUser?.id;
            final isCurrentHost = myUid == widget.hostId;

            final allUids = <String>{};
            allUids.add(widget.hostId);
            allUids.addAll(_participantStatuses.keys);
            allUids.addAll(_chatStatuses.keys);

            final uidsList = allUids.toList();

            final activeMembers = uidsList.where((uid) {
              if (uid == widget.hostId) return false;
              final reqStatus = _participantStatuses[uid];
              final chatStatus = _chatStatuses[uid];
              return (reqStatus == 'approved' || reqStatus == 'pending') &&
                  chatStatus != 'removed' &&
                  chatStatus != 'requested';
            }).toList();

            final removedMembers = uidsList.where((uid) {
              if (uid == widget.hostId) return false;
              final chatStatus = _chatStatuses[uid];
              return chatStatus == 'removed' || chatStatus == 'requested';
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chat Members',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // 1. Host Section
                          _buildSectionTitle('Host'),
                          _buildMemberItemRow(widget.hostId, isHost: true, showActions: false, setSheetState: setSheetState),
                          
                          // 2. Active Members Section
                          if (activeMembers.isNotEmpty) ...[
                            _buildSectionTitle('Active Members (${activeMembers.length})'),
                            ...activeMembers.map((uid) => _buildMemberItemRow(
                              uid,
                              isHost: false,
                              showActions: isCurrentHost,
                              setSheetState: setSheetState,
                            )),
                          ],

                          // 3. Removed/Banned Section
                          if (removedMembers.isNotEmpty) ...[
                            _buildSectionTitle('Removed / Pending Re-entry (${removedMembers.length})'),
                            ...removedMembers.map((uid) => _buildMemberItemRow(
                              uid,
                              isHost: false,
                              isRemoved: true,
                              showActions: isCurrentHost,
                              setSheetState: setSheetState,
                            )),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFFFF7A00),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMemberItemRow(
    String uid, {
    required bool isHost,
    bool isRemoved = false,
    required bool showActions,
    required StateSetter setSheetState,
  }) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getProfile(uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?['name'] ?? profile?['full_name'] ?? 'Loading...';
        final avatarUrl = profile?['avatar_url']?.toString();

        final reqStatus = _participantStatuses[uid];
        final chatStatus = _chatStatuses[uid];

        String roleLabel = 'Going';
        Color roleColor = const Color(0xFF10B981); // Green

        if (isHost) {
          roleLabel = 'Host';
          roleColor = const Color(0xFFEF4444); // Red
        } else if (isRemoved) {
          if (chatStatus == 'requested') {
            roleLabel = 'Requested Re-entry';
            roleColor = const Color(0xFFFBBF24); // Yellow
          } else {
            roleLabel = 'Removed';
            roleColor = Colors.white38;
          }
        } else if (reqStatus == 'pending') {
          roleLabel = 'Interested';
          roleColor = const Color(0xFFFBBF24); // Yellow
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? (avatarUrl.startsWith('data:')
                          ? MemoryImage(base64Decode(avatarUrl.split(',').last))
                          : NetworkImage(avatarUrl) as ImageProvider)
                      : null,
                  backgroundColor: const Color(0xFF1E1E24),
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFFF7A00),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // Name and Role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: roleColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          roleLabel,
                          style: GoogleFonts.plusJakartaSans(
                            color: roleColor.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons for host
              if (showActions) ...[
                if (isRemoved)
                  GestureDetector(
                    onTap: () async {
                      await Supabase.instance.client
                          .from('rush_in_chat_status')
                          .delete()
                          .eq('activity_id', widget.activityId)
                          .eq('user_id', uid);
                      
                      // Refresh local state and sheet state
                      await _loadChatStatuses();
                      setSheetState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        'Allow',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () async {
                      await Supabase.instance.client
                          .from('rush_in_chat_status')
                          .upsert({
                            'activity_id': widget.activityId,
                            'user_id': uid,
                            'status': 'removed',
                            'updated_at': DateTime.now().toUtc().toIso8601String(),
                          }, onConflict: 'activity_id,user_id');
                      
                      // Refresh local state and sheet state
                      await _loadChatStatuses();
                      setSheetState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        'Remove',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEF4444),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.activityTitle,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'RUSH-IN SESSION CHAT',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFFF7A00),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline, color: Colors.white70),
            onPressed: _showMembersSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Divider
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.05),
            ),
            // Message List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF7A00),
                      ),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.forum_outlined, color: Colors.white12, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white30,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Say hello to get the discussion started!',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white24,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final myUid = Supabase.instance.client.auth.currentUser?.id;
                            final isMe = msg['user_id'] == myUid;
                            final senderId = msg['user_id'].toString();

                            return FutureBuilder<Map<String, dynamic>>(
                              future: _getProfile(senderId),
                              builder: (context, snapshot) {
                                final profile = snapshot.data;
                                final senderName = profile?['name'] ?? profile?['full_name'] ?? 'User';
                                final avatarUrl = profile?['avatar_url']?.toString();

                                return _buildMessageItem(
                                  msg: msg,
                                  isMe: isMe,
                                  senderName: senderName,
                                  avatarUrl: avatarUrl,
                                  senderId: senderId,
                                );
                              },
                            );
                          },
                        ),
            ),
            // Typing Indicator
            _buildTypingIndicator(),
            // Message Input
            _buildInputSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem({
    required Map<String, dynamic> msg,
    required bool isMe,
    required String senderName,
    required String? avatarUrl,
    required String senderId,
  }) {
    final text = msg['text'] ?? '';
    final createdAtStr = msg['created_at'] != null
        ? DateTime.parse(msg['created_at']).toLocal()
        : DateTime.now();
    final timeStr = '${createdAtStr.hour}:${createdAtStr.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () {
                // Future profile navigation if needed
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? (avatarUrl.startsWith('data:')
                          ? MemoryImage(base64Decode(avatarUrl.split(',').last))
                          : NetworkImage(avatarUrl) as ImageProvider)
                      : null,
                  backgroundColor: const Color(0xFF1E1E24),
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFFF7A00),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        senderName,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getRoleColor(senderId),
                          boxShadow: [
                            BoxShadow(
                              color: _getRoleColor(senderId).withValues(alpha: 0.6),
                              blurRadius: 4,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getRoleLabel(senderId),
                        style: GoogleFonts.plusJakartaSans(
                          color: _getRoleColor(senderId).withValues(alpha: 0.8),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ] else ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getRoleColor(senderId),
                          boxShadow: [
                            BoxShadow(
                              color: _getRoleColor(senderId).withValues(alpha: 0.6),
                              blurRadius: 4,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getRoleLabel(senderId),
                        style: GoogleFonts.plusJakartaSans(
                          color: _getRoleColor(senderId).withValues(alpha: 0.8),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'You',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                GestureDetector(
                  onLongPress: () => _showMessageOptions(msg),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFFFF7A00).withValues(alpha: 0.15)
                          : const Color(0xFF1E1E24),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      border: Border.all(
                        color: isMe
                            ? const Color(0xFFFF7A00).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white30,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? (avatarUrl.startsWith('data:')
                        ? MemoryImage(base64Decode(avatarUrl.split(',').last))
                        : NetworkImage(avatarUrl) as ImageProvider)
                    : null,
                backgroundColor: const Color(0xFF1E1E24),
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFFF7A00),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E14),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: Colors.white30,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF7A00), Color(0xFFFF5E00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (_typingUsers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 24,
                width: (_typingUsers.length.clamp(1, 3) * 16.0) + 8.0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: _typingUsers.entries.take(3).map((entry) {
                    final idx = _typingUsers.keys.toList().indexOf(entry.key);
                    final avatarUrl = entry.value['avatar_url']?.toString();
                    final name = entry.value['name']?.toString() ?? 'User';

                    return Positioned(
                      left: idx * 14.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0C0E14),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 10,
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? (avatarUrl.startsWith('data:')
                                  ? MemoryImage(base64Decode(avatarUrl.split(',').last))
                                  : NetworkImage(avatarUrl) as ImageProvider)
                              : null,
                          backgroundColor: const Color(0xFF1E1E24),
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFFF7A00),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 8,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 4),
              const _TypingDotsAnimation(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingDotsAnimation extends StatefulWidget {
  const _TypingDotsAnimation();

  @override
  State<_TypingDotsAnimation> createState() => _TypingDotsAnimationState();
}

class _TypingDotsAnimationState extends State<_TypingDotsAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double delay = index * 0.2;
            final double progress = (_controller.value - delay) % 1.0;
            final double bounce = math.sin(progress * math.pi) * -4.0;
            final double scale = 0.8 + (math.sin(progress * math.pi) * 0.2);

            return Transform.translate(
              offset: Offset(0, progress < 0.5 ? bounce : 0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
