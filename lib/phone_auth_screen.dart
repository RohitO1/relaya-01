// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Color tokens (match app theme) ─────────────────────────────────
const _bg    = Colors.black;
const _card  = Color(0xFF1A1F2E);
const _cyan  = Color(0xFFFF6B00);
const _green = Color(0xFF22C55E);
const _red   = Color(0xFFEF4444);
const _txt   = Color(0xFFF1F5F9);
const _txt2  = Color(0xFF94A3B8);
const _muted = Color(0xFF64748B);
const _gb    = Color(0x14FFFFFF);

// ═══════════════════════════════════════════════════════════════════
// PHONE ENTRY SCREEN
// ═══════════════════════════════════════════════════════════════════
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  String _countryCode = '+91';

  late AnimationController _orbCtrl;

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

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (phone.length < 7) {
      _showError('Please enter a valid phone number.');
      return;
    }

    final fullPhone = '$_countryCode$phone';
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: fullPhone);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(phoneNumber: fullPhone),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Failed to send OTP. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor: _red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

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
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: _muted, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Select Country', style: GoogleFonts.inter(color: _txt, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...(_countryCodes.map((c) => ListTile(
            leading: Text(c['flag']!, style: const TextStyle(fontSize: 26)),
            title: Text(c['name']!, style: GoogleFonts.inter(color: _txt, fontSize: 14)),
            trailing: Text(c['code']!, style: GoogleFonts.inter(color: _txt2, fontSize: 14)),
            onTap: () {
              setState(() => _countryCode = c['code']!);
              Navigator.pop(context);
            },
          ))),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Ambient orbs
          AnimatedBuilder(
            animation: _orbCtrl,
            builder: (_, __) {
              final t = _orbCtrl.value;
              return Stack(children: [
                Positioned(
                  top: -80 + 20 * math.sin(t * math.pi),
                  right: -60,
                  child: _orb(280, _cyan),
                ),
                Positioned(
                  bottom: 100,
                  left: -50,
                  child: _orb(200, const Color(0xFFFF5C00)),
                ),
              ]);
            },
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: _txt2, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Header
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _cyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _cyan.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.phone_android_rounded,
                              color: _cyan, size: 32),
                        ),
                        const SizedBox(height: 20),

                        Text('Enter your\nphone number',
                            style: GoogleFonts.inter(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: _txt,
                                height: 1.2)),
                        const SizedBox(height: 10),
                        Text(
                          "We'll send a 6-digit code via SMS to verify it's you.",
                          style: GoogleFonts.inter(fontSize: 14, color: _txt2),
                        ),
                        const SizedBox(height: 36),

                        // Phone input
                        Text('PHONE NUMBER',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _muted,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Row(children: [
                          // Country code picker
                          GestureDetector(
                            onTap: _showCountryPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 16),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _gb),
                              ),
                              child: Row(children: [
                                Text(_countryCode,
                                    style: GoogleFonts.inter(
                                        color: _txt,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down,
                                    color: _muted, size: 18),
                              ]),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Number field
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _gb),
                              ),
                              child: TextField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                style: GoogleFonts.inter(
                                    color: _txt,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  hintText: '9876543210',
                                  hintStyle:
                                      GoogleFonts.inter(color: _muted, fontSize: 15),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                ),
                                onSubmitted: (_) => _sendOtp(),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          const Icon(Icons.info_outline, color: _muted, size: 12),
                          const SizedBox(width: 5),
                          Text('Standard SMS rates may apply.',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: _muted)),
                        ]),

                        const Spacer(),

                        // Send OTP button
                        GestureDetector(
                          onTap: _isLoading ? null : _sendOtp,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: _isLoading
                                  ? null
                                  : const LinearGradient(
                                      colors: [_cyan, Color(0xFFFF8C00)]),
                              color: _isLoading ? _muted.withValues(alpha: 0.3) : null,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _isLoading
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: _cyan.withValues(alpha: 0.35),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      )
                                    ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.5))
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.send_rounded,
                                            color: Colors.black, size: 18),
                                        const SizedBox(width: 8),
                                        Text('Send OTP',
                                            style: GoogleFonts.inter(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color.withValues(alpha: 0.10), Colors.transparent]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════
// OTP VERIFICATION SCREEN
// ═══════════════════════════════════════════════════════════════════
class OtpVerifyScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpVerifyScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final List<TextEditingController> _ctrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _foci[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrl) c.dispose();
    for (final f in _foci) f.dispose();
    super.dispose();
  }

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

  String get _otp => _ctrl.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < 6) {
      _showError('Please enter all 6 digits.');
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final res = await Supabase.instance.client.auth.verifyOTP(
        phone: widget.phoneNumber,
        token: _otp,
        type: OtpType.sms,
      );

      if (res.user != null && mounted) {
        await _ensureProfile(res.user!);
        // The StreamBuilder in main.dart auto-navigates to MainDashboard
      }
    } on AuthException catch (e) {
      if (mounted) _showError('Invalid code: ${e.message}');
      // Clear boxes on error
      for (final c in _ctrl) c.clear();
      if (mounted) _foci[0].requestFocus();
    } catch (e) {
      if (mounted) _showError('Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _ensureProfile(User user) async {
    try {
      final existing = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        final phone = widget.phoneNumber;
        final suffix = phone.length >= 4
            ? phone.substring(phone.length - 4)
            : phone;
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'name': 'User_$suffix',
          'username': 'user_${user.id.substring(0, 8)}',
          'full_name': 'Relaya User',
          'avatar_url': 'https://picsum.photos/seed/${user.id}/200',
          'onboarding_complete': false,
          'is_public': true,
          'phone': phone,
        }, onConflict: 'id');
      }
    } catch (e) {
      debugPrint('Profile creation error (non-fatal): $e');
    }
  }

  Future<void> _resend() async {
    if (_countdown > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await Supabase.instance.client.auth
          .signInWithOtp(phone: widget.phoneNumber);
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Code resent to ${widget.phoneNumber}',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      for (final c in _ctrl) c.clear();
      if (mounted) _foci[0].requestFocus();
    } catch (_) {
      if (mounted) _showError('Failed to resend. Try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor: _red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _txt2, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Icon
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _green.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.verified_rounded,
                          color: _green, size: 32),
                    ),
                    const SizedBox(height: 20),

                    Text('Verify your\nnumber',
                        style: GoogleFonts.inter(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: _txt,
                            height: 1.2)),
                    const SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        text: 'Code sent to ',
                        style: GoogleFonts.inter(fontSize: 14, color: _txt2),
                        children: [
                          TextSpan(
                            text: widget.phoneNumber,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _cyan,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── 6 OTP Boxes ─────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, _buildBox),
                    ),
                    const SizedBox(height: 36),

                    // Verify button
                    GestureDetector(
                      onTap: _isVerifying ? null : _verify,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: _isVerifying
                              ? null
                              : const LinearGradient(
                                  colors: [_cyan, Color(0xFFFF8C00)]),
                          color: _isVerifying
                              ? _muted.withValues(alpha: 0.3)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _isVerifying
                              ? []
                              : [
                                  BoxShadow(
                                    color: _cyan.withValues(alpha: 0.35),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  )
                                ],
                        ),
                        child: Center(
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded,
                                        color: Colors.black, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Verify & Continue',
                                        style: GoogleFonts.inter(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Resend row
                    Center(
                      child: _isResending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: _cyan, strokeWidth: 2))
                          : GestureDetector(
                              onTap: _countdown == 0 ? _resend : null,
                              child: RichText(
                                text: TextSpan(
                                  text: "Didn't receive code? ",
                                  style: GoogleFonts.inter(
                                      fontSize: 13, color: _txt2),
                                  children: [
                                    TextSpan(
                                      text: _countdown > 0
                                          ? 'Resend in ${_countdown}s'
                                          : 'Resend OTP',
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBox(int i) {
    return SizedBox(
      width: 48,
      height: 58,
      child: TextField(
        controller: _ctrl[i],
        focusNode: _foci[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.inter(
            color: _txt, fontSize: 24, fontWeight: FontWeight.bold),
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
            if (i < 5) _foci[i + 1].requestFocus();
            if (i == 5) _verify(); // auto-submit on last digit
          }
          setState(() {});
        },
        onTap: () => _ctrl[i].clear(),
      ),
    );
  }
}
