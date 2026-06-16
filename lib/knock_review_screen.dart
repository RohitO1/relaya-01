// ignore_for_file: use_build_context_synchronously, avoid_print
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'messages_screen.dart';
import 'services/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KNOCK REVIEW SCREEN
// ─────────────────────────────────────────────────────────────────────────────
/// Full-screen premium review page that the target user sees when they receive
/// a knock. It is reached from:
///   • Notifications screen (tap knock notification)
///   • Messages → Knocks tab (tap a pending incoming knock)
class KnockReviewScreen extends StatefulWidget {
  /// The knock `requests` row (must contain sender_id, knock_answers, status, etc.)
  final Map<String, dynamic> knockRequest;

  /// Pre-fetched sender profile (may be partial — we will re-fetch as needed)
  final Map<String, dynamic>? senderProfile;

  const KnockReviewScreen({
    super.key,
    required this.knockRequest,
    this.senderProfile,
  });

  @override
  State<KnockReviewScreen> createState() => _KnockReviewScreenState();
}

class _KnockReviewScreenState extends State<KnockReviewScreen>
    with TickerProviderStateMixin {
  // ── colours ──────────────────────────────────────────────────────────────
  static const _bg     = Color(0xFF07070F);
  static const _card   = Color(0xFF10101C);
  static const _orange = Color(0xFFFF6B00);
  static const _green  = Color(0xFF00E676);
  static const _gold   = Color(0xFFFFB300);
  static const _purple = Color(0xFF8B5CF6);

  // ── state ────────────────────────────────────────────────────────────────
  bool _revealed      = false;
  bool _loading       = true;
  bool _accepting     = false;
  bool _passing       = false;
  int  _activeTab     = 0;   // 0 = Overview, 1 = Answers, 2 = Vibe Check
  Map<String, dynamic>? _sender;
  Map<String, dynamic>? _myProfile;
  Map<String, dynamic>  _compatCats = {};
  int                   _compatScore = 0;
  List<String>          _sharedInterests = [];
  List<String>          _topReasons      = [];

  // ── animation controllers ────────────────────────────────────────────────
  late AnimationController _revealCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _ringCtrl;

  String get _myUid => Supabase.instance.client.auth.currentUser?.id ?? '';
  String get _senderId => widget.knockRequest['sender_id']?.toString() ?? '';
  bool   get _isSuper  => widget.knockRequest['is_super'] == true;
  List   get _answers  => (widget.knockRequest['knock_answers'] as List?) ?? [];

  // ── expiry ───────────────────────────────────────────────────────────────
  Duration? _expiresIn;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(vsync: this, duration: 600.ms);
    _pulseCtrl  = AnimationController(vsync: this, duration: 1800.ms)..repeat(reverse: true);
    _ringCtrl   = AnimationController(vsync: this, duration: 1200.ms);
    _load();
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  // ── data loading ─────────────────────────────────────────────────────────
  Future<void> _load() async {
    try {
      // Fetch sender + my profile in parallel
      final results = await Future.wait([
        Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', _senderId)
            .maybeSingle(),
        Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', _myUid)
            .maybeSingle(),
      ]);

      final sender = results[0];
      final me     = results[1];

      // ── expiry countdown ────────────────────────────────────────────────
      final expiresAtStr = widget.knockRequest['expires_at'] as String?;
      Duration? expiresIn;
      if (expiresAtStr != null) {
        try {
          final exp = DateTime.parse(expiresAtStr).toLocal();
          final rem = exp.difference(DateTime.now());
          if (rem.isNegative) expiresIn = Duration.zero;
          else expiresIn = rem;
        } catch (_) {}
      }

      // ── compat ──────────────────────────────────────────────────────────
      Map<String, dynamic> cats = {};
      int score = 0;
      List<String> sharedI = [];
      List<String> reasons = [];

      if (sender != null && me != null) {
        cats  = _calcCategories(me, sender);
        score = _calcScore(cats);
        sharedI = _calcSharedInterests(me, sender);
        reasons = _calcReasons(me, sender);
      }

      if (mounted) {
        setState(() {
          _sender         = sender;
          _myProfile      = me;
          _compatCats     = cats;
          _compatScore    = score;
          _sharedInterests = sharedI;
          _topReasons     = reasons;
          _expiresIn      = expiresIn;
          _loading        = false;
          // Super knocks auto-reveal
          if (_isSuper) { _revealed = true; _revealCtrl.forward(); }
        });
        _ringCtrl.forward();
      }
    } catch (e) {
      print('KnockReviewScreen load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── compat helpers ────────────────────────────────────────────────────────
  Map<String, dynamic> _calcCategories(Map<String, dynamic> my, Map<String, dynamic> other) {
    double ls = 0; int lsC = 0;
    for (final k in ['smoking', 'drinking', 'diet', 'exercise', 'pets']) {
      final mv = my[k]?.toString() ?? ''; final ov = other[k]?.toString() ?? '';
      if (mv.isNotEmpty && ov.isNotEmpty) { ls += (mv.toLowerCase() == ov.toLowerCase() ? 100 : 20); lsC++; }
    }
    final lsScore = lsC > 0 ? (ls / lsC).clamp(0, 100).toDouble() : 50.0;

    double dm = 0; int dmC = 0;
    final myAge = (my['age'] as num?)?.toInt() ?? 0; final otAge = (other['age'] as num?)?.toInt() ?? 0;
    if (myAge > 0 && otAge > 0) { dm += (myAge - otAge).abs() <= 5 ? 100 : 40; dmC++; }
    for (final k in ['education', 'zodiac']) {
      final mv = my[k]?.toString() ?? ''; final ov = other[k]?.toString() ?? '';
      if (mv.isNotEmpty && ov.isNotEmpty) { dm += (mv.toLowerCase() == ov.toLowerCase() ? 100 : 30); dmC++; }
    }
    final demoScore = dmC > 0 ? (dm / dmC).clamp(0, 100).toDouble() : 50.0;

    double vl = 0; int vlC = 0;
    for (final k in ['religion', 'political_view', 'open_to_relocate']) {
      final mv = my[k]?.toString() ?? ''; final ov = other[k]?.toString() ?? '';
      if (mv.isNotEmpty && ov.isNotEmpty) { vl += (mv.toLowerCase() == ov.toLowerCase() ? 100 : 30); vlC++; }
    }
    final vlScore = vlC > 0 ? (vl / vlC).clamp(0, 100).toDouble() : 50.0;

    final myI = List<String>.from(my['interests'] ?? []);
    final thI = List<String>.from(other['interests'] ?? []);
    final myT = List<String>.from(my['personality_traits'] ?? []);
    final thT = List<String>.from(other['personality_traits'] ?? []);
    final ov  = (myI.isEmpty || thI.isEmpty) ? 0.0 : myI.where(thI.contains).length / math.max(myI.length, thI.length);
    final tv  = (myT.isEmpty || thT.isEmpty) ? 0.0 : myT.where(thT.contains).length / math.max(myT.length, thT.length);
    final intScore = (ov * 75 + tv * 25).clamp(0, 100).toDouble();

    return {'Lifestyle': lsScore, 'Values': vlScore, 'Interests': intScore, 'Demographics': demoScore};
  }

  int _calcScore(Map<String, dynamic> cats) {
    final score = (cats['Lifestyle']! as double) * 0.35 +
                  (cats['Interests']! as double) * 0.30 +
                  (cats['Values']! as double)    * 0.25 +
                  (cats['Demographics']! as double) * 0.10;
    return score.round().clamp(0, 100);
  }

  List<String> _calcSharedInterests(Map<String, dynamic> my, Map<String, dynamic> other) {
    final myI = List<String>.from(my['interests'] ?? []);
    final thI = List<String>.from(other['interests'] ?? []);
    return myI.where(thI.contains).take(5).toList();
  }

  List<String> _calcReasons(Map<String, dynamic> my, Map<String, dynamic> other) {
    final reasons = <String>[];
    final myLF = List<String>.from(my['looking_for'] ?? []);
    final thLF = List<String>.from(other['looking_for'] ?? []);
    if (myLF.any(thLF.contains)) reasons.add('Same relationship goal');
    final myI = List<String>.from(my['interests'] ?? []);
    final thI = List<String>.from(other['interests'] ?? []);
    final shared = myI.where(thI.contains).take(2).toList();
    if (shared.isNotEmpty) reasons.add('Love for ${shared.join(' & ')}');
    for (final k in ['smoking', 'diet', 'religion']) {
      final mv = my[k]?.toString() ?? ''; final ov = other[k]?.toString() ?? '';
      if (mv.isNotEmpty && ov.isNotEmpty && mv.toLowerCase() == ov.toLowerCase()) {
        reasons.add(k == 'smoking' ? 'Non-smokers' : k == 'diet' ? 'Same diet ($mv)' : 'Same faith');
      }
    }
    return reasons.take(4).toList();
  }

  // ── actions ───────────────────────────────────────────────────────────────
  Future<void> _accept() async {
    HapticFeedback.heavyImpact();
    setState(() => _accepting = true);
    try {
      final reqId = widget.knockRequest['id'].toString();
      await Supabase.instance.client
          .from('requests').update({'status': 'approved'}).eq('id', reqId);

      final myName = _myProfile?['name']?.toString() ?? 'Someone';
      await NotificationService.sendNotification(
        userId: _senderId,
        type: NotificationType.knock_accepted,
        title: 'Knock Accepted! 🎉',
        body: '$myName accepted your knock. Start chatting!',
        payload: {
          'sender_id': _myUid,
          'sender_name': myName,
          'sender_avatar_url': _myProfile?['avatar_url']?.toString() ?? '',
        },
      );

      if (!mounted) return;
      // Pop this screen and navigate to chat
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          targetUserId: _senderId,
          name: _sender?['name']?.toString() ?? _sender?['full_name']?.toString() ?? 'User',
          avatarUrl: _sender?['avatar_url']?.toString() ?? '',
          isUnlocked: true,
        ),
      ));
    } catch (e) {
      print('Accept knock error: $e');
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _pass() async {
    HapticFeedback.mediumImpact();
    setState(() => _passing = true);
    try {
      final reqId = widget.knockRequest['id'].toString();
      await Supabase.instance.client
          .from('requests').update({'status': 'rejected'}).eq('id', reqId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print('Pass knock error: $e');
      if (mounted) setState(() => _passing = false);
    }
  }

  void _reveal() {
    HapticFeedback.heavyImpact();
    setState(() => _revealed = true);
    _revealCtrl.forward();
  }

  // ── ui helpers ────────────────────────────────────────────────────────────
  Color get _accentColor => _isSuper ? _gold : _orange;

  String _formatExpiry(Duration d) {
    if (d <= Duration.zero) return 'Expired';
    if (d.inHours >= 1) return '${d.inHours}h left';
    return '${d.inMinutes}m left';
  }

  Color _scoreColor(int s) {
    if (s >= 75) return _green;
    if (s >= 50) return _orange;
    return Colors.red.shade400;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? _buildLoading()
          : Stack(children: [
              _buildAmbient(),
              SafeArea(child: _buildContent()),
            ]),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(color: _orange, strokeWidth: 2),
        const SizedBox(height: 20),
        Text('Loading knock details…',
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14)),
      ]),
    );
  }

  Widget _buildAmbient() {
    return Positioned.fill(
      child: CustomPaint(painter: _KnockAmbientPainter(_accentColor, _pulseCtrl)),
    );
  }

  Widget _buildContent() {
    return Column(children: [
      _buildHeader(),
      _buildProfileCard(),
      _buildTabBar(),
      Expanded(child: _buildTabContent()),
      _buildActions(),
    ]);
  }

  // ── header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
          ),
        ),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(_isSuper ? '⚡ SUPER KNOCK' : '🚪 KNOCK REQUEST',
              style: GoogleFonts.outfit(
                color: _accentColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
          Text('Review & Decide',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
        const Spacer(),
        if (_expiresIn != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _expiresIn!.inHours < 2
                  ? Colors.red.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _expiresIn!.inHours < 2 ? Colors.red.withValues(alpha: 0.4) : Colors.white10),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer_outlined,
                  color: _expiresIn!.inHours < 2 ? Colors.red.shade300 : Colors.white38,
                  size: 13),
              const SizedBox(width: 4),
              Text(_formatExpiry(_expiresIn!),
                  style: GoogleFonts.outfit(
                    color: _expiresIn!.inHours < 2 ? Colors.red.shade300 : Colors.white38,
                    fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          )
        else
          const SizedBox(width: 40),
      ]),
    );
  }

  // ── profile card ─────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    final name   = _sender?['name']?.toString() ?? _sender?['full_name']?.toString() ?? 'Anonymous';
    final avatar = _sender?['avatar_url']?.toString() ?? '';
    final age    = _sender?['age']?.toString() ?? '';
    final city   = _sender?['city']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _accentColor.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [BoxShadow(color: _accentColor.withValues(alpha: 0.12), blurRadius: 30, spreadRadius: 2)],
        ),
        child: Row(children: [
          // ── avatar ──────────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _revealCtrl,
            builder: (_, child) {
              final blur = (1 - _revealCtrl.value) * 18.0;
              return Stack(children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _accentColor, width: 2.5),
                    boxShadow: [BoxShadow(color: _accentColor.withValues(alpha: 0.35), blurRadius: 16)],
                  ),
                  child: ClipOval(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: avatar.isNotEmpty
                          ? Image.network(avatar, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarFallback())
                          : _avatarFallback(),
                    ),
                  ),
                ),
                if (!_revealed)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.25),
                      ),
                      child: const Icon(Icons.person, color: Colors.white38, size: 30),
                    ),
                  ),
                if (_isSuper)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: _gold, shape: BoxShape.circle,
                          border: Border.all(color: _bg, width: 2)),
                      child: const Icon(Icons.bolt, color: Colors.black, size: 14),
                    ),
                  ),
              ]);
            },
          ),
          const SizedBox(width: 18),

          // ── info ─────────────────────────────────────────────────────────
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // name (revealed or mystery)
              AnimatedBuilder(
                animation: _revealCtrl,
                builder: (_, __) {
                  final blur = (1 - _revealCtrl.value) * 6.0;
                  return ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: 0),
                    child: Text(
                      _revealed ? name : '●●●●●●●',
                      style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              if (_revealed && (age.isNotEmpty || city.isNotEmpty))
                Row(children: [
                  if (age.isNotEmpty)
                    Text('$age yrs',
                        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                  if (age.isNotEmpty && city.isNotEmpty)
                    Text(' · ',
                        style: GoogleFonts.outfit(color: Colors.white24, fontSize: 13)),
                  if (city.isNotEmpty)
                    Flexible(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.location_on, color: Colors.white38, size: 12),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(city,
                              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ),
                ])
              else if (!_revealed)
                Text('Identity hidden',
                    style: GoogleFonts.outfit(color: Colors.white24, fontSize: 13, fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),

              // Compat ring mini
              Row(children: [
                _buildMiniRing(_compatScore),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_compatScore}% Vibe Match',
                        style: GoogleFonts.outfit(
                          color: _scoreColor(_compatScore), fontSize: 13, fontWeight: FontWeight.w700)),
                    if (_topReasons.isNotEmpty)
                      Text(_topReasons.first,
                          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
    );
  }

  Widget _avatarFallback() => Container(
    color: _accentColor.withValues(alpha: 0.15),
    child: Icon(Icons.person, color: _accentColor.withValues(alpha: 0.6), size: 40),
  );

  Widget _buildMiniRing(int score) {
    return SizedBox(
      width: 44, height: 44,
      child: AnimatedBuilder(
        animation: _ringCtrl,
        builder: (_, __) => CustomPaint(
          painter: _CompatRingPainter(score / 100, _scoreColor(score), _ringCtrl.value),
          child: Center(
            child: Text('$score',
                style: GoogleFonts.outfit(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }

  // ── tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = ['Overview', 'Answers', 'Vibe Check'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: List.generate(3, (i) {
        final sel = _activeTab == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _activeTab = i),
            child: AnimatedContainer(
              duration: 200.ms,
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              height: 40,
              decoration: BoxDecoration(
                color: sel ? _accentColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel ? _accentColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.06),
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(tabs[i],
                    style: GoogleFonts.outfit(
                      color: sel ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    )),
              ),
            ),
          ),
        );
      })),
    );
  }

  // ── tab content ───────────────────────────────────────────────────────────
  Widget _buildTabContent() {
    return AnimatedSwitcher(
      duration: 250.ms,
      child: switch (_activeTab) {
        0 => _buildOverviewTab(),
        1 => _buildAnswersTab(),
        _ => _buildVibeCheckTab(),
      },
    );
  }

  // ── OVERVIEW TAB ──────────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    final isSuper = _isSuper;
    final senderName = _sender?['name']?.toString().split(' ').first ?? 'They';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Knock type banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSuper
                  ? [_gold.withValues(alpha: 0.15), const Color(0xFFFF6B00).withValues(alpha: 0.08)]
                  : [_orange.withValues(alpha: 0.12), _orange.withValues(alpha: 0.04)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: (isSuper ? _gold : _orange).withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) => Transform.scale(
                scale: 1 + _pulseCtrl.value * 0.08,
                child: Text(isSuper ? '⚡' : '🚪', style: const TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isSuper
                      ? (_revealed ? '$senderName sent you a Super Knock!' : 'Someone sent you a Super Knock!')
                      : (_revealed ? '$senderName wants to connect with you' : 'Someone knocked to connect with you'),
                  style: GoogleFonts.outfit(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  isSuper
                      ? 'A Super Knock is an instant priority connection.'
                      : 'They answered ${_answers.length} question${_answers.length != 1 ? 's' : ''} to connect with you.',
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                ),
              ]),
            ),
          ]),
        ).animate().fadeIn(delay: 100.ms),

        const SizedBox(height: 16),

        // Reveal CTA (if not revealed)
        if (!_revealed) ...[
          GestureDetector(
            onTap: _reveal,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_purple, Color(0xFFFF0055)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.lock_open_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text('Reveal Identity & Answers',
                    style: GoogleFonts.outfit(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ]),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(
            duration: 2.5.seconds,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
        ],

        // Reasons to connect
        if (_topReasons.isNotEmpty) ...[
          _sectionLabel('WHY YOU MIGHT CLICK'),
          const SizedBox(height: 10),
          ..._topReasons.map((r) => _reasonRow(r)),
          const SizedBox(height: 16),
        ],

        // Shared interests
        if (_sharedInterests.isNotEmpty) ...[
          _sectionLabel('COMMON GROUND'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _sharedInterests.map((i) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accentColor.withValues(alpha: 0.35)),
              ),
              child: Text(i, style: GoogleFonts.outfit(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            )).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Sender bio (revealed only)
        if (_revealed && (_sender?['bio'] ?? '').toString().isNotEmpty) ...[
          _sectionLabel('ABOUT THEM'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Text(_sender!['bio'].toString(),
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, height: 1.5)),
          ),
          const SizedBox(height: 16),
        ],
      ]),
    );
  }

  Widget _reasonRow(String reason) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: _accentColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(reason,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }

  // ── ANSWERS TAB ───────────────────────────────────────────────────────────
  Widget _buildAnswersTab() {
    final superOnly = _isSuper && _answers.isEmpty;
    final hasAnswers = _answers.isNotEmpty && !(_answers.length == 1 && _answers[0] is Map && _answers[0]['super'] == true);

    if (superOnly || !hasAnswers) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.bolt_rounded, color: _gold.withValues(alpha: 0.4), size: 60),
          const SizedBox(height: 16),
          Text('Super Knock — No Questions',
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('They went straight for the connection!\nAccept to start chatting.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white24, fontSize: 13)),
        ]),
      );
    }

    if (!_revealed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _purple.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.lock_rounded, color: _purple, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Answers are locked',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Reveal their identity first to unlock their answers.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _reveal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_purple, Color(0xFFFF0055)]),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.4), blurRadius: 16)],
                ),
                child: Text('Reveal Now',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      itemCount: _answers.length,
      itemBuilder: (_, i) {
        final ans = _answers[i];
        if (ans is! Map) return const SizedBox.shrink();
        final qText = ans['question']?.toString() ?? '';
        final aText = ans['answer']?.toString() ?? '';
        if (qText.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: Row(children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: GoogleFonts.outfit(color: _accentColor, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(qText,
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: _green.withValues(alpha: 0.3)),
                  ),
                  child: ClipOval(
                    child: (_sender?['avatar_url']?.toString() ?? '').isNotEmpty
                        ? Image.network(_sender!['avatar_url'].toString(), fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.person, color: _green, size: 16))
                        : Icon(Icons.person, color: _green, size: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(aText,
                      style: GoogleFonts.outfit(color: _green, fontSize: 14, fontWeight: FontWeight.w500, height: 1.45)),
                ),
              ]),
            ),
          ]),
        ).animate().fadeIn(delay: (i * 60).ms).slideY(begin: 0.15, end: 0);
      },
    );
  }

  // ── VIBE CHECK TAB ────────────────────────────────────────────────────────
  Widget _buildVibeCheckTab() {
    final cats = [
      {'label': 'Lifestyle', 'icon': Icons.spa_rounded, 'color': const Color(0xFF00E676)},
      {'label': 'Interests', 'icon': Icons.interests_rounded, 'color': const Color(0xFF3B82F6)},
      {'label': 'Values', 'icon': Icons.favorite_rounded, 'color': const Color(0xFFF43F5E)},
      {'label': 'Demographics', 'icon': Icons.people_rounded, 'color': const Color(0xFFFFB300)},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Big ring
        Center(
          child: SizedBox(
            width: 140, height: 140,
            child: AnimatedBuilder(
              animation: _ringCtrl,
              builder: (_, __) => CustomPaint(
                painter: _CompatRingPainter(_compatScore / 100, _scoreColor(_compatScore), _ringCtrl.value, strokeWidth: 14),
                child: Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$_compatScore%',
                        style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                    Text('match',
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Category bars
        ..._compatCats.entries.toList().asMap().entries.map((e) {
          final idx   = e.key;
          final k     = e.value.key;
          final score = (e.value.value as double).round();
          final cat   = cats.firstWhere((c) => c['label'] == k,
              orElse: () => {'label': k, 'icon': Icons.star, 'color': _orange});
          final color = cat['color'] as Color;
          final icon  = cat['icon'] as IconData;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(k, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('$score%', style: GoogleFonts.outfit(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AnimatedBuilder(
                  animation: _ringCtrl,
                  builder: (_, __) => LinearProgressIndicator(
                    value: _ringCtrl.value * score / 100,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 8,
                  ),
                ),
              ),
            ]),
          ).animate().fadeIn(delay: (idx * 80).ms);
        }),

        if (_topReasons.isNotEmpty) ...[
          const SizedBox(height: 8),
          _sectionLabel('WHAT CLICKS'),
          const SizedBox(height: 10),
          ..._topReasons.map((r) => _reasonRow(r)),
        ],
      ]),
    );
  }

  Widget _sectionLabel(String label) => Text(label,
      style: GoogleFonts.outfit(
        color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5));

  // ── actions ───────────────────────────────────────────────────────────────
  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(children: [
        // Pass button
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _passing ? null : _pass,
            child: AnimatedContainer(
              duration: 200.ms,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Center(
                child: _passing
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2))
                    : Text('Pass',
                        style: GoogleFonts.outfit(
                          color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Accept button
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: (_accepting || !_revealed) ? null : _accept,
            child: AnimatedContainer(
              duration: 200.ms,
              height: 56,
              decoration: BoxDecoration(
                gradient: _revealed
                    ? LinearGradient(
                        colors: [_accentColor, const Color(0xFFFF0055)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      )
                    : null,
                color: _revealed ? null : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: !_revealed ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
                boxShadow: _revealed
                    ? [BoxShadow(color: _accentColor.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))]
                    : [],
              ),
              child: Center(
                child: _accepting
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(!_revealed ? Icons.lock_rounded : Icons.waving_hand_rounded,
                            color: _revealed ? Colors.white : Colors.white24, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          !_revealed ? 'Reveal First' : 'Accept Knock',
                          style: GoogleFonts.outfit(
                            color: _revealed ? Colors.white : Colors.white24,
                            fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTERS
// ─────────────────────────────────────────────────────────────────────────────
class _CompatRingPainter extends CustomPainter {
  final double progress;
  final Color  color;
  final double animValue;
  final double strokeWidth;

  _CompatRingPainter(this.progress, this.color, this.animValue, {this.strokeWidth = 7});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width - strokeWidth) / 2;

    // Track
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke);

    // Fill
    final filled = progress * animValue;
    if (filled > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * filled,
        false,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CompatRingPainter old) =>
      old.progress != progress || old.animValue != animValue;
}

class _KnockAmbientPainter extends CustomPainter {
  final Color  accent;
  final Animation<double> anim;
  _KnockAmbientPainter(this.accent, this.anim) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Top-left orb
    paint.color = accent.withValues(alpha: 0.04 + anim.value * 0.02);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.1), 140, paint);

    // Bottom-right orb
    paint.color = const Color(0xFF8B5CF6).withValues(alpha: 0.03 + anim.value * 0.015);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.85), 160, paint);
  }

  @override
  bool shouldRepaint(covariant _KnockAmbientPainter old) => true;
}
