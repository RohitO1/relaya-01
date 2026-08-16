import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../services/location_service.dart';
import '../image_upload_service.dart';

void showAdvancedEditCommunitySheet(
    BuildContext context,
    String campId,
    String initialName,
    String? initialDesc,
    String initialCategory,
    String? initialLocationDist,
    String? initialLocationState,
    bool initialIsPrivate,
    String initialBannerColor,
    String initialIcon,
    String? initialAvatarUrl,
    VoidCallback onEdited) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _EditCommunitySheet(
      campId: campId,
      initialName: initialName,
      initialDesc: initialDesc,
      initialCategory: initialCategory,
      initialLocationDist: initialLocationDist,
      initialLocationState: initialLocationState,
      initialIsPrivate: initialIsPrivate,
      initialBannerColor: initialBannerColor,
      initialIcon: initialIcon,
      initialAvatarUrl: initialAvatarUrl,
      onEdited: onEdited,
    ),
  );
}

class _EditCommunitySheet extends StatefulWidget {
  final String campId;
  final String initialName;
  final String? initialDesc;
  final String initialCategory;
  final String? initialLocationDist;
  final String? initialLocationState;
  final bool initialIsPrivate;
  final String initialBannerColor;
  final String initialIcon;
  final String? initialAvatarUrl;
  final VoidCallback onEdited;

  const _EditCommunitySheet(
      {required this.campId,
      required this.initialName,
      this.initialDesc,
      required this.initialCategory,
      this.initialLocationDist,
      this.initialLocationState,
      required this.initialIsPrivate,
      required this.initialBannerColor,
      required this.initialIcon,
      this.initialAvatarUrl,
      required this.onEdited});

  @override
  State<_EditCommunitySheet> createState() => _EditCommunitySheetState();
}

class _EditCommunitySheetState extends State<_EditCommunitySheet> {
  late final TextEditingController nameCtrl;
  late final TextEditingController descCtrl;

