// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously
import 'dart:async';
import 'dart:math';

import '../services/notification_service.dart';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chatroom_live_screen.dart';
import '../widgets/app_header_actions.dart';

class BolroomVoiceScreen extends StatefulWidget {
  const BolroomVoiceScreen({super.key});
  @override
  State<BolroomVoiceScreen> createState() => _BolroomVoiceScreenState();
}

class _BolroomVoiceScreenState extends State<BolroomVoiceScreen> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;
  String? _customFilterLocation;

  final Map<String, List<String>> _indiaLocations = {
    // 28 States
    'Andhra Pradesh': ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Kurnool', 'Tirupati', 'Kakinada', 'Kadapa', 'Anantapur', 'Rajahmundry', 'Eluru', 'Ongole', 'Machilipatnam', 'Chittoor'],
    'Arunachal Pradesh': ['Itanagar', 'Tawang', 'Naharlagun', 'Pasighat', 'Ziro', 'Tezu', 'Bomdila', 'Aalo', 'Roing'],
    'Assam': ['Guwahati', 'Silchar', 'Dibrugarh', 'Jorhat', 'Nagaon', 'Tinsukia', 'Tezpur', 'Bongaigaon', 'Karimganj', 'Diphu', 'Sivasagar', 'Goalpara', 'Barpeta', 'Dhubri'],
    'Bihar': ['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Purnia', 'Darbhanga', 'Ara', 'Begusarai', 'Katihar', 'Munger', 'Chhapra', 'Saharsa', 'Hajipur', 'Sasaram', 'Bettiah', 'Motihari'],
    'Chhattisgarh': ['Raipur', 'Bhilai', 'Bilaspur', 'Korba', 'Rajnandgaon', 'Raigarh', 'Jagdalpur', 'Ambikapur', 'Dhamtari', 'Mahasamund', 'Durg', 'Chirmiri'],
    'Goa': ['Panaji', 'Vasco da Gama', 'Margao', 'Mapusa', 'Ponda', 'Bicholim', 'Curchorem', 'Sanquelim', 'Cuncolim'],
    'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar', 'Jamnagar', 'Junagadh', 'Gandhinagar', 'Anand', 'Navsari', 'Morbi', 'Nadiad', 'Bharuch', 'Porbandar', 'Mehsana', 'Bhuj'],
    'Haryana': ['Gurugram', 'Faridabad', 'Panipat', 'Ambala', 'Rohtak', 'Hisar', 'Karnal', 'Sonipat', 'Panchkula', 'Yamunanagar', 'Bhiwani', 'Sirsa', 'Bahadurgarh', 'Kurukshetra', 'Jind', 'Kaithal'],
    'Himachal Pradesh': ['Shimla', 'Dharamshala', 'Mandi', 'Solan', 'Kullu', 'Palampur', 'Chamba', 'Nahan', 'Una', 'Bilaspur', 'Hamirpur', 'Manali'],
    'Jharkhand': ['Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro', 'Deoghar', 'Hazaribagh', 'Phusro', 'Giridih', 'Ramgarh', 'Medininagar', 'Chirkunda', 'Dumka'],
    'Karnataka': ['Bengaluru', 'Mysuru', 'Mangaluru', 'Hubballi', 'Belagavi', 'Davangere', 'Ballari', 'Kalaburagi', 'Shivamogga', 'Tumakuru', 'Raichur', 'Bidar', 'Hospet', 'Gadag', 'Hassan', 'Udupi', 'Kolar'],
    'Kerala': ['Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur', 'Kollam', 'Alappuzha', 'Palakkad', 'Kannur', 'Kottayam', 'Manjeri', 'Thalassery', 'Ponnani', 'Kasaragod', 'Pathanamthitta'],
    'Madhya Pradesh': ['Bhopal', 'Indore', 'Gwalior', 'Jabalpur', 'Ujjain', 'Sagar', 'Dewas', 'Satna', 'Ratlam', 'Rewa', 'Murwara', 'Singrauli', 'Burhanpur', 'Khandwa', 'Morena', 'Bhind', 'Chhindwara', 'Guna'],
    'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Aurangabad', 'Solapur', 'Amravati', 'Nanded', 'Kolhapur', 'Akola', 'Jalgaon', 'Latur', 'Dhule', 'Ahmednagar', 'Chandrapur', 'Parbhani', 'Thane', 'Kalyan-Dombivli', 'Navi Mumbai', 'Vasai-Virar'],
    'Manipur': ['Imphal', 'Thoubal', 'Kakching', 'Churachandpur', 'Bishnupur', 'Ukhrul', 'Jiribam', 'Senapati'],
    'Meghalaya': ['Shillong', 'Tura', 'Nongstoin', 'Jowai', 'Williamnagar', 'Baghmara', 'Resubelpara'],
    'Mizoram': ['Aizawl', 'Lunglei', 'Saiha', 'Champhai', 'Kolasib', 'Serchhip', 'Lawngtlai'],
    'Nagaland': ['Kohima', 'Dimapur', 'Mokokchung', 'Tuensang', 'Wokha', 'Zunheboto', 'Kiphire', 'Phek'],
    'Odisha': ['Bhubaneswar', 'Cuttack', 'Rourkela', 'Brahmapur', 'Sambalpur', 'Puri', 'Balasore', 'Bhadrak', 'Baripada', 'Jharsuguda', 'Bargarh', 'Rayagada', 'Koraput', 'Angul'],
    'Punjab': ['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda', 'Hoshiarpur', 'Mohali', 'Batala', 'Pathankot', 'Moga', 'Abohar', 'Malerkotla', 'Khanna', 'Phagwara', 'Muktsar', 'Faridkot'],
    'Rajasthan': ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Bikaner', 'Ajmer', 'Bhilwara', 'Alwar', 'Bharatpur', 'Sikar', 'Pali', 'Sri Ganganagar', 'Kishangarh', 'Baran', 'Tonk', 'Hanumangarh', 'Beawar'],
    'Sikkim': ['Gangtok', 'Namchi', 'Gyalshing', 'Mangan', 'Singtam', 'Rangpo', 'Jorethang'],
    'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem', 'Tirunelveli', 'Tiruppur', 'Erode', 'Vellore', 'Thoothukudi', 'Dindigul', 'Thanjavur', 'Ranipet', 'Sivakasi', 'Karur', 'Ooty', 'Hosur', 'Nagercoil', 'Kanchipuram'],
    'Telangana': ['Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar', 'Khammam', 'Ramagundam', 'Mahbubnagar', 'Nalgonda', 'Adilabad', 'Suryapet', 'Miryalaguda', 'Jagtial'],
    'Tripura': ['Agartala', 'Udaipur', 'Dharmanagar', 'Kailashahar', 'Belonia', 'Khowai', 'Bishalgarh', 'Ambassa'],
    'Uttar Pradesh': ['Lucknow', 'Kanpur', 'Ghaziabad', 'Agra', 'Varanasi', 'Meerut', 'Prayagraj', 'Bareilly', 'Aligarh', 'Moradabad', 'Saharanpur', 'Gorakhpur', 'Noida', 'Firozabad', 'Jhansi', 'Muzaffarnagar', 'Mathura', 'Ayodhya', 'Rampur', 'Shahjahanpur'],
    'Uttarakhand': ['Dehradun', 'Haridwar', 'Roorkee', 'Haldwani', 'Rudrapur', 'Kashipur', 'Rishikesh', 'Mussoorie', 'Nainital', 'Almora', 'Pithoragarh'],
    'West Bengal': ['Kolkata', 'Howrah', 'Darjeeling', 'Siliguri', 'Asansol', 'Durgapur', 'Bardhaman', 'English Bazar', 'Baharampur', 'Habra', 'Kharagpur', 'Shantipur', 'Dankuni', 'Haldia', 'Jalpaiguri', 'Kalyani', 'Raiganj'],
    
    // 8 Union Territories
    'Andaman and Nicobar Islands': ['Port Blair', 'Garacharma', 'Bambooflat', 'Prothrapur'],
    'Chandigarh': ['Chandigarh'],
    'Dadra and Nagar Haveli and Daman and Diu': ['Daman', 'Diu', 'Silvassa', 'Amli'],
    'Delhi': ['New Delhi', 'North Delhi', 'South Delhi', 'East Delhi', 'West Delhi', 'Central Delhi', 'Shahdara', 'Rohini', 'Dwarka', 'Chanakyapuri', 'Connaught Place'],
    'Jammu and Kashmir': ['Srinagar', 'Jammu', 'Anantnag', 'Baramulla', 'Kathua', 'Sopore', 'Bandipora', 'Poonch', 'Kupwara', 'Udhampur', 'Pulwama'],
    'Ladakh': ['Leh', 'Kargil'],
    'Lakshadweep': ['Kavaratti', 'Minicoy', 'Andrott', 'Amini', 'Agatti'],
    'Puducherry': ['Puducherry', 'Ozhukarai', 'Karaikal', 'Yanam', 'Mahe']
  };
  
  int _selectedFilter = 0;
  final List<String> _filters = ["All", "Trending", "Music", "Gaming", "Talk", "Study"];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  String _myLocation = 'Fetching location...';

  static const Color bgColor = Color(0xFF090710);
  static const Color cardColor = Color(0xFF13101E);
  static const Color borderColor = Color(0xFF231D38);
  static const Color purplePrimary = Color(0xFFB983FF);
  static const Color purpleDark = Color(0xFF7B2CBF);
  static const Color textMuted = Color(0xFF8E8B99);
  static const Color cyanBright = Color(0xFFFF6B00);

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _loadRooms();
    _sb.channel('bolroom_voice_rooms').onPostgresChanges(
      event: PostgresChangeEvent.all, schema: 'public', table: 'chatrooms',
      callback: (_) => _loadRooms(),
    ).subscribe();
  }

  @override
  void dispose() {
    try { _sb.removeChannel(_sb.channel('bolroom_voice_rooms')); } catch (_) {}
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      final myId = _sb.auth.currentUser?.id;
      final res = await _sb.from('chatrooms')
          .select('*')
          .or('visibility.neq.invite,host_id.eq.$myId')
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) setState(() { _rooms = List<Map<String, dynamic>>.from(res); _loading = false; });
    } catch (e) {
      debugPrint('Load rooms: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loc = prefs.getString('bolroom_location');
      if (mounted) {
        setState(() {
          _myLocation = (loc != null && loc.trim().isNotEmpty) ? loc : 'Global';
        });
      }
    } catch (e) {
      debugPrint('Prefs location fetch error: $e');
      if (mounted) setState(() => _myLocation = 'Global');
    }
  }

  void _joinRoom(Map<String, dynamic> room) {
    HapticFeedback.lightImpact();
    BolRoomManager.openRoom(context,
      roomId: room['id'].toString(), roomName: room['name'] ?? 'Untitled', topic: room['topic'] ?? 'General',
      hostId: room['host_id']?.toString() ?? '', hostName: room['host_name'] ?? 'Host',
    );
  }

  Color _getAuraColor(String hostId) {
    // Generate a consistent pseudo-random neon color based on host ID
    final colors = [
      const Color(0xFFFF6B00),
      const Color(0xFFFF00FF),
      const Color(0xFF8A2BE2),
      const Color(0xFFFF4655),
      const Color(0xFF00FF00),
      const Color(0xFFF7931A),
    ];
    int hash = hostId.hashCode;
    return colors[hash.abs() % colors.length];
  }

  List<String> _getTags(dynamic topicStr) {
    if (topicStr == null) return ['General'];
    final p = topicStr.toString().split('|');
    return p.map((e) => e.trim()).where((e) => e.isNotEmpty && !e.toLowerCase().contains('could not')).take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    List<Map<String, dynamic>> filteredRooms = _rooms;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredRooms = filteredRooms.where((r) {
        final name = (r['name'] ?? '').toString().toLowerCase();
        final topic = (r['topic'] ?? '').toString().toLowerCase();
        final tags = (r['tags'] ?? '').toString().toLowerCase();
        return name.contains(q) || topic.contains(q) || tags.contains(q);
      }).toList();
    }

    // Tag filter
    if (_selectedFilter > 0) {
      final tag = _filters[_selectedFilter].toLowerCase();
      filteredRooms = filteredRooms.where((r) {
        final topic = (r['topic'] ?? '').toString().toLowerCase();
        final tags = (r['tags'] ?? '').toString().toLowerCase();
        return topic.contains(tag) || tags.contains(tag);
      }).toList();
    }

    if (_customFilterLocation != null) {
      filteredRooms = filteredRooms.where((r) => r['topic'].toString().toLowerCase().contains(_customFilterLocation!.toLowerCase())).toList();
    }

    final live = filteredRooms.where((r) => r['scheduled_at'] == null || DateTime.tryParse(r['scheduled_at']?.toString() ?? '')?.isBefore(now) == true).toList();
    final scheduled = filteredRooms.where((r) {
      if (r['scheduled_at'] == null) return false;
      final t = DateTime.tryParse(r['scheduled_at'].toString());
      return t != null && t.isAfter(now);
    }).toList();

    return SafeArea(
      child: _loading
        ? const Center(child: CircularProgressIndicator(color: purplePrimary, strokeWidth: 2))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader("VoiceRoom", Icons.add_circle, onAction: () => _showCreateRoomSheet(context)),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search rooms by title or tag...',
                    hintStyle: const TextStyle(color: textMuted, fontSize: 13),
                    filled: true, fillColor: cardColor,
                    prefixIcon: const Icon(Icons.search, color: textMuted, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty ? IconButton(
                      onPressed: () => setState(() { _searchCtrl.clear(); _searchQuery = ''; }),
                      icon: const Icon(Icons.close, color: textMuted, size: 18),
                    ) : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),

              // Return to Room banner
              if (BolRoomManager.hasActiveRoom)
                GestureDetector(
                  onTap: () => BolRoomManager.maximizeRoom(context),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [purpleDark.withValues(alpha: 0.4), cyanBright.withValues(alpha: 0.15)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cyanBright.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Return to active room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                      const Icon(Icons.arrow_forward_ios, color: cyanBright, size: 14),
                    ]),
                  ),
                ),
              
              // Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: List.generate(_filters.length, (index) {
                    bool isSelected = _selectedFilter == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedFilter = index),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? purpleDark.withValues(alpha: 0.3) : cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? purplePrimary : borderColor),
                        ),
                        child: Row(
                          children: [
                            if (index == 1) ...[
                              Icon(Icons.radar, size: 14, color: isSelected ? cyanBright : textMuted),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _filters[index],
                              style: TextStyle(
                                color: isSelected ? Colors.white : textMuted,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Active Orbits", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () => _showLocationSelector(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cyanBright.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cyanBright.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, color: cyanBright, size: 14),
                                const SizedBox(width: 4),
                                Text(_customFilterLocation ?? 'Global', style: const TextStyle(color: cyanBright, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (live.isNotEmpty) ...[
                      ...live.map((r) => _buildLiveRoomCard(
                        room: r,
                        title: r['name'] ?? 'Untitled Echo',
                        host: r['host_name'] ?? 'Anonymous Host',
                        listeners: "${r['member_count'] ?? 1}",
                        tags: _getTags(r['topic']),
                        auraColor: _getAuraColor(r['host_id']?.toString() ?? ''),
                      )),
                      const SizedBox(height: 24),
                    ] else ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text("No Active Orbits found in this frequency.", style: TextStyle(color: textMuted)),
                        ),
                      ),
                    ],

                    if (scheduled.isNotEmpty) ...[
                      const Text("Scheduled Rooms", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...scheduled.map((r) {
                        final t = DateTime.tryParse(r['scheduled_at'].toString())?.toLocal();
                        String timeStr = 'Later';
                        if (t != null) {
                          final diff = t.difference(DateTime.now());
                          if (diff.inHours > 0) {
                            timeStr = 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
                          } else if (diff.inMinutes > 0) {
                            timeStr = 'Starts in ${diff.inMinutes}m';
                          } else {
                            timeStr = 'Starting soon';
                          }
                        }
                        return _buildScheduledRoom(
                          r,
                          r['name'] ?? 'Scheduled Room',
                          timeStr,
                          _getAuraColor(r['host_id']?.toString() ?? ''),
                        );
                      }),
                      const SizedBox(height: 80),
                    ]
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildHeader(String title, IconData actionIcon, {VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [BoxShadow(color: purplePrimary.withValues(alpha: 0.2), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                ),
              ),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
          Row(
            children: [
              AppHeaderActions(
                containerColor: cardColor,
                iconColor: purplePrimary,
                borderColor: Colors.white.withValues(alpha: 0.3),
                showMessages: false,
                isBolroomMode: true,
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    boxShadow: [BoxShadow(color: purplePrimary.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1)],
                  ),
                  child: Icon(actionIcon, color: purplePrimary, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveRoomCard({
    required Map<String, dynamic> room,
    required String title,
    required String host,
    required String listeners,
    required List<String> tags,
    required Color auraColor,
  }) {
    final maxP = room['max_participants'] as int? ?? 0;
    final count = room['member_count'] as int? ?? 1;
    final isFull = maxP > 0 && count >= maxP;

    return GestureDetector(
      onTap: () {
        if (isFull) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Room is full'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
          return;
        }
        _joinRoom(room);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: auraColor.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: auraColor.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3))),
                const SizedBox(width: 8),
                if (isFull)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5))),
                    child: const Text('Full', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else
                  _buildAudioVisualizer(auraColor),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildGlowingAvatar(auraColor, 32),
                const SizedBox(width: 8),
                Expanded(child: Text("Host: $host", style: const TextStyle(color: textMuted, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF1A132F), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.headphones, color: purplePrimary, size: 12),
                    const SizedBox(width: 4),
                    Text(listeners, style: const TextStyle(color: purplePrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Wrap(
                  spacing: 8,
                  children: tags.map((t) => Text("#$t", style: TextStyle(color: auraColor.withValues(alpha: 0.7), fontSize: 12))).toList(),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isFull ? Colors.white10 : auraColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isFull ? Colors.white24 : auraColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(isFull ? 'Full' : 'Join', style: TextStyle(color: isFull ? Colors.white38 : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledRoom(Map<String, dynamic> room, String title, String time, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.3), shape: BoxShape.circle),
            child: Icon(Icons.schedule, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Scheduled', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(time, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final myId = _sb.auth.currentUser?.id;
              if (myId == null) return;
              final roomId = room['id']?.toString() ?? '';
              try {
                await _sb.from('chatroom_reminders').upsert({
                  'room_id': roomId,
                  'user_id': myId,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('You\'ll be reminded 5 min before start'),
                    backgroundColor: Color(0xFF7B2CBF), behavior: SnackBarBehavior.floating));
                }
              } catch (_) {}
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.notifications_active, color: color, size: 14),
                const SizedBox(width: 4),
                Text('Remind Me', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationSelector() {
    String searchQuery = '';
    String? selectedState;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          List<String> displayItems = [];
          
          if (searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            _indiaLocations.forEach((state, cities) {
              if (state.toLowerCase().contains(query) && !displayItems.contains(state)) displayItems.add(state);
              for (var city in cities) {
                if (city.toLowerCase().contains(query) && !displayItems.contains(city)) displayItems.add(city);
              }
            });
          } else if (selectedState != null) {
            displayItems = ['All of $selectedState', ...(_indiaLocations[selectedState] ?? [])];
          } else {
            displayItems = _indiaLocations.keys.toList();
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (selectedState != null && searchQuery.isEmpty)
                      GestureDetector(
                        onTap: () => setSheetState(() => selectedState = null),
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      )
                    else
                      const Icon(Icons.location_on, color: cyanBright),
                    Text(
                      selectedState != null && searchQuery.isEmpty ? selectedState! : 'Select Location',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _customFilterLocation = null);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Global', style: TextStyle(color: cyanBright, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  onChanged: (v) => setSheetState(() => searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search State or City...',
                    hintStyle: const TextStyle(color: textMuted),
                    filled: true,
                    fillColor: bgColor,
                    prefixIcon: const Icon(Icons.search, color: textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: displayItems.length,
                    itemBuilder: (ctx, i) {
                      final item = displayItems[i];
                      final isState = _indiaLocations.containsKey(item);
                      final isAll = item.startsWith('All of ');
                      return ListTile(
                        title: Text(item, style: TextStyle(color: isAll ? cyanBright : Colors.white, fontWeight: isAll ? FontWeight.bold : FontWeight.normal)),
                        trailing: (isState && searchQuery.isEmpty) ? const Icon(Icons.chevron_right, color: textMuted) : null,
                        onTap: () {
                          if (isAll) {
                            setState(() => _customFilterLocation = selectedState);
                            Navigator.pop(ctx);
                          } else if (isState && searchQuery.isEmpty) {
                            setSheetState(() => selectedState = item);
                          } else {
                            setState(() => _customFilterLocation = item);
                            Navigator.pop(ctx);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreateRoomSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    bool hostAsGhost = true;
    bool encryptRadar = true;
    bool isRecording = false;
    bool isScheduled = false;
    String? gameMode;
    DateTime? scheduledTime;
    String visibility = 'public'; // 'public', 'friends', 'invite'
    int maxParticipants = 0; // 0 = unlimited
    final List<String> tagOptions = ['Music', 'Gaming', 'Talk', 'Chill', 'Study', 'Debate', 'Language', 'News'];
    final Set<String> selectedTags = {};
    final List<int> participantOptions = [10, 50, 100, 500, 0];
    String participantLabel(int v) => v == 0 ? 'Unlimited' : '$v';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scroll) => SingleChildScrollView(
              controller: scroll,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
                left: 24, right: 24, top: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 20),
                  const Text('Create Room', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Set up your live audio space', style: TextStyle(color: textMuted, fontSize: 13)),
                  const SizedBox(height: 24),

                  // Title (required)
                  const Text('Room Title *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleCtrl,
                    maxLength: 60,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'What\'s the vibe?',
                      hintStyle: const TextStyle(color: textMuted),
                      filled: true, fillColor: bgColor,
                      counterStyle: const TextStyle(color: textMuted, fontSize: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Topic / Description (optional)
                  const Text('Topic / Description', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: topicCtrl,
                    maxLength: 120,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Brief description (optional)',
                      hintStyle: const TextStyle(color: textMuted),
                      filled: true, fillColor: bgColor,
                      counterStyle: const TextStyle(color: textMuted, fontSize: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tags (multi-select chips)
                  const Text('Tags', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: tagOptions.map((tag) {
                      final selected = selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () => setSheetState(() {
                          if (selected) { selectedTags.remove(tag); }
                          else { selectedTags.add(tag); }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? purpleDark.withValues(alpha: 0.4) : bgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selected ? purplePrimary : borderColor),
                          ),
                          child: Text(tag, style: TextStyle(color: selected ? Colors.white : textMuted, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Visibility
                  const Text('Visibility', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _visibilityChip('Public', Icons.public, visibility == 'public', () => setSheetState(() => visibility = 'public')),
                      const SizedBox(width: 8),
                      _visibilityChip('Friends', Icons.people, visibility == 'friends', () => setSheetState(() => visibility = 'friends')),
                      const SizedBox(width: 8),
                      _visibilityChip('Invite', Icons.lock_outline, visibility == 'invite', () => setSheetState(() => visibility = 'invite')),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Max Participants
                  const Text('Max Participants', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: participantOptions.map((opt) {
                        final selected = maxParticipants == opt;
                        return GestureDetector(
                          onTap: () => setSheetState(() => maxParticipants = opt),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? cyanBright.withValues(alpha: 0.2) : bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selected ? cyanBright : borderColor),
                            ),
                            child: Text(participantLabel(opt), style: TextStyle(color: selected ? cyanBright : textMuted, fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Game Mode
                  const Text('Game Mode', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setSheetState(() => gameMode = null),
                          child: Container(
                            width: 110,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: gameMode == null ? cyanBright.withValues(alpha: 0.2) : bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: gameMode == null ? cyanBright : borderColor),
                            ),
                            child: Center(child: Text('💬 None', style: TextStyle(color: gameMode == null ? cyanBright : textMuted, fontSize: 13, fontWeight: gameMode == null ? FontWeight.bold : FontWeight.normal))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setSheetState(() => gameMode = 'truth_dare'),
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: gameMode == 'truth_dare' ? cyanBright.withValues(alpha: 0.2) : bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: gameMode == 'truth_dare' ? cyanBright : borderColor),
                              boxShadow: gameMode == 'truth_dare' ? [BoxShadow(color: cyanBright.withValues(alpha: 0.2), blurRadius: 10)] : [],
                            ),
                            child: Center(child: Text('🍾 Truth or Dare', style: TextStyle(color: gameMode == 'truth_dare' ? cyanBright : textMuted, fontSize: 13, fontWeight: gameMode == 'truth_dare' ? FontWeight.bold : FontWeight.normal))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setSheetState(() => gameMode = 'two_truths'),
                          child: Container(
                            width: 150,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: gameMode == 'two_truths' ? cyanBright.withValues(alpha: 0.2) : bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: gameMode == 'two_truths' ? cyanBright : borderColor),
                              boxShadow: gameMode == 'two_truths' ? [BoxShadow(color: cyanBright.withValues(alpha: 0.2), blurRadius: 10)] : [],
                            ),
                            child: Center(child: Text('🎭 Two Truths, One Lie', style: TextStyle(color: gameMode == 'two_truths' ? cyanBright : textMuted, fontSize: 13, fontWeight: gameMode == 'two_truths' ? FontWeight.bold : FontWeight.normal))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setSheetState(() => gameMode = 'blind_date'),
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: gameMode == 'blind_date' ? cyanBright.withValues(alpha: 0.2) : bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: gameMode == 'blind_date' ? cyanBright : borderColor),
                              boxShadow: gameMode == 'blind_date' ? [BoxShadow(color: cyanBright.withValues(alpha: 0.2), blurRadius: 10)] : [],
                            ),
                            child: Center(child: Text('🔥 Blind Date', style: TextStyle(color: gameMode == 'blind_date' ? cyanBright : textMuted, fontSize: 13, fontWeight: gameMode == 'blind_date' ? FontWeight.bold : FontWeight.normal))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle switches
                  SwitchListTile(
                    title: const Text('Host as Ghost (Anonymity)', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Hides your real identity', style: TextStyle(color: textMuted, fontSize: 12)),
                    value: hostAsGhost,
                    onChanged: (v) => setSheetState(() => hostAsGhost = v),
                    activeThumbColor: purplePrimary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Share Local Region', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Nearby users can find you', style: TextStyle(color: textMuted, fontSize: 12)),
                    value: encryptRadar,
                    onChanged: (v) => setSheetState(() => encryptRadar = v),
                    activeThumbColor: cyanBright,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Enable Recording', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('All participants see a consent banner', style: TextStyle(color: textMuted, fontSize: 12)),
                    value: isRecording,
                    onChanged: (v) => setSheetState(() => isRecording = v),
                    activeThumbColor: Colors.redAccent,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Schedule for Later', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(
                      isScheduled && scheduledTime != null
                          ? 'Scheduled: ${scheduledTime!.day}/${scheduledTime!.month} at ${scheduledTime!.hour}:${scheduledTime!.minute.toString().padLeft(2, '0')}'
                          : 'Go live immediately',
                      style: const TextStyle(color: textMuted, fontSize: 12),
                    ),
                    value: isScheduled,
                    onChanged: (v) async {
                      if (v) {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(hours: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                          if (time != null) {
                            setSheetState(() {
                              isScheduled = true;
                              scheduledTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      } else {
                        setSheetState(() { isScheduled = false; scheduledTime = null; });
                      }
                    },
                    activeThumbColor: purplePrimary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  // Go Live / Schedule button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isScheduled ? purpleDark : const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final name = titleCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Room title is required'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
                          );
                          return;
                        }

                        final myId = _sb.auth.currentUser?.id;
                        if (myId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login first')));
                          return;
                        }

                        String hostName = 'Host';
                        String? hostAvatar;
                        if (hostAsGhost) {
                          hostName = 'Ghost_${myId.length > 4 ? myId.substring(0, 4) : "Anon"}';
                        } else {
                          final profile = await _sb.from('profiles').select('full_name, avatar_url').eq('id', myId).maybeSingle();
                          if (profile != null) {
                            if (profile['full_name'] != null) hostName = profile['full_name'];
                            hostAvatar = profile['avatar_url']?.toString();
                          }
                        }

                        String topic = topicCtrl.text.trim();
                        if (topic.isEmpty) topic = selectedTags.isNotEmpty ? selectedTags.join(' | ') : 'General';
                        if (encryptRadar) topic += ' | $_myLocation';

                        try {
                          final res = await _sb.from('chatrooms').insert({
                            'name': name,
                            'host_id': myId,
                            'host_name': hostName,
                            'host_avatar': hostAvatar,
                            'topic': topic,
                            'speak_permission': 'everyone',
                            'is_recording': isRecording,
                            'game_mode': gameMode,
                            'visibility': visibility,
                            'max_participants': maxParticipants,
                            'room_status': isScheduled ? 'scheduled' : 'active',
                            'scheduled_at': scheduledTime?.toUtc().toIso8601String(),
                            'created_at': DateTime.now().toUtc().toIso8601String(),
                          }).select().single();

                          // Update bolroom profile hosted count
                          try {
                            final p = await _sb.from('bolroom_profiles').select('rooms_hosted').eq('id', myId).maybeSingle();
                            if (p == null) {
                              await _sb.from('bolroom_profiles').upsert({'id': myId, 'anon_name': hostName, 'rooms_hosted': 1});
                            } else {
                              await _sb.from('bolroom_profiles').update({'rooms_hosted': (p['rooms_hosted'] ?? 0) + 1}).eq('id', myId);
                            }
                          } catch (_) {}
                          
                          // Notify followers/followings
                          if (!isScheduled) {
                            try {
                              final reqs = await _sb.from('requests').select('sender_id, target_id').eq('target_type', 'follow').eq('status', 'approved').or('sender_id.eq.$myId,target_id.eq.$myId');
                              
                              final Set<String> usersToNotify = {};
                              for (var r in (reqs as List)) {
                                final sId = r['sender_id']?.toString();
                                final tId = r['target_id']?.toString();
                                if (sId != null && sId != myId) usersToNotify.add(sId);
                                if (tId != null && tId != myId) usersToNotify.add(tId);
                              }
                              
                              for (var uId in usersToNotify) {
                                NotificationService.sendNotification(
                                  userId: uId,
                                  type: NotificationType.system,
                                  title: '$hostName is Live! 🎙️',
                                  body: 'Hop in to BolRoom: $name',
                                  payload: {'bolroom_live': true, 'room_id': res['id'].toString()},
                                );
                              }
                            } catch (_) {}
                          }

                          _loadRooms();
                          Navigator.pop(ctx);
                          if (!isScheduled) _joinRoom(res);
                        } catch (e) {
                          debugPrint('Create room error: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
                          }
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isScheduled ? Icons.schedule : Icons.cell_tower, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            isScheduled ? 'Schedule Room' : 'Go Live 🔴',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _visibilityChip(String label, IconData icon, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? purpleDark.withValues(alpha: 0.3) : bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? purplePrimary : borderColor),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? purplePrimary : textMuted, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: selected ? Colors.white : textMuted, fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlowingAvatar(Color glowColor, double size, {bool isPulsing = false}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [glowColor, purpleDark, glowColor]),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.3),
            blurRadius: isPulsing ? 25 : 15,
            spreadRadius: isPulsing ? 5 : 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: bgColor),
          child: CircleAvatar(
            backgroundColor: cardColor,
            child: Icon(Icons.person, color: Colors.white30, size: size * 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioVisualizer(Color color) {
    final random = Random();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 3,
          height: 10.0 + random.nextInt(15),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: color, blurRadius: 4)],
          ),
        );
      }),
    );
  }
}
