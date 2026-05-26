import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // To get CosmicBackgroundPainter and _buildSafeImageProvider if needed

// Helper functions for displaying profile details
bool hasLifestyle(Map<String, dynamic> p) {
  return (p['drinking']?.toString().isNotEmpty ?? false) ||
         (p['smoking']?.toString().isNotEmpty ?? false) ||
         (p['weed']?.toString().isNotEmpty ?? false) ||
         (p['exercise']?.toString().isNotEmpty ?? false) ||
         (p['diet']?.toString().isNotEmpty ?? false);
}

bool hasMoreAboutMe(Map<String, dynamic> p) {
  return (p['education']?.toString().isNotEmpty ?? false) ||
         (p['job_title']?.toString().isNotEmpty ?? false) ||
         (p['zodiac']?.toString().isNotEmpty ?? false) ||
         (p['religion']?.toString().isNotEmpty ?? false) ||
         (p['relationship_type']?.toString().isNotEmpty ?? false);
}

Widget buildProfileSection(String title, IconData icon, List<Widget> children) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFFF6B00), size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

Widget buildDetailRow(IconData icon, String text, {String? subtitle}) {
  Color iconColor = Colors.white54;
  if (icon == Icons.location_on_outlined) {
    iconColor = const Color(0xFFFF6B00);
  } else if (icon == Icons.height) { iconColor = const Color(0xFFFACC15); }
  else if (icon == Icons.person_outline) { iconColor = const Color(0xFFFF3D00); }
  else if (icon == Icons.search) { iconColor = const Color(0xFF3B82F6); }
  else if (icon == Icons.wine_bar_outlined) { iconColor = const Color(0xFFEF4444); }
  else if (icon == Icons.smoking_rooms_outlined) { iconColor = const Color(0xFF9CA3AF); }
  else if (icon == Icons.grass_outlined) { iconColor = const Color(0xFF10B981); }
  else if (icon == Icons.fitness_center_outlined) { iconColor = const Color(0xFFF97316); }
  else if (icon == Icons.restaurant_outlined) { iconColor = const Color(0xFFEAB308); }
  else if (icon == Icons.school_outlined) { iconColor = const Color(0xFFFF7E40); }
  else if (icon == Icons.work_outline) { iconColor = const Color(0xFF06B6D4); }
  else if (icon == Icons.auto_awesome_outlined) { iconColor = const Color(0xFFD946EF); }
  else if (icon == Icons.church_outlined) { iconColor = const Color(0xFF38D9A9); }
  else if (icon == Icons.favorite_border) { iconColor = const Color(0xFFF43F5E); }
  else { iconColor = const Color(0xFFFF6B00); }

  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: subtitle != null ? CrossAxisAlignment.center : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: iconColor.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null)
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildPill(String text, {bool isHighlight = false, bool isInterest = false, bool isSmall = false}) {
  Color pillColor = isHighlight ? const Color(0xFF38D9A9) : Colors.white70;
  Color bgColor = isHighlight ? const Color(0xFF38D9A9).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05);
  Color borderColor = isHighlight ? const Color(0xFF38D9A9).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08);
  IconData? icon;

  if (isInterest) {
    final lower = text.toLowerCase();
    if (lower.contains('study')) { icon = Icons.menu_book; pillColor = const Color(0xFF3B82F6); }
    else if (lower.contains('fit') || lower.contains('gym')) { icon = Icons.fitness_center; pillColor = const Color(0xFFEF4444); }
    else if (lower.contains('music')) { icon = Icons.music_note; pillColor = const Color(0xFFFF7E40); }
    else if (lower.contains('start') || lower.contains('busin')) { icon = Icons.rocket_launch; pillColor = const Color(0xFFF59E0B); }
    else if (lower.contains('travel')) { icon = Icons.flight; pillColor = const Color(0xFF06B6D4); }
    else if (lower.contains('game') || lower.contains('gaming')) { icon = Icons.sports_esports; pillColor = const Color(0xFF10B981); }
    else if (lower.contains('photo')) { icon = Icons.camera_alt; pillColor = const Color(0xFFFF3D00); }
    else if (lower.contains('cook') || lower.contains('food')) { icon = Icons.restaurant; pillColor = const Color(0xFFF97316); }
    else if (lower.contains('art') || lower.contains('paint')) { icon = Icons.palette; pillColor = const Color(0xFFD946EF); }
    else if (lower.contains('tech') || lower.contains('code')) { icon = Icons.memory; pillColor = const Color(0xFF6366F1); }
    else if (lower.contains('dance')) { icon = Icons.nightlife; pillColor = const Color(0xFFEAB308); }
    else if (lower.contains('read') || lower.contains('book')) { icon = Icons.auto_stories; pillColor = const Color(0xFF14B8A6); }
    else { icon = Icons.local_fire_department; pillColor = const Color(0xFFFF6B00); }
    
    bgColor = pillColor.withValues(alpha: 0.15);
    borderColor = pillColor.withValues(alpha: 0.4);
  }

  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: isSmall ? 10 : 14, 
      vertical: isSmall ? 4 : 8,
    ),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(isSmall ? 12 : 20),
      border: Border.all(color: borderColor),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: pillColor, size: isSmall ? 12 : 14),
          SizedBox(width: isSmall ? 4 : 6),
        ],
        Text(text, style: TextStyle(
          color: pillColor,
          fontSize: isSmall ? 11 : 13,
          fontWeight: isHighlight || isInterest ? FontWeight.w600 : FontWeight.w500,
        )),
      ],
    ),
  );
}

