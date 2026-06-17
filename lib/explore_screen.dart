// ignore_for_file: avoid_print, unused_local_variable, unused_element, unused_field, use_build_context_synchronously

import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'widgets/location_picker_sheet.dart';
import 'widgets/skeleton_loaders.dart';

import 'utils/constants.dart';
import 'messages_screen.dart';

List<String> _parseListExplore(dynamic data) {
  if (data == null) return [];
  if (data is List) return data.map((e) => e.toString()).toList();
  if (data is String) {
    if (data.startsWith('[')) {
      try {
        final l = jsonDecode(data) as List;
        return l.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [data];
  }
  return [];
}

ImageProvider _getSafeImageProvider(String url) {
  if (url.startsWith('data:image')) {
    final b64 = url.split(',').last;
    return MemoryImage(base64Decode(b64));
  }
  return NetworkImage(url);
}

// ─────────────────────────────────────────────────────────────────────────────
// INTEREST PRESET QUESTION BANK  (~10 per interest)
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, List<Map<String, Object>>> _kInterestQuestions = {
  'Photography': [
    {'question': 'Film or digital — which do you swear by?', 'options': ['Film all the way', 'Digital for convenience', 'Both for different vibes', 'I just use my phone!'], 'allow_custom_answer': true},
    {'question': 'Street photography or portraits — what pulls you more?', 'options': ['Raw street moments', 'Posed artistic portraits', 'Landscapes & Nature', 'A little bit of everything'], 'allow_custom_answer': true},
    {'question': 'Golden hour or blue hour — pick one forever.', 'options': ['Golden hour glow', 'Moody blue hour', 'Harsh midday sun', 'Studio lighting'], 'allow_custom_answer': true},
    {'question': 'Do you edit minimally or go all-out in post?', 'options': ['Keep it natural', 'Heavy stylized edits', 'Black & white only', 'Depends on the shot'], 'allow_custom_answer': true},
    {'question': 'What camera gear would you take to a desert island?', 'options': ['My trusty DSLR/Mirrorless', 'A polaroid for memories', 'A vintage film camera', 'Just my smartphone'], 'allow_custom_answer': true},
  ],
  'Music': [
    {'question': 'Live concert or studio album — which experience wins?', 'options': ['The energy of a live show', 'The perfection of a studio album', 'A cozy acoustic set', 'Vinyl records at home'], 'allow_custom_answer': true},
    {'question': 'What genre do you listen to that surprises people?', 'options': ['Heavy Metal / Hard Rock', 'Classical / Jazz', 'Indie / Underground', 'Guilty pleasure pop'], 'allow_custom_answer': true},
    {'question': 'Lyrics-first or vibes-first listener?', 'options': ['I need deep lyrics', 'It\'s all about the beat/vibe', 'A perfect balance of both', 'I barely notice the lyrics'], 'allow_custom_answer': true},
    {'question': 'Do you play any instruments?', 'options': ['Yes, proficiently', 'Learning one right now', 'Used to, but stopped', 'No, strictly a listener'], 'allow_custom_answer': true},
    {'question': 'Do you listen to music while working or need silence?', 'options': ['Always need background music', 'Strictly silence to focus', 'Only instrumental/lo-fi', 'Depends on the task'], 'allow_custom_answer': true},
  ],
  'Gaming': [
    {'question': 'Solo campaign or multiplayer — your comfort zone?', 'options': ['Deep story-driven solo', 'Competitive multiplayer', 'Co-op with friends', 'Casual puzzle games'], 'allow_custom_answer': true},
    {'question': 'Console, PC, or mobile gamer?', 'options': ['PC Master Race', 'Console (PlayStation/Xbox/Nintendo)', 'Mobile gaming', 'A mix of everything'], 'allow_custom_answer': true},
    {'question': 'RPG or FPS — where does your soul belong?', 'options': ['Immersive RPGs', 'Fast-paced FPS', 'Strategy/Simulators', 'Sports/Racing'], 'allow_custom_answer': true},
    {'question': 'Do you game for the story or the challenge?', 'options': ['I want an epic narrative', 'I want a brutal challenge', 'Just here to relax and have fun', 'I play to hang out with friends'], 'allow_custom_answer': true},
    {'question': 'Day-gaming or midnight-gaming sessions?', 'options': ['Midnight marathon', 'Lazy afternoon gaming', 'Quick breaks during the day', 'Whenever I find time'], 'allow_custom_answer': true},
  ],
  'Travel': [
    {'question': 'Mountains or beaches — your forever escape?', 'options': ['Snowy mountains', 'Sunny beaches', 'Bustling cities', 'Lush forests'], 'allow_custom_answer': true},
    {'question': 'Planned itinerary or spontaneous adventure?', 'options': ['Spreadsheet planned to the hour', 'Book a flight and figure it out', 'Rough plan, but flexible', 'I let others plan for me'], 'allow_custom_answer': true},
    {'question': 'Budget backpacker or luxury traveller?', 'options': ['Hostels and backpacks', '5-star resorts', 'Comfortable mid-range', 'Glamping/Unique stays'], 'allow_custom_answer': true},
    {'question': 'Solo travel or travel with people you love?', 'options': ['Solo soul-searching', 'With a romantic partner', 'With a group of friends', 'With family'], 'allow_custom_answer': true},
    {'question': 'Street food explorer or fine-dining seeker abroad?', 'options': ['Eat where the locals eat', 'Michelin star experiences', 'A mix of both', 'Stick to familiar foods'], 'allow_custom_answer': true},
  ],
  'Food': [
    {'question': 'Cooking at home or eating out — your preference?', 'options': ['I love cooking my own meals', 'Exploring new restaurants', 'Ordering takeout to the couch', 'Eating out, but only socially'], 'allow_custom_answer': true},
    {'question': 'Sweet tooth or savoury cravings person?', 'options': ['Always leave room for dessert', 'Savoury all the way', 'I need both equally', 'Depends on my mood'], 'allow_custom_answer': true},
    {'question': 'Spice tolerance: mild, medium, or bring-the-fire?', 'options': ['Bring the fire', 'Medium kick', 'Zero spice please', 'I enjoy flavor over heat'], 'allow_custom_answer': true},
    {'question': 'Do you follow recipes strictly or freestyle cook?', 'options': ['Strictly measure everything', 'Throw things in and taste', 'I modify recipes as I go', 'I don\'t really cook'], 'allow_custom_answer': true},
    {'question': 'Early breakfast or brunch person?', 'options': ['Early breakfast champion', 'Late lazy brunch', 'Skip breakfast entirely', 'Coffee is my breakfast'], 'allow_custom_answer': true},
  ],
  'Fitness': [
    {'question': 'Morning workout or evening session?', 'options': ['Early bird gains', 'Late night pump', 'Whenever I can fit it in', 'I prefer afternoon workouts'], 'allow_custom_answer': true},
    {'question': 'Gym, outdoor, or home workouts?', 'options': ['The iron sanctuary (Gym)', 'Outdoor running/calisthenics', 'Home living room workouts', 'Sports and active hobbies'], 'allow_custom_answer': true},
    {'question': 'Cardio warrior or weights enthusiast?', 'options': ['Heavy lifting', 'Endurance cardio', 'A balanced hybrid', 'Yoga and mobility'], 'allow_custom_answer': true},
    {'question': 'Do you track your workouts or go by feel?', 'options': ['Spreadsheets and apps', 'Mental notes only', 'Just go with the flow', 'Track occasionally'], 'allow_custom_answer': true},
    {'question': 'Workout playlist or silence during training?', 'options': ['Aggressive hype music', 'Podcasts or audiobooks', 'Silence to focus', 'Whatever is playing in the gym'], 'allow_custom_answer': true},
  ],
  'Tech': [
    {'question': 'Apple or Android — and why is this hill worth dying on?', 'options': ['Apple ecosystem all the way', 'Android for the freedom', 'I use both seamlessly', 'I honestly do not care'], 'allow_custom_answer': true},
    {'question': 'Early adopter or wait-for-reviews type?', 'options': ['I need the latest gadget on day 1', 'I wait for the bugs to be fixed', 'I use tech until it completely breaks', 'Only buy if absolutely necessary'], 'allow_custom_answer': true},
    {'question': 'Dark mode or light mode — no compromises?', 'options': ['Dark mode everything', 'Light mode everywhere', 'Auto switch with the sun', 'Mix and match per app'], 'allow_custom_answer': true},
    {'question': 'Smart-home enthusiast or analog minimalist?', 'options': ['Everything is automated', 'A few smart lights/speakers', 'I prefer physical switches', 'AI scares me'], 'allow_custom_answer': true},
    {'question': 'Do you follow tech news daily or casually?', 'options': ['I watch all the keynotes', 'Just read the headlines', 'Only when buying something new', 'Not really interested'], 'allow_custom_answer': true},
  ],
  'Reading': [
    {'question': 'Fiction or non-fiction — your natural habitat?', 'options': ['Escaping into fiction', 'Learning from non-fiction', 'A healthy mix of both', 'Mostly biographies/memoirs'], 'allow_custom_answer': true},
    {'question': 'Physical book, e-reader, or audiobook?', 'options': ['The smell of physical books', 'Kindle/E-reader convenience', 'Audiobooks on the go', 'Read on my phone/tablet'], 'allow_custom_answer': true},
    {'question': 'Do you dog-ear pages or treat books like sacred objects?', 'options': ['Sacred objects (use a bookmark)', 'Dog-ear, highlight, write in them', 'Doesn\'t matter, it\'s just a book', 'I only read digital'], 'allow_custom_answer': true},
    {'question': 'One book at a time or juggle multiple?', 'options': ['Strictly one until finished', 'Juggle 2-3 at once', 'Start 10 and never finish them', 'Read based on my current mood'], 'allow_custom_answer': true},
    {'question': 'Re-reader or once-and-done book person?', 'options': ['I love revisiting favorites', 'Once done, I move on', 'Only re-read if it\'s been years', 'I read summaries'], 'allow_custom_answer': true},
  ],
  'Art': [
    {'question': 'Do you create art or primarily appreciate it?', 'options': ['I am an artist/creator', 'I strictly appreciate it', 'I dabble occasionally', 'I appreciate it but don\'t understand it'], 'allow_custom_answer': true},
    {'question': 'Museum person or street-art enthusiast?', 'options': ['Quiet museums & galleries', 'Vibrant street art', 'Digital art and NFTs', 'All forms of art'], 'allow_custom_answer': true},
    {'question': 'Art for expression or art for aesthetics?', 'options': ['Deep emotional expression', 'Just has to look beautiful', 'Provoking a strong reaction', 'A balance of both'], 'allow_custom_answer': true},
    {'question': 'Do you buy original art or prints?', 'options': ['Originals when I can', 'High-quality prints', 'Posters and digital downloads', 'I don\'t buy art'], 'allow_custom_answer': true},
    {'question': 'Gallery opening or live performance art — which excites you more?', 'options': ['Gallery with wine', 'Immersive live performance', 'Interactive installations', 'Neither really'], 'allow_custom_answer': true},
  ],
  'Dance': [
    {'question': 'Social dancing or solo performance?', 'options': ['Social/partner dancing', 'Freestyling solo', 'Choreographed routines', 'Only in my room alone'], 'allow_custom_answer': true},
    {'question': 'Do you prefer choreography or freestyle?', 'options': ['Learning strict choreo', 'Just letting the music guide me', 'A bit of both', 'I have two left feet'], 'allow_custom_answer': true},
    {'question': 'Would you dance on a first date if asked?', 'options': ['Absolutely, let\'s go!', 'Only if I\'ve had a drink', 'I\'d be too shy', 'Hard pass'], 'allow_custom_answer': true},
    {'question': 'Dance floor confidence: shy wallflower or center of attention?', 'options': ['Center of the circle!', 'Vibing on the edges', 'Only with my close friends', 'Sitting at the bar'], 'allow_custom_answer': true},
    {'question': 'Have you ever taken formal dance classes?', 'options': ['Yes, trained for years', 'Took a few basic classes', 'Self-taught via YouTube', 'Never in my life'], 'allow_custom_answer': true},
  ],
};

const List<Map<String, Object>> _kDefaultQuestions = [
  {'question': 'What got you into your main interest in the first place?', 'options': ['A friend/family introduced me', 'Stumbled upon it randomly', 'Saw it online and got inspired', 'Always been drawn to it naturally'], 'allow_custom_answer': true},
  {'question': 'Do you prefer pursuing your hobbies alone or with others?', 'options': ['Definitely alone', 'Mostly with others', 'Depends on the hobby', 'I like finding a community'], 'allow_custom_answer': true},
  {'question': 'What\'s a goal you have around your current interests?', 'options': ['Turn it into a career', 'Just get marginally better', 'Find people to share it with', 'Keep it purely as an escape'], 'allow_custom_answer': true},
  {'question': 'How much of your free time does your passion take up?', 'options': ['Literally all of it', 'A healthy few hours a week', 'Comes in intense phases', 'Barely any time lately'], 'allow_custom_answer': true},
  {'question': 'Has your primary interest changed you in any meaningful way?', 'options': ['Completely reshaped my life', 'Made me more disciplined', 'Introduced me to great people', 'Just gave me something fun to do'], 'allow_custom_answer': true},
];

// ─────────────────────────────────────────────────────────────────────────────
// EXPLORE SCREEN
// ─────────────────────────────────────────────────────────────────────────────
enum _XView { grid, split, random }

class ExploreScreen extends StatefulWidget {
  final VoidCallback onCreateTap;
  const ExploreScreen({super.key, required this.onCreateTap});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class ExploreCache {
  static bool quickSetupDone = false;
  static bool hasCheckedSetup = false;
  
  static Map<String, dynamic>? myProfile;
  static bool hasLoadedMyProfile = false;

  static List<Map<String, dynamic>> rawProfiles = [];
  static bool isProfilesLoaded = false;
  
  static Set<String> acceptedProfileIds = {};
  static Set<String> sentKnockProfileIds = {};
  static bool hasLoadedKnocks = false;

  static StreamSubscription<List<Map<String, dynamic>>>? profilesSub;
  static final StreamController<void> updateStream = StreamController<void>.broadcast();

  static void initStream() {
    if (profilesSub != null) return;
    profilesSub = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .listen((data) {
      rawProfiles = data;
      isProfilesLoaded = true;
      updateStream.add(null);
    }, onError: (e) {
      debugPrint('Explore stream: $e');
    });
  }

  static void disposeStream() {
    profilesSub?.cancel();
    profilesSub = null;
  }
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  final _uid = Supabase.instance.client.auth.currentUser?.id;
  bool _isLoading = true;

  List<Map<String, dynamic>> _activeUsers = [];
  List<Map<String, dynamic>> _inactiveUsers = [];
  Map<String, dynamic>? _myProfile;
  final List<Map<String, dynamic>> _pendingKnocks = [];

  _XView _view = _XView.grid;
  Map<String, dynamic>? _selected;
  bool _isSpinning = false;
  final Set<String> _seenProfileIds = {};
  final Set<String> _acceptedProfileIds = {};
  final Set<String> _sentKnockProfileIds = {};
  List<Map<String, dynamic>> _rawStreamProfiles = [];
  bool _quickSetupDone = false;

  late final AnimationController _spinCtrl;
  late final AnimationController _splitCtrl;

  StreamSubscription<void>? _cacheSub;

  static const _orange = Color(0xFFFF6B00);
  static const _deep   = Color(0xFF060608);
  static const _card   = Color(0xFF0E0E16);

  @override
  void initState() {
    super.initState();
    _spinCtrl  = AnimationController(vsync: this, duration: 3.seconds);
    _splitCtrl = AnimationController(vsync: this, duration: 600.ms);
    _checkFreshUser();

    if (ExploreCache.hasCheckedSetup) {
      _quickSetupDone = ExploreCache.quickSetupDone;
    } else {
      _checkSetupDone();
    }

    if (ExploreCache.hasLoadedMyProfile) {
      _myProfile = ExploreCache.myProfile;
    } else {
      _loadMyProfile();
    }

    if (ExploreCache.isProfilesLoaded) {
      _rawStreamProfiles = ExploreCache.rawProfiles;
      _isLoading = false;
      
      if (ExploreCache.hasLoadedKnocks) {
        _acceptedProfileIds.addAll(ExploreCache.acceptedProfileIds);
        _sentKnockProfileIds.addAll(ExploreCache.sentKnockProfileIds);
      }
      
      _processAndFilterProfiles();
    } else {
      _isLoading = true;
    }

    _loadKnocksAndStartStream();

    _cacheSub = ExploreCache.updateStream.stream.listen((_) {
      if (mounted) {
        _rawStreamProfiles = ExploreCache.rawProfiles;
        _processAndFilterProfiles();
        if (_isLoading) {
          setState(() => _isLoading = false);
        }
      }
    });

    locationService.activeLocationNotifier.addListener(_onLocationChanged);
  }

  void _onLocationChanged() {
    _loadKnocksAndStartStream();
  }

  Future<void> _checkSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    ExploreCache.quickSetupDone = prefs.getBool('quick_setup_done') ?? false;
    ExploreCache.hasCheckedSetup = true;
    if (mounted) setState(() => _quickSetupDone = ExploreCache.quickSetupDone);
  }

  @override
  void dispose() {
    _cacheSub?.cancel();
    _spinCtrl.dispose();
    _splitCtrl.dispose();
    locationService.activeLocationNotifier.removeListener(_onLocationChanged);
    super.dispose();
  }

  Future<void> _checkFreshUser() async {
    if (_uid == null) return;
    try {
      final r = await Supabase.instance.client
          .from('profiles')
          .select('explore_first_visited_at')
          .eq('id', _uid!)
          .maybeSingle();
      if (r != null && r['explore_first_visited_at'] == null) {
        await Supabase.instance.client.from('profiles').update({
          'explore_first_visited_at': DateTime.now().toUtc().toIso8601String(),
          'visibility': 'inactive',
          'visibility_updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', _uid!);
      }
    } catch (e) { print("Error in checkFreshUser: $e"); }
  }

  Future<void> _loadMyProfile() async {
    if (_uid == null) return;
    try {
      final r = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', _uid!)
          .maybeSingle();
      if (r != null) {
        ExploreCache.myProfile = r;
        ExploreCache.hasLoadedMyProfile = true;
        if (mounted) setState(() => _myProfile = r);
      }
    } catch (e) { print("Error in loadMyProfile: $e"); }
  }

  void _processAndFilterProfiles() {
    final district = locationService.activeDistrict;
    if (district.isEmpty || district == 'Unknown') {
      if (mounted) setState(() { _activeUsers = []; _inactiveUsers = []; });
      return;
    }
    
    final List<Map<String, dynamic>> act = [], inact = [];
    final city  = district.toLowerCase().trim();
    final cLat  = locationService.activeLat ?? 0;
    final cLng  = locationService.activeLng ?? 0;

    for (final p in _rawStreamProfiles) {
      final pid = p['id']?.toString() ?? '';
      if (pid == _uid) continue;
      if (_acceptedProfileIds.contains(pid)) continue;
      if (_sentKnockProfileIds.contains(pid)) continue;
      
      final pCity = (p['city']?.toString() ?? '').toLowerCase().trim();
      bool near = pCity == city;
      if (!near) continue;

      final vis = p['visibility']?.toString() ?? 'inactive';
      if (vis == 'invisible') continue;
      
      final profile = {
        'id': p['id'],
        'name': p['name'] ?? p['full_name'] ?? 'User',
        'age': p['age'] ?? 22,
        'avatar_url': _sanitizeAvatarUrl(p['avatar_url']),
        'bio': p['bio'] ?? '',
        'city': p['city'] ?? '',
        'visibility': vis,
        'visibility_updated_at': p['visibility_updated_at'] ?? p['updated_at'] ?? '',
        'explore_status': p['explore_status'] ?? '',
        'interests': (p['interests'] as List?)?.cast<String>() ?? <String>[],
        'gender': p['gender'] ?? '',
        'zodiac': p['zodiac'] ?? '',
        'education': p['education'] ?? '',
        'job_title': p['job_title'] ?? '',
        'personality_traits': (p['personality_traits'] as List?)?.cast<String>() ?? <String>[],
        'knock_questions': p['knock_questions'],
        'height_cm': p['height_cm'],
        'smoking': p['smoking'] ?? '',
        'drinking': p['drinking'] ?? '',
        'weed': p['weed'] ?? '',
        'diet': p['diet'] ?? '',
        'exercise': p['exercise'] ?? '',
        'religion': p['religion'] ?? '',
        'relationship_type': p['relationship_type'] ?? '',
        'looking_for': (p['looking_for'] as List?)?.cast<String>() ?? <String>[],
        'languages': (p['languages'] as List?)?.cast<String>() ?? <String>[],
        'match_gender': p['match_gender'] ?? '',
        'dob': p['dob'] ?? '',
        'pets': p['pets'] ?? '',
        'political_view': p['political_view'] ?? '',
        'wants_children': p['wants_children'] ?? '',
        'open_to_relocate': p['open_to_relocate'] ?? '',
        'fitness_routine': p['fitness_routine'] ?? '',
      };
      if (vis == 'active') { act.add(profile); } else { inact.add(profile); }
    }

    act.sort((a, b) => (b['visibility_updated_at']?.toString() ?? '')
        .compareTo(a['visibility_updated_at']?.toString() ?? ''));
    inact.sort((a, b) => (b['visibility_updated_at']?.toString() ?? '')
        .compareTo(a['visibility_updated_at']?.toString() ?? ''));

    if (mounted) {
      setState(() {
        _activeUsers = act;
        _inactiveUsers = inact;
      });
    }
  }

  Future<void> _loadKnocksAndStartStream() async {
    if (_uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final district = locationService.activeDistrict;
    if (district.isEmpty || district == 'Unknown') {
      if (mounted) setState(() { _activeUsers = []; _inactiveUsers = []; _isLoading = false; });
      return;
    }

    if (!ExploreCache.hasLoadedKnocks) {
      try {
        final rows = await Supabase.instance.client
            .from('requests')
            .select('sender_id, target_id')
            .eq('status', 'approved')
            .or('sender_id.eq.$_uid,target_id.eq.$_uid');
        final ids = <String>{};
        for (final row in (rows as List)) {
          final sid = row['sender_id']?.toString();
          final tid = row['target_id']?.toString();
          if (sid != null && sid != _uid) ids.add(sid);
          if (tid != null && tid != _uid) ids.add(tid);
        }
        
        final sentRows = await Supabase.instance.client
            .from('requests')
            .select('target_id')
            .eq('sender_id', _uid!)
            .eq('target_type', 'profile');
        final sentIds = <String>{};
        for (final row in (sentRows as List)) {
          final tid = row['target_id']?.toString();
          if (tid != null) sentIds.add(tid);
        }

        ExploreCache.acceptedProfileIds = ids;
        ExploreCache.sentKnockProfileIds = sentIds;
        ExploreCache.hasLoadedKnocks = true;

        if (mounted) {
          setState(() {
            _acceptedProfileIds..clear()..addAll(ids);
            _sentKnockProfileIds..clear()..addAll(sentIds);
          });
        }
      } catch (e) {
        debugPrint('Fetch accepted/sent knocks: $e');
      }
    }

    ExploreCache.initStream();
    if (ExploreCache.isProfilesLoaded) {
      if (mounted) _processAndFilterProfiles();
    }
  }

  Future<void> _refresh([Map<String, dynamic>? setupPayload]) async {
    if (setupPayload != null) {
      _quickSetupDone = true;
      ExploreCache.quickSetupDone = true;
      SharedPreferences.getInstance().then((p) => p.setBool('quick_setup_done', true));
      if (_myProfile != null) {
        _myProfile = {..._myProfile!, ...setupPayload};
      } else {
        _myProfile = Map<String, dynamic>.from(setupPayload);
      }
      ExploreCache.myProfile = _myProfile;
      ExploreCache.hasLoadedMyProfile = true;
    }
    _seenProfileIds.clear();
    
    ExploreCache.hasLoadedKnocks = false;
    ExploreCache.hasLoadedMyProfile = false;
    ExploreCache.isProfilesLoaded = false;
    ExploreCache.disposeStream();
    
    _loadMyProfile();
    _loadKnocksAndStartStream();
  }

  static String _sanitizeAvatarUrl(dynamic raw) {
    if (raw == null) return '';
    final url = raw.toString();
    if (url.isEmpty) return '';
    if (url.startsWith('http') || url.startsWith('data:image')) return url;
    return '';
  }

  static bool _strMatch(String a, String b) =>
      a.isNotEmpty && b.isNotEmpty && a.toLowerCase().trim() == b.toLowerCase().trim();

  static double _listOverlap(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) return 0.5;
    if (a.isEmpty || b.isEmpty) return 0.2;
    final sA = a.map((e) => e.toLowerCase()).toSet();
    final sB = b.map((e) => e.toLowerCase()).toSet();
    final shared = sA.intersection(sB).length;
    final total = sA.union(sB).length;
    return total > 0 ? shared / total : 0;
  }

  int _zodiacScore(String a, String b) {
    const fire  = ['aries', 'leo', 'sagittarius'];
    const earth = ['taurus', 'virgo', 'capricorn'];
    const air   = ['gemini', 'libra', 'aquarius'];
    const water = ['cancer', 'scorpio', 'pisces'];
    String el(String z) {
      final zl = z.toLowerCase().replaceAll(RegExp(r'[^\w]'), '').trim();
      if (fire.any((f) => zl.contains(f)))  return 'fire';
      if (earth.any((f) => zl.contains(f))) return 'earth';
      if (air.any((f) => zl.contains(f)))   return 'air';
      if (water.any((f) => zl.contains(f))) return 'water';
      return '';
    }
    final eA = el(a), eB = el(b);
    if (eA.isEmpty || eB.isEmpty) return 50;
    if (eA == eB) return 100;
    if ((eA == 'fire' && eB == 'air') || (eA == 'air' && eB == 'fire')) return 80;
    if ((eA == 'earth' && eB == 'water') || (eA == 'water' && eB == 'earth')) return 80;
    return 40;
  }

  Map<String, double> _compatCategories(Map<String, dynamic> other) {
    if (_myProfile == null) {
      return {'Lifestyle': 50, 'Values': 50, 'Interests': 50, 'Demographics': 50};
    }
    final my = _myProfile!;

    double demo = 0;
    int demoCount = 0;
    final myLF = List<String>.from(my['looking_for'] ?? []);
    final thLF = List<String>.from(other['looking_for'] ?? []);
    if (myLF.isNotEmpty || thLF.isNotEmpty) {
      demo += _listOverlap(myLF, thLF) * 100;
      demoCount++;
    }
    final myLang = List<String>.from(my['languages'] ?? []);
    final thLang = List<String>.from(other['languages'] ?? []);
    if (myLang.isNotEmpty || thLang.isNotEmpty) {
      demo += _listOverlap(myLang, thLang) * 100;
      demoCount++;
    }
    demo += _zodiacScore(my['zodiac'] ?? '', other['zodiac'] ?? '');
    demoCount++;
    final demoScore = demoCount > 0 ? (demo / demoCount).clamp(0, 100).toDouble() : 50.0;

    double ls = 0;
    int lsCount = 0;
    for (final key in ['smoking', 'drinking', 'diet', 'exercise']) {
      if (_strMatch(my[key] ?? '', other[key] ?? '')) {
        ls += 100; lsCount++;
      } else if ((my[key] ?? '').isNotEmpty && (other[key] ?? '').isNotEmpty) {
        ls += 35; lsCount++;
      }
    }
    if (_strMatch(my['fitness_routine'] ?? '', other['fitness_routine'] ?? '')) {
      ls += 100; lsCount++;
    } else if ((my['fitness_routine'] ?? '').isNotEmpty && (other['fitness_routine'] ?? '').isNotEmpty) {
      ls += 40; lsCount++;
    }
    if (_strMatch(my['pets'] ?? '', other['pets'] ?? '')) {
      ls += 100; lsCount++;
    } else if ((my['pets'] ?? '').isNotEmpty && (other['pets'] ?? '').isNotEmpty) {
      ls += 30; lsCount++;
    }
    final lsScore = lsCount > 0 ? (ls / lsCount).clamp(0, 100).toDouble() : 50.0;

    double vl = 0;
    int vlCount = 0;
    for (final key in ['religion', 'political_view', 'open_to_relocate']) {
      if (_strMatch(my[key] ?? '', other[key] ?? '')) {
        vl += 100; vlCount++;
      } else if ((my[key] ?? '').isNotEmpty && (other[key] ?? '').isNotEmpty) {
        vl += 30; vlCount++;
      }
    }
    final vlScore = vlCount > 0 ? (vl / vlCount).clamp(0, 100).toDouble() : 50.0;

    final myI = List<String>.from(my['interests'] ?? []);
    final thI = List<String>.from(other['interests'] ?? []);
    final myT = List<String>.from(my['personality_traits'] ?? []);
    final thT = List<String>.from(other['personality_traits'] ?? []);
    double intScore = (_listOverlap(myI, thI) * 75) + (_listOverlap(myT, thT) * 25);
    intScore = intScore.clamp(0, 100);

    return {
      'Lifestyle': lsScore,
      'Values': vlScore,
      'Interests': intScore,
      'Demographics': demoScore,
    };
  }

  int _compat(Map<String, dynamic> other) {
    final cats = _compatCategories(other);
    final score = (cats['Lifestyle']! * 0.35) +
                  (cats['Interests']! * 0.30) +
                  (cats['Values']! * 0.25) +
                  (cats['Demographics']! * 0.10);
    final activeBonus = other['visibility'] == 'active' ? 3.0 : 0.0;
    return (score + activeBonus).round().clamp(0, 100);
  }

  String _connectionHint(Map<String, dynamic> other) {
    if (_myProfile == null) return '';
    final myI  = List<String>.from(_myProfile!['interests'] ?? []);
    final thI  = List<String>.from(other['interests'] ?? []);
    final shared = myI.where(thI.contains).take(2).toList();
    if (shared.isEmpty) return '';
    if (shared.length == 1) return 'You both love ${shared[0]}';
    return 'You both love ${shared[0]} & ${shared[1]}';
  }

  List<String> _topReasons(Map<String, dynamic> other) {
    if (_myProfile == null) return [];
    final my = _myProfile!;
    final reasons = <String>[];

    final myLF = List<String>.from(my['looking_for'] ?? []);
    final thLF = List<String>.from(other['looking_for'] ?? []);
    final sharedLF = myLF.where(thLF.contains).toList();
    if (sharedLF.isNotEmpty) {
      reasons.add('Both want ${sharedLF.first}');
    }

    if (_strMatch(my['smoking'] ?? '', other['smoking'] ?? '') && (my['smoking'] ?? '').toLowerCase() == 'never') {
      reasons.add('Both are Non-Smokers');
    }

    final myI = List<String>.from(my['interests'] ?? []);
    final thI = List<String>.from(other['interests'] ?? []);
    final sharedI = myI.where(thI.contains).take(2).toList();
    if (sharedI.isNotEmpty) {
      reasons.add('Love for ${sharedI.join(' & ')}');
    }

    if (_strMatch(my['religion'] ?? '', other['religion'] ?? '')) {
      reasons.add('Same Religious Values');
    }

    if (_strMatch(my['political_view'] ?? '', other['political_view'] ?? '')) {
      reasons.add('Similar Political Views');
    }

    if (_strMatch(my['diet'] ?? '', other['diet'] ?? '')) {
      reasons.add('Same Dietary Preference');
    }

    if (_strMatch(my['pets'] ?? '', other['pets'] ?? '')) {
      reasons.add('Both ${my['pets']}s');
    }

    final myLang = List<String>.from(my['languages'] ?? []);
    final thLang = List<String>.from(other['languages'] ?? []);
    final sharedLang = myLang.where(thLang.contains).toList();
    if (sharedLang.length >= 2) {
      reasons.add('Speak ${sharedLang.take(2).join(' & ')}');
    }

    return reasons.take(5).toList();
  }

  List<Map<String, dynamic>> _buildQuestions(Map<String, dynamic> target) {
    final raw = target['knock_questions'];
    if (raw != null) {
      try {
        final qs = (raw as List).map((q) {
          if (q is Map) {
            return <String, dynamic>{
              'question': q['question']?.toString() ?? '',
              'options': (q['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
              'allow_custom_answer': q['allow_custom_answer'] == true || q['options'] == null || (q['options'] as List).isEmpty,
              'my_answer': q['my_answer']?.toString() ?? '',
              'question_type': q['question_type']?.toString(),
              'slider_min': double.tryParse(q['slider_min']?.toString() ?? '0') ?? 0.0,
              'slider_max': double.tryParse(q['slider_max']?.toString() ?? '10') ?? 10.0,
            };
          }
          return null;
        }).where((q) => q != null && (q['question'] as String).isNotEmpty).toList().cast<Map<String, dynamic>>();

        if (qs.length >= 3) {
          qs.shuffle();
          return qs.take(5).toList();
        }
      } catch (e) { print("Error in loadMyProfile: $e"); }
    }

    final rng   = math.Random();
    final myI   = List<String>.from(_myProfile?['interests'] ?? []);
    final thI   = List<String>.from(target['interests'] ?? []);
    final shared = thI.where(myI.contains).toList();
    final pool  = <Map<String, dynamic>>[];

    for (final interest in [...shared, ...thI]) {
      final key = _kInterestQuestions.keys.firstWhere(
        (k) => interest.toLowerCase().contains(k.toLowerCase()) ||
               k.toLowerCase().contains(interest.toLowerCase()),
        orElse: () => '',
      );
      if (key.isNotEmpty) {
        final src = List<Map<String, dynamic>>.from(_kInterestQuestions[key]!.map((m) => Map<String, dynamic>.from(m)))..shuffle(rng);
        pool.addAll(src.take(3));
      }
    }

    if (pool.length < 3) {
      pool.addAll(List<Map<String, dynamic>>.from(_kDefaultQuestions.map((m) => Map<String, dynamic>.from(m)))..shuffle(rng));
    }
    pool.shuffle(rng);

    final seen = <String>{};
    final finalQuestions = <Map<String, dynamic>>[];
    for (final q in pool) {
      final qStr = q['question'].toString();
      if (seen.add(qStr)) {
        finalQuestions.add(q);
        if (finalQuestions.length == 5) break;
      }
    }
    return finalQuestions;
  }

  void _goSplit(Map<String, dynamic> profile) {
    HapticFeedback.mediumImpact();
    setState(() { _selected = profile; _view = _XView.split; _isSpinning = false; });
    _splitCtrl.forward(from: 0);
  }

  void _goRandom() {
    final all = [..._activeUsers, ..._inactiveUsers];
    if (all.isEmpty) return;
    HapticFeedback.heavyImpact();

    final unseen = all.where((p) => !_seenProfileIds.contains(p['id']?.toString() ?? '')).toList();

    if (unseen.isEmpty) {
      setState(() => _seenProfileIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '🔄 You\'ve seen everyone! Starting fresh.',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFFFF6B00),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ));
      _goRandom();
      return;
    }

    setState(() { _selected = null; _view = _XView.random; _isSpinning = true; });
    _splitCtrl.forward(from: 0);
    _spinCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      final index = (all.length > 1) ? (all.indexOf(unseen.first)) : 0;
      setState(() {
        _selected = all[index];
        _view = _XView.split;
        _isSpinning = false;
      });
      _splitCtrl.forward(from: 0);
    });
  }


  void _backToGrid() {
    _spinCtrl.stop();
    _spinCtrl.reset();
    _splitCtrl.reverse();
    setState(() { _view = _XView.grid; _selected = null; _isSpinning = false; });
  }

  bool get _isProfileComplete {
    if (_quickSetupDone) return true;
    if (_myProfile == null) return false;
    final requiredFields = [
      'looking_for', 'smoking', 'drinking', 'diet', 'fitness_routine',
      'pets', 'religion',
      'languages', 'zodiac', 'interests', 'personality_traits'
    ];
    for (final f in requiredFields) {
      final val = _myProfile![f];
      if (val == null) return false;
      if (val is String && val.isEmpty) return false;
      if (val is List && val.isEmpty) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    
    // Removed _QuickSetupOverlay check so users can view the grid even with incomplete profiles.
    
    switch (_view) {
      case _XView.split:
      case _XView.random:
        return _SplitScreen(
          myProfile:  _myProfile,
          target:     _selected,
          isRandom:   _view == _XView.random,
          isSpinning: _isSpinning,
          allProfiles:[..._activeUsers, ..._inactiveUsers],
          compat:     _selected != null ? _compat(_selected!) : 50,
          compatCategories: _selected != null ? _compatCategories(_selected!) : {},
          topReasons: _selected != null ? _topReasons(_selected!) : [],
          connectionHint: _selected != null ? _connectionHint(_selected!) : '',
          onBack:     _backToGrid,
          onKnock:    (p) => _showKnockQuestionnaire(p),
          onSuperKnock: (p) => _handleSuperKnock(p),
          buildQuestions: _buildQuestions,
        );
      case _XView.grid:
        return _GridView(
          myProfile:     _myProfile,
          isLoading:     _isLoading,
          activeUsers:   _activeUsers,
          inactiveUsers: _inactiveUsers,
          onRefresh:     _refresh,
          onSelect:      _goSplit,
          onRandom:      _goRandom,
          onSettings:    () => _showKnockSettings(context),
          pendingKnocksCount: _pendingKnocks.length,
          onShowKnocks:  () {},
        );
    }
  }

  void _showKnockQuestionnaire(Map<String, dynamic> target) {
    final questions = _buildQuestions(target);
    final answers   = List<String?>.filled(questions.length, null);
    final customCtl = List.generate(questions.length, (_) => TextEditingController());
    int curQ        = 0;
    bool customMode = false;
    bool sending    = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, set) {
          final q        = questions[curQ];
          final progress = (curQ + 1) / questions.length;
          final tName    = (target['name'] ?? 'User').toString().split(' ')[0];

          final qMap       = questions[curQ];
          final qText      = qMap['question'].toString();
          final qOptions   = (qMap['options'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
          final allowCustom = qMap['allow_custom_answer'] == true;
          final benchmarkAns = qMap['my_answer']?.toString() ?? '';
          final qType      = qMap['question_type']?.toString();
          final sMin       = qMap['slider_min'] as double? ?? 0.0;
          final sMax       = qMap['slider_max'] as double? ?? 10.0;

          Widget buildOption(String text) {
            final sel = answers[curQ] == text && !customMode;
            final isBenchmark = text == benchmarkAns && benchmarkAns.isNotEmpty;
            return GestureDetector(
              onTap: () => set(() { answers[curQ] = text; customMode = false; }),
              child: AnimatedContainer(
                duration: 200.ms,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: sel
                      ? _orange.withValues(alpha: 0.13)
                      : isBenchmark
                          ? const Color(0xFF00E676).withValues(alpha: 0.06)
                          : const Color(0xFF181820),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: sel
                        ? _orange
                        : isBenchmark
                            ? const Color(0xFF00E676).withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.07),
                    width: sel || isBenchmark ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel ? _orange : Colors.transparent,
                        border: Border.all(color: sel ? _orange : Colors.white24, width: 2),
                      ),
                      child: sel ? const Icon(Icons.check, color: Colors.white, size: 13) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text,
                      style: GoogleFonts.outfit(
                        color: sel ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      ))),
                    if (isBenchmark && !sel)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                        ),
                        child: Text('their answer', style: GoogleFonts.outfit(color: const Color(0xFF00E676), fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.90,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(top: BorderSide(color: _orange.withValues(alpha: 0.2), width: 1.5)),
              ),
              child: Column(
                children: [
                  Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text('Knock Questions',
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: _orange.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _orange.withValues(alpha: 0.4)),
                          ),
                          child: Text('${curQ + 1} / ${questions.length}',
                            style: GoogleFonts.outfit(color: _orange, fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation(_orange),
                        minHeight: 5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        _MiniAvatar(url: target['avatar_url']?.toString() ?? '', size: 36, borderColor: _orange),
                        const SizedBox(width: 10),
                        Text('Knocking $tName',
                          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        const Icon(Icons.waving_hand_rounded, color: _orange, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_orange.withValues(alpha: 0.1), _orange.withValues(alpha: 0.03)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _orange.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _orange.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.help_outline_rounded, color: _orange, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(qText,
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.45))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (qType == 'slider') ...[
                            Text('Slide to answer', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                            const SizedBox(height: 10),
                            Slider(
                              value: double.tryParse(answers[curQ] ?? '') ?? ((sMax + sMin) / 2),
                              min: sMin,
                              max: sMax,
                              activeColor: _orange,
                              inactiveColor: Colors.white24,
                              onChanged: (v) => set(() { answers[curQ] = v.toStringAsFixed(1); customMode = false; }),
                            ),
                            Center(child: Text(answers[curQ] ?? ((sMax + sMin) / 2).toStringAsFixed(1), style: GoogleFonts.outfit(color: _orange, fontSize: 24, fontWeight: FontWeight.bold))),
                          ] else if (qType == 'open') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: TextField(
                                controller: customCtl[curQ],
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                                maxLines: 3,
                                onChanged: (v) => set(() { answers[curQ] = v.isEmpty ? null : v; customMode = true; }),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Type your answer here...',
                                  hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
                                ),
                              ),
                            ),
                          ] else ...[
                            if (qOptions.isNotEmpty) ...qOptions.map(buildOption)
                            else ...[
                              buildOption('Yes, definitely!'),
                              buildOption('Somewhat'),
                              buildOption('Not really'),
                              buildOption('Depends on the situation'),
                            ],
                            if (allowCustom) ...[
                              GestureDetector(
                                onTap: () => set(() { customMode = !customMode; if (!customMode) answers[curQ] = null; }),
                                child: AnimatedContainer(
                                  duration: 200.ms,
                                  margin: const EdgeInsets.only(top: 4, bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: customMode ? const Color(0xFF6366F1).withValues(alpha: 0.12) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: customMode ? const Color(0xFF6366F1) : Colors.white.withValues(alpha: 0.08),
                                      width: customMode ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_note_rounded,
                                        color: customMode ? const Color(0xFF6366F1) : Colors.white38, size: 20),
                                      const SizedBox(width: 10),
                                      Text('Write my own answer',
                                        style: GoogleFonts.outfit(
                                          color: customMode ? const Color(0xFF6366F1) : Colors.white38,
                                          fontSize: 14, fontWeight: FontWeight.w500,
                                        )),
                                    ],
                                  ),
                                ),
                              ),
                              if (customMode)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                                  ),
                                  child: TextField(
                                    controller: customCtl[curQ],
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                                    maxLines: 3,
                                    onChanged: (v) => set(() => answers[curQ] = v.isEmpty ? null : v),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Share your thoughts…',
                                      hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                    child: Row(
                      children: [
                        if (curQ > 0) ...[
                          GestureDetector(
                            onTap: () => set(() { curQ--; customMode = false; }),
                            child: Container(
                              width: 54, height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.05),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: Colors.white54, size: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: GestureDetector(
                            onTap: sending ? null : () async {
                              final ans = (customMode || qType == 'open')
                                  ? customCtl[curQ].text.trim()
                                  : answers[curQ];
                              if (ans == null || ans.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Please answer this question first!',
                                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                                  backgroundColor: const Color(0xFFFF3060),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ));
                                return;
                              }
                              answers[curQ] = ans;
                              if (curQ < questions.length - 1) {
                                set(() { curQ++; customMode = false; });
                              } else {
                                set(() => sending = true);
                                await _submitKnock(
                                  target, questions,
                                  answers.map((a) => a ?? '').toList(),
                                );
                                for (final c in customCtl) { c.dispose(); }
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) _showKnockCelebration(target);
                              }
                            },
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF3060), _orange],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [BoxShadow(color: _orange.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
                              ),
                              child: Center(
                                child: sending
                                    ? const SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        Text(
                                          curQ < questions.length - 1 ? 'Next Question' : 'Send Knock 🚪',
                                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(curQ < questions.length - 1
                                            ? Icons.arrow_forward_rounded : Icons.waving_hand_rounded,
                                          color: Colors.white, size: 18),
                                      ]),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Future<void> _submitKnock(
    Map<String, dynamic> target,
    List<Map<String, dynamic>> qs,
    List<String> ans, {
    bool isSuper = false,
  }) async {
    if (_uid == null) return;
    final tid = target['id'].toString();
    try {
      final existing = await Supabase.instance.client
          .from('requests').select('id')
          .eq('sender_id', _uid!).eq('target_id', tid).eq('target_type', 'profile')
          .maybeSingle();
      if (existing != null) return;

      final answersPayload = isSuper
          ? [{'super': true}]
          : List.generate(qs.length, (i) => {'question': qs[i]['question'].toString(), 'answer': ans[i]});

      await Supabase.instance.client.from('requests').insert({
        'sender_id': _uid,
        'target_id': tid,
        'target_type': 'profile',
        'status': 'pending',
        'knock_answers': answersPayload,
        'is_super': isSuper,
        'expires_at': DateTime.now().toUtc().add(const Duration(hours: 48)).toIso8601String(),
      });

      setState(() {
        _sentKnockProfileIds.add(tid);
      });
      _processAndFilterProfiles();

      final myName    = _myProfile?['name']?.toString() ?? 'Someone';
      final myAvatar  = _myProfile?['avatar_url']?.toString() ?? '';

      await NotificationService.sendNotification(
        userId: tid,
        type: NotificationType.knock,
        title: isSuper ? 'SUPER KNOCK! ⚡️' : 'New Knock! 🚪',
        body: isSuper
            ? '$myName just super-knocked you!'
            : '$myName wants to connect with you.',
        payload: {
          'sender_id': _uid,
          'sender_name': myName,
          'sender_avatar_url': myAvatar,
          'is_super': isSuper,
        },
      );

      final theirKnock = await Supabase.instance.client
          .from('requests').select('id')
          .eq('sender_id', tid).eq('target_id', _uid!).eq('target_type', 'profile')
          .eq('status', 'pending')
          .maybeSingle();
      if (theirKnock != null) {
        await Supabase.instance.client.from('requests').update({'status': 'approved'})
            .match({'target_type': 'profile'})
            .or('and(sender_id.eq.$_uid,target_id.eq.$tid),and(sender_id.eq.$tid,target_id.eq.$_uid)');

        await NotificationService.sendNotification(
          userId: tid,
          type: NotificationType.knock_accepted,
          title: 'Mutual Knock! 🎉',
          body: 'You and $myName both knocked each other. Start chatting!',
          payload: {
            'sender_id': _uid,
            'sender_name': myName,
            'sender_avatar_url': myAvatar,
          },
        );
      }
    } catch (e) { debugPrint('Knock error: $e'); }
  }

  void _handleSuperKnock(Map<String, dynamic> target) {
    HapticFeedback.heavyImpact();
    _submitKnock(target, [], [], isSuper: true).then((_) {
      if (!mounted) return;
      _showKnockCelebration(target, isSuper: true);
    });
  }

  void _showKnockCelebration(Map<String, dynamic> target, {bool isSuper = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _KnockCelebrationOverlay(
        targetName: (target['name'] ?? 'User').toString().split(' ')[0],
        isSuper: isSuper,
        onDone: () {
          entry.remove();
          _backToGrid();
        },
      ),
    );
    overlay.insert(entry);
  }

  void _showParticleOverlay(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ParticleOverlay(onComplete: () {
        entry.remove();
      }),
    );
    overlay.insert(entry);
  }

  bool _isCustomKnock(List answers) {
    if (answers.isEmpty) return true;
    final firstQ = answers.first['question'].toString();
    for (final qList in _kInterestQuestions.values) {
      if (qList.any((q) => q['question'] == firstQ)) return false;
    }
    if (_kDefaultQuestions.any((q) => q['question'] == firstQ)) return false;
    return true;
  }

  Map<String, dynamic>? _findQuestionData(String questionText) {
    for (final qList in _kInterestQuestions.values) {
      for (final q in qList) {
        if (q['question'] == questionText) return q;
      }
    }
    for (final q in _kDefaultQuestions) {
      if (q['question'] == questionText) return q;
    }
    return null;
  }

  bool _isSettingsOpening = false;

  void _showKnockSettings(BuildContext context) async {
    if (_uid == null || _isSettingsOpening) return;
    _isSettingsOpening = true;

    final initialVis = _myProfile?['visibility']?.toString() ?? 'active';
    KnockMode currentMode = initialVis == 'inactive' ? KnockMode.inactive : KnockMode.active;
    List<Map<String, dynamic>> kqs = [];
    int totalKnocksReceived = 0;
    int knocksAccepted = 0;

    try {
      final r = await Supabase.instance.client
          .from('profiles')
          .select('visibility,knock_questions')
          .eq('id', _uid!)
          .maybeSingle();
      if (r != null) {
        final vis = r['visibility']?.toString() ?? 'inactive';
        currentMode = vis == 'active' ? KnockMode.active : KnockMode.inactive;
        final raw = r['knock_questions'];
        if (raw != null) {
          try { kqs = (raw as List).map((q) => Map<String, dynamic>.from(q as Map)).toList(); } catch (e) { print("Error parsing questions: $e"); }
        }
      }

      final statsRes = await Supabase.instance.client
          .from('requests')
          .select('status')
          .eq('target_id', _uid!);
      
      totalKnocksReceived = statsRes.length;
      knocksAccepted = statsRes.where((k) => k['status'] == 'approved').length;

    } catch (e) { print("Error in loadMyProfile: $e"); }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.92,
              decoration: BoxDecoration(
                color: _deep,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                border: Border(top: BorderSide(color: _orange.withValues(alpha: 0.3), width: 1.5)),
                boxShadow: [
                  BoxShadow(color: _orange.withValues(alpha: 0.15), blurRadius: 40, spreadRadius: 5, offset: const Offset(0, -10)),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -100, right: -50,
                    child: Container(
                      width: 250, height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [_orange.withValues(alpha: 0.1), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(width: 48, height: 5,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(height: 20),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFFF3060), _orange]),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: _orange.withValues(alpha: 0.4), blurRadius: 12)],
                              ),
                              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Knock Studio',
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                                Text('Control how others connect with you',
                                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
                                child: _KnockStatsBar(total: totalKnocksReceived, accepted: knocksAccepted),
                              ),
                              const SizedBox(height: 32),

                              // ── Visibility ──
                              Row(
                                children: [
                                  const Icon(Icons.visibility_rounded, color: _orange, size: 18),
                                  const SizedBox(width: 8),
                                  _SettingsLabel('DISCOVERABILITY MODE'),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(child: _VisBtn(
                                    label: 'Active',
                                    sub: 'Visible & Open',
                                    icon: Icons.bolt_rounded,
                                    selected: currentMode == KnockMode.active,
                                    selColor: _orange,
                                    onTap: () {
                                       setModalState(() => currentMode = KnockMode.active);
                                       if (_uid != null) {
                                         Supabase.instance.client.from('profiles').update({
                                           'visibility': 'active',
                                           'visibility_updated_at': DateTime.now().toUtc().toIso8601String(),
                                         }).eq('id', _uid!);
                                       }
                                     },
                                  )),
                                  const SizedBox(width: 12),
                                  Expanded(child: _VisBtn(
                                    label: 'Inactive',
                                    sub: 'Hidden',
                                    icon: Icons.snooze_rounded,
                                    selected: currentMode == KnockMode.inactive,
                                    selColor: Colors.white60,
                                    onTap: () {
                                      setModalState(() => currentMode = KnockMode.inactive);
                                      if (_uid != null) {
                                        Supabase.instance.client.from('profiles').update({
                                          'visibility': 'inactive',
                                          'visibility_updated_at': DateTime.now().toUtc().toIso8601String(),
                                        }).eq('id', _uid!);
                                      }
                                    },
                                  )),
                                ],
                              ),
                              const SizedBox(height: 32),



                              // ── Knock Questions Builder ──
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: _orange.withValues(alpha: 0.2), shape: BoxShape.circle),
                                    child: const Icon(Icons.quiz_rounded, color: _orange, size: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  _SettingsLabel('KNOCK GATEWAY QUESTIONS'),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kqs.length == 5 ? Colors.red.withValues(alpha: 0.2) : _orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text('${kqs.length}/5',
                                      style: GoogleFonts.outfit(
                                        color: kqs.length == 5 ? Colors.redAccent : _orange, 
                                        fontSize: 12, fontWeight: FontWeight.w800
                                      )
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Build your custom gateway. Users must answer these to knock your profile.',
                                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, height: 1.4)),
                              const SizedBox(height: 16),

                              // existing questions
                              ...kqs.asMap().entries.map((e) {
                                final i = e.key;
                                final kq = e.value;
                                final isMCQ = kq['question_type'] == 'mcq';
                                final isSlider = kq['question_type'] == 'slider';
                                
                                IconData typeIcon = Icons.short_text_rounded;
                                Color typeColor = Colors.blueAccent;
                                if (isMCQ) { typeIcon = Icons.list_alt_rounded; typeColor = Colors.purpleAccent; }
                                else if (isSlider) { typeIcon = Icons.tune_rounded; typeColor = Colors.greenAccent; }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.02),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _orange.withValues(alpha: 0.3)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Stack(
                                      children: [
                                        // Left accent bar
                                        Positioned(
                                          left: 0, top: 0, bottom: 0, width: 4,
                                          child: Container(color: _orange),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16).copyWith(left: 20),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Icon(typeIcon, color: typeColor, size: 16),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(kq['question'] ?? '',
                                                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () => setModalState(() => kqs.removeAt(i)),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                                                      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              
                                              if (isMCQ && kq['options'] != null) ...[
                                                const SizedBox(height: 12),
                                                Wrap(
                                                  spacing: 8, runSpacing: 8,
                                                  children: (kq['options'] as List).map((opt) => Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.05),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                                    ),
                                                    child: Text(opt.toString(), style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
                                                  )).toList(),
                                                ),
                                              ],
                                              
                                              const SizedBox(height: 14),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black26,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.star_rounded, color: _orange, size: 14),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        kq['my_answer']?.toString().isNotEmpty == true 
                                                          ? 'Your Answer: ${kq['my_answer']}' 
                                                          : 'No benchmark answer set',
                                                        style: GoogleFonts.outfit(
                                                          color: kq['my_answer']?.toString().isNotEmpty == true ? _orange : Colors.white30,
                                                          fontSize: 13,
                                                          fontStyle: kq['my_answer']?.toString().isNotEmpty == true ? FontStyle.normal : FontStyle.italic
                                                        ),
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
                                  ),
                                ).animate().fadeIn().slideY(begin: 0.2, end: 0, duration: 300.ms);
                              }),

                              // Custom Question Builder
                              if (kqs.length < 5) ...[
                                const SizedBox(height: 10),
                                _CustomQuestionBuilder(
                                  onAdd: (q) => setModalState(() => kqs.add(q)),
                                ),
                              ],
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),

                      // ── Save Button ──
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        decoration: BoxDecoration(
                          color: _deep,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -5))],
                        ),
                        child: GestureDetector(
                          onTap: () async {
                            try {
                              String visVal = 'inactive';
                              if (currentMode == KnockMode.active) visVal = 'active';
                              if (currentMode == KnockMode.invisible) visVal = 'invisible';

                              await Supabase.instance.client.from('profiles').update({
                                'visibility': visVal,
                                'knock_questions': kqs,
                                'visibility_updated_at': DateTime.now().toUtc().toIso8601String(),
                              }).eq('id', _uid!);
                              
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.white),
                                      const SizedBox(width: 12),
                                      Text('Studio settings saved securely', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF00E676),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 10,
                                ));
                              }
                              await _loadMyProfile();
                            } catch (e) { debugPrint('Save settings: $e'); }
                          },
                          child: Container(
                            width: double.infinity, height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF3060), _orange],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: _orange.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
                                BoxShadow(color: const Color(0xFFFF3060).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Text('Save Studio Settings',
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) => _isSettingsOpening = false);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID VIEW — PREMIUM LOWKEY DARK REDESIGN
// ─────────────────────────────────────────────────────────────────────────────
class _GridView extends StatelessWidget {
  final Map<String, dynamic>? myProfile;
  final bool isLoading;
  final List<Map<String, dynamic>> activeUsers, inactiveUsers;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic>) onSelect;
  final VoidCallback onRandom, onSettings, onShowKnocks;
  final int pendingKnocksCount;

  const _GridView({
    this.myProfile,
    required this.isLoading, required this.activeUsers,
    required this.inactiveUsers, required this.onRefresh,
    required this.onSelect, required this.onRandom, required this.onSettings,
    required this.onShowKnocks, required this.pendingKnocksCount,
  });

  static const _orangeAcc = Color(0xFFFF5C00);
  static const _darkBg = Color(0xFF080808);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          // ── Premium Dark Background (No Image) ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.8),
                  radius: 1.2,
                  colors: [Color(0xFF151010), Color(0xFF080808)],
                ),
              ),
            ),
          ),
          
          // ── Main Content ──
          SafeArea(
            child: RefreshIndicator(
              color: Colors.white,
              backgroundColor: _orangeAcc,
              onRefresh: onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context)),
                  if (isLoading)
                    SliverFillRemaining(child: _buildLoading())
                  else if (activeUsers.isEmpty && inactiveUsers.isEmpty)
                    SliverFillRemaining(child: _buildEmpty())
                  else ...[
                    if (activeUsers.isNotEmpty) ...[
                      SliverToBoxAdapter(child: _sectionHeader('ACTIVE', activeUsers.length, Icons.stars_rounded)),
                      SliverToBoxAdapter(child: _buildActiveRow()),
                    ],
                    if (inactiveUsers.isNotEmpty) ...[
                      SliverToBoxAdapter(child: const SizedBox(height: 10)),
                      SliverToBoxAdapter(child: _sectionHeader('INACTIVE', inactiveUsers.length, Icons.grid_view_rounded)),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: _buildInactiveGrid(),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 140)),
                  ],
                ],
              ),
            ),
          ),
          
          // ── Top Left Notification Badge ──
          if (pendingKnocksCount > 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: GestureDetector(
                onTap: onShowKnocks,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _orangeAcc,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _orangeAcc.withValues(alpha: 0.4), blurRadius: 10)],
                  ),
                  child: Center(child: Text('$pendingKnocksCount', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1.seconds),
              ),
            ),

          // ── Settings Icon ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: GestureDetector(
              onTap: onSettings,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
                child: const Icon(Icons.settings_suggest_rounded, color: Colors.white70, size: 24),
              ),
            ),
          ),

          // ── Deploy Random — Bottom Bar ──
          Positioned(
            bottom: 30, left: 24, right: 24,
            child: _buildRandomLuckBtn(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EXPLORE', style: GoogleFonts.inter(
            color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: locationService.activeDistrictNotifier,
            builder: (_, loc, __) {
              final disp = loc.isNotEmpty ? loc : 'Jhansi';
              return GestureDetector(
                onTap: () { HapticFeedback.heavyImpact(); showLocationSearchSheet(context); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: _orangeAcc, size: 16),
                      const SizedBox(width: 8),
                      Text('Engaging in $disp', style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION HEADERS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _sectionHeader(String title, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          Icon(icon, color: _orangeAcc, size: 18),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.outfit(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ROW LISTS & GRIDS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildActiveRow() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: activeUsers.length,
        itemBuilder: (context, i) {
          final p = activeUsers[i];
          return _AvatarTile(profile: p, index: i, onTap: onSelect, isActive: true);
        },
      ),
    );
  }

  Widget _buildInactiveGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8, // Adjust for image+name
      ),
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final p = inactiveUsers[i];
          return _GridTileItem(profile: p, index: i, onTap: onSelect);
        },
        childCount: inactiveUsers.length,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMPTY / LOADING STATES
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.auto_awesome, color: _orangeAcc, size: 48),
      const SizedBox(height: 16),
      Text('Quiet night here...', style: GoogleFonts.outfit(
        color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
    ]));
  }

  Widget _buildLoading() {
    return SkeletonLoaders.profileGridSkeleton();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEPLOY RANDOM — BOTTOM BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildRandomLuckBtn() {
    return GestureDetector(
      onTap: onRandom,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E1E), Color(0xFF101010)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 15, offset: const Offset(0, 10)),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container()
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 3000.ms, color: Colors.white.withValues(alpha: 0.05), size: 0.2),
              ),
              Row(
                children: [
                  const SizedBox(width: 16),
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: _orangeAcc.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _orangeAcc.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.casino_rounded, color: _orangeAcc, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Random Luck', style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        Text('Dare fate. Discover more.', style: GoogleFonts.outfit(
                          color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w400)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 18),
                  const SizedBox(width: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR TILE — Active Users (Horizontal Row)
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarTile extends StatelessWidget {
  final Map<String, dynamic> profile;
  final int index;
  final void Function(Map<String, dynamic>) onTap;
  final bool isActive;
  
  const _AvatarTile({required this.profile, required this.index, required this.onTap, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final name = (profile['name'] ?? 'User').toString().split(' ')[0];
    final url  = profile['avatar_url']?.toString() ?? '';
    final double size = 90;

    return GestureDetector(
      onTap: () { HapticFeedback.mediumImpact(); onTap(profile); },
      child: Container(
        width: size + 20,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size, height: size,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8A00), Color(0xFFFF5C00)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF5C00).withValues(alpha: 0.4), blurRadius: 15)],
                  ),
                  child: ClipOval(
                    child: url.isNotEmpty
                        ? Image(image: _getSafeImageProvider(url), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback())
                        : _fallback(),
                  ),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5C00),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF080808), width: 3),
                    ),
                    child: const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(name, style: GoogleFonts.outfit(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ).animate(key: ValueKey('av_${profile['id']}'))
      .fadeIn(duration: 400.ms, delay: (index * 50).ms)
      .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: (index * 50).ms, curve: Curves.easeOutCubic);
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: const Center(child: Icon(Icons.person, color: Colors.white24, size: 40)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID TILE — Inactive Users (Grid)
// ─────────────────────────────────────────────────────────────────────────────
class _GridTileItem extends StatelessWidget {
  final Map<String, dynamic> profile;
  final int index;
  final void Function(Map<String, dynamic>) onTap;
  
  const _GridTileItem({required this.profile, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (profile['name'] ?? 'User').toString().split(' ')[0];
    final url  = profile['avatar_url']?.toString() ?? '';

    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(profile); },
      child: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: SizedBox(
                width: 60, height: 60,
                child: url.isNotEmpty
                    ? Image(image: _getSafeImageProvider(url), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback())
                    : _fallback(),
              ),
            ),
            const SizedBox(height: 12),
            Text(name, style: GoogleFonts.outfit(
              color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ).animate(key: ValueKey('grid_${profile['id']}'))
      .fadeIn(duration: 400.ms, delay: (index * 40).ms)
      .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 400.ms, delay: (index * 40).ms, curve: Curves.easeOutCubic);
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFF151515),
      child: const Center(child: Icon(Icons.person, color: Colors.white12, size: 30)),
    );
  }
}


