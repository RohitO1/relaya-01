$file = 'lib\messages_screen.dart'
$c = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
$c = $c -replace "`r`n", "`n"  # normalize
$n = 0

# 1. Add state variables after _pollingTimer
$old = "  List<MapEntry<String, Map<String, dynamic>>> _conversations = [];`n  bool _loading = true;`n  Timer? _pollingTimer;"
$new = "  List<MapEntry<String, Map<String, dynamic>>> _conversations = [];`n  bool _loading = true;`n  Timer? _pollingTimer;`n  final Set<String> _archivedIds = {};`n  final Map<String, DateTime?> _mutedUntilMap = {};`n  final Set<String> _pinnedIds = {};`n  final Set<String> _manuallyUnreadIds = {};`n  final Map<String, int> _unreadCounts = {};"
if ($c.Contains($old)) { $c = $c.Replace($old, $new); $n++ } else { Write-Host "MISS 1: state vars" }

# 2. Fix _fetchConversations to compute real unread counts
$old2 = "      final Map<String, Map<String, dynamic>> convos = {};`n      for (final m in (allMsgs as List)) {`n        final partnerId = m['sender_id'] == _myUid ? m['receiver_id'] : m['sender_id'];`n        if (partnerId == null) continue;`n        if (!convos.containsKey(partnerId)) {`n          convos[partnerId] = Map<String, dynamic>.from(m);`n        }`n      }`n`n      // Pre-fetch all profiles`n      for (final partnerId in convos.keys) {`n        await _getProfile(partnerId);`n      }`n`n      if (mounted) {`n        setState(() {`n          _conversations = convos.entries.toList();`n          _loading = false;`n        });`n      }"
$new2 = "      final Map<String, Map<String, dynamic>> convos = {};`n      final Map<String, int> unread = {};`n      for (final m in (allMsgs as List)) {`n        final partnerId = m['sender_id'] == _myUid ? m['receiver_id'] : m['sender_id'];`n        if (partnerId == null) continue;`n        if (!convos.containsKey(partnerId)) convos[partnerId] = Map<String, dynamic>.from(m);`n        if (m['sender_id'] != _myUid && m['is_read'] != true) {`n          unread[partnerId] = (unread[partnerId] ?? 0) + 1;`n        }`n      }`n      for (final partnerId in convos.keys) await _getProfile(partnerId);`n      if (mounted) setState(() { _conversations = convos.entries.toList(); _unreadCounts.addAll(unread); _loading = false; });"
if ($c.Contains($old2)) { $c = $c.Replace($old2, $new2); $n++ } else { Write-Host "MISS 2: fetchConversations body" }

# 3. Fix unreadCount to use real DB count
$old3 = "          final unreadCount = (!isMe && !isRead) ? 1 : 0; // Mock count"
$new3 = "          final isManualUnread = _manuallyUnreadIds.contains(partnerId);`n          final dbUnread = _unreadCounts[partnerId] ?? 0;`n          final unreadCount = isManualUnread ? 1 : ((!isMe && !isRead) ? dbUnread : 0);"
if ($c.Contains($old3)) { $c = $c.Replace($old3, $new3); $n++ } else { Write-Host "MISS 3: unreadCount" }

# 4. Fix isPinned and isMuted to use real state
$old4 = "          final isPinned = partnerId.hashCode % 4 == 0; // Mock pinned`n          final isMuted = partnerId.hashCode % 7 == 0; // Mock muted"
$new4 = "          final isPinned = _pinnedIds.contains(partnerId);`n          final isMutedVal = _mutedUntilMap[partnerId];`n          final isMuted = isMutedVal != null && isMutedVal.isAfter(DateTime.now());"
if ($c.Contains($old4)) { $c = $c.Replace($old4, $new4); $n++ } else { Write-Host "MISS 4: isPinned/isMuted" }

$c = $c -replace "`n", "`r`n"  # restore
[System.IO.File]::WriteAllText($file, $c, [System.Text.Encoding]::UTF8)
Write-Host "Done. Applied $n replacements."
