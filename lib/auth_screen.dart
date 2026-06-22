// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/doodle_theme.dart';

// ─────────────────────────────────────────────────────────────────
// AUTH SCREEN — Premium Sign In / Sign Up with animations
// ─────────────────────────────────────────────────────────────────

const _bg = Colors.black;
const _bg2 = Color(0xFF111827);
const _card = Color(0xFF1A1F2E);
const _cyan = Color(0xFFFF6B00);
const _green = Color(0xFF22C55E);
const _purple = Color(0xFFFF5C00);
const _pink = Color(0xFFFF8A00);
const _orange = Color(0xFFF97316);
const _red = Color(0xFFEF4444);
const _yellow = Color(0xFFEAB308);
const _txt = Color(0xFFF1F5F9);
const _txt2 = Color(0xFF94A3B8);
const _muted = Color(0xFF64748B);
const _gb = Color(0x14FFFFFF);
const _glass = Color(0x0DFFFFFF);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  // Controllers
  final _suNameCtrl    = TextEditingController();
  final _suEmailCtrl   = TextEditingController();
  final _suPassCtrl    = TextEditingController();
  final _suConfirmCtrl = TextEditingController();
  final _siEmailCtrl   = TextEditingController();
  final _siPassCtrl    = TextEditingController();

  bool _isLoading     = false;
  bool _suObscure     = true;
  bool _suConfObscure = true;
  bool _siObscure     = true;
  bool _isSignup      = true; // true = Sign Up tab, false = Sign In tab

  // Inline errors
  String? _emailError;
  String? _confirmError;

  // Password strength
  int _pwStrength = 0; // 0-4
  String _pwText  = '';
  Color  _pwColor = _muted;

  // Ambient
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
    _suNameCtrl.dispose();
    _suEmailCtrl.dispose();
    _suPassCtrl.dispose();
    _suConfirmCtrl.dispose();
    _siEmailCtrl.dispose();
    _siPassCtrl.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────
  bool _isValidEmail(String e) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e);

  void _checkPwStrength(String pw) {
    if (pw.isEmpty) { setState(() { _pwStrength = 0; _pwText = ''; }); return; }
    int s = 0;
    if (pw.length >= 6) s++;
    if (pw.length >= 10) s++;
    if (RegExp(r'[A-Z]').hasMatch(pw) && RegExp(r'[a-z]').hasMatch(pw)) s++;
    if (RegExp(r'[0-9]').hasMatch(pw)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) s++;

    String text; Color color;
    if (s <= 1) { text = 'Weak — add uppercase, numbers & symbols'; color = _red; }
    else if (s <= 2) { text = 'Fair — getting better, add more variety'; color = _yellow; }
    else if (s <= 3) { text = 'Good — almost there!'; color = _yellow; }
    else { text = 'Strong — great password! 💪'; color = _green; }

    setState(() { _pwStrength = s.clamp(0, 4); _pwText = text; _pwColor = color; });
  }

  // ── Friendly error translation ─────────────────────────────────
  String _friendlyError(dynamic e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('invalid login credentials') || raw.contains('invalid_credentials')) return 'Wrong email or password. Please try again.';
    if (raw.contains('email not confirmed') || raw.contains('email_not_confirmed')) return 'Please confirm your email first. Check your inbox!';
    if (raw.contains('user already registered') || raw.contains('already_exists') || raw.contains('duplicate')) return 'An account with this email already exists. Try signing in instead.';
    if (raw.contains('password should be at least') || raw.contains('weak_password')) return 'Password is too weak. Use at least 6 characters.';
    if (raw.contains('unable to validate email') || raw.contains('invalid email')) return 'Please enter a valid email address.';
    if (raw.contains('network') || raw.contains('socketexception') || raw.contains('connection')) return 'Network error. Please check your internet connection.';
    if (raw.contains('rate limit') || raw.contains('too many') || raw.contains('over_email_send_rate_limit') || raw.contains('429')) return 'Too many attempts. Please wait 60 seconds and try again.';
    return 'Something went wrong. Error: ${e.toString()}';
  }

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

  // ── Auth Actions ────────────────────────────────────────────────
  Future<void> _handleSignup() async {
    final name    = _suNameCtrl.text.trim();
    final email   = _suEmailCtrl.text.trim();
    final pass    = _suPassCtrl.text;
    final confirm = _suConfirmCtrl.text;

    setState(() { _emailError = null; _confirmError = null; });

    bool hasError = false;
    if (name.isEmpty) { _showError('Please enter your full name.'); hasError = true; }
    if (!_isValidEmail(email)) { setState(() => _emailError = 'Please enter a valid email'); hasError = true; }
    if (pass.length < 6) { _showError('Password must be at least 6 characters.'); hasError = true; }
    if (pass != confirm) { setState(() => _confirmError = 'Passwords do not match'); hasError = true; }
    if (hasError) return;

    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: pass,
        data: {'name': name},
      );

      if (res.user != null) {
        // Create profile with all essential fields
        try {
          await Supabase.instance.client.from('profiles').upsert({
            'id': res.user!.id,
            'name': name,
            'full_name': name,
            'avatar_url': 'https://picsum.photos/seed/${res.user!.id}/200',
            'onboarding_complete': false,
            'is_public': true,
          }, onConflict: 'id');
        } catch (profileError) {
          debugPrint('Profile creation error (non-fatal): $profileError');
        }

        if (res.session == null && mounted) {
          _showSuccess('Account created! Please check your email to confirm, then sign in.');
          setState(() => _isSignup = false);
        }
        // If session exists, StreamBuilder in main.dart will auto-navigate
      }
    } on AuthException catch (e) {
      if (mounted) _showError(_friendlyError(e.message));
    } catch (e) {
      if (mounted) _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignin() async {
    final email = _siEmailCtrl.text.trim();
    final pass  = _siPassCtrl.text.trim();

    if (!_isValidEmail(email) || pass.isEmpty) {
      _showError('Please enter a valid email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: pass);
      
      // Ensure profile exists after sign-in (handles edge case where profile creation failed at signup)
      if (res.user != null) {
        try {
          final existing = await Supabase.instance.client
              .from('profiles')
              .select('id')
              .eq('id', res.user!.id)
              .maybeSingle();
          if (existing == null) {
            await Supabase.instance.client.from('profiles').upsert({
              'id': res.user!.id,
              'name': res.user!.userMetadata?['name'] ?? email.split('@').first,
              'full_name': res.user!.userMetadata?['name'] ?? email.split('@').first,
              'avatar_url': 'https://picsum.photos/seed/${res.user!.id}/200',
              'onboarding_complete': false,
              'is_public': true,
            }, onConflict: 'id');
          }
        } catch (_) {}
      }
    } on AuthException catch (e) {
      if (mounted) _showError(_friendlyError(e.message));
    } catch (e) {
      if (mounted) _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleForgotPassword() {
    final resetCtrl = TextEditingController(text: _siEmailCtrl.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Password', style: GoogleFonts.inter(color: _txt, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Enter your email and we'll send you a reset link.", style: GoogleFonts.inter(color: _txt2, fontSize: 13)),
            const SizedBox(height: 16),
            _inputField(controller: resetCtrl, hint: 'Email address', icon: Icons.email_outlined),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: _muted))),
          TextButton(
            onPressed: () async {
              final email = resetCtrl.text.trim();
              Navigator.pop(ctx);
              if (email.isEmpty) return;
              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(email);
                if (mounted) _showSuccess('Reset link sent! Check your inbox.');
              } catch (e) {
                if (mounted) _showError('Error: ${e.toString()}');
              }
            },
            child: Text('Send Reset Link', style: GoogleFonts.inter(color: _cyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _switchTab(bool toSignup) {
    HapticFeedback.selectionClick();
    setState(() {
      _isSignup = toSignup;
      _emailError = null;
      _confirmError = null;
      _pwStrength = 0;
      _pwText = '';
    });
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
                      width: 100,
                      height: 100,
                      child: CustomPaint(
                        painter: YinYangCrescentPainter(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Tab Selector
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
                          alignment: _isSignup ? Alignment.centerLeft : Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: 0.5,
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  colors: [_cyan.withValues(alpha: 0.15), _green.withValues(alpha: 0.1)],
                                ),
                                border: Border.all(color: _cyan.withValues(alpha: 0.2)),
                              ),
                            ),
                          ),
                        ),
                        // Tabs
                        Row(
                          children: [
                            _tab('Sign Up', _isSignup, () => _switchTab(true)),
                            _tab('Sign In', !_isSignup, () => _switchTab(false)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Forms
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: _isSignup ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    firstChild: _buildSignupForm(),
                    secondChild: _buildSigninForm(),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SIGN UP FORM ────────────────────────────────────────────────
  Widget _buildSignupForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _formLabel(Icons.person, 'Full Name'),
        _inputField(controller: _suNameCtrl, hint: 'Enter your full name', icon: Icons.person_outlined),
        const SizedBox(height: 16),

        _formLabel(Icons.email, 'Email Address'),
        _inputField(controller: _suEmailCtrl, hint: 'you@example.com', icon: Icons.email_outlined, type: TextInputType.emailAddress),
        if (_emailError != null) _errorText(_emailError!),
        const SizedBox(height: 16),

        _formLabel(Icons.lock, 'Password'),
        _inputField(
          controller: _suPassCtrl,
          hint: 'Create a strong password',
          icon: Icons.lock_outlined,
          obscure: _suObscure,
          onToggleObscure: () => setState(() => _suObscure = !_suObscure),
          onChanged: _checkPwStrength,
        ),
        const SizedBox(height: 6),
        _buildPwStrengthBars(),
        if (_pwText.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_pwText, style: GoogleFonts.inter(fontSize: 10, color: _pwColor)),
        ),
        const SizedBox(height: 16),

        _formLabel(Icons.lock, 'Confirm Password'),
        _inputField(
          controller: _suConfirmCtrl,
          hint: 'Confirm your password',
          icon: Icons.lock_outlined,
          obscure: _suConfObscure,
          onToggleObscure: () => setState(() => _suConfObscure = !_suConfObscure),
        ),
        if (_confirmError != null) _errorText(_confirmError!),
        const SizedBox(height: 20),

        _primaryButton('Create Account', Icons.person_add, _handleSignup),

        const SizedBox(height: 16),
        _divider('or sign up with'),
        const SizedBox(height: 16),
        _socialButtons(),
        const SizedBox(height: 16),

        Center(
          child: Text.rich(
            TextSpan(
              text: 'By creating an account, you agree to Meetra\'s ',
              style: GoogleFonts.inter(fontSize: 10, color: _muted),
              children: [
                TextSpan(text: 'Terms of Service', style: GoogleFonts.inter(color: _cyan, fontSize: 10)),
                const TextSpan(text: ' and '),
                TextSpan(text: 'Privacy Policy', style: GoogleFonts.inter(color: _cyan, fontSize: 10)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ── SIGN IN FORM ────────────────────────────────────────────────
  Widget _buildSigninForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _formLabel(Icons.email, 'Email Address'),
        _inputField(controller: _siEmailCtrl, hint: 'you@example.com', icon: Icons.email_outlined, type: TextInputType.emailAddress),
        const SizedBox(height: 16),

        _formLabel(Icons.lock, 'Password'),
        _inputField(
          controller: _siPassCtrl,
          hint: 'Enter your password',
          icon: Icons.lock_outlined,
          obscure: _siObscure,
          onToggleObscure: () => setState(() => _siObscure = !_siObscure),
        ),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _handleForgotPassword,
            child: Text('Forgot Password?', style: GoogleFonts.inter(color: _cyan, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),

        const SizedBox(height: 8),
        _primaryButton('Sign In', Icons.login, _handleSignin),

        const SizedBox(height: 16),
        _divider('or sign in with'),
        const SizedBox(height: 16),
        _socialButtons(),
      ],
    );
  }

  // ── Shared Widgets ──────────────────────────────────────────────

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

  Widget _formLabel(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 11, color: _cyan),
          const SizedBox(width: 5),
          Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _txt2)),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType type = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gb),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: type,
        onChanged: onChanged,
        style: GoogleFonts.inter(color: _txt, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
          prefixIcon: Icon(icon, color: _muted, size: 15),
          suffixIcon: onToggleObscure != null
              ? GestureDetector(
                  onTap: onToggleObscure,
                  child: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: _muted, size: 16),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _errorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.error, color: _red, size: 10),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.inter(fontSize: 10, color: _red)),
        ],
      ),
    );
  }

  Widget _buildPwStrengthBars() {
    return Row(
      children: List.generate(4, (i) {
        Color barColor = Colors.white.withValues(alpha: 0.08);
        if (i < _pwStrength) {
          if (_pwStrength <= 1) {
            barColor = _red;
          } else if (_pwStrength <= 3) barColor = _yellow;
          else barColor = _green;
        }
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: barColor),
          ),
        );
      }),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: _isLoading ? null : const LinearGradient(colors: [_cyan, _green]),
          color: _isLoading ? _muted : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _isLoading ? [] : [BoxShadow(color: _cyan.withValues(alpha: 0.3), blurRadius: 25, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Icon(icon, color: Colors.black, size: 18),
            const SizedBox(width: 8),
            Text(
              _isLoading ? 'Please wait...' : label,
              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(String text) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _gb)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: GoogleFonts.inter(fontSize: 12, color: _muted)),
        ),
        Expanded(child: Container(height: 1, color: _gb)),
      ],
    );
  }

  Widget _socialButtons() {
    return Row(
      children: [
        _socialBtn('Google', Icons.g_mobiledata_rounded, const Color(0xFF4285F4)),
        const SizedBox(width: 10),
        _socialBtn('Apple', Icons.apple, Colors.white),
      ],
    );
  }

  Widget _socialBtn(String label, IconData icon, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _gb),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _txt2)),
          ],
        ),
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
