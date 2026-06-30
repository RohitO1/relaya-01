import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/doodle_theme.dart';
import '../main.dart'; // For navigation if needed

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  
  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> with TickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  
  bool _isLoading = false;
  String? _errorMsg;

  late AnimationController _orbCtrl;

  int _resendCountdown = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _startResendCountdown();
  }

  void _startResendCountdown() {
    setState(() => _resendCountdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _countdownTimer?.cancel();
    for (var ctrl in _otpControllers) {
      ctrl.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
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

  Future<void> _verifyOtp() async {
    final otpCode = _otpControllers.map((c) => c.text).join();
    if (otpCode.length < 6) {
      setState(() => _errorMsg = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _errorMsg = null;
      _isLoading = true;
    });

    try {
      final res = await Supabase.instance.client.auth.verifyOTP(
        phone: widget.phoneNumber,
        token: otpCode,
        type: OtpType.sms,
      );

      if (res.user != null) {
        // Create or ensure profile exists (1 phone number = 1 account)
        try {
          final existing = await Supabase.instance.client
              .from('profiles')
              .select('id')
              .eq('id', res.user!.id)
              .maybeSingle();
              
          if (existing == null) {
            await Supabase.instance.client.from('profiles').upsert({
              'id': res.user!.id,
              'name': 'User',
              'full_name': 'User',
              'avatar_url': 'https://picsum.photos/seed/${res.user!.id}/200',
              'onboarding_complete': false,
              'is_public': true,
              'phone': widget.phoneNumber,
            }, onConflict: 'id');
          }
        } catch (_) {}

        if (mounted) {
          // main.dart's auth state listener will automatically navigate
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      }
    } on AuthException catch (e) {
      _showError(e.message);
      setState(() {
        for (var ctrl in _otpControllers) {
          ctrl.clear();
        }
        _focusNodes[0].requestFocus();
      });
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) return;
    
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        phone: widget.phoneNumber,
      );
      _startResendCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('OTP sent again!'),
          backgroundColor: Color(0xFF22C55E),
        ));
      }
    } catch (e) {
      _showError('Could not resend OTP');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onOtpDigitChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyOtp(); // Auto submit when last digit entered
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: txtColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _buildAmbientOrbs(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sms_outlined, color: Color(0xFFFF6B00), size: 40),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Verify Phone Number',
                    style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: txtColor),
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      text: 'Enter the 6-digit code sent to\n',
                      style: GoogleFonts.inter(fontSize: 15, color: hintColor, height: 1.5),
                      children: [
                        TextSpan(
                          text: widget.phoneNumber,
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: txtColor),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // OTP Input Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return Container(
                        width: 48,
                        height: 56,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _focusNodes[index].hasFocus ? const Color(0xFFFF6B00) : borderColor),
                        ),
                        child: TextField(
                          controller: _otpControllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: txtColor, fontSize: 24, fontWeight: FontWeight.bold),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(1),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) => _onOtpDigitChanged(value, index),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),
                      );
                    }),
                  ),

                  if (_errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_errorMsg!, style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 13)),
                    ),

                  const SizedBox(height: 40),

                  // Verify Button
                  GestureDetector(
                    onTap: _isLoading ? null : _verifyOtp,
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
                              : const Icon(Icons.check_circle_outline, color: Colors.black, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _isLoading ? 'Verifying...' : 'Verify OTP',
                            style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Resend Timer
                  GestureDetector(
                    onTap: _resendCountdown == 0 ? _resendOtp : null,
                    child: Text(
                      _resendCountdown > 0 ? 'Resend code in $_resendCountdown s' : 'Resend OTP',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _resendCountdown > 0 ? hintColor : const Color(0xFFFF6B00),
                      ),
                    ),
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
              top: MediaQuery.of(context).size.height * 0.2 + 20 * math.sin(t * math.pi),
              left: -50 + 10 * math.cos(t * math.pi),
              child: _orb(250, const Color(0xFFFF6B00)),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.1,
              right: -50,
              child: _orb(200, const Color(0xFF22C55E)),
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
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.1), Colors.transparent]),
      ),
    );
  }
}
