// ignore_for_file: duplicate_ignore, unused_element, unused_element_parameter, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'rush_in_consumer_detail_view.dart';
import 'image_upload_service.dart';
import 'services/location_service.dart';
import 'widgets/app_header_actions.dart';

// ════════════════════════════════════════════════════════════════════
// EXPERIENCE DESIGN SYSTEM
// ════════════════════════════════════════════════════════════════════
class ExperienceColors {
  static const Color bgPrimary = Color(0xFF06070B);
  static const Color bgSecondary = Color(0xFF0A0C14);
  static const Color bgCard = Color(0xFF10121A);
  static const Color accentCyan = Color(0xFF00E5CC);
  static const Color accentPurple = Color(0xFF9D4EDD);
  static const Color accentPink = Color(0xFFFF2E97);
  static const Color accentBlue = Color(0xFF4E8BFF);
  static const Color textPrimary = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF93A2C4);

  static LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.08),
      Colors.white.withValues(alpha: 0.02),
    ],
  );

  static LinearGradient primaryGradient = const LinearGradient(
    colors: [accentCyan, accentBlue],
  );
}

// ════════════════════════════════════════════════════════════════════
// AMBIENT BACKGROUND PAINTER
// ════════════════════════════════════════════════════════════════════
class _ExperienceBackgroundPainter extends CustomPainter {
  final double animationValue;
  _ExperienceBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    // Orb 1: Cyan
    final orb1Pos = Offset(
      size.width * 0.2 + (Offset(animationValue, 0).dx * 40),
      size.height * 0.3 + (Offset(0, animationValue).dy * 60),
    );
    paint.color = ExperienceColors.accentCyan.withValues(alpha: 0.15);
    canvas.drawCircle(orb1Pos, 120, paint);

    // Orb 2: Purple
    final orb2Pos = Offset(
      size.width * 0.8 - (Offset(animationValue, 0).dx * 50),
      size.height * 0.6 + (Offset(0, animationValue).dy * 40),
    );
    paint.color = ExperienceColors.accentPurple.withValues(alpha: 0.12);
    canvas.drawCircle(orb2Pos, 150, paint);

    // Orb 3: Pink
    final orb3Pos = Offset(
      size.width * 0.5 + (Offset(animationValue, 0).dx * 30),
      size.height * 0.8 - (Offset(0, animationValue).dy * 70),
    );
    paint.color = ExperienceColors.accentPink.withValues(alpha: 0.1);
    canvas.drawCircle(orb3Pos, 100, paint);
  }

  @override
  bool shouldRepaint(covariant _ExperienceBackgroundPainter oldDelegate) => 
      oldDelegate.animationValue != animationValue;
}

class ExperienceScreen extends StatefulWidget {
  const ExperienceScreen({super.key});

  @override
  State<ExperienceScreen> createState() => _ExperienceScreenState();
}

class _ExperienceScreenState extends State<ExperienceScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _orbController;
  final ScrollController _mainScrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  String _selectedCategory = 'All Events';
  String _searchQuery = '';
  List<Map<String, dynamic>> _allActivities = [];
  List<Map<String, dynamic>> _filteredActivities = [];
  bool _loadingActivities = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _orbController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text;
        _applyLocalFilters();
      });
    });
    
    _fetchActivities();
    locationService.coordinatesUpdateNotifier.addListener(_fetchActivities);
  }

  @override
  void dispose() {
    locationService.coordinatesUpdateNotifier.removeListener(_fetchActivities);
    _tabController.dispose();
    _orbController.dispose();
    _mainScrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyLocalFilters() {
    setState(() {
      _filteredActivities = _allActivities.where((a) {
        final matchesCategory = _selectedCategory == 'All Events' || 
            (a['category']?.toString() ?? '').toLowerCase().contains(_selectedCategory.toLowerCase());
        final matchesSearch = _searchQuery.isEmpty || 
            (a['title']?.toString() ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (a['description']?.toString() ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  Future<void> _fetchActivities() async {
    if (!mounted) return;
    setState(() => _loadingActivities = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final currentDistrict = locationService.activeLocation.split(',').first.trim();

      var query = Supabase.instance.client.from('activities').select().eq('is_active', true).eq('is_rush_in', false);
      
      // Only filter by district if it's not empty — use ilike for case-insensitive match
      if (currentDistrict.isNotEmpty) {
        query = query.ilike('district', '%$currentDistrict%');
      }

      final data = await query.order('created_at', ascending: false).limit(50);
      if (mounted) {
        _allActivities = (data as List).cast<Map<String, dynamic>>().where((a) => a['user_id'] != uid).toList();
        _applyLocalFilters();
        setState(() => _loadingActivities = false);
      }
    } catch (e) {
      debugPrint('Fetch activities error: $e');
      if (mounted) setState(() => _loadingActivities = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExperienceColors.bgPrimary,
      floatingActionButton: _tabController.index == 1 ? _buildCompanionFAB() : null,
      body: Stack(
        children: [
          // 1. Ambient Background
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, child) {
              return CustomPaint(
                painter: _ExperienceBackgroundPainter(_orbController.value),
                size: Size.infinite,
              );
            },
          ),

          // 2. Main Content
          SafeArea(
            child: NestedScrollView(
              controller: _mainScrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // Header
                  SliverToBoxAdapter(child: _buildCustomHeader()),

                  // Stats & Switcher
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildCustomTabSwitcher(),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildEventsView(),
                  const _CompanionsView(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanionFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        // Find _CompanionsViewState and call _openRegisterFlow
        // For simplicity, we can just navigate directly from here
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _CompanionRegisterScreen()),
        );
      },
      backgroundColor: ExperienceColors.accentPink,
      icon: const Icon(Icons.volunteer_activism, color: Colors.white),
      label: Text(
        'Become a Companion',
        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }



  Widget _buildCustomHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds),
              child: Text(
                'EXPERIENCE',
                style: GoogleFonts.boogaloo(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const AppHeaderActions(),
        ],
      ),
    );
  }

  Widget _buildCustomTabSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: ExperienceColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: ExperienceColors.accentCyan.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white60,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'EVENTS'),
          Tab(text: 'COMPANIONS'),
        ],
      ),
    );
  }

  Widget _buildEventsView() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white38),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    onChanged: (v) {
                       setState(() {
                         _searchQuery = v;
                         _applyLocalFilters();
                       });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search premium events...',
                      hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ExperienceColors.accentCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune, color: ExperienceColors.accentCyan, size: 18),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: _loadingActivities 
            ? const Center(child: CircularProgressIndicator(color: ExperienceColors.accentCyan))
            : _filteredActivities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_busy, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      Text('No events near your selected location', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: _filteredActivities.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildCategoryPill('All Events', isSelected: _selectedCategory == 'All Events'),
                                _buildCategoryPill('Music & Arts', isSelected: _selectedCategory == 'Music & Arts'),
                                _buildCategoryPill('Tech & AI', isSelected: _selectedCategory == 'Tech & AI'),
                                _buildCategoryPill('Fitness', isSelected: _selectedCategory == 'Fitness'),
                                _buildCategoryPill('Dining', isSelected: _selectedCategory == 'Dining'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            'FEATURED EXPERIENCE',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: ExperienceColors.accentCyan,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_filteredActivities.isNotEmpty)
                            _buildFeaturedCard(context, _filteredActivities.first),
                          const SizedBox(height: 30),
                          Text(
                            'TRENDING NOW',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }
                    final act = _filteredActivities[index - 1];
                    return _buildExperienceCard(context, act);
                  },
                ),
        ),
      ],
    );
  }


  Widget _buildCategoryPill(String label, {bool isSelected = false}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
          _applyLocalFilters();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? ExperienceColors.accentCyan.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? ExperienceColors.accentCyan.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isSelected ? ExperienceColors.accentCyan : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(BuildContext context, Map<String, dynamic> act) {
    final title = act['title'] ?? 'Exclusive Event';
    final location = act['location_name'] ?? 'In-person';
    final imageId = act['id'].toString().length % 100;
    final image = 'https://picsum.photos/seed/$imageId/800/400';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => RushInConsumerDetailView(
          activity: act,
          onInteraction: () {},
        )));
      },
      child: Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: DecorationImage(image: NetworkImage(image), fit: BoxFit.cover),
          boxShadow: [
            BoxShadow(
              color: ExperienceColors.accentCyan.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                ),
              ),
            ),
            Positioned(
              top: 15,
              right: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ExperienceColors.accentCyan,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'FEATURED',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: ExperienceColors.accentCyan, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        '₹${act['price'] ?? 0}',
                        style: GoogleFonts.plusJakartaSans(
                          color: ExperienceColors.accentCyan,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).moveY(begin: 20, end: 0);
  }

  Widget _buildExperienceCard(BuildContext context, Map<String, dynamic> act) {
    final title = act['title'] ?? 'Experience';
    final location = act['location_name'] ?? 'Somewhere';
    final price = act['price']?.toString() ?? '0';
    final category = (act['category']?.toString() ?? 'EVENT').split(',').first.toUpperCase();
    final imageId = act['id'].toString().length % 100;
    final image = 'https://picsum.photos/seed/$imageId/400/300';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => RushInConsumerDetailView(
            activity: act,
            onInteraction: () {},
          )));
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  image,
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ExperienceColors.accentPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.inter(
                          color: ExperienceColors.accentPurple,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white38, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹$price',
                          style: GoogleFonts.plusJakartaSans(
                            color: ExperienceColors.accentCyan,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: ExperienceColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Book Now',
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }
}