// COMPATIBILITY COMPARISON PAGE — LUXURIOUS HOLOGRAPHIC GLASS REDESIGN
// ═══════════════════════════════════════════════════════════════════════════════

class _SplitScreen extends StatefulWidget {
  final Map<String, dynamic>? myProfile, target;
  final bool isRandom, isSpinning;
  final List<Map<String, dynamic>> allProfiles;
  final int compat;
  final Map<String, double> compatCategories;
  final List<String> topReasons;
  final String connectionHint;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic>) onKnock, onSuperKnock;
  final List<Map<String, dynamic>> Function(Map<String, dynamic>) buildQuestions;

  const _SplitScreen({
    required this.myProfile, required this.target, required this.isRandom,
    required this.isSpinning, required this.allProfiles, required this.compat,
    required this.compatCategories, required this.topReasons,
    required this.connectionHint,
    required this.onBack, required this.onKnock, required this.onSuperKnock, required this.buildQuestions,
  });

  @override
  State<_SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<_SplitScreen> {
  static const _bgDeep = Color(0xFF030305);
  static const _aurora1 = Color(0xFF5EE7DF);
  static const _aurora2 = Color(0xFFB490CA);
  static const _aurora3 = Color(0xFFFFD194);

  String _lookingForDisplay(dynamic lf) {
    if (lf == null) return '—';
    if (lf is List) {
      if (lf.isEmpty) return '—';
      return lf.take(2).join(', ');
    }
    return lf.toString().isEmpty ? '—' : lf.toString();
  }

  String _langDisplay(dynamic langs) {
    if (langs == null) return '—';
    if (langs is List) {
      if (langs.isEmpty) return '—';
      return langs.take(3).join(', ');
    }
    return langs.toString().isEmpty ? '—' : langs.toString();
  }

  String _valOr(dynamic v) => (v == null || v.toString().isEmpty) ? '—' : v.toString();

  @override
  Widget build(BuildContext context) {
    if (widget.isRandom && widget.isSpinning) {
      return _GridCarouselSpinner(profiles: widget.allProfiles, targetProfile: widget.target, onBack: widget.onBack);
    }
    if (widget.target == null) return const SizedBox();

    final my = widget.myProfile ?? {};
    final th = widget.target!;
    final myName = (my['name'] ?? 'You').toString().split(' ')[0];
    final thName = (th['name'] ?? 'User').toString().split(' ')[0];
    final myUrl  = my['avatar_url']?.toString() ?? '';
    final thUrl  = th['avatar_url']?.toString() ?? '';
    final myAge  = my['age']?.toString() ?? '';
    final thAge  = th['age']?.toString() ?? '';
    final myGender = (my['gender'] ?? '').toString();
    final thGender = (th['gender'] ?? '').toString();
    final myCity = my['city']?.toString() ?? '';
    final thCity = th['city']?.toString() ?? '';

    final rows = <_CmpRowData>[

      _CmpRowData(Icons.track_changes_rounded, 'Intent', _lookingForDisplay(my['looking_for']), _lookingForDisplay(th['looking_for'])),
      _CmpRowData(Icons.directions_run_rounded, 'Fitness', _valOr(my['fitness_routine'] ?? my['exercise']), _valOr(th['fitness_routine'] ?? th['exercise'])),
      _CmpRowData(Icons.vaping_rooms_rounded, 'Smoking', _valOr(my['smoking']), _valOr(th['smoking'])),
      _CmpRowData(Icons.wine_bar_rounded, 'Drinking', _valOr(my['drinking']), _valOr(th['drinking'])),
      _CmpRowData(Icons.eco_rounded, 'Diet', _valOr(my['diet']), _valOr(th['diet'])),
      _CmpRowData(Icons.pets_rounded, 'Pets', _valOr(my['pets']), _valOr(th['pets'])),
      _CmpRowData(Icons.nightlight_round, 'Religion', _valOr(my['religion']), _valOr(th['religion'])),
      _CmpRowData(Icons.language_rounded, 'Languages', _langDisplay(my['languages']), _langDisplay(th['languages'])),
      _CmpRowData(Icons.school_rounded, 'Education', _valOr(my['education']), _valOr(th['education'])),
      _CmpRowData(Icons.auto_awesome_rounded, 'Zodiac', _valOr(my['zodiac']), _valOr(th['zodiac'])),
    ];

    return Scaffold(
      backgroundColor: _bgDeep,
      body: Stack(children: [
        // Luxurious Ambient Background (Holographic Orbs)
        Positioned(top: -100, left: -50, child: Container(
          width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: _aurora2.withValues(alpha: 0.15), blurRadius: 100)]),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).slideY(begin: 0, end: 0.1, duration: 4.seconds)),
        Positioned(bottom: -50, right: -100, child: Container(
          width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: _aurora1.withValues(alpha: 0.1), blurRadius: 150)]),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).slideX(begin: 0, end: -0.1, duration: 5.seconds)),

        SafeArea(child: Column(children: [
          // ── HEADER ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              GestureDetector(onTap: widget.onBack, child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              )),
              const Spacer(),
              Text('VIBE ANALYSIS', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 4)),
              const Spacer(),
              const SizedBox(width: 44),
            ]),
          ),
          // ── SCROLLABLE BODY ──
          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            physics: const BouncingScrollPhysics(),
            children: [
              _DualHeader(
                myName: myName, thName: thName, myUrl: myUrl, thUrl: thUrl,
                myAge: myAge, thAge: thAge, myGender: myGender, thGender: thGender,
                myCity: myCity, thCity: thCity, score: widget.compat,
                hint: widget.connectionHint,
              ),
              const SizedBox(height: 48),

              Text('DIMENSIONAL MATCH', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 3)),
              const SizedBox(height: 16),

              // Data Shards (Rows)
              Column(children: rows.asMap().entries.map((e) =>
                _CmpRow(data: e.value, index: e.key)).toList()),
              const SizedBox(height: 24),
              
              // Interests Hex
              if (_parseListExplore(my['interests']).isNotEmpty || _parseListExplore(th['interests']).isNotEmpty)
                _InterestsCmp(
                  myI: _parseListExplore(my['interests']),
                  thI: _parseListExplore(th['interests']),
                ),
              const SizedBox(height: 32),

              // Glass HUD
              _CompatFooter(cats: widget.compatCategories, reasons: widget.topReasons),
              const SizedBox(height: 24),
            ],
          )),
        ])),
        // ── ACTION BAR ──
        Positioned(bottom: 0, left: 0, right: 0, child: Container(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 30),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [_bgDeep, Colors.transparent]),
          ),
          child: _ActionBar(target: th, onBack: widget.onBack, onKnock: widget.onKnock, onSuperKnock: widget.onSuperKnock),
        )),
      ]),
    );
  }
}

