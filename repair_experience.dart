import 'dart:io';

void main() {
  final file = File('lib/experience_screen.dart');
  var code = file.readAsStringSync();

  // ───────────────────────────────────────────────────────────────────────────
  // REPAIR 1: Fix the broken _updateStatus method (lines 1784-1793)
  // The "notify companion" block was deleted, leaving orphaned lines.
  // ───────────────────────────────────────────────────────────────────────────
  final badUpdateStatus = """      await Supabase.instance.client
          .from('requests')
          .update({'status': newStatus})
          .eq('id', requestId);

          'text': msg,
          'is_image': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      if (mounted) {""";

  final fixedUpdateStatus = """      await Supabase.instance.client
          .from('requests')
          .update({'status': newStatus})
          .eq('id', requestId);

      // Notify the requester with a DM
      if (senderId != null && myUid != null) {
        final myProfile = await Supabase.instance.client
            .from('profiles')
            .select('name, full_name')
            .eq('id', myUid)
            .maybeSingle();
        final myName = myProfile?['name'] ?? myProfile?['full_name'] ?? 'A companion';
        final notifyMsg = newStatus == 'approved'
            ? '✅ Great news! \$myName has accepted your connection request. You can now chat and plan your meetup!'
            : '❌ \$myName has reviewed your request and decided not to connect at this time.';
        await Supabase.instance.client.from('messages').insert({
          'sender_id': myUid,
          'receiver_id': senderId,
          'text': notifyMsg,
          'is_image': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      if (mounted) {""";

  if (code.contains(badUpdateStatus)) {
    code = code.replaceFirst(badUpdateStatus, fixedUpdateStatus);
    print('✅ Repair 1 applied: _updateStatus restored');
  } else {
    print('⚠️  Repair 1: pattern not found (may already be fixed)');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // REPAIR 2: Fix the corrupted build() method in CompanionRequestDetailScreen.
  // The avatar section was destroyed and fake blocks injected inside the widget tree.
  // Replace from "// Requester Profile Hero Card" down to "// Interests"
  // ───────────────────────────────────────────────────────────────────────────
  // Find anchor: after status banner, before Interests
  final badHeroStart = '                            // Requester Profile Hero Card';
  final badHeroEnd   = '                            // Interests';

  final startIdx = code.indexOf(badHeroStart);
  final endIdx   = code.indexOf(badHeroEnd);

  if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
    final cleanHero = r"""                            // Requester Profile Hero Card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                  colors: [const Color(0xFF8B5CF6).withOpacity(0.15), const Color(0xFF101015)],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25)),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: SweepGradient(colors: [Color(0xFF8B5CF6), Color(0xFF00E5FF), Color(0xFF8B5CF6)]),
                                    ),
                                    child: CircleAvatar(
                                      radius: 44,
                                      backgroundImage: _safeProvider(_requesterProfile!['avatar_url'] ?? 'https://picsum.photos/seed/${_requesterProfile!["id"]}/200'),
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
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
                                      child: Text(_requesterProfile!['bio'], style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Virtual Meet CTA (shown only when approved + virtual booking)
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
                                    boxShadow: [BoxShadow(color: Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 12)],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.videocam, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        virtualSlot.isNotEmpty ? 'Join Virtual Meet  ($virtualSlot)' : 'Join Virtual Meet',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Their message
                            if (requestMsg.isNotEmpty) ...[
                              const Text('THEIR MESSAGE', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.format_quote, color: Color(0xFF8B5CF6), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(requestMsg, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6))),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Interests""";

    code = code.substring(0, startIdx) + cleanHero + code.substring(endIdx + badHeroEnd.length);
    print('✅ Repair 2 applied: Hero card + virtual CTA restored');
  } else {
    print('⚠️  Repair 2: anchors not found (startIdx=$startIdx, endIdx=$endIdx)');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // REPAIR 3: Remove the duplicate virtual-meet block that got injected
  // in lines 1955–1988 (the old if(requestMsg.isNotEmpty) with stale content)
  // ───────────────────────────────────────────────────────────────────────────
  // After our new clean block, there should be an immediate "// Interests" section.
  // But there may be orphaned duplicate lines. Remove them.
  final dupMarker1 = """                            ],                        if (isApproved && isVirtual) ...[""";
  if (code.contains(dupMarker1)) {
    // Find the end of the dup block — find the next "// Interests"
    final dupStart = code.indexOf(dupMarker1);
    final dupEnd = code.indexOf('\n                            // Interests', dupStart);
    if (dupEnd != -1) {
      code = code.substring(0, dupStart) + '\n' + code.substring(dupEnd);
      print('✅ Repair 3 applied: duplicate virtual block removed');
    }
  } else {
    print('⚠️  Repair 3: dup marker not found (may already be clean)');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // REPAIR 4: Ensure build() pre-computes isVirtual/virtualSlot/requestMsg
  // They should be in the build() before the return Scaffold.
  // ───────────────────────────────────────────────────────────────────────────
  final preComputeTarget = "    // Pre-compute lists so they can be used inside the widget tree\n    final interests = _requesterProfile != null ? _parseList(_requesterProfile!['interests']) : <String>[];\n    final lookingFor = _requesterProfile != null ? _parseList(_requesterProfile!['looking_for']) : <String>[];";
  if (code.contains(preComputeTarget) && !code.contains('final String requestMsg')) {
    final fix = """    // Pre-compute lists so they can be used inside the widget tree
    final interests = _requesterProfile != null ? _parseList(_requesterProfile!['interests']) : <String>[];
    final lookingFor = _requesterProfile != null ? _parseList(_requesterProfile!['looking_for']) : <String>[];
    final String requestMsg = (widget.request['message'] ?? '').toString();
    final bool isVirtual = requestMsg.contains('Mode: Virtual');
    final String virtualSlot = isVirtual && requestMsg.contains('(Slot: ')
        ? requestMsg.split('(Slot: ').last.split(')').first
        : '';""";
    code = code.replaceFirst(preComputeTarget, fix);
    print('✅ Repair 4 applied: pre-compute vars added to build()');
  } else {
    print('⚠️  Repair 4: already present or anchor not found');
  }

  file.writeAsStringSync(code);
  print('\n🎉 All repairs complete. File saved.');
}