Widget buildActionButton(String text, Color color, BuildContext context, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      alignment: Alignment.center,
      child: Text(text, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
    ),
  );
}

void showFullProfileSheet(BuildContext context, Map<String, dynamic> p, VoidCallback onPass, VoidCallback onKnock) {
  final TextEditingController complimentCtrl = TextEditingController();
  bool isSendingCompliment = false;
  bool complimentSent = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setSheetState) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
      builder: (_, scroll) => Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D0D12),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CosmicBackgroundPainter(0.5),
                    ),
                  ),
                  ListView(
                    controller: scroll,
                    padding: EdgeInsets.zero,
                    children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                // Large Photo
                Container(
                  height: 420,
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    image:
                        (p['avatar'] != null && p['avatar'].toString().isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(p['avatar']),
                                fit: BoxFit.cover)
                            : (p['avatar_url'] != null && p['avatar_url'].toString().isNotEmpty)
                              ? DecorationImage(
                                image: NetworkImage(p['avatar_url']),
                                fit: BoxFit.cover)
                              : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${p['name'] ?? 'User'}, ',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('${p['age'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              color: Colors.white70)),
                    ],
                  ),
                ),

                // About Me
                if ((p['bio']?.toString().isNotEmpty ?? false) || (p['about']?.toString().isNotEmpty ?? false))
                  buildProfileSection('About me', Icons.format_quote_rounded, [
                    Text(p['bio'] ?? p['about'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
                  ]),

                // Essentials
                buildProfileSection('Essentials', Icons.assignment_outlined, [
                  buildDetailRow(Icons.location_on_outlined, '${p['distance'] ?? '< 1 miles'} away'),
                  if (p['height_cm'] != null && p['height_cm'] > 0)
                    buildDetailRow(Icons.height, '${p['height_cm']} cm'),
                  if (p['gender'] != null && p['gender'].toString().isNotEmpty)
                    buildDetailRow(Icons.person_outline, p['gender']),
                  if (p['match_gender'] != null && p['match_gender'].toString().isNotEmpty)
                    buildDetailRow(Icons.search, 'Looking for ${p['match_gender']}'),
                ]),

                // Personality Prompt
                if ((p['personality_traits'] as List?)?.isNotEmpty ?? false)
                  buildProfileSection('My personality', Icons.psychology_outlined, [
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: (p['personality_traits'] as List).map<Widget>((t) => buildPill(t.toString(), isHighlight: true)).toList(),
                    )
                  ]),

                // Lifestyle
                if (hasLifestyle(p))
                  buildProfileSection('Lifestyle', Icons.local_cafe_outlined, [
                    if (p['drinking'] != null && p['drinking'].toString().isNotEmpty)
                      buildDetailRow(Icons.wine_bar_outlined, p['drinking'], subtitle: 'Drinking'),
                    if (p['smoking'] != null && p['smoking'].toString().isNotEmpty)
                      buildDetailRow(Icons.smoking_rooms_outlined, p['smoking'], subtitle: 'Smoking'),
                    if (p['weed'] != null && p['weed'].toString().isNotEmpty)
                      buildDetailRow(Icons.grass_outlined, p['weed'], subtitle: 'Cannabis'),
                    if (p['exercise'] != null && p['exercise'].toString().isNotEmpty)
                      buildDetailRow(Icons.fitness_center_outlined, p['exercise'], subtitle: 'Workout'),
                    if (p['diet'] != null && p['diet'].toString().isNotEmpty)
                      buildDetailRow(Icons.restaurant_outlined, p['diet'], subtitle: 'Diet'),
                  ]),

                // More about me
                if (hasMoreAboutMe(p))
                  buildProfileSection('More about me', Icons.info_outline, [
                    if (p['education'] != null && p['education'].toString().isNotEmpty)
                      buildDetailRow(Icons.school_outlined, p['education'], subtitle: 'Education'),
                    if (p['job_title'] != null && p['job_title'].toString().isNotEmpty)
                      buildDetailRow(Icons.work_outline, p['job_title'], subtitle: 'Work'),
                    if (p['zodiac'] != null && p['zodiac'].toString().isNotEmpty)
                      buildDetailRow(Icons.auto_awesome_outlined, p['zodiac'], subtitle: 'Zodiac'),
                    if (p['religion'] != null && p['religion'].toString().isNotEmpty)
                      buildDetailRow(Icons.church_outlined, p['religion'], subtitle: 'Religion'),
                    if (p['relationship_type'] != null && p['relationship_type'].toString().isNotEmpty)
                      buildDetailRow(Icons.favorite_border, p['relationship_type'], subtitle: 'Looking for'),
                  ]),

                // Interests
                if ((p['interests'] as List?)?.isNotEmpty ?? false)
                  buildProfileSection('Interests', Icons.grid_view_rounded, [
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: (p['interests'] as List).map<Widget>((t) => buildPill(t.toString(), isInterest: true)).toList(),
                    )
                  ]),

                // Compliment Form
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(' Send a Compliment',
                          style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
                          ],
                        ),
                        child: complimentSent 
                        ? const Center(
                            child: Column(
                              children: [
                                SizedBox(height: 16),
                                Icon(Icons.favorite, color: Color(0xFFFF3D00), size: 40),
                                SizedBox(height: 12),
                                Text('Compliment Sent!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                SizedBox(height: 8),
                                Text('They will see it in their messages.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                SizedBox(height: 16),
                              ],
                            ),
                          )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: complimentCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Say something nice...',
                                hintStyle: const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: Colors.black26,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: isSendingCompliment ? null : () async {
                                if (complimentCtrl.text.trim().isEmpty) return;
                                setSheetState(() => isSendingCompliment = true);
                                try {
                                  final myUid = Supabase.instance.client.auth.currentUser?.id;
                                  final targetId = p['user_id']?.toString() ?? p['id']?.toString();
                                  if (myUid != null && targetId != null) {
                                    await Supabase.instance.client.from('messages').insert({
                                      'sender_id': myUid,
                                      'receiver_id': targetId,
                                      'text': '💌 Compliment: ${complimentCtrl.text.trim()}',
                                      'is_image': false,
                                      'created_at': DateTime.now().toUtc().toIso8601String(),
                                    });
                                    setSheetState(() {
                                      complimentSent = true;
                                      isSendingCompliment = false;
                                    });
                                  } else {
                                    setSheetState(() => isSendingCompliment = false);
                                  }
                                } catch (e) {
                                  setSheetState(() => isSendingCompliment = false);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFFFF3D00), Color(0xFFFF7E40)]),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFFFF3D00).withValues(alpha: 0.3), blurRadius: 8),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: isSendingCompliment
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Send Compliment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      buildActionButton('Share ${p['name'] ?? 'Profile'}', Colors.white, context, () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Profile link copied to clipboard!'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Color(0xFF22C55E),
                        ));
                      }),
                      const SizedBox(height: 8),
                      buildActionButton('Block ${p['name'] ?? 'User'}', Colors.white70, context, () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${p['name'] ?? 'User'} blocked. They will no longer appear in your feed.'),
                          behavior: SnackBarBehavior.floating,
                        ));
                      }),
                      const SizedBox(height: 8),
                      buildActionButton('Report ${p['name'] ?? 'User'}', Colors.redAccent, context, () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Report submitted. Our team will review this profile.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.redAccent,
                        ));
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 120), // padding for floating pass/knock buttons
              ],
            ),
                ],
              ),
            ),
          ),

          // Floating Knock / Pass Buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF0D0D12),
                    const Color(0xFF0D0D12).withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        onPass();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
                          ],
                        ),
                        child: const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close, color: Colors.white54, size: 20),
                                SizedBox(width: 8),
                                Text('Pass',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16)),
                              ],
                            )),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        onKnock();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              Color(0xFFFF6B00),
                              Color(0xFF3B82F6)
                            ]),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6))
                            ]),
                        child: const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.waving_hand, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('Knock',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16)),
                              ],
                            )),
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
    ),
  );
}