// ── DUAL PROFILE HEADER & SYNC CORE (Symmetrical Glass) ───────────────
class _DualHeader extends StatelessWidget {
  final String myName, thName, myUrl, thUrl, myAge, thAge;
  final String myGender, thGender, myCity, thCity;
  final int score;
  final String hint;
  const _DualHeader({required this.myName, required this.thName, required this.myUrl,
    required this.thUrl, required this.myAge, required this.thAge,
    required this.myGender, required this.thGender, required this.myCity,
    required this.thCity, required this.score, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Me (Mirrored Left)
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40)],
          ),
          child: Column(children: [
            _GlassAv(url: myUrl, ringColor: const Color(0xFF00FFCC)),
            const SizedBox(height: 16),
            Text(myName, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            if (myAge.isNotEmpty) Text('$myAge \u00b7 $myGender', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
            if (myCity.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on, color: Colors.white30, size: 10),
                const SizedBox(width: 4),
                Flexible(child: Text(myCity, style: GoogleFonts.outfit(color: Colors.white30, fontSize: 9), overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ]),
        )),
        
        // Symmetrical Center Core
        SizedBox(width: 140, height: 140, child: _PulsingCore(score: score)),
        
        // Them (Mirrored Right)
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40)],
          ),
          child: Column(children: [
            _GlassAv(url: thUrl, ringColor: const Color(0xFFFF0055)),
            const SizedBox(height: 16),
            Text(thName, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            if (thAge.isNotEmpty) Text('$thAge \u00b7 $thGender', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
            if (thCity.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on, color: Colors.white30, size: 10),
                const SizedBox(width: 4),
                Flexible(child: Text(thCity, style: GoogleFonts.outfit(color: Colors.white30, fontSize: 9), overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ]),
        )),
      ]),
      if (hint.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 24.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF00FFCC).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.psychology_rounded, color: Color(0xFF00FFCC), size: 16),
              const SizedBox(width: 8),
              Flexible(child: Text(hint, style: GoogleFonts.outfit(color: const Color(0xFF00FFCC), fontSize: 11, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500))),
            ]),
          ),
        ),
    ]).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0, duration: 800.ms, curve: Curves.easeOutQuart);
  }
}

