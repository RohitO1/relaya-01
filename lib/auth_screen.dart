// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'services/doodle_theme.dart';
import 'onboarding_screen.dart';
import 'main.dart' show MainDashboard;

// ─────────────────────────────────────────────────────────────────
// AUTH SCREEN — Premium Hybrid Auth (Phone + Username)
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
  bool _isPhoneMode = true; // true = Phone, false = Username
  int _phoneStep = 0; // 0 = Entry, 1 = OTP

  // Username Auth
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSigningIn = false;
  bool _obscurePassword = true;
  bool _isSendingReset = false;
  
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
  String? _verificationId;
  int? _resendToken;

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
    _orbCtrl.dispose();
    _floatCtrl.dispose();
    _phoneCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
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

  /// Shows a prominent banner when the phone number is already registered,
  /// with an action button that switches the user to the login tab.
  void _showAlreadyRegisteredBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'This number is already registered with Relaya. Please login.',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Login',
          textColor: Colors.black,
          onPressed: () {
            if (mounted) {
              setState(() {
                _isPhoneMode = false; // switch to Username tab
              });
            }
          },
        ),
        backgroundColor: const Color(0xFF1D4ED8), // info blue
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Username Auth Actions ─────────────────────────────────────────
  Future<void> _handleUsernameSignin() async {
    final rawInput = _usernameCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();

    if (rawInput.isEmpty || pass.isEmpty) {
      _showError('Please enter your username and password.');
      return;
    }

    setState(() => _isSigningIn = true);
    try {
      // ── Tier 1: Try username@relaya.app (the email set during onboarding) ──
      final usernameEmail = rawInput.contains('@') ? rawInput : '${rawInput.toLowerCase()}@relaya.app';
      bool loggedIn = false;
      
      try {
        final res = await Supabase.instance.client.auth.signInWithPassword(
          email: usernameEmail,
          password: pass,
        );
        if (res.user != null) loggedIn = true;
      } on AuthException catch (_) {
        // Tier 1 failed — try fallback
      }

      // ── Tier 2: If Supabase email update was pending/unconfirmed, the account may
      // still be registered as phone_<digits>@relaya.app. Look up the phone and try that. ──
      if (!loggedIn) {
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('phone')
              .eq('username', rawInput.toLowerCase())
              .maybeSingle();

          final phone = profile?['phone'] as String?;
          if (phone != null && phone.isNotEmpty) {
            final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
            final phoneEmail = 'phone_$digits@relaya.app';
            try {
              final res = await Supabase.instance.client.auth.signInWithPassword(
                email: phoneEmail,
                password: pass,
              );
              if (res.user != null) {
                loggedIn = true;
                // Now that we successfully logged in, migrate the email so future 
                // logins with username@relaya.app also work
                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(email: usernameEmail),
                  );
                  debugPrint('[Login] Migrated auth email to $usernameEmail');
                } catch (migrateErr) {
                  debugPrint('[Login] Email migration failed (non-fatal): $migrateErr');
                }
              }
            } on AuthException catch (_) {
              // Tier 2 also failed
            }
          }
        } catch (_) {
          // Profile lookup failed — continue to show error
        }
      }

      if (loggedIn && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const _DashboardWrapper()),
          (route) => false,
        );
      } else if (mounted) {
        _showError('Username or password is incorrect. Please try again.');
      }
    } catch (e) {
      if (mounted) _showError('Login failed. Please check your network.');
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  bool _isTestPhoneNumber(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final knownTestNumbers = {
      '16505553434',
      '919876543210',
      '911234567890',
      '919999999999',
      '918888888888',
      '917777777777',
      '910000000000',
      '1234567890',
    };
    return knownTestNumbers.contains(cleanPhone) || cleanPhone.contains('555');
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

    // ── Check if this phone number is already registered ──────────────
    try {
      final existing = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('phone', _fullPhoneNumber)
          .maybeSingle();

      if (existing != null) {
        // Phone already registered — tell the user to login instead
        if (mounted) {
          setState(() => _isLoading = false);
          _showAlreadyRegisteredBanner();
        }
        return;
      }
    } catch (_) {
      // If the check fails for any reason, proceed with OTP (fail-open)
    }
    // ─────────────────────────────────────────────────────────────────

    // Safety timeout — Firebase can hang silently if Play Integrity or reCAPTCHA fails
    bool otpResolved = false;
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && !otpResolved && _isLoading) {
        setState(() => _isLoading = false);
        _showError('OTP request timed out. Check your internet connection and try again.');
      }
    });

    try {
      final isTest = _isTestPhoneNumber(_fullPhoneNumber);
      await firebase.FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: isTest);

      await firebase.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _fullPhoneNumber,
        forceResendingToken: _resendToken,
        verificationCompleted: (firebase.PhoneAuthCredential credential) async {
          otpResolved = true;
          try {
            final userCred = await firebase.FirebaseAuth.instance.signInWithCredential(credential);
            if (userCred.user != null && mounted) {
              await _handleFirebaseUserAuthenticated(userCred.user!);
            }
          } catch (e) {
            debugPrint("Auto verification failed: $e");
          }
        },
        verificationFailed: (firebase.FirebaseAuthException e) {
          otpResolved = true;
          if (mounted) {
            setState(() => _isLoading = false);
            _showError(e.message ?? 'Verification failed.');
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          otpResolved = true;
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _isLoading = false;
              _phoneStep = 1;
            });
            _startTimer();
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _otpFoci[0].requestFocus();
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          otpResolved = true;
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      otpResolved = true;
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to send OTP. Check your connection.');
      }
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

  Future<void> _handleFirebaseUserAuthenticated(firebase.User firebaseUser) async {
    final phone = firebaseUser.phoneNumber ?? _fullPhoneNumber;
    final syntheticEmail = 'phone_${phone.replaceAll('+', '')}@relaya.app';
    final syntheticPassword = 'phone_auth_${firebaseUser.uid}';

    AuthResponse? sbRes;
    try {
      sbRes = await Supabase.instance.client.auth.signInWithPassword(
        email: syntheticEmail,
        password: syntheticPassword,
      );
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials') || e.statusCode == '400' || e.message.contains('User not found')) {
        // User does not exist in Supabase, sign them up
        sbRes = await Supabase.instance.client.auth.signUp(
          email: syntheticEmail,
          password: syntheticPassword,
        );
      } else {
        rethrow;
      }
    }

    if (sbRes.user != null && mounted) {
      final isNewUser = await _ensureProfile(sbRes.user!);
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
  }

  Future<void> _verifyOtp() async {
    if (_otpVal.length < 6) {
      _showError('Please enter all 6 digits.');
      return;
    }
    if (_verificationId == null) {
      _showError('Verification ID not found. Please resend code.');
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final credential = firebase.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpVal,
      );

      final userCred = await firebase.FirebaseAuth.instance.signInWithCredential(credential);

      if (userCred.user != null && mounted) {
        await _handleFirebaseUserAuthenticated(userCred.user!);
      }
    } on firebase.FirebaseAuthException catch (e) {
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
    bool resendResolved = false;
    // Safety timeout for resend
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && !resendResolved && _isResending) {
        setState(() => _isResending = false);
        _showError('Resend timed out. Please try again.');
      }
    });
    try {
      final isTest = _isTestPhoneNumber(_fullPhoneNumber);
      await firebase.FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: isTest);

      await firebase.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _fullPhoneNumber,
        forceResendingToken: _resendToken,
        verificationCompleted: (firebase.PhoneAuthCredential credential) async {
          resendResolved = true;
          try {
            final userCred = await firebase.FirebaseAuth.instance.signInWithCredential(credential);
            if (userCred.user != null && mounted) {
              await _handleFirebaseUserAuthenticated(userCred.user!);
            }
          } catch (e) {
            debugPrint("Auto verification failed: $e");
          }
        },
        verificationFailed: (firebase.FirebaseAuthException e) {
          resendResolved = true;
          if (mounted) {
            setState(() => _isResending = false);
            _showError(e.message ?? 'Failed to resend');
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          resendResolved = true;
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
            });
            _startTimer();
            _showSuccess('Code resent to $_fullPhoneNumber');
            for (final c in _otpCtrl) c.clear();
            _otpFoci[0].requestFocus();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          resendResolved = true;
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isResending = false;
            });
          }
        },
      );
    } catch (_) {
      resendResolved = true;
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

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: active ? _cyan : _muted,
          )),
        ),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
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

                  const SizedBox(height: 30),

                  // Tab Selector
                  if (_phoneStep == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _gb),
                      ),
                      child: Stack(
                        children: [
                          // Slider
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.elasticOut,
                            alignment: _isPhoneMode ? Alignment.centerLeft : Alignment.centerRight,
                            child: FractionallySizedBox(
                              widthFactor: 0.5,
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    colors: [_cyan.withValues(alpha: 0.15), _pink.withValues(alpha: 0.1)],
                                  ),
                                  border: Border.all(color: _cyan.withValues(alpha: 0.2)),
                                ),
                              ),
                            ),
                          ),
                          // Tabs
                          Row(
                            children: [
                              _tab('Phone Auth', _isPhoneMode, () => setState(() => _isPhoneMode = true)),
                              _tab('Username', !_isPhoneMode, () => setState(() => _isPhoneMode = false)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // Content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isPhoneMode 
                      ? (_phoneStep == 0 ? _buildPhoneEntryStep() : _buildOtpVerifyStep())
                      : _buildUsernameLoginStep(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameLoginStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      key: const ValueKey('username'),
      children: [
        Text('Welcome Back',
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: _txt, height: 1.2)),
        const SizedBox(height: 10),
        Text("Sign in with your username and password.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: _txt2, height: 1.4)),
        const SizedBox(height: 40),

        // Username
        Container(
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _gb)),
          child: TextField(
            controller: _usernameCtrl,
            style: GoogleFonts.inter(color: _txt, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Username',
              hintStyle: GoogleFonts.inter(color: _muted, fontSize: 15),
              prefixIcon: const Icon(Icons.person_outline, color: _muted, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Password
        Container(
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _gb)),
          child: TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            style: GoogleFonts.inter(color: _txt, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: GoogleFonts.inter(color: _muted, fontSize: 15),
              prefixIcon: const Icon(Icons.lock_outline, color: _muted, size: 18),
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                child: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: _muted, size: 18),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onSubmitted: (_) => _handleUsernameSignin(),
          ),
        ),
        const SizedBox(height: 40),

        // Login Button
        GestureDetector(
          onTap: _isSigningIn ? null : _handleUsernameSignin,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: _isSigningIn ? null : const LinearGradient(colors: [_cyan, _pink]),
              color: _isSigningIn ? _muted.withValues(alpha: 0.3) : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isSigningIn ? [] : [BoxShadow(color: _cyan.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Center(
              child: _isSigningIn
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login_rounded, color: Colors.black, size: 18),
                        const SizedBox(width: 8),
                        Text('Sign In', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
            ),
          ),
        ),

        // Forgot Password link
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _showForgotPasswordSheet,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_reset_rounded, color: _muted, size: 14),
              const SizedBox(width: 6),
              Text(
                'Forgot Password?',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _cyan,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: _cyan.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Forgot Password — OTP-based reset ───────────────────────────────

  void _showForgotPasswordSheet() {
    // We push a full-screen route so the OTP boxes and keyboard don't fight
    // with a bottom sheet.
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => const _ForgotPasswordFlow(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Widget _buildPhoneEntryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      key: const ValueKey('phone_entry'),
      children: [
        Text('Create an Account',
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
                        Text('Send Code', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
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
    );
  }

  Widget _buildOtpVerifyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      key: const ValueKey('otp_verify'),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _txt2, size: 20),
            onPressed: () {
              setState(() => _phoneStep = 0);
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
// FORGOT PASSWORD — OTP-based reset flow
// ═══════════════════════════════════════════════════════════════════

class _ForgotPasswordFlow extends StatefulWidget {
  const _ForgotPasswordFlow();
  @override
  State<_ForgotPasswordFlow> createState() => _ForgotPasswordFlowState();
}

class _ForgotPasswordFlowState extends State<_ForgotPasswordFlow> {
  // 0 = enter username/phone, 1 = OTP, 2 = new password, 3 = success
  int _step = 0;

  // Step 0
  final _identityCtrl = TextEditingController();
  bool _isLookingUp = false;
  String _resolvedPhone = ''; // full phone with country code
  String _resolvedSyntheticEmail = ''; // phone_XXX@relaya.app
  String _resolvedSyntheticPassword = ''; // phone_auth_<uid>

  // Step 1 — OTP
  final List<TextEditingController> _otpCtrl = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFoci = List.generate(6, (_) => FocusNode());
  String? _verificationId;
  int? _resendToken;
  bool _isVerifying = false;
  bool _isResending = false;
  int _countdown = 60;
  Timer? _timer;

  // Step 2 — new password
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _identityCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _timer?.cancel();
    for (final c in _otpCtrl) c.dispose();
    for (final f in _otpFoci) f.dispose();
    super.dispose();
  }

  String get _otpVal => _otpCtrl.map((c) => c.text).join();

  void _startTimer() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdown == 0) { t.cancel(); } else { setState(() => _countdown--); }
    });
  }

  void _showErr(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: _red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    ));
  }

  // ── Step 0: Look up user by username or phone ───────────────────
  Future<void> _handleLookup() async {
    final raw = _identityCtrl.text.trim();
    if (raw.isEmpty) { _showErr('Please enter your username or phone number.'); return; }
    setState(() => _isLookingUp = true);

    // Detect if input is a phone number (starts with + or 10+ digits)
    final isPhone = raw.startsWith('+') || RegExp(r'^\d{7,}$').hasMatch(raw);

    if (isPhone) {
      // ── Phone entered directly — no DB query needed (avoids RLS issues) ──
      _resolvedPhone = raw.startsWith('+') ? raw : '+91$raw';
      await _sendOtp();
    } else {
      // ── Username entered — must look up their phone number from profiles ──
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('id, phone, username')
            .eq('username', raw.toLowerCase())
            .maybeSingle();

        if (profile == null) {
          _showErr('No account found with that username.');
          setState(() => _isLookingUp = false);
          return;
        }

        final phone = profile['phone'] as String?;
        if (phone == null || phone.isEmpty) {
          _showErr('No phone linked to this account. Enter your phone number directly instead.');
          setState(() => _isLookingUp = false);
          return;
        }

        _resolvedPhone = phone;
        await _sendOtp();
      } on PostgrestException catch (e) {
        _showErr('Could not look up account: ${e.message}. Try entering your phone number directly.');
        setState(() => _isLookingUp = false);
      } catch (e) {
        _showErr('Something went wrong. Try entering your phone number directly.');
        setState(() => _isLookingUp = false);
      }
    }
  }

  // ── Step 1: Send Firebase OTP ────────────────────────────────────
  Future<void> _sendOtp() async {
    if (!mounted) return;
    setState(() => _isLookingUp = true);
    
    // Safety timeout in case Firebase hangs (e.g., due to Play Integrity or reCAPTCHA failure)
    bool otpResolved = false;
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && !otpResolved && _isLookingUp) {
        setState(() => _isLookingUp = false);
        _showErr('OTP request timed out. Please try again or check Play Integrity / reCAPTCHA setup.');
      }
    });

    try {
      await firebase.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _resolvedPhone,
        forceResendingToken: _resendToken,
        verificationCompleted: (firebase.PhoneAuthCredential cred) async {
          otpResolved = true;
          final uc = await firebase.FirebaseAuth.instance.signInWithCredential(cred);
          if (uc.user != null && mounted) await _afterOtpVerified(uc.user!);
        },
        verificationFailed: (firebase.FirebaseAuthException e) {
          otpResolved = true;
          if (mounted) { setState(() => _isLookingUp = false); _showErr(e.message ?? 'OTP send failed.'); }
        },
        codeSent: (String vid, int? rToken) {
          otpResolved = true;
          if (mounted) {
            setState(() { _verificationId = vid; _resendToken = rToken; _isLookingUp = false; _step = 1; });
            _startTimer();
            Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _otpFoci[0].requestFocus(); });
          }
        },
        codeAutoRetrievalTimeout: (String vid) {
          otpResolved = true;
          if (mounted) setState(() { 
            _verificationId = vid; 
            _isLookingUp = false; 
          });
        },
      );
    } catch (e) {
      otpResolved = true;
      if (mounted) { setState(() => _isLookingUp = false); _showErr('Failed to send OTP. Check your connection.'); }
    }
  }

  // ── Step 1: Verify OTP ───────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (_otpVal.length < 6) { _showErr('Enter all 6 digits.'); return; }
    if (_verificationId == null) { _showErr('Verification ID missing. Please resend.'); return; }
    setState(() => _isVerifying = true);
    try {
      final cred = firebase.PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: _otpVal);
      final uc = await firebase.FirebaseAuth.instance.signInWithCredential(cred);
      if (uc.user != null && mounted) await _afterOtpVerified(uc.user!);
    } on firebase.FirebaseAuthException catch (e) {
      _showErr('Invalid code: ${e.message}');
      for (final c in _otpCtrl) c.clear();
      if (mounted) _otpFoci[0].requestFocus();
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _afterOtpVerified(firebase.User firebaseUser) async {
    // Build the synthetic Supabase email used during original phone signup
    final phone = firebaseUser.phoneNumber ?? _resolvedPhone;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    _resolvedSyntheticEmail = 'phone_${digits}@relaya.app';
    _resolvedSyntheticPassword = 'phone_auth_${firebaseUser.uid}';

    // Try to sign into Supabase using the phone synthetic credentials
    bool sessionOk = Supabase.instance.client.auth.currentUser != null;
    if (!sessionOk) {
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _resolvedSyntheticEmail,
          password: _resolvedSyntheticPassword,
        );
        sessionOk = true;
      } catch (e) {
        debugPrint('[ForgotPw] Supabase sign-in failed: $e');
      }
    }

    if (!sessionOk) {
      if (mounted) {
        _showErr('Could not authenticate your account. Please try again.');
        setState(() { _isVerifying = false; });
      }
      return;
    }

    if (mounted) setState(() { _step = 2; _isVerifying = false; });
  }

  // ── Step 2: Save new password ────────────────────────────────────
  Future<void> _saveNewPassword() async {
    final newPass = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();
    if (newPass.length < 6) { _showErr('Password must be at least 6 characters.'); return; }
    if (newPass != confirm) { _showErr('Passwords do not match.'); return; }

    // Guard: we must have an active Supabase session to call updateUser
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      _showErr('Session expired. Please go back and verify OTP again.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Fetch the username linked to this account so we keep username login working
      String? username;
      try {
        final prof = await Supabase.instance.client
            .from('profiles')
            .select('username')
            .eq('id', uid)
            .maybeSingle();
        username = prof?['username'] as String?;
      } catch (_) { /* non-fatal — we'll update without changing email */ }

      // Update both the email alias (username@relaya.app) AND the password
      final attrs = (username != null && username.isNotEmpty)
          ? UserAttributes(email: '${username.toLowerCase()}@relaya.app', password: newPass)
          : UserAttributes(password: newPass);

      await Supabase.instance.client.auth.updateUser(attrs);
      if (mounted) setState(() => _step = 3);
    } on AuthException catch (e) {
      _showErr('Could not update password: ${e.message}');
    } catch (e) {
      _showErr('Unexpected error. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Resend OTP ───────────────────────────────────────────────────
  Future<void> _resendOtp() async {
    if (_countdown > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await firebase.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _resolvedPhone,
        forceResendingToken: _resendToken,
        verificationCompleted: (_) {},
        verificationFailed: (e) { if (mounted) _showErr(e.message ?? 'Resend failed.'); },
        codeSent: (vid, rToken) {
          if (mounted) {
            setState(() { _verificationId = vid; _resendToken = rToken; });
            _startTimer();
            for (final c in _otpCtrl) c.clear();
            _otpFoci[0].requestFocus();
          }
        },
        codeAutoRetrievalTimeout: (vid) { if (mounted) setState(() => _verificationId = vid); },
      );
    } catch (_) {
      if (mounted) _showErr('Failed to resend. Try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent tap-through
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40)],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStep(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _buildStepIdentity();
      case 1: return _buildStepOtp();
      case 2: return _buildStepNewPassword();
      case 3: return _buildStepSuccess();
      default: return const SizedBox.shrink();
    }
  }

  // ── Header helper ────────────────────────────────────────────────
  Widget _header(String title, String subtitle, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _cyan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cyan.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: _cyan, size: 20),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _gb, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.close_rounded, color: _muted, size: 18),
          ),
        ),
      ]),
      const SizedBox(height: 18),
      Text(title, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: _txt)),
      const SizedBox(height: 6),
      Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: _txt2, height: 1.4)),
      const SizedBox(height: 24),
    ]);
  }

  Widget _gradientBtn(String label, IconData icon, VoidCallback? onTap, bool loading) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: loading ? null : const LinearGradient(colors: [_cyan, _pink]),
          color: loading ? _muted.withValues(alpha: 0.25) : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: loading ? [] : [BoxShadow(color: _cyan.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: Colors.black, size: 16),
                  const SizedBox(width: 8),
                  Text(label, style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
        ),
      ),
    );
  }

  // ── Step 0: Identity ─────────────────────────────────────────────
  Widget _buildStepIdentity() {
    return Column(key: const ValueKey(0), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header('Reset Password', 'Enter your username or phone number to receive a verification code.', Icons.lock_reset_rounded),
      // Step dots
      _stepDots(0),
      const SizedBox(height: 24),
      Text('USERNAME OR PHONE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: TextField(
          controller: _identityCtrl,
          autofocus: true,
          style: GoogleFonts.inter(color: _txt, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'username  or  +91XXXXXXXXXX',
            hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
            prefixIcon: const Icon(Icons.person_search_rounded, color: _muted, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onSubmitted: (_) => _handleLookup(),
        ),
      ),
      const SizedBox(height: 24),
      _gradientBtn('Send OTP', Icons.sms_rounded, _handleLookup, _isLookingUp),
    ]);
  }

  // ── Step 1: OTP ──────────────────────────────────────────────────
  Widget _buildStepOtp() {
    return Column(key: const ValueKey(1), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header('Enter OTP', 'A 6-digit code was sent to\n$_resolvedPhone', Icons.phone_iphone_rounded),
      _stepDots(1),
      const SizedBox(height: 24),
      // OTP boxes
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) => _otpBox(i)),
      ),
      const SizedBox(height: 30),
      _gradientBtn('Verify Code', Icons.check_circle_outline_rounded, _verifyOtp, _isVerifying),
      const SizedBox(height: 16),
      Center(
        child: _isResending
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _cyan, strokeWidth: 2))
            : GestureDetector(
                onTap: _countdown == 0 ? _resendOtp : null,
                child: RichText(
                  text: TextSpan(
                    text: "Didn't receive it? ",
                    style: GoogleFonts.inter(fontSize: 13, color: _txt2),
                    children: [
                      TextSpan(
                        text: _countdown > 0 ? 'Resend in ${_countdown}s' : 'Resend OTP',
                        style: GoogleFonts.inter(fontSize: 13, color: _countdown > 0 ? _muted : _cyan, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    ]);
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 44,
      height: 54,
      child: TextField(
        controller: _otpCtrl[i],
        focusNode: _otpFoci[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.inter(color: _txt, fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.25),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cyan, width: 2)),
        ),
        onChanged: (val) {
          if (val.isNotEmpty) {
            if (i < 5) { _otpFoci[i + 1].requestFocus(); }
            else { WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && _otpVal.length == 6) _verifyOtp(); }); }
          } else if (val.isEmpty && i > 0) { _otpFoci[i - 1].requestFocus(); }
          setState(() {});
        },
      ),
    );
  }

  // ── Step 2: New Password ─────────────────────────────────────────
  Widget _buildStepNewPassword() {
    return Column(key: const ValueKey(2), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header('Set New Password', 'Choose a strong password. You can use this with your username to log in.', Icons.lock_outline_rounded),
      _stepDots(2),
      const SizedBox(height: 24),
      // New password
      Text('NEW PASSWORD', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
        child: TextField(
          controller: _newPassCtrl,
          obscureText: _obscureNew,
          style: GoogleFonts.inter(color: _txt, fontSize: 15),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Min. 6 characters',
            hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
            prefixIcon: const Icon(Icons.lock_outline, color: _muted, size: 18),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscureNew = !_obscureNew),
              child: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, color: _muted, size: 18),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
      const SizedBox(height: 14),
      // Confirm password
      Text('CONFIRM PASSWORD', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _confirmPassCtrl.text.isEmpty
                ? Colors.white.withValues(alpha: 0.1)
                : (_newPassCtrl.text == _confirmPassCtrl.text ? _green.withValues(alpha: 0.5) : _red.withValues(alpha: 0.5)),
            width: _confirmPassCtrl.text.isEmpty ? 1 : 1.5,
          ),
        ),
        child: TextField(
          controller: _confirmPassCtrl,
          obscureText: _obscureConfirm,
          style: GoogleFonts.inter(color: _txt, fontSize: 15),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _saveNewPassword(),
          decoration: InputDecoration(
            hintText: 'Re-enter password',
            hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
            prefixIcon: const Icon(Icons.lock_outline, color: _muted, size: 18),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
              child: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: _muted, size: 18),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
      if (_confirmPassCtrl.text.isNotEmpty && _newPassCtrl.text != _confirmPassCtrl.text)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text('Passwords do not match', style: GoogleFonts.inter(color: _red, fontSize: 11)),
        ),
      const SizedBox(height: 26),
      _gradientBtn('Save Password', Icons.check_rounded, _saveNewPassword, _isSaving),
    ]);
  }

  // ── Step 3: Success ──────────────────────────────────────────────
  Widget _buildStepSuccess() {
    return Column(key: const ValueKey(3), children: [
      const SizedBox(height: 10),
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [_green.withValues(alpha: 0.3), Colors.transparent]),
          border: Border.all(color: _green.withValues(alpha: 0.5), width: 2),
        ),
        child: const Icon(Icons.check_rounded, color: _green, size: 36),
      ),
      const SizedBox(height: 22),
      Text('Password Updated!', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: _txt)),
      const SizedBox(height: 10),
      Text(
        'Your password has been saved.\nYou can now sign in with your username and new password.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 13, color: _txt2, height: 1.5),
      ),
      const SizedBox(height: 30),
      _gradientBtn('Sign In Now', Icons.login_rounded, () => Navigator.pop(context), false),
    ]);
  }

  // ── Step progress dots ───────────────────────────────────────────
  Widget _stepDots(int current) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: i == current ? 22 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: i <= current ? _cyan : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
      )),
    );
  }
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
