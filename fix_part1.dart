import 'dart:io';

void main() {
  final file = File('lib/experience_screen.dart');
  var code = file.readAsStringSync();

  // 1. Add fields to _CompanionRegisterScreenState
  if (!code.contains('String _interactionMode =')) {
    final stateStart = code.indexOf('class _CompanionRegisterScreenState');
    final pStart = code.indexOf('int _step = 0;', stateStart);
    code = code.substring(0, pStart) + 
      "String _interactionMode = 'Both';\n  final List<String> _virtualSlots = [];\n  final _virtualSlotCtrl = TextEditingController();\n  " + 
      code.substring(pStart);
  }

  // 2. Load existing
  if (!code.contains('_interactionMode = data[')) {
    final loadIdx = code.indexOf('_category = data[\'category\']');
    code = code.substring(0, loadIdx) +
      "_interactionMode = data['interaction_mode'] ?? 'Both';\n      _virtualSlots.addAll((data['virtual_slots'] as List?)?.map((e) => e.toString()) ?? []);\n      " +
      code.substring(loadIdx);
  }

  // 3. Save to DB
  if (!code.contains('\'interaction_mode\': _interactionMode,')) {
    final saveIdx = code.indexOf('\'is_active\': true,');
    code = code.substring(0, saveIdx) +
      "'interaction_mode': _interactionMode,\n        'virtual_slots': _virtualSlots,\n        " +
      code.substring(saveIdx);
  }

  // 4. Update Step 4 UI
  final step4Start = code.indexOf('Widget _buildStep4() {');
  final step4End = code.indexOf('Widget _buildStep5() {');
  if (step4Start > -1 && step4End > -1 && !code.substring(step4Start, step4End).contains('Virtual Availability')) {
    final replaceTarget = code.substring(step4Start, step4End);
    final newStep4 = replaceTarget.replaceAll(
      '// Rate',
      '''// Interaction Mode & Virtual Slots
          const Text('Interaction Mode', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: ['In-Person', 'Virtual', 'Both'].map((mode) {
              final selected = _interactionMode == mode;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _interactionMode = mode),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF8B5CF6).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                      border: Border.all(color: selected ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(mode, style: TextStyle(color: selected ? const Color(0xFF8B5CF6) : Colors.white70, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          if (_interactionMode == 'Virtual' || _interactionMode == 'Both') ...[
            const Text('Virtual Availability Slots', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('e.g., "Mon 10:00 AM - 11:00 AM (IST)"', style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _virtualSlotCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a time slot...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true, fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_virtualSlotCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _virtualSlots.add(_virtualSlotCtrl.text.trim());
                        _virtualSlotCtrl.clear();
                      });
                    }
                  },
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: const Color(0xFF8B5CF6), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _virtualSlots.map((s) => Chip(
                label: Text(s, style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                deleteIconColor: Colors.white70,
                onDeleted: () => setState(() => _virtualSlots.remove(s)),
              )).toList(),
            ),
            const SizedBox(height: 24),
          ],
          
          // Rate'''
    );
    code = code.replaceFirst(replaceTarget, newStep4);
  }

  // 5. Update _CompanionDetailScreenState to handle Booking Sheet
  if (!code.contains('void _showBookingSheet()')) {
    final sendReqStart = code.indexOf('Future<void> _sendConnectRequest() async {');
    final replacement = '''String _selectedMode = 'In-Person';
  String _selectedSlot = '';

  void _showBookingSheet() {
    final interactionMode = widget.comp['interaction_mode'] ?? 'Both';
    final List<String> virtualSlots = (widget.comp['virtual_slots'] as List?)?.map((e) => e.toString()).toList() ?? [];
    
    setState(() {
      _selectedMode = interactionMode == 'Virtual' ? 'Virtual' : 'In-Person';
      _selectedSlot = virtualSlots.isNotEmpty ? virtualSlots.first : '';
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(24).copyWith(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            decoration: const BoxDecoration(
              color: Color(0xFF10121A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Book Companion', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                if (interactionMode == 'Both') ...[
                  const Text('Interaction Type', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    children: ['In-Person', 'Virtual'].map((m) => Expanded(
                      child: GestureDetector(
                        onTap: () => setSheetState(() => _selectedMode = m),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedMode == m ? const Color(0xFF06B6D4).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                            border: Border.all(color: _selectedMode == m ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(m, style: TextStyle(color: _selectedMode == m ? const Color(0xFF06B6D4) : Colors.white70)),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                if (_selectedMode == 'Virtual' && virtualSlots.isNotEmpty) ...[
                  const Text('Select Virtual Slot', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSlot,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1A1C24),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        items: virtualSlots.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white)))).toList(),
                        onChanged: (v) { if (v != null) setSheetState(() => _selectedSlot = v); },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendConnectRequest();
                  },
                  child: Container(
                    width: double.infinity, height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('Confirm Booking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Future<void> _sendConnectRequest() async {''';
    code = code.replaceFirst('Future<void> _sendConnectRequest() async {', replacement);
    
    // Replace tap on connectButton to use _showBookingSheet
    code = code.replaceFirst('onTap: _isRequesting ? null : _sendConnectRequest,', 'onTap: _isRequesting ? null : _showBookingSheet,');

    // Update message to include mode & slot
    final msgTarget = "'message': 'I would like to connect with you as a companion.',";
    final newMsg = "'message': 'I would like to connect with you as a companion. Mode: \' + (_selectedMode == 'Virtual' ? ' (Slot: \)' : ''),";
    code = code.replaceFirst(msgTarget, newMsg);
  }

  file.writeAsStringSync(code);
  print('Step 1 & 2 done.');
}
