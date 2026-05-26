import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';

class FollowListScreen extends StatelessWidget {
  final String userId;
  final int initialIndex;

  const FollowListScreen({super.key, required this.userId, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: const Color(0xFF050508),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Network', style: TextStyle(fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFF6B00),
            labelColor: Color(0xFFFF6B00),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'FOLLOWERS'),
              Tab(text: 'FOLLOWING'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FollowListHelper(userId: userId, isFollowers: true),
            _FollowListHelper(userId: userId, isFollowers: false),
          ],
        ),
      ),
    );
  }
}

class _FollowListHelper extends StatefulWidget {
  final String userId;
  final bool isFollowers;

  const _FollowListHelper({required this.userId, required this.isFollowers});

  @override
  State<_FollowListHelper> createState() => _FollowListHelperState();
}

class _FollowListHelperState extends State<_FollowListHelper> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await Supabase.instance.client
          .from('requests')
          .select('sender_id, target_id')
          .eq('target_type', 'follow')
          .eq('status', 'approved')
          .eq(widget.isFollowers ? 'target_id' : 'sender_id', widget.userId);

      final userIds = (res as List).map((r) => widget.isFollowers ? r['sender_id'] : r['target_id']).cast<String>().toSet().toList();

      if (userIds.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final profilesRes = await Supabase.instance.client.from('profiles').select('id, name, full_name, avatar_url, bio, is_public').inFilter('id', userIds);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(profilesRes as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_alt_outlined, size: 60, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(widget.isFollowers ? 'No followers yet' : 'Not following anyone yet', style: const TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final u = _users[index];
        final id = u['id']?.toString() ?? '';
        final name = u['name'] ?? u['full_name'] ?? 'User';
        final bio = u['bio'] ?? '';
        final avatar = u['avatar_url']?.toString();

        return ListTile(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
              backgroundColor: const Color(0xFF050508),
              body: ProfileScreen(userId: id),
            )));
          },
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          leading: CircleAvatar(
            radius: 26,
            backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar == null || avatar.isEmpty ? const Icon(Icons.person) : null,
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: bio.isNotEmpty ? Text(bio, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)) : null,
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
        );
      },
    );
  }
}
