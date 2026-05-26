// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bolroom_voice_screen.dart';
import 'bolroom_communities_screen.dart';
import 'bolroom_dm_screen.dart';
import 'bolroom_profile_screen.dart';
import '../chatroom_live_screen.dart'; // for BolRoomManager.hasActiveRoom

class BolroomShell extends StatefulWidget {
  const BolroomShell({super.key});
  @override
  State<BolroomShell> createState() => _BolroomShellState();
}

class _BolroomShellState extends State<BolroomShell> {
  int _currentIndex = 0;
  late final PageController _pageCtrl;

  // ── Navigation History ── tracks the last 10 tab switches
  final List<int> _tabHistory = [];
  static const int _maxHistory = 10;

  static const Color bgColor = Color(0xFF090710);
  static const Color purplePrimary = Color(0xFFB983FF);
  static const Color textMuted = Color(0xFF8E8B99);
  static const Color navBg = Color(0xFF0E0B16);

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() {
      _tabHistory.add(_currentIndex);
      if (_tabHistory.length > _maxHistory) {
        _tabHistory.removeAt(0);
      }
      _currentIndex = index;
    });
    _pageCtrl.jumpToPage(index);
  }

  /// Called by system back button — returns true if we handled it
  bool _handleSystemBack() {
    // Priority 1: Room is open full-screen
    if (BolRoomManager.isRoomFullscreen) {
      // 1a: Check if the room has an internal UI layer to close (chat panel, etc.)
      final roomState = BolRoomManager.roomStateKey?.currentState;
      if (roomState != null && roomState.handleBack()) {
        return true;
      }
      // 1b: Check if the internal navigator has any open dialogs/bottom sheets
      if (BolRoomManager.internalNavKey?.currentState?.canPop() == true) {
        BolRoomManager.internalNavKey!.currentState!.pop();
        return true;
      }
      // 1c: Nothing internal — minimize the room to floating bubble
      BolRoomManager.minimizeRoomIfOpen();
      return true;
    }

    // Priority 2: Room is minimized as bubble → allow normal navigation
    // (We removed the logic that maximizes it here to prevent the navigation loop)

    // Priority 3: Navigate to the previous tab in history
    if (_tabHistory.isNotEmpty) {
      setState(() {
        _currentIndex = _tabHistory.removeLast();
      });
      _pageCtrl.jumpToPage(_currentIndex);
      return true;
    }

    // Priority 4: Nothing left — pop the BolroomShell, go back to Home
    return false;
  }

  bool _canPop = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Only allow the system pop when we've exhausted all internal navigation
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_handleSystemBack()) {
          // Nothing left to go back to — exit BolRoom ecosystem to Home
          setState(() {
            _canPop = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            BolroomVoiceScreen(),
            BolroomCommunitiesScreen(),
            BolroomDmScreen(),
            BolroomProfileScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          height: 80,
          decoration: BoxDecoration(
            color: navBg,
            border: const Border(top: BorderSide(color: Color(0xFF1D182E), width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(Icons.mic_none_outlined, 'Voiceroom', 0),
                _buildNavItem(Icons.explore_outlined, 'Communities', 1),
                _buildNavItem(Icons.chat_bubble_outline, 'DM', 2),
                _buildNavItem(Icons.person_outline, 'Profile', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? purplePrimary : textMuted,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? purplePrimary : textMuted,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: purplePrimary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: purplePrimary.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  )
                ],
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}
