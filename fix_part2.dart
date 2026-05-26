import 'dart:io';

void main() {
  final file = File('lib/experience_screen.dart');
  var code = file.readAsStringSync();

  if (!code.contains('import \'virtual_meet_screen.dart\';')) {
    code = code.replaceFirst('import \'rush_in_consumer_detail_view.dart\';', 'import \'rush_in_consumer_detail_view.dart\';\nimport \'virtual_meet_screen.dart\';');
  }

  // Update CompanionRequestDetailScreen
  // Find where it checks for "Their message"
  final msgTarget = "if ((widget.request['message'] ?? '').toString().isNotEmpty) ...[";
  if (code.contains(msgTarget) && !code.contains('isVirtual')) {
    final replacement = '''final String requestMsg = (widget.request['message'] ?? '').toString();
                            final bool isVirtual = requestMsg.contains('Mode: Virtual');
                            final String virtualSlot = isVirtual && requestMsg.contains('(Slot: ') 
                                ? requestMsg.split('(Slot: ')[1].split(')')[0] 
                                : '';

                            if (isApproved && isVirtual) ...[
                              const Text('VIRTUAL MEET READY', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => VirtualMeetScreen(
                                    peerName: _requesterProfile!['name'] ?? 'User',
                                    channelId: widget.request['id'].toString(),
                                  )));
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF3B82F6)]),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 12)],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.videocam, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text('Join Virtual Meet\n(\)', 
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            if (requestMsg.isNotEmpty) ...[''';
    code = code.replaceFirst(msgTarget, replacement);
  }

  file.writeAsStringSync(code);
  print('Step 3 done.');
}