class _GlassAv extends StatelessWidget {
  final String url;
  final Color ringColor;
  const _GlassAv({required this.url, required this.ringColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80, height: 80, padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [ringColor.withValues(alpha: 0.8), ringColor.withValues(alpha: 0.2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: ringColor.withValues(alpha: 0.3), blurRadius: 20)],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: const Color(0xFF0D0D14),
          image: url.isNotEmpty ? DecorationImage(image: _getSafeImageProvider(url), fit: BoxFit.cover) : null,
        ),
        child: url.isEmpty ? const Icon(Icons.person, color: Colors.white30, size: 30) : null,
      ),
    );
  }
}

// ── PULSING CORE (3D Sync Rate) ─────────────────────────────────────────────
class _PulsingCore extends StatelessWidget {
  final int score;
  const _PulsingCore({required this.score});

  @override
  Widget build(BuildContext context) {
    Color coreColor = const Color(0xFF9D00FF); // Bright Purple
    if (score >= 80) { coreColor = const Color(0xFFCCFF00); } // Lime Green
    else if (score >= 50) { coreColor = const Color(0xFFFF5500); } // Vivid Orange
    else if (score < 30) { coreColor = const Color(0xFFFF007F); } // Hot Pink

    return Stack(alignment: Alignment.center, children: [
      // Connecting beams radiating outwards
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Expanded(child: Container(height: 4, decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.transparent, coreColor]),
          boxShadow: [BoxShadow(color: coreColor, blurRadius: 15)],
        ))),
        const SizedBox(width: 80),
        Expanded(child: Container(height: 4, decoration: BoxDecoration(
          gradient: LinearGradient(colors: [coreColor, Colors.transparent]),
          boxShadow: [BoxShadow(color: coreColor, blurRadius: 15)],
        ))),
      ]).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 800.ms),
      
      // Outer glow rings
      Container(
        width: 130, height: 130,
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: coreColor.withValues(alpha: 0.4), blurRadius: 30)]),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1200.ms, curve: Curves.easeInOut),
      
      // Core glass orb
      Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: coreColor.withValues(alpha: 0.15),
          border: Border.all(color: coreColor, width: 3),
          boxShadow: [BoxShadow(color: coreColor.withValues(alpha: 0.5), blurRadius: 20)],
        ),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$score%', style: GoogleFonts.outfit(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
          Text('SYNC', style: GoogleFonts.outfit(color: coreColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3)),
        ])),
      ),
    ]).animate().fadeIn(duration: 800.ms, delay: 200.ms).scale(begin: const Offset(0.2, 0.2), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 1500.ms);
  }
}

