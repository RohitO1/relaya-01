const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'lib', 'messages_screen.dart');
let c = fs.readFileSync(filePath, 'utf8');

c = c.replace(/\r\n/g, '\n');

let n = 0;

// 1. Check local deletion inside itemBuilder
const oldItemStart = `                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg['sender_id'] == _myUid;`;

const newItemStart = `                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg['sender_id'] == _myUid;
                        final msgId = msg['id'].toString();
                        if (_locallyDeletedMsgIds.contains(msgId)) {
                          return const SizedBox.shrink();
                        }`;

if (c.includes(oldItemStart)) {
  c = c.replace(oldItemStart, newItemStart);
  n++;
} else {
  console.log("MISS: oldItemStart");
}

// 2. Change onLongPress call
const oldLongPress = `                            GestureDetector(
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                if (!isImage) {
                                  Clipboard.setData(ClipboardData(text: msg['text'] as String));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Message copied'),
                                      backgroundColor: const Color(0xFF3B4CCA),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              },`;

const newLongPress = `                            GestureDetector(
                              onLongPress: () => _showMessageActions(msg),`;

if (c.includes(oldLongPress)) {
  c = c.replace(oldLongPress, newLongPress);
  n++;
} else {
  console.log("MISS: oldLongPress");
}

// 3. Update padding and child container contents for deletes and replies
const oldPadding = `                                        padding: isImage ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: isImage 
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: _buildImage(msg['text'] as String),
                                              )
                                            : isCompliment
                                                ? Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.favorite, color: Color(0xFFFF4D8D), size: 14),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            'Icebreaker Compliment',
                                                            style: TextStyle(
                                                              color: const Color(0xFFFF4D8D),
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              letterSpacing: 0.5,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        (msg['text'] as String).replaceAll('💌 Compliment:', '').trim(),
                                                        style: TextStyle(
                                                          color: isMe ? Colors.white : Colors.white70,
                                                          fontSize: 14,
                                                          height: 1.4,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : Text(msg['text'] as String, style: TextStyle(color: isMe ? Colors.white : Colors.white70, fontSize: 14, height: 1.4)),`;

const newPadding = `                                        padding: (isImage && msg['reply_to_text'] == null) ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: msg['deleted_for_everyone'] == true
                                            ? const Text(
                                                'This message was deleted',
                                                style: TextStyle(color: Colors.white30, fontStyle: FontStyle.italic, fontSize: 13),
                                              )
                                            : Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (msg['reply_to_text'] != null) ...[
                                                    Container(
                                                      margin: const EdgeInsets.only(bottom: 6),
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.06),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: const Border(
                                                          left: BorderSide(color: Color(0xFF00E5FF), width: 3),
                                                        ),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            msg['reply_to_sender'] == _myUid ? 'You' : widget.name,
                                                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            msg['reply_to_text'] as String,
                                                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  isImage 
                                                      ? ClipRRect(
                                                          borderRadius: BorderRadius.circular(16),
                                                          child: _buildImage(msg['text'] as String),
                                                        )
                                                      : isCompliment
                                                          ? Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    const Icon(Icons.favorite, color: Color(0xFFFF4D8D), size: 14),
                                                                    const SizedBox(width: 6),
                                                                    const Text(
                                                                      'Icebreaker Compliment',
                                                                      style: TextStyle(
                                                                        color: Color(0xFFFF4D8D),
                                                                        fontSize: 11,
                                                                        fontWeight: FontWeight.bold,
                                                                        letterSpacing: 0.5,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(height: 6),
                                                                Text(
                                                                  (msg['text'] as String).replaceAll('💌 Compliment:', '').trim(),
                                                                  style: TextStyle(
                                                                    color: isMe ? Colors.white : Colors.white70,
                                                                    fontSize: 14,
                                                                    height: 1.4,
                                                                    fontStyle: FontStyle.italic,
                                                                  ),
                                                                ),
                                                              ],
                                                            )
                                                          : Text(msg['text'] as String, style: TextStyle(color: isMe ? Colors.white : Colors.white70, fontSize: 14, height: 1.4)),
                                                ],
                                              ),`;

if (c.includes(oldPadding)) {
  c = c.replace(oldPadding, newPadding);
  n++;
} else {
  console.log("MISS: oldPadding");
}

// 4. Floating reactions badge below the message container
const oldMsgFooter = `                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,`;

const newMsgFooter = `                                      if (_messageReactions[msgId] != null) ...[
                                        Transform.translate(
                                          offset: const Offset(0, -2),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1B202D),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.white12, width: 1),
                                            ),
                                            child: Text(_messageReactions[msgId]!, style: const TextStyle(fontSize: 10)),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,`;

if (c.includes(oldMsgFooter)) {
  c = c.replace(oldMsgFooter, newMsgFooter);
  n++;
} else {
  console.log("MISS: oldMsgFooter");
}

c = c.replace(/\n/g, '\r\n');
fs.writeFileSync(filePath, c, 'utf8');
console.log(`Done. Applied ${n} replacements.`);
