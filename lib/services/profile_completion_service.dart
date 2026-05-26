import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../edit_profile_screen.dart';

class ProfileCompletionService {
  static const _cyan = Color(0xFFFF6B00);
  static const _card = Color(0xFF1A1F2E);
  static const _txt = Color(0xFFF1F5F9);
  static const _muted = Color(0xFF64748B);

  /// Checks if the current user's profile is complete enough for core actions.
  static Future<bool> isProfileComplete() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return false;

      final data = await Supabase.instance.client
          .from('profiles')
          .select('bio, interests, personality_traits')
          .eq('id', uid)
          .maybeSingle();

      if (data == null) return false;

      final bio = data['bio'] as String?;
      final interests = data['interests'] as List<dynamic>?;
      final traits = data['personality_traits'] as List<dynamic>?;

      // Define what is "complete". For now, we require at least bio, 1 interest, and 1 trait.
      if (bio == null || bio.trim().isEmpty) return false;
      if (interests == null || interests.isEmpty) return false;
      if (traits == null || traits.isEmpty) return false;

      return true;
    } catch (e) {
      debugPrint('Error checking profile completion: $e');
      return false; // Fail safe to requiring completion
    }
  }

  /// Wraps an action. If profile is complete, runs the action.
  /// If not, shows a popup guiding the user to EditProfileScreen.
  static Future<void> requireCompleteProfile(BuildContext context, {required VoidCallback onComplete}) async {
    final isComplete = await isProfileComplete();

    if (isComplete) {
      onComplete();
    } else {
      if (!context.mounted) return;
      _showIncompleteProfilePopup(context);
    }
  }

  static void _showIncompleteProfilePopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cyan.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_add_alt_1, color: _cyan, size: 48),
              const SizedBox(height: 16),
              Text(
                'Complete Your Profile',
                style: GoogleFonts.inter(color: _txt, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'To send messages, create posts, or join activities, please fill out your profile details so others can get to know you!',
                style: GoogleFonts.inter(color: _muted, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Not Now', style: GoogleFonts.inter(color: _muted, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        
                        final uid = Supabase.instance.client.auth.currentUser?.id;
                        if (uid == null) return;
                        
                        final fullProfile = await Supabase.instance.client
                            .from('profiles')
                            .select()
                            .eq('id', uid)
                            .maybeSingle();
                            
                        if (fullProfile != null && context.mounted) {
                          final result = await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => EditProfileScreen(initialProfile: fullProfile)
                          ));
                          if (result == true) {
                            final nowComplete = await isProfileComplete();
                            if (nowComplete && context.mounted) {
                              showCompletionSuccessPopup(context);
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text('Edit Profile', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showCompletionSuccessPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F17),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _cyan.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _cyan.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _cyan.withValues(alpha: 0.1),
                  border: Border.all(color: _cyan, width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: _cyan,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Profile Completed! 🎉',
                style: GoogleFonts.plusJakartaSans(
                  color: _txt,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Fantastic! Your profile is now 100% complete and fully verified.\n\nYou have unlocked full access to connect, knock, chat, post, and explore everything in the Relaya universe!',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: _cyan.withValues(alpha: 0.3),
                  ),
                  child: Text(
                    'Start Exploring 🚀',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
