const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'lib', 'messages_screen.dart');
let c = fs.readFileSync(filePath, 'utf8');

// Normalize line endings
c = c.replace(/\r\n/g, '\n');

let n = 0;

// 1. Update filter & sort logic in _ChatsViewState build
const oldFilterSort = `    // Apply Chip Filter
    var filtered = _conversations.where((entry) {
      if (widget.searchQuery.isNotEmpty) {
        final profile = _profileCache[entry.key];
        final name = profile?['name'] ?? '';
        return name.toLowerCase().contains(widget.searchQuery);
      }
      
      if (widget.filter == 'Unread') {
        // Simple mock for unread: if sender is not me and is_read == false
        final m = entry.value;
        return m['sender_id'] != _myUid && m['is_read'] == false;
      }
      // Favourites mock
      if (widget.filter == 'Favourites') {
        return entry.key.hashCode % 5 == 0; 
      }
      return true;
    }).toList();`;

const newFilterSort = `    // Apply Chip Filter & Archive Filtering & Pinned sorting
    var filtered = _conversations.where((entry) {
      // Filter out archived conversations from main list
      if (_archivedIds.contains(entry.key)) return false;

      if (widget.searchQuery.isNotEmpty) {
        final profile = _profileCache[entry.key];
        final name = profile?['name'] ?? '';
        return name.toLowerCase().contains(widget.searchQuery);
      }
      
      if (widget.filter == 'Unread') {
        final isMe = entry.value['sender_id'] == _myUid;
        final isRead = entry.value['is_read'] == true;
        final dbUnread = _unreadCounts[entry.key] ?? 0;
        final isManualUnread = _manuallyUnreadIds.contains(entry.key);
        final unreadCount = isManualUnread ? 1 : ((!isMe && !isRead) ? dbUnread : 0);
        return unreadCount > 0;
      }
      if (widget.filter == 'Favourites') {
        return entry.key.hashCode % 5 == 0; 
      }
      return true;
    }).toList();

    // Apply sorting: pinned chats first, then maintain recency
    filtered.sort((a, b) {
      final aPinned = _pinnedIds.contains(a.key);
      final bPinned = _pinnedIds.contains(b.key);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return 0;
    });`;

if (c.includes(oldFilterSort)) {
  c = c.replace(oldFilterSort, newFilterSort);
  n++;
} else {
  console.log("MISS: oldFilterSort");
}

// 2. Update Archived row onTap to open Archived Chats Screen
const oldArchivedTile = `            if (i == 2) {
              return ListTile(
                leading: const Padding(
                  padding: EdgeInsets.only(left: 8.0, right: 16.0),
                  child: Icon(Icons.archive_outlined, color: Color(0xFF8B95A5), size: 24),
                ),
                title: const Text('Archived', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archive coming soon! 📦')));
                },
              );
            }`;

const newArchivedTile = `            if (i == 2) {
              return ListTile(
                leading: const Padding(
                  padding: EdgeInsets.only(left: 8.0, right: 16.0),
                  child: Icon(Icons.archive_outlined, color: Color(0xFF8B95A5), size: 24),
                ),
                title: const Text('Archived', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                trailing: _archivedIds.isNotEmpty ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF8B95A5).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text('\${_archivedIds.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ) : null,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => _ArchivedChatsScreen(
                      archivedIds: _archivedIds,
                      conversations: _conversations,
                      profileCache: _profileCache,
                      unreadCounts: _unreadCounts,
                      manuallyUnreadIds: _manuallyUnreadIds,
                      onUnarchive: (id) => setState(() => _archivedIds.remove(id)),
                    ),
                  ));
                  _fetchConversations();
                },
              );
            }`;

if (c.includes(oldArchivedTile)) {
  c = c.replace(oldArchivedTile, newArchivedTile);
  n++;
} else {
  console.log("MISS: oldArchivedTile");
}

// 3. Append Archived Chats Screen class at the bottom of the file
const archivedClass = `

// =============================================================================
// ARCHIVED CHATS SCREEN
// =============================================================================
class _ArchivedChatsScreen extends StatefulWidget {
  final Set<String> archivedIds;
  final List<MapEntry<String, Map<String, dynamic>>> conversations;
  final Map<String, Map<String, String>> profileCache;
  final Map<String, int> unreadCounts;
  final Set<String> manuallyUnreadIds;
  final Function(String) onUnarchive;

  const _ArchivedChatsScreen({
    required this.archivedIds,
    required this.conversations,
    required this.profileCache,
    required this.unreadCounts,
    required this.manuallyUnreadIds,
    required this.onUnarchive,
  });

  @override
  State<_ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<_ArchivedChatsScreen> {
  @override
  Widget build(BuildContext context) {
    final list = widget.conversations.where((entry) => widget.archivedIds.contains(entry.key)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        title: const Text('Archived Chats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: list.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, color: Colors.white24, size: 64),
                  SizedBox(height: 16),
                  Text('No archived chats', style: TextStyle(color: Colors.white38, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final partnerId = list[i].key;
                final lastMsg = list[i].value;
                final profile = widget.profileCache[partnerId] ?? {'name': 'User', 'avatar': ''};
                final name = profile['name']!;
                final avatar = profile['avatar']!;

                return Dismissible(
                  key: Key(partnerId),
                  background: Container(
                    color: const Color(0xFF3B82F6),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: const Icon(Icons.unarchive, color: Colors.white, size: 28),
                  ),
                  confirmDismiss: (dir) async {
                    widget.onUnarchive(partnerId);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat unarchived')));
                    setState(() {});
                    return true;
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      backgroundColor: const Color(0xFF1B202D),
                      child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.white38) : null,
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      lastMsg['is_image'] == true ? '📸 Photo' : (lastMsg['text'] as String? ?? ''),
                      style: const TextStyle(color: Colors.white38),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.unarchive, color: Colors.white54),
                      onPressed: () {
                        widget.onUnarchive(partnerId);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat unarchived')));
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
`;

c = c + archivedClass;

// Restore Windows endings
c = c.replace(/\n/g, '\r\n');

fs.writeFileSync(filePath, c, 'utf8');
console.log(`Done. Applied ${n} replacements.`);