// ════════════════════════════════════════════════════════════════════
// 2. COMPANIONS VIEW — Live from Supabase (self-filtered)
// ════════════════════════════════════════════════════════════════════
class _CompanionsView extends StatefulWidget {
  const _CompanionsView();

  @override
  State<_CompanionsView> createState() => _CompanionsViewState();
}

class _CompanionsViewState extends State<_CompanionsView> {
  final _currentUid = Supabase.instance.client.auth.currentUser?.id;

  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
  }


  List<String> _parseList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) {
      return raw.replaceAll('{', '').replaceAll('}', '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> companions) {
    // ✅ FIX: Always filter out the current user's own listing
    final filtered = companions.where((c) => c['user_id']?.toString() != _currentUid).toList();

    if (_selectedFilter == 'All') return filtered;
    if (_selectedFilter == 'Free') {
      return filtered.where((c) {
        final rate = c['hourly_rate'];
        return rate == null || rate == 0;
      }).toList();
    }
    if (_selectedFilter == 'Professional') {
      return filtered.where((c) => c['category'] == 'professional').toList();
    }
    if (_selectedFilter == 'Companion') {
      return filtered.where((c) => c['category'] == 'companion').toList();
    }
    return filtered.where((c) {
      final skills = _parseList(c['skills']);
      return skills.any((s) => s.toLowerCase().contains(_selectedFilter.toLowerCase()));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search & Filter
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white24, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          onChanged: (v) => setState(() => _selectedFilter = v.isEmpty ? 'All' : v),
                          decoration: InputDecoration(
                            hintText: 'Search companions...',
                            hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                            border: InputBorder.none,
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

        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              _buildFilterPill('All'),
              _buildFilterPill('Professional'),
              _buildFilterPill('Companion'),
              _buildFilterPill('Free'),
              _buildFilterPill('Yoga'),
              _buildFilterPill('Music'),
            ],
          ),
        ),

        // Live Companions List
        Expanded(
          child: _CompanionsList(
            currentUid: _currentUid,
            selectedFilter: _selectedFilter,
            parseList: _parseList,
            applyFilter: _applyFilter,
            onOpenDetail: _openCompanionDetail,
          ),
        ),
      ],
    );
  }

  void _openCompanionDetail(Map<String, dynamic> comp) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanionDetailScreen(
          comp: comp,
          parseList: _parseList,
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? ExperienceColors.accentPurple.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: isSelected ? ExperienceColors.accentPurple.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: isSelected ? ExperienceColors.accentPurple : Colors.white60,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// COMPANIONS LIST — Reliable fetch-based list (no stream drop)
// ════════════════════════════════════════════════════════════════════
class _CompanionsList extends StatefulWidget {
  final String? currentUid;
  final String selectedFilter;
  final List<String> Function(dynamic) parseList;
  final List<Map<String, dynamic>> Function(List<Map<String, dynamic>>) applyFilter;
  final void Function(Map<String, dynamic>) onOpenDetail;

  const _CompanionsList({
    required this.currentUid,
    required this.selectedFilter,
    required this.parseList,
    required this.applyFilter,
    required this.onOpenDetail,
  });

  @override
  State<_CompanionsList> createState() => _CompanionsListState();
}

class _CompanionsListState extends State<_CompanionsList> {
  List<Map<String, dynamic>> _companions = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchCompanions();
    // Auto-refresh every 30 seconds to keep list alive
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchCompanions());
    locationService.coordinatesUpdateNotifier.addListener(_fetchCompanions);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    locationService.coordinatesUpdateNotifier.removeListener(_fetchCompanions);
    super.dispose();
  }

  Future<void> _fetchCompanions() async {
    try {
      final currentDistrict = locationService.activeLocation.split(',').first.trim();
      
      List<dynamic> data;
      
      if (currentDistrict.isNotEmpty) {
        // Try filtering by districts array first
        try {
          data = await Supabase.instance.client.from('companions').select()
            .contains('districts', [currentDistrict])
            .order('created_at', ascending: false);
        } catch (_) {
          // If districts column query fails, fetch all
          data = await Supabase.instance.client.from('companions').select()
            .order('created_at', ascending: false);
        }
        
        // If district filter returned empty, fall back to all companions
        if (data.isEmpty) {
          data = await Supabase.instance.client.from('companions').select()
            .order('created_at', ascending: false);
        }
      } else {
        data = await Supabase.instance.client.from('companions').select()
          .order('created_at', ascending: false);
      }

      if (mounted) {
        setState(() {
          _companions = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch companions error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: ExperienceColors.accentPurple));
    }

    final filtered = widget.applyFilter(_companions);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, color: Colors.white.withValues(alpha: 0.1), size: 80),
            const SizedBox(height: 16),
            Text('No companions found', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Try a different search or filter', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () { setState(() => _loading = true); _fetchCompanions(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: ExperienceColors.accentPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ExperienceColors.accentPurple.withValues(alpha: 0.3)),
                ),
                child: Text('Refresh', style: GoogleFonts.inter(color: ExperienceColors.accentPurple, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCompanions,
      color: ExperienceColors.accentPurple,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final comp = filtered[index];
          return _CompanionCard(
            comp: comp,
            parseList: widget.parseList,
            onTap: () => widget.onOpenDetail(comp),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// COMPANION CARD WIDGET
// ════════════════════════════════════════════════════════════════════
class _CompanionCard extends StatelessWidget {
  final Map<String, dynamic> comp;
  final List<String> Function(dynamic) parseList;
  final VoidCallback onTap;

  const _CompanionCard({required this.comp, required this.parseList, required this.onTap});

  ImageProvider _safeProvider(String url) {
    if (url.startsWith('data:image')) {
      return MemoryImage(base64Decode(url.split(',').last));
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final isPro = comp['category'] == 'professional';
    final rate = comp['hourly_rate'];
    final isFree = rate == null || rate == 0;
    final skills = parseList(comp['skills']);
    final avatarUrl = comp['avatar_url'] as String? ?? 'https://picsum.photos/200';
    final verificationStatus = comp['verification_status'] as String? ?? 'unverified';

    Color accentColor = isPro ? ExperienceColors.accentPurple : ExperienceColors.accentCyan;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 2),
                      image: DecorationImage(
                        image: _safeProvider(avatarUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (comp['is_active'] == true)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: ExperienceColors.bgPrimary, width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.green.withValues(alpha: 0.5), blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            comp['name'] ?? 'Anonymous',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (verificationStatus == 'verified')
                          const Icon(Icons.verified, color: ExperienceColors.accentCyan, size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      comp['title'] ?? 'Companion',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: skills.take(3).map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accentColor.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          s,
                          style: GoogleFonts.inter(
                            color: accentColor.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber.withValues(alpha: 0.8), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '4.9', // Mock rating
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          isFree ? 'FREE' : '₹$rate/hr',
                          style: GoogleFonts.plusJakartaSans(
                            color: isFree ? ExperienceColors.accentCyan : ExperienceColors.accentPurple,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// COMPANION DETAIL SCREEN — Full Profile with Connect Pipeline
// ════════════════════════════════════════════════════════════════════
class CompanionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> comp;
  final List<String> Function(dynamic) parseList;

  const CompanionDetailScreen({super.key, required this.comp, required this.parseList});

  @override
  State<CompanionDetailScreen> createState() => _CompanionDetailScreenState();
}

class _CompanionDetailScreenState extends State<CompanionDetailScreen> {
  bool _hasRequested = false;
  bool _isRequesting = false;
  bool _isLoadingRequestState = true;
  String? _requestStatus; // pending, approved, rejected

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
  }

  Future<void> _checkExistingRequest() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _isLoadingRequestState = false);
      return;
    }
    try {
      final companionId = widget.comp['id']?.toString();
      if (companionId == null) {
        setState(() => _isLoadingRequestState = false);
        return;
      }
      final existing = await Supabase.instance.client
          .from('requests')
          .select('id, status')
          .eq('sender_id', uid)
          .eq('target_id', companionId)
          .eq('target_type', 'companion')
          .maybeSingle();
      if (mounted) {
        setState(() {
          _hasRequested = existing != null;
          _requestStatus = existing?['status'] as String?;
          _isLoadingRequestState = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRequestState = false);
    }
  }

  Future<void> _sendConnectRequest() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _isRequesting = true);
    HapticFeedback.mediumImpact();

    try {
      final companionId = widget.comp['id']?.toString();
      final companionUserId = widget.comp['user_id']?.toString();
      final companionName = widget.comp['name'] ?? 'this companion';

      // 1. Get current user's name
      final myProfile = await Supabase.instance.client
          .from('profiles')
          .select('name, full_name')
          .eq('id', uid)
          .maybeSingle();
      final myName = myProfile?['name'] ?? myProfile?['full_name'] ?? 'Someone';

      // 2. Insert request
      await Supabase.instance.client.from('requests').insert({
        'sender_id': uid,
        'target_id': companionId,
        'target_type': 'companion',
        'status': 'pending',
        'message': 'I would like to connect with you as a companion.',
      });

      // 3. Notify companion via messages table
      if (companionUserId != null) {
        await Supabase.instance.client.from('messages').insert({
          'sender_id': uid,
          'receiver_id': companionUserId,
          'text': '🤝 New Connection Request from $myName! They want to connect with you as a companion. Open your Companion Management Hub to review their profile.',
          'is_image': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      if (mounted) {
        setState(() {
          _hasRequested = true;
          _requestStatus = 'pending';
          _isRequesting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection request sent to $companionName! 🎉\nThey will review your profile and respond.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRequesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }


  ImageProvider _safeProvider(String url) {
    if (url.startsWith('data:image')) {
      return MemoryImage(base64Decode(url.split(',').last));
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final isPro = widget.comp['category'] == 'professional';
    final rate = widget.comp['hourly_rate'];
    final isFree = rate == null || rate == 0 || rate == '0';
    final skills = widget.parseList(widget.comp['skills']);
    final avatarUrl = widget.comp['avatar_url']?.toString() ?? 'https://picsum.photos/200';
    final name = widget.comp['name']?.toString() ?? 'Unknown';
    final title = widget.comp['title']?.toString() ?? '';
    final experience = widget.comp['experience']?.toString() ?? 'New';
    final offering = widget.comp['offering']?.toString();
    final bio = widget.comp['bio']?.toString();
    final city = widget.comp['city']?.toString();
    final languages = widget.parseList(widget.comp['languages']);
    final verificationStatus = widget.comp['verification_status'] as String? ?? 'unverified';

    // Request button state
    Widget connectButton;
    if (_isLoadingRequestState) {
      connectButton = Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
      );
    } else if (_requestStatus == 'approved') {
      connectButton = Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Connected! ✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        )),
      );
    } else if (_hasRequested) {
      connectButton = Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: const Center(child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top, color: Color(0xFFFBBF24), size: 18),
            SizedBox(width: 8),
            Text('Request Pending…', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        )),
      );
    } else {
      connectButton = GestureDetector(
        onTap: _isRequesting ? null : _sendConnectRequest,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: isPro
                ? [ExperienceColors.accentPurple, ExperienceColors.accentPink]
                : [ExperienceColors.accentCyan, ExperienceColors.accentBlue]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: (isPro ? ExperienceColors.accentPurple : ExperienceColors.accentCyan).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Center(
            child: _isRequesting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(
                    isPro ? 'Book Now  •  ₹$rate/hr' : 'Connect for Free',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ExperienceColors.bgPrimary,
      body: Stack(
        children: [
          // Ambient Background
          CustomPaint(
            painter: _ExperienceBackgroundPainter(0.5), // Static for detail view
            size: Size.infinite,
          ),

          // Content
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leadingWidth: 70,
                leading: Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: _safeProvider(avatarUrl),
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              ExperienceColors.bgPrimary.withValues(alpha: 0.5),
                              ExperienceColors.bgPrimary,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 30,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isPro ? ExperienceColors.accentPurple : ExperienceColors.accentCyan).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: (isPro ? ExperienceColors.accentPurple : ExperienceColors.accentCyan).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                isPro ? 'PROFESSIONAL' : 'COMPANION',
                                style: GoogleFonts.inter(
                                  color: isPro ? ExperienceColors.accentPurple : ExperienceColors.accentCyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                if (verificationStatus == 'verified')
                                  const Icon(Icons.verified, color: ExperienceColors.accentCyan, size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetailStat('Experience', experience),
                          _buildDetailStat('Rating', '4.9/5'),
                          _buildDetailStat('Rate', isFree ? 'Free' : '₹$rate/hr'),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // City Box
                      if (city != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: ExperienceColors.accentCyan, size: 18),
                            const SizedBox(width: 8),
                            Text(city, style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 30),
                      ],

                      // Bio / About
                      Text('ABOUT', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: ExperienceColors.accentCyan, letterSpacing: 2)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Text(
                          bio ?? (offering ?? 'No bio provided for this companion.'),
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 15, height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Skills
                      if (skills.isNotEmpty) ...[
                        Text('SKILLS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: ExperienceColors.accentPurple, letterSpacing: 2)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10, runSpacing: 10,
                          children: skills.map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: ExperienceColors.accentPurple.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ExperienceColors.accentPurple.withValues(alpha: 0.2)),
                            ),
                            child: Text(s, style: GoogleFonts.inter(color: ExperienceColors.accentPurple, fontWeight: FontWeight.w600, fontSize: 13)),
                          )).toList(),
                        ),
                        const SizedBox(height: 30),
                      ],

                      // Languages
                      if (languages.isNotEmpty) ...[
                        Text('LANGUAGES', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: ExperienceColors.accentPink, letterSpacing: 2)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10, runSpacing: 10,
                          children: languages.map((l) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: ExperienceColors.accentPink.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ExperienceColors.accentPink.withValues(alpha: 0.2)),
                            ),
                            child: Text(l, style: GoogleFonts.inter(color: ExperienceColors.accentPink, fontWeight: FontWeight.w600, fontSize: 13)),
                          )).toList(),
                        ),
                        const SizedBox(height: 30),
                      ],

                      const SizedBox(height: 100), // Spacing for bottom button
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sticky Bottom Connect Button
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: connectButton,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// PROOF GALLERY VIEWER — Full screen swipeable gallery
// ════════════════════════════════════════════════════════════════════
class _ProofGalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _ProofGalleryViewer({required this.images, required this.initialIndex});
  @override
  State<_ProofGalleryViewer> createState() => _ProofGalleryViewerState();
}

class _ProofGalleryViewerState extends State<_ProofGalleryViewer> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  ImageProvider _safeProvider(String url) {
    if (url.startsWith('data:image')) return MemoryImage(base64Decode(url.split(',').last));
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('${_current + 1} / ${widget.images.length}', style: const TextStyle(color: Colors.white70)),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => Center(
          child: InteractiveViewer(
            child: Image(
              image: _safeProvider(widget.images[i]),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 60)),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// COMPANION INBOUND REQUEST DETAIL — Requester Profile Review
// ════════════════════════════════════════════════════════════════════
class CompanionRequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onStatusChanged;

  const CompanionRequestDetailScreen({super.key, required this.request, required this.onStatusChanged});

  @override
  State<CompanionRequestDetailScreen> createState() => _CompanionRequestDetailScreenState();
}

class _CompanionRequestDetailScreenState extends State<CompanionRequestDetailScreen> {
  Map<String, dynamic>? _requesterProfile;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadRequesterProfile();
  }

  Future<void> _loadRequesterProfile() async {
    final senderId = widget.request['sender_id']?.toString();
    if (senderId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', senderId)
          .maybeSingle();
      if (mounted) setState(() { _requesterProfile = profile; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    try {
      final requestId = widget.request['id'];
      final senderId = widget.request['sender_id']?.toString();
      final myUid = Supabase.instance.client.auth.currentUser?.id;

      await Supabase.instance.client
          .from('requests')
          .update({'status': newStatus})
          .eq('id', requestId);

      // Notify the requester with a message
      if (senderId != null && myUid != null) {
        final myProfile = await Supabase.instance.client
            .from('profiles')
            .select('name, full_name')
            .eq('id', myUid)
            .maybeSingle();
        final myName = myProfile?['name'] ?? myProfile?['full_name'] ?? 'A companion';
        final msg = newStatus == 'approved'
            ? '✅ Great news! $myName has accepted your connection request. You can now chat and plan your meetup!'
            : '❌ $myName has reviewed your request and decided not to connect at this time. Don\'t worry — keep exploring!';

        await Supabase.instance.client.from('messages').insert({
          'sender_id': myUid,
          'receiver_id': senderId,
          'text': msg,
          'is_image': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newStatus == 'approved' ? 'Connection Approved! 🎉 Requester has been notified.' : 'Request Declined. Requester has been notified.'),
          backgroundColor: newStatus == 'approved' ? const Color(0xFF10B981) : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        widget.onStatusChanged();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  List<String> _parseList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) return raw.replaceAll('{', '').replaceAll('}', '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return [];
  }

  ImageProvider _safeProvider(String url) {
    if (url.startsWith('data:image')) return MemoryImage(base64Decode(url.split(',').last));
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = widget.request['status'] as String? ?? 'pending';
    final isApproved = currentStatus == 'approved';
    final isRejected = currentStatus == 'rejected';
    // Pre-compute lists so they can be used inside the widget tree
    final interests = _requesterProfile != null ? _parseList(_requesterProfile!['interests']) : <String>[];
    final lookingFor = _requesterProfile != null ? _parseList(_requesterProfile!['looking_for']) : <String>[];

    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Review Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _requesterProfile == null
              ? const Center(child: Text('Profile not found', style: TextStyle(color: Colors.white54)))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status banner
                            if (isApproved || isRejected)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: isApproved ? const Color(0xFF10B981).withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isApproved ? const Color(0xFF10B981).withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(isApproved ? Icons.check_circle : Icons.cancel, color: isApproved ? const Color(0xFF10B981) : Colors.red, size: 20),
                                    const SizedBox(width: 10),
                                    Text(isApproved ? 'You have already accepted this request.' : 'You have already declined this request.', style: TextStyle(color: isApproved ? const Color(0xFF10B981) : Colors.red, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),

                            // Requester Profile Hero Card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                  colors: [const Color(0xFF8B5CF6).withValues(alpha: 0.15), const Color(0xFF101015)],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
                              ),
                              child: Column(
                                children: [
                                  // Avatar
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: SweepGradient(colors: [Color(0xFF8B5CF6), Color(0xFF00E5FF), Color(0xFF8B5CF6)]),
                                    ),
                                    child: CircleAvatar(
                                      radius: 44,
                                      backgroundImage: _safeProvider(_requesterProfile!['avatar_url'] ?? 'https://picsum.photos/seed/${_requesterProfile!['id']}/200'),
                                      backgroundColor: const Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _requesterProfile!['name'] ?? _requesterProfile!['full_name'] ?? 'Unknown User',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  if ((_requesterProfile!['city'] ?? '').toString().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      const Icon(Icons.location_on, color: Colors.white38, size: 13),
                                      const SizedBox(width: 3),
                                      Text(_requesterProfile!['city'], style: const TextStyle(color: Colors.white38, fontSize: 13)),
                                    ]),
                                  ],
                                  if ((_requesterProfile!['bio'] ?? '').toString().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(14)),
                                      child: Text(_requesterProfile!['bio'], style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Their message
                            if ((widget.request['message'] ?? '').toString().isNotEmpty) ...[
                              const Text('THEIR MESSAGE', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.format_quote, color: Color(0xFF8B5CF6), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(widget.request['message'], style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6))),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Interests
                            if (interests.isNotEmpty) ...[
                              const Text('THEIR INTERESTS', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8, runSpacing: 8,
                                children: interests.map((i) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(color: const Color(0xFF00E5FF).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3))),
                                  child: Text(i, style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w600, fontSize: 13)),
                                )).toList(),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Looking for
                            if (lookingFor.isNotEmpty) ...[
                              const Text('LOOKING FOR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8, runSpacing: 8,
                                children: lookingFor.map((l) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3))),
                                  child: Text(l, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 13)),
                                )).toList(),
                              ),
                              const SizedBox(height: 20),
                            ],

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),

                    // Action Buttons
                    if (!isApproved && !isRejected)
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                        decoration: BoxDecoration(
                          color: const Color(0xFF050508),
                          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              // Decline
                              Expanded(
                                child: GestureDetector(
                                  onTap: _isProcessing ? null : () => _updateStatus('rejected'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.4)),
                                    ),
                                    child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.close, color: Color(0xFFE11D48), size: 18),
                                      SizedBox(width: 6),
                                      Text('Decline', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 15)),
                                    ])),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Accept
                              Expanded(
                                flex: 2,
                                child: GestureDetector(
                                  onTap: _isProcessing ? null : () => _updateStatus('approved'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4)]),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))],
                                    ),
                                    child: Center(
                                      child: _isProcessing
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                          : const Row(mainAxisSize: MainAxisSize.min, children: [
                                              Icon(Icons.check, color: Colors.white, size: 18),
                                              SizedBox(width: 6),
                                              Text('Accept & Connect 🤝', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                            ]),
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
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// COMPANION INCOMING REQUESTS MANAGER — for CompanionManagementScreen
// ════════════════════════════════════════════════════════════════════
class CompanionIncomingRequestsScreen extends StatefulWidget {
  final String companionListingId;
  const CompanionIncomingRequestsScreen({super.key, required this.companionListingId});

  @override
  State<CompanionIncomingRequestsScreen> createState() => _CompanionIncomingRequestsScreenState();
}

class _CompanionIncomingRequestsScreenState extends State<CompanionIncomingRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Connection Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: const TabBar(
          indicatorColor: Color(0xFF10B981),
          labelColor: Color(0xFF10B981),
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: 'PENDING'),
            Tab(text: 'APPROVED'),
            Tab(text: 'DECLINED'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _IncomingRequestsList(companionListingId: widget.companionListingId, statusFilter: 'pending'),
          _IncomingRequestsList(companionListingId: widget.companionListingId, statusFilter: 'approved'),
          _IncomingRequestsList(companionListingId: widget.companionListingId, statusFilter: 'rejected'),
        ],
      ),
    );
  }
}

