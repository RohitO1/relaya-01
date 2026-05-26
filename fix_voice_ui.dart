import 'dart:io';

void main() {
  final file = File('lib/bolroom/bolroom_profile_screen.dart');
  var content = file.readAsStringSync();
  
  final idx = content.indexOf('  Widget _buildVoiceEffectsSection()');
  int depth = 0;
  bool started = false;
  int end = -1;
  for (int i = idx; i < content.length; i++) {
    if (content[i] == '{') { depth++; started = true; }
    else if (content[i] == '}') {
      depth--;
      if (started && depth == 0) { end = i + 1; break; }
    }
  }

  const newFn = r'''  Widget _buildVoiceEffectsSection() {
    final presets = VoiceMaskPreset.all;
    final activePreset = VoiceMaskPreset.byId(_voiceMaskPreset) ?? VoiceMaskPreset.all.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text("Voice Effects", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              // Main toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Enable Voice Masking", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _voiceMaskEnabled
                      ? "Active:  "
                      : "Original Voice Transmitting",
                  style: TextStyle(color: _voiceMaskEnabled ? const Color(0xFF00E5FF) : textMuted, fontSize: 12)
                ),
                value: _voiceMaskEnabled,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF00E5FF),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: const Color(0xFF2A2440),
                onChanged: (v) {
                  setState(() => _voiceMaskEnabled = v);
                  _updateProfile({'voice_mask_enabled': v});
                },
              ),
              if (_voiceMaskEnabled) ...[
                const Divider(color: borderColor, height: 24),
                // Active preset card
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [activePreset.colors.first.withValues(alpha: 0.15), activePreset.colors.last.withValues(alpha: 0.05)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: activePreset.colors.first.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: activePreset.colors,
                          ),
                          boxShadow: [BoxShadow(color: activePreset.colors.first.withValues(alpha: 0.5), blurRadius: 10)],
                        ),
                        child: Center(child: Text(activePreset.icon, style: const TextStyle(fontSize: 26))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activePreset.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 3),
                            Text(activePreset.description, style: TextStyle(color: activePreset.colors.first, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Preset grid — always visible when masking is ON
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: presets.length,
                  itemBuilder: (_, i) {
                    final p = presets[i];
                    final isActive = _voiceMaskPreset == p.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _voiceMaskPreset = p.id;
                          _hasRecording = false;
                          _isPlayingTest = false;
                          _isRecordingTest = false;
                        });
                        _audioPlayer.stop();
                        _updateProfile({'voice_mask_preset': p.id});
                        VoiceMaskService.instance.setPreset(p.id);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: isActive ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [p.colors.first.withValues(alpha: 0.25), p.colors.last.withValues(alpha: 0.1)],
                          ) : null,
                          border: Border.all(
                            color: isActive ? p.colors.first : borderColor,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 46, height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: p.colors,
                                ),
                                boxShadow: isActive ? [BoxShadow(color: p.colors.first.withValues(alpha: 0.5), blurRadius: 10)] : null,
                              ),
                              child: Center(child: Text(p.icon, style: const TextStyle(fontSize: 22))),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.name,
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.white60,
                                fontSize: 10,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Custom preset advanced controls
                if (_voiceMaskPreset == 'custom') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1030),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF093FB).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('???', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Text('Custom Voice Lab', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Pitch slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pitch', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(
                              _voicePitch >= 0.5
                                  ? '+ st'
                                  : ' st',
                              style: const TextStyle(color: Color(0xFFF093FB), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: const Color(0xFFF093FB),
                            inactiveTrackColor: const Color(0xFF2A2440),
                            thumbColor: Colors.white,
                            overlayColor: const Color(0xFFF093FB).withValues(alpha: 0.2),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _voicePitch,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (v) {
                              setState(() => _voicePitch = v);
                              VoiceMaskService.instance.setCustomPitch(v * 24 - 12);
                              _updateProfile({'voice_pitch': v});
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Deep', style: TextStyle(color: textMuted, fontSize: 10)),
                            Text('Original', style: TextStyle(color: textMuted, fontSize: 10)),
                            Text('High', style: TextStyle(color: textMuted, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Test voice button
                GestureDetector(
                  onTap: () => _toggleVoiceTest(setState),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _isRecordingTest
                          ? const Color(0xFFFF3D5A).withValues(alpha: 0.12)
                          : _isPlayingTest
                              ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
                              : _hasRecording
                                  ? const Color(0xFF00E676).withValues(alpha: 0.1)
                                  : cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isRecordingTest
                            ? const Color(0xFFFF3D5A)
                            : _isPlayingTest
                                ? const Color(0xFF00E5FF)
                                : _hasRecording
                                    ? const Color(0xFF00E676)
                                    : borderColor,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isPlayingTest ? Icons.stop_rounded
                              : _isRecordingTest ? Icons.stop_circle_outlined
                              : _hasRecording ? Icons.play_circle_fill
                              : Icons.mic,
                          color: _isRecordingTest
                              ? const Color(0xFFFF3D5A)
                              : _isPlayingTest
                                  ? const Color(0xFF00E5FF)
                                  : _hasRecording
                                      ? const Color(0xFF00E676)
                                      : Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isPlayingTest ? 'Stop Playback'
                              : _isRecordingTest ? 'Recording... ( s) — Tap to Stop'
                              : _hasRecording ? '? Play with   Voice'
                              : '?? Test Voice (3 sec)',
                          style: TextStyle(
                            color: _isRecordingTest
                                ? const Color(0xFFFF3D5A)
                                : _isPlayingTest
                                    ? const Color(0xFF00E5FF)
                                    : _hasRecording
                                        ? const Color(0xFF00E676)
                                        : Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Save button
                GestureDetector(
                  onTap: () {
                    _updateProfile({
                      'voice_mask_enabled': _voiceMaskEnabled,
                      'voice_mask_preset': _voiceMaskPreset,
                      'voice_pitch': _voicePitch,
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(children: [
                            Text(activePreset.icon, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(' voice saved!'),
                          ]),
                          backgroundColor: const Color(0xFF1A1A2E),
                          behavior: SnackBarBehavior.floating,
                        )
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: activePreset.colors),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: activePreset.colors.first.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(activePreset.icon, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          const Text('Save Voice Mask', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }''';
  
  content = content.substring(0, idx) + newFn + content.substring(end);
  file.writeAsStringSync(content);
  print('Done! Replaced _buildVoiceEffectsSection()');
}
