const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'lib', 'messages_screen.dart');
let c = fs.readFileSync(filePath, 'utf8');

c = c.replace(/\r\n/g, '\n');

let n = 0;

// 1. Add _isComposerEmpty and _markAsRead to _ChatDetailScreenState
const oldStateVars = `  bool _isConnectionLoading = true;
  bool _memberChatEnabled = false;`;

const newStateVars = `  bool _isConnectionLoading = true;
  bool _memberChatEnabled = false;
  bool _isComposerEmpty = true;

  Future<void> _markAsRead() async {
    if (_myUid.isEmpty || widget.targetUserId.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', widget.targetUserId)
          .eq('receiver_id', _myUid)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking messages as read: \$e');
    }
  }`;

if (c.includes(oldStateVars)) {
  c = c.replace(oldStateVars, newStateVars);
  n++;
} else {
  console.log("MISS: oldStateVars");
}

// 2. Setup composer empty check in initState
const oldInitState = `  @override
  void initState() {
    super.initState();
    _memberChatEnabled = widget.memberChatEnabled;
    _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    
    if (widget.isUnlocked) {
      _isChatLocked = false;
      _isConnectionLoading = false;
    } else {
      _fetchConnectionStatus();
    }
    
    _fetchMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMessages());
  }`;

const newInitState = `  @override
  void initState() {
    super.initState();
    _memberChatEnabled = widget.memberChatEnabled;
    _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    
    _msgController.addListener(() {
      if (mounted) {
        setState(() {
          _isComposerEmpty = _msgController.text.trim().isEmpty;
        });
      }
    });

    if (widget.isUnlocked) {
      _isChatLocked = false;
      _isConnectionLoading = false;
    } else {
      _fetchConnectionStatus();
    }
    
    _fetchMessages();
    _markAsRead();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchMessages();
    });
  }`;

if (c.includes(oldInitState)) {
  c = c.replace(oldInitState, newInitState);
  n++;
} else {
  console.log("MISS: oldInitState");
}

// 3. Mark read inside _fetchMessages when loaded
const oldFetchMsgs = `      final response = await Supabase.instance.client
          .from('messages')
          .select()
          .or('and(sender_id.eq.\$_myUid,receiver_id.eq.\${widget.targetUserId}),and(sender_id.eq.\${widget.targetUserId},receiver_id.eq.\$_myUid)')
          .order('created_at', ascending: true); // Oldest first at index 0 (Top)

      final newMsgs = List<Map<String, dynamic>>.from(response);`;

const newFetchMsgs = `      final response = await Supabase.instance.client
          .from('messages')
          .select()
          .or('and(sender_id.eq.\$_myUid,receiver_id.eq.\${widget.targetUserId}),and(sender_id.eq.\${widget.targetUserId},receiver_id.eq.\$_myUid)')
          .order('created_at', ascending: true); // Oldest first at index 0 (Top)

      final newMsgs = List<Map<String, dynamic>>.from(response);
      _markAsRead();`;

if (c.includes(oldFetchMsgs)) {
  c = c.replace(oldFetchMsgs, newFetchMsgs);
  n++;
} else {
  console.log("MISS: oldFetchMsgs");
}

// 4. Update the send button visibility/animation
const oldSendBtn = `                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF3B4CCA)]),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.3), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),`;

const newSendBtn = `                  const SizedBox(width: 10),
                  AnimatedScale(
                    scale: _isComposerEmpty ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: GestureDetector(
                      onTap: _isComposerEmpty ? null : _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF3B4CCA)]),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),`;

if (c.includes(oldSendBtn)) {
  c = c.replace(oldSendBtn, newSendBtn);
  n++;
} else {
  console.log("MISS: oldSendBtn");
}

// 5. Update delivery status ticks in bubble
const oldTicks = `                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(timeStr, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                                          if (isMe) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.done_all, color: Color(0xFF00E5FF), size: 12),
                                          ],
                                        ],
                                      ),`;

const newTicks = `                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(timeStr, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                                          if (isMe) ...[
                                            const SizedBox(width: 4),
                                            Builder(
                                              builder: (context) {
                                                final isTemp = msg['id'] is int && (msg['id'] as int) > 1000000000000;
                                                if (isTemp) {
                                                  return const Icon(Icons.done, color: Colors.white24, size: 12);
                                                }
                                                final isRead = msg['is_read'] == true;
                                                return Icon(
                                                  Icons.done_all,
                                                  color: isRead ? const Color(0xFF00E5FF) : Colors.white38,
                                                  size: 12,
                                                );
                                              }
                                            ),
                                          ],
                                        ],
                                      ),`;

if (c.includes(oldTicks)) {
  c = c.replace(oldTicks, newTicks);
  n++;
} else {
  console.log("MISS: oldTicks");
}

c = c.replace(/\n/g, '\r\n');
fs.writeFileSync(filePath, c, 'utf8');
console.log(`Done. Applied ${n} replacements.`);
