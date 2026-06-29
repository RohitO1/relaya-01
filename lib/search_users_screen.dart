import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final _sb = Supabase.instance.client;
  
  Timer? _debounce;
  bool _isLoading = false;
  List<Map<String, dynamic>> _results = [];
  String _lastQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _lastQuery = '';
      });
      return;
    }

    if (q == _lastQuery) return;

    setState(() {
      _isLoading = true;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(q);
    });
  }

  Future<void> _performSearch(String query) async {
    _lastQuery = query;
    try {
      final res = await _sb
          .from('profiles')
          .select('id, name, username, avatar_url')
          .or('username.ilike.%$query%,name.ilike.%$query%')
          .limit(30);
          
      if (mounted) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Search Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    if (_searchCtrl.text.trim().isEmpty) {
      return Center(
        child: Text(
          'Find people you know.',
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    if (_results.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          'No results found.',
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        final id = user['id']?.toString() ?? '';
        final name = user['name']?.toString() ?? 'Unknown';
        final username = user['username']?.toString() ?? name.replaceAll(' ', '.').toLowerCase();
        final avatarUrl = user['avatar_url']?.toString() ?? '';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return InkWell(
          onTap: () {
            FocusScope.of(context).unfocus();
            if (id.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ClipOval(
                    child: avatarUrl.isNotEmpty && avatarUrl.startsWith('http')
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackAvatar(initial),
                          )
                        : _fallbackAvatar(initial),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fallbackAvatar(String initial) {
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
