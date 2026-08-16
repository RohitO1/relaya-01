import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/doodle_theme.dart';

class ForwardBottomSheet extends StatefulWidget {
  final String contentTitle;
  final String contentUrl;
  final String? contentImageUrl;

  const ForwardBottomSheet({
    super.key,
    required this.contentTitle,
    required this.contentUrl,
    this.contentImageUrl,
  });

  @override
  State<ForwardBottomSheet> createState() => _ForwardBottomSheetState();
}

class _ForwardBottomSheetState extends State<ForwardBottomSheet> {
  final _sb = Supabase.instance.client;
  String get _uid => _sb.auth.currentUser?.id ?? '';

  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _communities = [];
  bool _loading = true;

  // Track status per target ID
  final Map<String, bool> _sentStatus = {};
  final Map<String, bool> _isSending = {};

  @override
  void initState() {
    super.initState();
    _fetchTargets();
  }

  Future<void> _fetchTargets() async {
    try {
      // 1. DMs (from requests logic)
      final reqs = await _sb
          .from('requests')
          .select('sender_id, target_id')
          .eq('status', 'approved');
      final relevantIds = <String>{};
      for (var r in reqs) {
        if (r['sender_id'] == _uid) relevantIds.add(r['target_id'].toString());
        if (r['target_id'] == _uid) relevantIds.add(r['sender_id'].toString());
      }
      relevantIds.remove(_uid);

      if (relevantIds.isNotEmpty) {
        final profiles = await _sb
            .from('profiles')
            .select('id, name, avatar_url')
            .inFilter('id', relevantIds.toList());
        _chats = List<Map<String, dynamic>>.from(profiles);
      }

      // 2. Communities
      final myCommsRes = await _sb
          .from('bolroom_community_members')
          .select(
              'community_id, bolroom_communities!inner(id, name, avatar_url)')
          .eq('user_id', _uid);

      _communities = List<Map<String, dynamic>>.from(
          myCommsRes.map((c) => c['bolroom_communities']));
    } catch (e) {
      debugPrint('Forward sheet fetch error: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send(String targetId, bool isCommunity) async {
    setState(() => _isSending[targetId] = true);

    final payload =
        '📌 Check this out: ${widget.contentTitle}\n${widget.contentUrl}'
        '${widget.contentImageUrl != null && widget.contentImageUrl!.isNotEmpty ? '\n|IMG|${widget.contentImageUrl}' : ''}';
    try {
      if (isCommunity) {
        await _sb.from('bolroom_community_messages').insert({
          'community_id': targetId,
          'sender_id': _uid,
          'text': payload,
        });
      } else {
        await _sb.from('messages').insert({
          'sender_id': _uid,
          'receiver_id': targetId,
          'text': payload,
          'is_image': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      if (mounted) setState(() => _sentStatus[targetId] = true);
    } catch (e) {
      debugPrint('Send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to forward: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending[targetId] = false);
    }
  }

  Widget _buildRow(Map<String, dynamic> data, bool isCommunity) {
    final name = data['name'] ?? 'Unknown';
    final avatar = data['avatar_url'];
    final targetId = data['id'].toString();
    final isSent = _sentStatus[targetId] == true;
    final sending = _isSending[targetId] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            backgroundColor: isCommunity
                ? const Color(0xFFFF6B00).withValues(alpha: 0.2)
                : Colors.white12,
            child: avatar == null
                ? Icon(isCommunity ? Icons.groups : Icons.person,
                    color:
                        isCommunity ? const Color(0xFFFF6B00) : Colors.white54,
                    size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(isCommunity ? 'Bolroom Community' : 'Direct Message',
                    style: GoogleFonts.outfit(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isSent ? Colors.white10 : const Color(0xFFFF6B00),
                foregroundColor: isSent ? Colors.white54 : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 0),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: (isSent || sending)
                  ? null
                  : () => _send(targetId, isCommunity),
              child: sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isSent ? 'Sent' : 'Send',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doodle = isDoodleMode(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: doodle ? DoodleColors.paper : const Color(0xFF141C2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Forward to...',
              style: GoogleFonts.outfit(
                  color: doodle ? DoodleColors.brown : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
                : (_chats.isEmpty && _communities.isEmpty)
                    ? Center(
                        child: Text('No active chats or communities.',
                            style: GoogleFonts.outfit(color: Colors.white54)))
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 40),
                        children: [
                          if (_communities.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 20, top: 10, bottom: 8),
                              child: Text('COMMUNITIES',
                                  style: GoogleFonts.outfit(
                                      color: const Color(0xFFFF6B00),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5)),
                            ),
                            ..._communities.map((c) => _buildRow(c, true)),
                            const Divider(
                                color: Colors.white10,
                                height: 24,
                                indent: 20,
                                endIndent: 20),
                          ],
                          if (_chats.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 20, top: 10, bottom: 8),
                              child: Text('DIRECT MESSAGES',
                                  style: GoogleFonts.outfit(
                                      color: const Color(0xFFFF6B00),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5)),
                            ),
                            ..._chats.map((c) => _buildRow(c, false)),
                          ]
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