class _IncomingRequestsList extends StatelessWidget {
  final String companionListingId;
  final String statusFilter;
  const _IncomingRequestsList({required this.companionListingId, required this.statusFilter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('requests')
          .stream(primaryKey: ['id'])
          .eq('target_id', companionListingId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
        }
        // Filter client-side for target_type and status
        final all = (snapshot.data ?? []).where((r) => r['target_type'] == 'companion').toList();
        final filtered = all.where((r) => r['status'] == statusFilter).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 70, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                Text('No $statusFilter requests', style: const TextStyle(color: Colors.white38, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _IncomingRequestCard(
            request: filtered[i],
            onStatusChanged: () {},
          ),
        );
      },
    );
  }
}

class _IncomingRequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onStatusChanged;
  const _IncomingRequestCard({required this.request, required this.onStatusChanged});

  @override
  State<_IncomingRequestCard> createState() => _IncomingRequestCardState();
}

class _IncomingRequestCardState extends State<_IncomingRequestCard> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final senderId = widget.request['sender_id']?.toString();
    if (senderId == null) { setState(() => _isLoading = false); return; }
    try {
      final p = await Supabase.instance.client.from('profiles').select('name, full_name, avatar_url, city, bio').eq('id', senderId).maybeSingle();
      if (mounted) setState(() { _profile = p; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  ImageProvider _safeProvider(String url) {
    if (url.startsWith('data:image')) return MemoryImage(base64Decode(url.split(',').last));
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.request['status'] as String? ?? 'pending';
    final statusColor = status == 'approved' ? const Color(0xFF10B981) : status == 'rejected' ? const Color(0xFFE11D48) : const Color(0xFFFBBF24);
    final statusIcon = status == 'approved' ? Icons.check_circle : status == 'rejected' ? Icons.cancel : Icons.hourglass_top;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CompanionRequestDetailScreen(
          request: widget.request,
          onStatusChanged: widget.onStatusChanged,
        )));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF101015),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        ),
        child: _isLoading
            ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2)))
            : Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: _safeProvider(_profile?['avatar_url'] ?? 'https://picsum.photos/200'),
                    backgroundColor: const Color(0xFF1A1A2E),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(_profile?['name'] ?? _profile?['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(statusIcon, color: statusColor, size: 11),
                              const SizedBox(width: 3),
                              Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ]),
                        if ((_profile?['city'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(_profile!['city'], style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                        if ((widget.request['message'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(widget.request['message'], style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
                ],
              ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// COMPANION REGISTRATION — Multi-Step Full Screen (with Proof Upload)
// ════════════════════════════════════════════════════════════════════
class _CompanionRegisterScreen extends StatefulWidget {
  final String? editId;
  const _CompanionRegisterScreen({super.key, this.editId});

  @override
  State<_CompanionRegisterScreen> createState() => _CompanionRegisterScreenState();
}

class _CompanionRegisterScreenState extends State<_CompanionRegisterScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  bool _saving = false;
  bool _loading = false;

  // Step 1: Category
  String _category = '';

  // Step 2: Basic Info
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _offeringCtrl = TextEditingController();

  // Step 3: Skills & Experience
  final _allSkills = [
    'Teaching', 'Tutoring', 'Music', 'Guitar', 'Piano', 'Singing',
    'Fitness', 'Yoga', 'Photography', 'Cooking', 'Programming',
    'Design', 'Writing', 'Language', 'Active Listening', 'Counseling',
    'Dancing', 'Art', 'Gaming', 'Sports', 'Meditation',
    'Career Advice', 'Travel Guide', 'Just Hanging Out',
  ];
  final Set<String> _selectedSkills = {};
  String _experience = '';

  // Step 4: Availability, Languages, City, Rate
  final _allAvailability = ['Morning', 'Afternoon', 'Evening', 'Night', 'Weekdays', 'Weekends', 'Flexible'];
  final Set<String> _selectedAvailability = {};
  final _allLanguages = ['English', 'Hindi', 'Tamil', 'Telugu', 'Bengali', 'Marathi', 'Gujarati', 'Kannada', 'Malayalam', 'Punjabi', 'Urdu'];
  final Set<String> _selectedLanguages = {};
  final _cityCtrl = TextEditingController();
  final List<String> _selectedDistricts = []; // max 3 districts
  double _hourlyRate = 0;

  // Step 5: Bio
  final _bioCtrl = TextEditingController();

  // Step 6: Credentials & Proof (NEW)
  final _credentialCtrl = TextEditingController(); // headline credential
  final List<String> _proofImages = []; // up to 3 proof image URLs
  bool _uploadingProof = false;

  static const int _totalSteps = 6;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client.from('companions').select().eq('id', widget.editId!).single();
      _category = data['category'] ?? '';
      _nameCtrl.text = data['name'] ?? '';
      _titleCtrl.text = data['title'] ?? '';
      _offeringCtrl.text = data['offering'] ?? '';
      _experience = data['experience'] ?? '';
      _hourlyRate = (data['hourly_rate'] ?? 0).toDouble();
      _cityCtrl.text = data['city'] ?? '';
      _bioCtrl.text = data['bio'] ?? '';
      _credentialCtrl.text = data['credential_headline'] ?? '';
      final savedProofs = (data['proof_images'] as List?)?.map((e) => e.toString()).toList() ?? [];
      _proofImages.addAll(savedProofs);
      _selectedSkills.addAll(_parseList(data['skills']));
      _selectedAvailability.addAll(_parseList(data['availability']));
      _selectedLanguages.addAll(_parseList(data['languages']));
      _selectedDistricts.addAll(_parseList(data['districts']));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<String> _parseList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) return raw.replaceAll('{', '').replaceAll('}', '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return [];
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose(); _titleCtrl.dispose(); _offeringCtrl.dispose();
    _cityCtrl.dispose(); _bioCtrl.dispose(); _credentialCtrl.dispose();
    super.dispose();
  }

  bool get _canProceed {
    switch (_step) {
      case 0: return _category.isNotEmpty;
      case 1: return _nameCtrl.text.trim().isNotEmpty && _titleCtrl.text.trim().isNotEmpty && _offeringCtrl.text.trim().isNotEmpty;
      case 2: return _selectedSkills.isNotEmpty && _experience.isNotEmpty;
      case 3: return _selectedAvailability.isNotEmpty && _selectedLanguages.isNotEmpty;
      case 4: return _bioCtrl.text.trim().isNotEmpty;
      case 5: return true; // proof is optional
      default: return true;
    }
  }

  void _nextStep() {
    if (!_canProceed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all required fields'), backgroundColor: Color(0xFFE11D48), behavior: SnackBarBehavior.floating));
      return;
    }
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  Future<void> _addProofImage() async {
    if (_proofImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 3 proof images allowed'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _uploadingProof = true);
    try {
      final url = await ImageUploadService.pickAndUpload(context: context, folder: 'proofs');
      if (url != null && mounted) {
        setState(() => _proofImages.add(url));
      }
    } finally {
      if (mounted) setState(() => _uploadingProof = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final profile = await Supabase.instance.client.from('profiles').select('avatar_url').eq('id', uid).maybeSingle();
      final data = {
        'user_id': uid,
        'name': _nameCtrl.text.trim(),
        'title': _titleCtrl.text.trim(),
        'category': _category,
        'bio': _bioCtrl.text.trim(),
        'skills': _selectedSkills.toList(),
        'offering': _offeringCtrl.text.trim(),
        'hourly_rate': _category == 'professional' ? _hourlyRate : 0,
        'currency': 'INR',
        'availability': _selectedAvailability.toList(),
        'languages': _selectedLanguages.toList(),
        'city': _cityCtrl.text.trim(),
        'districts': _selectedDistricts,
        'experience': _experience,
        'avatar_url': profile?['avatar_url'] ?? 'https://picsum.photos/seed/comp$uid/400',
        'is_active': true,
        'credential_headline': _credentialCtrl.text.trim(),
        'proof_images': _proofImages,
        'verification_status': _proofImages.isNotEmpty ? 'pending' : 'unverified',
      };

      if (widget.editId != null) {
        await Supabase.instance.client.from('companions').update(data).eq('id', widget.editId!);
      } else {
        await Supabase.instance.client.from('companions').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.editId != null ? 'Listing updated! ✅' : 'You are now a Companion! 🎉'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Color(0xFF050508), body: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))));

    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _step > 0 ? _prevStep : () => Navigator.pop(context),
                        child: Icon(_step > 0 ? Icons.arrow_back_ios : Icons.close, color: Colors.white54, size: 22),
                      ),
                      Text('Step ${_step + 1} of $_totalSteps', style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 22),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(_totalSteps, (i) => Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: i <= _step ? const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFF8B5CF6)]) : null,
                          color: i > _step ? Colors.white.withValues(alpha: 0.1) : null,
                        ),
                      ),
                    )),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                  _buildStep5(),
                  _buildStep6(), // NEW: Credentials
                ],
              ),
            ),

            // Next Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: GestureDetector(
                onTap: _saving ? null : _nextStep,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: const Color(0xFFE11D48).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(
                            _step == _totalSteps - 1 ? (widget.editId != null ? 'Update Listing' : 'Submit & Go Live 🚀') : 'Continue',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Category ──
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How would you like\nto help? 🤝', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.3)),
          const SizedBox(height: 6),
          const Text('Choose what best describes you', style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 32),
          _categoryCard('companion', 'Companion', 'Share your time — no skills required', 'Perfect for those who want to help combat loneliness. Just hang out, listen, go for walks, grab coffee.', Icons.volunteer_activism, const Color(0xFF10B981)),
          const SizedBox(height: 16),
          _categoryCard('professional', 'Professional', 'Get paid for your skills & expertise', 'Offer tutoring, music lessons, fitness coaching, career advice, counseling, and more.', Icons.workspace_premium, const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _categoryCard(String value, String title, String subtitle, String desc, IconData icon, Color color) {
    final selected = _category == value;
    return GestureDetector(
      onTap: () => setState(() => _category = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: selected ? LinearGradient(colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)]) : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.white.withValues(alpha: 0.06), width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(subtitle, style: TextStyle(color: selected ? Colors.white54 : Colors.white38, fontSize: 12)),
              ])),
              if (selected) const Icon(Icons.check_circle, color: Colors.white, size: 24),
            ]),
            const SizedBox(height: 12),
            Text(desc, style: TextStyle(color: selected ? Colors.white60 : Colors.white30, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Basic Info ──
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tell us about\nyourself ✍️', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.3)),
        const SizedBox(height: 6),
        const Text('This info will be shown on your companion card', style: TextStyle(color: Colors.white38, fontSize: 14)),
        const SizedBox(height: 32),
        _label('Display Name'), _field(_nameCtrl, 'How people will address you', Icons.person_outline),
        const SizedBox(height: 20),
        _label('Your Title / Role'), _field(_titleCtrl, _category == 'professional' ? 'e.g. Guitar Teacher, Math Tutor' : 'e.g. Active Listener, Walk Buddy', Icons.badge_outlined),
        const SizedBox(height: 20),
        _label('What are you offering?'), const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: TextField(controller: _offeringCtrl, maxLines: 3, maxLength: 300, style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(hintText: _category == 'professional' ? 'e.g. I teach guitar from beginner to advanced level...' : 'e.g. I\'m here to listen, hang out, grab coffee, go for walks...', hintStyle: const TextStyle(color: Colors.white30, fontSize: 13), border: InputBorder.none, contentPadding: const EdgeInsets.all(16), counterStyle: const TextStyle(color: Colors.white30))),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ── Step 3: Skills ──
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_category == 'professional' ? 'Your Skills 💡' : 'What can you do? 💡', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Pick what applies (select at least 1)', style: TextStyle(color: Colors.white38, fontSize: 14)),
        const SizedBox(height: 32),
        Wrap(spacing: 10, runSpacing: 10, children: _allSkills.map((skill) {
          final selected = _selectedSkills.contains(skill);
          return GestureDetector(
            onTap: () => setState(() { if (selected) {
              _selectedSkills.remove(skill);
            } else if (_selectedSkills.length < 8) {
              _selectedSkills.add(skill);
            }
          }),
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(gradient: selected ? const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFF8B5CF6)]) : null, color: selected ? null : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? Colors.transparent : Colors.white.withValues(alpha: 0.1))),
              child: Text(skill, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontWeight: selected ? FontWeight.bold : FontWeight.w500, fontSize: 13))),
          );
        }).toList()),
        const SizedBox(height: 8),
        Text('${_selectedSkills.length}/8 selected', style: const TextStyle(color: Colors.white30, fontSize: 12)),
        const SizedBox(height: 28),
        _label('Experience Level'), const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: ['Just Starting', '< 1 year', '1-3 years', '3-5 years', '5+ years'].map((e) => _selectionChip(e, _experience == e, () => setState(() => _experience = e))).toList()),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ── Step 4: Availability etc. ──
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('When & Where? 📍', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Let users know when you\'re available', style: TextStyle(color: Colors.white38, fontSize: 14)),
        const SizedBox(height: 32),
        _label('Availability'), const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: _allAvailability.map((a) => _selectionChip(a, _selectedAvailability.contains(a), () => setState(() { if (_selectedAvailability.contains(a)) {
          _selectedAvailability.remove(a);
        } else {
          _selectedAvailability.add(a);
        } }))).toList()),
        const SizedBox(height: 24),
        _label('Languages'), const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: _allLanguages.map((l) => _selectionChip(l, _selectedLanguages.contains(l), () => setState(() { if (_selectedLanguages.contains(l)) {
          _selectedLanguages.remove(l);
        } else {
          _selectedLanguages.add(l);
        } }))).toList()),
        _label('Locations (Districts)'), const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF15151A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedDistricts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _selectedDistricts.map((d) => Chip(
                      label: Text(d, style: const TextStyle(fontSize: 12, color: Colors.white)),
                      backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                      onDeleted: () => setState(() => _selectedDistricts.remove(d)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF8B5CF6))),
                    )).toList(),
                  ),
                ),
              if (_selectedDistricts.length < 3)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cityCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Enter district...',
                          hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty && _selectedDistricts.length < 3 && !_selectedDistricts.contains(v.trim())) {
                            setState(() { _selectedDistricts.add(v.trim()); _cityCtrl.clear(); });
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFF8B5CF6)),
                      onPressed: () {
                        final v = _cityCtrl.text.trim();
                        if (v.isNotEmpty && _selectedDistricts.length < 3 && !_selectedDistricts.contains(v)) {
                          setState(() { _selectedDistricts.add(v); _cityCtrl.clear(); });
                        }
                      },
                    )
                  ],
                ),
              if (_selectedDistricts.length >= 3)
                const Text('Maximum 3 locations allowed', style: TextStyle(color: Colors.orange, fontSize: 12)),
            ],
          ),
        ),
        if (_category == 'professional') ...[
          const SizedBox(height: 24),
          _label('Hourly Rate (₹)'), const SizedBox(height: 8),
          Row(children: [Text('₹${_hourlyRate.toInt()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))), const Text('/hr', style: TextStyle(color: Colors.white38, fontSize: 14))]),
          const SizedBox(height: 8),
          SliderTheme(data: SliderThemeData(activeTrackColor: const Color(0xFF8B5CF6), inactiveTrackColor: Colors.white.withValues(alpha: 0.08), thumbColor: const Color(0xFF8B5CF6), overlayColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
            child: Slider(value: _hourlyRate, min: 0, max: 5000, divisions: 100, onChanged: (v) => setState(() => _hourlyRate = v))),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('₹0', style: TextStyle(color: Colors.white30, fontSize: 12)), Text('₹5000', style: TextStyle(color: Colors.white30, fontSize: 12))]),
        ],
        const SizedBox(height: 40),
      ]),
    );
  }

  // ── Step 5: Bio ──
  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Almost Done! ✨', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Write a bio that makes people want to connect', style: TextStyle(color: Colors.white38, fontSize: 14)),
        const SizedBox(height: 32),
        _label('About You'), const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: TextField(controller: _bioCtrl, maxLines: 5, maxLength: 500, style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(hintText: _category == 'professional' ? 'Tell people about your background, qualifications, and teaching style...' : 'Share why you want to be a companion. What makes you a great person to hang out with?', hintStyle: const TextStyle(color: Colors.white30, fontSize: 13), border: InputBorder.none, contentPadding: const EdgeInsets.all(16), counterStyle: const TextStyle(color: Colors.white30))),
        ),
        const SizedBox(height: 28),
        const Text('PREVIEW', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF101015), borderRadius: BorderRadius.circular(20), border: Border.all(color: _category == 'professional' ? const Color(0xFF8B5CF6).withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const CircleAvatar(radius: 20, backgroundColor: Color(0xFF1a1a24), child: Icon(Icons.person, color: Colors.white38)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_nameCtrl.text.isEmpty ? 'Your Name' : _nameCtrl.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(_titleCtrl.text.isEmpty ? 'Your Title' : _titleCtrl.text, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (_category == 'professional' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981)).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(_category == 'professional' ? 'PRO' : 'FREE', style: TextStyle(color: _category == 'professional' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 10))),
            ]),
            if (_offeringCtrl.text.isNotEmpty) ...[const SizedBox(height: 10), Text(_offeringCtrl.text, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)],
            if (_selectedSkills.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 6, runSpacing: 6, children: _selectedSkills.take(3).map((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)), child: Text(s, style: const TextStyle(color: Colors.white54, fontSize: 11)))).toList())],
          ]),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ── Step 6: Credentials & Proof (NEW) ──
  Widget _buildStep6() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Build Trust 🏅', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Add credentials and proof to boost user confidence', style: TextStyle(color: Colors.white38, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFBBF24).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.2))),
          child: const Row(children: [Icon(Icons.info_outline, color: Color(0xFFFBBF24), size: 16), SizedBox(width: 8), Expanded(child: Text('This step is optional but highly recommended. Listings with proof get 3× more connections.', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12, height: 1.4)))]),
        ),
        const SizedBox(height: 28),

        // Credential headline
        _label('Credential Headline (optional)'),
        const SizedBox(height: 8),
        _field(_credentialCtrl, 'e.g. Certified Yoga Instructor | B.Tech IIT Delhi', Icons.workspace_premium),

        const SizedBox(height: 28),

        // Proof image upload
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _label('Proof Images (up to 3)'),
          Text('${_proofImages.length}/3', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        const Text('Upload certificates, work samples, or portfolio photos', style: TextStyle(color: Colors.white30, fontSize: 12)),
        const SizedBox(height: 12),

        // Proof image grid
        if (_proofImages.isNotEmpty) ...[
          Wrap(spacing: 10, runSpacing: 10, children: List.generate(_proofImages.length, (i) {
            final url = _proofImages[i];
            ImageProvider prov = url.startsWith('data:image') ? MemoryImage(base64Decode(url.split(',').last)) : NetworkImage(url) as ImageProvider;
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image(image: prov, width: 90, height: 90, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 90, height: 90, color: const Color(0xFF101015), child: const Icon(Icons.broken_image, color: Colors.white24))),
                ),
                Positioned(top: 4, right: 4, child: GestureDetector(
                  onTap: () => setState(() => _proofImages.removeAt(i)),
                  child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 12)),
                )),
              ],
            );
          })),
          const SizedBox(height: 12),
        ],

        // Add proof button
        if (_proofImages.length < 3)
          GestureDetector(
            onTap: _uploadingProof ? null : _addProofImage,
            child: Container(
              width: double.infinity,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), style: BorderStyle.solid),
              ),
              child: Center(
                child: _uploadingProof
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_photo_alternate_outlined, color: Colors.white38, size: 22),
                        SizedBox(width: 10),
                        Text('Add Proof Image', style: TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.w600)),
                      ]),
              ),
            ),
          ),

        const SizedBox(height: 40),
      ]),
    );
  }

  // ── Shared Widgets ──
  Widget _label(String text) => Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14));

  Widget _field(TextEditingController ctrl, String hint, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: TextField(controller: ctrl, style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white30, fontSize: 14), prefixIcon: Icon(icon, color: Colors.white30, size: 20), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))),
    );
  }

  Widget _selectionChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(gradient: selected ? const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFF8B5CF6)]) : null, color: selected ? null : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? Colors.transparent : Colors.white.withValues(alpha: 0.1))),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontWeight: selected ? FontWeight.bold : FontWeight.w500, fontSize: 13))),
    );
  }
}



