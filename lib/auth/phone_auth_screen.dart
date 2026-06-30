import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/doodle_theme.dart';
// import 'otp_verification_screen.dart'; // OTP verification bypassed for dev
import '../auth_screen.dart'; // Just for the background painter if needed

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> with TickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  String? _phoneError;

  late AnimationController _orbCtrl;
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  // Country Code selector
  String _selectedCountryCode = '+91';
  final List<String> _countryCodes = ['+91', '+1', '+44', '+61', '+81', '+971'];

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
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.error_outline, color: Colors.white, size: 18), const SizedBox(width: 10), Expanded(child: Text(msg, style: const TextStyle(color: Colors.white)))]),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _sendOtp() async {
    final phoneNum = _phoneCtrl.text.trim();
    if (phoneNum.isEmpty || phoneNum.length < 5) {
      setState(() => _phoneError = 'Please enter a valid phone number');
      return;
    }
    setState(() {
      _phoneError = null;
      _isLoading = true;
    });

    final fullNumber = '$_selectedCountryCode$phoneNum';
    // Dev bypass: skip OTP verification, sign in/up with email+password derived from phone
    final fakeEmail = '${fullNumber.replaceAll('+', '')}@meetra.dev';
    const fakePassword = 'meetra_dev_2024!';

    try {
      // Try signing in first
      await Supabase.instance.client.auth.signInWithPassword(
        email: fakeEmail,
        password: fakePassword,
      );
      // Auth state change in main.dart will auto-redirect to dashboard
    } on AuthException catch (signInError) {
      // If user doesn't exist, sign up
      if (signInError.message.contains('Invalid login') || signInError.message.contains('invalid_credentials') || signInError.statusCode == '400') {
        try {
          await Supabase.instance.client.auth.signUp(
            email: fakeEmail,
            password: fakePassword,
            data: {'phone': fullNumber},
          );
          // Auth state change in main.dart will auto-redirect to dashboard
        } on AuthException catch (e) {
          _showError(e.message);
        } catch (e) {
          _showError('Sign up failed: $e');
        }
      } else {
        _showError(signInError.message);
      }
    } catch (e) {
      _showError('Something went wrong. Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = isDoodleMode(context);
    final bg = isLight ? DoodleColors.cream : Colors.black;
    final cardColor = isLight ? Colors.white : const Color(0xFF1A1F2E);
    final txtColor = isLight ? DoodleColors.textPrimary : Colors.white;
    final hintColor = isLight ? Colors.black54 : const Color(0xFF94A3B8);
    final borderColor = isLight ? DoodleColors.navBorder : const Color(0x14FFFFFF);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          _buildAmbientOrbs(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),

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

                  const SizedBox(height: 40),

                  Text(
                    'Welcome to Meetra',
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: txtColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your phone number to continue',
                    style: GoogleFonts.inter(fontSize: 14, color: hintColor),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Phone Input Field
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        // Country Code Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: borderColor)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCountryCode,
                              dropdownColor: cardColor,
                              icon: Icon(Icons.arrow_drop_down, color: hintColor),
                              style: GoogleFonts.inter(color: txtColor, fontSize: 16, fontWeight: FontWeight.w600),
                              items: _countryCodes.map((String code) {
                                return DropdownMenuItem<String>(
                                  value: code,
                                  child: Text(code),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() => _selectedCountryCode = newValue);
                                }
                              },
                            ),
                          ),
                        ),
                        
                        // Phone Number Input
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.inter(color: txtColor, fontSize: 16, letterSpacing: 1),
                            decoration: InputDecoration(
                              hintText: 'Phone Number',
                              hintStyle: GoogleFonts.inter(color: hintColor, fontSize: 16),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_phoneError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Color(0xFFEF4444), size: 12),
                          const SizedBox(width: 4),
                          Text(_phoneError!, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444))),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Get OTP Button
                  GestureDetector(
                    onTap: _isLoading ? null : _sendOtp,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: _isLoading ? null : const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFF22C55E)]),
                        color: _isLoading ? const Color(0xFF64748B) : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _isLoading ? [] : [
                          BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.3), blurRadius: 25, offset: const Offset(0, 6))
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Icon(Icons.message, color: Colors.black, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _isLoading ? 'Signing in...' : 'Continue',
                            style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  Text(
                    'Enter your phone number to get started',
                    style: GoogleFonts.inter(fontSize: 12, color: hintColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
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
              child: _orb(300, const Color(0xFFFF6B00)),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.15,
              left: -60,
              child: _orb(250, const Color(0xFF22C55E)),
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