// ── COMPARISON ROW (Athletic Dynamic Shards) ─────────────────────
class _CmpRow extends StatelessWidget {
  final _CmpRowData data;
  final int index;
  const _CmpRow({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final isMatch = data.isMatch;
    final isMissing = data.isMissing;
    
    // Vibrant match highlights
    final matchColor = isMatch ? const Color(0xFFCCFF00) : (isMissing ? Colors.white12 : const Color(0xFFFF007F));

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          // Center Label
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(data.label.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 1.5)),
            if (isMatch) ...[
              const SizedBox(width: 8),
              Transform(
                transform: Matrix4.skewX(-0.2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFCCFF00), borderRadius: BorderRadius.circular(4)),
                  child: Text('MATCH', style: GoogleFonts.outfit(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                ),
              )
            ]
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              // My Value
              Expanded(child: Transform(
                transform: Matrix4.skewX(-0.1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isMatch ? const Color(0xFFCCFF00).withValues(alpha: 0.15) : (isMissing ? Colors.transparent : Colors.white.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isMatch ? const Color(0xFFCCFF00) : (isMissing ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2)), width: isMatch ? 2 : 1),
                  ),
                  child: Text(data.myVal == '—' ? 'UNKNOWN' : data.myVal, textAlign: TextAlign.center, style: GoogleFonts.outfit(color: data.myVal == '—' ? Colors.white38 : Colors.white, fontSize: 14, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
                ),
              )),
              
              // Symmetrical Center Connector
              SizedBox(width: 60, child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isMatch)
                    Container(height: 4, width: 60, decoration: BoxDecoration(
                      color: const Color(0xFFCCFF00),
                      boxShadow: [BoxShadow(color: const Color(0xFFCCFF00), blurRadius: 15)],
                    )).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 500.ms),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D14),
                      shape: BoxShape.circle,
                      border: Border.all(color: matchColor, width: 2),
                      boxShadow: isMatch ? [BoxShadow(color: const Color(0xFFCCFF00).withValues(alpha: 0.5), blurRadius: 12)] : [],
                    ),
                    child: Icon(data.icon, color: isMatch ? const Color(0xFFCCFF00) : (isMissing ? Colors.white24 : Colors.white), size: 18),
                  ),
                ],
              )),
              
              // Their Value
              Expanded(child: Transform(
                transform: Matrix4.skewX(-0.1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isMatch ? const Color(0xFFCCFF00).withValues(alpha: 0.15) : (isMissing ? Colors.transparent : Colors.white.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isMatch ? const Color(0xFFCCFF00) : (isMissing ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2)), width: isMatch ? 2 : 1),
                  ),
                  child: Text(data.thVal == '—' ? 'UNKNOWN' : data.thVal, textAlign: TextAlign.center, style: GoogleFonts.outfit(color: data.thVal == '—' ? Colors.white38 : Colors.white, fontSize: 14, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
                ),
              )),
            ],
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 400.ms, delay: Duration(milliseconds: 50 * index + 100))
      .slideX(begin: index % 2 == 0 ? -0.1 : 0.1, end: 0, duration: 600.ms, curve: Curves.elasticOut, delay: Duration(milliseconds: 50 * index + 100));
  }
}

