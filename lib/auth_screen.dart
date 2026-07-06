// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/doodle_theme.dart';
import 'onboarding_screen.dart';
import 'main.dart' show MainDashboard;

// ─────────────────────────────────────────────────────────────────
// AUTH SCREEN — Premium Phone Sign In / Sign Up
// ─────────────────────────────────────────────────────────────────

const _bg = Colors.black;
const _card = Color(0xFF1A1F2E);
const _cyan = Color(0xFFFF6B00);
const _green = Color(0xFF22C55E);
const _purple = Color(0xFFFF5C00);
const _pink = Color(0xFFFF8A00);
const _red = Color(0xFFEF4444);
const _txt = Color(0xFFF1F5F9);
const _txt2 = Color(0xFF94A3B8);
const _muted = Color(0xFF64748B);
const _gb = Color(0x14FFFFFF);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  // Page Control
  final PageController _pageCtrl = PageController();
  
  // Phone Entry
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  String _countryCode = '+91';

  final List<Map<String, String>> _countryCodes = [
    {'code': '+91',  'flag': '🇮🇳', 'name': 'India'},
    {'code': '+1',   'flag': '🇺🇸', 'name': 'USA / Canada'},
    {'code': '+44',  'flag': '🇬🇧', 'name': 'United Kingdom'},
    {'code': '+61',  'flag': '🇦🇺', 'name': 'Australia'},
    {'code': '+971', 'flag': '🇦🇪', 'name': 'UAE'},
    {'code': '+65',  'flag': '🇸🇬', 'name': 'Singapore'},
    {'code': '+60',  'flag': '🇲🇾', 'name': 'Malaysia'},
    {'code': '+49',  'flag': '🇩🇪', 'name': 'Germany'},
    {'code': '+33',  'flag': '🇫🇷', 'name': 'France'},
    {'code': '+81',  'flag': '🇯🇵', 'name': 'Japan'},
  ];

  // OTP Entry
  final List<TextEditingController> _otpCtrl = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFoci = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  bool _isResending = false;
  int _countdown = 60;
  Timer? _timer;
  String _fullPhoneNumber = '';

  // Ambient Animations
  late AnimationController _orbCtrl;
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _orbCtrl.dispose();
    _floatCtrl.dispose();
    _phoneCtrl.dispose();
    _timer?.cancel();
    for (final c in _otpCtrl) c.dispose();
    for (final f in _otpFoci) f.dispose();
    super.dispose();
  }

  // ── Validation & Helpers ─────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.error_outline, color: Colors.white, size: 18), const SizedBox(width: 10), Expanded(child: Text(msg, style: const TextStyle(color: Colors.white)))]),
      backgroundColor: _red,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.check_circle_outline, color: Colors.white, size: 18), const SizedBox(width: 10), Expanded(child: Text(msg, style: const TextStyle(color: Colors.white)))]),
      backgroundColor: _green,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Phone Auth Actions ──────────────────────────────────────────

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (phone.length < 7) {
      _showError('Please enter a valid phone number.');
      return;
    }

    _fullPhoneNumber = '$_countryCode$phone';
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: _fullPhoneNumber);
      if (mounted) {
        _startTimer();
        _pageCtrl.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _otpFoci[0].requestFocus();
        });
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Failed to send OTP. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── OTP Actions ─────────────────────────────────────────────────

  void _startTimer() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdown == 0) {
        t.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  String get _otpVal => _otpCtrl.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_otpVal.length < 6) {
      _showError('Please enter all 6 digits.');
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final res = await Supabase.instance.client.auth.verifyOTP(
        phone: _fullPhoneNumber,
        token: _otpVal,
        type: OtpType.sms,
      );

      if (res.user != null && mounted) {
        final isNewUser = await _ensureProfile(res.user!);
        if (!mounted) return;
        
        if (isNewUser) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const _OnboardingWrapper()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const _DashboardWrapper()),
            (route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) _showError('Invalid code: ${e.message}');
      for (final c in _otpCtrl) c.clear();
      if (mounted) _otpFoci[0].requestFocus();
    } catch (e) {
      if (mounted) _showError('Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<bool> _ensureProfile(User user) async {
    try {
      final existing = await Supabase.instance.client
          .from('profiles')
          .select('id, onboarding_complete')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        final phone = _fullPhoneNumber;
        final suffix = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'name': 'User_$suffix',
          'username': 'user_${user.id.substring(0, 8)}',
          'full_name': 'Relaya User',
          'avatar_url': '',
          'onboarding_complete': false,
          'is_public': true,
          'phone': phone,
        }, onConflict: 'id');
        return true; 
      }
      return existing['onboarding_complete'] != true; 
    } catch (e) {
      debugPrint('Profile creation error: $e');
      return false;
    }
  }

  Future<void> _resendOtp() async {
    if (_countdown > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: _fullPhoneNumber);
      _startTimer();
      if (mounted) {
        _showSuccess('Code resent to $_fullPhoneNumber');
      }
      for (final c in _otpCtrl) c.clear();
      if (mounted) _otpFoci[0].requestFocus();
    } catch (_) {
      if (mounted) _showError('Failed to resend. Try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ── UI Building ─────────────────────────────────────────────────

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _muted, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Select Country', style: GoogleFonts.inter(color: _txt, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _countryCodes.length,
              itemBuilder: (context, index) {
                final c = _countryCodes[index];
                return ListTile(
                  leading: Text(c['flag']!, style: const TextStyle(fontSize: 26)),
                  title: Text(c['name']!, style: GoogleFonts.inter(color: _txt, fontSize: 14)),
                  trailing: Text(c['code']!, style: GoogleFonts.inter(color: _txt2, fontSize: 14)),
                  onTap: () {
                    setState(() => _countryCode = c['code']!);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDoodleMode(context) ? DoodleColors.cream : _bg,
      body: Stack(
        children: [
          _buildAmbientOrbs(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Logo
                AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (_, child) => Transform.translate(offset: Offset(0, _floatAnim.value), child: child),
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(painter: YinYangCrescentPainter()),
                  ),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildPhoneEntryStep(),
                      _buildOtpVerifyStep(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneEntryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text('Welcome to Relaya',
              style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: _txt, height: 1.2)),
          const SizedBox(height: 10),
          Text("Enter your phone number to continue.\nWe'll send you a verification code.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: _txt2, height: 1.4)),
          const SizedBox(height: 40),

          // Phone input
          Align(
            alignment: Alignment.centerLeft,
            child: Text('PHONE NUMBER',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            GestureDetector(
              onTap: _showCountryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _gb)),
                child: Row(children: [
                  Text(_countryCode, style: GoogleFonts.inter(color: _txt, fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: _muted, size: 18),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _gb)),
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  style: GoogleFonts.inter(color: _txt, fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: '9876543210',
                    hintStyle: GoogleFonts.inter(color: _muted, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  onSubmitted: (_) => _sendOtp(),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: _muted, size: 12),
              const SizedBox(width: 5),
              Text('Secured by Supabase.', style: GoogleFonts.inter(fontSize: 11, color: _muted)),
            ],
          ),

          const SizedBox(height: 40),

          // Send OTP button
          GestureDetector(
            onTap: _isLoading ? null : _sendOtp,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: _isLoading ? null : const LinearGradient(colors: [_cyan, _pink]),
                color: _isLoading ? _muted.withValues(alpha: 0.3) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isLoading ? [] : [BoxShadow(color: _cyan.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                          const SizedBox(width: 8),
                          Text('Continue', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
                        ],
                      ),
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          Text.rich(
            TextSpan(
              text: 'By continuing, you agree to our ',
              style: GoogleFonts.inter(fontSize: 11, color: _muted),
              children: [
                TextSpan(text: 'Terms of Service', style: GoogleFonts.inter(color: _cyan, fontSize: 11)),
                const TextSpan(text: ' and '),
                TextSpan(text: 'Privacy Policy', style: GoogleFonts.inter(color: _cyan, fontSize: 11)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpVerifyStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _txt2, size: 20),
              onPressed: () {
                _pageCtrl.previousPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
              },
            ),
          ),
          const SizedBox(height: 10),
          Text('Verify your number',
              style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: _txt, height: 1.2)),
          const SizedBox(height: 10),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              text: 'Code sent to ',
              style: GoogleFonts.inter(fontSize: 14, color: _txt2, height: 1.4),
              children: [
                TextSpan(
                  text: _fullPhoneNumber,
                  style: GoogleFonts.inter(fontSize: 14, color: _cyan, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _red.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, color: _red, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Note: Please check your spam/blocked folder if you do not receive the OTP.',
                    style: GoogleFonts.inter(color: _red, fontSize: 11, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // OTP Boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, _buildBox),
          ),
          const SizedBox(height: 36),

          // Verify button
          GestureDetector(
            onTap: _isVerifying ? null : _verifyOtp,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: _isVerifying ? null : const LinearGradient(colors: [_cyan, _pink]),
                color: _isVerifying ? _muted.withValues(alpha: 0.3) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isVerifying ? [] : [BoxShadow(color: _cyan.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Center(
                child: _isVerifying
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: Colors.black, size: 18),
                          const SizedBox(width: 8),
                          Text('Verify & Login', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Resend row
          Center(
            child: _isResending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _cyan, strokeWidth: 2))
                : GestureDetector(
                    onTap: _countdown == 0 ? _resendOtp : null,
                    child: RichText(
                      text: TextSpan(
                        text: "Didn't receive code? ",
                        style: GoogleFonts.inter(fontSize: 13, color: _txt2),
                        children: [
                          TextSpan(
                            text: _countdown > 0 ? 'Resend in ${_countdown}s' : 'Resend OTP',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _countdown > 0 ? _muted : _cyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBox(int i) {
    return SizedBox(
      width: 48,
      height: 58,
      child: TextField(
        controller: _otpCtrl[i],
        focusNode: _otpFoci[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.inter(color: _txt, fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: _card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _gb),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _cyan, width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty) {
            if (i < 5) {
              _otpFoci[i + 1].requestFocus();
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _otpVal.length == 6) _verifyOtp();
              });
            }
          } else if (val.isEmpty && i > 0) {
            _otpFoci[i - 1].requestFocus();
          }
          setState(() {});
        },
        onTap: () {
          if (_otpVal.length < 6) _otpCtrl[i].selection = TextSelection.fromPosition(TextPosition(offset: _otpCtrl[i].text.length));
        },
      ),
    );
  }

  Widget _buildAmbientOrbs() {
    return AnimatedBuilder(
      animation: _orbCtrl,
      builder: (_, __) {
        final t = _orbCtrl.value;
        return Stack(
          children: [
            Positioned(
              top: -100 + 15 * math.sin(t * math.pi),
              right: -80 + 20 * math.cos(t * math.pi),
              child: _orb(300, _cyan),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.15,
              left: -60,
              child: _orb(250, _purple),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              right: -50,
              child: _orb(200, _pink),
            ),
          ],
        );
      },
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.12), Colors.transparent]),
      ),
    );
  }
}

class YinYangCrescentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint1 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF8A00), Color(0xFFFF5C00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF5C00), Color(0xFFFF2A00)],
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(center.dx - radius + 5, center.dy);
    path1.arcToPoint(Offset(center.dx + radius - 5, center.dy), radius: Radius.circular(radius - 5), clockwise: true);
    path1.arcToPoint(Offset(center.dx, center.dy), radius: Radius.circular((radius - 5) / 2), clockwise: true);
    path1.arcToPoint(Offset(center.dx - radius + 5, center.dy), radius: Radius.circular((radius - 5) / 2), clockwise: false);

    final path2 = Path();
    path2.moveTo(center.dx + radius - 5, center.dy);
    path2.arcToPoint(Offset(center.dx - radius + 5, center.dy), radius: Radius.circular(radius - 5), clockwise: true);
    path2.arcToPoint(Offset(center.dx, center.dy), radius: Radius.circular((radius - 5) / 2), clockwise: true);
    path2.arcToPoint(Offset(center.dx + radius - 5, center.dy), radius: Radius.circular((radius - 5) / 2), clockwise: false);

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);

    final dotPaint = Paint()..color = const Color(0xFF0A0A0A);
    canvas.drawCircle(Offset(center.dx + (radius - 5) / 2, center.dy), 6, dotPaint);
    canvas.drawCircle(Offset(center.dx - (radius - 5) / 2, center.dy), 6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════
// NAVIGATION WRAPPERS
// ═══════════════════════════════════════════════════════════════════

/// Routes a brand-new user to the onboarding flow
class _OnboardingWrapper extends StatelessWidget {
  const _OnboardingWrapper();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: const OnboardingScreen(),
        ),
      ),
    );
  }
}

/// Routes a returning user straight into the main dashboard
class _DashboardWrapper extends StatelessWidget {
  const _DashboardWrapper();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: const MainDashboard(),
        ),
      ),
    );
  }
}
