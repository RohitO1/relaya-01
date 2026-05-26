const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'lib', 'messages_screen.dart');
let c = fs.readFileSync(filePath, 'utf8');

c = c.replace(/\r\n/g, '\n');

let n = 0;

// 1. Add replies, local deletions, and reactions state maps/sets
const oldStateVars2 = `  bool _isComposerEmpty = true;`;
const newStateVars2 = `  bool _isComposerEmpty = true;
  Map<String, dynamic>? _replyingTo;
  final Set<String> _locallyDeletedMsgIds = {};
  final Map<String, String> _messageReactions = {};`;

if (c.includes(oldStateVars2)) {
  c = c.replace(oldStateVars2, newStateVars2);
  n++;
} else {
  console.log("MISS: oldStateVars2");
}

// 2. Add _showMessageActions helper method inside _ChatDetailScreenState
const oldInitState2 = `  @override
  void initState() {`;

const newActionsMethod = `  void _showMessageActions(Map<String, dynamic> msg) {
    final isMe = msg['sender_id'] == _myUid;
    final isImage = msg['is_image'] == true;
    final text = msg['text'] as String? ?? '';
    final msgId = msg['id'].toString();
    final createdAt = msg['created_at'] != null ? DateTime.parse(msg['created_at']) : DateTime.now();
    final canDeleteEveryone = isMe && DateTime.now().difference(createdAt).inHours < 24;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B202D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji Reaction Bar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) => GestureDetector(
                    onTap: () {
                      setState(() => _messageReactions[msgId] = emoji);
                      Navigator.pop(ctx);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  )).toList(),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.reply, color: Colors.white),
                title: const Text('Reply', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _replyingTo = msg);
                },
              ),
              if (!isImage)
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.white),
                  title: const Text('Copy Text', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.white),
                title: const Text('Delete for me', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _locallyDeletedMsgIds.add(msgId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message deleted locally')));
                },
              ),
              if (canDeleteEveryone)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Color(0xFFEF4444)),
                  title: const Text('Delete for everyone', style: TextStyle(color: Color(0xFFEF4444))),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      // Perform soft delete in database
                      await Supabase.instance.client
                          .from('messages')
                          .update({'deleted_for_everyone': true})
                          .eq('id', msg['id']);
                      
                      _fetchMessages(); // Sync updates
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: \$e')));
                    }
                  },
                ),
            ],
          ),
        );
      }
    );
  }

  @override
  void initState() {`;

if (c.includes(oldInitState2)) {
  c = c.replace(oldInitState2, newActionsMethod);
  n++;
} else {
  console.log("MISS: oldInitState2");
}

// 3. Update _sendMessage to incorporate reply fields
const oldSendBody = `    // Optimistic update
    final tempMsg = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'sender_id': _myUid,
      'receiver_id': widget.targetUserId,
      'text': text,
      'is_image': false,
      'created_at': DateTime.now().toIso8601String(),
    };
    
    setState(() => _messages.add(tempMsg));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    
    try {
      await Supabase.instance.client.from('messages').insert({
        'sender_id': _myUid,
        'receiver_id': widget.targetUserId,
        'text': text,
        'is_image': false,
      });`;

const newSendBody = `    // Optimistic update
    final tempMsg = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'sender_id': _myUid,
      'receiver_id': widget.targetUserId,
      'text': text,
      'is_image': false,
      'created_at': DateTime.now().toIso8601String(),
      if (_replyingTo != null) ...{
        'reply_to_id': _replyingTo!['id'].toString(),
        'reply_to_text': _replyingTo!['text'].toString(),
        'reply_to_sender': _replyingTo!['sender_id'].toString(),
      }
    };
    
    final payload = {
      'sender_id': _myUid,
      'receiver_id': widget.targetUserId,
      'text': text,
      'is_image': false,
      if (_replyingTo != null) ...{
        'reply_to_id': _replyingTo!['id'].toString(),
        'reply_to_text': _replyingTo!['text'].toString(),
        'reply_to_sender': _replyingTo!['sender_id'].toString(),
      }
    };

    setState(() {
      _messages.add(tempMsg);
      _replyingTo = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    
    try {
      await Supabase.instance.client.from('messages').insert(payload);`;

if (c.includes(oldSendBody)) {
  c = c.replace(oldSendBody, newSendBody);
  n++;
} else {
  console.log("MISS: oldSendBody");
}

// 4. Update composer rendering with replies preview bar
const oldComposerBody = `          else
            Container(
              padding: EdgeInsets.fromLTRB(12, 12, 12, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D12),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: Row(
                children: [`;

const newComposerBody = `          else
            Container(
              padding: EdgeInsets.fromLTRB(12, 12, 12, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D12),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingTo != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: const Border(left: BorderSide(color: Color(0xFF00E5FF), width: 3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _replyingTo!['sender_id'] == _myUid ? 'Replying to yourself' : 'Replying to \${widget.name}',
                                  style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _replyingTo!['text'] as String,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                            onPressed: () => setState(() => _replyingTo = null),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    children: [`;

if (c.includes(oldComposerBody)) {
  c = c.replace(oldComposerBody, newComposerBody);
  n++;
} else {
  console.log("MISS: oldComposerBody");
}

// 5. Close matching brace for Row column inside composer
const oldComposerClose = `                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _shouldShowDateSeparator`;

const newComposerClose = `                ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _shouldShowDateSeparator`;

if (c.includes(oldComposerClose)) {
  c = c.replace(oldComposerClose, newComposerClose);
  n++;
} else {
  console.log("MISS: oldComposerClose");
}

c = c.replace(/\n/g, '\r\n');
fs.writeFileSync(filePath, c, 'utf8');
console.log(`Done. Applied ${n} replacements.`);