// ── INTERESTS COMPARISON (Funky Sticker Wall) ───────────────────────────────────
class _InterestsCmp extends StatelessWidget {
  final List<String> myI, thI;
  const _InterestsCmp({required this.myI, required this.thI});

  @override
  Widget build(BuildContext context) {
    final shared = myI.where(thI.contains).toSet();
    if (shared.length < 2) {
      final combined = {...myI, ...thI}.toList()..shuffle();
      for (final item in combined) {
        shared.add(item);
        if (shared.length >= 2) break;
      }
    }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: shared.isNotEmpty ? const Color(0xFFCCFF00).withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: shared.isNotEmpty ? const Color(0xFFCCFF00) : Colors.white.withValues(alpha: 0.1), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.local_fire_department_rounded, color: shared.isNotEmpty ? const Color(0xFFCCFF00) : Colors.white54, size: 24),
          const SizedBox(width: 10),
          Text('COMMON GROUND', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
          const Spacer(),
          if (shared.isNotEmpty) Transform(
            transform: Matrix4.skewX(-0.2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFCCFF00), borderRadius: BorderRadius.circular(6)),
              child: Text('${shared.length} MATCHES', style: GoogleFonts.outfit(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 800.ms),
        ]),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12, runSpacing: 12,
          children: {...myI, ...thI}.toSet().map((i) {
            final isShared = shared.contains(i);
            return Transform.rotate(
              angle: isShared ? (i.length % 2 == 0 ? 0.05 : -0.05) : 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isShared ? const Color(0xFFCCFF00) : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isShared ? Colors.transparent : Colors.white.withValues(alpha: 0.1), width: 2),
                  boxShadow: isShared ? [BoxShadow(color: const Color(0xFFCCFF00).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))] : [],
                ),
                child: Text(i.toUpperCase(), style: GoogleFonts.outfit(
                  color: isShared ? Colors.black : Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                )),
              ).animate(target: isShared ? 1 : 0).fadeIn(duration: 800.ms),
            );
          }).toList(),
        ),
      ]),
    ).animate().fadeIn(duration: 800.ms, delay: 600.ms).slideY(begin: 0.1, end: 0, duration: 800.ms, curve: Curves.elasticOut);
  }
}

// ── COMPATIBILITY FOOTER (Athletic Vibe Check) ──────────────────────────────────
class _CompatFooter extends StatelessWidget {
  final Map<String, double> cats;
  final List<String> reasons;
  const _CompatFooter({required this.cats, required this.reasons});

  @override
  Widget build(BuildContext context) {
    // Generate some contextual icebreakers based on reasons
    final List<String> starters = [];
    if (reasons.isNotEmpty) {
      if (reasons.isNotEmpty) { starters.add("I noticed we both like ${reasons[0].split(' ').last}..."); }
      if (reasons.length >= 2) { starters.add("So about ${reasons[1]}..."); }
      if (reasons.length >= 3) { starters.add("What's your take on ${reasons[2]}?"); }
      if (starters.isEmpty) { starters.add("What's your favorite thing to do on a weekend?"); }
    } else {
      starters.add("What's your favorite thing to do on a weekend?");
      starters.add("Any exciting plans coming up?");
      starters.add("What's the best thing that happened to you this week?");
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (reasons.isNotEmpty) ...[
          Row(children: [
            const Icon(Icons.flash_on_rounded, color: Color(0xFFCCFF00), size: 22),
            const SizedBox(width: 8),
            Text('WHY YOU CLICK', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
          ]),
          const SizedBox(height: 20),
          ...reasons.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12),
            child: Transform(
                transform: Matrix4.skewX(-0.05),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFF00).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCCFF00).withValues(alpha: 0.3), width: 2),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('0${e.key + 1}', style: GoogleFonts.outfit(color: const Color(0xFFCCFF00), fontSize: 14, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(e.value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          )),
          const SizedBox(height: 24),
          Container(height: 2, color: Colors.white10),
          const SizedBox(height: 24),
        ],
        
        // AI Conversation Starters
        Row(children: [
          const Icon(Icons.chat_bubble_rounded, color: Color(0xFFFF007F), size: 22),
          const SizedBox(width: 8),
          Text('CONVERSATION STARTERS', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
        ]),
        const SizedBox(height: 16),
        ...starters.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFF007F).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF007F).withValues(alpha: 0.4), width: 2),
            ),
            child: Text('"$s"', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic)),
          ),
        )),
        
        const SizedBox(height: 24),
        Container(height: 2, color: Colors.white10),
        const SizedBox(height: 24),

        if (cats.isNotEmpty) ...[
          Row(children: [
            const Icon(Icons.insights_rounded, color: Color(0xFF9D00FF), size: 22),
            const SizedBox(width: 8),
            Text('ALIGNMENT PROFILE', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
          ]),
          const SizedBox(height: 24),
          _VibeCheckBars(cats: cats),
        ],
      ]),
    ).animate().fadeIn(duration: 800.ms, delay: 500.ms).slideY(begin: 0.1, end: 0, duration: 800.ms, curve: Curves.elasticOut);
  }
}

// ── VIBE CHECK BARS (Simple Progress Bars) ──────────────────────────────────
class _VibeCheckBars extends StatelessWidget {
  final Map<String, double> cats;
  const _VibeCheckBars({required this.cats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: cats.entries.map((e) {
        final val = (e.value / 100).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, letterSpacing: 1)),
                  Text('${e.value.toInt()}%', style: GoogleFonts.outfit(color: const Color(0xFFCCFF00), fontSize: 14, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        height: 8,
                        width: constraints.maxWidth * val,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFF00),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [BoxShadow(color: const Color(0xFFCCFF00).withValues(alpha: 0.3), blurRadius: 6)],
                        ),
                      ).animate().scaleX(begin: 0, end: 1, duration: 1000.ms, curve: Curves.easeOutQuart, alignment: Alignment.centerLeft);
                    }
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── 3D PARALLAX GRID SPINNER (Intriguing UI) ──────────────────────────────────
class _GridCarouselSpinner extends StatefulWidget {
  final List<Map<String, dynamic>> profiles;
  final Map<String, dynamic>? targetProfile;
  final VoidCallback onBack;
  const _GridCarouselSpinner({required this.profiles, required this.targetProfile, required this.onBack});

  @override
  State<_GridCarouselSpinner> createState() => _GridCarouselSpinnerState();
}

class _GridCarouselSpinnerState extends State<_GridCarouselSpinner> with TickerProviderStateMixin {
  late AnimationController _scrollCtrl;
  late AnimationController _zoomCtrl;
  
