import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'knock_review_screen.dart';
import 'services/doodle_theme.dart';

class KnocksListScreen extends StatefulWidget {
  const KnocksListScreen({super.key});

  @override
  State<KnocksListScreen> createState() => _KnocksListScreenState();
}

class _KnocksListScreenState extends State<KnocksListScreen> {
  final _uid = Supabase.instance.client.auth.currentUser?.id;
  bool _isLoading = true;
  List<Map<String, dynamic>> _knocks = [];
  final Map<String, Map<String, dynamic>> _sendersCache = {};

  @override
  void initState() {
    super.initState();
    _fetchKnocks();
  }

  Future<void> _fetchKnocks() async {
    if (_uid == null) return;
    setState(() => _isLoading = true);

    try {
      final res = await Supabase.instance.client
          .from('requests')
          .select()
          .eq('target_id', _uid!)
          .eq('status', 'pending')
          .eq('target_type', 'profile')
          .order('created_at', ascending: false);

      final knocks = List<Map<String, dynamic>>.from(res);

      for (var knock in knocks) {
        final senderId = knock['sender_id'];
        if (senderId != null && !_sendersCache.containsKey(senderId)) {
          final profileData = await Supabase.instance.client
              .from('profiles')
              .select('name, full_name, avatar_url, age, city')
              .eq('id', senderId)
              .maybeSingle();
          if (profileData != null) {
            _sendersCache[senderId] = profileData;
          }
        }
      }

      if (mounted) {
        setState(() {
          _knocks = knocks;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching knocks: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDoodleMode(context) ? DoodleColors.cream : const Color(0xFF07070F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Knock Requests',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : _knocks.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFFFF6B00),
                  backgroundColor: const Color(0xFF10101C),
                  onRefresh: _fetchKnocks,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _knocks.length,
                    itemBuilder: (context, index) {
                      final knock = _knocks[index];
                      return _buildKnockCard(knock);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF10101C),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: const Icon(Icons.door_front_door_outlined, color: Colors.white38, size: 64),
          ),
          const SizedBox(height: 24),
          Text(
            'No Pending Knocks',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When someone knocks your profile,\nit will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnockCard(Map<String, dynamic> knock) {
    final senderId = knock['sender_id'];
    final isSuper = knock['is_super'] == true;
    final profile = _sendersCache[senderId] ?? {};
    
    final name = profile['name'] ?? profile['full_name'] ?? 'Someone';
    final avatar = profile['avatar_url']?.toString() ?? '';
    final age = (profile['age'] as num?)?.toInt() ?? 0;
    final city = profile['city']?.toString() ?? 'Unknown Location';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => KnockReviewScreen(
              knockRequest: knock,
              senderProfile: profile,
            ),
          ),
        );
        // Refresh after returning in case it was accepted/declined
        _fetchKnocks();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF10101C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSuper ? const Color(0xFFFFB300).withValues(alpha: 0.3) : Colors.white10,
            width: isSuper ? 1.5 : 1.0,
          ),
          boxShadow: isSuper
              ? [BoxShadow(color: const Color(0xFFFFB300).withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 1)]
              : [],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF20202C),
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.white54) : null,
                ),
                if (isSuper)
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10101C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt, color: Color(0xFFFFB300), size: 16),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$name${age > 0 ? ', $age' : ''}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSuper)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Super Knock',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFFB300),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white54, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          city,
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to review knock',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFF6B00),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
