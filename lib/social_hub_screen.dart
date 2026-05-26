import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'host_activity_screen.dart';
import 'rush_in_consumer_detail_view.dart';

class SocialHubScreen extends StatefulWidget {
  final VoidCallback onBack;
  const SocialHubScreen({super.key, required this.onBack});

  @override
  State<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends State<SocialHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currentUid = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ✨ Premium Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SOCIAL HUB', 
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5,
                        color: isDark ? Colors.white : Colors.black)),
                      const Text('Join live or planned discoveries', 
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const HostActivityScreen(
                          initialLocation: LatLng(28.6139, 77.2090), 
                          initialIsRushIn: false,
                        ),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFF0077FF)]),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.3), blurRadius: 10)],
                      ),
                      child: const Icon(Icons.add, color: Colors.black, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            // ⚡ Custom Toggle
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF101015) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)
                  ],
                ),
                labelColor: const Color(0xFFFF6B00),
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'RUSH-IN LIVE'),
                  Tab(text: 'ACTIVITIES'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                   _SocialViewList(isRushIn: true, currentUid: _currentUid),
                   _SocialViewList(isRushIn: false, currentUid: _currentUid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialViewList extends StatelessWidget {
  final bool isRushIn;
  final String? currentUid;

  const _SocialViewList({required this.isRushIn, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('activities')
          .stream(primaryKey: ['id'])
          .eq('is_rush_in', isRushIn)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
        }

        final items = (snapshot.data ?? [])
            .where((i) => i['user_id'] != currentUid && i['is_active'] == true)
            .toList();

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isRushIn ? Icons.flash_off : Icons.event_busy, size: 60, color: Colors.white12),
                const SizedBox(height: 16),
                Text('No ${isRushIn ? "live rush-ins" : "activities"} nearby', 
                  style: const TextStyle(color: Colors.white30)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _SocialCard(item: item, isRushIn: isRushIn);
          },
        );
      },
    );
  }
}

class _SocialCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isRushIn;

  const _SocialCard({required this.item, required this.isRushIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF101015),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => RushInConsumerDetailView(
              activity: item,
              onInteraction: () {},
            ),
          ));
        },
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Preview Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Stack(
                children: [
                  Image.network(
                    item['preview_image'] ?? 'https://picsum.photos/seed/${item['id']}/600/300',
                    height: 180, width: double.infinity, fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(isRushIn ? Icons.flash_on : Icons.event, color: const Color(0xFFFF6B00), size: 14),
                          const SizedBox(width: 4),
                          Text(isRushIn ? 'LIVE' : 'PLANNED', 
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title'] ?? 'Untitled', 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(item['description'] ?? 'No description', 
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 14),
                      const SizedBox(width: 4),
                      Expanded(child: Text(item['location_name'] ?? 'Near you', 
                        style: const TextStyle(color: Colors.white38, fontSize: 12))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