  final List<ScrollController> _cols = List.generate(3, (_) => ScrollController());
  
  @override
  void initState() {
    super.initState();
    _scrollCtrl = AnimationController(vsync: this, duration: 4.seconds)..addListener(_onTick)..forward();
    _zoomCtrl = AnimationController(vsync: this, duration: 1.seconds);
    
    // Trigger zoom in after scrolling finishes
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) _zoomCtrl.forward();
    });
  }

  void _onTick() {
    if (widget.profiles.isEmpty) return;
    final t = _scrollCtrl.value;
    
    // Slow down easing curve: fast at start, extremely slow at end
    final speed = t < 0.7 ? 1.0 : (1.0 - (t - 0.7) / 0.3).clamp(0.01, 1.0);
    
    for (int i = 0; i < 3; i++) {
      if (!_cols[i].hasClients) continue;
      final max = _cols[i].position.maxScrollExtent;
      if (max <= 0) continue;
      
      // Center column scrolls up, side columns scroll down
      final dir = (i == 1) ? 1.0 : -1.0;
      final baseSpeed = 120.0;
      final delta = baseSpeed * speed * dir;
      
      final next = (_cols[i].offset + delta);
      // Loop scroll
      if (next > max) {
        _cols[i].jumpTo(next - max);
      } else if (next < 0) {
        _cols[i].jumpTo(max + next);
      } else {
        _cols[i].jumpTo(next);
      }
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _zoomCtrl.dispose();
    for (var c in _cols) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profiles.isEmpty) return const SizedBox();
    
    // Multiply profiles to create an infinite scroll effect
    final display = [...widget.profiles, ...widget.profiles, ...widget.profiles, ...widget.profiles, ...widget.profiles];
    
    return Scaffold(
      backgroundColor: const Color(0xFF030508),
      body: Stack(children: [
        // Grid
        AnimatedBuilder(
          animation: _zoomCtrl,
          builder: (ctx, child) {
            final z = _zoomCtrl.value;
            // Scale up dramatically and blur the background as we zoom into the target
            return Transform.scale(
              scale: 1.0 + (z * 3.0),
              child: Opacity(
                opacity: 1.0 - (z * 0.8),
                child: child,
              ),
            );
          },
          child: Row(children: [
            for (int i = 0; i < 3; i++)
              Expanded(
                child: ListView.builder(
                  controller: _cols[i],
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: display.length,
                  itemBuilder: (ctx, idx) {
                    final p = display[(idx + (i * 3)) % display.length];
                    return _GridCard(profile: p, index: idx);
                  },
                ),
              ),
          ]),
        ),
        
        // Dark Vignette
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Colors.transparent, const Color(0xFF030508).withValues(alpha: 0.9)],
                radius: 0.8,
              ),
            ),
          ),
        ),

        // Header
        SafeArea(
          child: AnimatedBuilder(
            animation: _zoomCtrl,
            builder: (ctx, child) => Opacity(opacity: 1.0 - _zoomCtrl.value, child: child),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                GestureDetector(onTap: widget.onBack, child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                )),
                const Spacer(),
                Text('SEARCHING MATRICE...', style: GoogleFonts.outfit(color: const Color(0xFFE2B0FF), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 3)),
                const Spacer(),
                const SizedBox(width: 40),
              ]),
            ),
          ),
        ),

        // Target Reveal Overlay
        if (widget.targetProfile != null)
          AnimatedBuilder(
            animation: _zoomCtrl,
            builder: (ctx, child) {
              if (_zoomCtrl.value == 0) return const SizedBox();
              return Opacity(
                opacity: _zoomCtrl.value,
                child: Transform.scale(
                  scale: 0.8 + (_zoomCtrl.value * 0.2),
                  child: Center(
                    child: _TargetRevealCard(profile: widget.targetProfile!),
                  ),
                ),
              );
            },
          ),
      ]),
    );
  }
}

class _GridCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final int index;
  const _GridCard({required this.profile, required this.index});

  @override
  Widget build(BuildContext context) {
    final url = profile['avatar_url']?.toString() ?? '';
    final name = (profile['name'] ?? 'User').toString().split(' ')[0];
    final age = profile['age']?.toString() ?? '';
    final lf = profile['looking_for'];
    String intent = '';
    if (lf is List && lf.isNotEmpty) intent = lf.first.toString();
    
    // Staggered margin for dynamic look
    final m = index % 2 == 0 ? const EdgeInsets.fromLTRB(8, 16, 16, 16) : const EdgeInsets.fromLTRB(16, 16, 8, 16);

    return Container(
      height: 200,
      margin: m,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0D121F),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Stack(fit: StackFit.expand, children: [
        if (url.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF151515), child: const Center(child: Icon(Icons.person, color: Colors.white12, size: 40)))),
          ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
              if (age.isNotEmpty) Text(age, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10)),
              if (intent.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFB026FF).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
                  child: Text(intent.toUpperCase(), style: GoogleFonts.outfit(color: const Color(0xFFE2B0FF), fontSize: 8, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _TargetRevealCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _TargetRevealCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final url = profile['avatar_url']?.toString() ?? '';
    final name = (profile['name'] ?? 'User').toString().split(' ')[0];
    return Container(
      width: 240, height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00F0FF).withValues(alpha: 0.2), blurRadius: 50, spreadRadius: 10),
          BoxShadow(color: const Color(0xFFB026FF).withValues(alpha: 0.2), blurRadius: 50, spreadRadius: 10, offset: const Offset(0, 20)),
        ],
        image: url.isNotEmpty ? DecorationImage(image: _getSafeImageProvider(url), fit: BoxFit.cover) : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00F0FF), size: 40),
          const SizedBox(height: 12),
          Text('TARGET ACQUIRED', style: GoogleFonts.outfit(color: const Color(0xFF00F0FF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
          Text(name.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ]),
      ),
    );
  }
}


class _ParticleOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const _ParticleOverlay({required this.onComplete});
  @override
  State<_ParticleOverlay> createState() => _ParticleOverlayState();
}

class _ParticleOverlayState extends State<_ParticleOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_Particle> _particles = [];
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _ctrl.addListener(() {
      if (_ctrl.isCompleted) {
        widget.onComplete();
      }
      setState(() {
        for (var p in _particles) {
          p.update();
        }
      });
    });
    
    // Generate particles
    for (int i = 0; i < 100; i++) {
      _particles.add(_Particle(
        x: _rnd.nextDouble() * 400,
        y: _rnd.nextDouble() * 800,
        vx: (_rnd.nextDouble() - 0.5) * 20,
        vy: (_rnd.nextDouble() - 0.5) * 20 - 10,
        color: [Colors.green, Colors.yellow, Colors.pink, Colors.blue][_rnd.nextInt(4)],
        size: _rnd.nextDouble() * 8 + 4,
      ));
    }
    
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ParticlePainter(_particles, 1.0 - _ctrl.value),
        child: Container(),
      ),
    );
  }
}

class _Particle {
  double x, y, vx, vy, size;
  Color color;
  _Particle({required this.x, required this.y, required this.vx, required this.vy, required this.color, required this.size});
  void update() {
    x += vx;
    y += vy;
    vy += 0.5; // gravity
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double opacity;
  _ParticlePainter(this.particles, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      paint.color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}

// ── Action bar ───────────────────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  final Map<String, dynamic> target;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic>) onKnock;
  final void Function(Map<String, dynamic>) onSuperKnock;

  const _ActionBar({required this.target, required this.onBack, required this.onKnock, required this.onSuperKnock});
  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(children: [
        // Reject
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white54, size: 26),
          ),
        ),
        const SizedBox(width: 12),
        // Knock
        Expanded(child: GestureDetector(
          onTap: () => onKnock(target),
          child: Stack(
            children: [
              Container(
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3060), _orange],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: _orange.withValues(alpha: 0.5), blurRadius: 22, offset: const Offset(0, 6))],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.waving_hand_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text('KNOCK', style: GoogleFonts.outfit(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
                ]),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ).animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.02, 1.02), duration: 1200.ms),
        )),
      ]),
    );
  }

  void _showMiniProfile(BuildContext context, Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.62, minChildSize: 0.38, maxChildSize: 0.85,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D12),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(controller: sc, padding: const EdgeInsets.all(20), children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Text(p['name'] ?? 'User',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            if (p['bio']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(p['bio'], style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14, height: 1.5)),
            ],
            if ((p['interests'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 18),
              Text('INTERESTS', style: GoogleFonts.outfit(
                color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6,
                children: (p['interests'] as List).map<Widget>((i) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _orange.withValues(alpha: 0.3)),
                  ),
                  child: Text(i.toString(),
                    style: GoogleFonts.outfit(color: _orange, fontSize: 12, fontWeight: FontWeight.w600)),
                )).toList()),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Data for comparison row ──────────────────────────────────────────────────
class _CmpRowData {
  final IconData icon;
  final String label, myVal, thVal;
  const _CmpRowData(this.icon, this.label, this.myVal, this.thVal);
  bool get isMatch => myVal != '—' && thVal != '—' && myVal.toLowerCase().trim() == thVal.toLowerCase().trim();
  bool get isMissing => myVal == '—' || thVal == '—';
}


// ─────────────────────────────────────────────────────────────────────────────
// SMALL SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  final String url;
  final double size;
  final Color borderColor;
  const _MiniAvatar({required this.url, required this.size, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 10)],
        image: url.isNotEmpty ? DecorationImage(image: _getSafeImageProvider(url), fit: BoxFit.cover) : null,
        color: const Color(0xFF2A2A2A),
      ),
      child: url.isEmpty ? Icon(Icons.person, color: Colors.white54, size: size * 0.4) : null,
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: GoogleFonts.outfit(
        color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
    );
  }
}

class _InterestChips extends StatelessWidget {
  final List<String> interests;
  final Set<String> highlighted;
  const _InterestChips({required this.interests, required this.highlighted});
  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('INTERESTS', style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.25), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
      const SizedBox(height: 5),
      Wrap(spacing: 4, runSpacing: 4,
        children: interests.map((i) {
          final hi = highlighted.contains(i);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: hi ? _orange.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hi ? _orange.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.07),
                width: hi ? 1.5 : 1,
              ),
            ),
            child: Text(i, style: GoogleFonts.outfit(
              color: hi ? _orange : Colors.white38, fontSize: 8, fontWeight: hi ? FontWeight.w700 : FontWeight.w500)),
          );
        }).toList()),
    ]);
  }
}

class _SettingsLabel extends StatelessWidget {
  final String text;
  const _SettingsLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: GoogleFonts.outfit(
      color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2));
  }
}

class _VisBtn extends StatelessWidget {
  final String label, sub;
  final IconData icon;
  final bool selected;
  final Color selColor;
  final VoidCallback onTap;
  const _VisBtn({required this.label, required this.sub, required this.icon,
      required this.selected, required this.selColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? selColor.withValues(alpha: 0.12) : const Color(0xFF181820),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? selColor : Colors.transparent, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? selColor : Colors.white24, size: 24),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.outfit(
            color: selected ? Colors.white : Colors.white38, fontWeight: FontWeight.w700, fontSize: 14)),
          Text(sub, style: GoogleFonts.outfit(
            color: selected ? Colors.white.withValues(alpha: 0.40) : Colors.white.withValues(alpha: 0.20), fontSize: 10)),
        ]),
      ),
    );
  }
}

// ── QUICK SETUP OVERLAY ───────────────────────────────────────────────────────
class _QuickSetupOverlay extends StatefulWidget {
  final Map<String, dynamic> myProfile;
  final Function(Map<String, dynamic>) onComplete;
  const _QuickSetupOverlay({required this.myProfile, required this.onComplete});

  @override
  State<_QuickSetupOverlay> createState() => _QuickSetupOverlayState();
}

class _QuickSetupOverlayState extends State<_QuickSetupOverlay> {

  final _fields = [
    {'key': 'looking_for', 'label': 'Intent (Looking For)', 'type': 'single', 'opts': ProfileConstants.purposeOptions},
    {'key': 'fitness_routine', 'label': 'Fitness Routine', 'type': 'single', 'opts': ['Active', 'Light', 'Rarely', 'Never', 'Prefer not to say']},
    {'key': 'smoking', 'label': 'Smoking', 'type': 'single', 'opts': ['Never', 'Socially', 'Regularly', 'Trying to quit']},
    {'key': 'drinking', 'label': 'Drinking', 'type': 'single', 'opts': ['Never', 'Socially', 'Regularly', 'Trying to quit']},
    {'key': 'diet', 'label': 'Diet', 'type': 'single', 'opts': ['Anything', 'Vegetarian', 'Vegan', 'Pescatarian', 'Keto', 'Other']},
    {'key': 'pets', 'label': 'Pets', 'type': 'single', 'opts': ['Dog', 'Cat', 'Both', 'Other', 'None']},
    {'key': 'religion', 'label': 'Religion', 'type': 'single', 'opts': ['Agnostic', 'Atheist', 'Buddhist', 'Catholic', 'Christian', 'Hindu', 'Jewish', 'Muslim', 'Spiritual', 'Other', 'Prefer not to say']},
    {'key': 'languages', 'label': 'Languages', 'type': 'multi', 'opts': ProfileConstants.languages},
    {'key': 'zodiac', 'label': 'Zodiac', 'type': 'single', 'opts': ProfileConstants.zodiacSigns},
    {'key': 'interests', 'label': 'Interests (Pick up to 5)', 'type': 'multi', 'opts': ProfileConstants.interestCategories.values.expand((v) => v).toList(), 'max': 5},
    {'key': 'personality_traits', 'label': 'Traits (Pick up to 5)', 'type': 'multi', 'opts': ProfileConstants.personalityTraits, 'max': 5},
  ];