  late String category;
  late bool isPrivate;
  late String bannerColor;
  late String icon;
  late String photoUrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.initialName);
    descCtrl = TextEditingController(text: widget.initialDesc ?? '');
    category = widget.initialCategory;
    isPrivate = widget.initialIsPrivate;
    bannerColor = widget.initialBannerColor.isEmpty
        ? '#FF6B00'
        : widget.initialBannerColor;
    icon = widget.initialIcon.isEmpty ? '💬' : widget.initialIcon;
    photoUrl = widget.initialAvatarUrl ?? '';

    if (widget.initialLocationDist != null) {
      locationService.activeDistrictNotifier.value =
          widget.initialLocationDist!;
    }
  }

  final List<Map<String, String>> categories = [
    {'name': 'General', 'icon': '🎯'},
    {'name': 'Local', 'icon': '📍'},
    {'name': 'Gaming', 'icon': '🎮'},
    {'name': 'Tech', 'icon': '💻'},
    {'name': 'Music', 'icon': '🎵'},
    {'name': 'Art', 'icon': '🎨'},
    {'name': 'Fitness', 'icon': '💪'},
  ];

  final List<String> colors = [
    '#FF6B00',
    '#B983FF',
    '#00DFD8',
    '#FF3366',
    '#7856FF',
    '#4CAF50'
  ];

  bool _isCreating = false;

  Future<void> _editCommunity() async {
    if (nameCtrl.text.trim().isEmpty) return;

    setState(() => _isCreating = true);

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        throw Exception('Not logged in');
      }

      final dist = locationService.activeDistrict;
      final state = locationService.activeState;

      // Update community
      await Supabase.instance.client.from('text_camps').update({
        'name': nameCtrl.text.trim(),
        'description':
            descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
        'category': category,
        'icon': icon,
        'banner_color': bannerColor,
        'avatar_url': photoUrl.isNotEmpty ? photoUrl : null,
        'location_district': dist.isNotEmpty ? dist : null,
        'location_state': state.isNotEmpty ? state : null,
        'is_private': isPrivate,
      }).eq('id', widget.campId);

      if (mounted) {
        widget.onEdited();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Community updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update community: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13101E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text('Edit Community',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              // Photo Selection
              Center(
                child: GestureDetector(
                  onTap: () async {
                    setState(() => _isCreating = true);
                    final url = await ImageUploadService.pickAndUpload(
                        context: context, folder: 'community_avatars');

                    setState(() {
                      _isCreating = false;
                      if (url != null) {
                        photoUrl = url;
                      }
                    });
                  },
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B202D),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFFF6B00).withOpacity(0.5),
                          width: 2),
                      image: photoUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(photoUrl), fit: BoxFit.cover)
                          : null,
                    ),
                    child: photoUrl.isEmpty
                        ? const Icon(Icons.add_a_photo,
                            color: Color(0xFFFF6B00))
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Icon and Banner selection
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(int.parse(
                              'FF${bannerColor.replaceAll('#', '')}',
                              radix: 16))
                          .withOpacity(0.2),
                      border: Border.all(
                          color: Color(int.parse(
                              'FF${bannerColor.replaceAll('#', '')}',
                              radix: 16))),
                    ),
                    child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Banner Color',
                            style: GoogleFonts.inter(
                                color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: colors.map((c) {
                              final isSel = c == bannerColor;
                              return GestureDetector(
                                onTap: () => setState(() => bannerColor = c),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(int.parse(
                                        'FF${c.replaceAll('#', '')}',
                                        radix: 16)),
                                    border: Border.all(
                                        color: Colors.white,
                                        width: isSel ? 2 : 0),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),

              TextField(
                controller: nameCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Community Name...',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1B202D),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Description (optional)...',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1B202D),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),

              Text('CATEGORY',
                  style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((c) {
                  final sel = c['name'] == category;
                  return GestureDetector(
                    onTap: () => setState(() {
                      category = c['name']!;
                      icon = c['icon']!;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFFFF6B00).withOpacity(0.15)
                            : const Color(0xFF1B202D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel
                                ? const Color(0xFFFF6B00)
                                : Colors.transparent),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c['icon']!,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(c['name']!,
                              style: GoogleFonts.inter(
                                  color: sel
                                      ? const Color(0xFFFF6B00)
                                      : Colors.white,
                                  fontSize: 13,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              Text('YOUR LOCATION',
                  style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: locationService.activeDistrictNotifier,
                builder: (_, dist, __) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B202D),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: dist.isNotEmpty
                              ? const Color(0xFFFF6B00).withOpacity(0.3)
                              : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on,
                            color: dist.isNotEmpty
                                ? const Color(0xFFFF6B00)
                                : Colors.white38,
                            size: 20),
                        const SizedBox(width: 12),
                        Text(
                          dist.isNotEmpty ? dist : 'Detecting location...',
                          style: GoogleFonts.inter(
                              color: dist.isNotEmpty
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              Text('PRIVACY SETTING',
                  style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isPrivate = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: !isPrivate
                              ? const Color(0xFFFF6B00).withOpacity(0.15)
                              : const Color(0xFF1B202D),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: !isPrivate
                                  ? const Color(0xFFFF6B00)
                                  : Colors.transparent),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.public,
                                color: !isPrivate
                                    ? const Color(0xFFFF6B00)
                                    : Colors.white54),
                            const SizedBox(height: 4),
                            Text('Public',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isPrivate = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isPrivate
                              ? const Color(0xFFFF6B00).withOpacity(0.15)
                              : const Color(0xFF1B202D),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: isPrivate
                                  ? const Color(0xFFFF6B00)
                                  : Colors.transparent),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.lock,
                                color: isPrivate
                                    ? const Color(0xFFFF6B00)
                                    : Colors.white54),
                            const SizedBox(height: 4),
                            Text('Private',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _editCommunity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Save Changes',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
