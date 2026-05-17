const fs = require('fs');
let code = fs.readFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', 'utf8');

// 1. Add _approvedRushInIds state
code = code.replace(
    'List<dynamic> _requestedRushInIds = [];',
    'List<dynamic> _requestedRushInIds = [];\n  List<dynamic> _approvedRushInIds = [];'
);

// 2. Update _fetchRequestedIds
code = code.replace(
    /Future<void> _fetchRequestedIds\(\) async \{[\s\S]*?\.select\('target_id'\)[\s\S]*?setState\(\(\) \{[\s\S]*?_requestedRushInIds = \(response as List\)\.map\(\(e\) => e\['target_id'\]\)\.toList\(\);[\s\S]*?\}\);[\s\S]*?\} catch \(e\) \{/,
    `Future<void> _fetchRequestedIds() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('requests')
          .select('target_id, status')
          .eq('sender_id', uid)
          .eq('target_type', 'activity');
          
      if (mounted) {
        setState(() {
          _requestedRushInIds = (response as List).map((e) => e['target_id']).toList();
          _approvedRushInIds = (response as List).where((e) => e['status'] == 'approved').map((e) => e['target_id']).toList();
        });
      }
    } catch (e) {`
);

// 3. Update liveActs filter to allow approved Rush-Ins into the feed data
code = code.replace(
    `if (act['is_rush_in'] == true) return false;`,
    `if (act['is_rush_in'] == true && !_approvedRushInIds.contains(act['id'].toString())) return false;`
);

// 4. Update _buildListView to explicitly exclude Rush-Ins so they visually appear ONLY on the map
code = code.replace(
    `Widget _buildListView(List<Map<String, dynamic>> liveActivities) {`,
    `Widget _buildListView(List<Map<String, dynamic>> liveActivities) {
    final listActs = liveActivities.where((act) => act['is_rush_in'] != true).toList();`
);
code = code.replace(
    `...liveActivities.map((act) => _buildMapLiveCard(act)).toList(),`,
    `...listActs.map((act) => _buildMapLiveCard(act)).toList(),`
);
code = code.replace(
    `if (liveActivities.isEmpty)`,
    `if (listActs.isEmpty)`
);

// 5. Update _buildFlutterMap so it passes the approved rush ins down through the activity map marker
code = code.replace(
    `.where((act) => act['is_rush_in'] != true)`,
    `` // Remove the hard block on flutter map because we do want them plotted!
);

code = code.replace(
    `: _StandardActivityMarker(color: const Color(0xFF101015), icon: Icons.maps_ugc_rounded, userId: null),`,
    `? _SparkingRushInMarker(userId: act['user_id']?.toString())
          : _StandardActivityMarker(color: const Color(0xFF101015), icon: Icons.maps_ugc_rounded, userId: null),`
);

// 6. Append _SparkingRushInMarker definition to end of file
const sparkingClass = `
class _SparkingRushInMarker extends StatefulWidget {
  final String? userId;
  const _SparkingRushInMarker({this.userId});
  @override
  State<_SparkingRushInMarker> createState() => _SparkingRushInMarkerState();
}

class _SparkingRushInMarkerState extends State<_SparkingRushInMarker> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 35 + (20 * _ctrl.value), height: 35 + (20 * _ctrl.value),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF4081).withOpacity(0.3 * (1 - _ctrl.value)), blurRadius: 20, spreadRadius: 10),
                BoxShadow(color: Colors.amberAccent.withOpacity(0.4 * (1 - _ctrl.value)), blurRadius: 40, spreadRadius: 5),
              ]
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF101015),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFFFF4081).withOpacity(0.6), blurRadius: 15)],
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: widget.userId != null ? NetworkImage('https://picsum.photos/seed/\${widget.userId}/100') : null,
              backgroundColor: const Color(0xFF101015),
              child: widget.userId == null ? const Icon(Icons.bolt, color: Colors.amberAccent, size: 18) : null,
            ),
          ),
          const Positioned(
            bottom: -5,
            child: Icon(Icons.keyboard_arrow_down, color: Color(0xFFFF4081), size: 16),
          )
        ],
      )
    );
  }
}
`;

if (!code.includes('class _SparkingRushInMarker')) {
    code += sparkingClass;
}

fs.writeFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', code, 'utf8');
console.log('Script injected Rush-In mapping logic.');