  late Map<String, dynamic> _data;
  bool _saving = false;
  late List<Map<String, dynamic>> _missingFields;
  late List<GlobalKey> _itemKeys;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.myProfile);
    _missingFields = _fields.where((f) {
      final val = widget.myProfile[f['key']];
      return val == null || (val is String && val.isEmpty) || (val is List && val.isEmpty);
    }).toList();
    _itemKeys = List.generate(_missingFields.length, (_) => GlobalKey());
  }

  void _scrollToNext(int currentIndex) {
    if (currentIndex + 1 < _itemKeys.length) {
      final key = _itemKeys[currentIndex + 1];
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    }
  }
  Future<void> _save() async {
    for (int i = 0; i < _missingFields.length; i++) {
      final f = _missingFields[i];
      final val = _data[f['key']];
      if (val == null || (val is String && val.isEmpty) || (val is List && val.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please fill: ${f['label']}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
        ));
        if (_itemKeys[i].currentContext != null) {
          Scrollable.ensureVisible(
            _itemKeys[i].currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        }
        return;
      }
    }
    
    // Also double check all _fields just in case
    for (final f in _fields) {
      final val = _data[f['key']];
      if (val == null || (val is String && val.isEmpty) || (val is List && val.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('System error: ${f['label']} is completely missing.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
        ));
        return;
      }
    }

    setState(() => _saving = true);
    
    final payload = <String, dynamic>{};
    for (final f in _fields) {
      final k = f['key'] as String;
      // edit_profile_screen.dart uses 'exercise' for fitness_routine in DB
      if (k == 'fitness_routine') {
        payload['exercise'] = _data[k];
      } else {
        payload[k] = _data[k];
      }
    }
    if (payload['looking_for'] is String) {
      payload['looking_for'] = [payload['looking_for']];
    }
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Send payload to _refresh to optimistically update UI and prevent bounce-back
        await Supabase.instance.client.from('profiles').update(payload).eq('id', user.id);
        widget.onComplete(payload);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Icon(Icons.tune_rounded, color: Color(0xFF00F0FF), size: 40),
              const SizedBox(height: 16),
              Text('CALIBRATE YOUR VIBE', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 8),
              Text('To establish a Vibe Link, our system requires baseline synchronization data. Please complete the missing fields.',
                textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, height: 1.5)),
            ]),
          ),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _missingFields.length,
            itemBuilder: (ctx, i) {
              final f = _missingFields[i];
              final k = f['key'] as String;
              return Container(
                key: _itemKeys[i],
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF080B15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.2)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f['label'] as String, style: GoogleFonts.outfit(color: const Color(0xFF00F0FF), fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (f['type'] == 'single')
                    Wrap(spacing: 8, runSpacing: 8, children: (f['opts'] as List<String>).map((opt) {
                      final sel = _data[k] == opt;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _data[k] = opt);
                          _scrollToNext(i);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFF00F0FF).withValues(alpha: 0.2) : Colors.transparent,
                            border: Border.all(color: sel ? const Color(0xFF00F0FF) : Colors.white24),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(opt, style: GoogleFonts.outfit(color: sel ? const Color(0xFF00F0FF) : Colors.white70, fontSize: 12)),
                        ),
                      );
                    }).toList()),
                  if (f['type'] == 'multi')
                    Wrap(spacing: 8, runSpacing: 8, children: (f['opts'] as List<String>).map((opt) {
                      final list = List<String>.from(_data[k] ?? []);
                      final sel = list.contains(opt);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (sel) {
                              list.remove(opt);
                            } else {
                              final max = f['max'] as int?;
                              if (max != null && list.length >= max) return;
                              list.add(opt);
                              if (max != null && list.length == max) {
                                _scrollToNext(i);
                              }
                            }
                            _data[k] = list;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFFB026FF).withValues(alpha: 0.2) : Colors.transparent,
                            border: Border.all(color: sel ? const Color(0xFFB026FF) : Colors.white24),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(opt, style: GoogleFonts.outfit(color: sel ? const Color(0xFFB026FF) : Colors.white70, fontSize: 12)),
                        ),
                      );
                    }).toList()),
                ]),
              );
            },
          )),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Text('INITIALIZE SYSTEM', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
            )),
          ),
        ]),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// KNOCK CELEBRATION OVERLAY
// ─────────────────────────────────────────────────────────────────────────────
class _KnockCelebrationOverlay extends StatefulWidget {
  final String targetName;
  final bool isSuper;
  final VoidCallback onDone;
  const _KnockCelebrationOverlay({
    required this.targetName,
    required this.isSuper,
    required this.onDone,
  });

  @override
  State<_KnockCelebrationOverlay> createState() => _KnockCelebrationOverlayState();
}

class _KnockCelebrationOverlayState extends State<_KnockCelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _exitCtrl;
  final _rng = math.Random();
  late final List<_CelebParticle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(30, (_) => _CelebParticle(_rng));
    _enterCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _exitCtrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _enterCtrl.forward().then((_) {
      _particleCtrl.forward();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _exitCtrl.forward().then((_) => widget.onDone());
      });
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _particleCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final accent = widget.isSuper ? const Color(0xFFFFB300) : const Color(0xFFFF6B00);

    return AnimatedBuilder(
      animation: Listenable.merge([_enterCtrl, _exitCtrl]),
      builder: (_, __) {
        final opacity = (_enterCtrl.value * (1 - _exitCtrl.value)).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Material(
            color: Colors.black.withValues(alpha: 0.88),
            child: SizedBox.expand(
              child: Stack(children: [
                AnimatedBuilder(
                  animation: _particleCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _CelebParticlePainter(_particles, _particleCtrl.value, accent),
                    size: size,
                  ),
                ),
                Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(widget.isSuper ? '⚡' : '🚪',
                        style: const TextStyle(fontSize: 72))
                        .animate()
                        .scale(begin: const Offset(0.3, 0.3), end: const Offset(1.0, 1.0),
                               duration: const Duration(milliseconds: 500), curve: Curves.elasticOut),
                    const SizedBox(height: 20),
                    Text(
                      widget.isSuper ? 'SUPER KNOCK!' : 'KNOCK SENT!',
                      style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 28,
                        fontWeight: FontWeight.w900, letterSpacing: 1),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 200))
                        .slideY(begin: 0.3, end: 0),
                    const SizedBox(height: 10),
                    Text(
                      widget.isSuper
                          ? '⚡ Priority connection to ${widget.targetName}'
                          : '${widget.targetName} will be notified! 🔔',
                      style: GoogleFonts.outfit(color: Colors.white60, fontSize: 15),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 350)),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: accent.withValues(alpha: 0.5)),
                      ),
                      child: Text('Waiting for response…',
                          style: GoogleFonts.outfit(
                            color: accent, fontSize: 14, fontWeight: FontWeight.w700)),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 500)),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _CelebParticle {
  final double angle;
  final double speed;
  final double size;
  final Color  color;
  _CelebParticle(math.Random rng)
      : angle = rng.nextDouble() * 2 * math.pi,
        speed = 0.3 + rng.nextDouble() * 0.7,
        size  = 4 + rng.nextDouble() * 8,
        color = const [
          Color(0xFFFF6B00), Color(0xFFFF0055),
          Color(0xFFFFB300), Color(0xFF00E676),
          Color(0xFF3B82F6), Color(0xFF8B5CF6),
        ][rng.nextInt(6) % 6];
}

class _CelebParticlePainter extends CustomPainter {
  final List<_CelebParticle> particles;
  final double progress;
  final Color  accent;
  _CelebParticlePainter(this.particles, this.progress, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (final p in particles) {
      final dist  = progress * size.height * 0.45 * p.speed;
      final x     = cx + math.cos(p.angle) * dist;
      final y     = cy + math.sin(p.angle) * dist;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, y),
        p.size * (1 - progress * 0.5),
        Paint()..color = p.color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CelebParticlePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// KNOCK STUDIO HELPER CLASSES & WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
enum KnockMode { active, inactive, invisible }
enum _QuestionTypeTab { open, mcq, slider }

class _KnockStatsBar extends StatelessWidget {
  final int total;
  final int accepted;
  const _KnockStatsBar({required this.total, required this.accepted});

  @override
  Widget build(BuildContext context) {
    final double acceptanceRate = total == 0 ? 0 : (accepted / total);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F16),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.doorbell_rounded, total.toString(), 'Knocks\nReceived', const Color(0xFFFF3060), () {
            Navigator.pop(context); // Close the studio sheet
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen(initialFilter: 'Knocks')));
          }),
          Container(width: 1, height: 40, color: Colors.white12),
          _statItem(Icons.handshake_rounded, accepted.toString(), 'Knocks\nAccepted', const Color(0xFF00E676), () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen(initialFilter: 'All')));
          }),
          Container(width: 1, height: 40, color: Colors.white12),
          _statItem(Icons.analytics_rounded, '${(acceptanceRate * 100).toInt()}%', 'Acceptance\nRate', const Color(0xFFFF6B00), () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('You accept ${(acceptanceRate * 100).toInt()}% of your incoming knocks!'),
              backgroundColor: const Color(0xFFFF6B00),
            ));
          }),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String val, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(val, style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600, height: 1.2)),
        ],
      ),
    );
  }
}

class _CustomQuestionBuilder extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const _CustomQuestionBuilder({required this.onAdd});

  @override
  State<_CustomQuestionBuilder> createState() => _CustomQuestionBuilderState();
}

class _CustomQuestionBuilderState extends State<_CustomQuestionBuilder> {
  bool isExpanded = false;
  _QuestionTypeTab activeTab = _QuestionTypeTab.open;
  
  final qCtl = TextEditingController();
  final ansCtl = TextEditingController();
  
  // MCQ state
  List<String> options = ['', ''];
  
  // Slider state
  double sliderMin = 0;
  double sliderMax = 10;
  double sliderVal = 5;

  static const _orange = Color(0xFFFF6B00);

  void _save() {
    final q = qCtl.text.trim();
    if (q.isEmpty) return;

    Map<String, dynamic> data = {
      'question': q,
      'is_custom': true,
      'question_type': activeTab.name,
      'allow_custom_answer': false,
    };

    if (activeTab == _QuestionTypeTab.open) {
      data['my_answer'] = ansCtl.text.trim();
      data['allow_custom_answer'] = true;
    } else if (activeTab == _QuestionTypeTab.mcq) {
      final validOps = options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (validOps.length < 2) return; // Must have at least 2 options
      data['options'] = validOps;
      data['my_answer'] = ansCtl.text.trim(); // The selected option index or string
    } else if (activeTab == _QuestionTypeTab.slider) {
      data['slider_min'] = sliderMin;
      data['slider_max'] = sliderMax;
      data['my_answer'] = sliderVal.toString();
    }

    widget.onAdd(data);
    
    // Reset state
    setState(() {
      isExpanded = false;
      qCtl.clear();
      ansCtl.clear();
      options = ['', ''];
      sliderMin = 0;
      sliderMax = 10;
      sliderVal = 5;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isExpanded) {
      return GestureDetector(
        onTap: () => setState(() => isExpanded = true),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _orange.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _orange.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, color: _orange, size: 28),
              ),
              const SizedBox(height: 12),
              Text('Create Gateway Question',
                style: GoogleFonts.outfit(color: _orange, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF14141A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _orange.withValues(alpha: 0.5), width: 2),
        boxShadow: [BoxShadow(color: _orange.withValues(alpha: 0.15), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('New Question', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              GestureDetector(
                onTap: () => setState(() => isExpanded = false),
                child: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                _buildTab(_QuestionTypeTab.open, 'Open', Icons.short_text_rounded),
                _buildTab(_QuestionTypeTab.mcq, 'MCQ', Icons.list_alt_rounded),
                _buildTab(_QuestionTypeTab.slider, 'Scale', Icons.linear_scale_rounded),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Question Text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: qCtl,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
              maxLines: 2,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Type your question...',
                hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Dynamic Body
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildDynamicBody(),
          ),
          const SizedBox(height: 24),

          // Add Button
          GestureDetector(
            onTap: _save,
            child: Container(
              width: double.infinity, height: 50,
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _orange.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Text('Add to Gateway',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTab(_QuestionTypeTab tab, String label, IconData icon) {
    final active = activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => activeTab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? _orange.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? _orange : Colors.white30, size: 20),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.outfit(color: active ? _orange : Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicBody() {
    switch (activeTab) {
      case _QuestionTypeTab.open:
        return Column(
          key: const ValueKey('open'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('YOUR BENCHMARK ANSWER', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: TextField(
                controller: ansCtl,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'What would your answer be?',
                  hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 14),
                  icon: const Icon(Icons.star_rounded, color: _orange, size: 16),
                ),
              ),
            ),
          ],
        );
      
      case _QuestionTypeTab.mcq:
        return Column(
          key: const ValueKey('mcq'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OPTIONS', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
            const SizedBox(height: 12),
            ...List.generate(options.length, (idx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (options[idx].trim().isNotEmpty) {
                          setState(() { ansCtl.text = options[idx]; });
                        }
                      },
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: ansCtl.text == options[idx] && options[idx].isNotEmpty ? _orange : Colors.white30, width: 2),
                          color: ansCtl.text == options[idx] && options[idx].isNotEmpty ? _orange : Colors.transparent,
                        ),
                        child: ansCtl.text == options[idx] && options[idx].isNotEmpty ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          onChanged: (v) => setState(() => options[idx] = v),
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Option ${idx + 1}',
                            hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                    if (options.length > 2) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => options.removeAt(idx)),
                        child: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white30, size: 20),
                      ),
                    ],
                  ],
                ),
              );
            }),
            if (options.length < 4) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => setState(() => options.add('')),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: _orange, size: 18),
                    const SizedBox(width: 8),
                    Text('Add Option', style: GoogleFonts.outfit(color: _orange, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ],
        );

      case _QuestionTypeTab.slider:
        return Column(
          key: const ValueKey('slider'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('YOUR BENCHMARK: ${sliderVal.toInt()}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                Text('Range: ${sliderMin.toInt()} - ${sliderMax.toInt()}', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _orange,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                overlayColor: _orange.withValues(alpha: 0.2),
                trackHeight: 8,
              ),
              child: Slider(
                value: sliderVal,
                min: sliderMin,
                max: sliderMax,
                divisions: 10,
                onChanged: (v) => setState(() => sliderVal = v),
              ),
            ),
          ],
        );
    }
  }
}
